//
//  ShareSheet.swift
//  EnglishHelper — Presentation
//
//  UIActivityViewController bridge for the system share sheet (exporting the AlgoApp .xml deck).
//

import SwiftUI
import UIKit

/// Identifiable wrapper so the share sheet can be presented via `.sheet(item:)`.
struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
