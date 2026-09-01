import AppKit
import CoolSkillCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppContainer.shared.model
    private var windowController: SkillLibraryWindowController?
    private var chordMonitor: GlobalChordMonitor?
    private var pinMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        let windowController = SkillLibraryWindowController(model: model)
        self.windowController = windowController
        model.onOpenPanel = { [weak windowController] in
            windowController?.showAndActivate()
        }
        installApplicationMenu()
        windowController.showAndActivate()

        #if !COOLSKILL_LIFECYCLE_TEST
        let monitor = GlobalChordMonitor(configuration: model.shortcutConfiguration) { [weak windowController] in
            windowController?.toggleVisibility()
        }
        chordMonitor = monitor
        model.onShortcutChanged = { [weak monitor] configuration in
            monitor?.update(configuration: configuration)
        }
        model.onPermissionRefresh = { [weak monitor] in
            guard monitor?.status != .running else { return }
            _ = monitor?.start()
        }
        _ = monitor.start()
        #endif
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
        applicationMenu.delegate = self
        applicationMenu.addItem(withTitle: "关于 CoolSkill", action: #selector(showAbout), keyEquivalent: "")
        applicationMenu.addItem(.separator())
        applicationMenu.addItem(withTitle: "设置…", action: #selector(showSettings), keyEquivalent: ",")
        applicationMenu.addItem(withTitle: "更新 Skills", action: #selector(refreshSkills), keyEquivalent: "")
        applicationMenu.addItem(.separator())
        let pin = applicationMenu.addItem(withTitle: "窗口置顶", action: #selector(togglePinned), keyEquivalent: "")
        pinMenuItem = pin
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

    @objc private func togglePinned() {
        windowController?.togglePinned()
        updatePinMenuItem()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func updatePinMenuItem() {
        guard let pinMenuItem else { return }
        pinMenuItem.state = windowController?.isPinned == true ? .on : .off
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        updatePinMenuItem()
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
