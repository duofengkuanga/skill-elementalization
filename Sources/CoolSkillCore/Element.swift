import Foundation

public enum Element: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case wind
    case fire
    case water
    case mountain

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .wind: return "风"
        case .fire: return "火"
        case .water: return "水"
        case .mountain: return "山"
        }
    }

    public var chineseDefinition: String {
        switch self {
        case .wind: return "风 · 协作"
        case .fire: return "火 · 行动"
        case .water: return "水 · 洞察"
        case .mountain: return "山 · 守序"
        }
    }
}
