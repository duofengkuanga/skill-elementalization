import AppKit
import CoolSkillCore
import Foundation
import SwiftUI

private final class PreviewInserter: SkillInserting {
    func insert(invocationName: String) -> Result<InsertionPlan, Error> {
        .success(
            InsertionPlan(
                text: "$\(invocationName)",
                selection: TextSelection(location: invocationName.utf16.count + 1, length: 0),
                insertedText: "$\(invocationName)"
            )
        )
    }
}

private struct PreviewPermissions: PermissionControlling {
    func snapshot() -> PermissionSnapshot {
        PermissionSnapshot(accessibilityGranted: false)
    }

    func requestAccessibility() {}
}

private final class PreviewLoginItem: LoginItemManaging {
    var isEnabled = false
    func setEnabled(_ enabled: Bool) throws { isEnabled = enabled }
}

@main
struct RenderPreview {
    @MainActor
    static func main() throws {
        guard CommandLine.arguments.count >= 3 else {
            throw CocoaError(.fileNoSuchFile)
        }
        let output = URL(fileURLWithPath: CommandLine.arguments[1])
        let mode = CommandLine.arguments[2]
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("coolskill-preview-\(UUID().uuidString)", isDirectory: true)
        let store = LocalStateStore(fileURL: root.appendingPathComponent("state.json"))
        let rendersSkillList = mode.hasPrefix("list-")
        let model = CoolSkillModel(
            skills: mode.contains("stress") ? stressSkills : previewSkills,
            catalog: SkillCatalog(roots: []),
            store: store,
            usageReconstructor: UsageReconstructor(roots: []),
            inserter: PreviewInserter(),
            loginItemManager: PreviewLoginItem(),
            permissionController: PreviewPermissions()
        )
        if mode == "empty" {
            model.select(.mountain)
        } else if mode != "unselected" {
            model.select(.wind)
        }
        let colorScheme: ColorScheme = mode.contains("light") ? .light : .dark
        let previewSize = rendersSkillList
            ? NSSize(width: 300, height: 260)
            : NSSize(width: 840, height: 580)
        let rootView: AnyView
        if rendersSkillList {
            rootView = AnyView(
                SkillListPanelContent(model: model, onHoverChanged: { _ in })
                    .frame(width: previewSize.width, height: previewSize.height)
                    .environment(\.colorScheme, colorScheme)
            )
        } else {
            rootView = AnyView(
                CoolSkillPanel(
                    model: model,
                    reduceMotionOverride: mode == "reduce-motion" ? true : nil
                )
                .frame(width: previewSize.width, height: previewSize.height)
                .environment(\.colorScheme, colorScheme)
            )
        }
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = NSRect(origin: .zero, size: previewSize)
        hostingView.layoutSubtreeIfNeeded()

        guard let bitmap = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            throw CocoaError(.coderInvalidValue)
        }
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        guard let png = bitmap.representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try png.write(to: output, options: .atomic)
        try? FileManager.default.removeItem(at: root)
        print(output.path)
    }

    private static var previewSkills: [Skill] {
        [
            Skill(
                invocationName: "browser-control",
                name: "Browser Control",
                summary: "控制浏览器完成网页任务",
                element: .wind,
                usageCount: 18,
                lastUsedAt: Date(timeIntervalSince1970: 1_788_400_535),
                isManualInvocationOnly: true
            ),
            Skill(
                invocationName: "chrome-use",
                name: "Chrome Use",
                summary: "操作真实浏览器与网页",
                element: .wind,
                usageCount: 11,
                lastUsedAt: Date(timeIntervalSince1970: 1_788_396_923)
            ),
            Skill(
                invocationName: "computer-use",
                name: "Computer Use",
                summary: "操作本机 macOS 应用",
                element: .wind,
                usageCount: 7,
                lastUsedAt: Date(timeIntervalSince1970: 1_788_389_704),
                isManualInvocationOnly: true
            ),
            Skill(
                invocationName: "unknown-tool",
                name: "Unknown Tool",
                summary: "尚未确认元素的通用能力",
                element: .wind,
                isLowConfidence: true
            )
        ]
    }

    private static var stressSkills: [Skill] {
        [
            Skill(
                invocationName: "extremely-long-skill-name-for-layout-verification",
                name: "Extremely Long Skill Name for Layout Verification",
                summary: "这是一条非常长的 Skill 描述，用于确认内容会在单行内正确截断且不会挤压右侧累计次数。",
                element: .wind,
                usageCount: 123_456,
                lastUsedAt: Date(timeIntervalSince1970: 1_788_400_535),
                isManualInvocationOnly: true
            ),
            Skill(
                invocationName: "zero-count",
                name: "Zero Count Skill",
                summary: "零次使用不应展示数字",
                element: .wind
            )
        ]
    }
}
