import Foundation

public struct UsageEvent: Codable, Equatable, Hashable, Sendable {
    public let id: String
    public let invocationName: String
    public let occurredAt: Date

    public init(id: String, invocationName: String, occurredAt: Date) {
        self.id = id
        self.invocationName = invocationName
        self.occurredAt = occurredAt
    }
}

public struct UsageScanIssue: Equatable, Identifiable, Sendable {
    public let path: String
    public let message: String

    public var id: String { "\(path):\(message)" }

    public init(path: String, message: String) {
        self.path = path
        self.message = message
    }
}

public struct UsageScanResult: Equatable, Sendable {
    public let events: [UsageEvent]
    public let cursors: [String: UInt64]
    public let issues: [UsageScanIssue]

    public init(
        events: [UsageEvent],
        cursors: [String: UInt64],
        issues: [UsageScanIssue]
    ) {
        self.events = events
        self.cursors = cursors
        self.issues = issues
    }
}

public struct UsageReconstructor {
    private let roots: [URL]
    private let fileManager: FileManager

    public init(roots: [URL], fileManager: FileManager = .default) {
        self.roots = roots
        self.fileManager = fileManager
    }

    public static func defaultReconstructor(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) -> UsageReconstructor {
        let codexHome = environment["CODEX_HOME"].map(URL.init(fileURLWithPath:))
            ?? homeDirectory.appendingPathComponent(".codex", isDirectory: true)
        return UsageReconstructor(roots: [
            codexHome.appendingPathComponent("sessions", isDirectory: true),
            codexHome.appendingPathComponent("archived_sessions", isDirectory: true)
        ])
    }

    public func scan(
        skills: [Skill],
        cursors: [String: UInt64],
        rebuild: Bool = false
    ) -> UsageScanResult {
        let knownNames = Set(skills.map(\.invocationName))
        var sourceMap: [String: String] = [:]
        for skill in skills {
            sourceMap[skill.source.resolvingPath] = skill.invocationName
        }
        var eventsByID: [String: UsageEvent] = [:]
        var nextCursors = rebuild ? [:] : cursors
        var issues: [UsageScanIssue] = []

        for fileURL in rolloutFiles() {
            do {
                let path = fileURL.path
                let fileSize = try size(of: fileURL)
                let savedCursor = rebuild ? 0 : min(cursors[path] ?? 0, fileSize)
                if !rebuild, savedCursor == fileSize {
                    nextCursors[path] = savedCursor
                    continue
                }
                nextCursors[path] = try scanFile(
                    fileURL: fileURL,
                    offset: savedCursor,
                    knownNames: knownNames,
                    sourceMap: sourceMap,
                    into: &eventsByID,
                    issues: &issues
                )
            } catch {
                issues.append(UsageScanIssue(path: fileURL.path, message: error.localizedDescription))
            }
        }

        return UsageScanResult(
            events: eventsByID.values.sorted {
                if $0.occurredAt != $1.occurredAt { return $0.occurredAt < $1.occurredAt }
                return $0.id < $1.id
            },
            cursors: nextCursors,
            issues: issues
        )
    }

    private func scanFile(
        fileURL: URL,
        offset: UInt64,
        knownNames: Set<String>,
        sourceMap: [String: String],
        into eventsByID: inout [String: UsageEvent],
        issues: inout [UsageScanIssue]
    ) throws -> UInt64 {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }
        try handle.seek(toOffset: offset)

        var currentTurnID: String?
        var currentTimestamp = modificationDate(of: fileURL)
        var remainder = Data()
        var remainderOffset = offset

        while let chunk = try handle.read(upToCount: 1_048_576), !chunk.isEmpty {
            var buffer = Data()
            buffer.reserveCapacity(remainder.count + chunk.count)
            buffer.append(remainder)
            buffer.append(chunk)
            let bufferOffset = remainderOffset
            var start = buffer.startIndex

            while start < buffer.endIndex,
                  let newline = buffer[start...].firstIndex(of: 0x0A) {
                let lineData = buffer[start..<newline]
                processLine(
                    lineData,
                    lineOffset: bufferOffset + UInt64(start),
                    fileURL: fileURL,
                    knownNames: knownNames,
                    sourceMap: sourceMap,
                    currentTurnID: &currentTurnID,
                    currentTimestamp: &currentTimestamp,
                    eventsByID: &eventsByID,
                    issues: &issues
                )
                start = buffer.index(after: newline)
            }

            remainder = Data(buffer[start...])
            remainderOffset = handle.offsetInFile - UInt64(remainder.count)
        }

