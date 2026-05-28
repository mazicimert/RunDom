import SwiftUI

struct BlockedUsersView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = BlockedUsersViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.blocked.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.blocked.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(viewModel.blocked) { relationship in
                        row(relationship)
                            .listRowBackground(Color.cardBackground)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(Color.surfacePrimary.ignoresSafeArea())
            }
        }
        .navigationTitle("settings.blockedUsers".localized)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.surfacePrimary.ignoresSafeArea())
        .task {
            guard let userId = appState.currentUser?.id else { return }
            await viewModel.load(currentUserId: userId)
        }
        .refreshable {
            guard let userId = appState.currentUser?.id else { return }
            await viewModel.load(currentUserId: userId)
        }
    }

    private func row(_ relationship: BlockRelationship) -> some View {
        HStack(spacing: 12) {
            AvatarView(
                photoURL: relationship.photoURL,
                userColor: relationship.color ?? "#4ECDC4",
                size: 44
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(relationship.displayName)
                    .font(.subheadline.weight(.semibold))
                Text(relationship.createdAt.relativeFormatted())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button {
                guard let userId = appState.currentUser?.id else { return }
                Task { await viewModel.unblock(currentUserId: userId, targetUserId: relationship.userId) }
            } label: {
                if viewModel.processingId == relationship.userId {
                    ProgressView()
                } else {
                    Text("social.unblock.action".localized)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(Color.accentColor.opacity(0.15))
                        )
                        .foregroundStyle(Color.accentColor)
                }
            }
            .buttonStyle(.plain)
            .disabled(viewModel.processingId == relationship.userId)
        }
        .padding(.vertical, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("settings.blockedUsers.empty.title".localized)
                .font(.headline)
            Text("settings.blockedUsers.empty.subtitle".localized)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.surfacePrimary)
    }
}

@MainActor
final class BlockedUsersViewModel: ObservableObject {
    @Published var blocked: [BlockRelationship] = []
    @Published var isLoading = false
    @Published var processingId: String?

    private let blockService = BlockService()

    func load(currentUserId: String) async {
        isLoading = true
        do {
            blocked = try await blockService.getBlocked(of: currentUserId)
        } catch {
            AppLogger.firebase.warning("getBlocked failed: \(error.localizedDescription)")
        }
        isLoading = false
    }

    func unblock(currentUserId: String, targetUserId: String) async {
        processingId = targetUserId
        defer { processingId = nil }
        do {
            try await blockService.unblock(
                currentUserId: currentUserId,
                targetUserId: targetUserId
            )
            blocked.removeAll { $0.userId == targetUserId }
            Haptics.notification(.success)
        } catch {
            AppLogger.firebase.error("Unblock failed: \(error.localizedDescription)")
        }
    }
}
