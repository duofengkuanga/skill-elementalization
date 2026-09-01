import AppKit
import CoolSkillCore
import SwiftUI

@MainActor
final class SkillLibraryWindowController: NSObject, NSWindowDelegate {
    private let model: CoolSkillModel
    private var window: NSWindow!
    private var listPanel: NSPanel?
    private var settingsWindow: NSWindow?
    private var keyMonitor: Any?
    private var dismissListTask: Task<Void, Never>?
    private var isSnapping = false

    private let collapsedWidth: CGFloat = 72
    private let collapsedHeight: CGFloat = 420
    private let listWidth: CGFloat = 300
    private let listHeight: CGFloat = 300

    private(set) var isPinned = false
    var isVisible: Bool { window.isVisible }
    var title: String { window.title }

    init(model: CoolSkillModel) {
        self.model = model
        super.init()
        window = makeWindow()
        installKeyboardMonitor()
    }

    deinit {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
    }

    func showAndActivate() {
        model.prepareForPresentation()
        hideListImmediately()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func toggleVisibility() {
        if window.isVisible, window.isKeyWindow {
            window.orderOut(nil)
        } else {
            showAndActivate()
        }
    }

    func setPinned(_ pinned: Bool) {
        guard pinned != isPinned else { return }
        isPinned = pinned
        model.setPinned(pinned)
        window.level = pinned ? .floating : .normal
        window.collectionBehavior = pinned
            ? [.canJoinAllSpaces, .fullScreenAuxiliary]
            : [.moveToActiveSpace, .fullScreenAuxiliary]
        listPanel?.level = window.level
        listPanel?.collectionBehavior = pinned
            ? [.canJoinAllSpaces, .fullScreenAuxiliary]
            : [.moveToActiveSpace, .fullScreenAuxiliary]
    }

    func togglePinned() {
        setPinned(!isPinned)
    }

    func openSettings() {
        let settings = settingsWindow ?? makeSettingsWindow()
        settingsWindow = settings
        settings.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeWindow() -> NSWindow {
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: collapsedWidth, height: collapsedHeight),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        newWindow.delegate = self
        newWindow.title = "CoolSkill"
        newWindow.titleVisibility = .hidden
        newWindow.titlebarAppearsTransparent = true
        newWindow.isOpaque = false
        newWindow.backgroundColor = .clear
        newWindow.isReleasedWhenClosed = false
        newWindow.minSize = NSSize(width: 56, height: 300)
        newWindow.maxSize = NSSize(width: 180, height: 900)
        newWindow.isMovableByWindowBackground = true
        newWindow.contentView = NSHostingView(
            rootView: CoolSkillPanel(
                model: model,
                onTogglePin: { [weak self] in
                    self?.setPinned(!(self?.isPinned ?? false))
                },
                onPresentationChange: { [weak self] isShowing in
                    self?.setListPresentation(isShowing)
                }
            )
        )
        newWindow.contentView?.wantsLayer = true
        newWindow.contentView?.layer?.cornerRadius = 20
        newWindow.contentView?.layer?.masksToBounds = true
        newWindow.center()
        return newWindow
    }

    private func installKeyboardMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.window.isKeyWindow else { return event }
            switch event.keyCode {
            case 18, 19, 20, 21:
                self.model.select(Element.allCases[Int(event.keyCode - 18)])
                self.showList()
                return nil
            case 125:
                self.model.moveKeyboardSelection(by: 1)
                return nil
            case 126:
                self.model.moveKeyboardSelection(by: -1)
                return nil
            case 36:
                _ = self.model.invokeKeyboardSelection()
                return nil
            case 53:
                self.window.performClose(nil)
                return nil
            default:
                return event
            }
        }
    }

    func windowWillClose(_ notification: Notification) {
        setPinned(false)
        hideListImmediately()
    }

    func windowDidMove(_ notification: Notification) {
        guard !isSnapping,
              let movedWindow = notification.object as? NSWindow,
              let visible = movedWindow.screen?.visibleFrame else { return }
        let threshold: CGFloat = 18
        let candidates: [(CGFloat, NSPoint)] = [
            (abs(movedWindow.frame.minX - visible.minX), NSPoint(x: visible.minX, y: movedWindow.frame.minY)),
            (abs(movedWindow.frame.maxX - visible.maxX), NSPoint(x: visible.maxX - movedWindow.frame.width, y: movedWindow.frame.minY)),
            (abs(movedWindow.frame.minY - visible.minY), NSPoint(x: movedWindow.frame.minX, y: visible.minY)),
            (abs(movedWindow.frame.maxY - visible.maxY), NSPoint(x: movedWindow.frame.minX, y: visible.maxY - movedWindow.frame.height))
        ]
        guard let nearest = candidates.min(by: { $0.0 < $1.0 }), nearest.0 <= threshold else { return }
        isSnapping = true
        movedWindow.setFrameOrigin(nearest.1)
        isSnapping = false
    }

    private func setListPresentation(_ isShowing: Bool) {
        if isShowing {
            dismissListTask?.cancel()
            showList()
        } else {
            scheduleListDismissal()
        }
    }

    private func showList() {
        dismissListTask?.cancel()
        guard model.selectedElement != nil else { return }
        let panel = listPanel ?? makeListPanel()
        listPanel = panel
        place(panel)
        panel.orderFront(nil)
    }

    private func scheduleListDismissal() {
        dismissListTask?.cancel()
        dismissListTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 320_000_000)
            guard !Task.isCancelled else { return }
            self?.hideListImmediately()
            self?.model.clearSelection()
        }
    }

    private func hideListImmediately() {
        dismissListTask?.cancel()
        listPanel?.orderOut(nil)
    }

    private func makeListPanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: listWidth, height: listHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.level = window.level
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(
            rootView: SkillListPanelContent(model: model) { [weak self] hovering in
                self?.setListPresentation(hovering)
            }
        )
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.cornerRadius = 20
        panel.contentView?.layer?.masksToBounds = true
        return panel
    }

    private func makeSettingsWindow() -> NSWindow {
        let settings = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 390, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        settings.title = "设置"
        settings.isReleasedWhenClosed = false
        settings.contentView = NSHostingView(
            rootView: SettingsSheet(model: model) { [weak settings] in
                settings?.close()
            }
        )
        settings.center()
        return settings
    }

    private func place(_ panel: NSPanel) {
        let screen = window.screen ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSScreen.screens.first?.visibleFrame ?? .zero
        let gap: CGFloat = 8
        let width = min(listWidth, visible.width - 32)
        let contentHeight = CGFloat(model.visibleSkills.count) * 46 + 72
        let height = min(max(160, min(listHeight, contentHeight)), visible.height - 32)
        let rightSpace = visible.maxX - window.frame.maxX
        let leftSpace = window.frame.minX - visible.minX
        let aboveSpace = visible.maxY - window.frame.maxY
        let belowSpace = window.frame.minY - visible.minY

        let x: CGFloat
        let y: CGFloat
        let size: NSSize
        if rightSpace >= width + gap {
            size = NSSize(width: width, height: height)
            x = window.frame.maxX + gap
            y = min(max(window.frame.midY - height / 2, visible.minY), visible.maxY - height)
        } else if leftSpace >= width + gap {
            size = NSSize(width: width, height: height)
            x = window.frame.minX - width - gap
            y = min(max(window.frame.midY - height / 2, visible.minY), visible.maxY - height)
        } else if belowSpace >= height + gap {
            size = NSSize(width: width, height: height)
            x = min(max(window.frame.midX - width / 2, visible.minX), visible.maxX - width)
            y = window.frame.minY - height - gap
        } else if aboveSpace >= height + gap {
            size = NSSize(width: width, height: height)
            x = min(max(window.frame.midX - width / 2, visible.minX), visible.maxX - width)
            y = window.frame.maxY + gap
        } else if max(rightSpace, leftSpace) >= max(aboveSpace, belowSpace) {
            let availableWidth = max(220, max(rightSpace, leftSpace) - gap)
            size = NSSize(width: min(width, availableWidth), height: height)
            x = rightSpace >= leftSpace ? window.frame.maxX + gap : window.frame.minX - size.width - gap
            y = min(max(window.frame.midY - height / 2, visible.minY), visible.maxY - height)
        } else {
            let availableHeight = max(180, max(aboveSpace, belowSpace) - gap)
            size = NSSize(width: width, height: min(height, availableHeight))
            x = min(max(window.frame.midX - width / 2, visible.minX), visible.maxX - width)
            y = aboveSpace >= belowSpace ? window.frame.maxY + gap : window.frame.minY - size.height - gap
        }
        panel.setContentSize(size)
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
