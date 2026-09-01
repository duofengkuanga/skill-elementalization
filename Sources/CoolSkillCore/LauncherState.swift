import Foundation

public enum LauncherAction: Equatable, Sendable {
    case selectElement(Element)
    case clearElement
    case replaceSkills([Skill])
    case moveSkill(invocationName: String, to: Element, isManual: Bool)
    case recordUse(invocationName: String, at: Date)
}

public struct LauncherState: Equatable, Sendable {
    public private(set) var selectedElement: Element?
    public private(set) var skills: [Skill]

    public init(selectedElement: Element? = nil, skills: [Skill] = []) {
        self.selectedElement = selectedElement
        self.skills = skills
    }

    public var visibleSkills: [Skill] {
        guard let selectedElement else { return [] }
        return skills
            .filter { $0.element == selectedElement }
            .sorted {
                if $0.usageCount != $1.usageCount { return $0.usageCount > $1.usageCount }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    public mutating func send(_ action: LauncherAction) {
        switch action {
        case let .selectElement(element):
            selectedElement = element
        case .clearElement:
            selectedElement = nil
        case let .replaceSkills(skills):
            self.skills = skills
        case let .moveSkill(invocationName, element, isManual):
            guard let index = skills.firstIndex(where: { $0.invocationName == invocationName }) else {
                return
            }
            skills[index].element = element
            skills[index].isManualElement = isManual
        case let .recordUse(invocationName, date):
            guard let index = skills.firstIndex(where: { $0.invocationName == invocationName }) else {
                return
            }
            skills[index].usageCount += 1
            skills[index].lastUsedAt = date
        }
    }
}
