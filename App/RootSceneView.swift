import SwiftUI

/// Separate app-update and helper-update content; macOS owns both scene chrome.
struct UpdateRootView: View {
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss
    var softwareUpdate = false
    var body: some View {
        if softwareUpdate {
            SoftwareUpdateContent(router: router, store: router.updates)
        } else {
            HelperUpdateSceneContent(prompt: router.helperUpdate)
                .onAppear {
                    router.helperUpdate.returnToPanel = { dismiss(); router.showStatusPanel() }
                    router.helperUpdate.presented = true
                }
        }
    }
}

private struct HelperUpdateSceneContent: View {
    @ObservedObject var prompt: HelperUpdatePrompt
    @Environment(\.scenePhase) private var phase
    var body: some View {
        VStack(spacing: WattSpacing.md) {
            Text(prompt.message)
            if case .success(.awaitingApproval) = prompt.outcome {
                Button("Check Approval") { Task { await prompt.update() } }
                    .disabled(prompt.busy)
            } else if case .failure = prompt.outcome {
                Button("Retry") { prompt.presented = true }.disabled(prompt.busy)
            }
        }
        .padding(WattSpacing.xl)
        .modifier(HelperUpdatePresentation(prompt: prompt))
        .onChange(of: phase) { value in
            if value == .active, case .success(.awaitingApproval) = prompt.outcome {
                Task { await prompt.update() }
            }
        }
    }
}


/// Widths the Software Update window uses. The offer is wider than checking
/// and download so the icon, notes, checkbox and three buttons keep a margin.
/// The window host has to adopt that width. A narrower host centers the offer
/// and cuts both the left and the right edges off.
enum SoftwareUpdateWindowMetrics {
    static let identifier = NSUserInterfaceItemIdentifier("watt.software-update")
    static let offerWidth: CGFloat = 520
    static let compactWidth: CGFloat = 420
    static let margin: CGFloat = 20
    static let iconSide: CGFloat = 64
    static let iconGap: CGFloat = 16
    static let minimumHeight: CGFloat = 146
    /// Title bar plus a gap so a tall note list stays on the visible screen.
    static let screenChrome: CGFloat = 64

    static var notesWidth: CGFloat { offerWidth - margin * 2 }
    static var headlineWidth: CGFloat { notesWidth - iconSide - iconGap }

    static func contentSize(fitting: CGSize, visibleHeight: CGFloat) -> NSSize {
        let width = max(1, fitting.width.rounded(.up))
        let limit = max(minimumHeight, visibleHeight - screenChrome)
        let height = min(max(minimumHeight, fitting.height.rounded(.up)), limit)
        return NSSize(width: width, height: height)
    }

    @MainActor
    static func measuredSize(of host: NSView) -> NSSize {
        host.layoutSubtreeIfNeeded()
        let fitted = host.fittingSize
        guard fitted.width > 1, fitted.height > 1 else {
            return NSSize(width: offerWidth, height: minimumHeight)
        }
        return fitted
    }

    @MainActor
    static func hostingView(in window: NSWindow) -> NSView? {
        if let scroll = window.contentView as? NSScrollView {
            return scroll.documentView
        }
        return window.contentView
    }

    /// Gives the SwiftUI tree the full fitted height when notes are taller than
    /// the screen, and scrolls vertically. Width stays the fitted width so a
    /// long line cannot be cut off on the side.
    @MainActor
    static func place(host: NSView, fitted: CGSize, in window: NSWindow, contentSize: NSSize) {
        let scrolls = fitted.height > contentSize.height + 1
        if scrolls {
            let scroll: NSScrollView
            if let existing = window.contentView as? NSScrollView, existing.documentView === host {
                scroll = existing
            } else {
                scroll = NSScrollView()
                scroll.borderType = .noBorder
                scroll.drawsBackground = false
                scroll.hasVerticalScroller = true
                scroll.hasHorizontalScroller = false
                scroll.autohidesScrollers = true
                scroll.scrollerStyle = .overlay
                scroll.automaticallyAdjustsContentInsets = false
                scroll.contentInsets = NSEdgeInsets()
                scroll.documentView = host
                window.contentView = scroll
            }
            let document = NSRect(origin: .zero, size: NSSize(width: contentSize.width, height: fitted.height))
            if host.frame.integral != document.integral { host.frame = document }
        } else if window.contentView !== host {
            window.contentView = host
        }
        let current = window.contentRect(forFrameRect: window.frame).size
        guard abs(current.width - contentSize.width) > 1 || abs(current.height - contentSize.height) > 1 else { return }
        window.setContentSize(contentSize)
    }

