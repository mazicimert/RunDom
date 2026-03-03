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
                        icon: page.icon,
                        title: page.title,
                        subtitle: page.subtitle
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Bottom section
            VStack(spacing: 20) {
                // Page indicator
                HStack(spacing: 8) {
                    ForEach(0..<viewModel.totalPages, id: \.self) { index in
                        Circle()
                            .fill(index == viewModel.currentPage ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: index == viewModel.currentPage ? 10 : 8,
                                   height: index == viewModel.currentPage ? 10 : 8)
                            .animation(.easeInOut(duration: AppConstants.Animation.quick), value: viewModel.currentPage)
                    }
                }

                // Next / Get Started button
                Button {
                    viewModel.nextPage()
                } label: {
                    Text(viewModel.currentPage == viewModel.totalPages - 1
                         ? "onboarding.getStarted".localized
                         : "common.next".localized)
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, AppConstants.UI.screenPadding)
            }
            .padding(.bottom, 40)
        }
    }
}

#Preview {
    OnboardingContainerView(viewModel: OnboardingViewModel())
}
