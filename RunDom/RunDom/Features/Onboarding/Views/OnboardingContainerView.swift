import SwiftUI

struct OnboardingContainerView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Skip button
            HStack {
                Spacer()
                Button("common.skip".localized) {
                    viewModel.skipPages()
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.trailing, AppConstants.UI.screenPadding)
                .padding(.top, 8)
            }

            // Page content
            TabView(selection: $viewModel.currentPage) {
                ForEach(Array(viewModel.pages.enumerated()), id: \.offset) { index, page in
                    OnboardingPageView(
                        mediaAssetName: page.mediaAssetName,
                        mediaStyle: page.mediaStyle,
                        title: page.titleKey.localized,
                        subtitle: page.subtitleKey.localized,
                        supportingText: viewModel.supportingText(for: index),
                        accentColor: page.accentColor,
                        isActive: viewModel.currentPage == index
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Bottom section
            VStack(spacing: 18) {
                // Page indicator
                HStack(spacing: 10) {
                    ForEach(0..<viewModel.totalPages, id: \.self) { index in
                        Capsule(style: .continuous)
                            .fill(index == viewModel.currentPage ? Color.accentColor : Color.secondary.opacity(0.28))
                            .frame(width: index == viewModel.currentPage ? 22 : 8, height: 8)
                            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: viewModel.currentPage)
                    }
                }

                // Next / Get Started button
                Button {
                    viewModel.nextPage()
                } label: {
                    Text(buttonTitle)
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, AppConstants.UI.screenPadding)
            }
            .padding(.bottom, 40)
        }
        .background(
            LinearGradient(
                colors: [
                    Color.black,
                    Color.black.opacity(0.96),
                    Color.accentColor.opacity(0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .onAppear {
            viewModel.trackPageViewed(viewModel.currentPage)
        }
        .onChange(of: viewModel.currentPage) { _, newValue in
            viewModel.trackPageViewed(newValue)
        }
    }

    private var buttonTitle: String {
        guard viewModel.currentPage == viewModel.totalPages - 1 else {
            return "common.next".localized
        }

        return viewModel.pages[viewModel.currentPage].primaryCTAKey?.localized
            ?? "onboarding.getStarted".localized
    }
}

#Preview {
    OnboardingContainerView(viewModel: OnboardingViewModel())
}
