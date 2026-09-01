import Foundation

public enum FixtureSkills {
    public static let all: [Skill] = [
        Skill(
            invocationName: "browser-control",
            name: "Browser Control",
            summary: "控制浏览器完成网页任务",
            element: .wind,
            usageCount: 18
        ),
        Skill(
            invocationName: "frontend-design",
            name: "Frontend Design",
            summary: "创建具有鲜明视觉品质的界面",
            element: .fire,
            usageCount: 11
        ),
        Skill(
            invocationName: "deep-research",
            name: "Deep Research",
            summary: "研究复杂主题并整理证据",
            element: .water,
            usageCount: 7
        ),
        Skill(
            invocationName: "code-review",
            name: "Code Review",
            summary: "审查实现质量与规格一致性",
            element: .mountain,
            usageCount: 5
        )
    ]
}
