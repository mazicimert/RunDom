import SwiftUI

struct RunReview: Equatable {
    var rating: Int?
    var tags: [String]
    var note: String?

    static let empty = RunReview(rating: nil, tags: [], note: nil)

    var hasContent: Bool {
        rating != nil || !tags.isEmpty || !(note?.isEmpty ?? true)
    }
}

struct RunReviewSheet: View {
    private static let initialDetent: PresentationDetent = .fraction(0.7)

    @Binding var review: RunReview?
    let onSave: (RunReview) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var rating: Int?
    @State private var selectedTags: Set<String> = []
    @State private var customTags: [String] = []
    @State private var noteText: String = ""
    @State private var isAddingCustomTag = false
    @State private var customTagDraft: String = ""

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case note
        case customTag
    }

    private let presetTagKeys: [String] = [
        "tag.morning",
        "tag.evening",
        "tag.rainy",
        "tag.hot",
        "tag.tempo",
        "tag.long",
        "tag.race"
    ]

    init(review: Binding<RunReview?>, onSave: @escaping (RunReview) -> Void) {
        self._review = review
        self.onSave = onSave

        let current = review.wrappedValue ?? .empty
        _rating = State(initialValue: current.rating)
        _selectedTags = State(initialValue: Set(current.tags))
        _customTags = State(initialValue: current.tags.filter { tag in
            !["tag.morning", "tag.evening", "tag.rainy", "tag.hot", "tag.tempo", "tag.long", "tag.race"].contains(tag)
        })
        _noteText = State(initialValue: current.note ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    ratingSection
                    tagsSection
                    noteSection
                    saveButton
                }
                .padding(AppConstants.UI.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .navigationTitle("run.review.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.done".localized) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([Self.initialDetent, .large])
        .presentationDragIndicator(.visible)
    }

    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("run.review.rate".localized)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        Haptics.selection()
                        if rating == star {
                            rating = nil
                        } else {
                            rating = star
                        }
                    } label: {
                        Image(systemName: (rating ?? 0) >= star ? "star.fill" : "star")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle((rating ?? 0) >= star ? Color.yellow : Color.secondary.opacity(0.5))
                            .symbolEffect(.bounce, value: rating)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(star)")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("run.review.tags".localized)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(presetTagKeys, id: \.self) { key in
                        tagChip(
                            title: key.localized,
                            isSelected: selectedTags.contains(key)
                        ) {
                            toggleTag(key)
                        }
                    }

                    ForEach(customTags, id: \.self) { tag in
                        tagChip(
                            title: tag,
                            isSelected: selectedTags.contains(tag)
                        ) {
                            toggleTag(tag)
                        }
                    }

                    if isAddingCustomTag {
                        HStack(spacing: 6) {
                            TextField("", text: $customTagDraft)
                                .textFieldStyle(.plain)
                                .focused($focusedField, equals: .customTag)
                                .submitLabel(.done)
                                .onSubmit(commitCustomTag)
                                .frame(minWidth: 80)

                            Button {
                                commitCustomTag()
                            } label: {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.body)
                            }
                            .buttonStyle(.plain)
                            .disabled(customTagDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.accentColor.opacity(0.12))
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.accentColor, lineWidth: 1)
                        )
                    } else {
                        Button {
                            isAddingCustomTag = true
                            focusedField = .customTag
                        } label: {
                            Text("tag.addCustom".localized)
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .stroke(Color.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4]))
                                )
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("run.review.note".localized)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField("run.review.note".localized, text: $noteText)
                .textFieldStyle(.plain)
                .focused($focusedField, equals: .note)
                .submitLabel(.done)
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius, style: .continuous)
                        .fill(Color.secondary.opacity(0.1))
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    private var saveButton: some View {
        Button {
            commitAndSave()
        } label: {
            Text("run.review.save".localized)
        }
        .buttonStyle(PrimaryButtonStyle())
    }

    private func tagChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.12))
                )
                .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }

    private func toggleTag(_ key: String) {
        Haptics.selection()
        if selectedTags.contains(key) {
            selectedTags.remove(key)
        } else {
            selectedTags.insert(key)
        }
    }

    private func commitCustomTag() {
        let trimmed = customTagDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            isAddingCustomTag = false
            customTagDraft = ""
            return
        }

        if !customTags.contains(trimmed) && !presetTagKeys.contains(trimmed) {
            customTags.append(trimmed)
        }
        selectedTags.insert(trimmed)
        customTagDraft = ""
        isAddingCustomTag = false
        focusedField = nil
    }

    private func commitAndSave() {
        let trimmedNote = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        let orderedTags = orderedSelectedTags()
        let updated = RunReview(
            rating: rating,
            tags: orderedTags,
            note: trimmedNote.isEmpty ? nil : trimmedNote
        )
        review = updated
        onSave(updated)
        dismiss()
    }

    private func orderedSelectedTags() -> [String] {
        var result: [String] = []
        for key in presetTagKeys where selectedTags.contains(key) {
            result.append(key)
        }
        for tag in customTags where selectedTags.contains(tag) {
            result.append(tag)
        }
        return result
    }
}

#Preview {
    StatefulPreviewWrapper(RunReview?.none) { binding in
        Color.clear
            .sheet(isPresented: .constant(true)) {
                RunReviewSheet(review: binding) { _ in }
            }
    }
}

private struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State var value: Value
    let content: (Binding<Value>) -> Content

    init(_ initial: Value, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
        self._value = State(initialValue: initial)
        self.content = content
    }

    var body: some View {
        content($value)
    }
}
