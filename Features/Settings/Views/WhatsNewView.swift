import SwiftUI

/// One native window for the signed notes of the version that is running.
/// Appearance records that the notes were shown. Closing does not.
struct WhatsNewView: View {
    static func headline(version: String) -> String { "What’s New in Watt? \(version)" }
    static func summary(version: String) -> String { "You updated to \(version)." }
    static let closeTitle = "Done"

    let version: String
    let notes: String?
    var recordAppearance: () -> Void = {}
    var onClose: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                Image("WattAppIcon").resizable().frame(width: 64, height: 64)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(Self.headline(version: version))
                        .font(.body).fontWeight(.semibold)
                        .accessibilityIdentifier("whatsNew.title")
                        .accessibilityLabel(Self.headline(version: version))
                    Text(Self.summary(version: version))
                        .font(.subheadline).foregroundStyle(.secondary)
                        .accessibilityLabel(Self.summary(version: version))
                }
            }
            Text(UpdateAvailableContent.changesHeading).font(.headline)
                .accessibilityLabel(UpdateAvailableContent.changesHeading)
            ReleaseNotesBlock(notes: notes)
                .accessibilityIdentifier("whatsNew.notes")
            HStack {
                Spacer()
                Button(Self.closeTitle, action: onClose)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("whatsNew.done")
            }
        }
        .padding(20)
        .frame(width: 520)
        .frame(minHeight: 280)
        .onAppear(perform: recordAppearance)
    }
}

struct WhatsNewScene: View {
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        WhatsNewView(
            version: router.whatsNewPresentation?.version ?? router.currentAppVersion,
            notes: router.whatsNewPresentation?.notes,
            recordAppearance: { router.whatsNewDidAppear() },
            onClose: { dismiss() }
        )
    }
}
