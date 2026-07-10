import SwiftUI

public struct UpNextScenes: Scene {
    @State private var viewModel = MenuBarViewModel()
    @State private var appUpdater = AppUpdater()

    public init() {}

    public var body: some Scene {
        MenuBarExtra {
            MenuBarPopover(viewModel: viewModel)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                Text(viewModel.menuBarText)
            }
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
