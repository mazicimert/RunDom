import SwiftUI

struct LevelBreakdownView: View {
    let totalTrail: Double

    @Environment(\.dismiss) private var dismiss

    private var current: PlayerLevel { PlayerLevel(totalTrail: totalTrail) }
    private var lastVisibleLevel: Int { max(current.level + 8, 12) }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 24) {
                        currentLevelCard
                        levelsList
                    }
                    .padding(.horizontal, AppConstants.UI.screenPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
                .onAppear {
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(rowID(for: current.level), anchor: .center)
                        }
                    }
                }
            }
            .navigationTitle("profile.level.sheet.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done".localized) { dismiss() }
                }
            }
        }
    }

    private var currentLevelCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.callout.weight(.bold))

                Text("profile.level.title".localized(with: current.level))
                    .font(.title3.weight(.bold))
            }
            .foregroundStyle(Color.accentColor)

            ProgressView(value: current.fraction)
                .progressViewStyle(.linear)
                .tint(Color.accentColor)
                .accessibilityValue(Text("\(Int((current.fraction * 100).rounded()))%"))

            HStack {
                Text("trail.points".localized(with: current.totalTrail.formattedTrail))
                    .font(.caption.weight(.semibold))

                Spacer()

                Text(remainingText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius, style: .continuous)
                .fill(Color.accentColor.opacity(0.10))
        )
    }

    private var levelsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("profile.level.sheet.allLevelsSection".localized)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            VStack(spacing: 8) {
                ForEach(1...lastVisibleLevel, id: \.self) { level in
                    row(for: level)
                        .id(rowID(for: level))
                }
            }
        }
    }

    @ViewBuilder
    private func row(for level: Int) -> some View {
        let isCurrent = level == current.level
        let isReached = level < current.level
        let threshold = PlayerLevel.threshold(for: level)
        let accent = rowAccent(reached: isReached, current: isCurrent)

        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accent.opacity(isCurrent ? 0.20 : 0.14))
                    .frame(width: 36, height: 36)

                Image(systemName: rowIcon(reached: isReached, current: isCurrent))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("profile.level.title".localized(with: level))
                    .font(.subheadline.weight(.semibold))

                Text(thresholdText(for: level, threshold: threshold))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if isCurrent {
                Text("profile.level.sheet.currentMarker".localized)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.accentColor.opacity(0.18))
                    )
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isCurrent ? Color.accentColor.opacity(0.08) : Color.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isCurrent ? Color.accentColor.opacity(0.45) : Color.clear, lineWidth: 1)
        )
    }

    private var remainingText: String {
        let pointsText = "trail.points".localized(with: current.remaining.formattedTrail)
        return "profile.level.remaining".localized(with: pointsText)
    }

    private func thresholdText(for level: Int, threshold: Double) -> String {
        if level == 1 {
            return "profile.level.sheet.startingLevel".localized
        }
        let pointsText = "trail.points".localized(with: threshold.formattedTrail)
        return "profile.level.sheet.requirement".localized(with: pointsText)
    }

    private func rowID(for level: Int) -> String { "level-\(level)" }

    private func rowIcon(reached: Bool, current: Bool) -> String {
        if current { return "location.fill" }
        if reached { return "checkmark" }
        return "lock.fill"
    }

    private func rowAccent(reached: Bool, current: Bool) -> Color {
        if current { return .accentColor }
        if reached { return .green }
        return .secondary
    }
}

#Preview("Mid-level") {
    LevelBreakdownView(totalTrail: 6_800)
}

#Preview("New runner") {
    LevelBreakdownView(totalTrail: 120)
}
