import AppKit
import SwiftUI
import XCTest
@testable import Watt

/// The status item holds every reading with up to two integer digits, including
/// a sign in battery-delta mode, and widens only when the integer part reaches
/// three digits. The decision is a pure function of the strings and font metrics.
@MainActor
final class MenuBarStatusWidthTests: XCTestCase {
    func testFormatterCasesMatchTheDigitBoundaries() {
        XCTAssertEqual(PowerFormatter.watts(0, signed: false, precision: .decimal), "0.0 W")
        XCTAssertEqual(PowerFormatter.watts(9.9, signed: false, precision: .decimal), "9.9 W")
        XCTAssertEqual(PowerFormatter.watts(10, signed: false, precision: .decimal), "10.0 W")
        XCTAssertEqual(PowerFormatter.watts(99.9, signed: false, precision: .decimal), "99.9 W")
        XCTAssertEqual(PowerFormatter.watts(-99.9, signed: true, precision: .decimal), "-99.9 W")
        XCTAssertEqual(PowerFormatter.watts(-99.9, signed: true, precision: .decimal)
            .replacingOccurrences(of: "-", with: "−"), "−99.9 W")
        XCTAssertEqual(PowerFormatter.watts(100, signed: false, precision: .decimal), "100.0 W")
        XCTAssertEqual(PowerFormatter.watts(100, signed: true, precision: .decimal), "+100.0 W")
        XCTAssertEqual(MenuBarStatusReserve.unit, "W")
    }

    func testOneAndTwoIntegerDigitsShareTheUnsignedReserve() {
        let metrics = metrics(covering: samples)
        let references = MenuBarStatusReserve.unsigned(precision: .decimal)
        XCTAssertEqual(references, ["88.8 W"])
        let minimum = resolved("88.8 W", references: references, metrics: metrics).minimumTextWidth
        for displayed in ["0.0 W", "9.9 W", "10.0 W", "99.9 W"] {
            let result = resolved(displayed, references: references, metrics: metrics)
            XCTAssertEqual(result.textWidth, minimum, displayed)
            XCTAssertLessThanOrEqual(result.displayedTextWidth, minimum, displayed)
            XCTAssertEqual(metrics.width(of: MenuBarStatusWidth.widest([displayed] + references, metrics: metrics)), minimum, displayed)
        }
        XCTAssertEqual(metrics.width(of: "0.0 W"), metrics.width(of: "9.9 W"))
        XCTAssertEqual(metrics.width(of: "10.0 W"), metrics.width(of: "99.9 W"))
        XCTAssertGreaterThan(metrics.width(of: "10.0 W"), metrics.width(of: "0.0 W"))
        let hundred = resolved("100.0 W", references: references, metrics: metrics)
        XCTAssertGreaterThan(hundred.textWidth, minimum)
        XCTAssertEqual(hundred.textWidth, metrics.width(of: "100.0 W"))
        XCTAssertEqual(hundred.textWidth - minimum, metrics.width(of: "8"),
                       "Three integer digits add one digit, not a fixed inset")
    }

    func testSignedDeltaHoldsALeadingSignThroughTwoIntegerDigits() {
        let readings = ["0.0 W", "9.9 W", "10.0 W", "99.9 W", "-99.9 W", "−99.9 W", "+99.9 W", "+100.0 W", "−100.0 W"]
        let metrics = metrics(covering: readings + MenuBarStatusReserve.signed(precision: .decimal))
        let references = MenuBarStatusReserve.signed(precision: .decimal)
        XCTAssertEqual(Set(references), Set(["+88.8 W", "−88.8 W", "-88.8 W"]))
        let minimum = resolved("+88.8 W", references: references, metrics: metrics).minimumTextWidth
        for displayed in ["0.0 W", "9.9 W", "10.0 W", "99.9 W", "-99.9 W", "−99.9 W", "+99.9 W"] {
            let result = resolved(displayed, references: references, metrics: metrics)
            XCTAssertEqual(result.textWidth, minimum, displayed)
            XCTAssertGreaterThanOrEqual(minimum, metrics.width(of: displayed), displayed)
        }
        for displayed in ["+100.0 W", "−100.0 W"] {
            let result = resolved(displayed, references: references, metrics: metrics)
            XCTAssertGreaterThan(result.textWidth, minimum, displayed)
            XCTAssertEqual(result.textWidth, metrics.width(of: displayed), displayed)
        }
        let noReading = resolved(NoReadingPresentation.value, references: references, metrics: metrics)
        XCTAssertEqual(noReading.textWidth, minimum, "The no-reading placeholder sits in the signed reserve")
        XCTAssertEqual(resolved("—", references: references, metrics: metrics).textWidth, minimum)
    }