    @MainActor
    static func makeWindow<Content: View>(content: Content) -> NSWindow {
        let host = SoftwareUpdateHostingView(rootView: content)
        let fitted = measuredSize(of: host)
        let visible = NSScreen.main?.visibleFrame.height ?? 900
        let size = contentSize(fitting: fitted, visibleHeight: visible)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.titled, .closable, .miniaturizable],
                              backing: .buffered, defer: false)
        window.title = "Software Update"
        window.identifier = identifier
        window.isReleasedWhenClosed = false
        place(host: host, fitted: fitted, in: window, contentSize: size)
        return window
    }
}

/// Puts wrap opportunities into a long token, such as a URL or version, so the
/// line stays inside the update window. Short copy is returned unchanged.
enum SoftwareUpdateWrapping {
    static let tokenLimit = 28

    static func breakable(_ text: String, limit: Int = tokenLimit) -> String {
        guard limit > 1 else { return text }
        var result = String()
        result.reserveCapacity(text.count)
        var run = 0
        var inserted = false
        for character in text {
            result.append(character)
            if character.isWhitespace {
                run = 0
                continue
            }
            run += 1
            if run >= limit {
                result.append("\u{200B}")
                inserted = true
                run = 0
            }
        }
        return inserted ? result : text
    }

    static func breakable(_ source: AttributedString, limit: Int = tokenLimit) -> AttributedString {
        let raw = String(source.characters)
        guard breakable(raw, limit: limit) != raw else { return source }
        var result = AttributedString()
        var run = 0
        for slice in source.runs {
            for character in source[slice.range].characters {
                result.append(AttributedString(String(character), attributes: slice.attributes))
                if character.isWhitespace {
                    run = 0
                    continue
                }
                run += 1
                if run >= limit {
                    result.append(AttributedString("\u{200B}", attributes: slice.attributes))
                    run = 0
                }
            }
        }
        return result
    }

    static func measuredWidth(_ text: String, font: NSFont, wrapping: CGFloat) -> CGFloat {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byWordWrapping
        let rect = (text as NSString).boundingRect(
            with: NSSize(width: wrapping, height: 10_000),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font, .paragraphStyle: style])
        return ceil(rect.width)
    }
}

private extension View {
    func softwareUpdateWrapped() -> some View {
        fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    func softwareUpdateColumn(_ width: CGFloat, alignment: Alignment = .center) -> some View {
        frame(width: width, alignment: alignment)
            .preference(key: SoftwareUpdateWidthKey.self, value: width)
    }
}

/// The designed width of the visible update state. This is a constant, not the
/// window's current bounds, so a 420 point host can still learn that the offer
/// needs 520.
private struct SoftwareUpdateWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

@MainActor
protocol SoftwareUpdateSizingView: AnyObject {
    func softwareUpdateIdealSize(width: CGFloat) -> CGSize
}

final class SoftwareUpdateHostingView<Content: View>: NSHostingView<Content>, SoftwareUpdateSizingView {
    func softwareUpdateIdealSize(width: CGFloat) -> CGSize {
        // fittingSize on the live host repeats the window width, so a 420 point
        // window never discovers that the offer is 520. A new host is unconstrained.
        let probe = NSHostingView(rootView: rootView)
        probe.layoutSubtreeIfNeeded()
        let fitted = probe.fittingSize
        let resolvedWidth = fitted.width > 1 ? fitted.width : width
        let height = (fitted.height > 1 && fitted.height < 7_000) ? fitted.height : SoftwareUpdateWindowMetrics.minimumHeight
        return CGSize(width: resolvedWidth, height: height)
    }
}

@MainActor
final class SoftwareUpdateSizeRelay: ObservableObject {
    var width: CGFloat = 0
    var onChange: (@MainActor () -> Void)?
    func update(width: CGFloat) {
        guard width > 1 else { return }
        let changed = abs(self.width - width) > 0.5
        self.width = width
        if changed { onChange?() }
    }
}

/// Resizes the AppKit Software Update window when checking, the offer,
/// download and install swap content inside the same host.
private struct SoftwareUpdateWindowSizer: NSViewRepresentable {
    @ObservedObject var relay: SoftwareUpdateSizeRelay
    func makeNSView(context: Context) -> NSView { Marker() }
    func updateNSView(_ view: NSView, context: Context) {
        guard let marker = view as? Marker else { return }
        marker.latestWidth = relay.width
        relay.onChange = { [weak marker, weak relay] in
            marker?.latestWidth = relay?.width ?? 0
            marker?.apply()
        }
        marker.apply()
    }

