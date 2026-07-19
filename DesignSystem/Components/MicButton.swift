//
//  MicButton.swift
//  EnglishHelper — DesignSystem
//
//  Voice capture control, PUSH-TO-TALK: capture runs while the finger is DOWN; lifting it submits.
//  Shaped as a full-width pill IDENTICAL to the primary EHButton (Capsule, minHeight 50), so the
//  mic and the action button below it read as one family; the status caption lives INSIDE the pill.
//  Press-down gives an impact haptic (the audible start/stop cues come from the speech adapter,
//  which sequences them around the actual recording). State is expressed through MOTION (per the
//  design: diverging capsule rings while listening, spinner while processing), with a Reduce Motion
//  fallback to a static treatment.
//
//  A deliberate finger-lift (onPressEnded) is distinguished from a SYSTEM touch-cancel
//  (onPressCancelled: permission alert, incoming call, Control Center, app switcher, the enclosing
//  scroll view claiming the touch) — only the deliberate release may submit; a cancelled hold must
//  drop the half-finished utterance instead of firing a request the user never asked for.
//
//  VoiceOver can't hold a control, so the accessibility ACTIVATE action degrades to a toggle:
//  first activation presses, the next releases (a deliberate release — it submits).
//

import SwiftUI

public struct MicButton: View {
    public enum Status: Sendable { case idle, listening, processing }

    private let status: Status
    private let title: String
    private let onPressBegan: () -> Void
    private let onPressEnded: () -> Void
    private let onPressCancelled: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false
    /// GestureState (not @State): resets to `false` even when the system CANCELS the gesture
    /// (sheet/alert appears mid-hold, scroll steals the touch), so a press can never be left
    /// "stuck down" without an ended/cancelled callback.
    @GestureState private var isPressed = false
    /// Set by DragGesture.onEnded — which fires ONLY on a genuine touch-up, never on a system
    /// cancel. Lets the GestureState reset tell the two apart: reset with this flag = release
    /// already handled; reset without it = the system killed the touch → onPressCancelled.
    @State private var handledDeliberateEnd = false

    /// `title` is the status caption shown inside the pill (the caller keys it off the same status).
    public init(status: Status, title: String,
                onPressBegan: @escaping () -> Void,
                onPressEnded: @escaping () -> Void,
                onPressCancelled: @escaping () -> Void) {
        self.status = status
        self.title = title
        self.onPressBegan = onPressBegan
        self.onPressEnded = onPressEnded
        self.onPressCancelled = onPressCancelled
    }

    public var body: some View {
        ZStack {
            // Diverging rings while listening — same pulse as the old round mic, capsule-shaped.
            // Drawn OUTSIDE the pill bounds on purpose (no reserved frame): the layout stays as
            // compact as a plain button.
            if status == .listening && !reduceMotion {
                ForEach(0..<2, id: \.self) { i in
                    Capsule()
                        .stroke(Tokens.Signal.live.opacity(0.5), lineWidth: 2)
                        .scaleEffect(pulse ? 1.10 : 1.0)
                        .opacity(pulse ? 0 : 0.6)
                        .animation(
                            .easeOut(duration: 1.6).repeatForever(autoreverses: false)
                                .delay(Double(i) * 0.8),
                            value: pulse
                        )
                }
            }
            // Pill geometry mirrors EHButton exactly (headline font, minHeight 50, s20 padding,
            // Capsule) so the mic reads as the same control family as the action button below it.
            HStack(spacing: Tokens.Space.s8) {
                icon
                Text(title)
                    .multilineTextAlignment(.center)   // long captions wrap; the pill grows like EHButton
            }
            .font(Tokens.Text.headline.font)
            .tracking(-0.2)
            .foregroundStyle(foreground)
            .frame(minHeight: 50)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Tokens.Space.s20)
            .background(fill)
            .clipShape(Capsule())
            .overlay {
                if status == .listening && reduceMotion {
                    Capsule().strokeBorder(Tokens.Signal.live, lineWidth: 3)
                }
            }
        }
        .contentShape(Capsule())
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(duration: 0.15), value: isPressed)
        // minimumDistance 0 = the press is recognized at touch-DOWN, so capture starts immediately.
        // Plain .gesture (not highPriority) DELIBERATELY leaves the enclosing ScrollView able to
        // claim a moving touch: a scroll that starts on the button cancels the hold (→ cancelled
        // path, no submit) instead of the button blocking scrolling on its large hit area.
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($isPressed) { _, state, _ in state = true }
                .onEnded { _ in
                    // Genuine touch-UP only (a system cancel never calls onEnded) — this is the
                    // deliberate release. The flag tells the GestureState reset below it's handled;
                    // ordering is safe both ways (see onChange).
                    handledDeliberateEnd = true
                    onPressEnded()
                }
        )
        .onChange(of: isPressed) { _, pressed in
            if pressed {
                handledDeliberateEnd = false
                onPressBegan()
            } else if handledDeliberateEnd {
                handledDeliberateEnd = false          // release already delivered via onEnded
            } else {
                onPressCancelled()                    // reset with NO onEnded = system cancel
                // If onEnded still fires after this (ordering not guaranteed by SwiftUI), the
                // view models guard on the listening phase — the late release is a no-op.
            }
        }
        // Tactile confirmation of the press itself; the release is confirmed by the end-of-capture
        // sound cue, so it deliberately gets no second haptic.
        .sensoryFeedback(.impact(weight: .medium), trigger: isPressed) { _, pressed in pressed }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            if status == .listening { onPressEnded() } else { onPressBegan() }
        }
        .onAppear { if status == .listening { pulse = true } }
        .onChange(of: status) { _, new in pulse = (new == .listening) }
    }

    private var fill: Color {
        switch status {
        case .idle:       Tokens.Surface.invert
        case .listening:  Tokens.Signal.live
        case .processing: Tokens.Surface.invert
        }
    }

    private var foreground: Color {
        switch status {
        case .idle, .processing: Tokens.Content.onInvert
        case .listening:         .white
        }
    }

    @ViewBuilder private var icon: some View {
        switch status {
        case .idle:
            Image(systemName: "mic.fill")
        case .listening:
            Image(systemName: "waveform")
                .symbolEffect(.variableColor.iterative, isActive: !reduceMotion)
        case .processing:
            ProgressView().tint(Tokens.Content.onInvert)
        }
    }
}
