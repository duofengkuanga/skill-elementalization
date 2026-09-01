import ApplicationServices
import CoolSkillCore
import Foundation

final class GlobalChordMonitor {
    enum Status: Equatable {
        case stopped
        case running
        case permissionRequired
    }

    var onTrigger: (() -> Void)?
    var onStatusChange: ((Status) -> Void)?

    private(set) var status: Status = .stopped {
        didSet { onStatusChange?(status) }
    }

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var recognizer: ChordRecognizer
    private var pendingDDown: CGEvent?
    private var pendingDUp: CGEvent?
    private var timeoutWorkItem: DispatchWorkItem?

    private var configuration: ChordConfiguration
    private let replayTag: Int64 = 0x434F4F4C

    init(
        configuration: ChordConfiguration = .commandDP,
        onTrigger: (() -> Void)? = nil
    ) {
        self.configuration = configuration
        recognizer = ChordRecognizer(configuration: configuration)
        self.onTrigger = onTrigger
    }

    func update(configuration: ChordConfiguration) {
        let wasRunning = eventTap != nil
        stop()
        self.configuration = configuration
        recognizer = ChordRecognizer(configuration: configuration)
        if wasRunning {
            _ = start()
        }
    }

    deinit {
        stop()
    }

    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else { return true }
        let mask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.tapDisabledByTimeout.rawValue)
            | (1 << CGEventType.tapDisabledByUserInput.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<GlobalChordMonitor>.fromOpaque(context).takeUnretainedValue()
            return monitor.handle(type: type, event: event)
        }
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: context
        ) else {
            status = .permissionRequired
            return false
        }
        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        status = .running
        return true
    }

    func stop() {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap = eventTap {
            CFMachPortInvalidate(tap)
        }
        runLoopSource = nil
        eventTap = nil
        pendingDDown = nil
        pendingDUp = nil
        status = .stopped
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }
        if event.getIntegerValueField(.eventSourceUserData) == replayTag {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let phase: ChordKeyPhase = type == .keyDown ? .down : .up
        let input = ChordInput(
            keyCode: keyCode,
            phase: phase,
            commandPressed: event.flags.contains(.maskCommand)
        )

        if keyCode == configuration.primaryKeyCode, phase == .down, input.commandPressed, !recognizer.isWaitingForP {
            pendingDDown = event.copy()
            scheduleTimeout()
        } else if keyCode == configuration.primaryKeyCode, phase == .up, recognizer.isWaitingForP {
            pendingDUp = event.copy()
        }

        let decision = recognizer.receive(input)
        apply(decision)
        return decision.suppressCurrent ? nil : Unmanaged.passUnretained(event)
    }

    private func scheduleTimeout() {
        timeoutWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.apply(self.recognizer.timeout())
        }
        timeoutWorkItem = workItem
        let delay = TimeInterval(configuration.windowMilliseconds) / 1_000
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func apply(_ decision: ChordDecision) {
        if decision.didTrigger {
            timeoutWorkItem?.cancel()
            timeoutWorkItem = nil
            pendingDDown = nil
            pendingDUp = nil
            DispatchQueue.main.async { [weak self] in
                self?.onTrigger?()
            }
            return
        }
        if decision.replayDDown {
            timeoutWorkItem?.cancel()
            timeoutWorkItem = nil
            post(pendingDDown)
            if decision.replayDUp {
                post(pendingDUp)
            }
            pendingDDown = nil
            pendingDUp = nil
        }
    }

    private func post(_ event: CGEvent?) {
        guard let event else { return }
        event.setIntegerValueField(.eventSourceUserData, value: replayTag)
        event.post(tap: .cghidEventTap)
    }
}
