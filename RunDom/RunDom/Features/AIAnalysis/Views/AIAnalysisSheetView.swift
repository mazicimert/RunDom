import SwiftUI

struct AIRunAnalysisSheetView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AIRunAnalysisViewModel

    init(session: RunSession, trailResult: TrailCalculator.TrailResult, neighborhood: String?) {
        _viewModel = StateObject(wrappedValue: AIRunAnalysisViewModel(
            session: session,
            trailResult: trailResult,
            neighborhood: neighborhood
        ))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("ai.run.title".localized)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("common.done".localized) {
                            dismiss()
                        }
                    }
                }
                .task {
                    if let user = appState.currentUser {
                        await viewModel.generateIfNeeded(user: user)
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            AIAnalysisLoadingView(message: "ai.run.loading".localized)

        case .loaded(let result):
            ScrollView {
                AIRunAnalysisCardView(
                    analysis: result.analysis,
                    source: result.source,
                    fallbackMessage: nil
                )
                .padding(20)
            }

        case .fallback(let result, let error):
            ScrollView {
                AIRunAnalysisCardView(
                    analysis: result.analysis,
                    source: result.source,
                    fallbackMessage: error
                )
                .padding(20)
            }
        }
    }
}

struct AIWeeklyAnalysisSheetView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AIWeeklyAnalysisViewModel()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("ai.weekly.title".localized)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("common.done".localized) {
                            dismiss()
                        }
                    }
                }
                .task {
                    guard case .idle = viewModel.state else { return }
                    if let user = appState.currentUser {
                        await viewModel.generate(user: user)
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .loading:
            AIAnalysisLoadingView(message: "ai.weekly.loading".localized)

        case .loaded(let result):
            ScrollView {
                AIWeeklyAnalysisCardView(
                    analysis: result.analysis,
                    source: result.source,
                    fallbackMessage: nil
                )
                .padding(20)
            }

        case .fallback(let result, let error):
            ScrollView {
                AIWeeklyAnalysisCardView(
                    analysis: result.analysis,
                    source: result.source,
                    fallbackMessage: error
                )
                .padding(20)
            }
        }
    }
}

private struct AIAnalysisLoadingView: View {
    let message: String

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            CroppedLoadingAnimation()

            VStack(spacing: 8) {
                Text(message)
                    .font(.headline)
                Text("ai.loading.subtitle".localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            ProgressView()
                .progressViewStyle(.circular)
                .tint(Color.accentColor)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(20)
    }
}

private struct CroppedLoadingAnimation: View {
    private let visibleSize = CGSize(width: 190, height: 140)
    private let animationSize: CGFloat = 250

    var body: some View {
        LottieView(
            animationName: "loading",
            loopMode: .loop,
            contentMode: .scaleAspectFit
        )
        .frame(width: animationSize, height: animationSize)
        .offset(y: -18)
        .frame(width: visibleSize.width, height: visibleSize.height)
        .clipped()
        .accessibilityHidden(true)
    }
}
