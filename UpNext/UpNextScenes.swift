import SwiftUI

public struct UpNextScenes: Scene {
    @State private var viewModel = MenuBarViewModel()

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

        Window("Settings", id: "settings") {
            SettingsView(calendarManager: viewModel.calendarManager)
        }
    }
}
