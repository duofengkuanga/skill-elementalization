import CoolSkillCore
import Foundation

private enum FakeInsertionError: Error {
    case rejected
}

private final class FakeInserter: SkillInserting {
    var result: Result<InsertionPlan, Error>

    init(result: Result<InsertionPlan, Error>) {
        self.result = result
    }

    func insert(invocationName: String) -> Result<InsertionPlan, Error> {
        result
    }
}

private final class FakeLoginItemManager: LoginItemManaging {
    var isEnabled = false

    func setEnabled(_ enabled: Bool) throws {
        isEnabled = enabled
    }
}

private struct FakePermissionController: PermissionControlling {
    let value: PermissionSnapshot

    func snapshot() -> PermissionSnapshot { value }
    func requestAccessibility() {}
    func requestInputMonitoring() {}
}

@main
struct AppModelVerification {
    @MainActor
    static func main() {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("coolskill-model-\(UUID().uuidString)", isDirectory: true)
        let store = LocalStateStore(fileURL: root.appendingPathComponent("state.json"))
        let successPlan = InsertionPlan(
            text: "$Retro",
            selection: TextSelection(location: 6, length: 0),
            insertedText: "$Retro"
        )
        let inserter = FakeInserter(result: .success(successPlan))
        let loginManager = FakeLoginItemManager()
        let model = CoolSkillModel(
            skills: FixtureSkills.all,
            catalog: SkillCatalog(roots: []),
            store: store,
            usageReconstructor: UsageReconstructor(roots: []),
            inserter: inserter,
            loginItemManager: loginManager,
            permissionController: FakePermissionController(
                value: PermissionSnapshot(
                    accessibilityGranted: false,
                    inputMonitoringGranted: false
                )
            )
        )

        precondition(model.selectedElement == nil)
        precondition(model.visibleSkills.isEmpty)
        model.select(.water)
        precondition(!model.isKeyboardSelected(FixtureSkills.all[2]))
        model.moveSkill("deep-research", to: .mountain)
        precondition(model.selectedElement == .water)
        precondition(store.state.skills["deep-research"]?.manualElement == .mountain)

        var changedShortcut: ChordConfiguration?
        model.onShortcutChanged = { changedShortcut = $0 }
        model.setShortcut(primary: .c, secondary: .v)
        precondition(changedShortcut?.primaryKeyCode == ShortcutKey.c.keyCode)

        model.setLaunchAtLogin(true)
        precondition(loginManager.isEnabled)
        precondition(model.launchAtLogin)

        model.completeOnboarding()
        precondition(model.hasCompletedOnboarding)
        precondition(model.invoke(FixtureSkills.all[0]))

        inserter.result = .failure(FakeInsertionError.rejected)
        precondition(!model.invoke(FixtureSkills.all[0]))
        precondition(model.insertionMessage != nil)
        model.dismissInsertionMessage()
        precondition(model.insertionMessage == nil)

        model.prepareForPresentation()
        precondition(model.selectedElement == nil)
        precondition(model.state.skills.isEmpty, "An empty agents directory must clear the catalog")

        try? FileManager.default.removeItem(at: root)
        print("App model verification passed")
    }
}
