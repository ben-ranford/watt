import AppKit
import XCTest
@testable import Watt

@MainActor
final class AboutPanelTests: XCTestCase {
    func testSponsorsURLLivesInOneProductionConstant() throws {
        XCTAssertEqual(AppLinks.githubSponsors.absoluteString, "https://github.com/sponsors/ben-ranford")
        XCTAssertEqual(AppLinks.githubSponsors.scheme, "https")
        let root = repoRoot()
        var hits: [String] = []
        for directory in ["App", "Features", "DesignSystem", "Models", "Services"] {
            let folder = root.appendingPathComponent(directory)
            guard let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil) else {
                continue
            }
            for case let url as URL in enumerator where url.pathExtension == "swift" {
                let source = try String(contentsOf: url, encoding: .utf8)
                if source.contains("https://github.com/sponsors/ben-ranford") {
                    hits.append(url.lastPathComponent)
                }
            }
        }
        XCTAssertEqual(hits, ["AboutPanel.swift"])
    }

    func testReadmeAndFundingPointAtTheSameSponsor() throws {
        let root = repoRoot()
        let readme = try String(contentsOf: root.appendingPathComponent("README.md"), encoding: .utf8)
        let funding = try String(contentsOf: root.appendingPathComponent(".github/FUNDING.yml"), encoding: .utf8)
        XCTAssertTrue(readme.contains("## Support"))
        XCTAssertTrue(readme.contains("https://github.com/sponsors/ben-ranford"))
        XCTAssertTrue(funding.contains("github: ben-ranford"))
        let agents = try String(contentsOf: root.appendingPathComponent("AGENTS.md"), encoding: .utf8)
        XCTAssertFalse(agents.contains("docs/guidance-schema.md"))
    }

    func testCreditsAreACenteredSponsorLink() {
        let credits = AboutPanel.credits()
        XCTAssertEqual(credits.string, AboutPanel.sponsorTitle)
        let range = NSRange(location: 0, length: credits.length)
        var link: URL?
        var centered = false
        credits.enumerateAttribute(.link, in: range) { value, _, _ in
            link = value as? URL
        }
        credits.enumerateAttribute(.paragraphStyle, in: range) { value, _, _ in
            centered = (value as? NSParagraphStyle)?.alignment == .center
        }
        XCTAssertEqual(link, AppLinks.githubSponsors)
        XCTAssertTrue(centered)
    }

    func testSponsorClickOpensTheConfiguredURLWithTheGivenOpener() {
        var opened: [URL] = []
        XCTAssertTrue(AboutPanel.handleLinkClick(AppLinks.githubSponsors, open: { url in
            opened.append(url)
            return true
        }))
        XCTAssertEqual(opened, [AppLinks.githubSponsors])
        XCTAssertTrue(AboutPanel.handleLinkClick(AppLinks.githubSponsors.absoluteString, open: { url in
            opened.append(url)
            return true
        }))
        XCTAssertFalse(AboutPanel.handleLinkClick(URL(string: "https://example.com")!, open: { url in
            opened.append(url)
            return true
        }))
        XCTAssertFalse(AboutPanel.handleLinkClick("not a url", open: { url in
            opened.append(url)
            return true
        }))
        XCTAssertEqual(opened, [AppLinks.githubSponsors, AppLinks.githubSponsors])
    }

    func testAboutMenuPresentsThePanelAndOpensLinksWithNSWorkspace() throws {
        let menu = try source("Features/MenuBar/Views/StatusItemContextMenu.swift")
        XCTAssertTrue(menu.contains("onAbout: @escaping () -> Void = { AboutPanel.show() }"))
        let panel = try source("App/AboutPanel.swift")
        XCTAssertTrue(panel.contains("NSWorkspace.shared.open"))
        XCTAssertTrue(panel.contains("orderFrontStandardAboutPanel"))
        XCTAssertTrue(panel.contains("clickedOnLink"))
    }

    func testAboutPanelShowsTheSponsorCredit() throws {
        AboutPanel.show()
        defer { AboutPanel.dismiss() }
        let deadline = Date().addingTimeInterval(2)
        var textView = AboutPanel.sponsorTextView()
        while textView == nil && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
            textView = AboutPanel.sponsorTextView()
        }
        let titles = NSApplication.shared.windows.map(\.title)
        let view = try XCTUnwrap(textView, "About panel did not show Sponsor. Windows: \(titles)")
        XCTAssertTrue(view.string.contains(AboutPanel.sponsorTitle))
        let range = NSRange(location: 0, length: (view.string as NSString).length)
        var link: URL?
        view.textStorage?.enumerateAttribute(.link, in: range) { value, _, _ in
            if let url = value as? URL { link = url }
        }
        let sponsorLink = try XCTUnwrap(link)
        XCTAssertEqual(sponsorLink.absoluteString, AppLinks.githubSponsors.absoluteString)
        XCTAssertTrue(AboutPanel.handleLinkClick(sponsorLink, open: { _ in true }))
    }

    private func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot().appendingPathComponent(path), encoding: .utf8)
    }

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