    final class Marker: NSView {
        var latestWidth: CGFloat = 0
        private var applying = false
        override var intrinsicContentSize: NSSize { .zero }
        func apply() {
            guard !applying else { return }
            applying = true
            defer { applying = false }
            guard let window, window.identifier == SoftwareUpdateWindowMetrics.identifier,
                  let host = SoftwareUpdateWindowMetrics.hostingView(in: window) else { return }
            let width = latestWidth > 1 ? latestWidth : SoftwareUpdateWindowMetrics.measuredSize(of: host).width
            let fitted: CGSize
            if let measuring = host as? SoftwareUpdateSizingView {
                fitted = measuring.softwareUpdateIdealSize(width: width)
            } else {
                var measured = SoftwareUpdateWindowMetrics.measuredSize(of: host)
                measured.width = width
                fitted = measured
            }
            let visible = window.screen?.visibleFrame.height ?? NSScreen.main?.visibleFrame.height ?? 900
            let size = SoftwareUpdateWindowMetrics.contentSize(fitting: fitted, visibleHeight: visible)
            SoftwareUpdateWindowMetrics.place(host: host, fitted: fitted, in: window, contentSize: size)
        }
    }
}

// Keep the checking → available transition inside the same native window.
struct SoftwareUpdateContent: View {
    @ObservedObject var router: AppRouter
    @ObservedObject var store: UpdateStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var sizing = SoftwareUpdateSizeRelay()
    var body: some View {
        content
            .onPreferenceChange(SoftwareUpdateWidthKey.self) { sizing.update(width: $0) }
            .frame(minWidth: SoftwareUpdateWindowMetrics.compactWidth,
                   minHeight: SoftwareUpdateWindowMetrics.minimumHeight)
            .background(SoftwareUpdateWindowSizer(relay: sizing))
            .background(UpToDatePresentation(router: router) { dismiss() })
            .background(CouldntCheckPresentation(router: router) { dismiss() })
            .onDisappear { router.closeUpdatePresentation() }
    }

    private static func isClosingAfterUpdate(_ state: UpdateState) -> Bool {
        switch state {
        case .completed, .handoffAccepted: return true
        default: return false
        }
    }

    @ViewBuilder private var content: some View {
        if router.upToDatePresented || router.couldntCheckPresented {
            Color.clear
        } else if case .adminRequired = store.state {
            VStack(alignment: .leading, spacing: 16) {
                Text("The update is ready. Administrator installation is required to update Watt? and its helper together. Use the Watt? installer, then launch the installed app.")
                    .softwareUpdateWrapped()
                Button("Discard Download") { Task { if await router.cancelUpdateDownload() { dismiss() } } }
            }.padding(SoftwareUpdateWindowMetrics.margin).softwareUpdateColumn(SoftwareUpdateWindowMetrics.compactWidth)
        } else if Self.isClosingAfterUpdate(store.state) {
            Text("Watt? will close while the update finishes.").softwareUpdateWrapped()
                .padding(SoftwareUpdateWindowMetrics.margin).softwareUpdateColumn(SoftwareUpdateWindowMetrics.compactWidth)
        } else if router.isUnattendedInstall, let version = router.downloadVersion {
            UpdateDownloadingContent(router: router, store: store, version: version)
        } else if router.pendingProtectedReceipt != nil {
            VStack(alignment: .leading, spacing: 16) {
                Text("An update needs recovery. Resume to verify the installer result and relaunch Watt?.")
                    .softwareUpdateWrapped()
                Button("Resume Install and Relaunch") { Task { await router.resumeProtectedUpdate() } }
                    .disabled(router.resumingProtectedUpdate)
            }.padding(SoftwareUpdateWindowMetrics.margin).softwareUpdateColumn(SoftwareUpdateWindowMetrics.compactWidth)
        } else if let receipt = router.readyReceipt, let version = router.downloadVersion {
            UpdateReadyContent(router: router, store: store, version: version, receipt: receipt)
        } else if let version = router.downloadVersion {
            UpdateDownloadingContent(router: router, store: store, version: version)
        } else if case .available(let version) = store.state {
            UpdateAvailableContent(router: router, store: store, version: version)
        } else {
            UpdateCheckingContent(router: router, store: store)
        }
    }
}

struct UpdateAvailableContent: View {
    static func headline(version: String) -> String { "Watt? \(version) is out" }
    static func summary(installedVersion: String) -> String { "You have \(installedVersion). Here’s what changed." }
    static let changesHeading = "What changed"

