import SwiftUI

struct LoadingView: View {
    var message: String? = nil

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)

            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    LoadingView(message: "common.loading".localized)
}
