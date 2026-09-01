import CoolSkillCore
import Foundation
import XCTest

final class UsageReconstructorTests: XCTestCase {
    func testExplicitAndLoadEvidenceDeduplicateWithinTurn() throws {
        let fixture = try UsageFixture()
        defer { fixture.cleanup() }
        try fixture.write([
            fixture.sessionMeta,
            fixture.turn("turn-1"),
            fixture.userMessage("$retro reflect"),
            fixture.toolLoad
        ])

        let result = fixture.reconstructor.scan(skills: [fixture.skill], cursors: [:])

        XCTAssertEqual(result.events.count, 1)
        XCTAssertEqual(result.events.first?.invocationName, "retro")
    }

    func testIncrementalCursorReturnsOnlyAppendedTurns() throws {
        let fixture = try UsageFixture()
        defer { fixture.cleanup() }
        try fixture.write([
            fixture.sessionMeta,
            fixture.turn("turn-1"),
            fixture.toolLoad
        ])
        let first = fixture.reconstructor.scan(skills: [fixture.skill], cursors: [:])
        try fixture.append([
            fixture.turn("turn-2"),
            fixture.toolLoad
        ])

        let second = fixture.reconstructor.scan(skills: [fixture.skill], cursors: first.cursors)

        XCTAssertEqual(first.events.count, 1)
        XCTAssertEqual(second.events.count, 1)
        XCTAssertNotEqual(first.events.first?.id, second.events.first?.id)
    }
}

private final class UsageFixture {
    let root: URL
    let rollout: URL
    let skillPath: String
    let skill: Skill
    let reconstructor: UsageReconstructor

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        rollout = root.appendingPathComponent("sessions/rollout.jsonl")
        skillPath = root.appendingPathComponent("skills/retro/SKILL.md").path
        skill = Skill(
            invocationName: "retro",
            name: "retro",
            summary: "",
            element: .water,
            source: skillPath
        )
        reconstructor = UsageReconstructor(roots: [root.appendingPathComponent("sessions")])
        try FileManager.default.createDirectory(
            at: rollout.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }

    var sessionMeta: String {
        #"{"type":"session_meta","payload":{"timestamp":"2026-08-27T08:00:00Z"}}"#
    }

    func turn(_ id: String) -> String {
        #"{"type":"turn_context","turn_id":"\#(id)","payload":{}}"#
    }

    func userMessage(_ message: String) -> String {
        #"{"type":"event_msg","payload":{"type":"user_message","message":"\#(message)"}}"#
    }

    var toolLoad: String {
        #"{"type":"response_item","payload":{"type":"custom_tool_call","input":"read \#(skillPath)"}}"#
    }

    func write(_ lines: [String]) throws {
        try (lines.joined(separator: "\n") + "\n")
            .write(to: rollout, atomically: true, encoding: .utf8)
    }

    func append(_ lines: [String]) throws {
        let handle = try FileHandle(forWritingTo: rollout)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data((lines.joined(separator: "\n") + "\n").utf8))
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: root)
    }
}
