import CoolSkillCore
import XCTest

final class PanelPlacementTests: XCTestCase {
    func testClampsPanelToEveryScreenEdge() {
        let visible = PanelRect(
            origin: PanelPoint(x: 100, y: 50),
            size: PanelSize(width: 900, height: 700)
        )
        let panel = PanelSize(width: 400, height: 480)

        XCTAssertEqual(
            PanelPlacement.clampedOrigin(
                desired: PanelPoint(x: -50, y: -50),
                panelSize: panel,
                visibleFrame: visible
            ),
            PanelPoint(x: 100, y: 50)
        )
        XCTAssertEqual(
            PanelPlacement.clampedOrigin(
                desired: PanelPoint(x: 900, y: 600),
                panelSize: panel,
                visibleFrame: visible
            ),
            PanelPoint(x: 600, y: 270)
        )
    }
}
