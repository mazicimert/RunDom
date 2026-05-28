import SwiftUI

struct UserSearchView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = UserSearchViewModel()
    @ObservedObject private var blockedStore = BlockedUsersStore.shared

    private var visibleResults: [User] {
        viewModel.results.filter { !blockedStore.hasBlockRelationship(with: $0.id) }
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("social.search.title".localized)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("common.done".localized) {
                            dismiss()
                        }
                    }
                }
                .background(Color.surfacePrimary.ignoresSafeArea())
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 0) {
            searchField

            if let errorMessage = viewModel.errorMessage {
                ErrorBannerView(
                    message: errorMessage,
                    onDismiss: { viewModel.errorMessage = nil },
                    onRetry: nil
                )
                .padding(.horizontal, AppConstants.UI.screenPadding)
                .padding(.top, 8)
            }

            ScrollView {
                LazyVStack(spacing: 8) {
                    if viewModel.query.isEmpty {
                        hintView
                    } else if viewModel.isSearching && visibleResults.isEmpty {
                        ProgressView()
                            .padding(.top, 40)
                    } else if visibleResults.isEmpty {
                        emptyView
                    } else {
                        ForEach(visibleResults) { user in
                            NavigationLink {
                                UserProfileView(userId: user.id)
                                    .environmentObject(appState)
                            } label: {
                                searchRow(user)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, AppConstants.UI.screenPadding)
                .padding(.vertical, 12)
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("social.search.placeholder".localized, text: $viewModel.query)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: viewModel.query) { _, newValue in
                    viewModel.onQueryChange(newValue)
                }

            if !viewModel.query.isEmpty {
                Button {
                    viewModel.query = ""
                    viewModel.onQueryChange("")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.cardBackground)
        )
        .padding(.horizontal, AppConstants.UI.screenPadding)
        .padding(.top, 12)
    }

    private var hintView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("social.search.hint".localized)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var emptyView: some View {
        Text("social.search.empty".localized)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.top, 40)
    }

    private func searchRow(_ user: User) -> some View {
        HStack(spacing: 12) {
            AvatarView(photoURL: user.photoURL, userColor: user.color, size: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                if let neighborhood = user.neighborhood {
                    Text(neighborhood)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .cardStyle()
    }
}
