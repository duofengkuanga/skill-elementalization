import Foundation

public struct ClassificationResult: Equatable, Sendable {
    public let element: Element
    public let score: Int
    public let isLowConfidence: Bool

    public init(element: Element, score: Int, isLowConfidence: Bool) {
        self.element = element
        self.score = score
        self.isLowConfidence = isLowConfidence
    }
}

public struct ElementClassifier: Sendable {
    private let terms: [Element: [String]]

    public init(terms: [Element: [String]] = ElementClassifier.defaultTerms) {
        self.terms = terms
    }

    public func classify(name: String, description: String, headings: [String] = []) -> ClassificationResult {
        let normalizedName = normalize(name)
        let normalizedDescription = normalize(description)
        let normalizedHeadings = normalize(headings.joined(separator: " "))
        var scores = Dictionary(uniqueKeysWithValues: Element.allCases.map { ($0, 0) })

        for element in Element.allCases {
            for rawTerm in terms[element, default: []] {
                let term = normalize(rawTerm)
                guard !term.isEmpty else { continue }
                let phraseBonus = max(0, term.split(separator: " ").count - 1)
                if normalizedName.contains(term) {
                    scores[element, default: 0] += 8 + phraseBonus
                }
                if normalizedDescription.contains(term) {
                    scores[element, default: 0] += 3 + phraseBonus
                }
                if normalizedHeadings.contains(term) {
                    scores[element, default: 0] += 1 + phraseBonus
                }
            }
        }

        let topScore = scores.values.max() ?? 0
        guard topScore > 0 else {
            return ClassificationResult(element: .wind, score: 0, isLowConfidence: true)
        }

        let winners = Element.allCases.filter { scores[$0] == topScore }
        return ClassificationResult(
            element: winners.first ?? .wind,
            score: topScore,
            isLowConfidence: winners.count > 1
        )
    }

    private func normalize(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .lowercased()
    }

    public static let defaultTerms: [Element: [String]] = [
        .wind: [
            "browser control", "computer use", "automation", "automate", "navigate",
            "connect", "integration", "install", "deploy", "publish", "manage", "control",
            "workflow", "orchestrate", "浏览器", "自动化", "操作", "连接", "导航", "安装",
            "部署", "发布", "管理", "工作流"
        ],
        .fire: [
            "frontend design", "image generation", "generate", "create", "build", "compose",
            "design", "draw", "write", "author", "transform", "scaffold", "presentation",
            "创造", "生成", "创建", "设计", "绘制", "写作", "制作", "搭建", "改造", "脚手架"
        ],
        .water: [
            "deep research", "diagnose", "debug", "explore", "investigate", "research",
            "analyze", "understand", "trace", "explain", "discover", "read", "inspect",
            "研究", "诊断", "调试", "探索", "调查", "分析", "理解", "追踪", "解释", "发现"
        ],
        .mountain: [
            "code review", "impact analysis", "quality gate", "review", "verify", "validate",
            "test", "audit", "guard", "standard", "compliance", "safety", "check", "lint",
            "评审", "审查", "验证", "测试", "检查", "守护", "规范", "合规", "安全", "质量"
        ]
    ]
}
