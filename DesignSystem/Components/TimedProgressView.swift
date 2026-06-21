//
//  TimedProgressView.swift
//  EnglishHelper — DesignSystem
//
//  A reassuring progress bar for operations whose real percentage is UNKNOWN (a non-streaming LLM
//  call — we can't know how far along it is). It eases toward ~96% over `expectedDuration` and never
//  claims 100%: the view simply disappears when the work finishes. Honest about "in progress" while
//  giving the user a visibly moving bar — useful for the slow photo-recognition path.
//

import SwiftUI

public struct TimedProgressView: View {
    private let message: String
    private let expectedDuration: TimeInterval
    @State private var start = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameters:
    ///   - message: caption under the bar.
    ///   - expectedDuration: a rough "typical" completion time; the bar reaches ~87% around here and
    ///     then keeps creeping (capped at 96%) so it never stalls visually.
    public init(_ message: String, expectedDuration: TimeInterval = 30) {
        self.message = message
        self.expectedDuration = expectedDuration
    }

    public var body: some View {
        VStack(spacing: Tokens.Space.s12) {
            if reduceMotion {
                // Reduce Motion: a continuously-filling bar is unnecessary movement → use the static
                // system indeterminate control instead (same as elsewhere in the app).
                ProgressView()
                    .controlSize(.large)
                    .tint(Tokens.Content.primary)
            } else {
                TimelineView(.animation) { context in
                    let elapsed = max(0, context.date.timeIntervalSince(start))
                    // Ease-out asymptote: rises fast, then slows; approaches but never reaches 1.
                    let progress = 1 - exp(-elapsed / (expectedDuration * 0.5))
                    ProgressView(value: min(progress, 0.96))
                        .tint(Tokens.Content.primary)
                }
                .frame(maxWidth: 240)
            }

            Text(message)
                .textStyle(Tokens.Text.subhead)
                .foregroundStyle(Tokens.Content.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(Tokens.Space.s24)
        .frame(maxWidth: .infinity)
        .onAppear { start = Date() }          // restart the clock each time the work begins
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
        .accessibilityAddTraits(.updatesFrequently)
    }
}
