import SwiftUI

public struct UpNextScenes: Scene {
    @State private var viewModel = MenuBarViewModel()
    @State private var appUpdater = AppUpdater()

    public init() {}

    public var body: some Scene {
        MenuBarExtra {
            MenuBarPopover(
                viewModel: viewModel,
                availableUpdateVersion: appUpdater.availableUpdateVersion,
                checkForUpdates: appUpdater.checkForUpdates
            )
        } label: {
            HStack(spacing: 4) {
                Image(systemName: appUpdater.isUpdateAvailable ? "arrow.down.circle.fill" : "calendar")
                Text(viewModel.menuBarText)
            }
            .accessibilityLabel(
                appUpdater.isUpdateAvailable
                    ? "UpNext update available. \(viewModel.menuBarText)"
                    : viewModel.menuBarText
            )
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(
                calendarManager: viewModel.calendarManager,
                appUpdater: appUpdater
            )
        }
    }
}
