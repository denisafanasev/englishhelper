//
//  RootView.swift
//  EnglishHelper — Presentation
//
//  App shell. v1 is built screen by screen; tabs accumulate each step (the native TabView renders
//  the Liquid-Glass tab bar). Final structure is reconciled once all screens exist.
//

import SwiftUI

public struct RootView: View {
    @State private var voice: VoiceViewModel
    @State private var translate: TranslateViewModel

    public init(voice: VoiceViewModel, translate: TranslateViewModel) {
        _voice = State(initialValue: voice)
        _translate = State(initialValue: translate)
    }

    public var body: some View {
        TabView {
            Tab("Голос", systemImage: "mic.fill") {
                VoiceView(model: voice)
            }
            Tab("Перевод", systemImage: "character.bubble") {
                TranslateView(model: translate)
            }
        }
    }
}
