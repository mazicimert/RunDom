import SwiftUI

/// Lets the user pick one of their past runs and publish it to the feed.
/// Reached from the social feed's "+" button — the counterpart to sharing
/// straight from the post-run summary. Uses the same rich `RunSummaryCard` as
/// the run history list so a run is instantly recognisable by its route, and
/// splits runs into "not shared yet" and "shared" so a run is only posted once.
struct SharePastRunPickerView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SharePastRunPickerViewModel()

    /// The run the user tapped, driving the create-post sheet.
    @State private var selectedSession: RunSession?

    var body: some View {
        NavigationStack {
            content
                .background(Color.surfacePrimary.ignoresSafeArea())
                .navigationTitle("social.share.picker.title".localized)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("social.create.cancel".localized) {
                            dismiss()
                        }
                    }
                }
                .task(id: appState.currentUser?.id) {
                    guard let userId = appState.currentUser?.id else { return }
                    await viewModel.loadInitial(userId: userId)
                }
                .sheet(item: $selectedSession) { session in
                    if let user = appState.currentUser {
                        CreatePostSheet(
                            session: session,
                            author: user,
                            onPublished: { post in
                                viewModel.markShared(runId: session.id, postId: post.id)
                                // Drop the picker too so the user lands back on
                                // the feed where their new post appears.
                                dismiss()
                            }
                        )
                    }
                }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if let errorMessage = viewModel.errorMessage, viewModel.runs.isEmpty {
            EmptyStateView(
                icon: "exclamationmark.triangle",
                title: errorMessage,
                subtitle: "social.share.picker.error.subtitle".localized,
                actionTitle: "common.retry".localized,
                action: reload
            )
        } else if viewModel.isLoading && viewModel.runs.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.hasNoShareableRuns && !viewModel.hasMore {
            EmptyStateView(
                icon: "figure.run",
                title: "social.share.picker.empty.title".localized,
                subtitle: "social.share.picker.empty.subtitle".localized
            )
        } else {
            runList
        }
    }

    private var runList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                Text("social.share.picker.prompt".localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !viewModel.unsharedRuns.isEmpty {
                    section(
                        title: "social.share.picker.section.unshared".localized,
                        runs: viewModel.unsharedRuns,
                        isShared: false
                    )
                }

                if !viewModel.sharedRuns.isEmpty {
                    section(
                        title: "social.share.picker.section.shared".localized,
                        runs: viewModel.sharedRuns,
                        isShared: true
                    )
                }

                if viewModel.hasMore {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .onAppear(perform: loadMore)
                }
            }
            .padding(.horizontal, AppConstants.UI.screenPadding)
            .padding(.vertical, 16)
        }
    }

    private func section(title: String, runs: [RunSession], isShared: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ForEach(runs) { run in
                runCard(run, isShared: isShared)
            }
        }
    }

    private func runCard(_ run: RunSession, isShared: Bool) -> some View {
        Button {
            Haptics.selection()
            selectedSession = run
        } label: {
            RunSummaryCard(run: run, isDimmed: isShared) {
                accessory(isShared: isShared)
            }
        }
        .buttonStyle(.plain)
        .disabled(isShared)
    }

    @ViewBuilder
    private func accessory(isShared: Bool) -> some View {
        if isShared {
            Image(systemName: "checkmark.seal.fill")
                .font(.title3)
                .foregroundStyle(.green)
                .padding(.top, 6)
                .accessibilityLabel("social.share.picker.shared".localized)
        } else {
            Image(systemName: "square.and.arrow.up")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Color.accentColor, in: Circle())
                .accessibilityLabel("social.share.history.button".localized)
        }
    }

    // MARK: - Actions

    private func reload() {
        guard let userId = appState.currentUser?.id else { return }
        Task { await viewModel.loadInitial(userId: userId) }
    }

    private func loadMore() {
        guard let userId = appState.currentUser?.id else { return }
        Task { await viewModel.loadMore(userId: userId) }
    }
}
