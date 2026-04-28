import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var localizationManager: LocalizationManager
    @EnvironmentObject private var unitPreference: UnitPreference
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: SettingsViewModel

    init(authService: AuthService) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(authService: authService))
    }

    var body: some View {
        NavigationStack {
            List {
                // Notifications
                Section {
                    HStack {
                        Label("settings.notifications".localized, systemImage: "bell.fill")
                        Spacer()
                        if viewModel.notificationsEnabled {
                            Text("settings.enabled".localized)
                                .foregroundStyle(.green)
                                .font(.subheadline)
                        } else {
                            Button("settings.enable".localized) {
                                viewModel.openNotificationSettings()
                            }
                            .font(.subheadline)
                        }
                    }
                }

                Section("settings.language".localized) {
                    Picker(
                        "settings.language".localized,
                        selection: $localizationManager.selectedLanguageCode
                    ) {
                        Text("settings.language.turkish".localized)
                            .tag(AppLanguage.turkish.rawValue)
                        Text("settings.language.english".localized)
                            .tag(AppLanguage.english.rawValue)
                    }
                    .pickerStyle(.segmented)
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

#Preview {
    SettingsView(authService: AuthService())
        .environmentObject(AppState())
        .environmentObject(LocalizationManager.shared)
        .environmentObject(UnitPreference.shared)
}
