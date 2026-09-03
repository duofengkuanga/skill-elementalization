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
    @State private var listPresentation = SkillListPresentationState()
    @State private var elementOrder = Element.allCases
    @State private var rightDragOriginOrder: [Element]?

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
            elementRail(size: proxy.size)
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
        .alert(
            "无法插入 Skill",
            isPresented: Binding(
                get: { model.insertionMessage != nil },
                set: { if !$0 { model.dismissInsertionMessage() } }
            )
        ) {
            Button("好", role: .cancel) {
                model.dismissInsertionMessage()
            }
        } message: {
            Text(model.insertionMessage ?? "")
        }
        .task {
            model.loadInitialCatalogIfNeeded()
            model.refreshUsage()
            synchronizePresentation(with: model.selectedElement)
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard !Task.isCancelled else { return }
                model.refreshUsage()
            }
        }
        .onChange(of: model.selectedElement) { selectedElement in
            synchronizePresentation(with: selectedElement)
        }
    }

    private func elementRail(size: CGSize) -> some View {
        let inset = min(max(8, size.width * 0.16), 22)
        let usableHeight = max(1, size.height - inset * 2)
        let buttonSide = min(max(20, min(size.width * 0.62, usableHeight / 5.6)), 76)
        let glyphSide = buttonSide * 0.66
        let pinHeight = buttonSide * 0.78
        let gap = max(5, min(26, (usableHeight - pinHeight - buttonSide * 4) / 4))
        return VStack(spacing: gap) {
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
                .background {
                    RightMouseDragReader {
                        rightDragOriginOrder = elementOrder
                    } onChanged: { verticalOffset in
                        reorderElement(
                            element,
                            verticalOffset: verticalOffset,
                            itemStride: buttonSide + gap
                        )
                    } onEnded: {
                        rightDragOriginOrder = nil
                    }
                }
            }
        }
        .padding(inset)
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
        apply(listPresentation.reveal())
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

    private func synchronizePresentation(with selectedElement: Element?) {
        let command = listPresentation.synchronize(hasSelection: selectedElement != nil)
        if command == .show, let selectedElement {
            model.select(selectedElement)
        }
        apply(command)
    }

    private func apply(_ command: SkillListPresentationCommand?) {
        switch command {
        case .show: onPresentationChange(true)
        case .hide: onPresentationChange(false)
        case nil: break
        }
    }
}

struct SkillListPanelContent: View {
    @ObservedObject var model: CoolSkillModel
    let onHoverChanged: (Bool) -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            if let selectedElement = model.selectedElement {
                Text("\(selectedElement.chineseDefinition) · 共 \(model.visibleSkills.count) 个 Skill")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                Divider().opacity(0.45)
            }
            if let selectedElement = model.selectedElement, !model.visibleSkills.isEmpty {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 2) {
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
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
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

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Button(action: action) {
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(accentColor.opacity(0.86))
                        .frame(width: 7, height: 7)
                        .padding(.top, 5)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(skill.name)
                                .font(.system(size: 13, weight: .semibold))
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            if skill.usageCount > 0 {
                                Text("\(skill.usageCount)")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Color.primary.opacity(0.045), in: Capsule())
                            }
                        }
                        Text(skill.chineseSummary)
                            .font(.system(size: 9.5))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                            Text(lastUsedText)
                                .fontDesign(.monospaced)
                        }
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel("\(skill.name)，\(skill.summary)，最近调用：\(lastUsedText)")
            ImplicitInvocationIndicator(
                isOn: skill.allowsImplicitInvocation,
                tint: accentColor
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(minHeight: 64)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isKeyboardSelected() ? accentColor.opacity(0.13) : (isHovered ? Color.primary.opacity(0.035) : Color.clear),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
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
        }
    }

    private var lastUsedText: String {
        guard let lastUsedAt = skill.lastUsedAt else { return "从未调用" }
        return Self.timestampFormatter.string(from: lastUsedAt)
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

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(trackGradient)
                .overlay {
                    Capsule()
                        .strokeBorder(
                            isOn ? tint.opacity(0.64) : Color.primary.opacity(0.16),
                            lineWidth: 0.75
                        )
                }
                .overlay(alignment: isOn ? .leading : .trailing) {
                    Image(systemName: isOn ? "sparkles" : "hand.raised.fill")
                        .font(.system(size: 6.5, weight: .bold))
                        .foregroundStyle(isOn ? Color.white.opacity(0.82) : Color.primary.opacity(0.34))
                        .padding(.horizontal, 5.5)
                }

            Circle()
                .fill(knobGradient)
                .overlay {
                    Circle()
                        .fill(isOn ? tint.opacity(0.82) : Color.primary.opacity(0.22))
                        .frame(width: 3.5, height: 3.5)
                }
                .padding(2)
                .shadow(
                    color: isOn ? tint.opacity(0.34) : Color.black.opacity(0.16),
                    radius: 1.5,
                    y: 0.8
                )
        }
        .frame(width: 36, height: 20)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: isOn)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("允许自动调用")
        .accessibilityValue(isOn ? "开启" : "关闭")
        .help(isOn ? "允许自动调用" : "仅允许手动调用")
    }

    private var trackGradient: LinearGradient {
        if isOn {
            return LinearGradient(
                colors: [tint.opacity(0.62), tint.opacity(0.30)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [
                Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.09),
                Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.04)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var knobGradient: LinearGradient {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color.white.opacity(0.90), Color.white.opacity(0.62)]
                : [Color.white, Color.white.opacity(0.84)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct SettingsSheet: View {
    @ObservedObject var model: CoolSkillModel
    let onClose: (() -> Void)?

    init(model: CoolSkillModel, onClose: (() -> Void)? = nil) {
        self.model = model
        self.onClose = onClose
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("设置")
                .font(.system(size: 20, weight: .bold, design: .rounded))
            settingGroup {
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
