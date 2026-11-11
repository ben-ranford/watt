import AppKit
import SwiftUI
import XCTest
@testable import Watt

private struct ScreenshotError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

/// Renders the pages and README screenshots from the SwiftUI views.
/// Sample readings only: this test never captures the desktop.
@MainActor
final class SiteScreenshotTests: XCTestCase {
    private let scale: CGFloat = 2
    private let menuBarSize = CGSize(width: 112, height: 28)
    private let panelSize = CGSize(width: WattSpacing.panelWidth, height: WattSpacing.panelHeight)
    private let settingsSize = CGSize(width: WattSpacing.settingsWidth, height: WattSpacing.settingsContentHeight)
    private let whatsNewSize = CGSize(width: 520, height: 360)

    func testRendersCommittedSiteScreenshots() throws {
        let reading = siteReading()
        let schemes: [(String, ColorScheme, NSAppearance.Name)] = [
            ("light", .light, .aqua),
            ("dark", .dark, .darkAqua),
        ]
        let export = exportDirectory()
        try FileManager.default.createDirectory(at: export, withIntermediateDirectories: true)
        var rendered: [String: Data] = [:]
        for (name, scheme, appearance) in schemes {
            let preferences = PreferencesStore(storage: InMemoryStorage())
            preferences.displayMode = .draw
            let menu = MenuBarStatusLabel(reading: reading, preferences: preferences)
            rendered["menu-bar-\(name)"] = try snapshot(menu, size: menuBarSize, scheme: scheme, appearance: appearance)

            let panel = StatusPanelView(
                reading: reading,
                chargerDescription: "96 W USB-C charger",
                onSettings: {},
                onQuit: {}
            )
            rendered["panel-\(name)"] = try snapshot(panel, size: panelSize, scheme: scheme, appearance: appearance)

            let settingsPreferences = PreferencesStore(storage: InMemoryStorage())
            let router = AppRouter(updateService: FakeUpdateService())
            router.settingsHelperSetup.unavailableReason = .installationRequired
            router.settingsHelperSetup.installHelper = { () async -> ServiceFailure? in nil }
            let settings = SettingsRootView()
                .environmentObject(settingsPreferences)
                .environmentObject(router)
                .environmentObject(PowerReadingStore.preview)
            rendered["settings-\(name)"] = try snapshot(settings, size: settingsSize, scheme: scheme, appearance: appearance)
            rendered["whats-new-\(name)"] = try snapshot(whatsNewSample(), size: whatsNewSize, scheme: scheme, appearance: appearance)
        }

        for (name, data) in rendered.sorted(by: { $0.key < $1.key }) {
            let url = export.appendingPathComponent(name + ".png")
            try data.write(to: url)
            let again = try snapshot(named: name, reading: reading)
            XCTAssertEqual(again, data, "\(name) did not render twice to the same PNG")
        }

        #if !SWIFT_PACKAGE
        let committed = committedDirectory()
        let committedNames = [
            "menu-bar-light", "menu-bar-dark",
            "panel-light", "panel-dark",
            "settings-light", "settings-dark",
        ]
        for name in committedNames {
            let url = committed.appendingPathComponent(name + ".png")
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                          "Missing \(url.path). Copy \(export.path)/\(name).png here after the macOS render.")
            let stored = try Data(contentsOf: url)
            XCTAssertEqual(stored, rendered[name],
                           "\(name).png does not match the SwiftUI render in \(export.path)")
        }
        #endif
    }

    private func whatsNewSample() -> WhatsNewView {
        WhatsNewView(
            version: "1.3.0",
            notes: "### Changes\n\n* Updates roll out gradually\n* What’s New appears once after you update",
            recordAppearance: {},
            onClose: {}
        )
    }

    private func siteReading() -> PowerReading {
        let started = Date(timeIntervalSince1970: 1_700_000_000)
        let pair = ComponentEstimatePair(
            acquisitionID: UUID(uuidString: "8C3E0B2A-7A11-4D5E-9C10-6B2F4A8D11E0")!,
            startedAt: started,
            duration: 1,
            cpuWatts: 9.8,
            gpuWatts: 4.1,
            provenance: "site-screenshot"
        )
        return PowerReading(
            mode: .charging,
            watts: 42.1,
            batteryPercentage: 64,
            detail: "full in about 38 min",
            components: pair.components,
            timestamp: started,
            batteryState: .charging,
            capabilities: .init(battery: .available, charger: .available, systemDraw: .available, components: .available),
            source: .fixture,
            chargerWatts: 65,
            systemWatts: 22.9,
            componentEstimate: pair
        )
    }

    /// Second render for the stability check. Rebuilds the same fixture view.
    private func snapshot(named name: String, reading: PowerReading) throws -> Data {
        let scheme: ColorScheme = name.hasSuffix("dark") ? .dark : .light
        let appearance: NSAppearance.Name = scheme == .dark ? .darkAqua : .aqua
        if name.hasPrefix("menu-bar") {
            let preferences = PreferencesStore(storage: InMemoryStorage())
            preferences.displayMode = .draw
            return try snapshot(MenuBarStatusLabel(reading: reading, preferences: preferences),
                                size: menuBarSize, scheme: scheme, appearance: appearance)
        }
        if name.hasPrefix("whats-new") {
            return try snapshot(whatsNewSample(), size: whatsNewSize, scheme: scheme, appearance: appearance)
        }
        if name.hasPrefix("panel") {
            return try snapshot(
                StatusPanelView(reading: reading, chargerDescription: "96 W USB-C charger", onSettings: {}, onQuit: {}),
                size: panelSize, scheme: scheme, appearance: appearance
            )
        }
        let preferences = PreferencesStore(storage: InMemoryStorage())
        let router = AppRouter(updateService: FakeUpdateService())
        router.settingsHelperSetup.unavailableReason = .installationRequired
        router.settingsHelperSetup.installHelper = { () async -> ServiceFailure? in nil }
        return try snapshot(
            SettingsRootView()
                .environmentObject(preferences)
                .environmentObject(router)
                .environmentObject(PowerReadingStore.preview),
            size: settingsSize, scheme: scheme, appearance: appearance
        )
    }

    private func snapshot<V: View>(_ view: V, size: CGSize, scheme: ColorScheme, appearance: NSAppearance.Name) throws -> Data {
        let previous = NSApp.appearance
        NSApp.appearance = NSAppearance(named: appearance)
        defer { NSApp.appearance = previous }

        let root = view
            .environment(\.colorScheme, scheme)
            .environment(\.locale, Locale(identifier: "en_US"))
            .frame(width: size.width, height: size.height)
            .background(Color(nsColor: .windowBackgroundColor))
        let host = NSHostingView(rootView: root)
        host.appearance = NSAppearance(named: appearance)
        host.frame = NSRect(origin: .zero, size: size)
        host.wantsLayer = true

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.appearance = host.appearance
        window.isReleasedWhenClosed = false
        window.contentView = host
        host.frame = window.contentView?.bounds ?? host.frame
        window.orderFrontRegardless()
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        host.layoutSubtreeIfNeeded()
        window.displayIfNeeded()

        let pixelsWide = Int((size.width * scale).rounded())
        let pixelsHigh = Int((size.height * scale).rounded())
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelsWide,
            pixelsHigh: pixelsHigh,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw ScreenshotError("Could not allocate a bitmap")
        }
        bitmap.size = size
        guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw ScreenshotError("Could not build a graphics context")
        }
        host.displayIgnoringOpacity(host.bounds, in: context)
        window.orderOut(nil)
        let colors = distinctColors(in: bitmap)
        guard colors > 8 else {
            throw ScreenshotError("Render is blank at \(size) (\(colors) colors)")
        }
        guard let encoded = bitmap.representation(using: .png, properties: [:]) else {
            throw ScreenshotError("Could not encode PNG")
        }
        let png = canonicalPNG(encoded)
        XCTAssertEqual(pngSize(png), CGSize(width: pixelsWide, height: pixelsHigh))
        return png
    }

    private func distinctColors(in bitmap: NSBitmapImageRep) -> Int {
        guard let raw = bitmap.bitmapData, bitmap.bitsPerPixel >= 24 else { return 0 }
        let bytesPerPixel = bitmap.bitsPerPixel / 8
        var seen = Set<UInt32>()
        var y = 0
        while y < bitmap.pixelsHigh {
            var x = 0
            while x < bitmap.pixelsWide {
                let offset = y * bitmap.bytesPerRow + x * bytesPerPixel
                if offset >= 0, offset + 2 < bitmap.bytesPerRow * bitmap.pixelsHigh {
                    let pixel = (UInt32(raw[offset]) << 16) | (UInt32(raw[offset + 1]) << 8) | UInt32(raw[offset + 2])
                    seen.insert(pixel)
                    if seen.count > 12 { return seen.count }
                }
                x += 4
            }
            y += 4
        }
        return seen.count
    }

    private func canonicalPNG(_ data: Data) -> Data {
        let signature = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        guard data.starts(with: signature) else { return data }
        var output = signature
        let bytes = [UInt8](data)
        var index = 8
        while index + 12 <= bytes.count {
            let length = (Int(bytes[index]) << 24) | (Int(bytes[index + 1]) << 16)
                | (Int(bytes[index + 2]) << 8) | Int(bytes[index + 3])
            guard length >= 0, index + 12 + length <= bytes.count else { break }
            let type = Data(bytes[(index + 4)..<(index + 8)])
            let end = index + 12 + length
            if type == Data("IHDR".utf8) || type == Data("PLTE".utf8)
                || type == Data("IDAT".utf8) || type == Data("IEND".utf8) {
                output.append(contentsOf: bytes[index..<end])
            }
            if type == Data("IEND".utf8) { break }
            index = end
        }
        return output
    }

    private func pngSize(_ data: Data) -> CGSize? {
        guard data.count >= 24 else { return nil }
        let bytes = [UInt8](data)
        guard Data(bytes[0..<8]) == Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) else { return nil }
        let width = (Int(bytes[16]) << 24) | (Int(bytes[17]) << 16) | (Int(bytes[18]) << 8) | Int(bytes[19])
        let height = (Int(bytes[20]) << 24) | (Int(bytes[21]) << 16) | (Int(bytes[22]) << 8) | Int(bytes[23])
        return CGSize(width: width, height: height)
    }

    private func exportDirectory() -> URL {
        if let raw = ProcessInfo.processInfo.environment["WATT_SCREENSHOT_DIR"], !raw.isEmpty {
            return URL(fileURLWithPath: raw, isDirectory: true)
        }
        return URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("site-screenshots", isDirectory: true)
    }

    private func committedDirectory() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("docs/screenshots", isDirectory: true)
    }
}
