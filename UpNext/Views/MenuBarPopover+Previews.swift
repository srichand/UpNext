#if DEBUG
import SwiftUI

@MainActor
struct MenuBarPopover_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MenuBarPopover(viewModel: MenuBarPreviewFactory.makeViewModel(scenario: .activeMeeting))
                .previewDisplayName("Active Meeting")

            MenuBarPopover(viewModel: MenuBarPreviewFactory.makeViewModel(scenario: .packedDay))
                .previewDisplayName("Packed Day")

            MenuBarPopover(viewModel: MenuBarPreviewFactory.makeViewModel(scenario: .emptyDay))
                .previewDisplayName("Empty Day")

            MenuBarPopover(viewModel: MenuBarPreviewFactory.makeViewModel(scenario: .activeMeeting))
                .environment(\.colorScheme, .dark)
                .previewDisplayName("Active Meeting (Dark)")
        }
    }
}
#endif
