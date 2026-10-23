import AppKit
import CoolSkillCore
import SwiftUI
import UniformTypeIdentifiers

struct CoolSkillPanel: View {
    @ObservedObject var model: CoolSkillModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var elementOrder = Element.allCases
    @State private var rightDragOriginOrder: [Element]?

    var body: some View {
        HStack(spacing: 0) {
            sidebar
                .frame(width: 210)
            Divider()
            SkillListPanelContent(model: model)
        }
        .background(AppTheme.canvas(for: colorScheme))
        .foregroundStyle(AppTheme.ink(for: colorScheme))
        .tint(AppTheme.accent(for: colorScheme))
        .sheet(
            isPresented: Binding(
                get: { model.isSettingsPresented },
                set: { if !$0 { model.closeSettings() } }
            )
        ) {
            SettingsSheet(model: model)
        }
        .alert(
            "无法插入 Skill",
            isPresented: Binding(
                get: { model.insertionMessage != nil },
                set: { if !$0 { model.dismissInsertionMessage() } }
            )
        ) {
            Button("好", role: .cancel) { model.dismissInsertionMessage() }
        } message: {
            Text(model.insertionMessage ?? "")
        }
        .task {
            model.loadInitialCatalogIfNeeded()
        }
        .task {
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 30_000_000_000)
                } catch { return }
                guard !Task.isCancelled else { return }
                model.refreshUsage()
            }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                BrandMark()
                    .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 4) {
                    Text("kcoisga")
                        .font(.system(size: 22, weight: .bold))
                    Text("你的 Skill 工作台")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 26)
            .padding(.bottom, 32)

            Text("技能库")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 22)
                .padding(.bottom, 10)

            VStack(spacing: 4) {
                ForEach(elementOrder) { element in
                    ElementButton(
                        element: element,
                        isSelected: model.selectedElement == element,
                        color: model.selectedElement == element
                            ? AppTheme.accent(for: colorScheme)
                            : element.color(for: colorScheme),
                        count: model.skillCount(for: element),
                        action: { model.select(element) }
                    )
                    .onDrag { NSItemProvider(object: NSString(string: element.rawValue)) }
                    .onDrop(of: [UTType.plainText], isTargeted: nil) { providers in
                        guard let provider = providers.first else { return false }
                        provider.loadObject(ofClass: NSString.self) { object, _ in
                            guard let value = object as? String else { return }
                            Task { @MainActor in
                                if let draggedElement = Element(rawValue: value) {
                                    move(draggedElement, before: element)
                                } else {
                                    model.moveSkill(value, to: element)
                                }
                            }
                        }
                        return true
                    }
                    .background {
                        RightMouseDragReader {
                            rightDragOriginOrder = elementOrder
                        } onChanged: { verticalOffset in
                            reorderElement(element, verticalOffset: verticalOffset, itemStride: 44)
                        } onEnded: {
                            rightDragOriginOrder = nil
                        }
                    }
                }
            }
            .padding(.horizontal, 10)

            Spacer(minLength: 24)
            VStack(alignment: .leading, spacing: 8) {
                Label("本机技能库", systemImage: "internaldrive")
                    .font(.system(size: 12, weight: .medium))
                Text("共 \(model.totalSkillCount) 个 Skill")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 20)
            Divider()
            Button { model.openSettings() } label: {
                HStack {
                    Image(systemName: "gearshape")
                    Text("设置")
                    Spacer()
                    Text("⌘,").foregroundStyle(.tertiary)
                }
                .font(.system(size: 13))
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("设置（⌘,）")
        }
        .frame(maxHeight: .infinity)
        .background(AppTheme.sidebar(for: colorScheme))
    }

    private func move(_ dragged: Element, before destination: Element) {
        guard dragged != destination,
              let from = elementOrder.firstIndex(of: dragged),
              let to = elementOrder.firstIndex(of: destination) else { return }
        elementOrder.remove(at: from)
        elementOrder.insert(dragged, at: to)
    }

    private func reorderElement(
        _ dragged: Element,
        verticalOffset: CGFloat,
        itemStride: CGFloat
    ) {
        let originOrder = rightDragOriginOrder ?? elementOrder
        guard let sourceIndex = originOrder.firstIndex(of: dragged), itemStride > 0 else { return }
        let indexOffset = Int((verticalOffset / itemStride).rounded())
        let destinationIndex = min(max(sourceIndex - indexOffset, 0), originOrder.count - 1)
        var reordered = originOrder
        reordered.remove(at: sourceIndex)
        reordered.insert(dragged, at: destinationIndex)
        elementOrder = reordered
    }

}

