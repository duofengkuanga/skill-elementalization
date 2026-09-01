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
            guard AXIsProcessTrusted() else {
                throw CodexInsertionError.permissionRequired
            }
            let composer = try focusedCodexComposer()
            let text = try currentText(from: composer)
            let selection = try currentSelection(from: composer)
            let plan = try planner.plan(
                currentText: text,
                selection: selection,
                invocationName: invocationName
            )
            try apply(
                plan,
                to: composer,
                originalText: text,
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

    private func focusedCodexComposer() throws -> AXUIElement {
        let applications = NSRunningApplication.runningApplications(
            withBundleIdentifier: bundleIdentifier
        )
        guard let application = applications.first else {
            throw CodexInsertionError.codexNotRunning
        }
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
        guard CFGetTypeID(focusedValue) == AXUIElementGetTypeID() else {
            throw CodexInsertionError.composerNotFocused
        }
        let element = focusedValue as! AXUIElement

        var roleValue: CFTypeRef?
        _ = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue)
        let role = roleValue as? String
        guard role == kAXTextAreaRole as String || role == kAXTextFieldRole as String else {
            throw CodexInsertionError.composerNotFocused
        }

        var isSettable: DarwinBoolean = false
        guard AXUIElementIsAttributeSettable(
            element,
            kAXValueAttribute as CFString,
            &isSettable
        ) == .success,
        isSettable.boolValue else {
            throw CodexInsertionError.composerNotWritable
        }
        var selectionIsSettable: DarwinBoolean = false
        guard AXUIElementIsAttributeSettable(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &selectionIsSettable
        ) == .success,
        selectionIsSettable.boolValue else {
            throw CodexInsertionError.composerNotWritable
        }
        return element
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
}
