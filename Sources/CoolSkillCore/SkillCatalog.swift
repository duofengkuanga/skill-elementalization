import Foundation

public enum SkillSourceKind: String, Codable, Sendable {
    case codexGlobal
    case sharedGlobal
    case plugin
}

public struct SkillSourceRoot: Equatable, Sendable {
    public let url: URL
    public let kind: SkillSourceKind
    public let precedence: Int

    public init(url: URL, kind: SkillSourceKind, precedence: Int) {
        self.url = url
        self.kind = kind
        self.precedence = precedence
    }
}

public struct CatalogIssue: Equatable, Identifiable, Sendable {
    public let path: String
    public let message: String

    public var id: String { "\(path):\(message)" }

    public init(path: String, message: String) {
        self.path = path
        self.message = message
    }
}

public struct CatalogScanResult: Equatable, Sendable {
    public let skills: [Skill]
    public let issues: [CatalogIssue]

    public init(skills: [Skill], issues: [CatalogIssue]) {
        self.skills = skills
        self.issues = issues
    }
}

public struct SkillCatalog {
    private let roots: [SkillSourceRoot]
    private let parser: SkillDocumentParser
    private let classifier: ElementClassifier
    private let fileManager: FileManager

    public init(
        roots: [SkillSourceRoot],
        parser: SkillDocumentParser = SkillDocumentParser(),
        classifier: ElementClassifier = ElementClassifier(),
        fileManager: FileManager = .default
    ) {
        self.roots = roots
        self.parser = parser
        self.classifier = classifier
        self.fileManager = fileManager
    }

    public static func defaultCatalog(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> SkillCatalog {
        _ = environment
        return SkillCatalog(roots: [
            SkillSourceRoot(
                url: homeDirectory.appendingPathComponent(".agents/skills", isDirectory: true),
                kind: .sharedGlobal,
                precedence: 100
            )
        ])
    }

    public func scan() -> CatalogScanResult {
        struct Candidate {
            let skill: Skill
            let precedence: Int
        }

        var selected: [String: Candidate] = [:]
        var issues: [CatalogIssue] = []

        for root in roots.sorted(by: { $0.precedence > $1.precedence }) {
            for fileURL in skillFiles(under: root.url) {
                do {
                    let contents = try String(contentsOf: fileURL, encoding: .utf8)
                    let document = try parser.parse(contents: contents)
                    let invocationName = Self.normalizeInvocationName(document.name)
                    guard !invocationName.isEmpty else {
                        issues.append(CatalogIssue(path: fileURL.path, message: "Skill 名称无法形成调用名"))
                        continue
                    }
                    let classification = classifier.classify(
                        name: document.name,
                        description: document.description,
                        headings: document.headings
                    )
                    let skill = Skill(
                        invocationName: invocationName,
                        name: document.name,
                        summary: document.description,
                        element: classification.element,
                        source: fileURL.path,
                        allowsImplicitInvocation: allowsImplicitInvocation(for: fileURL) ?? true,
                        isLowConfidence: classification.isLowConfidence
                    )
                    if let current = selected[invocationName], current.precedence >= root.precedence {
                        continue
                    }
                    selected[invocationName] = Candidate(skill: skill, precedence: root.precedence)
                } catch {
                    let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    issues.append(CatalogIssue(path: fileURL.path, message: message))
                }
            }
        }

        return CatalogScanResult(
            skills: selected.values.map(\.skill).sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            },
            issues: issues.sorted { $0.path < $1.path }
        )
    }

    public static func normalizeInvocationName(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        let normalized = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "-")
            .replacingOccurrences(of: " ", with: "-")
        return normalized.unicodeScalars.filter { allowed.contains($0) }.map(String.init).joined()
    }

    private func allowsImplicitInvocation(for skillFileURL: URL) -> Bool? {
        let policyURL = skillFileURL.deletingLastPathComponent()
            .appendingPathComponent("agents/openai.yaml")
        guard let contents = try? String(contentsOf: policyURL, encoding: .utf8) else {
            return nil
        }
        return parser.parseAllowsImplicitInvocation(contents: contents)
    }

    private func skillFiles(under root: URL) -> [URL] {
        var visitedDirectories = Set<String>()
        var results: [URL] = []

        func visit(_ url: URL) {
            var isDirectory: ObjCBool = false
            let isSymbolicLink = (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink ?? false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
                  !isSymbolicLink else {
                return
            }
            if !isDirectory.boolValue {
                if url.lastPathComponent == "SKILL.md" {
                    results.append(url)
                }
                return
            }
            guard visitedDirectories.insert(url.standardizedFileURL.path).inserted else { return }
            guard let children = try? fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: []
            ) else {
                return
            }
            for child in children {
                visit(child)
            }
        }

        visit(root)
        return results.sorted { $0.path < $1.path }
    }
}
