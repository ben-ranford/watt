// Isolated feasibility probe, not linked into Watt. No private APIs/global input/AX access.
import AppKit

@MainActor final class Probe: NSObject, NSMenuDelegate {
    var events: [String] = []
    @objc func invoke(_ sender: NSMenuItem) { events.append("action: \(sender.title)") }
    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        events.append("highlight \(menu.title): \(item?.title ?? "none")")
    }
    func menuWillOpen(_ menu: NSMenu) { events.append("open: \(menu.title)") }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
app.appearance = NSAppearance(named: .darkAqua)
let custom = CommandLine.arguments[1] == "custom"
let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
let probe = Probe()
let anchor = NSWindow(contentRect: NSRect(x: 600, y: 500, width: 50, height: 30),
                      styleMask: [.borderless], backing: .buffered, defer: false)
anchor.orderFrontRegardless()
let menu = NSMenu(title: "main")
menu.minimumWidth = 230
menu.font = .systemFont(ofSize: 13, weight: .regular)
menu.delegate = probe
let submenu = NSMenu(title: "submenu")
submenu.minimumWidth = 190
submenu.font = menu.font
submenu.delegate = probe
@MainActor func row(_ title: String, key: String = "") -> NSMenuItem {
    let item = NSMenuItem(title: title, action: #selector(Probe.invoke(_:)), keyEquivalent: key)
    item.target = probe
    if custom {
        let view = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 230, height: 22))
        view.material = .menu
        view.blendingMode = .withinWindow
        view.state = .active
        view.autoresizingMask = [.width]
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.frame = NSRect(x: 36, y: 3, width: 180, height: 16)
        view.addSubview(label)
        item.view = view
    }
    return item
}
let parent = row("Show in Menu Bar")
parent.submenu = submenu
menu.addItem(parent)
let delta = row("Delta")
delta.state = .on
submenu.addItem(delta)
submenu.addItem(row("Charger"))
menu.addItem(.separator())
menu.addItem(row("Settings…", key: ","))
// Test the public shortcut dispatcher separately from menu tracking.
let shortcut = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: .command,
    timestamp: 0, windowNumber: 0, context: nil, characters: ",", charactersIgnoringModifiers: ",",
    isARepeat: false, keyCode: 43)!
probe.events.append("shortcut dispatched: \(menu.performKeyEquivalent(with: shortcut))")
@MainActor func later(_ delay: Double, _ body: @escaping @MainActor () -> Void) {
    let timer = Timer(timeInterval: delay, repeats: false) { _ in MainActor.assumeIsolated { body() } }
    RunLoop.main.add(timer, forMode: .eventTracking)
}
@MainActor func key(_ code: UInt16, _ character: String) {
    let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
        timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: anchor.windowNumber,
        context: nil, characters: character, charactersIgnoringModifiers: character,
        isARepeat: false, keyCode: code)!
    app.postEvent(event, atStart: false)
}
later(0.2) { key(125, "\u{f701}") } // down
later(0.4) { key(124, "\u{f703}") } // right: native submenu attachment
later(0.7) {
    for (index, window) in app.windows.filter({ $0.isVisible && $0 !== anchor }).enumerated() {
        if let view = window.contentView, let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
            view.cacheDisplay(in: view.bounds, to: bitmap)
            try! bitmap.representation(using: .png, properties: [:])!.write(
                to: output.appendingPathComponent("\(custom ? "custom" : "native")-\(index).png"))
        }
    }
    probe.events.append("selected main: \(menu.highlightedItem?.title ?? "none"); submenu: \(submenu.highlightedItem?.title ?? "none")")
}
later(0.9) { key(125, "\u{f701}") }
later(1.1) { key(36, "\r") }
later(1.5) { probe.events.append("fallback cancel"); menu.cancelTracking() }
menu.popUp(positioning: nil, at: .zero, in: anchor.contentView)
let result: [String: Any] = ["customView": custom, "events": probe.events,
    "titleRetained": parent.title, "submenuAttached": parent.submenu === submenu,
    "deltaStateRetained": delta.state == .on,
    "limitation": "Isolated minimal custom views, not Watt; no VoiceOver audit or WindowServer composite",
    "os": ProcessInfo.processInfo.operatingSystemVersionString]
try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
    .write(to: output.appendingPathComponent("\(custom ? "custom" : "native").json"))
anchor.close()
