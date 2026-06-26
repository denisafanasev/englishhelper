//
//  LockWidgets.swift
//  EnglishHelper — Lock Screen widgets (WidgetKit extension)
//
//  Six accessoryCircular Lock Screen widgets — one per scenario — that DEEP-LINK straight in via the
//  englishhelper:// scheme and (per RootView) open the camera or mic on arrival:
//
//    See it · Explain     seeit            See it · Translate     seeit-translate
//    Get it · Explain      getit            Get it · Translate      getit-translate
//    Say it · How to say   sayit            Say it · What to say    sayit-what
//
//  Each is a STATIC launcher (one `.never` timeline entry + a `.widgetURL`). The icon encodes TWO axes
//  so all six are visually distinct on the Lock Screen:
//    • INPUT MODALITY = the centered base glyph, reused from the app menu: camera / character bubble / mic.
//    • MODE = a small corner badge: `lightbulb` (Explain / What-to-say) vs `globe` (Translate / How-to-say).
//  Lock Screen accessory widgets render monochrome/vibrant, so these are pure SF Symbols in the
//  foreground tint (hue is discarded anyway); the modality glyph + mode badge carry the meaning by SHAPE.
//

import WidgetKit
import SwiftUI

private struct LockEntry: TimelineEntry { let date: Date }

private struct LockProvider: TimelineProvider {
    func placeholder(in context: Context) -> LockEntry { LockEntry(date: .now) }
    func getSnapshot(in context: Context, completion: @escaping (LockEntry) -> Void) {
        completion(LockEntry(date: .now))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<LockEntry>) -> Void) {
        completion(Timeline(entries: [LockEntry(date: .now)], policy: .never))   // pure launcher: never refresh
    }
}

/// A circular face: the MODALITY glyph centered, with the MODE glyph as a small bottom-trailing badge
/// over the standard translucent Lock Screen disc. `.containerBackground(for: .widget)` is required on
/// iOS 17+. Both glyphs use `.primary` (the Lock Screen tint) so they survive monochrome desaturation.
private struct WidgetFace: View {
    let modality: String   // camera.fill / character.bubble.fill / mic.fill
    let mode: String       // lightbulb.fill (Explain / What-to-say) | globe (Translate / How-to-say)

    var body: some View {
        Image(systemName: modality)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(.primary)
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: mode)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.primary)
                    .padding(2.5)
                    .background(.thinMaterial, in: Circle())   // a small frosted chip so the badge reads
                    .offset(x: 5, y: 5)
            }
            .widgetAccentable()
            .containerBackground(for: .widget) { AccessoryWidgetBackground() }
    }
}

// MARK: - The six widgets (each its own STABLE kind + deep link)

struct SeeItExplainWidget: Widget {
    let kind = "tech.10xt.englishhelper.widget.seeit"            // STABLE — do not change post-ship
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LockProvider()) { _ in
            WidgetFace(modality: "camera.fill", mode: "lightbulb.fill")
                .widgetURL(URL(string: "englishhelper://seeit"))
        }
        .configurationDisplayName("See it · Explain")
        .description("Camera → explain what it shows.")
        .supportedFamilies([.accessoryCircular])
    }
}

struct SeeItTranslateWidget: Widget {
    let kind = "tech.10xt.englishhelper.widget.seeit.translate"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LockProvider()) { _ in
            WidgetFace(modality: "camera.fill", mode: "globe")
                .widgetURL(URL(string: "englishhelper://seeit-translate"))
        }
        .configurationDisplayName("See it · Translate")
        .description("Camera → translate the text in it.")
        .supportedFamilies([.accessoryCircular])
    }
}

struct GetItExplainWidget: Widget {
    let kind = "tech.10xt.englishhelper.widget.getit"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LockProvider()) { _ in
            WidgetFace(modality: "character.bubble.fill", mode: "lightbulb.fill")
                .widgetURL(URL(string: "englishhelper://getit"))
        }
        .configurationDisplayName("Get it · Explain")
        .description("Explain a word or phrase.")
        .supportedFamilies([.accessoryCircular])
    }
}

struct GetItTranslateWidget: Widget {
    let kind = "tech.10xt.englishhelper.widget.getit.translate"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LockProvider()) { _ in
            WidgetFace(modality: "character.bubble.fill", mode: "globe")
                .widgetURL(URL(string: "englishhelper://getit-translate"))
        }
        .configurationDisplayName("Get it · Translate")
        .description("Translate a word or phrase.")
        .supportedFamilies([.accessoryCircular])
    }
}

struct SayItHowWidget: Widget {
    let kind = "tech.10xt.englishhelper.widget.sayit"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LockProvider()) { _ in
            WidgetFace(modality: "mic.fill", mode: "globe")
                .widgetURL(URL(string: "englishhelper://sayit"))
        }
        .configurationDisplayName("Say it · How to say")
        .description("Learn how to say something.")
        .supportedFamilies([.accessoryCircular])
    }
}

struct SayItWhatWidget: Widget {
    let kind = "tech.10xt.englishhelper.widget.sayit.what"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LockProvider()) { _ in
            WidgetFace(modality: "mic.fill", mode: "lightbulb.fill")
                .widgetURL(URL(string: "englishhelper://sayit-what"))
        }
        .configurationDisplayName("Say it · What to say")
        .description("Ideas for what to say in a situation.")
        .supportedFamilies([.accessoryCircular])
    }
}

@main
struct LockWidgetsBundle: WidgetBundle {
    var body: some Widget {
        SeeItExplainWidget()
        SeeItTranslateWidget()
        GetItExplainWidget()
        GetItTranslateWidget()
        SayItHowWidget()
        SayItWhatWidget()
    }
}