    func testHighWaterStaysUntilTheReserveChanges() {
        let metrics = metrics(covering: samples)
        let references = MenuBarStatusReserve.unsigned(precision: .decimal)
        let hundred = resolved("100.0 W", references: references, metrics: metrics)
        let held = resolved("0.0 W", references: references, metrics: metrics,
                            highWater: hundred.highWater, keepHighWater: true)
        XCTAssertEqual(held.textWidth, hundred.textWidth)
        XCTAssertEqual(held.contentWidth, hundred.contentWidth)
        let reset = resolved("0.0 W", references: references, metrics: metrics,
                             highWater: hundred.highWater, keepHighWater: false)
        XCTAssertEqual(reset.textWidth, reset.minimumTextWidth)
        XCTAssertLessThan(reset.textWidth, hundred.textWidth)
        let winner = MenuBarStatusWidth.widest(["0.0 W", "88.8 W", "100.0 W"], metrics: metrics)
        XCTAssertEqual(metrics.width(of: winner), metrics.width(of: "100.0 W"))
    }

    func testWholeAndHundredthsPrecisionUseTheSameIntegerBoundary() {
        for precision in [WattPrecision.whole, .hundredths] {
            let references = MenuBarStatusReserve.unsigned(precision: precision)
            let signed = MenuBarStatusReserve.signed(precision: precision)
            let corpus = [0, 9, 10, 99, 100].map { PowerFormatter.watts($0, signed: false, precision: precision) }
                + [PowerFormatter.watts(-99, signed: true, precision: precision)]
                + references + signed
            let metrics = metrics(covering: corpus)
            let minimum = resolved(references[0], references: references, metrics: metrics).minimumTextWidth
            for value in [0.0, 9.0, 10.0, 99.0] {
                let displayed = PowerFormatter.watts(value, signed: false, precision: precision)
                XCTAssertEqual(resolved(displayed, references: references, metrics: metrics).textWidth, minimum, displayed)
            }
            let hundred = PowerFormatter.watts(100, signed: false, precision: precision)
            XCTAssertGreaterThan(resolved(hundred, references: references, metrics: metrics).textWidth, minimum, hundred)
            let negative = PowerFormatter.watts(-99, signed: true, precision: precision)
            let signedMinimum = resolved(negative, references: signed, metrics: metrics)
            XCTAssertEqual(signedMinimum.textWidth, signedMinimum.minimumTextWidth, negative)
            let signedHundred = PowerFormatter.watts(100, signed: true, precision: precision)
            XCTAssertGreaterThan(resolved(signedHundred, references: signed, metrics: metrics).textWidth,
                                 signedMinimum.minimumTextWidth, signedHundred)
        }
        XCTAssertEqual(MenuBarStatusReserve.unsigned(precision: .whole), ["88 W"])
        XCTAssertEqual(MenuBarStatusReserve.unsigned(precision: .hundredths), ["88.88 W"])
    }

