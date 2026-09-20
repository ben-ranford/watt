import Foundation
import SwiftUI

struct MenuBarStatusLabel: View {
    let reading: PowerReading

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "bolt.fill")
            Text(reading.watts.map { String(format: "%+.1f W", $0) } ?? "—")
        }
        .font(WattTypography.bodyEmphasized)
        .accessibilityLabel("Watt? power reading")
        .accessibilityValue(reading.watts.map { String(format: "%+.1f watts", $0) } ?? "No reading yet")
    }
}
