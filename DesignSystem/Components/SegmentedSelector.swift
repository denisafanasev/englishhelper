//
//  SegmentedSelector.swift
//  EnglishHelper — DesignSystem
//
//  Monochrome segmented control: one row of equal-width segments in a tonal track, the selected
//  one filled with the inverted surface. Used for the on-screen tone picker ("Сказать") and the
//  translate/explain mode picker ("Понять").
//
//  Value + callback (NOT a Binding) so the owning view model can react to a change with a side
//  effect — e.g. re-running generation in the new tone/mode. All fills are solid, so it reads the
//  same under Reduce Transparency.
//

import SwiftUI

public struct SegmentedSelector<Option: Hashable>: View {
    private let options: [Option]
    private let selected: Option
    private let label: (Option) -> String
    private let onSelect: (Option) -> Void

    public init(
        _ options: [Option],
        selected: Option,
        label: @escaping (Option) -> String,
        onSelect: @escaping (Option) -> Void
    ) {
        self.options = options
        self.selected = selected
        self.label = label
        self.onSelect = onSelect
    }

    public var body: some View {
        HStack(spacing: Tokens.Space.s4) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selected
                Button { onSelect(option) } label: {
                    Text(label(option))
                        .font(.system(size: 14, weight: .semibold))
                        .tracking(-0.1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(isSelected ? Tokens.Content.onInvert : Tokens.Content.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Tokens.Space.s8)
                        .background {
                            if isSelected {
                                Capsule().fill(Tokens.Surface.invert)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(Tokens.Space.s4)
        .background(Capsule().fill(Tokens.Fill.default))
        .animation(Tokens.Motion.quick, value: selected)
    }
}
