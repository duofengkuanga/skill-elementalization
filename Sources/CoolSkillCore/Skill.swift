import Foundation

public struct Skill: Codable, Hashable, Identifiable, Sendable {
    public let invocationName: String
    public var name: String
    public var summary: String
    public var element: Element
    public var source: String
    public var usageCount: Int
    public var lastUsedAt: Date?
    public var isLowConfidence: Bool
    public var isManualElement: Bool

    public var id: String { invocationName }

    public var commandName: String {
        let words = name.split { !$0.isLetter && !$0.isNumber }
        let command = words.map { word in
            word.prefix(1).uppercased() + word.dropFirst()
        }.joined()
        return command.isEmpty ? invocationName : command
    }

    public init(
        invocationName: String,
        name: String,
        summary: String,
        element: Element,
        source: String = "fixture",
        usageCount: Int = 0,
        lastUsedAt: Date? = nil,
        isLowConfidence: Bool = false,
        isManualElement: Bool = false
    ) {
        self.invocationName = invocationName
        self.name = name
        self.summary = summary
        self.element = element
        self.source = source
        self.usageCount = usageCount
        self.lastUsedAt = lastUsedAt
        self.isLowConfidence = isLowConfidence
        self.isManualElement = isManualElement
    }
}
