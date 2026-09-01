import CoolSkillCore
import Foundation
import XCTest

final class LocalStateStoreTests: XCTestCase {
    func testManualElementAndSelectedElementSurviveReload() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let file = root.appendingPathComponent("state.json")
        defer { try? FileManager.default.removeItem(at: root) }

        let store = LocalStateStore(fileURL: file)
        try store.setSelectedElement(.water)
        try store.setManualElement(.mountain, for: "retro")

        let reloaded = LocalStateStore(fileURL: file)
        XCTAssertEqual(reloaded.state.selectedElement, .water)
        XCTAssertEqual(reloaded.state.skills["retro"]?.manualElement, .mountain)
    }

    func testUsageFieldsCoexistWithManualElement() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let file = root.appendingPathComponent("state.json")
        defer { try? FileManager.default.removeItem(at: root) }

        let store = LocalStateStore(fileURL: file)
        try store.setManualElement(.fire, for: "retro")
        try store.recordUsage(invocationName: "retro", count: 2, at: Date(timeIntervalSince1970: 10))

        XCTAssertEqual(store.state.skills["retro"]?.manualElement, .fire)
        XCTAssertEqual(store.state.skills["retro"]?.usageCount, 2)
    }
}
