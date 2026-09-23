import AppKit

final class Delegate: NSObject, NSApplicationDelegate {
    var item: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.item = item
        item.button?.title = "PROBE"
        item.button?.toolTip = "probe"
        item.button?.setAccessibilityLabel("probe status item")
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
            NSApp.terminate(nil)
        }
    }
}

let application = NSApplication.shared
let delegate = Delegate()
application.delegate = delegate
application.run()