    @ObservedObject var router: AppRouter
    @ObservedObject var store: UpdateStore
    let version: String
    @Environment(\.dismiss) private var dismiss
    @State private var automaticUpdates: Bool

    init(router: AppRouter, store: UpdateStore, version: String) {
        self.router = router
        self.store = store
        self.version = version
        _automaticUpdates = State(initialValue: store.installFutureUpdatesAutomatically)
    }
    @State private var choiceFailed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: SoftwareUpdateWindowMetrics.iconGap) {
                Image("WattAppIcon").resizable()
                    .frame(width: SoftwareUpdateWindowMetrics.iconSide, height: SoftwareUpdateWindowMetrics.iconSide)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(SoftwareUpdateWrapping.breakable(Self.headline(version: version)))
                        .font(.body).fontWeight(.semibold)
                        .softwareUpdateWrapped()
                        .accessibilityLabel(Self.headline(version: version))
                    Text(SoftwareUpdateWrapping.breakable(Self.summary(installedVersion: router.currentAppVersion)))
                        .font(.subheadline).foregroundStyle(.secondary)
                        .softwareUpdateWrapped()
                        .accessibilityLabel(Self.summary(installedVersion: router.currentAppVersion))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text(Self.changesHeading).font(.headline)
                .accessibilityLabel(Self.changesHeading)
            ReleaseNotesBlock(notes: router.promptNotes(version: version))
            Toggle("Install future updates automatically", isOn: $automaticUpdates)
                .toggleStyle(.checkbox)
            HStack {
                Button("Skip This Version") { choose(.skip) }
                Spacer()
                Button("Remind Me Later") { choose(.remindLater) }
                    .keyboardShortcut(.cancelAction)
                Button("Install Update") { choose(.install) }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .buttonStyle(.bordered)
            .disabled(router.updateOfferIntent != nil)
            if store.persistenceFailure != nil {
                Text("Couldn’t save your choice. Try again.").font(.caption)
            } else if choiceFailed {
                Text("Couldn’t apply your choice. Try again.").font(.caption)
            }
        }
        .padding(SoftwareUpdateWindowMetrics.margin)
        .softwareUpdateColumn(SoftwareUpdateWindowMetrics.offerWidth)
        .frame(minHeight: 334)
    }

    private func choose(_ action: UpdateOfferAction) {
        if action == .install {
            choiceFailed = !router.installOfferedUpdate(version: version, generation: store.generation,
                                                         automaticUpdates: automaticUpdates)
        } else {
            choiceFailed = !router.chooseUpdateOffer(action, version: version, generation: store.generation,
                                                     automaticUpdates: automaticUpdates)
            if !choiceFailed { dismiss() }
        }
    }
}

struct ReleaseNotesBlock: View {
    let notes: String?
    @Environment(\.wattMotionSuppressed) private var motionSuppressed
    @State private var revealed = false

    var body: some View {
        if let text = UpdateReleaseNotes.promptText(notes) {
            noteRows(UpdateReleaseNotes.blocks(text))
        } else {
            Text(UpdateReleaseNotes.unavailable)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(UpdateReleaseNotes.unavailable)
        }
    }

