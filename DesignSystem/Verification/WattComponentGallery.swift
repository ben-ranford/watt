#if DEBUG
import SwiftUI

/// Debug component gallery. No service graph, storage, clock or polling.
/// F01 hosts one instance per appearance in a key window to capture the native focus ring.
struct WattComponentGallery: View {
    var colorScheme: ColorScheme = .light
    @State private var reading: WattDisplayMode = .delta
    @State private var updateInterval = "Every 2 seconds"
    @State private var showSymbol = true
    @State private var enabled = true
    @State private var focusText = "Keyboard focus"
    @State private var showsConfirmation = false
    @State private var confirmationResult = "No action taken"
    @FocusState private var fieldFocused: Bool

    var body: some View {
        Form {
            Text("Watt? Components")
                .font(WattTypography.title)
                .accessibilityAddTraits(.isHeader)
            Text(colorScheme == .dark ? "Dark appearance · component specimens" : "Light appearance · component specimens")
                .font(WattTypography.footnote)
                .foregroundStyle(WattColors.secondaryLabel)

            Section("Actions") {
                WattFormRow {
                    WattActionButton(title: "Back") {}
                } trailing: {
                    WattActionButton(title: "Continue", style: .prominent) {}
                }
                WattFormRow {
                    WattActionButton(title: "Disabled") {}.disabled(true)
                } trailing: {
                    WattActionButton(title: "Disabled primary", style: .prominent) {}.disabled(true)
                }
                WattFormRow {
                    WattActionButton(title: "Remove…", style: .destructive) {
                        showsConfirmation = true
                    }
                    .accessibilityIdentifier("gallery.remove")
                } trailing: {
                    WattActionButton(title: "Disabled removal", style: .destructive) {}.disabled(true)
                }
            }

            ReadingPicker(selection: $reading, unavailableModes: [.components])
                .accessibilityIdentifier("gallery.reading")

            Section("Settings row specimens") {
                WattFormRow {
                    Text("Show")
                } trailing: {
                    Picker("Show", selection: $reading) {
                        ForEach(WattDisplayMode.allCases, id: \.self) { mode in
                            Text(mode.title).accessibilityLabel(mode.title).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                }
                WattFormRow {
                    Text("Show symbol")
                } trailing: {
                    Toggle("Show symbol", isOn: $showSymbol)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .labelsHidden()
                }
                WattFormRow {
                    WattRowLabel(title: "Update", subtitle: "Faster uses a little more energy.")
                } trailing: {
                    Picker("Update interval", selection: $updateInterval) {
                        Text("Every 2 seconds").tag("Every 2 seconds")
                        Text("Every 5 seconds").tag("Every 5 seconds")
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                }
                WattFormRow {
                    WattRowLabel(title: SettingsHelperRows.helperTitle, subtitle: SettingsHelperRows.privacy)
                } trailing: {
                    WattActionButton(title: "Remove…") { showsConfirmation = true }
                        .accessibilityIdentifier("gallery.neutral-remove")
                }
            }

            Section("Control states") {
                WattFormRow {
                    Toggle("Selected", isOn: $enabled)
                } trailing: {
                    Toggle("Disabled selected", isOn: .constant(true)).disabled(true)
                }
                WattFormRow {
                    Text("Unselected switch")
                } trailing: {
                    Toggle("Unselected switch", isOn: .constant(false))
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .labelsHidden()
                }
                TextField("Focused field", text: $focusText)
                    .textFieldStyle(.roundedBorder)
                    .focused($fieldFocused)
                    .accessibilityIdentifier("gallery.focus")
                WattFormRow {
                    Text("Progress")
                } trailing: {
                    ProgressView("Download", value: 0.5, total: 1)
                        .accessibilityValue("50 percent")
                }
            }
            Text("Ready — success").foregroundStyle(WattColors.success)
            Text("Unable to continue — failure").foregroundStyle(WattColors.destructive)
            Text(confirmationResult).font(WattTypography.footnote)
        }
        .font(WattTypography.body)
        .formStyle(.grouped)
        .frame(width: WattSpacing.settingsWidth, height: 1000)
        .environment(\.locale, Locale(identifier: "en_US"))
        .environment(\.colorScheme, colorScheme)
        .task {
            await Task.yield()
            fieldFocused = true
        }
        .alert("Remove demonstration item?", isPresented: $showsConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                confirmationResult = "Demonstration item removed"
            }
        } message: {
            Text("Gallery only. No helper, files or preferences are changed.")
        }
    }
}

struct WattComponentGallery_Previews: PreviewProvider {
    static var previews: some View {
        WattComponentGallery(colorScheme: .light).previewDisplayName("Light")
        WattComponentGallery(colorScheme: .dark).previewDisplayName("Dark")
    }
}
/// Content-only reference specimens: no onboarding routes or real settings mutations.
struct WattReferenceSpecimen: View {
    enum Kind: String, CaseIterable { case reading, settings }
    let kind: Kind
    let colorScheme: ColorScheme
    @State private var reading: WattDisplayMode = .delta
    @State private var showSymbol = true
    @State private var smoothing = true
    @State private var precision = "42.1 W"
    @State private var components = "CPU, GPU"
    @State private var update = "Every 2 seconds"
    @State private var confirmsRemoval = false
    @State private var removed = false

    static let readingOptions: [ReadingPicker.Option] = [
        .init(mode: .delta, description: "How fast the battery fills or drains. +42.1 W"),
        .init(mode: .charger, description: "What the charger is giving. 65 W"),
        .init(mode: .draw, description: "What your Mac uses right now. 22.9 W"),
        .init(mode: .components, description: "CPU, GPU and the rest. Needs the helper — next step.")
    ]

    var body: some View {
        Group {
            switch kind {
            case .reading: readingContent
            case .settings: settingsContent
            }
        }
        .font(WattTypography.body)
        .environment(\.locale, Locale(identifier: "en_US"))
        .environment(\.colorScheme, colorScheme)
        .alert("Remove demonstration helper?", isPresented: $confirmsRemoval) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) { removed = true }
        } message: {
            Text("Specimen only. No helper, files or preferences are changed.")
        }
    }

