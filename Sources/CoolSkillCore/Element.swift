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
        case .wind: return "快速探索和连接工具；收录浏览、检索与轻量操作。"
        case .fire: return "创造并推动变化；收录设计、实现与强力追问。"
        case .water: return "理解问题并深入分析；收录研究、诊断与解释。"
        case .mountain: return "守住结构和质量；收录评审、规范与安全改造。"
        }
    }
}
