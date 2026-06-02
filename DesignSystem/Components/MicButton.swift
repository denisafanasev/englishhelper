//
//  MicButton.swift
//  EnglishHelper — DesignSystem
//
//  Voice capture control. State is expressed through MOTION (per the design: diverging rings while
//  listening, spinner while processing), with a Reduce Motion fallback to a static treatment.
//

import SwiftUI

public struct MicButton: View {
    public enum Status: Sendable { case idle, listening, processing }

    private let status: Status
    private let action: () -> Void
    private let size: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    public init(status: Status, size: CGFloat = 88, action: @escaping () -> Void) {
        self.status = status
        self.size = size
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
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
        }
        .buttonStyle(.plain)
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