    private func noteRows(_ blocks: [UpdateReleaseNotes.Block]) -> some View {
        VStack(alignment: .leading, spacing: WattSpacing.sm) {
            ForEach(blocks) { block in
                noteRow(block)
                    .padding(.top, block.isHeader && block.id > 0 ? WattSpacing.xs : 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .opacity(motionSuppressed ? 1 : (revealed ? 1 : 0))
        .accessibilityHidden(!motionSuppressed && !revealed)
        .wattAnimate(.reveal, value: revealed, enabled: !motionSuppressed)
        .onAppear { revealed = true }
    }

    @ViewBuilder private func noteRow(_ block: UpdateReleaseNotes.Block) -> some View {
        let row = rowBody(block)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(block.spoken)
        if block.isHeader {
            row.accessibilityAddTraits(.isHeader)
        } else {
            row
        }
    }

    @ViewBuilder private func rowBody(_ block: UpdateReleaseNotes.Block) -> some View {
        if let marker = block.marker {
            HStack(alignment: .firstTextBaseline, spacing: WattSpacing.sm) {
                Text(marker)
                    .font(WattTypography.body)
                    .foregroundStyle(.secondary)
                noteText(block)
            }
        } else {
            noteText(block)
        }
    }

    private func noteText(_ block: UpdateReleaseNotes.Block) -> some View {
        Text(SoftwareUpdateWrapping.breakable(block.inline))
            .font(noteFont(block.kind))
            .foregroundStyle(.primary)
            .multilineTextAlignment(.leading)
            .softwareUpdateWrapped()
            .textSelection(.enabled)
    }

    private func noteFont(_ kind: UpdateReleaseNotes.Block.Kind) -> Font {
        switch kind {
        case .heading(let level) where level < 3:
            return WattTypography.headline
        case .heading:
            return WattTypography.bodyEmphasized
        case .bullet, .paragraph:
            return WattTypography.body
        }
    }
}

// J10.5: the OS owns progress, buttons, labels and window chrome.
struct UpdateReadyContent: View {
    static let title = "Ready to install"
    static let footnote = "Watt? quits, updates and comes back to the menu bar. About 5 seconds."
    static let progress = 1.0
    @ObservedObject var router: AppRouter
    @ObservedObject var store: UpdateStore
    let version: String
    let receipt: OperationReceipt
    @Environment(\.dismiss) private var dismiss
    @State private var presentation: UUID?
    @State private var generation: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: SoftwareUpdateWindowMetrics.iconGap) {
                Image("WattAppIcon").resizable()
                    .frame(width: SoftwareUpdateWindowMetrics.iconSide, height: SoftwareUpdateWindowMetrics.iconSide)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(Self.title).font(WattTypography.headline).softwareUpdateWrapped()
                    ProgressView(value: Self.progress).progressViewStyle(.linear)
                        .accessibilityLabel("Download complete")
                    Text(Self.footnote).font(WattTypography.footnote).foregroundStyle(.secondary)
                        .softwareUpdateWrapped()
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 10) {
                Spacer()
                Button("Later") { choose(.later) }
                    .buttonStyle(.bordered).keyboardShortcut(.cancelAction)
                Button("Install and Relaunch") { choose(.installAndRelaunch) }
                    .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            }.font(WattTypography.bodyEmphasized).disabled(router.readyIntent != nil)
            if let message = router.readyInstallFailure?.message {
                Text(SoftwareUpdateWrapping.breakable(message))
                    .font(WattTypography.footnote).foregroundStyle(.secondary)
                    .softwareUpdateWrapped()
                    .accessibilityLabel(message)
            }
            if store.persistenceFailure != nil {
                Text("Couldn’t save your choice. Try again.").font(WattTypography.footnote)
                    .foregroundStyle(.secondary)
            }
        }.padding(SoftwareUpdateWindowMetrics.margin)
            .softwareUpdateColumn(SoftwareUpdateWindowMetrics.compactWidth)
            .frame(minHeight: SoftwareUpdateWindowMetrics.minimumHeight)
        .onAppear {
            generation = store.generation
            presentation = router.beginReadyPresentation()
        }
        .onDisappear { router.closeReadyPresentation(presentation) }
        .onChange(of: router.readyInstallFailure?.id) { _ in
            guard router.readyInstallFailure != nil else { return }
            generation = store.generation
            presentation = router.beginReadyPresentation()
        }
    }

    private func choose(_ action: AppRouter.ReadyIntent.Action) {
        guard let presentation, let generation else { return }
        if router.chooseReadyUpdate(action, version: version, generation: generation,
                                    receipt: receipt, presentation: presentation) { dismiss() }
    }
}

