import AppKit
import CoolSkillCore
import SwiftUI
import UniformTypeIdentifiers

struct CoolSkillPanel: View {
    @ObservedObject var model: CoolSkillModel
    let onSuccessfulInsertion: () -> Void
    let onTogglePin: () -> Void
    let onPresentationChange: (Bool) -> Void
    let showsPinControl: Bool
    let reduceMotionOverride: Bool?
    @Environment(\.colorScheme) private var colorScheme
    @State private var isShowingSkillList = false
    @State private var elementOrder = Element.allCases

    init(
        model: CoolSkillModel,
        onSuccessfulInsertion: @escaping () -> Void = {},
        onTogglePin: @escaping () -> Void = {},
        onPresentationChange: @escaping (Bool) -> Void = { _ in },
        showsPinControl: Bool = true,
        reduceMotionOverride: Bool? = nil
    ) {
        self.model = model
        self.onSuccessfulInsertion = onSuccessfulInsertion
        self.onTogglePin = onTogglePin
        self.onPresentationChange = onPresentationChange
        self.showsPinControl = showsPinControl
        self.reduceMotionOverride = reduceMotionOverride
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                elementRail(size: proxy.size)
                if let message = model.insertionMessage {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.thickMaterial, in: Capsule())
                        .padding(.bottom, 14)
                }
            }
        }
        .background {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                glassTint
            }
        }
        .overlay(Color.white.opacity(colorScheme == .dark ? 0.02 : 0.08).allowsHitTesting(false))
        .sheet(
            isPresented: Binding(
                get: { model.isSettingsPresented },
                set: { if !$0 { model.closeSettings() } }
            )
        ) {
            SettingsSheet(model: model)
        }
        .task {
            model.loadInitialCatalogIfNeeded()
            model.refreshUsage()
            synchronizePresentation(with: model.selectedElement)
        }
        .onChange(of: model.selectedElement) { selectedElement in
            synchronizePresentation(with: selectedElement)
        }
    }

    private func elementRail(size: CGSize) -> some View {
        let buttonSide = min(max(28, min(size.width * 0.62, size.height / 6.5)), 76)
        let glyphSide = buttonSide * 0.48
        return VStack(spacing: max(8, buttonSide * 0.20)) {
            Button(action: onTogglePin) {
                Image(systemName: model.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: max(12, glyphSide * 0.54), weight: .semibold))
                    .frame(width: buttonSide, height: buttonSide * 0.78)
                    .foregroundStyle(model.isPinned ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .help(model.isPinned ? "取消窗口置顶" : "窗口置顶")
            ForEach(elementOrder) { element in
                ElementButton(
                    element: element,
                    isSelected: model.selectedElement == element,
                    color: element.color(for: colorScheme),
                    side: buttonSide,
                    glyphSide: glyphSide,
                    action: { revealList(for: element) }
                )
                .onHover { hovering in
                    if hovering {
                        revealList(for: element)
                    }
                }
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
                if element != elementOrder.last {
                    Spacer(minLength: 0)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(max(8, size.width * 0.16))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background {
            ZStack {
                Rectangle().fill(.thinMaterial)
                railTint
            }
        }
        .onHover { hovering in
            if !hovering {
                scheduleDismissal()
            }
        }
    }

    private var glassTint: Color {
        switch (model.selectedElement, colorScheme) {
        case (.wind?, .light): return Color(red: 0.82, green: 0.97, blue: 0.91).opacity(0.82)
        case (.fire?, .light): return Color(red: 1.00, green: 0.88, blue: 0.84).opacity(0.82)
        case (.water?, .light): return Color(red: 0.84, green: 0.91, blue: 1.00).opacity(0.82)
        case (.mountain?, .light): return Color(red: 0.99, green: 0.93, blue: 0.78).opacity(0.82)
        case (nil, .light): return .clear
        case (.wind?, .dark): return Color(red: 0.06, green: 0.22, blue: 0.17).opacity(0.84)
        case (.fire?, .dark): return Color(red: 0.25, green: 0.10, blue: 0.07).opacity(0.84)
        case (.water?, .dark): return Color(red: 0.06, green: 0.14, blue: 0.29).opacity(0.84)
        case (.mountain?, .dark): return Color(red: 0.22, green: 0.16, blue: 0.07).opacity(0.84)
        case (nil, .dark): return .clear
        @unknown default: return Color(nsColor: .windowBackgroundColor)
        }
    }

    private var railTint: Color {
        switch (model.selectedElement, colorScheme) {
        case (.wind?, .light): return Color(red: 0.58, green: 0.88, blue: 0.76).opacity(0.46)
        case (.fire?, .light): return Color(red: 1.00, green: 0.62, blue: 0.54).opacity(0.44)
        case (.water?, .light): return Color(red: 0.51, green: 0.70, blue: 1.00).opacity(0.44)
        case (.mountain?, .light): return Color(red: 0.85, green: 0.66, blue: 0.35).opacity(0.44)
        case (nil, .light): return .clear
        case (.wind?, .dark): return Color(red: 0.15, green: 0.54, blue: 0.42).opacity(0.56)
        case (.fire?, .dark): return Color(red: 0.68, green: 0.24, blue: 0.16).opacity(0.56)
        case (.water?, .dark): return Color(red: 0.18, green: 0.37, blue: 0.78).opacity(0.56)
        case (.mountain?, .dark): return Color(red: 0.55, green: 0.38, blue: 0.15).opacity(0.56)
        case (nil, .dark): return .clear
        @unknown default: return Color(nsColor: .underPageBackgroundColor)
        }
    }

    private func revealList(for element: Element) {
        model.select(element)
        guard !isShowingSkillList else { return }
        isShowingSkillList = true
        onPresentationChange(true)
    }

    private func scheduleDismissal() {
        onPresentationChange(false)
    }

    private func move(_ dragged: Element, before destination: Element) {
        guard dragged != destination,
              let from = elementOrder.firstIndex(of: dragged),
              let to = elementOrder.firstIndex(of: destination) else { return }
        elementOrder.remove(at: from)
        elementOrder.insert(dragged, at: to)
    }

    private func synchronizePresentation(with selectedElement: Element?) {
        guard let selectedElement else {
            guard isShowingSkillList else { return }
            isShowingSkillList = false
            onPresentationChange(false)
            return
        }
        guard !isShowingSkillList else { return }
        isShowingSkillList = true
        model.select(selectedElement)
        onPresentationChange(true)
    }
}

struct SkillListPanelContent: View {
    @ObservedObject var model: CoolSkillModel
    let onHoverChanged: (Bool) -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if let selectedElement = model.selectedElement, !model.visibleSkills.isEmpty {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        ForEach(model.visibleSkills) { skill in
                            SkillRow(skill: skill, accentColor: selectedElement.color(for: colorScheme)) {
                                _ = model.invoke(skill)
                            } moveAction: { element in
                                model.moveSkill(skill.invocationName, to: element)
                            } isKeyboardSelected: {
                                model.isKeyboardSelected(skill)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                }
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                listTint.opacity(0.82)
            }
        }
        .onHover(perform: onHoverChanged)
    }

    private var listTint: Color {
        switch (model.selectedElement, colorScheme) {
        case (.wind?, .light): return Color(red: 0.82, green: 0.97, blue: 0.91)
        case (.fire?, .light): return Color(red: 1.00, green: 0.88, blue: 0.84)
        case (.water?, .light): return Color(red: 0.84, green: 0.91, blue: 1.00)
        case (.mountain?, .light): return Color(red: 0.99, green: 0.93, blue: 0.78)
        case (.wind?, .dark): return Color(red: 0.06, green: 0.22, blue: 0.17)
        case (.fire?, .dark): return Color(red: 0.25, green: 0.10, blue: 0.07)
        case (.water?, .dark): return Color(red: 0.06, green: 0.14, blue: 0.29)
        case (.mountain?, .dark): return Color(red: 0.22, green: 0.16, blue: 0.07)
        default: return Color(nsColor: .windowBackgroundColor)
        }
    }
}

private struct ElementButton: View {
    let element: Element
    let isSelected: Bool
    let color: Color
    let side: CGFloat
    let glyphSide: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ElementGlyph(element: element, color: color)
                .frame(width: glyphSide, height: glyphSide)
                .frame(width: side, height: side)
                .background(isSelected ? color.opacity(0.13) : Color.clear)
                .overlay {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(color.opacity(0.30), lineWidth: 1)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(element.displayName)
        .help(element.displayName)
    }
}

private struct SkillRow: View {
    let skill: Skill
    let accentColor: Color
    let action: () -> Void
    let moveAction: (Element) -> Void
    let isKeyboardSelected: () -> Bool

    @State private var showsDetail = false
    @State private var hoverTask: Task<Void, Never>?
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Circle()
                    .fill(accentColor.opacity(0.86))
                    .frame(width: 7, height: 7)
                Text(skill.name)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 12)
                if skill.usageCount > 0 {
                    Text("\(skill.usageCount)")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(Color.primary.opacity(0.045), in: Capsule())
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 42)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isKeyboardSelected() ? accentColor.opacity(0.13) : (isHovered ? Color.primary.opacity(0.035) : Color.clear),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(skill.name)，\(skill.summary)")
        .onDrag {
            NSItemProvider(object: NSString(string: skill.invocationName))
        }
        .contextMenu {
            ForEach(Element.allCases) { element in
                Button("移至\(element.displayName)") {
                    moveAction(element)
                }
                .disabled(element == skill.element)
            }
        }
        .onHover { hovering in
            isHovered = hovering
            hoverTask?.cancel()
            if hovering {
                hoverTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    guard !Task.isCancelled else { return }
                    showsDetail = true
                }
            } else {
                showsDetail = false
            }
        }
        .popover(isPresented: $showsDetail, arrowEdge: .trailing) {
            VStack(alignment: .leading, spacing: 8) {
                Text(skill.name)
                    .font(.headline)
                Text(skill.summary.isEmpty ? "无描述" : skill.summary)
                    .font(.body)
                Divider()
                Text("使用次数：\(skill.usageCount)")
                Text(skill.source)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            .padding(14)
            .frame(width: 300, alignment: .leading)
        }
    }
}

