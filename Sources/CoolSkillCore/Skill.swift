import Foundation

public struct Skill: Codable, Hashable, Identifiable, Sendable {
    public let invocationName: String
    public var name: String
    public var summary: String
    public var element: Element
    public var source: String
    public var usageCount: Int
    public var lastUsedAt: Date?
    public var isManualInvocationOnly: Bool
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

    public var chineseSummary: String {
        let summaries: [String: String] = [
            "chatgpt-imagegen": "用文字生成图片或简单循环动画。",
            "chrome-use": "操控真实浏览器完成搜索、阅读和网页操作。",
            "code-review": "按规范和需求检查代码改动是否可靠。",
            "codebase-design": "帮助设计边界清晰、容易维护的代码模块。",
            "create-skill": "创建结构规范、可直接使用的新 Skill。",
            "diagnosing-bugs": "用可重复验证的步骤定位复杂故障。",
            "domain-modeling": "统一业务概念和术语，减少理解偏差。",
            "eli5": "把复杂内容讲成人人看得懂的简单说明。",
            "frontend-design": "设计并实现有辨识度的高质量界面。",
            "gitnexus-cli": "运行 GitNexus 的索引、状态和知识库命令。",
            "gitnexus-debugging": "沿代码关系追踪故障来源和调用路径。",
            "gitnexus-exploring": "快速理解陌生代码的结构和运行流程。",
            "gitnexus-guide": "说明 GitNexus 的能力、图谱和使用方法。",
            "gitnexus-impact-analysis": "评估代码改动会影响哪些功能和模块。",
            "gitnexus-pr-review": "分析合并请求的改动、风险和测试缺口。",
            "gitnexus-refactoring": "借助代码关系安全地重命名或重构。",
            "grill-me": "连续追问，把模糊想法打磨成清晰方案。",
            "grill-with-docs": "边追问边沉淀决策、术语和设计文档。",
            "grilling": "用高强度追问检验计划中的薄弱点。",
            "handoff": "把当前工作压缩成别人能接手的交接说明。",
            "implement": "按照规格或任务清单完成具体开发。",
            "improve-codebase-architecture": "发现架构问题并提出可落地的改进方向。",
            "vercel-react-best-practices": "按 Vercel 建议优化 React 和 Next.js 性能。",
            "repo-env": "记录仓库工具链和验证命令，减少环境踩坑。",
            "retro": "复盘一次开发过程并总结可改进之处。",
            "show-me": "用图形和简短示例把问题直观展示出来。",
            "skill-doctor": "评估已安装 Skill 的效果并提出改进建议。",
            "tdd": "先写测试，再用红绿重构完成开发。",
            "to-spec": "把当前讨论整理成可执行的本地规格。",
            "to-tickets": "把方案拆成有依赖关系的小任务。",
            "wayfinder": "把大型工作拆成可逐步推进的路线图。",
            "writing-for-agents": "编写让智能体容易理解和执行的文档。"
        ]
        return summaries[invocationName] ?? "用于完成“\(name)”相关任务的专用助手。"
    }

    public init(
        invocationName: String,
        name: String,
        summary: String,
        element: Element,
        source: String = "fixture",
        usageCount: Int = 0,
        lastUsedAt: Date? = nil,
        isManualInvocationOnly: Bool = false,
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
        self.isManualInvocationOnly = isManualInvocationOnly
        self.isLowConfidence = isLowConfidence
        self.isManualElement = isManualElement
    }
}