// Native controls and chrome follow the system, including across OS versions.
struct UpdateDownloadingContent: View {
    @ObservedObject var router: AppRouter
    @ObservedObject var store: UpdateStore
    let version: String
    @Environment(\.dismiss) private var dismiss
    @State private var cancelling = false
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: SoftwareUpdateWindowMetrics.iconGap) {
                Image("WattAppIcon").resizable()
                    .frame(width: SoftwareUpdateWindowMetrics.iconSide, height: SoftwareUpdateWindowMetrics.iconSide)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(SoftwareUpdateWrapping.breakable("Downloading Watt? \(version)…"))
                        .font(WattTypography.bodyEmphasized)
                        .softwareUpdateWrapped()
                        .accessibilityLabel("Downloading Watt? \(version)…")
                    ProgressView(value: progress).progressViewStyle(.linear)
                        .accessibilityLabel("Download progress")
                    Text(router.downloadProgress?.label ?? "Preparing download…")
                        .font(WattTypography.footnote).foregroundStyle(.secondary)
                        .softwareUpdateWrapped()
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                Spacer()
                Button("Cancel") {
                    cancelling = true
                    Task {
                        if await router.cancelUpdateDownload() { dismiss() }
                        cancelling = false
                    }
                }.buttonStyle(.bordered).keyboardShortcut(.cancelAction).disabled(cancelling)
            }
            if store.persistenceFailure != nil {
                Text("Couldn’t save download state. Try Cancel again.").font(.caption)
            } else if case .failed = store.state {
                Text("Download stopped. Cancel to clean up before retrying.").font(.caption)
            }
        }.padding(SoftwareUpdateWindowMetrics.margin)
            .softwareUpdateColumn(SoftwareUpdateWindowMetrics.compactWidth)
            .frame(minHeight: SoftwareUpdateWindowMetrics.minimumHeight)
        .onDisappear {
            if case .downloading = store.state { Task { _ = await router.cancelUpdateDownload() } }
        }
    }
    private var progress: Double {
        if case .downloading(let value) = store.state { return value }
        if case .staged = store.state { return 1 }
        return router.downloadProgress?.fraction ?? 0
    }
}

// J10.2: macOS owns window chrome, progress animation and button appearance.
struct UpdateCheckingContent: View {
    let router: AppRouter
    @ObservedObject var store: UpdateStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: SoftwareUpdateWindowMetrics.iconGap) {
                Image("WattAppIcon")
                    .resizable()
                    .frame(width: SoftwareUpdateWindowMetrics.iconSide, height: SoftwareUpdateWindowMetrics.iconSide)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Checking for updates…")
                        .font(WattTypography.bodyEmphasized)
                        .softwareUpdateWrapped()
                    ProgressView()
                        .progressViewStyle(.linear)
                        .accessibilityLabel("Checking for updates…")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                Spacer()
                Button("Cancel") {
                    if router.cancelUpdateCheck() { dismiss() }
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.bordered)
            }
            if store.persistenceFailure != nil {
                Text("Couldn’t save cancellation. Try Cancel again.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(SoftwareUpdateWindowMetrics.margin)
        .softwareUpdateColumn(SoftwareUpdateWindowMetrics.compactWidth, alignment: .leading)
        .frame(minHeight: SoftwareUpdateWindowMetrics.minimumHeight)
        .onChange(of: store.state) { state in
            // Keep native result alerts in this scene.
            if state != .checking && !router.upToDatePresented && !router.couldntCheckPresented {
                if case .available = state { return }
                dismiss()
            }
        }
        .onDisappear { _ = router.cancelUpdateCheck() }
    }
}

/// AppKit owns the app icon, typography, default button, material and standalone chrome.
/// SwiftUI's sheet-style alert omits the app icon on some supported macOS versions.
private struct UpToDatePresentation: NSViewRepresentable {
    @ObservedObject var router: AppRouter
    let dismiss: () -> Void

