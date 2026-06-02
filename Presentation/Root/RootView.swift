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
    @State private var photo: PhotoTranslateViewModel
    @State private var library: StudyListViewModel
    @State private var history: HistoryViewModel

    public init(
        voice: VoiceViewModel,
        translate: TranslateViewModel,
        photo: PhotoTranslateViewModel,
        library: StudyListViewModel,
        history: HistoryViewModel
    ) {
        _voice = State(initialValue: voice)
        _translate = State(initialValue: translate)
        _photo = State(initialValue: photo)
        _library = State(initialValue: library)
        _history = State(initialValue: history)
    }

    public var body: some View {
        TabView {
            Tab("Голос", systemImage: "mic.fill") {
                VoiceView(model: voice)
            }
            Tab("Перевод", systemImage: "character.bubble") {
                TranslateView(model: translate)
            }
            Tab("Камера", systemImage: "camera") {
                PhotoTranslateView(model: photo)
            }
            Tab("Изучаю", systemImage: "rectangle.stack") {
                StudyListView(model: library)
            }
            Tab("История", systemImage: "clock.arrow.circlepath") {
                HistoryView(model: history)
            }
        }
    }
}
