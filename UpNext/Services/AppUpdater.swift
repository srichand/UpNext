import Foundation
import Observation
import Sparkle

struct AppUpdaterConfiguration {
    let feedURL: String?
    let publicEDKey: String?

    init(infoDictionary: [String: Any]) {
        feedURL = Self.resolvedFeedURL(in: infoDictionary)
        publicEDKey = Self.resolvedPublicEDKey(in: infoDictionary)
    }

    var isConfigured: Bool {
        missingKeys.isEmpty
    }

    var missingKeys: [String] {
        var keys: [String] = []
        if feedURL == nil {
            keys.append("SUFeedURL")
        }
        if publicEDKey == nil {
            keys.append("SUPublicEDKey")
        }
        return keys
    }

    private static func resolvedString(for key: String, in infoDictionary: [String: Any]) -> String? {
        guard let rawValue = infoDictionary[key] as? String else {
            return nil
        }

        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else {
            return nil
        }

        guard !isPlaceholder(trimmedValue) else {
            return nil
        }

        return trimmedValue
    }

    private static func resolvedFeedURL(in infoDictionary: [String: Any]) -> String? {
        guard let value = resolvedString(for: "SUFeedURL", in: infoDictionary),
              let components = URLComponents(string: value),
              components.scheme?.lowercased() == "https",
              components.host?.isEmpty == false
        else {
            return nil
        }

        return value
    }

    private static func resolvedPublicEDKey(in infoDictionary: [String: Any]) -> String? {
        guard let value = resolvedString(for: "SUPublicEDKey", in: infoDictionary),
              let decodedKey = Data(base64Encoded: value),
              decodedKey.count == 32
        else {
            return nil
        }

        return value
    }

    private static func isPlaceholder(_ value: String) -> Bool {
        value.hasPrefix("$(") && value.hasSuffix(")")
    }
}

@MainActor
@Observable
final class AppUpdater {
    let configuration: AppUpdaterConfiguration

    @ObservationIgnored
    private let updaterController: SPUStandardUpdaterController?

    init(bundle: Bundle = .main) {
        configuration = AppUpdaterConfiguration(infoDictionary: bundle.infoDictionary ?? [:])

        if configuration.isConfigured {
            updaterController = SPUStandardUpdaterController(
                startingUpdater: true,
                updaterDelegate: nil,
                userDriverDelegate: nil
            )
        } else {
            updaterController = nil
        }
    }

    var isConfigured: Bool {
        configuration.isConfigured
    }

    var configurationMessage: String {
        guard !configuration.isConfigured else {
            return "UpNext is configured to check for updates automatically."
        }

        let missingKeysList = configuration.missingKeys.joined(separator: " and ")
        return "Set \(missingKeysList) for this build to enable Sparkle updates."
    }

    var automaticallyChecksForUpdates: Bool {
        get { updater?.automaticallyChecksForUpdates ?? false }
        set { updater?.automaticallyChecksForUpdates = newValue }
    }

    var automaticallyDownloadsUpdates: Bool {
        get { updater?.automaticallyDownloadsUpdates ?? false }
        set { updater?.automaticallyDownloadsUpdates = newValue }
    }

    var allowsAutomaticUpdates: Bool {
        updater?.allowsAutomaticUpdates ?? false
    }

    func checkForUpdates() {
        updater?.checkForUpdates()
    }

    private var updater: SPUUpdater? {
        updaterController?.updater
    }
}
