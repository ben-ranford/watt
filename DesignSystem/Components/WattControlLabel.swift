import AppKit
import SwiftUI

/// SwiftUI draws the visible title in a separate text node and leaves the backing
/// control's AX title and description empty. System Events then reports
/// `missing value` for both name and description. Stamp the real control.
struct WattControlLabel: NSViewRepresentable {
    var label: String

    func makeNSView(context: Context) -> Marker { Marker() }

    func updateNSView(_ view: Marker, context: Context) {
        view.label = label
        view.schedule()
    }

    final class Marker: NSView {
        var label = ""
        override var intrinsicContentSize: NSSize { .zero }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            schedule()
        }
        func schedule() {
            DispatchQueue.main.async { [weak self] in self?.apply() }
        }
        func apply() {
            guard !label.isEmpty else { return }
            var view: NSView? = superview
            var hops = 0
            while let current = view, hops < 10 {
                if let control = current as? NSControl {
                    control.setAccessibilityLabel(label)
                    control.setAccessibilityHelp(label)
                    control.accessibilitySetOverrideValue(label, forAttribute: .title)
                    control.accessibilitySetOverrideValue(label, forAttribute: .description)
                    return
                }
                view = current.superview
                hops += 1
            }
        }
    }
}

extension View {
    func wattControlLabel(_ label: String) -> some View {
        accessibilityLabel(label)
            .accessibilityHint(label)
            .background(WattControlLabel(label: label))
    }
}
