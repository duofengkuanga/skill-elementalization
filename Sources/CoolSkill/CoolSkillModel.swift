import Combine
import CoolSkillCore
import Foundation

@MainActor
final class CoolSkillModel: ObservableObject {
    @Published private(set) var state: LauncherState
    @Published private(set) var catalogIssues: [CatalogIssue] = []
    @Published private(set) var isRefreshing = false
    @Published private(set) var storageMessage: String?
    @Published private(set) var usageIssues: [UsageScanIssue] = []
    @Published private(set) var isRefreshingUsage = false
    @Published private(set) var insertionMessage: String?
    @Published private(set) var keyboardSelectionIndex: Int?
    @Published private(set) var isPinned = false
    @Published private(set) var shortcutConfiguration: ChordConfiguration
    @Published private(set) var launchAtLogin: Bool
    @Published private(set) var hasCompletedOnboarding: Bool
    @Published private(set) var permissions: PermissionSnapshot
    @Published private(set) var lifecycleMessage: String?
    @Published private(set) var isSettingsPresented = false

    private let catalog: SkillCatalog
    private let store: LocalStateStore
    private let usageReconstructor: UsageReconstructor
    private let inserter: SkillInserting
    private let loginItemManager: LoginItemManaging
    private let permissionController: PermissionControlling
    private var hasLoadedCatalog = false
    private var insertionMessageTask: Task<Void, Never>?

    var onShortcutChanged: ((ChordConfiguration) -> Void)?
    var onPermissionRefresh: (() -> Void)?
    var onOpenPanel: (() -> Void)?

    init(
        skills: [Skill] = [],
        catalog: SkillCatalog = .defaultCatalog(),
        store: LocalStateStore = LocalStateStore(),
        usageReconstructor: UsageReconstructor = .defaultReconstructor(),
        inserter: SkillInserting = CodexAccessibilityInserter(),
        loginItemManager: LoginItemManaging = SystemLoginItemManager(),
        permissionController: PermissionControlling = SystemPermissionController()
    ) {
        self.store = store
        state = LauncherState(
            selectedElement: nil,
            skills: Self.applying(store.state, to: skills)
        )
        self.catalog = catalog
        self.usageReconstructor = usageReconstructor
        self.inserter = inserter
        self.loginItemManager = loginItemManager
        self.permissionController = permissionController
        shortcutConfiguration = store.state.shortcut
        launchAtLogin = store.state.launchAtLogin
        hasCompletedOnboarding = store.state.hasCompletedOnboarding
        permissions = permissionController.snapshot()
        storageMessage = store.loadMessage
    }

    var selectedElement: Element? { state.selectedElement }
    var visibleSkills: [Skill] { state.visibleSkills }
    var totalSkillCount: Int { state.skills.count }

    func skillCount(for element: Element) -> Int {
        state.skills.lazy.filter { $0.element == element }.count
    }

    func select(_ element: Element) {
        guard selectedElement != element else { return }
        state.send(.selectElement(element))
        keyboardSelectionIndex = nil
    }

    func clearSelection() {
        state.send(.clearElement)
        keyboardSelectionIndex = nil
    }

    func prepareForPresentation() {
        state.send(.clearElement)
        keyboardSelectionIndex = nil
        insertionMessage = nil
        loadInitialCatalogIfNeeded()
    }

    func moveKeyboardSelection(by delta: Int) {
        guard !visibleSkills.isEmpty else {
            keyboardSelectionIndex = nil
            return
        }
        keyboardSelectionIndex = min(
            max((keyboardSelectionIndex ?? (delta > 0 ? -1 : visibleSkills.count)) + delta, 0),
            visibleSkills.count - 1
        )
    }

    func invokeKeyboardSelection() -> Bool {
        guard let keyboardSelectionIndex,
              visibleSkills.indices.contains(keyboardSelectionIndex) else { return false }
        return invoke(visibleSkills[keyboardSelectionIndex])
    }

    func isKeyboardSelected(_ skill: Skill) -> Bool {
        guard let keyboardSelectionIndex else { return false }
        return visibleSkills.indices.contains(keyboardSelectionIndex)
            && visibleSkills[keyboardSelectionIndex].id == skill.id
    }

    func setPinned(_ pinned: Bool) {
        isPinned = pinned
    }

    func openPanel() {
        onOpenPanel?()
    }

    func openSettings() {
        isSettingsPresented = true
    }

    func closeSettings() {
        isSettingsPresented = false
    }

    func setShortcut(primary: ShortcutKey, secondary: ShortcutKey) {
        guard primary != secondary else {
            lifecycleMessage = "快捷键需要使用两个不同的字母"
            return
        }
        let configuration = ChordConfiguration(
            primaryKeyCode: primary.keyCode,
            secondaryKeyCode: secondary.keyCode,
            windowMilliseconds: 150
        )
        do {
            try store.setShortcut(configuration)
            shortcutConfiguration = configuration
            lifecycleMessage = nil
            onShortcutChanged?(configuration)
        } catch {
            lifecycleMessage = "无法保存快捷键：\(error.localizedDescription)"
        }
    }

