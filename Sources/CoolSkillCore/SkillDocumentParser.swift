import Foundation

public struct SkillDocument: Equatable, Sendable {
    public let name: String
    public let description: String
    public let headings: [String]

    public init(name: String, description: String, headings: [String]) {
        self.name = name
        self.description = description
        self.headings = headings
    }
}

public enum SkillDocumentParserError: Error, Equatable, LocalizedError {
    case unreadable
    case missingFrontmatter
    case missingName

    public var errorDescription: String? {
        switch self {
        case .unreadable: return "无法读取 Skill 文件"
        case .missingFrontmatter: return "缺少 YAML frontmatter"
        case .missingName: return "frontmatter 缺少 name"
        }
    }
}

public struct SkillDocumentParser: Sendable {
    public init() {}

    public func parse(contents: String) throws -> SkillDocument {
        let lines = contents.components(separatedBy: .newlines)
        guard lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) == "---" else {
            throw SkillDocumentParserError.missingFrontmatter
        }
        guard let closingIndex = lines.dropFirst().firstIndex(where: {
            $0.trimmingCharacters(in: .whitespacesAndNewlines) == "---"
        }) else {
            throw SkillDocumentParserError.missingFrontmatter
        }

        let frontmatter = Array(lines[1..<closingIndex])
        guard let rawName = scalarValue(for: "name", in: frontmatter), !rawName.isEmpty else {
            throw SkillDocumentParserError.missingName
        }
        let description = scalarValue(for: "description", in: frontmatter) ?? ""
        let bodyStart = closingIndex + 1
        let bodyLines: ArraySlice<String> = bodyStart < lines.endIndex
            ? lines[bodyStart...]
            : ArraySlice()
        let headings = bodyLines.compactMap { line -> String? in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("#") else { return nil }
            return trimmed.drop(while: { $0 == "#" || $0 == " " }).isEmpty
                ? nil
                : String(trimmed.drop(while: { $0 == "#" || $0 == " " }))
        }

        return SkillDocument(
            name: unquote(rawName),
            description: unquote(description),
            headings: headings
        )
    }

    private func scalarValue(for key: String, in lines: [String]) -> String? {
        guard let index = lines.firstIndex(where: { line in
            line.trimmingCharacters(in: .whitespaces).hasPrefix("\(key):")
        }) else {
            return nil
        }

        let line = lines[index].trimmingCharacters(in: .whitespaces)
        let value = String(line.dropFirst(key.count + 1)).trimmingCharacters(in: .whitespaces)
        guard value == ">" || value == ">-" || value == "|" || value == "|-" else {
            return value
        }

        var parts: [String] = []
        for continuation in lines.dropFirst(index + 1) {
            if continuation.isEmpty {
                parts.append("")
                continue
            }
            guard continuation.first?.isWhitespace == true else { break }
            parts.append(continuation.trimmingCharacters(in: .whitespaces))
        }
        let separator = value.hasPrefix(">") ? " " : "\n"
        return parts.joined(separator: separator).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func unquote(_ value: String) -> String {
        guard value.count >= 2 else { return value }
        if (value.first == "\"" && value.last == "\"") || (value.first == "'" && value.last == "'") {
            return String(value.dropFirst().dropLast())
        }
        return value
    }
}
