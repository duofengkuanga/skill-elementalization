import Foundation

struct GitHubRelease: Decodable, Equatable {
    let tagName: String
    let htmlURL: URL

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
    }
}

enum UpdateCheckResult: Equatable {
    case upToDate
    case available(GitHubRelease)
    case failed
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
