import ApplicationServices
import AppKit
import Foundation
import ServiceManagement

struct PermissionSnapshot: Equatable {
    let accessibilityGranted: Bool
}

protocol PermissionControlling {
    func snapshot() -> PermissionSnapshot
    func requestAccessibility()
}

struct SystemPermissionController: PermissionControlling {
    func snapshot() -> PermissionSnapshot {
        PermissionSnapshot(accessibilityGranted: AXIsProcessTrusted())
    }

    func requestAccessibility() {
        CodexAccessibilityInserter.requestPermission()
        openPrivacyPane("Privacy_Accessibility")
    }

    private func openPrivacyPane(_ anchor: String) {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)"
        ) else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}

protocol LoginItemManaging {
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool) throws
}

struct SystemLoginItemManager: LoginItemManaging {
    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}

@MainActor
final class AppContainer {
    static let shared = AppContainer()
    let model = CoolSkillModel()

    private init() {}
}
