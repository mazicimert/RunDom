import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var displayName: String = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var selectedColor: String = "#4ECDC4"
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let storageService = StorageService()
    private let colorColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)

    var body: some View {
        NavigationStack {
            Form {
                // Photo Section
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            if let selectedImage {
                                Image(uiImage: selectedImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color(hex: selectedColor) ?? .accentColor, lineWidth: 3)
                                    )
                            } else {
                                AvatarView(
                                    photoURL: appState.currentUser?.photoURL,
                                    userColor: selectedColor,
                                    size: 100
                                )
                            }

                            PhotosPicker(
                                selection: $selectedPhoto,
                                matching: .images,
                                photoLibrary: .shared()
                            ) {
                                Text("profile.changePhoto".localized)
                                    .font(.subheadline)
                            }
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                // Color Section
                Section("profile.selectColor".localized) {
                    LazyVGrid(columns: colorColumns, spacing: 12) {
                        ForEach(AppConstants.UserColors.all, id: \.self) { hex in
                            let isSelected = hex == selectedColor
                            Circle()
                                .fill(Color(hex: hex) ?? .gray)
                                .frame(width: 44, height: 44)
                                .overlay {
                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(.white)
                                            .shadow(color: .black.opacity(0.3), radius: 2)
                                    }
                                }
                                .overlay(
                                    Circle()
                                        .stroke(.white.opacity(isSelected ? 1 : 0), lineWidth: 3)
                                )
                                .scaleEffect(isSelected ? 1.1 : 1.0)
                                .animation(.easeInOut(duration: 0.2), value: selectedColor)
                                .onTapGesture {
                                    Haptics.impact(.light)
                                    selectedColor = hex
                                }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Name Section
                Section("profile.displayName".localized) {
                    TextField("runner.defaultName".localized, text: $displayName)
                        .textContentType(.name)
                        .autocorrectionDisabled()
                }

                // Email (read-only)
                if let email = appState.currentUser?.email, !email.isEmpty {
                    Section("profile.email".localized) {
                        Text(email)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("profile.editProfile".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.save".localized) {
                        Task { await saveProfile() }
                    }
                    .bold()
                    .disabled(isSaving || displayName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .overlay {
                if isSaving {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView()
                        .tint(.white)
                }
            }
            .onChange(of: selectedPhoto) { _, newValue in
                Task { await loadPhoto(from: newValue) }
            }
            .onAppear {
                displayName = appState.currentUser?.displayName ?? ""
                selectedColor = appState.currentUser?.color ?? "#4ECDC4"
            }
            .alert("common.error".localized, isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("common.ok".localized, role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Actions

    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        selectedImage = image
    }

    private func saveProfile() async {
        guard var user = appState.currentUser else { return }
        isSaving = true

        do {
            // Upload photo if changed
            if let selectedImage {
                let url = try await storageService.uploadProfilePhoto(userId: user.id, image: selectedImage)
                user.photoURL = url
            }

            // Update name and color
            user.displayName = displayName.trimmingCharacters(in: .whitespaces)
            user.color = selectedColor

            try await appState.firestoreService.updateUser(user)
            appState.currentUser = user
            Haptics.notification(.success)
            dismiss()
        } catch {
            AppLogger.firebase.error("Failed to save profile: \(error.localizedDescription)")
            errorMessage = "error.generic".localized
        }

        isSaving = false
    }
}

#Preview {
    EditProfileView()
        .environmentObject(AppState())
}
