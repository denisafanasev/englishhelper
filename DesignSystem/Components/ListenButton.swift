//
//  ListenButton.swift
//  EnglishHelper — DesignSystem
//
//  The Online-mode listening TOGGLE: one tap starts a live session, the next tap ends it. Same
//  pill geometry as EHButton/MicButton so the whole control family reads as one. While listening
//  the pill turns `Signal.live` and shows a LIVE SOUND DIAGRAM — a scrolling bar meter driven by
//  the microphone level — plus a stop glyph so the exit is obvious. Haptic on every toggle.
//  Reduce Motion: the diagram freezes into a static bar row (state still shown via color + glyph).
//

import SwiftUI
import Combine   // Timer.publish for the scrolling level diagram

public struct ListenButton: View {
    private let isListening: Bool
    /// True while the session drains its final words after a stop tap (button disabled, spinner).
    private let isStopping: Bool
    /// Microphone input level 0…1; feeds the diagram only while listening.
    private let level: Float
    private let idleTitle: String
    private let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled
    /// Rolling window of recent levels — the bars scroll left as new audio arrives.
    @State private var levelHistory: [Float] = Array(repeating: 0, count: ListenButton.barCount)

    private static let barCount = 24

    public init(isListening: Bool, isStopping: Bool = false, level: Float,
                idleTitle: String, action: @escaping () -> Void) {
        self.isListening = isListening
        self.isStopping = isStopping
        self.level = level
        self.idleTitle = idleTitle
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Space.s12) {
                if isStopping {
                    ProgressView().tint(.white)
                } else if isListening {
                    Image(systemName: "stop.fill")
                    diagram
                } else {
                    Image(systemName: "waveform")
                    Text(idleTitle)
                }
            }
            .font(Tokens.Text.headline.font)
            .tracking(-0.2)
            .foregroundStyle(isListening || isStopping ? .white : Tokens.Content.onInvert)
            .frame(minHeight: 50)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Tokens.Space.s20)
            .background(isListening || isStopping ? Tokens.Signal.live : Tokens.Surface.invert)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isStopping)
        .opacity(isEnabled ? 1 : 0.4)
        .sensoryFeedback(.impact(weight: .medium), trigger: isListening)
        // Timer-driven (not onChange(of: level)): equal consecutive levels — dead silence, a muted
        // mic — must still SCROLL the diagram, or it freezes and looks stuck.
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
            guard isListening, !reduceMotion else { return }
            levelHistory.removeFirst()
            levelHistory.append(level)
        }
        .onChange(of: isListening) { _, listening in
            if !listening { levelHistory = Array(repeating: 0, count: Self.barCount) }
        }
        .accessibilityLabel(idleTitle)
        .accessibilityValue(isListening ? DSLoc.t("Слушаю", "Listening") : DSLoc.t("Готов", "Ready"))
        .accessibilityHint(isListening
            ? DSLoc.t("Коснитесь, чтобы остановить прослушивание", "Tap to stop listening")
            : DSLoc.t("Коснитесь, чтобы начать слушать и переводить речь вокруг",
                      "Tap to start listening and translating nearby speech"))
    }

    /// The sound diagram: a fixed row of bars whose heights are the recent level history (newest on
    /// the right), so speech visibly "runs" across the button. Under Reduce Motion the history stops
    /// updating and the row stays flat — color + the stop glyph still carry the state.
    private var diagram: some View {
        HStack(spacing: 3) {
            ForEach(Array(levelHistory.enumerated()), id: \.offset) { _, value in
                Capsule()
                    .fill(.white.opacity(0.9))
                    .frame(width: 3, height: barHeight(for: value))
            }
        }
        .frame(maxWidth: .infinity)
        .animation(reduceMotion ? nil : .linear(duration: 0.08), value: levelHistory)
        .accessibilityHidden(true)
    }

    private func barHeight(for level: Float) -> CGFloat {
        let minH: CGFloat = 4, maxH: CGFloat = 28
        return minH + (maxH - minH) * CGFloat(min(1, max(0, level)))
    }
}