    func testEveryDisplayModeReservesTwoIntegerDigits() {
        let draw = label(mode: .draw, watts: 9.9, system: 9.9)
        let charger = label(mode: .charger, charger: 10)
        let positive = label(mode: .delta, watts: 99.9, battery: .charging)
        let negative = label(mode: .delta, watts: -99.9, battery: .discharging)
        let components = componentLabel([("CPU", 9.8), ("GPU", 4.1)])
        let icon = label(mode: .iconOnly, watts: 42.1, system: 42.1)
        XCTAssertEqual(draw.text, "9.9 W")
        XCTAssertEqual(charger.text, "10.0 W")
        XCTAssertEqual(positive.text, "+99.9 W")
        XCTAssertEqual(negative.text, "−99.9 W")
        XCTAssertEqual(components.text, "CPU 9.8 · GPU 4.1 W")
        XCTAssertNil(icon.text)
        let asleepPreferences = PreferencesStore(storage: InMemoryStorage())
        asleepPreferences.displayMode = .delta
        let asleep = MenuBarStatusLabel(reading: .unavailable, preferences: asleepPreferences)
        XCTAssertEqual(asleep.text, NoReadingPresentation.value)
        assertHoldsTwoDigits(asleep)
        asleepPreferences.displayMode = .draw
        let blank = MenuBarStatusLabel(reading: .unavailable, preferences: asleepPreferences)
        XCTAssertEqual(blank.text, "—")
        assertHoldsTwoDigits(blank)
        let font = MenuBarStatusFont.menuBar()
        let forced = MenuBarStatusLabel(reading: delta(9.9, battery: .charging), preferences: asleepPreferences, helperSwitchedOff: true)
        XCTAssertEqual(forced.statusWidthIdentity(font: font).mode, .delta)
        XCTAssertEqual(forced.text, "+9.9 W")
        assertHoldsTwoDigits(forced)
        for sample in [draw, charger, positive, negative, components] {
            assertHoldsTwoDigits(sample)
        }
        XCTAssertEqual(icon.statusWidthReferences, [])
        assertGrows(label(mode: .draw, watts: 100, system: 100))
        assertGrows(label(mode: .charger, charger: 100))
        assertGrows(label(mode: .delta, watts: 100, battery: .charging))
        assertGrows(label(mode: .delta, watts: -100, battery: .discharging))
        assertGrows(componentLabel([("CPU", 100), ("GPU", 88.8)]))
        assertHoldsTwoDigits(componentLabel([("CPU", 100), ("GPU", 4.1)]),
                             "A three-digit component beside a one-digit component is not wider than two two-digit values")
    }

    func testComponentReserveMatchesTheSharedAndSeparateLayouts() {
        XCTAssertTrue(MenuBarStatusReserve.components(labels: ["CPU", "GPU"], precision: .decimal, sharesUnit: true)
            .contains("CPU 88.8 · GPU 88.8 W"))
        XCTAssertEqual(MenuBarStatusReserve.components(labels: ["GPU"], precision: .whole, sharesUnit: false), ["GPU 88 W"])
        XCTAssertEqual(MenuBarStatusReserve.components(labels: [], precision: .decimal, sharesUnit: true), ["—"])
        let named = componentLabel([("cpu", 9.8)], names: [("cpu", "CPU estimate")])
        XCTAssertEqual(named.text, "CPU estimate 9.8 W")
        XCTAssertTrue(named.statusWidthReferences.contains("CPU estimate 88.8 W"))
        assertHoldsTwoDigits(named)
        let partial = componentLabel([("CPU", 9.8)], names: [("CPU", "CPU"), ("GPU", "GPU")], selected: ["CPU", "GPU"])
        XCTAssertEqual(partial.text, "CPU 9.8 W · GPU —")
        assertHoldsTwoDigits(partial)
    }

    func testIconAndTextShareTheTextReserveWithoutExtraSpacing() {
        let metrics = metrics(covering: samples)
        let references = MenuBarStatusReserve.unsigned(precision: .decimal)
        let narrow = resolved("9.9 W", references: references, metrics: metrics, iconWidth: 16, iconSpacing: 4)
        let wide = resolved("99.9 W", references: references, metrics: metrics, iconWidth: 16, iconSpacing: 4)
        XCTAssertEqual(narrow.contentWidth, wide.contentWidth)
        XCTAssertEqual(narrow.contentWidth, 16 + 4 + narrow.textWidth)
        XCTAssertEqual(narrow.textWidth, narrow.minimumTextWidth)
        let iconOnly = resolved("", references: [], metrics: metrics, iconWidth: 16, iconSpacing: 4)
        XCTAssertEqual(iconOnly.contentWidth, 16, "Icon Only does not reserve a text slot or the icon gap")
        let hundred = resolved("100.0 W", references: references, metrics: metrics, iconWidth: 16, iconSpacing: 4)
        XCTAssertGreaterThan(hundred.contentWidth, wide.contentWidth)
        let smallerIcon = resolved("0.0 W", references: references, metrics: metrics,
                                   iconWidth: 12, iconSpacing: 4, highWater: hundred.highWater)
        XCTAssertEqual(smallerIcon.textWidth, hundred.textWidth)
        XCTAssertEqual(smallerIcon.contentWidth, 12 + 4 + hundred.textWidth)
    }