    final class Coordinator {
        var scheduled = false
        var attempts = 0
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ view: NSView, context: Context) {
        guard router.upToDatePresented, !context.coordinator.scheduled else { return }
        context.coordinator.scheduled = true
        let generation = router.upToDateGeneration
        DispatchQueue.main.async {
            defer { context.coordinator.scheduled = false }
            guard router.upToDatePresented, router.upToDateGeneration == generation else { return }
            guard let window = view.window, window.isVisible else {
                context.coordinator.attempts += 1
                guard context.coordinator.attempts < 30 else { return }
                DispatchQueue.main.async { self.updateNSView(view, context: context) }
                return
            }
            context.coordinator.attempts = 0
            let alert = UpToDateAlert.make(message: router.upToDateMessage)
            window.orderOut(nil)
            _ = alert.runModal()
            router.dismissUpToDate()
            dismiss()
        }
    }
}

enum UpToDateAlert {
    @MainActor static func make(message: String) -> NSAlert {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: primary)
        return alert
    }
    static func message(version: String) -> String { "\(version) is the latest." }
    static let title = "You’re up to date"
    static let primary = "OK"
}

/// No custom icon, material, appearance or geometry: this is the macOS alert component.
enum CouldntCheckAlert {
    static let title = "Couldn’t check for updates"
    static let offlineMessage = "No connection right now. Watt? checks again later on its own."
    static func message(for reason: ServiceFailure) -> String {
        switch reason {
        case .network, .timedOut, .disconnected:
            return offlineMessage
        case .untrustedIdentity:
            return "The update couldn’t be verified."
        case .invalidData:
            return "The update information couldn’t be read."
        case .incompatibleVersion:
            return "This Mac can’t run the published update."
        default:
            return "Watt? couldn’t finish the update check."
        }
    }
    @MainActor static func make(reason: ServiceFailure = .network) -> NSAlert {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = message(for: reason)
        alert.addButton(withTitle: "Try Again")
        alert.addButton(withTitle: "OK")
        return alert
    }
}

private struct CouldntCheckPresentation: NSViewRepresentable {
    @ObservedObject var router: AppRouter
    let dismiss: () -> Void
    final class Coordinator {
        var scheduled = false
        var attempts = 0
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ view: NSView, context: Context) {
        guard router.couldntCheckPresented, let token = router.checkFailurePresentation,
              !context.coordinator.scheduled else { return }
        context.coordinator.scheduled = true
        DispatchQueue.main.async {
            defer { context.coordinator.scheduled = false }
            guard router.couldntCheckPresented, router.checkFailurePresentation == token else { return }
            guard let window = view.window, window.isVisible else {
                context.coordinator.attempts += 1
                guard context.coordinator.attempts < 30 else { return }
                DispatchQueue.main.async { self.updateNSView(view, context: context) }
                return
            }
            context.coordinator.attempts = 0
            window.orderOut(nil)
            let response = CouldntCheckAlert.make(reason: token.reason).runModal()
            guard router.couldntCheckPresented, router.checkFailurePresentation == token else { return }
            if response == .alertFirstButtonReturn {
                // Restore the host even on a failed persistence write, so retry remains possible.
                window.makeKeyAndOrderFront(nil)
                if !router.retryCouldntCheck(token) {
                    DispatchQueue.main.async { updateNSView(view, context: context) }
                }
            } else if router.dismissCouldntCheck(token) {
                dismiss()
            }
        }
    }
}

#if DEBUG
@MainActor
enum J107FixtureLaunch {
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J10.7/base"
        }
        return false
        #endif
    }
    static func makeWindow() -> NSWindow {
        let service = FakeUpdateService()
        service.availableVersion = .failure(.network)
        let router = AppRouter(updateService: service)
        let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Software Update"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: UpdateRootView(softwareUpdate: true).environmentObject(router))
        window.center()
        _ = router.checkForUpdatesFromMenu(presentationID: router.beginMenuSetupPresentation())
        return window
    }
}

@MainActor
enum J106FixtureLaunch {
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J10.6/base"
        }
        return false
        #endif
    }
    static func makeWindow() -> NSWindow {
        let service = FakeUpdateService()
        service.availableVersion = .success(nil)
        let router = AppRouter(updateService: service)
        let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Software Update"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: UpdateRootView(softwareUpdate: true).environmentObject(router))
        window.center()
        _ = router.checkForUpdatesFromMenu(presentationID: router.beginMenuSetupPresentation())
        return window
    }
}

