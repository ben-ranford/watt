import Foundation
import SwiftUI

struct StatusPanelView: View {
    let reading: PowerReading
    let onSettings: () -> Void
    let onQuit: () -> Void

    var body: some View {
        WattWindowScaffold {
            VStack(alignment: .leading, spacing: WattSpacing.sm) {
                Text(title)
                    .font(WattTypography.bodyEmphasized)
                    .foregroundStyle(.secondary)
                Text(reading.watts.map { String(format: "%+.1f W", $0) } ?? "—")
                    .font(WattTypography.largeTitle)
                if let detail = reading.detail {
                    Text("\(reading.batteryPercentage.map(String.init) ?? "—")% · \(detail)")
                        .font(WattTypography.subheadline)
                        .foregroundStyle(.secondary)
                }

                WattFormSection("Power") {
                    WattFormRow {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Charger input")
                            Text("96 W USB-C charger")
                                .font(WattTypography.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } trailing: {
                        Text("65.0 W")
                    }
                    Divider().padding(.horizontal, WattSpacing.md)
                    WattFormRow {
                        Text("System draw")
                    } trailing: {
                        Text("22.9 W")
                    }
                    Divider().padding(.horizontal, WattSpacing.md)
                    WattFormRow {
                        Text("Battery")
                    } trailing: {
                        Text(reading.watts.map { String(format: "%+.1f W", $0) } ?? "—")
                    }
                }

                WattFormSection("Components") {
                    ForEach(Array(reading.components.enumerated()), id: \.element.id) { index, component in
                        if index > 0 { Divider().padding(.horizontal, WattSpacing.md) }
                        WattFormRow {
                            Text(component.name)
                        } trailing: {
                            Text(String(format: "%.1f W", component.watts))
                        }
                    }
                }

                HStack {
                    Button("Settings…", action: onSettings)
                    Spacer()
                    Button("Quit Watt?", role: .destructive, action: onQuit)
                }
                .buttonStyle(.link)
                .font(WattTypography.body)
            }
            .padding(WattSpacing.xl)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Watt? live power panel")
    }

    private var title: String {
        switch reading.mode {
        case .charging: return "Charging"
        case .onBattery: return "On Battery"
        case .charged: return "Fully Charged"
        case .chargerInput: return "Charger Input"
        case .systemDraw: return "System Draw"
        case .perComponent: return "Components"
        case .noReading: return "No Reading Yet"
        }
    }
}
