import CoolSkillCore
import XCTest

final class InsertionPlannerTests: XCTestCase {
    func testPlacesCursorImmediatelyAfterSkillForEmptyComposer() throws {
        let plan = try InsertionPlanner().plan(
            currentText: "",
            selection: TextSelection(location: 0, length: 0),
            invocationName: "Wayfinder"
        )

        XCTAssertEqual(plan.text, "/Wayfinder")
        XCTAssertEqual(plan.insertedText, "/Wayfinder")
        XCTAssertEqual(plan.selection, TextSelection(location: 10, length: 0))
    }

    func testInsertsAtCursorWithoutOverwritingText() throws {
        let plan = try InsertionPlanner().plan(
            currentText: "请帮我检查模块",
            selection: TextSelection(location: 3, length: 0),
            invocationName: "CodeReview"
        )

        XCTAssertEqual(plan.text, "请帮我 /CodeReview 检查模块")
        XCTAssertEqual(plan.selection.length, 0)
    }

    func testPreservesSelectedTextByInsertingBeforeIt() throws {
        let plan = try InsertionPlanner().plan(
            currentText: "review this",
            selection: TextSelection(location: 7, length: 4),
            invocationName: "Retro"
        )

        XCTAssertEqual(plan.text, "review /Retro this")
        XCTAssertTrue(plan.text.contains("this"))
    }

    func testAvoidsDuplicateWhitespace() throws {
        let plan = try InsertionPlanner().plan(
            currentText: "hello  world",
            selection: TextSelection(location: 6, length: 0),
            invocationName: "Retro"
        )

        XCTAssertEqual(plan.text, "hello /Retro world")
    }

    func testSupportsUnicodeUTF16Selection() throws {
        let plan = try InsertionPlanner().plan(
            currentText: "A😀B",
            selection: TextSelection(location: 3, length: 0),
            invocationName: "Retro"
        )

        XCTAssertEqual(plan.text, "A😀 /Retro B")
    }
}
