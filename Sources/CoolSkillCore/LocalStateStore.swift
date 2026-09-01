import Foundation

public struct PersistedSkillState: Codable, Equatable, Sendable {
    public var manualElement: Element?
    public var usageCount: Int
    public var lastUsedAt: Date?

    public init(
        manualElement: Element? = nil,
        usageCount: Int = 0,
        lastUsedAt: Date? = nil
    ) {
        self.manualElement = manualElement
        self.usageCount = usageCount
        self.lastUsedAt = lastUsedAt
    }
}

public struct PersistedAppState: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var selectedElement: Element
    public var skills: [String: PersistedSkillState]
    public var usageCursors: [String: UInt64]
    public var usageEventIDs: Set<String>
    public var shortcut: ChordConfiguration
    public var launchAtLogin: Bool
    public var hasCompletedOnboarding: Bool

    public init(
        schemaVersion: Int = 1,
        selectedElement: Element = .wind,
        skills: [String: PersistedSkillState] = [:],
        usageCursors: [String: UInt64] = [:],
        usageEventIDs: Set<String> = [],
        shortcut: ChordConfiguration = .commandDP,
        launchAtLogin: Bool = false,
        hasCompletedOnboarding: Bool = false
    ) {
        self.schemaVersion = schemaVersion
        self.selectedElement = selectedElement
        self.skills = skills
        self.usageCursors = usageCursors
        self.usageEventIDs = usageEventIDs
        self.shortcut = shortcut
        self.launchAtLogin = launchAtLogin
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case selectedElement
        case skills
        case usageCursors
        case usageEventIDs
        case shortcut
        case launchAtLogin
        case hasCompletedOnboarding
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        selectedElement = try container.decodeIfPresent(Element.self, forKey: .selectedElement) ?? .wind
        skills = try container.decodeIfPresent([String: PersistedSkillState].self, forKey: .skills) ?? [:]
        usageCursors = try container.decodeIfPresent([String: UInt64].self, forKey: .usageCursors) ?? [:]
        usageEventIDs = try container.decodeIfPresent(Set<String>.self, forKey: .usageEventIDs) ?? []
        shortcut = try container.decodeIfPresent(ChordConfiguration.self, forKey: .shortcut) ?? .commandDP
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
    }
}

public final class LocalStateStore {
    public let fileURL: URL
    public private(set) var state: PersistedAppState
    public private(set) var loadMessage: String?

    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        fileURL: URL = LocalStateStore.defaultFileURL(),
        fileManager: FileManager = .default
    ) {
        self.fileURL = fileURL
        self.fileManager = fileManager
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        state = PersistedAppState()
        if fileManager.fileExists(atPath: fileURL.path) {
            do {
                let data = try Data(contentsOf: fileURL)
                state = try decoder.decode(PersistedAppState.self, from: data)
            } catch {
                loadMessage = "CoolSkill 本地状态损坏，已使用安全默认值：\(error.localizedDescription)"
            }
        }
    }

    public static func defaultFileURL(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> URL {
        homeDirectory
            .appendingPathComponent("Library/Application Support/CoolSkill", isDirectory: true)
            .appendingPathComponent("state.json")
    }

    public func setSelectedElement(_ element: Element) throws {
        state.selectedElement = element
        try persist()
    }

    public func setManualElement(_ element: Element, for invocationName: String) throws {
        var skillState = state.skills[invocationName] ?? PersistedSkillState()
        skillState.manualElement = element
        state.skills[invocationName] = skillState
        try persist()
    }

    public func setShortcut(_ shortcut: ChordConfiguration) throws {
        state.shortcut = shortcut
        try persist()
    }

    public func setLaunchAtLogin(_ enabled: Bool) throws {
        state.launchAtLogin = enabled
        try persist()
    }

    public func setOnboardingCompleted(_ completed: Bool) throws {
        state.hasCompletedOnboarding = completed
        try persist()
    }

    public func recordUsage(
        invocationName: String,
        count: Int = 1,
        at date: Date
    ) throws {
        var skillState = state.skills[invocationName] ?? PersistedSkillState()
        skillState.usageCount += count
        if skillState.lastUsedAt == nil || skillState.lastUsedAt! < date {
            skillState.lastUsedAt = date
        }
        state.skills[invocationName] = skillState
        try persist()
    }

    public func replaceState(_ state: PersistedAppState) throws {
        self.state = state
        loadMessage = nil
        try persist()
    }

    public func applyUsageScan(_ result: UsageScanResult, rebuild: Bool) throws {
        if rebuild {
            state.skills = state.skills.mapValues { saved in
                PersistedSkillState(manualElement: saved.manualElement)
            }
            state.usageCursors = [:]
            state.usageEventIDs = []
        }

        for event in result.events where state.usageEventIDs.insert(event.id).inserted {
            var saved = state.skills[event.invocationName] ?? PersistedSkillState()
            saved.usageCount += 1
            if saved.lastUsedAt == nil || saved.lastUsedAt! < event.occurredAt {
                saved.lastUsedAt = event.occurredAt
            }
            state.skills[event.invocationName] = saved
        }
        state.usageCursors = result.cursors
        try persist()
    }

    public func removeAll() throws {
        state = PersistedAppState()
        loadMessage = nil
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }

    private func persist() throws {
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(state)
        try data.write(to: fileURL, options: .atomic)
    }
}
