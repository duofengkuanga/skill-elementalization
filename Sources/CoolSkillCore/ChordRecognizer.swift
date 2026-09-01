import Foundation

public struct ChordConfiguration: Codable, Equatable, Sendable {
    public var primaryKeyCode: Int64
    public var secondaryKeyCode: Int64
    public var windowMilliseconds: Int

    public init(
        primaryKeyCode: Int64 = 2,
        secondaryKeyCode: Int64 = 35,
        windowMilliseconds: Int = 150
    ) {
        self.primaryKeyCode = primaryKeyCode
        self.secondaryKeyCode = secondaryKeyCode
        self.windowMilliseconds = windowMilliseconds
    }

    public static let commandDP = ChordConfiguration()
}

public enum ShortcutKey: String, CaseIterable, Codable, Identifiable, Sendable {
    case a, b, c, d, e, f, g, h, i, j, k, l, m
    case n, o, p, q, r, s, t, u, v, w, x, y, z

    public var id: String { rawValue }
    public var displayName: String { rawValue.uppercased() }

    public var keyCode: Int64 {
        switch self {
        case .a: return 0
        case .b: return 11
        case .c: return 8
        case .d: return 2
        case .e: return 14
        case .f: return 3
        case .g: return 5
        case .h: return 4
        case .i: return 34
        case .j: return 38
        case .k: return 40
        case .l: return 37
        case .m: return 46
        case .n: return 45
        case .o: return 31
        case .p: return 35
        case .q: return 12
        case .r: return 15
        case .s: return 1
        case .t: return 17
        case .u: return 32
        case .v: return 9
        case .w: return 13
        case .x: return 7
        case .y: return 16
        case .z: return 6
        }
    }

    public init?(keyCode: Int64) {
        guard let key = Self.allCases.first(where: { $0.keyCode == keyCode }) else { return nil }
        self = key
    }
}

public enum ChordKey: Equatable, Sendable {
    case d
    case p
    case other
}

public enum ChordKeyPhase: Equatable, Sendable {
    case down
    case up
}

public struct ChordInput: Equatable, Sendable {
    public let key: ChordKey
    public let keyCode: Int64?
    public let phase: ChordKeyPhase
    public let commandPressed: Bool

    public init(key: ChordKey, phase: ChordKeyPhase, commandPressed: Bool) {
        self.key = key
        switch key {
        case .d: keyCode = ShortcutKey.d.keyCode
        case .p: keyCode = ShortcutKey.p.keyCode
        case .other: keyCode = nil
        }
        self.phase = phase
        self.commandPressed = commandPressed
    }

    public init(keyCode: Int64, phase: ChordKeyPhase, commandPressed: Bool) {
        self.keyCode = keyCode
        switch keyCode {
        case ShortcutKey.d.keyCode: key = .d
        case ShortcutKey.p.keyCode: key = .p
        default: key = .other
        }
        self.phase = phase
        self.commandPressed = commandPressed
    }
}

public struct ChordDecision: Equatable, Sendable {
    public let suppressCurrent: Bool
    public let replayDDown: Bool
    public let replayDUp: Bool
    public let didTrigger: Bool

    public init(
        suppressCurrent: Bool = false,
        replayDDown: Bool = false,
        replayDUp: Bool = false,
        didTrigger: Bool = false
    ) {
        self.suppressCurrent = suppressCurrent
        self.replayDDown = replayDDown
        self.replayDUp = replayDUp
        self.didTrigger = didTrigger
    }
}

public struct ChordRecognizer: Sendable {
    public private(set) var isWaitingForP = false
    private let configuration: ChordConfiguration
    private var receivedDUp = false
    private var consumesDUp = false
    private var consumesPUp = false

    public init(configuration: ChordConfiguration = .commandDP) {
        self.configuration = configuration
    }

    public mutating func receive(_ input: ChordInput) -> ChordDecision {
        let isPrimary = input.keyCode == configuration.primaryKeyCode
        let isSecondary = input.keyCode == configuration.secondaryKeyCode

        if isSecondary, input.phase == .up, consumesPUp {
            consumesPUp = false
            return ChordDecision(suppressCurrent: true)
        }
        if isPrimary, input.phase == .up, consumesDUp {
            consumesDUp = false
            return ChordDecision(suppressCurrent: true)
        }

        if isPrimary, input.phase == .down, input.commandPressed, !isWaitingForP {
            isWaitingForP = true
            receivedDUp = false
            return ChordDecision(suppressCurrent: true)
        }

        guard isWaitingForP else {
            return ChordDecision()
        }

        if isPrimary, input.phase == .up {
            receivedDUp = true
            return ChordDecision(suppressCurrent: true)
        }

        if isSecondary, input.phase == .down, input.commandPressed {
            consumesDUp = !receivedDUp
            isWaitingForP = false
            receivedDUp = false
            consumesPUp = true
            return ChordDecision(suppressCurrent: true, didTrigger: true)
        }

        let decision = ChordDecision(replayDDown: true, replayDUp: receivedDUp)
        isWaitingForP = false
        receivedDUp = false
        return decision
    }

    public mutating func timeout() -> ChordDecision {
        guard isWaitingForP else { return ChordDecision() }
        let decision = ChordDecision(replayDDown: true, replayDUp: receivedDUp)
        isWaitingForP = false
        receivedDUp = false
        return decision
    }
}