@MainActor
enum J102FixtureLaunch {
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J10.2/base"
        }
        return false
        #endif
    }

    static func makeWindow() -> NSWindow {
        let router = AppRouter(updateService: CheckingFixtureService())
        _ = router.checkForUpdatesFromMenu(presentationID: router.beginMenuSetupPresentation())
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 146),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Software Update"
        window.appearance = NSAppearance(named: .aqua)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: UpdateRootView(softwareUpdate: true).environmentObject(router))
        window.center()
        return window
    }
}

@MainActor
enum J103FixtureLaunch {
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J10.3/base"
        }
        return false
        #endif
    }
    static func makeWindow() -> NSWindow {
        let service = FakeUpdateService()
        service.availableVersion = .success("1.1")
        service.offeredNotes = """
        ### Fixes

        * The update window shows the notes shipped with this release.
        """
        let router = AppRouter(updateService: service)
        _ = router.checkForUpdatesFromMenu(presentationID: router.beginMenuSetupPresentation())
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 334),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Software Update"
        window.appearance = NSAppearance(named: .aqua)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: UpdateRootView(softwareUpdate: true).environmentObject(router))
        window.center()
        return window
    }
}

@MainActor
enum J104FixtureLaunch {
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J10.4/base"
        }
        return false
        #endif
    }
    static func makeWindow() -> NSWindow {
        let store = UpdateStore()
        store.accept(.checking, generation: store.generation)
        store.accept(.available(version: "1.1"), generation: store.generation)
        let router = AppRouter(updateService: DownloadingFixtureService(), updates: store)
        router.startUpdateDownload(version: "1.1", generation: store.generation)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 146),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Software Update"
        window.appearance = NSAppearance(named: .aqua)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: UpdateRootView(softwareUpdate: true).environmentObject(router))
        window.center()
        return window
    }
}

@MainActor
enum J105FixtureLaunch {
    static var requested: Bool {
        #if SWIFT_PACKAGE
        false
        #else
        if case .story(let selection) = try? FixtureLaunchSelection.parse(ProcessInfo.processInfo.arguments) {
            return selection.stableID == "J10.5/base"
        }
        return false
        #endif
    }
    static func makeWindow() -> NSWindow {
        let store = UpdateStore()
        store.accept(.checking, generation: store.generation)
        store.accept(.available(version: "1.1"), generation: store.generation)
        let router = AppRouter(updateService: FakeUpdateService(), updates: store)
        router.startUpdateDownload(version: "1.1", generation: store.generation)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 146),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Software Update"
        window.appearance = NSAppearance(named: .aqua)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: UpdateRootView(softwareUpdate: true).environmentObject(router))
        window.center()
        return window
    }
}

@MainActor
private final class DownloadingFixtureService: CheckingFixtureService {
    override func download(version: String, receipt: OperationReceipt,
                           progress: @escaping @MainActor (UpdateDownloadProgress) -> Void) async -> ServiceOutcome<UpdateState> {
        progress(UpdateDownloadProgress(received: 2_100_000, total: 4_200_000))
        _ = await check()
        return .failure(.cancelled)
    }
    override func cancel(receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> { .success(.failed(.cancelled, receipt)) }
    override func discard(receipt: OperationReceipt) async -> ServiceOutcome<OperationReceipt> { .success(receipt) }
}

/// Suspends without a fabricated update result; no endpoint, disk or installation effects.
@MainActor
private class CheckingFixtureService: UpdateService {
    func check() async -> ServiceOutcome<String?> {
        do {
            while true { try await Task.sleep(nanoseconds: 60_000_000_000) }
        } catch { return .failure(.cancelled) }
    }
    func download(version: String, receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> { .failure(.unknownStatus) }
    func download(version: String, receipt: OperationReceipt,
                  progress: @escaping @MainActor (UpdateDownloadProgress) -> Void) async -> ServiceOutcome<UpdateState> {
        await download(version: version, receipt: receipt)
    }
    func install(receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> { .failure(.unknownStatus) }
    func recover(receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> { .failure(.unknownStatus) }
    func cancel(receipt: OperationReceipt) async -> ServiceOutcome<UpdateState> { .failure(.unknownStatus) }
    func discard(receipt: OperationReceipt) async -> ServiceOutcome<OperationReceipt> { .failure(.unknownStatus) }
}
#endif
