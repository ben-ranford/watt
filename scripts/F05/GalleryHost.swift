#if DEBUG
import AppKit
import SwiftUI

/// Standalone native smoke host: never starts WattApp or its UserDefaults/service graph.
/// Compiled by capture.sh, never a member of Watt's app/package targets.
@main
@MainActor
struct F05GalleryHost {
    static func main() throws {
        guard let selection = try FixtureLaunchSelection.parse(CommandLine.arguments),
              case .gallery(let fixture) = selection else {
            throw FixtureError.invalidArguments
        }
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let host = NSHostingView(rootView: WattComponentGallery(colorScheme: fixture == .dark ? .dark : .light)
            .environment(\.locale, Locale(identifier: "en_US")))
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: host.fittingSize),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.title = fixture.windowTitle
        window.appearance = NSAppearance(named: fixture == .dark ? .darkAqua : .aqua)
        window.contentView = host
        window.isReleasedWhenClosed = false
        window.center()
        window.orderFrontRegardless()
        withExtendedLifetime(window) { app.run() }
    }
}
#endif
