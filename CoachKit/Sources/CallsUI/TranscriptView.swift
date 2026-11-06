import CallArchive
import Foundation
import SwiftUI

/// Transcription d'un call, en script : l'heure, qui parle, le texte.
struct TranscriptView: View {
    let lines: [SavedCall.Line]
    /// Réplique ouverte depuis le débrief : montrée et surlignée.
    let highlightedLine: Int?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        TranscriptRow(line: line, isHighlighted: index == highlightedLine)
                            .id(index)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .onAppear {
                if let highlightedLine {
                    proxy.scrollTo(highlightedLine, anchor: .center)
                }
            }
            .onChange(of: highlightedLine) {
                if let highlightedLine {
                    withAnimation { proxy.scrollTo(highlightedLine, anchor: .center) }
                }
            }
        }
    }
}

/// Réplique : son moment, qui parle (« Moi » en violet), et le texte.
private struct TranscriptRow: View {
    let line: SavedCall.Line
    let isHighlighted: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(CallTime.label(line.start))
                .monospacedDigit()
                .foregroundStyle(.tertiary)
                .frame(width: 56, alignment: .leading)
            Text(line.speaker == .me ? "Moi" : "Interlocuteur")
                .fontWeight(.semibold)
                .foregroundStyle(line.speaker == .me ? CallsStyle.violet : .secondary)
                .frame(width: 96, alignment: .leading)
            Text(line.text)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 10)
        .background(isHighlighted ? CallsStyle.violet.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 6))
        .overlay(alignment: .leading) {
            if isHighlighted {
                Rectangle().fill(CallsStyle.violet).frame(width: 3)
            }
        }
    }
}
