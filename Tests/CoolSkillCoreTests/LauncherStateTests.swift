import CoolSkillCore
import XCTest

final class LauncherStateTests: XCTestCase {
    func testStartsWithoutElementAndFiltersAfterSelection() {
        var state = LauncherState(skills: FixtureSkills.all)

        XCTAssertNil(state.selectedElement)
        XCTAssertTrue(state.visibleSkills.isEmpty)

        state.send(.selectElement(.wind))
        XCTAssertEqual(state.visibleSkills.map(\.invocationName), ["browser-control"])

        state.send(.selectElement(.water))

        XCTAssertEqual(state.visibleSkills.map(\.invocationName), ["deep-research"])
    }

    func testRecordsUseAndSortsHighestUsageFirst() {
        let older = Skill(
            invocationName: "older",
            name: "Older",
            summary: "",
            element: .wind,
            usageCount: 3,
            lastUsedAt: Date(timeIntervalSince1970: 10)
        )
        let fresh = Skill(
            invocationName: "fresh",
            name: "Fresh",
            summary: "",
            element: .wind
        )
        var state = LauncherState(selectedElement: .wind, skills: [older, fresh])

        state.send(.recordUse(invocationName: "fresh", at: Date(timeIntervalSince1970: 20)))

        XCTAssertEqual(state.visibleSkills.map(\.invocationName), ["older", "fresh"])
        XCTAssertEqual(state.visibleSkills.first?.usageCount, 3)
    }

    func testUnknownUseDoesNotMutateState() {
        var state = LauncherState(skills: FixtureSkills.all)
        let original = state

        state.send(.recordUse(invocationName: "missing", at: Date()))

        XCTAssertEqual(state, original)
    }
}
