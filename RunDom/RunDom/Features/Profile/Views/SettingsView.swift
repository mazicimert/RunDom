import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var localizationManager: LocalizationManager
    @EnvironmentObject private var unitPreference: UnitPreference
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel: SettingsViewModel

    init(authService: AuthService, locationManager: LocationManager) {
        _viewModel = StateObject(
            wrappedValue: SettingsViewModel(
                authService: authService,
                locationManager: locationManager
            )
        )
    }

    var body: some View {
        NavigationStack {
            List {
                // Location
                Section {
                    Toggle(isOn: locationToggleBinding) {
                        Label("settings.location".localized, systemImage: "location.fill")
                    }
                } footer: {
                    if let hint = locationFooterHint {
                        Text(hint)
                    }
                }

                // Notifications
                Section {
                    Toggle(isOn: notificationsToggleBinding) {
                        Label("settings.notifications".localized, systemImage: "bell.fill")
                    }
                } footer: {
                    if viewModel.notificationStatus == .denied {
                        Text("settings.notifications.deniedHint".localized)
                    } else if viewModel.notificationStatus == .authorized
                                || viewModel.notificationStatus == .provisional {
                        Text("settings.notifications.enabledHint".localized)
                    }
                }

                Section("settings.language".localized) {
                    Picker(
                        "settings.language".localized,
                        selection: $localizationManager.selectedLanguageCode
                    ) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayName)
                                .tag(language.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section {
                    Toggle("settings.voiceFeedback".localized, isOn: $viewModel.isVoiceFeedbackEnabled)
                }

                Section {
                    Toggle(isOn: $viewModel.isAIAnalysisEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("settings.aiAnalysis".localized)
                            Text("settings.aiAnalysis.description".localized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    Toggle(isOn: $unitPreference.useMiles) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("settings.unit".localized)
                            Text(
                                unitPreference.useMiles
                                    ? "settings.unit.miles".localized
                                    : "settings.unit.km".localized
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }

                // Account
                Section("settings.account".localized) {
                    Button(role: .destructive) {
                        viewModel.showSignOutAlert = true
                    } label: {
                        Label("auth.signOut".localized, systemImage: "rectangle.portrait.and.arrow.right")
                    }

                    Button(role: .destructive) {
                        viewModel.showDeleteAccountAlert = true
                    } label: {
                        Label("settings.deleteAccount".localized, systemImage: "trash")
                    }
                }

                // About
                Section("settings.about".localized) {
                    HStack {
                        Text("settings.version".localized)
                        Spacer()
                        Text(viewModel.appVersion)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("settings.testing".localized) {
                    Button(role: .destructive) {
                        appState.resetOnboardingForTesting()
                        dismiss()
                    } label: {
                        Label("settings.restartOnboarding".localized, systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .navigationTitle("settings.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                }
            }
            .task {
                await viewModel.checkNotificationStatus()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await viewModel.checkNotificationStatus() }
                }
            }
            .alert("auth.signOut".localized, isPresented: $viewModel.showSignOutAlert) {
                Button("auth.signOut".localized, role: .destructive) {
                    appState.signOut()
                    dismiss()
                }
                Button("common.cancel".localized, role: .cancel) {}
            } message: {
                Text("auth.signOutConfirm".localized)
            }
            .alert("settings.deleteAccount".localized, isPresented: $viewModel.showDeleteAccountAlert) {
                Button("common.delete".localized, role: .destructive) {
                    Task {
                        let success = await viewModel.deleteAccount()
                        if success {
                            dismiss()
                        }
                    }
                }
                Button("common.cancel".localized, role: .cancel) {}
            } message: {
                Text("settings.deleteAccountConfirm".localized)
            }
            .alert(
                "common.error".localized,
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { isPresented in
                        if !isPresented {
                            viewModel.dismissError()
                        }
                    }
                )
            ) {
                Button("common.ok".localized, role: .cancel) {
                    viewModel.dismissError()
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .overlay {
                if viewModel.isDeleting {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView()
                        .tint(.white)
                }
            }
        }
    }
}

private extension SettingsView {
    /// Toggle that doesn't update local state directly — taps trigger either a
    /// system prompt (notDetermined) or open iOS Settings (denied/authorized).
    /// The actual toggle visual updates via `checkNotificationStatus()` once
    /// the user returns from Settings (scenePhase active).
    var notificationsToggleBinding: Binding<Bool> {
        Binding(
            get: { viewModel.notificationsEnabled },
            set: { _ in
                Task { await viewModel.handleNotificationToggleTap() }
            }
        )
    }

    /// Same pattern for location: tap triggers system request (.notDetermined)
    /// or deep-links to iOS Settings (denied / restricted / partial / always).
    /// Visual stays in sync via the LocationManager publisher subscription
    /// in SettingsViewModel.
    var locationToggleBinding: Binding<Bool> {
        Binding(
            get: { viewModel.locationEnabled },
            set: { _ in
                viewModel.handleLocationToggleTap()
            }
        )
    }

    var locationFooterHint: String? {
        switch viewModel.locationAuthStatus {
        case .notDetermined:
            return nil
        case .denied, .restricted:
            return "settings.location.deniedHint".localized
        case .authorizedWhenInUse:
            return "settings.location.whenInUseHint".localized
        case .authorizedAlways:
            return "settings.location.alwaysHint".localized
        @unknown default:
            return nil
        }
    }
}

#Preview {
    SettingsView(authService: AuthService(), locationManager: LocationManager())
        .environmentObject(AppState())
        .environmentObject(LocalizationManager.shared)
        .environmentObject(UnitPreference.shared)
}
