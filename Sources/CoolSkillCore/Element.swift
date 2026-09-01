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
}
