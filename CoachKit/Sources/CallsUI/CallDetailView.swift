import CallArchive
import Foundation
import SwiftUI

/// Call choisi : son en-tête, puis trois onglets, Résumé, Débrief et Transcription.
struct CallDetailView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case summary = "Résumé"
        case debrief = "Débrief"
        case transcript = "Transcription"

        var id: Self { self }
    }

    let call: SavedCall
    @Binding var tab: Tab
    /// « Réessayer », quand le compte rendu n'a pas pu être écrit.
    let onRetry: () -> Void
    /// Moment ouvert depuis le débrief, surligné dans la transcription.
    @State private var highlightedMoment: TimeInterval?

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            // Le titre du call, son détail et les onglets vont dans la barre d'outils, comme dans Mail ou Notes.
            .navigationTitle(CallFormat.title(of: call))
            .navigationSubtitle(CallFormat.headerDetail(of: call, now: Date()))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Picker("Onglet", selection: $tab) {
                        ForEach(Tab.allCases) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
            }
            .onChange(of: call.id) {
                highlightedMoment = nil
            }
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .summary:
            recap { SummaryView(summary: $0.summary) }
        case .debrief:
            recap { recap in
                DebriefView(debrief: recap.debrief) { moment in
                    highlightedMoment = moment
                    tab = .transcript
                }
            }
        case .transcript:
            TranscriptView(lines: call.transcript, highlightedLine: highlightedMoment.flatMap(call.lineIndex(at:)))
        }
    }

    /// Compte rendu écrit, ou ce qui le remplace : Claude en train d'écrire, ou l'échec et « Réessayer ».
    @ViewBuilder
    private func recap(@ViewBuilder _ written: (CallRecap) -> some View) -> some View {
        switch call.recapStatus {
        case .written(let recap):
            ScrollView {
                written(recap)
            }
        case .writing:
            VStack(spacing: 10) {
                ProgressView()
                Text("Claude écrit le compte rendu…")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let reason):
            ContentUnavailableView {
                Label("Le compte rendu n'a pas pu être écrit", systemImage: "exclamationmark.bubble")
            } description: {
                Text("\(reason)\nLa transcription reste disponible.")
            } actions: {
                Button("Réessayer", action: onRetry)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
