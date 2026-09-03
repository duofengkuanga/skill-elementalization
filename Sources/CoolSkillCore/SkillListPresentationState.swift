public enum SkillListPresentationCommand: Equatable, Sendable {
    case show
    case hide
}

public struct SkillListPresentationState: Equatable, Sendable {
    public private(set) var isShowing = false

    public init() {}

    public mutating func reveal() -> SkillListPresentationCommand? {
        isShowing = true
        return .show
    }

    public mutating func synchronize(hasSelection: Bool) -> SkillListPresentationCommand? {
        if hasSelection {
            guard !isShowing else { return nil }
            isShowing = true
            return .show
        }
        guard isShowing else { return nil }
        isShowing = false
        return .hide
    }
}
