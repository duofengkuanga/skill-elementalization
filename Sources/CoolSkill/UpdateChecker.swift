import Foundation
import CryptoKit

struct GitHubRelease: Decodable, Equatable {
    let tagName: String
    let htmlURL: URL
    let assets: [GitHubReleaseAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case assets
    }
}

struct GitHubReleaseAsset: Decodable, Equatable {
    let name: String
    let browserDownloadURL: URL
    let digest: String?

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
        case digest
    }
}

enum UpdateCheckResult: Equatable {
    case upToDate
    case available(GitHubRelease)
    case failed
}

enum SelfUpdateInstaller {
    static func install(_ release: GitHubRelease) async throws {
        guard let asset = release.assets.first(where: { $0.name.hasSuffix("macos-arm64.zip") }) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let (downloadURL, _) = try await URLSession.shared.download(from: asset.browserDownloadURL)
        if let digest = asset.digest?.replacingOccurrences(of: "sha256:", with: ""),
           digest != sha256(of: try Data(contentsOf: downloadURL)) {
            throw CocoaError(.fileReadCorruptFile)
        }
        let staging = FileManager.default.temporaryDirectory.appendingPathComponent("coolskill-update-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        let unzip = Process()
        unzip.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        unzip.arguments = ["-x", "-k", downloadURL.path, staging.path]
        try unzip.run()
        unzip.waitUntilExit()
        guard unzip.terminationStatus == 0 else { throw CocoaError(.fileReadUnknown) }
        let replacement = staging.appendingPathComponent("CoolSkill.app")
        guard FileManager.default.fileExists(atPath: replacement.path) else { throw CocoaError(.fileNoSuchFile) }

        let destination = Bundle.main.bundleURL
        let script = staging.appendingPathComponent("install-update.sh")
        let pid = ProcessInfo.processInfo.processIdentifier
        let scriptText = """
        #!/bin/zsh
        while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done
        /usr/bin/ditto '\(replacement.path)' '\(destination.path)'
        /usr/bin/open '\(destination.path)'
        """
        try scriptText.write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        let helper = Process()
        helper.executableURL = URL(fileURLWithPath: "/bin/zsh")
        helper.arguments = [script.path]
        try helper.run()
    }

    private static func sha256(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

struct GitHubUpdateChecker {
    let latestReleaseURL = URL(string: "https://api.github.com/repos/duofengkuanga/skill-elementalization/releases/latest")!

    func check(currentVersion: String) async -> UpdateCheckResult {
        do {
            var request = URLRequest(url: latestReleaseURL)
            request.setValue("CoolSkill", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
                return .failed
            }
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            return isNewer(release.tagName, than: currentVersion) ? .available(release) : .upToDate
        } catch {
            return .failed
        }
    }

    func isNewer(_ candidate: String, than current: String) -> Bool {
        let candidateParts = versionParts(candidate)
        let currentParts = versionParts(current)
        let length = max(candidateParts.count, currentParts.count)
        for index in 0..<length {
            let left = index < candidateParts.count ? candidateParts[index] : 0
            let right = index < currentParts.count ? currentParts[index] : 0
            if left != right { return left > right }
        }
        return false
    }

    private func versionParts(_ version: String) -> [Int] {
        version
            .trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            .split(separator: ".")
            .map { Int($0) ?? 0 }
    }
}
