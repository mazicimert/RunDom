import SwiftUI

/// A compact row representation of one of the current user's posts. Shared by
/// the profile preview and the full "My Posts" list so the two stay in sync.
struct ProfilePostRowView: View {
    let post: Post

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill((Color(hex: post.authorColor) ?? Color.accentColor).opacity(0.18))
                    .frame(width: 42, height: 42)
                Image(systemName: "figure.run")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(hex: post.authorColor) ?? .accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(post.distance.formattedDistanceFromMeters)
                        .font(.subheadline.weight(.semibold))
                    Text("•")
                        .foregroundStyle(.secondary)
                    Text("trail.points".localized(with: post.trail.formattedTrail))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                if let note = post.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            Text(post.createdAt.relativeFormatted())
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .cardStyle()
        .contentShape(Rectangle())
    }
}
