import SwiftUI
import AppKit

@main
struct UpNextApp: App {
    @State private var viewModel = MenuBarViewModel()

    init() {
        terminateExistingInstances()
    }

    var body: some Scene {
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

    private func terminateExistingInstances() {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return }
        let currentPID = ProcessInfo.processInfo.processIdentifier

        let existingInstances = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .filter { $0.processIdentifier != currentPID }

        for app in existingInstances {
            app.terminate()
        }
    }
}
