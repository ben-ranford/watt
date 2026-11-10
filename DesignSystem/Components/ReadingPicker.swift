import AppKit
import SwiftUI

/// Native radio-group selection. The caller owns availability and persistence policy.
struct ReadingPicker: View {
    @Binding var selection: WattDisplayMode
    struct Option: Identifiable, Equatable {
        let mode: WattDisplayMode
        let description: String?
        var id: WattDisplayMode { mode }

        static let defaults = WattDisplayMode.allCases.map {
            Option(mode: $0, description: ReadingPicker.description(for: $0))
        }
    }

    var unavailableModes: Set<WattDisplayMode> = []

    var options: [Option] = Option.defaults

    @ViewBuilder
    var body: some View {
        if unavailableModes.isEmpty {
            swiftUIRadioGroup
        } else {
            // macOS SwiftUI's radioGroup does not propagate per-option `isEnabled` to
            // the native AX radio buttons when the option contains custom content.
            // Keep the standard Picker for the normal path and use AppKit's native
            // radio controls for capability-gated options.
            NativeReadingRadioGroup(selection: $selection,
                                    unavailableModes: unavailableModes,
                                    options: options)
        }
    }

    private var swiftUIRadioGroup: some View {
        Picker("Menu bar reading", selection: availableSelection) {
            ForEach(options) { option in
                let mode = option.mode
                VStack(alignment: .leading, spacing: WattSpacing.xxs) {
                    Text(mode.rawValue)
                        .font(WattTypography.body)
                    if let description = option.description {
                        Text(description)
                            .font(WattTypography.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, WattSpacing.xxs)
                .tag(mode)
                .disabled(unavailableModes.contains(mode))
            }
        }
        .pickerStyle(.radioGroup)
        .labelsHidden()
        .font(WattTypography.body)
    }

    var availableSelection: Binding<WattDisplayMode> {
        Binding(
            get: { selection },
            set: { mode in
                if options.contains(where: { $0.mode == mode }), !unavailableModes.contains(mode) {
                    selection = mode
                }
            }
        )
    }

    nonisolated private static func description(for mode: WattDisplayMode) -> String? {
        switch mode {
        case .delta: return "How fast the battery fills or drains."
        case .charger: return "What the charger is giving."
        case .draw: return "What your Mac uses right now."
        case .components: return "CPU/GPU estimates. Needs administrator approval."
        case .iconOnly: return nil
        }
    }

}

/// AppKit-backed fallback for radio groups with unavailable options. SwiftUI's
/// radioGroup remains the default, but its macOS bridge currently exposes nested
/// custom option content as enabled even when the option's environment is disabled.
private struct NativeReadingRadioGroup: NSViewRepresentable {
    @Binding var selection: WattDisplayMode
    let unavailableModes: Set<WattDisplayMode>
    let options: [ReadingPicker.Option]

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection, unavailableModes: unavailableModes, options: options)
    }

    func makeNSView(context: Context) -> NSStackView {
        context.coordinator.makeView()
    }

    func updateNSView(_ view: NSStackView, context: Context) {
        context.coordinator.selection = $selection
        context.coordinator.unavailableModes = unavailableModes
        context.coordinator.options = options
        context.coordinator.refresh()
    }

    @MainActor
    final class Coordinator: NSObject {
        var selection: Binding<WattDisplayMode>
        var unavailableModes: Set<WattDisplayMode>
        var options: [ReadingPicker.Option]
        private weak var stack: NSStackView?
        private var buttons: [NSButton] = []

        init(selection: Binding<WattDisplayMode>,
             unavailableModes: Set<WattDisplayMode>,
             options: [ReadingPicker.Option]) {
            self.selection = selection
            self.unavailableModes = unavailableModes
            self.options = options
        }

        func makeView() -> NSStackView {
            let stack = NSStackView()
            stack.orientation = .vertical
            stack.alignment = .leading
            stack.spacing = WattSpacing.xs
            stack.setAccessibilityElement(true)
            stack.setAccessibilityRole(.group)
            stack.setAccessibilityLabel("Menu bar reading")
            self.stack = stack
            rebuild()
            return stack
        }

        func refresh() {
            guard stack != nil else { return }
            if buttons.count != options.count || buttons.map(\.title) != options.map({ $0.mode.rawValue }) {
                rebuild()
                return
            }
            for (button, option) in zip(buttons, options) {
                button.isEnabled = !unavailableModes.contains(option.mode)
                button.state = selection.wrappedValue == option.mode ? .on : .off
            }
        }

        private func rebuild() {
            guard let stack else { return }
            stack.arrangedSubviews.forEach { stack.removeArrangedSubview($0); $0.removeFromSuperview() }
            buttons = []
            for option in options {
                let row = NSStackView()
                row.orientation = .vertical
                row.alignment = .leading
                row.spacing = WattSpacing.xxs

                let button = NSButton(title: option.mode.rawValue, target: self, action: #selector(select(_:)))
                button.setButtonType(.radio)
                button.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
                button.identifier = NSUserInterfaceItemIdentifier(option.mode.rawValue)
                button.setAccessibilityLabel(option.mode.rawValue)
                button.setAccessibilityHelp(option.description)
                button.setAccessibilityIdentifier("reading-picker.\(option.mode.rawValue.lowercased())")
                button.isEnabled = !unavailableModes.contains(option.mode)
                button.state = selection.wrappedValue == option.mode ? .on : .off
                button.translatesAutoresizingMaskIntoConstraints = false
                buttons.append(button)
                row.addArrangedSubview(button)

                if let description = option.description {
                    let detail = NSTextField(labelWithString: description)
                    detail.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
                    detail.textColor = .secondaryLabelColor
                    detail.lineBreakMode = .byWordWrapping
                    detail.maximumNumberOfLines = 0
                    detail.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
                    detail.translatesAutoresizingMaskIntoConstraints = false
                    row.addArrangedSubview(detail)
                    detail.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 22).isActive = true
                }
                stack.addArrangedSubview(row)
            }
        }

        @objc private func select(_ sender: NSButton) {
            guard sender.isEnabled,
                  let mode = WattDisplayMode(rawValue: sender.identifier?.rawValue ?? ""),
                  !unavailableModes.contains(mode) else {
                refresh()
                return
            }
            selection.wrappedValue = mode
            refresh()
        }
    }
}
