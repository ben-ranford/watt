import AppKit

/// External product addresses. The app opens these with NSWorkspace.
enum AppLinks {
    static let githubSponsors: URL = {
        guard let url = URL(string: "https://github.com/sponsors/ben-ranford") else {
            preconditionFailure("GitHub Sponsors URL is invalid")
        }
        return url
    }()
}

/// Standard About panel. The status-item menu’s About Watt? action presents this.
@MainActor
enum AboutPanel {
    static let sponsorTitle = "Sponsor"

    static func show() {
        NSApplication.shared.orderFrontStandardAboutPanel(options: [
            .credits: credits()
        ])
        attachSponsorLinkHandler()
        Task { @MainActor in
            attachSponsorLinkHandler()
        }
    }

    /// Centered Sponsor credit. The about panel draws it under the version.
    static func credits() -> NSAttributedString {
        let text = NSMutableAttributedString(string: sponsorTitle)
        let range = NSRange(location: 0, length: (sponsorTitle as NSString).length)
        text.addAttribute(.link, value: AppLinks.githubSponsors, range: range)
        text.addAttribute(.font, value: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize), range: range)
        text.addAttribute(.foregroundColor, value: NSColor.linkColor, range: range)
        text.addAttribute(.underlineStyle, value: NSNumber(value: NSUnderlineStyle.single.rawValue), range: range)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        text.addAttribute(.paragraphStyle, value: paragraph, range: range)
        return text
    }

    /// Opens the sponsors page when the credit’s link is the configured URL.
    @discardableResult
    static func handleLinkClick(_ link: Any) -> Bool {
        handleLinkClick(link, open: { NSWorkspace.shared.open($0) })
    }

    @discardableResult
    static func handleLinkClick(_ link: Any, open: @MainActor (URL) -> Bool) -> Bool {
        guard let url = url(from: link),
              url.absoluteString == AppLinks.githubSponsors.absoluteString else { return false }
        return open(AppLinks.githubSponsors)
    }

    static func sponsorTextView() -> NSTextView? {
        for window in NSApplication.shared.windows {
            if let match = textView(in: window.contentView, containing: sponsorTitle) {
                return match
            }
        }
        return nil
    }

    static func dismiss() {
        if let window = sponsorTextView()?.window {
            window.close()
            return
        }
        for window in NSApplication.shared.windows where window.title.localizedCaseInsensitiveContains("About") {
            window.close()
        }
    }

    private static let linkHandler = AboutSponsorLinkHandler()

    private static func attachSponsorLinkHandler() {
        sponsorTextView()?.delegate = linkHandler
    }

    private static func url(from link: Any) -> URL? {
        if let url = link as? URL { return url }
        if let string = link as? String { return URL(string: string) }
        return nil
    }

    private static func textView(in view: NSView?, containing needle: String) -> NSTextView? {
        guard let view else { return nil }
        if let textView = view as? NSTextView, textView.string.contains(needle) {
            return textView
        }
        if let scroll = view as? NSScrollView, let document = scroll.documentView,
           let match = textView(in: document, containing: needle) {
            return match
        }
        for subview in view.subviews {
            if let match = textView(in: subview, containing: needle) { return match }
        }
        return nil
    }
}

@MainActor
private final class AboutSponsorLinkHandler: NSObject, NSTextViewDelegate {
    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        AboutPanel.handleLinkClick(link)
    }
}
