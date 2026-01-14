import Foundation
import AppKit

// MARK: - Update Service

class UpdateService: NSObject, ObservableObject {
    static let shared = UpdateService()

    // GitHub Releases API for update checking
    private let updateURL = "https://api.github.com/repos/Vladimirbabic/typebettermac/releases/latest"
    private let downloadPageURL = "https://github.com/Vladimirbabic/typebettermac/releases/latest"

    @Published var canCheckForUpdates = true
    @Published var isChecking = false
    @Published var latestVersion: String?
    @Published var updateAvailable = false

    override private init() {
        super.init()
    }

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var currentBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    // MARK: - Check for Updates

    func checkForUpdates() {
        Task { @MainActor in
            isChecking = true

            do {
                let update = try await fetchLatestVersion()

                if isNewerVersion(update.version, than: currentVersion) {
                    updateAvailable = true
                    latestVersion = update.version
                    showUpdateAlert(update: update)
                } else {
                    showNoUpdateAlert()
                }
            } catch {
                showErrorAlert(error: error)
            }

            isChecking = false
        }
    }

    func checkForUpdatesInBackground(showAlertIfAvailable: Bool = true) {
        Task {
            do {
                let update = try await fetchLatestVersion()

                await MainActor.run {
                    if isNewerVersion(update.version, than: currentVersion) {
                        updateAvailable = true
                        latestVersion = update.version

                        if showAlertIfAvailable {
                            showUpdateAlert(update: update)
                        }
                    }
                }
            } catch {
                // Silently fail for background checks
                print("Background update check failed: \(error)")
            }
        }
    }

    // MARK: - Fetch Update Info

    private func fetchLatestVersion() async throws -> UpdateInfo {
        guard let url = URL(string: updateURL) else {
            throw UpdateError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw UpdateError.serverError
        }

        let decoder = JSONDecoder()
        let release = try decoder.decode(GitHubRelease.self, from: data)

        // Convert GitHub release to UpdateInfo
        return UpdateInfo(
            version: release.tagName.replacingOccurrences(of: "v", with: ""),
            build: nil,
            downloadURL: release.assets.first?.browserDownloadURL ?? release.htmlURL,
            releaseNotes: release.body,
            minimumSystemVersion: "13.0"
        )
    }

    // MARK: - Version Comparison

    private func isNewerVersion(_ new: String, than current: String) -> Bool {
        let newParts = new.split(separator: ".").compactMap { Int($0) }
        let currentParts = current.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(newParts.count, currentParts.count) {
            let newPart = i < newParts.count ? newParts[i] : 0
            let currentPart = i < currentParts.count ? currentParts[i] : 0

            if newPart > currentPart {
                return true
            } else if newPart < currentPart {
                return false
            }
        }

        return false
    }

    // MARK: - Alerts

    private func showUpdateAlert(update: UpdateInfo) {
        let alert = NSAlert()
        alert.messageText = "Update Available"
        alert.informativeText = "TypeBetter \(update.version) is available. You have \(currentVersion).\n\n\(update.releaseNotes ?? "")"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Download")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: update.downloadURL ?? downloadPageURL) {
                NSWorkspace.shared.open(url)
            }
        }
    }

    private func showNoUpdateAlert() {
        let alert = NSAlert()
        alert.messageText = "You're Up to Date"
        alert.informativeText = "TypeBetter \(currentVersion) is the latest version."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func showErrorAlert(error: Error) {
        let alert = NSAlert()
        alert.messageText = "Update Check Failed"
        alert.informativeText = "Could not check for updates. Please try again later.\n\n\(error.localizedDescription)"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - Models

struct GitHubRelease: Codable {
    let tagName: String
    let name: String?
    let body: String?
    let htmlURL: String
    let assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlURL = "html_url"
        case assets
    }
}

struct GitHubAsset: Codable {
    let name: String
    let browserDownloadURL: String

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}

struct UpdateInfo {
    let version: String
    let build: String?
    let downloadURL: String?
    let releaseNotes: String?
    let minimumSystemVersion: String?
}

enum UpdateError: LocalizedError {
    case invalidURL
    case serverError
    case parseError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid update URL"
        case .serverError:
            return "Server returned an error"
        case .parseError:
            return "Could not parse update information"
        }
    }
}
