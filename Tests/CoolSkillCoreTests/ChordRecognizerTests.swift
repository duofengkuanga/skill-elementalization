import CoolSkillCore
import XCTest

final class ChordRecognizerTests: XCTestCase {
    func testTriggersForCommandDThenCommandP() {
        var recognizer = ChordRecognizer()

        XCTAssertTrue(recognizer.receive(.init(key: .d, phase: .down, commandPressed: true)).suppressCurrent)
        let trigger = recognizer.receive(.init(key: .p, phase: .down, commandPressed: true))

        XCTAssertTrue(trigger.suppressCurrent)
        XCTAssertTrue(trigger.didTrigger)
        XCTAssertFalse(trigger.replayDDown)
    }

    func testTriggersForConfiguredKeyPair() {
        var recognizer = ChordRecognizer(
            configuration: ChordConfiguration(
                primaryKeyCode: ShortcutKey.c.keyCode,
                secondaryKeyCode: ShortcutKey.v.keyCode
            )
        )

        XCTAssertTrue(recognizer.receive(.init(keyCode: ShortcutKey.c.keyCode, phase: .down, commandPressed: true)).suppressCurrent)
        XCTAssertTrue(recognizer.receive(.init(keyCode: ShortcutKey.v.keyCode, phase: .down, commandPressed: true)).didTrigger)
    }

    func testTimeoutReplaysBufferedD() {
        var recognizer = ChordRecognizer()
        _ = recognizer.receive(.init(key: .d, phase: .down, commandPressed: true))
        _ = recognizer.receive(.init(key: .d, phase: .up, commandPressed: true))

        let timeout = recognizer.timeout()

        XCTAssertTrue(timeout.replayDDown)
        XCTAssertTrue(timeout.replayDUp)
        XCTAssertFalse(timeout.didTrigger)
    }

    func testUnrelatedKeyFlushesDAndPassesCurrentEvent() {
        var recognizer = ChordRecognizer()
        _ = recognizer.receive(.init(key: .d, phase: .down, commandPressed: true))

        let decision = recognizer.receive(.init(key: .other, phase: .down, commandPressed: true))

        XCTAssertFalse(decision.suppressCurrent)
        XCTAssertTrue(decision.replayDDown)
    }

    func testConsumesBothKeyUpsAfterTrigger() {
        var recognizer = ChordRecognizer()
        _ = recognizer.receive(.init(key: .d, phase: .down, commandPressed: true))
        _ = recognizer.receive(.init(key: .p, phase: .down, commandPressed: true))

        XCTAssertTrue(recognizer.receive(.init(key: .d, phase: .up, commandPressed: true)).suppressCurrent)
        XCTAssertTrue(recognizer.receive(.init(key: .p, phase: .up, commandPressed: true)).suppressCurrent)
    }
}