    func testADifferentUnitPrecisionModeOrFontDropsTheHighWater() {
        let font = MenuBarStatusFont.menuBar()
        let base = MenuBarStatusWidthIdentity(mode: .draw, precision: .decimal, unit: "W",
                                              fontName: font.fontName, fontSize: font.pointSize,
                                              components: [], componentSharesUnit: false)
        var other = base
        other.unit = "mW"
        XCTAssertNotEqual(base, other)
        other = base
        other.precision = .whole
        XCTAssertNotEqual(base, other)
        other = base
        other.mode = .delta
        XCTAssertNotEqual(base, other)
        other = base
        other.fontSize = base.fontSize + 1
        XCTAssertNotEqual(base, other)
        other = base
        other.fontName = base.fontName + "-other"
        XCTAssertNotEqual(base, other)
        other = base
        other.components = ["CPU"]
        XCTAssertNotEqual(base, other)
        other = base
        other.componentSharesUnit = true
        XCTAssertNotEqual(base, other)
        let watts = metrics(covering: ["88.8 W", "88.8 mW"])
        XCTAssertGreaterThan(watts.width(of: "88.8 mW"), watts.width(of: "88.8 W"))
    }

    func testLengthAddsOnlyTheTextSlack() {
        XCTAssertEqual(MenuBarStatusWidth.itemLength(intrinsicWidth: 48, textSlack: 0, scale: 2), 48)
        XCTAssertEqual(MenuBarStatusWidth.itemLength(intrinsicWidth: 40, textSlack: 8, scale: 2), 48)
        XCTAssertEqual(MenuBarStatusWidth.itemLength(intrinsicWidth: 40.25, textSlack: 0, scale: 2), 40.5)
        XCTAssertEqual(MenuBarStatusWidth.itemLength(intrinsicWidth: 40, textSlack: -4, scale: 2), 40)
    }

    func testMonospacedMenuBarDigitsMakeTheCasesAgreeWithRenderedWidth() {
        let font = MenuBarStatusFont.menuBar()
        let corpus = ["0123456789", "0.0 W", "9.9 W", "10.0 W", "99.9 W", "-99.9 W", "−99.9 W", "+99.9 W", "100.0 W", "+100.0 W", "−100.0 W"]
        let metrics = MenuBarFontMetrics.measuring(font, covering: corpus)
        let digitWidths = Set((0...9).map { metrics.advances[Character(String($0))] })
        XCTAssertEqual(digitWidths.count, 1)
        XCTAssertEqual(metrics.width(of: "0.0 W"), metrics.width(of: "9.9 W"))
        XCTAssertEqual(metrics.width(of: "10.0 W"), metrics.width(of: "99.9 W"))
        XCTAssertGreaterThan(metrics.width(of: "99.9 W"), metrics.width(of: "9.9 W"))
        XCTAssertGreaterThan(metrics.width(of: "100.0 W"), metrics.width(of: "99.9 W"))
        XCTAssertEqual(metrics.width(of: "100.0 W") - metrics.width(of: "99.9 W"),
                       rendered("100.0 W", font: font) - rendered("99.9 W", font: font), accuracy: 1)
        XCTAssertEqual(metrics.width(of: "99.9 W") - metrics.width(of: "9.9 W"),
                       rendered("99.9 W", font: font) - rendered("9.9 W", font: font), accuracy: 1)
        let references = MenuBarStatusReserve.unsigned(precision: .decimal)
        let signed = MenuBarStatusReserve.signed(precision: .decimal)
        let fontMetrics = MenuBarFontMetrics.measuring(font, covering: corpus + references + signed)
        for displayed in ["0.0 W", "9.9 W", "10.0 W", "99.9 W"] {
            let result = resolved(displayed, references: references, metrics: fontMetrics)
            XCTAssertEqual(result.textWidth, result.minimumTextWidth, displayed)
        }
        XCTAssertGreaterThan(resolved("100.0 W", references: references, metrics: fontMetrics).textWidth,
                             resolved("99.9 W", references: references, metrics: fontMetrics).textWidth)
        let signedMinimum = resolved("−99.9 W", references: signed, metrics: fontMetrics)
        XCTAssertEqual(signedMinimum.textWidth, signedMinimum.minimumTextWidth)
        XCTAssertGreaterThanOrEqual(signedMinimum.minimumTextWidth, fontMetrics.width(of: "-99.9 W"))
        XCTAssertGreaterThanOrEqual(signedMinimum.minimumTextWidth, fontMetrics.width(of: "−99.9 W"))
        XCTAssertGreaterThan(resolved("+100.0 W", references: signed, metrics: fontMetrics).textWidth, signedMinimum.minimumTextWidth)
        XCTAssertGreaterThan(resolved("−100.0 W", references: signed, metrics: fontMetrics).textWidth, signedMinimum.minimumTextWidth)
    }

