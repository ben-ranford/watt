import AppKit
@preconcurrency import ScreenCaptureKit
import ImageIO
import UniformTypeIdentifiers

// Bounded evidence helper for C03. It captures only visible, app-owned menu
// windows from the supplied Watt PID. It never requests TCC, captures the
// desktop, injects input, or changes production menu rendering.
_ = NSApplication.shared
let targetPID = Int32(CommandLine.arguments.dropFirst().first ?? "0") ?? 0
let output = URL(fileURLWithPath: CommandLine.arguments.dropFirst(2).first ?? "/tmp/watt-c03-screencapturekit")
try? FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

let semaphore = DispatchSemaphore(value: 0)
let deadline = Date().addingTimeInterval(12)

func save(_ image: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, 1, nil
    ) else {
        throw NSError(domain: "Watt.C03.ScreenCaptureKit", code: 1)
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "Watt.C03.ScreenCaptureKit", code: 2)
    }
}

DispatchQueue.global(qos: .userInitiated).async {
    Task {
    var seen = Set<CGWindowID>()
    var records: [[String: Any]] = []

    while Date() < deadline && records.count < 2 {
        if let content = try? await SCShareableContent.current {
            let candidates = content.windows
                .filter {
                    $0.isOnScreen &&
                    $0.owningApplication?.processID == targetPID &&
                    $0.frame.width > 120 && $0.frame.height > 100
                }
                .sorted { $0.frame.origin.x < $1.frame.origin.x }

            for window in candidates where !seen.contains(window.windowID) {
                seen.insert(window.windowID)
                let filter = SCContentFilter(desktopIndependentWindow: window)
                let scale = max(1, Double(SCShareableContent.info(for: filter).pointPixelScale))
                let configuration = SCStreamConfiguration()
                configuration.width = max(1, Int(window.frame.width * scale))
                configuration.height = max(1, Int(window.frame.height * scale))
                configuration.showsCursor = false
                let name = "sck-menu-\(records.count).png"
                let destination = output.appendingPathComponent(name)

                do {
                    let image = try await SCScreenshotManager.captureImage(
                        contentFilter: filter, configuration: configuration
                    )
                    try save(image, to: destination)
                    let screenName = "sck-screen-\(records.count).png"
                    let screenConfiguration = SCScreenshotConfiguration()
                    screenConfiguration.width = configuration.width
                    screenConfiguration.height = configuration.height
                    screenConfiguration.showsCursor = false
                    let screenOutput = try await SCScreenshotManager.captureScreenshot(
                        rect: window.frame, configuration: screenConfiguration
                    )
                    if let screenImage = screenOutput.sdrImage {
                        try save(screenImage, to: output.appendingPathComponent(screenName))
                    }
                    records.append([
                        "windowID": window.windowID,
                        "title": window.title ?? "",
                        "windowLayer": window.windowLayer,
                        "frame": NSStringFromRect(window.frame),
                        "scale": scale,
                        "capture": name,
                        "screenCapture": screenName,
                        "width": image.width,
                        "height": image.height
                    ])
                    print("captured \(window.windowID) \(image.width)x\(image.height) \(name)")
                } catch {
                    print("capture-error \(window.windowID): \(error)")
                }
            }
        }

        if records.count < 2 {
            try? await Task.sleep(for: .milliseconds(150))
        }
    }

    let metadata: [String: Any] = [
        "pid": targetPID,
        "method": "ScreenCaptureKit SCScreenshotManager desktop-independent window",
        "screenRecordingPrompted": false,
        "records": records
    ]
    if let data = try? JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys]) {
        try? data.write(to: output.appendingPathComponent("capture.json"))
    }
    semaphore.signal()
    }
}

semaphore.wait()
