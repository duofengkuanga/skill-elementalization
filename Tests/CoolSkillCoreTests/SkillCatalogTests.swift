import CoolSkillCore
import Foundation
import XCTest

final class SkillCatalogTests: XCTestCase {
    func testParserReadsFoldedDescriptionAndHeadings() throws {
        let document = try SkillDocumentParser().parse(contents: """
        ---
        name: deep-research
        description: >-
          Research complex topics
          with evidence.
        ---
        # Workflow
        ## Verify sources
        """)

        XCTAssertEqual(document.name, "deep-research")
        XCTAssertEqual(document.description, "Research complex topics with evidence.")
        XCTAssertEqual(document.headings, ["Workflow", "Verify sources"])
    }

    func testParserAcceptsDocumentWithoutBody() throws {
        let document = try SkillDocumentParser().parse(contents: "---\nname: retro\ndescription: Review work\n---")

        XCTAssertEqual(document.name, "retro")
        XCTAssertTrue(document.headings.isEmpty)
    }

    func testClassifierCoversFourElementsAndFallback() {
        let classifier = ElementClassifier()

        XCTAssertEqual(classifier.classify(name: "browser-control", description: "").element, .fire)
        XCTAssertEqual(classifier.classify(name: "frontend-design", description: "").element, .fire)
        XCTAssertEqual(classifier.classify(name: "deep-research", description: "").element, .water)
        XCTAssertEqual(classifier.classify(name: "code-review", description: "").element, .mountain)

        XCTAssertEqual(classifier.classify(name: "handoff", description: "Send context to another session").element, .wind)
        XCTAssertEqual(classifier.classify(name: "investigate-bug", description: "Find the root cause").element, .water)
        XCTAssertEqual(classifier.classify(name: "generate-tests", description: "Create test code").element, .fire)
        XCTAssertEqual(classifier.classify(name: "agent-party-time-repair-bug", description: "Delegate internally, then repair the bug").element, .fire)
        XCTAssertEqual(classifier.classify(name: "run-tests", description: "Verify correctness").element, .mountain)

        let fallback = classifier.classify(name: "unknown-capability", description: "")
        XCTAssertEqual(fallback.element, .water)
        XCTAssertTrue(fallback.isLowConfidence)
    }

    func testCatalogUsesHigherPrecedenceAndReportsMalformedDocuments() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let high = root.appendingPathComponent("high", isDirectory: true)
        let low = root.appendingPathComponent("low", isDirectory: true)
        try FileManager.default.createDirectory(at: high, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: low, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try writeSkill(name: "same-skill", description: "Create a design", under: high)
        try writeSkill(name: "same-skill", description: "Review quality", under: low)
        let malformed = low.appendingPathComponent("broken/SKILL.md")
        try FileManager.default.createDirectory(
            at: malformed.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "not frontmatter".write(to: malformed, atomically: true, encoding: .utf8)

        let result = SkillCatalog(roots: [
            SkillSourceRoot(url: high, kind: .codexGlobal, precedence: 20),
            SkillSourceRoot(url: low, kind: .plugin, precedence: 10)
        ]).scan()

        XCTAssertEqual(result.skills.count, 1)
        XCTAssertEqual(result.skills.first?.element, .fire)
        XCTAssertEqual(result.skills.first?.source.contains("high"), true)
        XCTAssertEqual(result.issues.count, 1)
    }

    private func writeSkill(name: String, description: String, under root: URL) throws {
        let directory = root.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try """
        ---
        name: \(name)
        description: \(description)
        ---
        """.write(
            to: directory.appendingPathComponent("SKILL.md"),
            atomically: true,
            encoding: .utf8
        )
    }
}
