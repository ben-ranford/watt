import AppKit
import SwiftUI

/// One-shot motion for a surface the user is looking at.
///
/// Springs are critically damped and every duration stays inside 0.15–0.35s.
/// Reduce Motion uses a short opacity crossfade, or no animation for pointer
/// feedback. Nothing here repeats, sleeps, or schedules a timer. Callers pass
/// `enabled: false` while a window is closed so a hidden panel cannot animate
/// the next power sample.
enum WattMotion {
    static let numericResponse = 0.28
    static let stateResponse = 0.26
    static let revealResponse = 0.24
    static let settleResponse = 0.32
    static let pressDuration = 0.15
    static let crossfadeDuration = 0.15
    static let damping = 1.0
    /// Hover scale for borderless panel actions. Resting scale stays 1.
    static let hoverScale = 0.98

    /// The menu-bar status item stays visible while the panel is closed.
    /// Production draws it with `NSStatusBarButton.title`, which must stay
    /// immediate so samples cannot tick, jitter, or change the item width.
    static let animatesStatusItemText = false

    enum Kind: String, CaseIterable, Equatable {
        case numeric, state, reveal, press, settle
    }

    enum Curve: Equatable {
        case spring(response: Double, dampingFraction: Double)
        case easeOut(TimeInterval)
        case crossfade(TimeInterval)
        case none
    }

    /// How a changing reading is presented. `instant` is the closed-panel and
    /// screenshot path: the text view is left untouched.
    enum TextMotion: Equatable {
        case instant
        case opacity(Kind)
        case numericText
    }

    struct Spec: Equatable {
        var curve: Curve
        var animatesNumericText: Bool
        var allowsMovement: Bool

        var duration: TimeInterval {
            switch curve {
            case .spring(let response, _): return response
            case .easeOut(let duration), .crossfade(let duration): return duration
            case .none: return 0
            }
        }

        var animation: Animation? {
            switch curve {
            case .spring(let response, let dampingFraction):
                return .spring(response: response, dampingFraction: dampingFraction)
            case .easeOut(let duration):
                return .easeOut(duration: duration)
            case .crossfade(let duration):
                return .easeInOut(duration: duration)
            case .none:
                return nil
            }
        }
    }

    static func spec(_ kind: Kind, reduceMotion: Bool) -> Spec {
        if reduceMotion {
            switch kind {
            case .press:
                return Spec(curve: .none, animatesNumericText: false, allowsMovement: false)
            case .numeric, .state, .reveal, .settle:
                return Spec(curve: .crossfade(crossfadeDuration), animatesNumericText: false, allowsMovement: false)
            }
        }
        switch kind {
        case .numeric:
            return Spec(curve: .spring(response: numericResponse, dampingFraction: damping),
                        animatesNumericText: true, allowsMovement: false)
        case .state:
            return Spec(curve: .spring(response: stateResponse, dampingFraction: damping),
                        animatesNumericText: false, allowsMovement: false)
        case .reveal:
            return Spec(curve: .spring(response: revealResponse, dampingFraction: damping),
                        animatesNumericText: false, allowsMovement: false)
        case .press:
            return Spec(curve: .easeOut(pressDuration), animatesNumericText: false, allowsMovement: true)
        case .settle:
            return Spec(curve: .spring(response: settleResponse, dampingFraction: damping),
                        animatesNumericText: false, allowsMovement: false)
        }
    }

    static func animation(_ kind: Kind, reduceMotion: Bool, enabled: Bool) -> Animation? {
        guard enabled else { return nil }
        return spec(kind, reduceMotion: reduceMotion).animation
    }

    static func textMotion(reduceMotion: Bool, enabled: Bool, hasNumber: Bool) -> TextMotion {
        guard enabled else { return .instant }
        if reduceMotion || !hasNumber { return .opacity(reduceMotion ? .numeric : .state) }
        return .numericText
    }

    /// Window visibility, not a poll. Occlusion and miniaturize are events.
    static func surfaceAllowsMotion(isVisible: Bool, isMiniaturized: Bool, occlusionVisible: Bool) -> Bool {
        isVisible && !isMiniaturized && occlusionVisible
    }
}

private struct WattMotionSuppressedKey: EnvironmentKey {
    static let defaultValue = false
}

public extension EnvironmentValues {
    /// Screenshot hosts set this so the render is the settled frame.
    /// Public so the test module can write the key path. `@testable` does not
    /// make an internal setter a `WritableKeyPath`.
    var wattMotionSuppressed: Bool {
        get { self[WattMotionSuppressedKey.self] }
        set { self[WattMotionSuppressedKey.self] = newValue }
    }
}

extension View {
    /// Arms motion only while this view's window is on screen.
    /// Suppressed hosts skip the probe so a screenshot keeps the settled tree.
    func wattObserveSurface(_ visible: Binding<Bool>) -> some View {
        modifier(WattObserveSurfaceModifier(visible: visible))
    }

    /// Numeric samples roll. Sentences and Reduce Motion crossfade. A closed
    /// surface keeps the original text, so idle samples do not animate.
    func wattTextMotion(displayed: String, number: Double?, enabled: Bool) -> some View {
        modifier(WattTextMotionModifier(displayed: displayed, number: number, enabled: enabled))
    }

