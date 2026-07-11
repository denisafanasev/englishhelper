//
//  MicButton.swift
//  EnglishHelper — DesignSystem
//
//  Voice capture control, PUSH-TO-TALK: capture runs while the finger is DOWN; lifting it submits.
//  Press-down gives an impact haptic (the audible start/stop cues come from the speech adapter,
//  which sequences them around the actual recording). State is expressed through MOTION (per the
//  design: diverging rings while listening, spinner while processing), with a Reduce Motion
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
    private let onPressBegan: () -> Void
    private let onPressEnded: () -> Void
    private let onPressCancelled: () -> Void
    private let size: CGFloat
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

    public init(status: Status, size: CGFloat = 88,
                onPressBegan: @escaping () -> Void,
                onPressEnded: @escaping () -> Void,
                onPressCancelled: @escaping () -> Void) {
        self.status = status
        self.size = size
        self.onPressBegan = onPressBegan
        self.onPressEnded = onPressEnded
        self.onPressCancelled = onPressCancelled
    }

    public var body: some View {
        ZStack {
            if status == .listening && !reduceMotion {
                ForEach(0..<2, id: \.self) { i in
                    Circle()
                        .stroke(Tokens.Signal.live.opacity(0.5), lineWidth: 2)
                        .frame(width: size, height: size)
                        .scaleEffect(pulse ? 1.6 : 1.0)
                        .opacity(pulse ? 0 : 0.6)
                        .animation(
                            .easeOut(duration: 1.6).repeatForever(autoreverses: false)
                                .delay(Double(i) * 0.8),
                            value: pulse
                        )
                }
            }
            Circle()
                .fill(fill)
                .frame(width: size, height: size)
                .overlay {
                    if status == .listening && reduceMotion {
                        Circle().strokeBorder(Tokens.Signal.live, lineWidth: 3)
                    }
                }
            icon
        }
        .frame(width: size * 1.6, height: size * 1.6)   // room for rings
        .contentShape(Circle())
        .scaleEffect(isPressed ? 0.92 : 1.0)
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

    @ViewBuilder private var icon: some View {
        switch status {
        case .idle:
            Image(systemName: "mic.fill").font(.system(size: size * 0.36, weight: .medium))
                .foregroundStyle(Tokens.Content.onInvert)
        case .listening:
            Image(systemName: "waveform").font(.system(size: size * 0.36, weight: .semibold))
                .foregroundStyle(.white)
                .symbolEffect(.variableColor.iterative, isActive: !reduceMotion)
        case .processing:
            ProgressView().tint(Tokens.Content.onInvert).controlSize(.large)
        }
    }
}
