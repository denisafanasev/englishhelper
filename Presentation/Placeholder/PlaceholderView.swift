//
//  PlaceholderView.swift
//  EnglishHelper — Presentation
//
//  Placeholder ONLY (Step 1 deliverable). Demonstrates that Presentation renders through the
//  DesignSystem tokens/components. No feature UI yet.
//

import SwiftUI
import DesignSystem

public struct PlaceholderView: View {
    private let status: String
    private let expressionCount: Int

    public init(status: String, expressionCount: Int) {
        self.status = status
        self.expressionCount = expressionCount
    }

    public var body: some View {
        VStack(spacing: Tokens.Space.s20) {
            Spacer()

            VStack(spacing: Tokens.Space.s8) {
                Text("EnglishHelper")
                    .textStyle(Tokens.Text.largeTitle)
                    .foregroundStyle(Tokens.Content.primary)
                Text(status)
                    .textStyle(Tokens.Text.subhead)
                    .foregroundStyle(Tokens.Content.secondary)
            }

            GlassCard {
                VStack(alignment: .leading, spacing: Tokens.Space.s8) {
                    Text("Study list")
                        .textStyle(Tokens.Text.footnote)
                        .foregroundStyle(Tokens.Content.tertiary)
                    Text("\(expressionCount) expressions")
                        .textStyle(Tokens.Text.title3)
                        .foregroundStyle(Tokens.Content.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: Tokens.Space.s8) {
                RegisterTagView(.formal)
                RegisterTagView(.casual)
                RegisterTagView(.slang)
            }

            Spacer()
        }
        .padding(Tokens.Space.s24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .screenBackground()
    }
}

#Preview {
    PlaceholderView(status: "Skeleton · running on mocks", expressionCount: 2)
}
