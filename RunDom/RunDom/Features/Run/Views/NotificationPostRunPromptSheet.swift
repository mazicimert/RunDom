import SwiftUI
import UserNotifications

struct NotificationPostRunPromptSheet: View {
    let userColorHex: String?
    let onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var accent: Color {
        guard let hex = userColorHex, let color = Color(hex: hex) else {
            return .accentColor
        }
        return color
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 8)

            heroIcon

            VStack(spacing: 10) {
                Text("postRun.notificationPrompt.title".localized)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)

                Text("postRun.notificationPrompt.subtitle".localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 10) {
                Button {
                    Task { await allowTapped() }
                } label: {
                    Text("postRun.notificationPrompt.allow".localized)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())

                Button {
                    skipTapped()
                } label: {
                    Text("postRun.notificationPrompt.skip".localized)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .padding(.top, 24)
        .onAppear {
            AnalyticsService.logPostRunNotificationPromptShown()
        }
    }

    private var heroIcon: some View {
        ZStack {
            Circle()
                .fill(accent.opacity(0.15))
                .frame(width: 96, height: 96)

            Circle()
                .stroke(accent.opacity(0.35), lineWidth: 1.5)
                .frame(width: 110, height: 110)

            Image(systemName: "bell.badge.fill")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(accent)
        }
    }

    private func allowTapped() async {
        AnalyticsService.logPostRunNotificationPromptAllowTapped()
        Haptics.impact(.medium)

        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        UserDefaults.standard.set(true, forKey: AppConstants.UserDefaultsKeys.hasRequestedNotificationPermission)

        AnalyticsService.logPostRunNotificationPromptResult(granted: granted)

        await MainActor.run {
            onComplete()
            dismiss()
        }
    }

    private func skipTapped() {
        AnalyticsService.logPostRunNotificationPromptSkipped()
        UserDefaults.standard.set(true, forKey: AppConstants.UserDefaultsKeys.hasRequestedNotificationPermission)
        onComplete()
        dismiss()
    }
}

#Preview {
    Color.gray
        .sheet(isPresented: .constant(true)) {
            NotificationPostRunPromptSheet(
                userColorHex: "#4ECDC4",
                onComplete: {}
            )
            .presentationDetents([.medium])
        }
}
