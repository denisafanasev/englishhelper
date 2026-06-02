//
//  RootView.swift
//  EnglishHelper — Presentation
//
//  App root. v1 is being built screen by screen — currently hosts "Как сказать". A tab bar
//  (Voice / Study / Camera) replaces this once more screens land.
//

import SwiftUI

public struct RootView: View {
    private let voiceModel: VoiceViewModel

    public init(voice: VoiceViewModel) {
        self.voiceModel = voice
    }

    public var body: some View {
        VoiceView(model: voiceModel)
    }
}
