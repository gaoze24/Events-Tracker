//
//  QuickLookPreviewView.swift
//  Events Tracker
//

import Quartz
import SwiftUI

struct QuickLookPreviewItem: Identifiable, Hashable {
    let url: URL
    let title: String

    var id: String {
        url.path
    }
}

struct QuickLookPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    let item: QuickLookPreviewItem

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            QuickLookPreviewView(url: item.url)
                .frame(minWidth: 720, minHeight: 520)
        }
    }
}

struct QuickLookPreviewView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> QLPreviewView {
        let previewView = QLPreviewView(frame: .zero, style: .normal)
        previewView?.previewItem = url as NSURL
        return previewView ?? QLPreviewView()
    }

    func updateNSView(_ nsView: QLPreviewView, context: Context) {
        nsView.previewItem = url as NSURL
    }
}
