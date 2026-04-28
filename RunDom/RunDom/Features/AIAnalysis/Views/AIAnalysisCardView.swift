import SwiftUI

struct AIRunAnalysisCardView: View {
    let analysis: AIRunAnalysis
    let source: AIAnalysisSource
    let fallbackMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            AIAnalysisHeaderView(source: source, fallbackMessage: fallbackMessage)

            AIAnalysisSection(
                title: "ai.run.section.summary".localized,
                icon: "text.alignleft"
            ) {
                Text(analysis.runSummary)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            AIAnalysisSection(
                title: "ai.run.section.highlights".localized,
                icon: "sparkles"
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(analysis.highlights.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 6, height: 6)
                                .padding(.top, 7)
                            Text(item)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            AIAnalysisSection(
                title: "ai.run.section.commentary".localized,
                icon: "quote.bubble.fill",
                isPrimary: true
            ) {
                Text(analysis.aiCommentary)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            AIAnalysisSection(
                title: "ai.run.section.next".localized,
                icon: "arrow.up.right.circle.fill"
            ) {
                Text(analysis.nextSuggestion)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            AIDisclaimerFooterView()
        }
    }
}

struct AIWeeklyAnalysisCardView: View {
    let analysis: AIWeeklyAnalysis
    let source: AIAnalysisSource
    let fallbackMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            AIAnalysisHeaderView(source: source, fallbackMessage: fallbackMessage)

            AIAnalysisSection(
                title: "ai.weekly.section.trend".localized,
                icon: "chart.line.uptrend.xyaxis"
            ) {
                Text(analysis.weekTrend)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            AIAnalysisSection(
                title: "ai.weekly.section.top".localized,
                icon: "trophy.fill"
            ) {
                Text(analysis.topAchievement)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            AIAnalysisSection(
                title: "ai.weekly.section.weak".localized,
                icon: "exclamationmark.triangle.fill"
            ) {
                Text(analysis.weakPoint)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            AIAnalysisSection(
                title: "ai.weekly.section.focus".localized,
                icon: "scope",
                isPrimary: true
            ) {
                Text(analysis.nextWeekFocus)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            AIDisclaimerFooterView()
        }
    }
}

private struct AIAnalysisHeaderView: View {
    let source: AIAnalysisSource
    let fallbackMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: source == .ai ? "sparkles" : "doc.text.magnifyingglass")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(source == .ai ? Color.accentColor : .secondary)

                Text(source == .ai
                     ? "ai.badge.gemini".localized
                     : "ai.badge.template".localized)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(source == .ai ? Color.accentColor : .secondary)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill((source == .ai ? Color.accentColor : Color.secondary).opacity(0.10))
            )

            if let fallbackMessage {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.orange)
                    Text(fallbackMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.orange.opacity(0.10))
                )
            }
        }
    }
}

private struct AIAnalysisSection<Content: View>: View {
    let title: String
    let icon: String
    var isPrimary: Bool = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isPrimary ? Color.accentColor : .secondary)
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
            }

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isPrimary
                      ? Color.accentColor.opacity(0.08)
                      : Color.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            isPrimary
                                ? Color.accentColor.opacity(0.25)
                                : Color.secondary.opacity(0.12),
                            lineWidth: 1
                        )
                )
        )
    }
}

private struct AIDisclaimerFooterView: View {
    var body: some View {
        Text("ai.disclaimer".localized)
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