struct SkillListPanelContent: View {
    @ObservedObject var model: CoolSkillModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(model.selectedElement?.chineseDefinition ?? "技能库")
                        .font(.system(size: 25, weight: .bold))
                    Text(elementDescription)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 16)
                Button {
                    model.refreshCatalog(generateChineseSummaries: true)
                } label: {
                    Label(model.isGeneratingSummaries ? "生成介绍中…" : "更新 Skills", systemImage: "arrow.clockwise")
                }
                .disabled(model.isRefreshing || model.isGeneratingSummaries)
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent(for: colorScheme))
                .controlSize(.regular)
                .help("重新扫描技能，更新统计并生成缺失的中文介绍")
            }
            .padding(.horizontal, 28)
            .padding(.top, 26)
            .padding(.bottom, 26)

            HStack {
                Text("\(model.visibleSkills.count) 个 Skill")
                Spacer()
                Label("最近调用优先", systemImage: "clock")
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 28)
            .padding(.bottom, 12)
            Divider().padding(.horizontal, 28)

            if model.visibleSkills.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "square.stack.3d.up")
                        .font(.system(size: 30, weight: .light))
                        .foregroundStyle(.tertiary)
                    Text(model.selectedElement == nil ? "选择一个元素" : "这个分类还没有 Skill")
                        .font(.system(size: 17, weight: .semibold))
                    Text(model.selectedElement == nil
                         ? "从左侧选择风、火、水或山，浏览你的技能。"
                         : "更新技能库，或在其他分类中右键移动 Skill 到这里。")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(model.visibleSkills) { skill in
                                SkillRow(
                                    skill: skill,
                                    summaryText: model.summaryText(for: skill),
                                    accentColor: skill.element.color(for: colorScheme)
                                ) {
                                    _ = model.invoke(skill)
                                } moveAction: { element in
                                    model.moveSkill(skill.invocationName, to: element)
                                } isKeyboardSelected: {
                                    model.isKeyboardSelected(skill)
                                }
                                .id(skill.id)
                                Divider().padding(.leading, 56)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                    }
                    .onChange(of: model.keyboardSelectionIndex) { index in
                        guard let index, model.visibleSkills.indices.contains(index) else { return }
                        proxy.scrollTo(model.visibleSkills[index].id)
                    }
                    .onChange(of: model.selectedElement) { _ in
                        if let first = model.visibleSkills.first { proxy.scrollTo(first.id, anchor: .top) }
                    }
                }
            }
            if let message = model.storageMessage ?? model.summaryMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 12)
            }
            Divider()
            HStack {
                Label("点击技能，插入 Codex", systemImage: "arrow.up.right.square")
                Spacer()
                Text("右键更改分类")
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.canvas(for: colorScheme))
    }

    private var elementDescription: String {
        switch model.selectedElement {
        case .wind: return "连接 Agent、人与工具，让协作顺畅发生。"
        case .fire: return "把想法付诸行动，完成代码与作品。"
        case .water: return "探索未知，理解问题，找到方向。"
        case .mountain: return "审视结果，守住质量与边界。"
        case nil: return "按职责整理，随时找到合适的技能。"
        }
    }
}

private struct RightMouseDragReader: NSViewRepresentable {
    let onBegan: () -> Void
    let onChanged: (CGFloat) -> Void
    let onEnded: () -> Void

    func makeNSView(context: Context) -> TrackingView {
        let view = TrackingView()
        update(view)
        return view
    }

    func updateNSView(_ nsView: TrackingView, context: Context) {
        update(nsView)
    }

    static func dismantleNSView(_ nsView: TrackingView, coordinator: ()) {
        nsView.stopMonitoring()
    }

    private func update(_ view: TrackingView) {
        view.onBegan = onBegan
        view.onChanged = onChanged
        view.onEnded = onEnded
    }

    final class TrackingView: NSView {
        var onBegan: (() -> Void)?
        var onChanged: ((CGFloat) -> Void)?
        var onEnded: (() -> Void)?

        private var monitor: Any?
        private var startY: CGFloat?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window == nil {
                stopMonitoring()
            } else {
                startMonitoring()
            }
        }

        deinit {
            stopMonitoring()
        }

        func stopMonitoring() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
            startY = nil
        }

        private func startMonitoring() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(
                matching: [.rightMouseDown, .rightMouseDragged, .rightMouseUp]
            ) { [weak self] event in
                self?.handle(event)
                return event
            }
        }

        private func handle(_ event: NSEvent) {
            switch event.type {
            case .rightMouseDown:
                guard event.window === window,
                      bounds.contains(convert(event.locationInWindow, from: nil)) else { return }
                startY = event.locationInWindow.y
                onBegan?()
            case .rightMouseDragged:
                guard let startY else { return }
                onChanged?(event.locationInWindow.y - startY)
            case .rightMouseUp:
                guard startY != nil else { return }
                startY = nil
                onEnded?()
            default:
                break
            }
        }
    }
}

