import AppKit
import CoolSkillCore
import Foundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppContainer.shared.model
    private var windowController: SkillLibraryWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        let windowController = SkillLibraryWindowController(model: model)
        self.windowController = windowController
        installApplicationMenu()
        windowController.showAndActivate()
    }

    #if COOLSKILL_LIFECYCLE_TEST
    var libraryIsVisible: Bool { windowController?.isVisible ?? false }
    var libraryTitle: String { windowController?.title ?? "" }
    var applicationMenuTitles: [String] {
        NSApp.mainMenu?.items.first?.submenu?.items.map(\.title) ?? []
    }
    #endif

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            windowController?.showAndActivate()
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func installApplicationMenu() {
        let mainMenu = NSMenu()
        let applicationItem = NSMenuItem(title: "CoolSkill", action: nil, keyEquivalent: "")
        let applicationMenu = NSMenu(title: "CoolSkill")
        applicationMenu.addItem(withTitle: "关于 CoolSkill", action: #selector(showAbout), keyEquivalent: "")
        applicationMenu.addItem(.separator())
        applicationMenu.addItem(withTitle: "设置…", action: #selector(showSettings), keyEquivalent: ",")
        applicationMenu.addItem(withTitle: "检查更新…", action: #selector(checkForUpdates), keyEquivalent: "")
        applicationMenu.addItem(withTitle: "更新 Skills", action: #selector(refreshSkills), keyEquivalent: "")
        applicationMenu.addItem(.separator())
        applicationMenu.addItem(withTitle: "退出 CoolSkill", action: #selector(quit), keyEquivalent: "q")
        for item in applicationMenu.items where !item.isSeparatorItem {
            item.target = self
        }
        applicationItem.submenu = applicationMenu
        mainMenu.addItem(applicationItem)
        NSApp.mainMenu = mainMenu
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func showSettings() {
        windowController?.openSettings()
    }

    @objc private func refreshSkills() {
        model.refreshCatalog()
    }

    @objc private func checkForUpdates() {
        let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        Task { @MainActor in
            let result = await GitHubUpdateChecker().check(currentVersion: currentVersion)
            let alert = NSAlert()
            alert.messageText = "检查更新"
            switch result {
            case .upToDate:
                alert.informativeText = "CoolSkill 已是最新版本（\(currentVersion)）。"
                alert.addButton(withTitle: "好")
                alert.runModal()
            case let .available(release):
                alert.informativeText = "发现新版本 \(release.tagName)。下载后替换“应用程序”文件夹中的 CoolSkill 即可完成更新。"
                alert.addButton(withTitle: "下载并更新")
                alert.addButton(withTitle: "稍后")
                if alert.runModal() == .alertFirstButtonReturn {
                    do {
                        try await SelfUpdateInstaller.install(release)
                        NSApp.terminate(nil)
                    } catch {
                        let failure = NSAlert(error: error)
                        failure.informativeText = "自动更新失败；已保留当前版本。你可以前往 Release 页面手动下载。"
                        failure.runModal()
                    }
                }
            case .failed:
                alert.informativeText = "暂时无法连接 GitHub 检查更新，请稍后重试。"
                alert.addButton(withTitle: "好")
                alert.runModal()
            }
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

}

#if !COOLSKILL_LIFECYCLE_TEST
@main
enum CoolSkillApplication {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}
#endif
