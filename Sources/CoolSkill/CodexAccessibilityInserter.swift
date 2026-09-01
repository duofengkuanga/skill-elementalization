import AppKit
import ApplicationServices
import CoolSkillCore
import Foundation

enum CodexInsertionError: Error, LocalizedError {
    case permissionRequired
    case codexNotRunning
    case composerNotFocused
    case composerNotWritable
    case textUnavailable
    case selectionUnavailable
    case writeFailed(AXError)

    var errorDescription: String? {
        switch self {
        case .permissionRequired:
            return "请先授予 CoolSkill 辅助功能权限"
        case .codexNotRunning:
            return "请先打开 Codex"
        case .composerNotFocused:
            return "请先将光标放入 Codex 对话框"
        case .composerNotWritable:
            return "当前 Codex 控件不可写入"
        case .textUnavailable:
            return "无法读取 Codex 输入内容"
        case .selectionUnavailable:
            return "无法读取 Codex 光标位置"
        case let .writeFailed(error):
            return "写入 Codex 失败（\(error.rawValue)）"
        }
    }
}

protocol SkillInserting {
    func insert(invocationName: String) -> Result<InsertionPlan, Error>
}

final class CodexAccessibilityInserter: SkillInserting {
    private let planner: InsertionPlanner
    private let bundleIdentifier: String

    init(
        planner: InsertionPlanner = InsertionPlanner(),
        bundleIdentifier: String = "com.openai.codex"
    ) {
        self.planner = planner
        self.bundleIdentifier = bundleIdentifier
    }

    func insert(invocationName: String) -> Result<InsertionPlan, Error> {
        do {
            let application = try launchAndActivateCodex()
            guard AXIsProcessTrusted() else {
                throw CodexInsertionError.permissionRequired
            }
            let composer = try focusedCodexComposer(in: application)
            let text = try currentText(from: composer)
            let selection = try currentSelection(from: composer)
            let plan = try planner.plan(
                currentText: text,
                selection: selection,
                invocationName: invocationName
            )
            try typeLikeUser(
                plan,
                to: composer,
                originalSelection: selection
            )
            return .success(plan)
        } catch {
            return .failure(error)
        }
    }

    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    static func requestPermission() {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private func codexApplication() -> NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first
    }

    private func launchAndActivateCodex() throws -> NSRunningApplication {
        if codexApplication() == nil,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
            let deadline = Date().addingTimeInterval(2)
            while Date() < deadline, codexApplication() == nil {
                RunLoop.current.run(until: Date().addingTimeInterval(0.05))
            }
        }
        guard let application = codexApplication() else {
            throw CodexInsertionError.codexNotRunning
        }
        application.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        return application
    }

    private func focusedCodexComposer(in application: NSRunningApplication) throws -> AXUIElement {
        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        ) == .success,
        let focusedValue else {
            throw CodexInsertionError.composerNotFocused
        }
        if CFGetTypeID(focusedValue) == AXUIElementGetTypeID(),
           let element = writableComposer(from: focusedValue as! AXUIElement) {
            return element
        }
        if let composer = findWritableComposer(in: appElement) {
            _ = AXUIElementSetAttributeValue(composer, kAXFocusedAttribute as CFString, true as CFTypeRef)
            return composer
        }
        throw CodexInsertionError.composerNotFocused
    }

    private func writableComposer(from element: AXUIElement) -> AXUIElement? {
        var roleValue: CFTypeRef?
        _ = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue)
        let role = roleValue as? String
        guard role == kAXTextAreaRole as String || role == kAXTextFieldRole as String else { return nil }

        var isSettable: DarwinBoolean = false
        guard AXUIElementIsAttributeSettable(
            element,
            kAXValueAttribute as CFString,
            &isSettable
        ) == .success,
        isSettable.boolValue else { return nil }
        var selectionIsSettable: DarwinBoolean = false
        guard AXUIElementIsAttributeSettable(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &selectionIsSettable
        ) == .success,
        selectionIsSettable.boolValue else { return nil }
        return element
    }

    private func findWritableComposer(in root: AXUIElement) -> AXUIElement? {
        if let composer = writableComposer(from: root) { return composer }
        var childrenValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(root, kAXChildrenAttribute as CFString, &childrenValue) == .success,
              let children = childrenValue as? [AXUIElement] else { return nil }
        for child in children {
            if let composer = findWritableComposer(in: child) { return composer }
        }
        return nil
    }

    private func currentText(from element: AXUIElement) throws -> String {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXValueAttribute as CFString,
            &value
        ) == .success,
        let text = value as? String else {
            throw CodexInsertionError.textUnavailable
        }
        return text
    }

    private func currentSelection(from element: AXUIElement) throws -> TextSelection {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &value
        ) == .success,
        let value,
        CFGetTypeID(value) == AXValueGetTypeID() else {
            throw CodexInsertionError.selectionUnavailable
        }
        let axValue = value as! AXValue
        var range = CFRange()
        guard AXValueGetValue(axValue, .cfRange, &range) else {
            throw CodexInsertionError.selectionUnavailable
        }
        return TextSelection(location: range.location, length: range.length)
    }

    private func apply(
        _ plan: InsertionPlan,
        to element: AXUIElement,
        originalText: String,
        originalSelection: TextSelection
    ) throws {
        let textResult = AXUIElementSetAttributeValue(
            element,
            kAXValueAttribute as CFString,
            plan.text as CFTypeRef
        )
        guard textResult == .success else {
            throw CodexInsertionError.writeFailed(textResult)
        }

        var range = CFRange(
            location: plan.selection.location,
            length: plan.selection.length
        )
        guard let rangeValue = AXValueCreate(.cfRange, &range) else {
            throw CodexInsertionError.selectionUnavailable
        }
        let selectionResult = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            rangeValue
        )
        guard selectionResult == .success else {
            _ = AXUIElementSetAttributeValue(
                element,
                kAXValueAttribute as CFString,
                originalText as CFTypeRef
            )
            var originalRange = CFRange(
                location: originalSelection.location,
                length: originalSelection.length
            )
            if let originalRangeValue = AXValueCreate(.cfRange, &originalRange) {
                _ = AXUIElementSetAttributeValue(
                    element,
                    kAXSelectedTextRangeAttribute as CFString,
                    originalRangeValue
                )
            }
            throw CodexInsertionError.writeFailed(selectionResult)
        }
    }

    private func typeLikeUser(
        _ plan: InsertionPlan,
        to element: AXUIElement,
        originalSelection: TextSelection
    ) throws {
        var insertionRange = CFRange(location: originalSelection.location, length: 0)
        guard let rangeValue = AXValueCreate(.cfRange, &insertionRange),
              AXUIElementSetAttributeValue(
                element,
                kAXSelectedTextRangeAttribute as CFString,
                rangeValue
              ) == .success,
              let source = CGEventSource(stateID: .hidSystemState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
            throw CodexInsertionError.selectionUnavailable
        }

        var characters = Array(plan.insertedText.utf16)
        characters.withUnsafeMutableBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            down.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: baseAddress)
            up.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: baseAddress)
        }
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        RunLoop.current.run(until: Date().addingTimeInterval(0.08))

        guard let updatedText = try? currentText(from: element), updatedText == plan.text else {
            throw CodexInsertionError.writeFailed(.failure)
        }
    }
}
