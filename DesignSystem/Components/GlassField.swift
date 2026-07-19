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
    private let accessibilityID: String?
    /// Non-nil = the field is a fixed BOX of exactly this TOTAL height (padding included), matching
    /// a sibling pane pixel-for-pixel; long text scrolls INSIDE instead of growing the box.
    /// Nil = the default compact field that grows from one line up to four as the user types.
    private let fixedHeight: CGFloat?
    private let onSubmit: () -> Void

    public init(_ placeholder: String, text: Binding<String>,
                accessibilityID: String? = nil, fixedHeight: CGFloat? = nil,
                onSubmit: @escaping () -> Void = {}) {
        self.placeholder = placeholder
        self._text = text
        self.accessibilityID = accessibilityID
        self.fixedHeight = fixedHeight
        self.onSubmit = onSubmit
    }

    public var body: some View {
        HStack(alignment: .top, spacing: Tokens.Space.s8) {
            field
                .textStyle(Tokens.Text.body)
                .foregroundStyle(Tokens.Content.primary)
                .submitLabel(.go)
                .onSubmit(onSubmit)
                .accessibilityIdentifier(accessibilityID ?? "")

            // Clear-all affordance: appears once there's text, wipes the field to start fresh.
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Tokens.Content.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(DSLoc.t("Очистить", "Clear"))
            }
        }
        .padding(.horizontal, Tokens.Space.s16)
        .padding(.vertical, Tokens.Space.s12)
        .glassPanel(cornerRadius: Tokens.Radius.control)
    }

    @ViewBuilder private var field: some View {
        if let fixedHeight {
            // A TextEditor (scrolls internally, tracks the caret) inside a hard frame: the box
            // NEVER changes size, no matter how much text is typed or pasted. TextEditor has no
            // placeholder, so it's overlaid, aligned to the editor's default text insets.
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .textStyle(Tokens.Text.body)
                        .foregroundStyle(Tokens.Content.tertiary)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .accessibilityHidden(true)
                }
                TextEditor(text: $text)
                    .scrollContentBackground(.hidden)   // glass shows through
            }
            .frame(height: fixedHeight - 2 * Tokens.Space.s12)   // total box = content + s12 padding
        } else {
            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(1...4)
        }
    }
}