    func testSwiftUILabelWidthIsStableAcrossDigitCounts() {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.showSymbol = false
        preferences.displayMode = .draw
        let widths = [0.0, 9.9, 10.0, 99.9].map { fittingWidth(draw($0), preferences: preferences) }
        XCTAssertGreaterThan(widths[0], 0)
        for width in widths {
            XCTAssertEqual(width, widths[0], accuracy: 1)
        }
        let hundred = fittingWidth(draw(100), preferences: preferences)
        XCTAssertGreaterThan(hundred, widths[0] + 3)
        XCTAssertLessThan(hundred - widths[0], 24, "Three digits grow by about one digit, not a large inset")

        preferences.showSymbol = true
        let withIcon = [fittingWidth(draw(9.9), preferences: preferences), fittingWidth(draw(99.9), preferences: preferences)]
        XCTAssertEqual(withIcon[0], withIcon[1], accuracy: 1)
        XCTAssertGreaterThan(fittingWidth(draw(100), preferences: preferences), withIcon[0] + 3)

        preferences.displayMode = .delta
        preferences.showSymbol = false
        let positive = fittingWidth(delta(99.9, battery: .charging), preferences: preferences)
        let negative = fittingWidth(delta(-99.9, battery: .discharging), preferences: preferences)
        let small = fittingWidth(delta(0, battery: .charging), preferences: preferences)
        XCTAssertEqual(positive, negative, accuracy: 1)
        XCTAssertEqual(small, positive, accuracy: 1)
        XCTAssertGreaterThan(fittingWidth(delta(100, battery: .charging), preferences: preferences), positive + 3)

        preferences.displayMode = .charger
        let chargerWidths = [0.0, 9.9, 99.9].map { fittingWidth(charger($0), preferences: preferences) }
        for width in chargerWidths { XCTAssertEqual(width, chargerWidths[0], accuracy: 1) }
        XCTAssertGreaterThan(fittingWidth(charger(100), preferences: preferences), chargerWidths[0] + 3)

        preferences.displayMode = .components
        preferences.selectedComponents = ["CPU", "GPU"]
        let quiet = fittingWidth(components([("CPU", 9.8), ("GPU", 4.1)]), preferences: preferences)
        let busy = fittingWidth(components([("CPU", 99.9), ("GPU", 10)]), preferences: preferences)
        XCTAssertEqual(quiet, busy, accuracy: 1)
        XCTAssertGreaterThan(fittingWidth(components([("CPU", 100), ("GPU", 99.9)]), preferences: preferences), busy + 3)

        preferences.displayMode = .iconOnly
        preferences.showSymbol = true
        let icons = [fittingWidth(draw(9.9), preferences: preferences), fittingWidth(draw(100), preferences: preferences)]
        XCTAssertEqual(icons[0], icons[1], accuracy: 1)
        XCTAssertLessThan(icons[0], quiet)
    }

