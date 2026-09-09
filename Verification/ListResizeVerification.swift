import AppKit
import CoolSkillCore

@main
enum ListResizeVerification {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let model = CoolSkillModel(
            catalog: SkillCatalog(roots: []),
            store: LocalStateStore(fileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("coolskill-resize-\(UUID().uuidString)/state.json")),
            usageReconstructor: UsageReconstructor(roots: [])
        )
        let controller = SkillLibraryWindowController(model: model)
        controller.showAndActivate()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000)
            model.select(.wind)
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard let panel = app.windows.first(where: { $0 is NSPanel && $0.isVisible }) as? NSPanel else {
                preconditionFailure("Selecting an element must show the skill list")
            }
            precondition(panel.styleMask.contains(.resizable), "List must support native edge resizing")
            precondition(panel.minSize == NSSize(width: 260, height: 180), "Actual minimum: \(panel.minSize)")
            let expanded = NSSize(width: 480, height: 440)
            controller.windowWillStartLiveResize(Notification(name: NSWindow.willStartLiveResizeNotification, object: panel))
            panel.setContentSize(expanded)
            model.clearSelection()
            try? await Task.sleep(nanoseconds: 450_000_000)
            precondition(panel.isVisible, "Hover dismissal must not hide a list during resizing")
            model.select(.water)
            try? await Task.sleep(nanoseconds: 100_000_000)
            precondition(panel.frame.size == expanded, "Reentering the list must not reset its size")
            controller.windowDidEndLiveResize(Notification(name: NSWindow.didEndLiveResizeNotification, object: panel))
            controller.showAndActivate()
            try? await Task.sleep(nanoseconds: 100_000_000)
            model.select(.fire)
            try? await Task.sleep(nanoseconds: 150_000_000)
            precondition(panel.isVisible, "List must reopen after being hidden")
            precondition(panel.frame.size == expanded, "Reopened list must retain the resized dimensions")
            panel.contentView?.layoutSubtreeIfNeeded()
            precondition(panel.contentView?.frame.size == expanded, "Content must fill the expanded list")
            panel.orderOut(nil)
            print("List resize verification passed: native resizing, dismissal protection, retained size and flexible content.")
            app.terminate(nil)
        }
        withExtendedLifetime(controller) { app.run() }
    }
}
