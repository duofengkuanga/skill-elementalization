import AppKit

@main
enum LifecycleVerification {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            precondition(delegate.libraryIsVisible, "Skill library window must be visible at launch")
            precondition(delegate.libraryTitle == "kcoisga", "Main window title is missing")
            guard let window = app.windows.first(where: { $0.isVisible && $0.title == "kcoisga" }) else {
                preconditionFailure("Expected visible kcoisga main window")
            }
            precondition(app.activationPolicy() == .regular, "The app must have a Dock presence")
            precondition(window.styleMask.contains([.titled, .closable, .miniaturizable, .resizable]))
            precondition(window.level == .normal, "The library must not float above other apps")
            precondition(window.contentView!.bounds.width >= 780)
            precondition(!app.windows.contains { $0 is NSPanel && $0.isVisible }, "No floating list panel")
            precondition(delegate.applicationMenuTitles.contains("设置…"))
            precondition(delegate.applicationMenuTitles.contains("检查更新…"))
            precondition(delegate.applicationMenuTitles.contains("退出 kcoisga"))
            precondition(delegate.applicationShouldTerminateAfterLastWindowClosed(app))
            print("AppKit lifecycle passed: standard resizable kcoisga window, normal level and menu. Closing window must exit.")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                preconditionFailure("Closing the main window left a resident process")
            }
            window.performClose(nil)
        }
        withExtendedLifetime(delegate) { app.run() }
    }
}
