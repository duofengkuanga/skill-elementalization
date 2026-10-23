import AppKit
import CoolSkillCore
import SwiftUI

@MainActor
final class SkillLibraryWindowController: NSObject {
    private let model: CoolSkillModel
    private var window: NSWindow!
    private var keyMonitor: Any?

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
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func openSettings() {
        window.makeKeyAndOrderFront(nil)
        model.openSettings()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeWindow() -> NSWindow {
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = "kcoisga"
        newWindow.titlebarAppearsTransparent = true
        newWindow.isReleasedWhenClosed = false
        newWindow.contentMinSize = NSSize(width: 780, height: 520)
        newWindow.contentView = NSHostingView(rootView: CoolSkillPanel(model: model))
        newWindow.setFrameAutosaveName("kcoisga-library")
        newWindow.center()
        return newWindow
    }

    private func installKeyboardMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.window.isKeyWindow,
                  !self.model.isSettingsPresented,
                  self.model.insertionMessage == nil else { return event }
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                .subtracting([.numericPad, .function, .capsLock])
            if modifiers == .command,
               let number = Int(event.charactersIgnoringModifiers ?? ""),
               (1...4).contains(number) {
                self.model.select(Element.allCases[number - 1])
                return nil
            }
            guard modifiers.isEmpty else { return event }
            switch event.keyCode {
            case 125:
                self.model.moveKeyboardSelection(by: 1)
                return nil
            case 126:
                self.model.moveKeyboardSelection(by: -1)
                return nil
            case 36:
                return self.model.invokeKeyboardSelection() ? nil : event
            default:
                return event
            }
        }
    }
}
