import CallArchive
import Foundation
import SwiftUI

/// Onglet Résumé : la vue d'ensemble, les points importants et les prochaines étapes.
struct SummaryView: View {
    let summary: CallRecap.Summary

    var body: some View {
        ReadingColumn {
            Text(summary.overview)
            if !summary.keyPoints.isEmpty {
                RecapSection("Points importants") {
                    ForEach(summary.keyPoints, id: \.self) { BulletItem($0) }
                }
            }
            if !summary.nextSteps.isEmpty {
                RecapSection("Prochaines étapes") {
                    ForEach(summary.nextSteps, id: \.self) { BulletItem($0) }
                }
            }
        }
    }
}

/// Onglet Débrief : ce qui a marché, puis ce qui est à travailler, chaque point avec sa phrase d'origine et une
/// meilleure formulation.
struct DebriefView: View {
    let debrief: CallRecap.Debrief
    /// Ouvre la transcription sur le moment d'une phrase citée.
    let openMoment: (TimeInterval) -> Void

    var body: some View {
        ReadingColumn {
            if !debrief.strengths.isEmpty {
                RecapSection("Ce qui a marché") {
                    ForEach(debrief.strengths, id: \.self) { strength in
                        SparkleItem(color: CallsStyle.strength) { Text(strength) }
                    }
                }
            }
            if !debrief.improvements.isEmpty {
                RecapSection("À travailler") {
                    ForEach(Array(debrief.improvements.enumerated()), id: \.offset) { _, improvement in
                        SparkleItem(color: CallsStyle.improvement) { improvementDetail(improvement) }
                    }
                }
            }
        }
    }

    private func improvementDetail(_ improvement: CallRecap.Improvement) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(improvement.issue)
            if improvement.quote != nil || improvement.moment != nil {
                HStack(alignment: .top, spacing: 10) {
                    Rectangle().fill(CallsStyle.violet).frame(width: 3)
                    VStack(alignment: .leading, spacing: 3) {
                        if let moment = improvement.moment {
                            Button("Toi, à \(CallTime.label(moment))") { openMoment(moment) }
                                .buttonStyle(.plain)
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(CallsStyle.violet)
                                .pointerStyle(.link)
                                .help("Ouvrir la transcription à ce moment")
                        }
                        if let quote = improvement.quote {
                            Text("«\u{00A0}\(quote)\u{00A0}»")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            (Text("Mieux ").font(.callout.weight(.semibold)).foregroundStyle(CallsStyle.ink)
                + Text("«\u{00A0}\(improvement.betterPhrasing)\u{00A0}»"))
        }
    }
}

/// Colonne de lecture : le serif de lecture, moins de 80 caractères par ligne, texte sélectionnable.
private struct ReadingColumn<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            content
        }
        .font(CallsStyle.reading)
        .lineSpacing(CallsStyle.readingLineSpacing)
        .textSelection(.enabled)
        .frame(maxWidth: CallsStyle.readingWidth, alignment: .leading)
        .padding(.horizontal, 28)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Rubrique du compte rendu : son nom, puis ses éléments.
private struct RecapSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(CallsStyle.ink)
            content
        }
    }
}

/// Élément de liste du résumé.
private struct BulletItem: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("•").foregroundStyle(.secondary)
            Text(text)
        }
    }
}

/// Élément du débrief, marqué par une étincelle de l'icône : verte pour ce qui a marché, jaune pour ce qui est à
/// travailler.
private struct SparkleItem<Content: View>: View {
    let color: Color
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("✦").foregroundStyle(color).accessibilityHidden(true)
            content
        }
    }
}
