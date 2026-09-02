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
    private let responsibilityOverrides: [String: Element]

    public init(
        terms: [Element: [String]] = ElementClassifier.defaultTerms,
        responsibilityOverrides: [String: Element] = ElementClassifier.defaultResponsibilityOverrides
    ) {
        self.terms = terms
        self.responsibilityOverrides = responsibilityOverrides
    }

    public func classify(name: String, description: String, headings: [String] = []) -> ClassificationResult {
        let normalizedName = normalize(name)
        if let element = responsibilityOverrides[normalizedName] {
            return ClassificationResult(element: element, score: 100, isLowConfidence: false)
        }
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
            return ClassificationResult(element: .water, score: 0, isLowConfidence: true)
        }

        let responsibilityPriority: [Element] = [.fire, .mountain, .water, .wind]
        let winners = responsibilityPriority.filter { scores[$0] == topScore }
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
            "handoff", "delegate", "notify", "route", "sync", "coordinate", "orchestrate",
            "cross session", "multi agent", "agent party", "wake agent", "send message",
            "交接", "委派", "通知", "路由", "同步", "协调", "跨会话", "多智能体", "唤醒"
        ],
        .fire: [
            "implement", "fix", "create", "generate", "write", "build", "modify", "update",
            "refactor", "migrate", "deploy", "install", "configure", "scaffold", "edit", "design",
            "实现", "修复", "创建", "生成", "编写", "修改", "更新", "重构", "迁移", "部署",
            "安装", "配置", "搭建", "设计"
        ],
        .water: [
            "research", "investigate", "diagnose", "debug", "explore", "analyze", "understand",
            "trace", "explain", "discover", "read", "search", "summarize", "guide", "retro",
            "grill", "研究", "调查", "诊断", "调试", "探索", "分析", "理解", "追踪", "解释",
            "搜索", "汇总", "复盘", "追问"
        ],
        .mountain: [
            "review", "verify", "validate", "audit", "test", "check", "inspect", "approve",
            "quality gate", "compliance", "safety", "security", "lint", "grade", "doctor",
            "评审", "审查", "验证", "测试", "检查", "验收", "审计", "合规", "安全", "质量", "评分"
        ]
    ]

    public static let defaultResponsibilityOverrides: [String: Element] = [
        "agent party time repair bug": .fire,
        "browser control": .fire, "computer use": .fire, "deep research": .water,
        "chatgpt imagegen": .fire, "chrome use": .fire, "code review": .mountain,
        "codebase design": .water, "create skill": .fire, "diagnosing bugs": .water,
        "domain modeling": .fire, "eli5": .water, "frontend design": .fire,
        "gitnexus cli": .fire, "gitnexus debugging": .water, "gitnexus exploring": .water,
        "gitnexus guide": .water, "gitnexus impact analysis": .water,
        "gitnexus pr review": .mountain, "gitnexus refactoring": .fire,
        "grill me": .water, "grill with docs": .fire, "grilling": .water,
        "handoff": .wind, "implement": .fire, "improve codebase architecture": .water,
        "vercel react best practices": .mountain, "repo env": .water, "retro": .water,
        "show me": .water, "skill doctor": .mountain, "tdd": .fire,
        "to spec": .fire, "to tickets": .fire, "wayfinder": .fire,
        "writing for agents": .fire
    ]
}
