import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var localizationManager: LocalizationManager
    @EnvironmentObject private var unitPreference: UnitPreference
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel: SettingsViewModel

    /// The legal/help document currently presented in the in-app browser.
    @State private var activeLegalLink: LegalLink?

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

                // Privacy & Safety
                Section("settings.privacy".localized) {
                    NavigationLink {
                        PrivacyZonesView()
                            .environmentObject(appState)
                    } label: {
                        Label("settings.privacyZones".localized, systemImage: "shield.lefthalf.filled")
                    }

                    NavigationLink {
                        BlockedUsersView()
                            .environmentObject(appState)
                    } label: {
                        Label("settings.blockedUsers".localized, systemImage: "person.crop.circle.badge.xmark")
                    }
                }

                // Legal
                Section("settings.legal".localized) {
                    legalLinkRow(.communityGuidelines)
                    legalLinkRow(.termsOfUse)
                    legalLinkRow(.privacyPolicy)
                }

                // Help
                Section("settings.help".localized) {
                    legalLinkRow(.helpCenter)
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
                    viewModel.startAccountDeletion()
                }
                Button("common.cancel".localized, role: .cancel) {}
            } message: {
                Text("settings.deleteAccountConfirm".localized)
            }
            .sheet(item: $activeLegalLink) { link in
                if let url = link.url(languageCode: localizationManager.selectedLanguageCode) {
                    SafariView(url: url)
                        .ignoresSafeArea()
                }
            }
            .sheet(isPresented: $viewModel.showDeleteReauthSheet) {
                DeleteAccountReauthSheet(
                    authService: viewModel.authServicePublic,
                    onSucceeded: {
                        await viewModel.performDeletionAfterReauth()
                    },
                    onFinished: { success in
                        if success {
                            // AppState observes the auth listener and routes
                            // back to onboarding; just close Settings too.
                            dismiss()
                        }
                    }
                )
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
    /// A row that opens a Notion-hosted legal/help document in the in-app
    /// browser, picking the language-appropriate page.
    @ViewBuilder
    func legalLinkRow(_ link: LegalLink) -> some View {
        Button {
            activeLegalLink = link
        } label: {
            HStack {
                Label(link.titleLocalizationKey.localized, systemImage: link.iconName)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .tint(.primary)
    }

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