    func restoreDefaultShortcut() {
        setShortcut(primary: .d, secondary: .p)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try loginItemManager.setEnabled(enabled)
            try store.setLaunchAtLogin(enabled)
            launchAtLogin = enabled
            lifecycleMessage = nil
        } catch {
            lifecycleMessage = "无法修改登录启动：\(error.localizedDescription)"
        }
    }

    func refreshPermissions() {
        permissions = permissionController.snapshot()
        onPermissionRefresh?()
    }

    func requestAccessibilityPermission() {
        permissionController.requestAccessibility()
        refreshPermissions()
    }

    func requestInputMonitoringPermission() {
        permissionController.requestInputMonitoring()
        refreshPermissions()
    }

    func completeOnboarding() {
        do {
            try store.setOnboardingCompleted(true)
            hasCompletedOnboarding = true
            lifecycleMessage = nil
        } catch {
            lifecycleMessage = "无法保存引导状态：\(error.localizedDescription)"
        }
    }

    func clearLocalData() {
        do {
            if launchAtLogin {
                try loginItemManager.setEnabled(false)
            }
            try store.removeAll()
            shortcutConfiguration = .commandDP
            launchAtLogin = false
            hasCompletedOnboarding = false
            state = LauncherState(
                selectedElement: nil,
                skills: state.skills.map { skill in
                    var reset = skill
                    reset.isManualElement = false
                    reset.usageCount = 0
                    reset.lastUsedAt = nil
                    return reset
                }
            )
            onShortcutChanged?(.commandDP)
            lifecycleMessage = nil
        } catch {
            lifecycleMessage = "无法清除本地数据：\(error.localizedDescription)"
        }
    }

    @discardableResult
    func invoke(_ skill: Skill) -> Bool {
        switch inserter.insert(invocationName: skill.commandName) {
        case .success:
            insertionMessageTask?.cancel()
            insertionMessage = nil
            return true
        case let .failure(error):
            let message = error.localizedDescription
            insertionMessage = message
            insertionMessageTask?.cancel()
            insertionMessageTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard !Task.isCancelled, self?.insertionMessage == message else { return }
                self?.insertionMessage = nil
            }
            return false
        }
    }

    func loadInitialCatalogIfNeeded() {
        guard !hasLoadedCatalog else { return }
        hasLoadedCatalog = true
        refreshCatalog()
    }

    func refreshCatalog() {
        isRefreshing = true
        let result = catalog.scan()
        state.send(.replaceSkills(Self.applying(store.state, to: result.skills)))
        catalogIssues = result.issues
        isRefreshing = false
        refreshUsage()
    }

    func refreshUsage(rebuild: Bool = false) {
        guard !isRefreshingUsage else { return }
        isRefreshingUsage = true
        let skills = state.skills
        let cursors = store.state.usageCursors
        let reconstructor = usageReconstructor
        Task { [weak self] in
            let result = await Task.detached(priority: .utility) {
                reconstructor.scan(
                    skills: skills,
                    cursors: cursors,
                    rebuild: rebuild
                )
            }.value
            self?.finishUsageRefresh(result, rebuild: rebuild)
        }
    }

    private func finishUsageRefresh(_ result: UsageScanResult, rebuild: Bool) {
        do {
            let visibleNames = Set(state.skills.map(\.invocationName))
            let scopedResult = UsageScanResult(
                events: result.events.filter { visibleNames.contains($0.invocationName) },
                cursors: result.cursors,
                issues: result.issues
            )
            try store.applyUsageScan(scopedResult, rebuild: rebuild)
            state.send(.replaceSkills(Self.applying(store.state, to: state.skills)))
            storageMessage = nil
        } catch {
            storageMessage = "无法保存使用统计：\(error.localizedDescription)"
        }
        usageIssues = result.issues
        isRefreshingUsage = false
    }

    func moveSkill(_ invocationName: String, to element: Element) {
        state.send(.moveSkill(invocationName: invocationName, to: element, isManual: true))
        do {
            try store.setManualElement(element, for: invocationName)
            storageMessage = nil
        } catch {
            storageMessage = "无法保存元素选择：\(error.localizedDescription)"
        }
    }

    private static func applying(_ persisted: PersistedAppState, to skills: [Skill]) -> [Skill] {
        skills.map { skill in
            guard let saved = persisted.skills[skill.invocationName] else { return skill }
            var merged = skill
            if let manualElement = saved.manualElement {
                merged.element = manualElement
                merged.isManualElement = true
                merged.isLowConfidence = false
            }
            merged.usageCount = saved.usageCount
            merged.lastUsedAt = saved.lastUsedAt
            return merged
        }
    }
}
