//
//  GlassField.swift
//  EnglishHelper — DesignSystem
//
//  Glass-surfaced multiline text input (e.g. typed Russian intent).
//

import SwiftUI

public struct GlassField: View {
    private let placeholder: String
    @Binding private var text: String
    private let onSubmit: () -> Void

    public init(_ placeholder: String, text: Binding<String>, onSubmit: @escaping () -> Void = {}) {
        self.placeholder = placeholder
        self._text = text
        self.onSubmit = onSubmit
    }

    public var body: some View {
        TextField(placeholder, text: $text, axis: .vertical)
            .textStyle(Tokens.Text.body)
            .foregroundStyle(Tokens.Content.primary)
            .lineLimit(1...4)
            .submitLabel(.go)
            .onSubmit(onSubmit)
            .padding(.horizontal, Tokens.Space.s16)
            .padding(.vertical, Tokens.Space.s12)
            .glassPanel(cornerRadius: Tokens.Radius.control)
    }
}
