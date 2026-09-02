import Foundation

@main
struct CoreVerification {
    static func main() {
        var state = LauncherState(skills: FixtureSkills.all)
        precondition(state.selectedElement == nil)
        precondition(state.visibleSkills.isEmpty)

        state.send(.selectElement(.wind))
        precondition(state.visibleSkills.map(\.invocationName) == ["browser-control"])

        state.send(.selectElement(.water))
        precondition(state.visibleSkills.map(\.invocationName) == ["deep-research"])

        state.send(
            .recordUse(
                invocationName: "deep-research",
                at: Date(timeIntervalSince1970: 100)
            )
        )
        precondition(state.visibleSkills.first?.usageCount == 8)

        let classifier = ElementClassifier()
        precondition(classifier.classify(name: "browser-control", description: "").element == .fire)
        precondition(classifier.classify(name: "frontend-design", description: "").element == .fire)
        precondition(classifier.classify(name: "deep-research", description: "").element == .water)
        precondition(classifier.classify(name: "code-review", description: "").element == .mountain)
        precondition(classifier.classify(name: "handoff", description: "Send context").element == .wind)

        do {
            let parsed = try SkillDocumentParser().parse(contents: """
            ---
            name: deep-research
            description: >-
              Research complex topics
              with evidence.
            ---
            # Workflow
            """)
            precondition(parsed.description == "Research complex topics with evidence.")
        } catch {
            preconditionFailure("Parser verification failed: \(error)")
        }

        verifyCatalogScan()
        verifyAgentsOnlyCatalog()
        verifyLocalStateStore()
        verifyUsageReconstruction()
        verifyMalformedUsageRecord()
        verifyInsertionPlanning()
        verifyChordRecognition()
        verifyPanelPlacement()
        verifyLegacyStateMigration()
        verifyLargeCatalog()

        if CommandLine.arguments.contains("--catalog") {
            let result = SkillCatalog.defaultCatalog().scan()
            print("Catalog skills: \(result.skills.count), issues: \(result.issues.count)")
            for element in Element.allCases {
                let names = result.skills.filter { $0.element == element }.map(\.invocationName)
                print("\(element.rawValue): \(names.joined(separator: ", "))")
            }
            precondition(!result.skills.isEmpty)
        }

        if CommandLine.arguments.contains("--usage") {
            let catalog = SkillCatalog.defaultCatalog().scan()
            let result = UsageReconstructor.defaultReconstructor().scan(
                skills: catalog.skills,
                cursors: [:],
                rebuild: true
            )
            print("Usage events: \(result.events.count), issues: \(result.issues.count)")
            let incrementalStart = Date()
            let incremental = UsageReconstructor.defaultReconstructor().scan(
                skills: catalog.skills,
                cursors: result.cursors
            )
            print(
                "Incremental events: \(incremental.events.count), seconds: "
                    + String(format: "%.3f", Date().timeIntervalSince(incrementalStart))
            )
        }

        print("Core verification passed")
    }

