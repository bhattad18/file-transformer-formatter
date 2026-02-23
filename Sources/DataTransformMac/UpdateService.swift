import Foundation

struct ReleaseInfo {
    let version: String
    let url: URL
}

enum UpdateCheckResult {
    case upToDate(current: String)
    case updateAvailable(current: String, release: ReleaseInfo)
    case failed(String)
}

enum UpdateService {
    static func checkForUpdates(currentVersion: String) async -> UpdateCheckResult {
        guard let url = URL(string: "https://api.github.com/repos/\(AppInfo.updatesRepoOwner)/\(AppInfo.updatesRepoName)/releases/latest") else {
            return .failed("Update URL is invalid.")
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .failed("Unexpected update response.")
            }

            if http.statusCode == 404 {
                return .failed("No GitHub release is published yet.")
            }

            guard (200...299).contains(http.statusCode) else {
                return .failed("Update check failed with status \(http.statusCode).")
            }

            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            guard let releaseURL = URL(string: release.html_url) else {
                return .failed("Release URL is invalid.")
            }

            let latest = normalizeVersion(release.tag_name)
            if isVersion(latest, newerThan: currentVersion) {
                return .updateAvailable(
                    current: currentVersion,
                    release: ReleaseInfo(version: latest, url: releaseURL)
                )
            }
            return .upToDate(current: currentVersion)
        } catch {
            return .failed("Could not check updates: \(error.localizedDescription)")
        }
    }

    static func currentVersionFromBundle() -> String {
        if let bundled = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           !bundled.isEmpty {
            return bundled
        }
        return AppInfo.currentVersion
    }

    private static func normalizeVersion(_ tag: String) -> String {
        var value = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.lowercased().hasPrefix("v") {
            value = String(value.dropFirst())
        }
        while value.first == "." {
            value.removeFirst()
        }
        return value
    }

    private static func isVersion(_ lhs: String, newerThan rhs: String) -> Bool {
        let left = normalizeVersion(lhs)
        let right = normalizeVersion(rhs)
        return left.compare(right, options: .numeric) == .orderedDescending
    }
}

private struct GitHubRelease: Decodable {
    let tag_name: String
    let html_url: String
}
