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
            precondition(delegate.libraryTitle == "CoolSkill", "Main window title is missing")
            precondition(app.windows.contains { $0.isVisible && $0.title == "CoolSkill" },
                         "Expected visible CoolSkill main window")
            precondition(delegate.applicationMenuTitles.contains("设置…"))
            precondition(delegate.applicationMenuTitles.contains("检查更新…"))
            precondition(delegate.applicationMenuTitles.contains("窗口置顶"))
            print("AppKit lifecycle passed: compact CoolSkill window and application menu are configured.")
            app.terminate(nil)
        }
        withExtendedLifetime(delegate) { app.run() }
    }
}
