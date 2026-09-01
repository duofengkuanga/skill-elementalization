import Foundation

public struct TextSelection: Codable, Equatable, Sendable {
    public let location: Int
    public let length: Int

    public init(location: Int, length: Int) {
        self.location = location
        self.length = length
    }
}

public struct InsertionPlan: Equatable, Sendable {
    public let text: String
    public let selection: TextSelection
    public let insertedText: String

    public init(text: String, selection: TextSelection, insertedText: String) {
        self.text = text
        self.selection = selection
        self.insertedText = insertedText
    }
}

public enum InsertionPlanningError: Error, Equatable, LocalizedError {
    case invalidInvocationName
    case invalidSelection

    public var errorDescription: String? {
        switch self {
        case .invalidInvocationName: return "Skill 调用名无效"
        case .invalidSelection: return "Codex 光标位置无效"
        }
    }
}

public struct InsertionPlanner: Sendable {
    public init() {}

    public func plan(
        currentText: String,
        selection: TextSelection,
        invocationName: String
    ) throws -> InsertionPlan {
        let commandName = invocationName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !commandName.isEmpty,
              commandName.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) }) else {
            throw InsertionPlanningError.invalidInvocationName
        }

        let utf16 = currentText.utf16
        guard selection.location >= 0,
              selection.length >= 0,
              selection.location + selection.length <= utf16.count,
              let insertionIndex = String.Index(
                utf16Offset: selection.location,
                in: currentText,
                limitedBy: currentText.endIndex
              ) else {
            throw InsertionPlanningError.invalidSelection
        }

        let prefix = String(currentText[..<insertionIndex])
        let suffix = String(currentText[insertionIndex...])
        let needsLeadingSpace = prefix.last.map { !$0.isWhitespace } ?? false
        let needsTrailingSpace = suffix.first.map { !$0.isWhitespace } ?? true
        let insertedText = (needsLeadingSpace ? " " : "")
            + "/\(commandName)"
            + (needsTrailingSpace ? " " : "")
        let newText = prefix + insertedText + suffix
        let newLocation = prefix.utf16.count + insertedText.utf16.count

        return InsertionPlan(
            text: newText,
            selection: TextSelection(location: newLocation, length: 0),
            insertedText: insertedText
        )
    }
}

private extension String.Index {
    init?(utf16Offset: Int, in string: String, limitedBy endIndex: String.Index) {
        guard let utf16Index = string.utf16.index(
            string.utf16.startIndex,
            offsetBy: utf16Offset,
            limitedBy: string.utf16.endIndex
        ),
        let index = String.Index(utf16Index, within: string),
        index <= endIndex else {
            return nil
        }
        self = index
    }
}
