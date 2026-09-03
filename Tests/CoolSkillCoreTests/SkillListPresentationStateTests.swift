import CoolSkillCore
import XCTest

final class SkillListPresentationStateTests: XCTestCase {
    func testRepeatedRevealKeepsPresentationAlive() {
        var state = SkillListPresentationState()

        XCTAssertEqual(state.reveal(), .show)
        XCTAssertEqual(state.reveal(), .show)
    }

    func testSelectionClearHidesOnlyOnce() {
        var state = SkillListPresentationState()
        _ = state.reveal()

        XCTAssertEqual(state.synchronize(hasSelection: false), .hide)
        XCTAssertNil(state.synchronize(hasSelection: false))
    }
}
