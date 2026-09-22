import AppKit
import SwiftUI

/// Standalone DEBUG evidence host; it renders production views, not picture replicas.
@main @MainActor
struct NativeStylingCaptureHost {
    static func settle() {
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.25))
    }

    static func accessibility(_ value: Any, depth: Int = 0) -> [[String: Any]] {
        guard depth < 16, let element = value as? NSAccessibilityProtocol else { return [] }
        var record: [String: Any] = [
            "class": String(describing: type(of: value)),
            "role": element.accessibilityRole()?.rawValue ?? "",
            "label": element.accessibilityLabel() ?? "",
            "enabled": element.isAccessibilityEnabled()
        ]
        if let id = element.accessibilityIdentifier() { record["identifier"] = id }
        if let value = element.accessibilityValue() { record["value"] = String(describing: value) }
        let children = element.accessibilityChildren() ?? []
        return [record] + children.flatMap { accessibility($0, depth: depth + 1) }
    }

    static func descendants(_ view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap(descendants)
    }

    static func main() throws {
        let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.finishLaunching()
        app.activate(ignoringOtherApps: true)
        for scheme in [ColorScheme.light, .dark] {
            let mode = scheme == .light ? "light" : "dark"
            let views = [
                ("reading", AnyView(WattReferenceSpecimen(kind: .reading, colorScheme: scheme)), CGSize(width: 480, height: 340)),
                ("settings-shell", AnyView(SettingsRootView()), CGSize(width: 540, height: 320)),
                ("settings-shell-bottom", AnyView(SettingsRootView()), CGSize(width: 540, height: 320)),
                ("settings", AnyView(WattReferenceSpecimen(kind: .settings, colorScheme: scheme)), CGSize(width: 580, height: 620)),
                ("controls", AnyView(WattComponentGallery(colorScheme: scheme)), CGSize(width: 580, height: 1000)),
                ("controls-bottom", AnyView(WattComponentGallery(colorScheme: scheme)), CGSize(width: 580, height: 1000))
            ]
            for (name, view, size) in views {
                let host = NSHostingView(rootView: view.environment(\.colorScheme, scheme)
                    .environment(\.locale, Locale(identifier: "en_US")))
                let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                    styleMask: [.titled, .closable], backing: .buffered, defer: false)
                window.title = "Watt native styling — \(name) — \(mode)"
                window.appearance = NSAppearance(named: scheme == .light ? .aqua : .darkAqua)
                window.isReleasedWhenClosed = false
                window.contentView = host
                window.center()
                window.makeKeyAndOrderFront(nil)
                settle()
                host.layoutSubtreeIfNeeded()
                if name.hasSuffix("-bottom"), let scroll = descendants(host).compactMap({ $0 as? NSScrollView }).first,
                   let document = scroll.documentView {
                    document.scroll(NSPoint(x: 0, y: document.bounds.height))
                    settle()
                }
                window.displayIfNeeded()
                let includesWindowFrame = name == "reading" || name.hasPrefix("settings-shell")
                let captureView = includesWindowFrame ? (host.superview ?? host) : host
                guard let bitmap = captureView.bitmapImageRepForCachingDisplay(in: captureView.bounds) else {
                    throw NSError(domain: "NativeCapture", code: 1)
                }
                captureView.cacheDisplay(in: captureView.bounds, to: bitmap)
                guard let png = bitmap.representation(using: .png, properties: [:]) else {
                    throw NSError(domain: "NativeCapture", code: 2)
                }
                let basename = "\(name)-\(mode)"
                try png.write(to: output.appendingPathComponent(basename + ".png"))
                let metadata: [String: Any] = [
                    "sample": basename, "captureBounds": NSStringFromRect(captureView.bounds),
                    "includesWindowFrame": includesWindowFrame, "nativeContentBounds": NSStringFromRect(host.bounds),
                    "widthPixels": bitmap.pixelsWide, "heightPixels": bitmap.pixelsHigh,
                    "pixelsPerPoint": Double(bitmap.pixelsWide) / host.bounds.width,
                    "os": ProcessInfo.processInfo.operatingSystemVersionString,
                    "capture": "in-process NSView.cacheDisplay; actual SwiftUI/AppKit controls",
                    "capturedAt": ISO8601DateFormatter().string(from: Date()),
                    "accessibility": accessibility(host),
                    "limitations": "Reading and settings shell include the native NSWindow frame; other samples are content-only. Inactive window; active accent/focus and WindowServer vibrancy not verified. In-process accessibility traversal is incomplete, not VoiceOver/AX interaction sign-off.",
                    "windowStyleMask": window.styleMask.rawValue,
                    "windowClass": String(describing: type(of: window)),
                    "isKeyWindow": window.isKeyWindow,
                    "visualPass": false
                ]
                try JSONSerialization.data(withJSONObject: metadata, options: [.sortedKeys, .prettyPrinted])
                    .write(to: output.appendingPathComponent(basename + ".json"))
                window.close()
                print("Captured \(basename): \(bitmap.pixelsWide)x\(bitmap.pixelsHigh)")
            }
        }
    }
}