        return remainderOffset
    }

    private func processLine(
        _ lineData: Data.SubSequence,
        lineOffset: UInt64,
        fileURL: URL,
        knownNames: Set<String>,
        sourceMap: [String: String],
        currentTurnID: inout String?,
        currentTimestamp: inout Date,
        eventsByID: inout [String: UsageEvent],
        issues: inout [UsageScanIssue]
    ) {
        guard !lineData.isEmpty else { return }
        let data = Data(lineData)
        let isSkillLoad = (
            contains(data, "\"type\":\"custom_tool_call\"")
                || contains(data, "\"type\": \"custom_tool_call\"")
        ) && contains(data, "SKILL.md")
        let needsStructuredRead = contains(data, "turn_context")
            || contains(data, "task_started")
            || contains(data, "user_message")
            || contains(data, "session_meta")
        guard isSkillLoad || needsStructuredRead else { return }

        let rawLine = String(decoding: data, as: UTF8.self)

        if needsStructuredRead {
            guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                if !issues.contains(where: { $0.path == fileURL.path }) {
                    issues.append(
                        UsageScanIssue(
                            path: fileURL.path,
                            message: "无法解析相关 Codex 记录（offset \(lineOffset)）"
                        )
                    )
                }
                return
            }
                let type = object["type"] as? String
                let payload = object["payload"] as? [String: Any] ?? [:]
                let payloadType = payload["type"] as? String

                if type == "turn_context", let turnID = object["turn_id"] as? String {
                    currentTurnID = turnID
                } else if payloadType == "task_started", let turnID = payload["turn_id"] as? String {
                    currentTurnID = turnID
                }

                if let timestamp = date(from: object["timestamp"] ?? payload["started_at"] ?? payload["timestamp"]) {
                    currentTimestamp = timestamp
                }

                if type == "event_msg", payloadType == "user_message" {
                    let message = payload["message"] as? String ?? ""
                    let activationScope = currentTurnID ?? "offset-\(lineOffset)"
                    for invocationName in explicitInvocations(in: message) where knownNames.contains(invocationName) {
                        insertEvent(
                            invocationName: invocationName,
                            scope: activationScope,
                            fileURL: fileURL,
                            date: currentTimestamp,
                            into: &eventsByID
                        )
                    }
                }
        }

        if isSkillLoad {
            let activationScope = currentTurnID ?? "offset-\(lineOffset)"
            let normalizedLine = rawLine.resolvingPath
            var matchedInvocationNames = Set<String>()
            for (sourcePath, invocationName) in sourceMap where normalizedLine.contains(sourcePath) {
                matchedInvocationNames.insert(invocationName)
                insertEvent(
                    invocationName: invocationName,
                    scope: activationScope,
                    fileURL: fileURL,
                    date: currentTimestamp,
                    into: &eventsByID
                )
            }
            for invocationName in knownNames
            where !matchedInvocationNames.contains(invocationName)
                && normalizedLine.contains("/\(invocationName)/SKILL.md") {
                insertEvent(
                    invocationName: invocationName,
                    scope: activationScope,
                    fileURL: fileURL,
                    date: currentTimestamp,
                    into: &eventsByID
                )
            }
        }
    }

    private func contains(_ data: Data, _ text: String) -> Bool {
        data.range(of: Data(text.utf8)) != nil
    }

    private func insertEvent(
        invocationName: String,
        scope: String,
        fileURL: URL,
        date: Date,
        into eventsByID: inout [String: UsageEvent]
    ) {
        let id = "\(fileURL.path)|\(scope)|\(invocationName)"
        eventsByID[id] = UsageEvent(id: id, invocationName: invocationName, occurredAt: date)
    }

    private func explicitInvocations(in text: String) -> Set<String> {
        let scalars = Array(text.unicodeScalars)
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        var results = Set<String>()
        var index = 0

        while index < scalars.count {
            guard scalars[index] == "$" else {
                index += 1
                continue
            }
            var end = index + 1
            while end < scalars.count, allowed.contains(scalars[end]) {
                end += 1
            }
            if end > index + 1 {
                let name = String(String.UnicodeScalarView(scalars[(index + 1)..<end]))
                results.insert(SkillCatalog.normalizeInvocationName(name))
            }
            index = max(end, index + 1)
        }
        return results
    }

    private func rolloutFiles() -> [URL] {
        var files: [URL] = []
        for root in roots {
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsPackageDescendants]
            ) else {
                continue
            }
            files.append(contentsOf: enumerator.compactMap { item -> URL? in
                guard let url = item as? URL, url.pathExtension == "jsonl" else { return nil }
                return url
            })
        }
        return files.sorted { $0.path < $1.path }
    }

    private func size(of fileURL: URL) throws -> UInt64 {
        let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
        return (attributes[.size] as? NSNumber)?.uint64Value ?? 0
    }

    private func modificationDate(of fileURL: URL) -> Date {
        (try? fileManager.attributesOfItem(atPath: fileURL.path)[.modificationDate] as? Date) ?? Date()
    }

    private func date(from value: Any?) -> Date? {
        if let number = value as? NSNumber {
            let raw = number.doubleValue
            return Date(timeIntervalSince1970: raw > 10_000_000_000 ? raw / 1_000 : raw)
        }
        guard let text = value as? String else { return nil }
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return withFractional.date(from: text) ?? ISO8601DateFormatter().date(from: text)
    }
}

private extension String {
    var resolvingPath: String {
        NSString(string: self).expandingTildeInPath
            .replacingOccurrences(of: "\\/", with: "/")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }
}