    func testUpdateButtonUsesTheReserveAndDoesNotAddAConstantInset() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let app = try String(contentsOf: root.appendingPathComponent("App/WattFallbackStatusItem.swift"), encoding: .utf8)
        let lower = try XCTUnwrap(app.range(of: "private func updateButton()"))
        let upper = try XCTUnwrap(app.range(of: "private func startSampling()", range: lower.upperBound..<app.endIndex))
        let update = String(app[lower.lowerBound..<upper.lowerBound])
        XCTAssertTrue(update.contains("button.title = label.text ?? \"\""))
        XCTAssertTrue(update.contains("MenuBarStatusFont.menuBar()"))
        XCTAssertTrue(update.contains("MenuBarStatusWidth.resolve"))
        XCTAssertTrue(update.contains("keepHighWater: widthIdentity == identity"))
        XCTAssertFalse(update.contains("+ 12"))
        XCTAssertFalse(update.contains("max(42"))
        let label = try String(contentsOf: root.appendingPathComponent("Features/MenuBar/Components/MenuBarStatusLabel.swift"), encoding: .utf8)
        XCTAssertTrue(label.contains(".font(WattTypography.bodyEmphasized)"))
        XCTAssertTrue(label.contains(".monospacedDigit()"))
        XCTAssertTrue(label.contains("ZStack(alignment: .center)"))
        XCTAssertFalse(label.contains(".padding("))
        for forbidden in ["contentTransition", ".animation(", "withAnimation", "TimelineView"] {
            XCTAssertFalse(label.contains(forbidden), forbidden)
        }
    }

    private var samples: [String] {
        ["0.0 W", "9.9 W", "10.0 W", "99.9 W", "100.0 W", "88.8 W", "8"]
    }

    private func metrics(covering texts: [String]) -> MenuBarFontMetrics {
        var advances: [Character: CGFloat] = [:]
        for character in texts.joined() {
            if advances[character] != nil { continue }
            if character.isNumber {
                advances[character] = 10
            } else {
                switch character {
                case ".": advances[character] = 5
                case " ": advances[character] = 4
                case "W": advances[character] = 12
                case "+": advances[character] = 9
                case "-": advances[character] = 7
                case "−": advances[character] = 11
                case "—": advances[character] = 16
                case "·": advances[character] = 6
                default: advances[character] = 9
                }
            }
        }
        return MenuBarFontMetrics(advances: advances, fallbackAdvance: 9)
    }

    private func resolved(_ displayed: String, references: [String], metrics: MenuBarFontMetrics,
                          iconWidth: CGFloat = 0, iconSpacing: CGFloat = 0,
                          highWater: CGFloat = 0, keepHighWater: Bool = true) -> MenuBarStatusWidth.Result {
        MenuBarStatusWidth.resolve(.init(
            displayed: displayed, references: references, metrics: metrics,
            iconWidth: iconWidth, iconSpacing: iconSpacing,
            highWater: highWater, keepHighWater: keepHighWater
        ))
    }

    private func rendered(_ text: String, font: NSFont) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: font]).width
    }

    private func assertHoldsTwoDigits(_ label: MenuBarStatusLabel, _ message: String = "",
                                      file: StaticString = #filePath, line: UInt = #line) {
        let result = resolution(label)
        XCTAssertFalse(label.statusWidthReferences.isEmpty, message, file: file, line: line)
        XCTAssertEqual(result.textWidth, result.minimumTextWidth, "\(label.text ?? "") \(message)", file: file, line: line)
        XCTAssertLessThanOrEqual(result.displayedTextWidth, result.minimumTextWidth, message, file: file, line: line)
    }

    private func assertGrows(_ label: MenuBarStatusLabel, file: StaticString = #filePath, line: UInt = #line) {
        let result = resolution(label)
        XCTAssertGreaterThan(result.textWidth, result.minimumTextWidth, label.text ?? "", file: file, line: line)
        XCTAssertEqual(result.textWidth, result.displayedTextWidth, label.text ?? "", file: file, line: line)
    }

    private func resolution(_ label: MenuBarStatusLabel) -> MenuBarStatusWidth.Result {
        let displayed = label.text ?? ""
        let references = label.statusWidthReferences
        let font = MenuBarStatusFont.menuBar()
        let metrics = MenuBarFontMetrics.measuring(font, covering: [displayed] + references)
        return resolved(displayed, references: references, metrics: metrics)
    }

    private func label(mode: WattDisplayMode, watts: Double? = nil, battery: BatteryState = .unknown,
                       charger: Double? = nil, system: Double? = nil) -> MenuBarStatusLabel {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.displayMode = mode
        preferences.precision = .decimal
        let reading = PowerReading(
            mode: mode == .delta && battery == .discharging ? .onBattery : mode == .charger ? .chargerInput : .systemDraw,
            watts: mode == .charger ? nil : watts,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            batteryState: battery,
            capabilities: .init(battery: mode == .delta ? .available : .unknown,
                                charger: mode == .charger ? .available : .unknown,
                                systemDraw: mode == .draw || mode == .iconOnly ? .available : .unknown),
            source: .fixture,
            chargerWatts: charger,
            systemWatts: system ?? (mode == .draw || mode == .iconOnly ? watts : nil)
        )
        return MenuBarStatusLabel(reading: reading, preferences: preferences)
    }

    private func componentLabel(_ pairs: [(String, Double)], names: [(String, String)]? = nil,
                                selected: [String]? = nil) -> MenuBarStatusLabel {
        let preferences = PreferencesStore(storage: InMemoryStorage())
        preferences.displayMode = .components
        preferences.precision = .decimal
        preferences.showSymbol = false
        let ids = names?.map(\.0) ?? pairs.map(\.0)
        preferences.selectedComponents = selected ?? ids
        let components = (names ?? pairs.map { ($0.0, $0.0) }).map { id, name in
            PowerComponent(id: id, name: name, watts: pairs.first { $0.0 == id }?.1 ?? 0)
        }
        let present = Set(pairs.map(\.0))
        let reading = PowerReading(
            mode: .perComponent, watts: nil,
            components: components.filter { present.contains($0.id) },
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            capabilities: .init(components: .available),
            source: .fixture
        )
        return MenuBarStatusLabel(reading: reading, preferences: preferences)
    }

    private func draw(_ watts: Double) -> PowerReading {
        PowerReading(mode: .systemDraw, watts: watts, timestamp: Date(timeIntervalSince1970: 1_700_000_000),
                     capabilities: .init(systemDraw: .available), source: .fixture, systemWatts: watts)
    }

    private func delta(_ watts: Double, battery: BatteryState) -> PowerReading {
        PowerReading(mode: battery == .discharging ? .onBattery : .charging, watts: watts,
                     timestamp: Date(timeIntervalSince1970: 1_700_000_000), batteryState: battery,
                     capabilities: .init(battery: .available), source: .fixture)
    }

    private func charger(_ watts: Double) -> PowerReading {
        PowerReading(mode: .chargerInput, watts: nil, timestamp: Date(timeIntervalSince1970: 1_700_000_000),
                     capabilities: .init(charger: .available), source: .fixture, chargerWatts: watts)
    }

    private func components(_ pairs: [(String, Double)]) -> PowerReading {
        PowerReading(mode: .perComponent, watts: nil,
                     components: pairs.map { PowerComponent(name: $0.0, watts: $0.1) },
                     timestamp: Date(timeIntervalSince1970: 1_700_000_000),
                     capabilities: .init(components: .available), source: .fixture)
    }

    private func fittingWidth(_ reading: PowerReading, preferences: PreferencesStore) -> CGFloat {
        let host = NSHostingView(rootView: MenuBarStatusLabel(reading: reading, preferences: preferences))
        host.layoutSubtreeIfNeeded()
        return host.fittingSize.width
    }
}
