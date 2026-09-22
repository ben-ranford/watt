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

    var body: some View {
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
        case .components: return "CPU, GPU and the rest. Needs the helper — next step."
        case .iconOnly: return nil
        }
    }

}
