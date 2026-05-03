import SwiftUI

struct QuizContainerView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 0) {
                quizHeader
                    .padding(.horizontal, AppConstants.UI.screenPadding)
                    .padding(.top, 8)

                ScrollView {
                    currentQuestion
                        .padding(.horizontal, AppConstants.UI.screenPadding)
                        .padding(.top, 32)
                        .padding(.bottom, 24)
                }
                .id(viewModel.currentQuizIndex) // forces transition between questions

                Button {
                    viewModel.advanceQuiz()
                } label: {
                    Text(ctaLabel)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!viewModel.canAdvanceQuiz)
                .opacity(viewModel.canAdvanceQuiz ? 1 : 0.5)
                .padding(.horizontal, AppConstants.UI.screenPadding)
                .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        LinearGradient(
            colors: [
                Color.black,
                Color(red: 0.04, green: 0.08, blue: 0.16),
                Color.black
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Header

    private var quizHeader: some View {
        VStack(spacing: 14) {
            HStack {
                Button {
                    viewModel.previousQuiz()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }

                Spacer()

                Text(progressLabel)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.55))
            }

            QuizProgressBar(
                progress: Double(viewModel.currentQuizIndex + 1) / Double(viewModel.totalQuizQuestions)
            )
        }
    }

    private var progressLabel: String {
        "\(viewModel.currentQuizIndex + 1) / \(viewModel.totalQuizQuestions)"
    }

    private var ctaLabel: String {
        viewModel.isLastQuizQuestion
            ? "onboarding.quiz.complete".localized
            : "common.next".localized
    }

    // MARK: - Question Switch

    @ViewBuilder
    private var currentQuestion: some View {
        switch viewModel.currentQuizIndex {
        case 0: weeklyGoalQuestion
        case 1: motivationQuestion
        case 2: experienceQuestion
        case 3: modeQuestion
        default: EmptyView()
        }
    }

    private var weeklyGoalQuestion: some View {
        QuestionLayout(
            titleKey: "onboarding.quiz.weeklyGoal.title",
            subtitleKey: "onboarding.quiz.weeklyGoal.subtitle"
        ) {
            VStack(spacing: 12) {
                ForEach(WeeklyRunGoal.allCases) { goal in
                    QuizOptionCard(
                        title: goal.localizationKey.localized,
                        description: nil,
                        icon: icon(for: goal),
                        isSelected: viewModel.pendingProfile.weeklyGoal == goal
                    ) {
                        viewModel.selectWeeklyGoal(goal)
                    }
                }
            }
        }
    }

    private var motivationQuestion: some View {
        QuestionLayout(
            titleKey: "onboarding.quiz.motivation.title",
            subtitleKey: "onboarding.quiz.motivation.subtitle"
        ) {
            VStack(spacing: 12) {
                ForEach(RunnerMotivation.allCases) { motivation in
                    QuizOptionCard(
                        title: motivation.localizationKey.localized,
                        description: nil,
                        icon: icon(for: motivation),
                        isSelected: viewModel.pendingProfile.motivation == motivation
                    ) {
                        viewModel.selectMotivation(motivation)
                    }
                }
            }
        }
    }

    private var experienceQuestion: some View {
        QuestionLayout(
            titleKey: "onboarding.quiz.experience.title",
            subtitleKey: "onboarding.quiz.experience.subtitle"
        ) {
            VStack(spacing: 12) {
                ForEach(RunnerExperience.allCases) { experience in
                    QuizOptionCard(
                        title: experience.localizationKey.localized,
                        description: nil,
                        icon: icon(for: experience),
                        isSelected: viewModel.pendingProfile.experience == experience
                    ) {
                        viewModel.selectExperience(experience)
                    }
                }
            }
        }
    }

    private var modeQuestion: some View {
        QuestionLayout(
            titleKey: "onboarding.quiz.mode.title",
            subtitleKey: "onboarding.quiz.mode.subtitle"
        ) {
            VStack(spacing: 12) {
                QuizOptionCard(
                    title: "onboarding.quiz.mode.normal.label".localized,
                    description: "onboarding.quiz.mode.normal.description".localized,
                    icon: "checkmark.shield.fill",
                    isSelected: viewModel.pendingProfile.preferredMode == .normal
                ) {
                    viewModel.selectMode(.normal)
                }

                QuizOptionCard(
                    title: "onboarding.quiz.mode.boost.label".localized,
                    description: "onboarding.quiz.mode.boost.description".localized,
                    icon: "bolt.fill",
                    isSelected: viewModel.pendingProfile.preferredMode == .boost
                ) {
                    viewModel.selectMode(.boost)
                }
            }
        }
    }

    // MARK: - Icon mapping

    private func icon(for goal: WeeklyRunGoal) -> String {
        switch goal {
        case .two: return "calendar"
        case .four: return "calendar.badge.clock"
        case .six: return "calendar.badge.plus"
        case .daily: return "flame.fill"
        }
    }

    private func icon(for motivation: RunnerMotivation) -> String {
        switch motivation {
        case .competition: return "trophy.fill"
        case .health: return "heart.fill"
        case .exploration: return "map.fill"
        case .mindClearing: return "leaf.fill"
        }
    }

    private func icon(for experience: RunnerExperience) -> String {
        switch experience {
        case .beginner: return "figure.walk"
        case .casual: return "figure.walk.motion"
        case .regular: return "figure.run"
        case .competitive: return "medal.fill"
        }
    }
}

// MARK: - Question Layout

private struct QuestionLayout<Content: View>: View {
    let titleKey: String
    let subtitleKey: String?
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                Text(titleKey.localized)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if let subtitleKey {
                    Text(subtitleKey.localized)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Option Card

private struct QuizOptionCard: View {
    let title: String
    let description: String?
    let icon: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? Color.accentColor : Color.white.opacity(0.08))
                        .frame(width: 48, height: 48)

                    Image(systemName: icon)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.85))
                }

                VStack(alignment: .leading, spacing: description == nil ? 0 : 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)

                    if let description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.white.opacity(0.3))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(isSelected ? 0.1 : 0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius, style: .continuous)
                    .stroke(
                        isSelected ? Color.accentColor : Color.white.opacity(0.06),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: AppConstants.Animation.quick), value: isSelected)
    }
}

// MARK: - Progress Bar

private struct QuizProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.1))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(8, geo.size.width * progress))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: progress)
            }
        }
        .frame(height: 6)
    }
}

#Preview {
    QuizContainerView(viewModel: OnboardingViewModel())
}