struct SettingsSheet: View {
    @ObservedObject var model: CoolSkillModel
    let onClose: (() -> Void)?
    @State private var primary: ShortcutKey
    @State private var secondary: ShortcutKey

    init(model: CoolSkillModel, onClose: (() -> Void)? = nil) {
        self.model = model
        self.onClose = onClose
        _primary = State(initialValue: ShortcutKey(keyCode: model.shortcutConfiguration.primaryKeyCode) ?? .d)
        _secondary = State(initialValue: ShortcutKey(keyCode: model.shortcutConfiguration.secondaryKeyCode) ?? .p)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("设置")
                .font(.system(size: 20, weight: .bold, design: .rounded))
            settingGroup {
                HStack {
                    Text("全局快捷键")
                    Spacer()
                    Text("⌘")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Picker("第一键", selection: $primary) {
                        ForEach(ShortcutKey.allCases) { key in
                            Text(key.displayName).tag(key)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 64)
                    Picker("第二键", selection: $secondary) {
                        ForEach(ShortcutKey.allCases) { key in
                            Text(key.displayName).tag(key)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 64)
                }
                .padding(.vertical, 12)
                Divider()
                Toggle(
                    "登录时启动",
                    isOn: Binding(
                        get: { model.launchAtLogin },
                        set: { model.setLaunchAtLogin($0) }
                    )
                )
                .padding(.vertical, 12)
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
                Divider()
                PermissionRow(
                    title: "输入监听",
                    detail: "使用全局快捷键呼出窗口",
                    isGranted: model.permissions.inputMonitoringGranted,
                    action: { model.requestInputMonitoringPermission() }
                )
            }
            if let message = model.lifecycleMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            HStack {
                Button("更新 Skills") {
                    model.refreshCatalog()
                }
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
        .onChange(of: primary) { _ in
            persistShortcut()
        }
        .onChange(of: secondary) { _ in
            persistShortcut()
        }
        .onAppear {
            model.refreshPermissions()
        }
    }

    private func settingGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0, content: content)
            .padding(.horizontal, 14)
            .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func persistShortcut() {
        guard primary != secondary else {
            secondary = primary == .p ? .d : .p
            return
        }
        model.setShortcut(primary: primary, secondary: secondary)
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