    /// Fades a row that already appears and disappears. Opacity only, so the
    /// settled layout does not move.
    func wattFade<V: Equatable>(_ kind: WattMotion.Kind = .reveal, when value: V, enabled: Bool) -> some View {
        modifier(WattFadeModifier(kind: kind, value: value, enabled: enabled))
    }

    func wattPointerFeedback(enabled: Bool) -> some View {
        modifier(WattPointerFeedbackModifier(enabled: enabled))
    }

    /// Animates an existing container when `value` changes. No-op while the
    /// surface is closed or motion is suppressed, so resting layout is unchanged.
    func wattAnimate<V: Equatable>(_ kind: WattMotion.Kind, value: V, enabled: Bool) -> some View {
        modifier(WattAnimateModifier(kind: kind, value: value, enabled: enabled))
    }
}

private struct WattObserveSurfaceModifier: ViewModifier {
    @Environment(\.wattMotionSuppressed) private var suppressed
    @Binding var visible: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        let binding = $visible
        if suppressed {
            content
        } else {
            content.background(WattSurfaceProbe { value in
                guard binding.wrappedValue != value else { return }
                binding.wrappedValue = value
            })
        }
    }
}

private struct WattTextMotionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.wattMotionSuppressed) private var suppressed
    var displayed: String
    var number: Double?
    var enabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        let finite = number?.isFinite == true
        switch WattMotion.textMotion(reduceMotion: reduceMotion, enabled: enabled && !suppressed, hasNumber: finite) {
        case .instant:
            content
        case .opacity(let kind):
            content
                .contentTransition(.opacity)
                .animation(WattMotion.animation(kind, reduceMotion: reduceMotion, enabled: true), value: displayed)
        case .numericText:
            numeric(content)
        }
    }

    @ViewBuilder
    private func numeric(_ content: Content) -> some View {
        let animation = WattMotion.animation(.numeric, reduceMotion: false, enabled: true)
        if #available(macOS 14, *), let number, number.isFinite {
            content
                .contentTransition(.numericText(value: number))
                .animation(animation, value: displayed)
        } else {
            content
                .contentTransition(.opacity)
                .animation(animation, value: displayed)
        }
    }
}

private struct WattFadeModifier<Value: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.wattMotionSuppressed) private var suppressed
    var kind: WattMotion.Kind
    var value: Value
    var enabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        let animation = WattMotion.animation(kind, reduceMotion: reduceMotion, enabled: enabled && !suppressed)
        if let animation {
            content
                .transition(.opacity)
                .animation(animation, value: value)
        } else {
            content
        }
    }
}

private struct WattAnimateModifier<Value: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.wattMotionSuppressed) private var suppressed
    var kind: WattMotion.Kind
    var value: Value
    var enabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if let animation = WattMotion.animation(kind, reduceMotion: reduceMotion, enabled: enabled && !suppressed) {
            content.animation(animation, value: value)
        } else {
            content
        }
    }
}

private struct WattPointerFeedbackModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.wattMotionSuppressed) private var suppressed
    var enabled: Bool
    @State private var hovering = false

    @ViewBuilder
    func body(content: Content) -> some View {
        let spec = WattMotion.spec(.press, reduceMotion: reduceMotion)
        if enabled && !suppressed && spec.allowsMovement {
            content
                .scaleEffect(hovering ? WattMotion.hoverScale : 1)
                .animation(spec.animation, value: hovering)
                .onHover { hovering = $0 }
        } else {
            content
        }
    }
}

/// Reports show, hide, close, and occlusion. No timer and no display link.
private struct WattSurfaceProbe: NSViewRepresentable {
    var onChange: (Bool) -> Void

    func makeNSView(context: Context) -> Probe {
        let probe = Probe()
        probe.onChange = onChange
        return probe
    }

    func updateNSView(_ probe: Probe, context: Context) {
        probe.onChange = onChange
    }

    final class Probe: NSView {
        var onChange: (Bool) -> Void = { _ in }
        private var last: Bool?
        private var pending: Bool?
        override var intrinsicContentSize: NSSize { .zero }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            NotificationCenter.default.removeObserver(self)
            guard let window else {
                publish(false)
                return
            }
            let names: [Notification.Name] = [
                NSWindow.didChangeOcclusionStateNotification,
                NSWindow.willCloseNotification,
                NSWindow.didBecomeKeyNotification,
                NSWindow.didResignKeyNotification
            ]
            for name in names {
                NotificationCenter.default.addObserver(self, selector: #selector(windowChanged(_:)), name: name, object: window)
            }
            publish(allowsMotion)
        }

        @objc private func windowChanged(_ notification: Notification) {
            publish(allowsMotion)
        }

        private var allowsMotion: Bool {
            guard let window else { return false }
            return WattMotion.surfaceAllowsMotion(
                isVisible: window.isVisible,
                isMiniaturized: window.isMiniaturized,
                occlusionVisible: window.occlusionState.contains(.visible))
        }

        private func publish(_ visible: Bool) {
            guard last != visible else { return }
            last = visible
            pending = visible
            DispatchQueue.main.async { [weak self] in self?.flush() }
        }

        private func flush() {
            guard let pending else { return }
            self.pending = nil
            onChange(pending)
        }
    }
}
