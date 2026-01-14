import Foundation
import AppKit
import Sparkle

// MARK: - Update Service

class UpdateService: NSObject, ObservableObject {
    static let shared = UpdateService()

    // Sparkle updater controller
    private var updaterController: SPUStandardUpdaterController!

    @Published var canCheckForUpdates = true

    override private init() {
        super.init()
        // Initialize Sparkle updater
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var currentBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    // MARK: - Check for Updates (User initiated)

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    // MARK: - Check for Updates in Background

    func checkForUpdatesInBackground(showAlertIfAvailable: Bool = true) {
        // Sparkle handles background checks automatically based on SUScheduledCheckInterval
        // This is called on app launch for an immediate check
        updaterController.updater.checkForUpdatesInBackground()
    }
}