private struct ElementButton: View {
    let element: Element
    let isSelected: Bool
    let color: Color
    let count: Int
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ElementGlyph(element: element, color: color)
                    .frame(width: 22, height: 22)
                Text(element.chineseDefinition)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                Spacer(minLength: 4)
                Text("\(count)")
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .foregroundStyle(isSelected ? AppTheme.accent(for: colorScheme) : AppTheme.ink(for: colorScheme))
            .background(isSelected ? AppTheme.selection(for: colorScheme) : .clear,
                        in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(element.chineseDefinition)，\(count) 个 Skill")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .help("\(element.chineseDefinition)（⌘\((Element.allCases.firstIndex(of: element) ?? 0) + 1)）")
    }
}

private struct SkillRow: View {
    let skill: Skill
    let summaryText: String
    let accentColor: Color
    let action: () -> Void
    let moveAction: (Element) -> Void
    let isKeyboardSelected: () -> Bool
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 14) {
                ElementGlyph(element: skill.element, color: accentColor)
                    .frame(width: 22, height: 22)
                    .frame(width: 36, height: 36)
                    .background(accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(skill.name)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                            .help(skill.name)
                        if skill.usageCount > 0 {
                            Text("\(skill.usageCount) 次")
                                .font(.system(size: 10))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .fixedSize()
                        }
                    }
                    Text(summaryText)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .help(summaryText)
                    Text(lastUsedText)
                        .font(.system(size: 10))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                ImplicitInvocationIndicator(isOn: skill.allowsImplicitInvocation, tint: accentColor)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isHovered ? accentColor : Color.secondary.opacity(0.5))
                    .frame(width: 22)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 16)
            .frame(minHeight: 104)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            isKeyboardSelected() ? accentColor.opacity(0.10) : (isHovered ? Color.primary.opacity(0.035) : .clear),
            in: RoundedRectangle(cornerRadius: 10)
        )
        .accessibilityLabel("插入 \(skill.name)，\(summaryText)，\(lastUsedText)，调用 \(skill.usageCount) 次")
        .onDrag { NSItemProvider(object: NSString(string: skill.invocationName)) }
        .contextMenu {
            ForEach(Element.allCases) { element in
                Button("移至\(element.displayName)") { moveAction(element) }
                    .disabled(element == skill.element)
            }
        }
        .onHover { isHovered = $0 }
        .help("插入 $\(skill.commandName) 到 Codex")
    }

    private var lastUsedText: String {
        guard let lastUsedAt = skill.lastUsedAt else { return "尚未调用" }
        return "最近调用 " + Self.timestampFormatter.string(from: lastUsedAt)
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}

private struct ImplicitInvocationIndicator: View {
    let isOn: Bool
    let tint: Color

    var body: some View {
        Label(isOn ? "自动" : "手动", systemImage: isOn ? "sparkles" : "hand.raised")
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(isOn ? tint : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(isOn ? tint.opacity(0.08) : Color.primary.opacity(0.04), in: Capsule())
            .fixedSize()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("允许自动调用")
            .accessibilityValue(isOn ? "开启" : "关闭")
            .help(isOn ? "允许自动调用（只读）" : "仅允许手动调用（只读）")
    }
}

struct SettingsSheet: View {
    @ObservedObject var model: CoolSkillModel
    @Environment(\.colorScheme) private var colorScheme
    let onClose: (() -> Void)?

    init(model: CoolSkillModel, onClose: (() -> Void)? = nil) {
        self.model = model
        self.onClose = onClose
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("kcoisga 设置")
                .font(.system(size: 20, weight: .semibold))
            settingGroup {
                Toggle(
                    "登录时启动",
                    isOn: Binding(
                        get: { model.launchAtLogin },
                        set: { model.setLaunchAtLogin($0) }
                    )
                )
                .padding(.top, 12)
                Text("按需打开，关闭主窗口即退出。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 12)
            }
            Text("系统权限")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            settingGroup {
                PermissionRow(
                    title: "辅助功能",
                    detail: "向 Codex 输入框写入 Skill",
                    isGranted: model.permissions.accessibilityGranted,
                    action: { model.requestAccessibilityPermission() }
                )
            }
            if let message = model.lifecycleMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            if let message = model.summaryMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Button(model.isGeneratingSummaries ? "正在生成中文介绍…" : "更新 Skills") {
                    model.refreshCatalog(generateChineseSummaries: true)
                }
                .disabled(model.isGeneratingSummaries)
                .help("新增或描述变化的 Skill 会使用 Codex 生成中文介绍")
                Button("刷新权限") {
                    model.refreshPermissions()
                }
                Spacer()
                Button("完成") {
                    if let onClose {
                        onClose()
                    } else {
                        model.closeSettings()
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 390)
        .background(AppTheme.sidebar(for: colorScheme))
        .foregroundStyle(AppTheme.ink(for: colorScheme))
        .tint(AppTheme.accent(for: colorScheme))
        .onAppear {
            model.refreshPermissions()
        }
    }

    private func settingGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0, content: content)
            .padding(.horizontal, 14)
            .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

}

private struct PermissionRow: View {
    let title: String
    let detail: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isGranted ? .green : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isGranted {
                Text("已允许")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Button("授权", action: action)
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 11)
    }
}
