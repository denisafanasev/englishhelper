//
//  StatusViews.swift
//  EnglishHelper — DesignSystem
//
//  The mandatory non-content states: loading · empty · error · offline. One shared shape so they
//  read consistently.
//

import SwiftUI

/// Centered icon + title + message + optional action. Use for empty / error / offline.
public struct StatusView: View {
    private let systemImage: String
    private let title: String
    private let message: String?
    private let actionTitle: String?
    private let action: (() -> Void)?

    public init(systemImage: String, title: String, message: String? = nil,
                actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: Tokens.Space.s12) {
            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(Tokens.Content.tertiary)
            Text(title)
                .textStyle(Tokens.Text.headline)
                .foregroundStyle(Tokens.Content.primary)
                .multilineTextAlignment(.center)
            if let message {
                Text(message)
                    .textStyle(Tokens.Text.subhead)
                    .foregroundStyle(Tokens.Content.secondary)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                EHButton(actionTitle, kind: .tonal, action: action)
                    .fixedSize()
                    .padding(.top, Tokens.Space.s4)
            }
        }
        .padding(Tokens.Space.s24)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// Indeterminate progress with a caption.
public struct LoadingView: View {
    private let message: String
    public init(_ message: String) { self.message = message }
    public var body: some View {
        VStack(spacing: Tokens.Space.s12) {
            ProgressView()
                .controlSize(.large)
                .tint(Tokens.Content.secondary)
            Text(message)
                .textStyle(Tokens.Text.subhead)
                .foregroundStyle(Tokens.Content.secondary)
        }
        .padding(Tokens.Space.s24)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }
}
