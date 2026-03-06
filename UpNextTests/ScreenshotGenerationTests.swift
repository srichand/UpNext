import AppKit
import SwiftUI
import UniformTypeIdentifiers
import XCTest
@testable import UpNextCore

@MainActor
final class ScreenshotGenerationTests: XCTestCase {
    private enum Appearance: String, CaseIterable {
        case light
        case dark

        var colorScheme: ColorScheme {
            switch self {
            case .light:
                return .light
            case .dark:
                return .dark
            }
        }
    }

    func testGenerateMenuBarPopoverScreenshots() throws {
        try capturePopover(
            scenario: .activeMeeting,
            appearance: .light
        )
        try capturePopover(
            scenario: .activeMeeting,
            appearance: .dark
        )
        try capturePopover(
            scenario: .packedDay,
            appearance: .light
        )
        try capturePopover(
            scenario: .emptyDay,
            appearance: .light
        )
    }

    private func capturePopover(
        scenario: MenuBarPreviewScenario,
        appearance: Appearance
    ) throws {
        let viewModel = MenuBarPreviewFactory.makeViewModel(scenario: scenario)
        let content = MenuBarPopover(viewModel: viewModel)
            .environment(\.colorScheme, appearance.colorScheme)
            .background(Color(nsColor: .windowBackgroundColor))

        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        renderer.proposedSize = ProposedViewSize(width: 300, height: nil)

        let nsImage = try XCTUnwrap(
            renderer.nsImage,
            "ImageRenderer failed for \(scenario.rawValue)-\(appearance.rawValue)"
        )
        let pngData = try pngData(from: nsImage)

        let filename = "popover-\(scenario.rawValue)-\(appearance.rawValue).png"
        let attachment = XCTAttachment(
            data: pngData,
            uniformTypeIdentifier: UTType.png.identifier
        )
        attachment.name = filename
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func pngData(from image: NSImage) throws -> Data {
        let tiffData = try XCTUnwrap(image.tiffRepresentation)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: tiffData))
        return try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
    }
}
