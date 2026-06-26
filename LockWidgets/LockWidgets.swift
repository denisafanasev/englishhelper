//
//  LockWidgets.swift
//  EnglishHelper — Lock Screen widgets (WidgetKit extension)
//
//  Three accessoryCircular Lock Screen widgets that DEEP-LINK straight into a scenario:
//    • See it / Explain     englishhelper://seeit   (camera → explain what you point at)
//    • Get it / Explain      englishhelper://getit   (text   → explain a word/phrase)
//    • Say it / How to say   englishhelper://sayit   (voice  → how to say something)
//
//  Each is a STATIC launcher (no data, no refresh — one `.never` timeline entry) plus a `.widgetURL`
//  the app's RootView.onOpenURL routes to the right tab + mode. The icon reuses the app's MENU glyph
//  (camera / character bubble / mic) and adds ONE shared brand mark — a top-trailing `sparkle` — so the
//  three read as a family and aren't mistaken for the stock Camera / Messages / Voice Memos widgets.
//  Lock Screen accessory widgets render monochrome/vibrant, so these are pure SF Symbols in the
//  foreground tint (hue would be discarded anyway) sized to survive desaturation at Lock-Screen scale.
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

/// One circular face: the scenario glyph centered + the shared `sparkle` brand mark top-trailing, over
/// the standard translucent Lock Screen disc. `.containerBackground(for: .widget)` is required on iOS 17+.
private struct WidgetFace: View {
    let glyph: String

    var body: some View {
        ZStack {
            Image(systemName: glyph)
                .font(.system(size: 19, weight: .semibold))
            Image(systemName: "sparkle")              // shared EnglishHelper brand mark (AI/transform cue)
                .font(.system(size: 9, weight: .bold))
                .offset(x: 10, y: -10)                // sits in the empty top-trailing arc of the disc
        }
        .foregroundStyle(.primary)                    // resolved to the Lock Screen tint; monochrome-safe
        .widgetAccentable()
        .containerBackground(for: .widget) { AccessoryWidgetBackground() }
    }
}

// MARK: - The three widgets (each its own stable kind + deep link)

struct SeeItWidget: Widget {
    let kind = "tech.10xt.englishhelper.widget.seeit"   // STABLE forever — changing it orphans placed widgets
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LockProvider()) { _ in
            WidgetFace(glyph: "camera.fill")
                .widgetURL(URL(string: "englishhelper://seeit"))
        }
        .configurationDisplayName("See it · Explain")
        .description("Point the camera and explain what it shows.")
        .supportedFamilies([.accessoryCircular])        // Lock Screen circular only
    }
}

struct GetItWidget: Widget {
    let kind = "tech.10xt.englishhelper.widget.getit"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LockProvider()) { _ in
            WidgetFace(glyph: "character.bubble.fill")
                .widgetURL(URL(string: "englishhelper://getit"))
        }
        .configurationDisplayName("Get it · Explain")
        .description("Explain a word or phrase.")
        .supportedFamilies([.accessoryCircular])
    }
}

struct SayItWidget: Widget {
    let kind = "tech.10xt.englishhelper.widget.sayit"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LockProvider()) { _ in
            WidgetFace(glyph: "mic.fill")
                .widgetURL(URL(string: "englishhelper://sayit"))
        }
        .configurationDisplayName("Say it · How to say")
        .description("Learn how to say something.")
        .supportedFamilies([.accessoryCircular])
    }
}

@main
struct LockWidgetsBundle: WidgetBundle {
    var body: some Widget {
        SeeItWidget()
        GetItWidget()
        SayItWidget()
    }
}
