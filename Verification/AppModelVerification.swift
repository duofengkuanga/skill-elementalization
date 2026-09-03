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
                    accessibilityGranted: false
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

        verifyCodexComposerAcquisitionWakesBeforeRetry()
        verifyCatalogRefreshRebuildsHistoricalUsage()
        verifyCatalogRefreshUpdatesImplicitInvocationPolicy()

        try? FileManager.default.removeItem(at: root)
        print("App model verification passed")
    }

    private static func verifyCodexComposerAcquisitionWakesBeforeRetry() {
        var events: [String] = []
        var timeouts: [TimeInterval] = []
        do {
            let composer: String = try CodexComposerAcquisition.locate(
                lookup: { timeout in
                    timeouts.append(timeout)
                    events.append(timeout == 0 ? "probe" : "retry")
                    guard timeout > 0 else {
                        throw CodexInsertionError.composerNotFocused
                    }
                    return "composer"
                },
                requestWindow: {
                    events.append("wake")
                }
            )
            precondition(composer == "composer")
            precondition(timeouts == [0, 5], "The first composer probe must not wait before waking Codex")
            precondition(
                events == ["probe", "wake", "retry"],
                "A missing composer must wake Codex before the bounded retry"
            )
        } catch {
            preconditionFailure("Composer acquisition should recover after waking Codex: \(error)")
        }
    }

    @MainActor
    private static func verifyCatalogRefreshRebuildsHistoricalUsage() {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("coolskill-catalog-usage-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let sessions = root.appendingPathComponent("sessions", isDirectory: true)
        let skillPath = root.appendingPathComponent("skills/retro/SKILL.md")
        do {
            try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
            try [
                #"{"type":"session_meta","payload":{"timestamp":"2026-09-03T10:00:00Z"}}"#,
                #"{"type":"turn_context","turn_id":"turn-1","payload":{}}"#,
                #"{"type":"response_item","payload":{"type":"custom_tool_call","input":"read \#(skillPath.path)"}}"#
            ]
            .joined(separator: "\n")
            .appending("\n")
            .write(to: sessions.appendingPathComponent("rollout.jsonl"), atomically: true, encoding: .utf8)

            let store = LocalStateStore(fileURL: root.appendingPathComponent("state.json"))
            let model = CoolSkillModel(
                catalog: SkillCatalog(roots: [
                    SkillSourceRoot(
                        url: root.appendingPathComponent("skills"),
                        kind: .sharedGlobal,
                        precedence: 1
                    )
                ]),
                store: store,
                usageReconstructor: UsageReconstructor(roots: [sessions]),
                inserter: FakeInserter(result: .failure(FakeInsertionError.rejected)),
                loginItemManager: FakeLoginItemManager(),
                permissionController: FakePermissionController(
                    value: PermissionSnapshot(accessibilityGranted: false)
                )
            )

            model.refreshUsage()
            waitForUsageRefresh(model)
            precondition(store.state.usageCursors.count == 1)

            try FileManager.default.createDirectory(
                at: skillPath.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try "---\nname: retro\ndescription: Reflect on work\n---\n"
                .write(to: skillPath, atomically: true, encoding: .utf8)
            model.refreshCatalog()
            waitForUsageRefresh(model)

            precondition(
                model.state.skills.first?.usageCount == 1,
                "Updating Skills must rebuild usage for newly discovered skills"
            )
            precondition(
                model.state.skills.first?.lastUsedAt == ISO8601DateFormatter().date(from: "2026-09-03T10:00:00Z"),
                "Updating Skills must rebuild the most recent invocation time"
            )

            let rollout = sessions.appendingPathComponent("rollout.jsonl")
            let handle = try FileHandle(forWritingTo: rollout)
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(([
                #"{"type":"turn_context","turn_id":"turn-2","timestamp":"2026-09-03T10:00:30Z","payload":{}}"#,
                #"{"type":"response_item","payload":{"type":"custom_tool_call","input":"read \#(skillPath.path)"}}"#
            ].joined(separator: "\n") + "\n").utf8))
            try handle.close()

            model.refreshUsage()
            waitForUsageRefresh(model)
            precondition(model.state.skills.first?.usageCount == 2)
            precondition(
                model.state.skills.first?.lastUsedAt == ISO8601DateFormatter().date(from: "2026-09-03T10:00:30Z"),
                "Incremental refresh must update the most recent invocation time"
            )
        } catch {
            preconditionFailure("Catalog refresh usage verification failed: \(error)")
        }
    }

    @MainActor
    private static func verifyCatalogRefreshUpdatesImplicitInvocationPolicy() {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("coolskill-implicit-policy-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let skillURL = root.appendingPathComponent("manual-only/SKILL.md")
        let policyURL = root.appendingPathComponent("manual-only/agents/openai.yaml")
        do {
            try FileManager.default.createDirectory(
                at: skillURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try """
            ---
            name: manual-only
            description: Review work
            disable-model-invocation: true
            ---
            """.write(to: skillURL, atomically: true, encoding: .utf8)

            let model = CoolSkillModel(
                catalog: SkillCatalog(roots: [
                    SkillSourceRoot(url: root, kind: .sharedGlobal, precedence: 100)
                ]),
                store: LocalStateStore(fileURL: root.appendingPathComponent("state.json")),
                usageReconstructor: UsageReconstructor(roots: []),
                inserter: FakeInserter(result: .failure(FakeInsertionError.rejected)),
                loginItemManager: FakeLoginItemManager(),
                permissionController: FakePermissionController(
                    value: PermissionSnapshot(accessibilityGranted: false)
                )
            )

            model.refreshCatalog()
            precondition(model.state.skills.first?.allowsImplicitInvocation == true)

            try FileManager.default.createDirectory(
                at: policyURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try "policy:\n  allow_implicit_invocation: false\n"
                .write(to: policyURL, atomically: true, encoding: .utf8)
            model.refreshCatalog()
            precondition(model.state.skills.first?.allowsImplicitInvocation == false)
        } catch {
            preconditionFailure("Implicit invocation policy refresh verification failed: \(error)")
        }
    }

    @MainActor
    private static func waitForUsageRefresh(_ model: CoolSkillModel) {
        let deadline = Date().addingTimeInterval(2)
        while model.isRefreshingUsage && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        precondition(!model.isRefreshingUsage, "Usage refresh did not finish")
    }
}