    private static func verifyCatalogScan() {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("coolskill-verification-\(UUID().uuidString)", isDirectory: true)
        let high = root.appendingPathComponent("high/same-skill", isDirectory: true)
        let low = root.appendingPathComponent("low/same-skill", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: high, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: low, withIntermediateDirectories: true)
            try skillDocument(name: "same-skill", description: "Create a design")
                .write(to: high.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
            try skillDocument(name: "same-skill", description: "Review quality")
                .write(to: low.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
            let broken = root.appendingPathComponent("low/broken/SKILL.md")
            try FileManager.default.createDirectory(
                at: broken.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try "not frontmatter".write(to: broken, atomically: true, encoding: .utf8)
            let result = SkillCatalog(roots: [
                SkillSourceRoot(url: root.appendingPathComponent("high"), kind: .codexGlobal, precedence: 20),
                SkillSourceRoot(url: root.appendingPathComponent("low"), kind: .plugin, precedence: 10)
            ]).scan()
            precondition(result.skills.count == 1)
            precondition(result.skills.first?.element == .fire)
            precondition(result.issues.count == 1)
        } catch {
            preconditionFailure("Catalog verification failed: \(error)")
        }
        try? FileManager.default.removeItem(at: root)
    }

    private static func verifyAgentsOnlyCatalog() {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("coolskill-scope-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        do {
            for (directory, name) in [
                (".agents/skills/allowed", "allowed"),
                (".codex/skills/excluded", "excluded"),
                (".codex/plugins/cache/plugin/skills/excluded-plugin", "excluded-plugin")
            ] {
                let destination = root.appendingPathComponent(directory, isDirectory: true)
                try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
                try skillDocument(name: name, description: "Review work")
                    .write(to: destination.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
            }
            let result = SkillCatalog.defaultCatalog(
                environment: ["CODEX_HOME": root.appendingPathComponent(".codex").path],
                homeDirectory: root
            ).scan()
            precondition(result.skills.map(\.invocationName) == ["allowed"])
            precondition(result.issues.isEmpty)
        } catch {
            preconditionFailure("Agents-only catalog verification failed: \(error)")
        }
    }

    private static func skillDocument(name: String, description: String) -> String {
        """
        ---
        name: \(name)
        description: \(description)
        ---
        """
    }

    private static func verifyLocalStateStore() {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("coolskill-store-\(UUID().uuidString)", isDirectory: true)
        let file = root.appendingPathComponent("state.json")
        do {
            let store = LocalStateStore(fileURL: file)
            try store.setSelectedElement(.water)
            try store.setManualElement(.mountain, for: "retro")
            try store.setShortcut(ChordConfiguration(primaryKeyCode: 8, secondaryKeyCode: 9))
            try store.setOnboardingCompleted(true)
            let reloaded = LocalStateStore(fileURL: file)
            precondition(reloaded.state.selectedElement == .water)
            precondition(reloaded.state.skills["retro"]?.manualElement == .mountain)
            precondition(reloaded.state.shortcut.primaryKeyCode == 8)
            precondition(reloaded.state.hasCompletedOnboarding)
        } catch {
            preconditionFailure("Local store verification failed: \(error)")
        }
        try? FileManager.default.removeItem(at: root)
    }

    private static func verifyUsageReconstruction() {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("coolskill-usage-\(UUID().uuidString)", isDirectory: true)
        let sessions = root.appendingPathComponent("sessions", isDirectory: true)
        let rollout = sessions.appendingPathComponent("rollout.jsonl")
        let skillPath = root.appendingPathComponent("skills/retro/SKILL.md").path
        do {
            try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
            let lines = [
                #"{"type":"session_meta","payload":{"timestamp":"2026-08-27T08:00:00Z"}}"#,
                #"{"type":"turn_context","turn_id":"turn-1","payload":{}}"#,
                #"{"type":"event_msg","payload":{"type":"user_message","message":"$retro reflect"}}"#,
                #"{"type":"response_item","payload":{"type":"custom_tool_call","input":"read \#(skillPath)"}}"#
            ]
            try (lines.joined(separator: "\n") + "\n")
                .write(to: rollout, atomically: true, encoding: .utf8)
            let skill = Skill(
                invocationName: "retro",
                name: "retro",
                summary: "",
                element: .water,
                source: skillPath
            )
            let reconstructor = UsageReconstructor(roots: [sessions])
            let first = reconstructor.scan(skills: [skill], cursors: [:])
            precondition(first.events.count == 1)

            let handle = try FileHandle(forWritingTo: rollout)
            try handle.seekToEnd()
            try handle.write(contentsOf: Data((
                #"{"type":"turn_context","turn_id":"turn-2","payload":{}}"# + "\n" +
                #"{"type":"response_item","payload":{"type":"custom_tool_call","input":"read \#(skillPath)"}}"# + "\n"
            ).utf8))
            try handle.close()
            let second = reconstructor.scan(skills: [skill], cursors: first.cursors)
            precondition(second.events.count == 1)
            precondition(first.events.first?.id != second.events.first?.id)
        } catch {
            preconditionFailure("Usage reconstruction verification failed: \(error)")
        }
        try? FileManager.default.removeItem(at: root)
    }

    private static func verifyMalformedUsageRecord() {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("coolskill-malformed-\(UUID().uuidString)", isDirectory: true)
        let rollout = root.appendingPathComponent("rollout.jsonl")
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try "{\"type\":\"event_msg\",\"payload\":{\"type\":\"user_message\"\n"
                .write(to: rollout, atomically: true, encoding: .utf8)
            let result = UsageReconstructor(roots: [root]).scan(
                skills: FixtureSkills.all,
                cursors: [:]
            )
            precondition(result.issues.count == 1)
        } catch {
            preconditionFailure("Malformed usage verification failed: \(error)")
        }
        try? FileManager.default.removeItem(at: root)
    }

    private static func verifyInsertionPlanning() {
        do {
            let chinese = try InsertionPlanner().plan(
                currentText: "请帮我检查模块",
                selection: TextSelection(location: 3, length: 0),
                invocationName: "CodeReview"
            )
            precondition(chinese.text == "请帮我 $CodeReview 检查模块")

            let unicode = try InsertionPlanner().plan(
                currentText: "A😀B",
                selection: TextSelection(location: 3, length: 0),
                invocationName: "Retro"
            )
            precondition(unicode.text == "A😀 $Retro B")
        } catch {
            preconditionFailure("Insertion planning verification failed: \(error)")
        }
    }

    private static func verifyChordRecognition() {
        var recognizer = ChordRecognizer()
        let d = recognizer.receive(.init(key: .d, phase: .down, commandPressed: true))
        precondition(d.suppressCurrent)
        let trigger = recognizer.receive(.init(key: .p, phase: .down, commandPressed: true))
        precondition(trigger.didTrigger)

        var customRecognizer = ChordRecognizer(
            configuration: ChordConfiguration(
                primaryKeyCode: ShortcutKey.c.keyCode,
                secondaryKeyCode: ShortcutKey.v.keyCode
            )
        )
        _ = customRecognizer.receive(.init(keyCode: ShortcutKey.c.keyCode, phase: .down, commandPressed: true))
        precondition(
            customRecognizer.receive(.init(keyCode: ShortcutKey.v.keyCode, phase: .down, commandPressed: true)).didTrigger,
            "Configured shortcut must trigger for its selected key pair"
        )

        var timeoutRecognizer = ChordRecognizer()
        _ = timeoutRecognizer.receive(.init(key: .d, phase: .down, commandPressed: true))
        _ = timeoutRecognizer.receive(.init(key: .d, phase: .up, commandPressed: true))
        let timeout = timeoutRecognizer.timeout()
        precondition(timeout.replayDDown && timeout.replayDUp)
    }

    private static func verifyPanelPlacement() {
        let result = PanelPlacement.clampedOrigin(
            desired: PanelPoint(x: 900, y: 600),
            panelSize: PanelSize(width: 400, height: 480),
            visibleFrame: PanelRect(
                origin: PanelPoint(x: 100, y: 50),
                size: PanelSize(width: 900, height: 700)
            )
        )
        precondition(result == PanelPoint(x: 600, y: 270))
    }

    private static func verifyLegacyStateMigration() {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("coolskill-legacy-\(UUID().uuidString)", isDirectory: true)
        let file = root.appendingPathComponent("state.json")
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            try #"{"schemaVersion":1,"selectedElement":"water","skills":{}}"#
                .write(to: file, atomically: true, encoding: .utf8)
            let migrated = LocalStateStore(fileURL: file).state
            precondition(migrated.selectedElement == .water)
            precondition(migrated.shortcut == .commandDP)
            precondition(!migrated.hasCompletedOnboarding)

            try "{broken".write(to: file, atomically: true, encoding: .utf8)
            let recovered = LocalStateStore(fileURL: file)
            precondition(recovered.loadMessage != nil)
            precondition(recovered.state == PersistedAppState())
        } catch {
            preconditionFailure("Legacy state migration failed: \(error)")
        }
        try? FileManager.default.removeItem(at: root)
    }

    private static func verifyLargeCatalog() {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("coolskill-large-\(UUID().uuidString)", isDirectory: true)
        do {
            for index in 0..<150 {
                let directory = root.appendingPathComponent("skill-\(index)", isDirectory: true)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try skillDocument(name: "skill-\(index)", description: "Create workflow \(index)")
                    .write(
                        to: directory.appendingPathComponent("SKILL.md"),
                        atomically: true,
                        encoding: .utf8
                    )
            }
            let start = Date()
            let result = SkillCatalog(roots: [
                SkillSourceRoot(url: root, kind: .codexGlobal, precedence: 100)
            ]).scan()
            precondition(result.skills.count == 150)
            precondition(Date().timeIntervalSince(start) < 5)
        } catch {
            preconditionFailure("Large catalog verification failed: \(error)")
        }
        try? FileManager.default.removeItem(at: root)
    }
}