    private var readingContent: some View {
        VStack(spacing: 16) {
            Text("Pick one number for the menu bar")
                .font(WattTypography.title).accessibilityAddTraits(.isHeader)
            Text("Change it any time. Right-click Watt? or open Settings.")
                .foregroundStyle(WattColors.secondaryLabel)
            ReadingPicker(selection: $reading, options: Self.readingOptions)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
            HStack {
                Spacer()
                WattActionButton(title: "Back") {}
                WattActionButton(title: "Continue", style: .prominent) {}
            }
        }
        .padding(.horizontal, 32)
        .padding(.top, 32)
        .padding(.bottom, 24)
        .frame(width: WattSpacing.onboardingWidth)
    }

    private var settingsContent: some View {
        Form {
            Section {
                WattFormRow { Text("Show") } trailing: {
                    Picker("Show", selection: $reading) {
                        ForEach(WattDisplayMode.allCases, id: \.self) { mode in
                            Text(mode.title).accessibilityLabel(mode.title).tag(mode)
                        }
                    }.labelsHidden().pickerStyle(.menu).fixedSize()
                }
                WattFormRow { Text("Show symbol") } trailing: {
                    miniSwitch("Show symbol", value: $showSymbol)
                }
                WattFormRow { Text("Precision") } trailing: {
                    choice("Precision", value: $precision, options: ["42.1 W", "42 W"])
                }
                WattFormRow {
                    WattRowLabel(title: "Components", subtitle: "In Components mode. Two fit; more crowd the menu bar.")
                } trailing: { choice("Components", value: $components, options: ["CPU, GPU", "CPU"]) }
            } header: {
                Text("Menu Bar")
            } footer: {
                Text("Menu bar full? Choose Icon and Watt? stays put.")
            }
            Section("Readings") {
                WattFormRow {
                    WattRowLabel(title: "Update", subtitle: "Faster uses a little more energy.")
                } trailing: { choice("Update", value: $update, options: ["Every 2 seconds", "Every 5 seconds"]) }
                WattFormRow {
                    WattRowLabel(title: "Smooth readings", subtitle: smoothing ? "On — averages the last 5 seconds, so the number doesn’t jump." : "Off — shows the latest reading.")
                } trailing: { miniSwitch("Smooth readings", value: $smoothing) }
            }
            Section(SettingsHelperRows.helperTitle) {
                WattFormRow {
                    WattRowLabel(title: SettingsHelperRows.statusTitle, subtitle: removed ? "Demonstration helper removed." : SettingsHelperRows.statusSubtitle)
                } trailing: { Text(removed ? "Off" : "On").foregroundStyle(WattColors.secondaryLabel) }
                WattFormRow {
                    WattRowLabel(title: SettingsHelperRows.helperTitle, subtitle: SettingsHelperRows.privacy)
                } trailing: {
                    WattActionButton(title: "Remove…") { confirmsRemoval = true }
                        .disabled(removed).accessibilityIdentifier("specimen.neutral-remove")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: WattSpacing.settingsWidth, height: 620)
    }

    private func miniSwitch(_ label: String, value: Binding<Bool>) -> some View {
        Toggle(label, isOn: value).toggleStyle(.switch).controlSize(.mini).labelsHidden()
    }

    private func choice(_ label: String, value: Binding<String>, options: [String]) -> some View {
        Picker(label, selection: value) {
            ForEach(options, id: \.self) { Text($0).tag($0) }
        }.labelsHidden().pickerStyle(.menu).fixedSize()
    }
}
#endif
