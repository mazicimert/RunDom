import SwiftUI

/// Drop-in card with a "Generate AI Analysis" button. Handles the one-time disclosure
/// flow and presentation of the run-analysis sheet, so callers stay tiny.
struct AIRunAnalysisLauncher: View {
    let session: RunSession
    let trailResult: TrailCalculator.TrailResult?
    let neighborhood: String?

    @State private var showSheet = false
    @State private var showDisclosure = false
    @AppStorage(AppConstants.UserDefaultsKeys.aiAnalysisEnabled)
    private var aiEnabled = true
    @AppStorage(AppConstants.UserDefaultsKeys.aiDisclosureAccepted)
    private var disclosureAccepted = false

    var body: some View {
        if shouldRender {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ai.run.cta.title".localized)
                            .font(.subheadline.weight(.bold))
                        Text("ai.run.cta.subtitle".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                Button(action: didTapGenerate) {
                    Label("ai.run.cta.button".localized, systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(trailResult == nil)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.accentColor.opacity(0.18), lineWidth: 1)
                    )
            )
            .sheet(isPresented: $showSheet) {
                if let trailResult {
                    AIRunAnalysisSheetView(
                        session: session,
                        trailResult: trailResult,
                        neighborhood: neighborhood
                    )
                }
            }
            .sheet(isPresented: $showDisclosure) {
                AIDisclosureView(
                    onContinue: {
                        disclosureAccepted = true
                        showDisclosure = false
                        AnalyticsService.logAIDisclosureAccepted()
                        showSheet = true
                    },
                    onCancel: {
                        showDisclosure = false
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private var shouldRender: Bool {
        guard aiEnabled else { return false }
        guard session.distance >= AIRunAnalysisLimits.minDistanceMeters else { return false }
        guard session.duration >= AIRunAnalysisLimits.minDurationSeconds else { return false }
        return true
    }

    private func didTapGenerate() {
        Haptics.impact(.light)
        if disclosureAccepted {
            showSheet = true
        } else {
            AnalyticsService.logAIDisclosureShown()
            showDisclosure = true
        }
    }
}

struct AIWeeklyAnalysisLauncher: View {
    @State private var showSheet = false
    @State private var showDisclosure = false
    @AppStorage(AppConstants.UserDefaultsKeys.aiAnalysisEnabled)
    private var aiEnabled = true
    @AppStorage(AppConstants.UserDefaultsKeys.aiDisclosureAccepted)
    private var disclosureAccepted = false

    var body: some View {
        if aiEnabled {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ai.weekly.cta.title".localized)
                            .font(.subheadline.weight(.bold))
                        Text("ai.weekly.cta.subtitle".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                Button(action: didTapGenerate) {
                    Label("ai.weekly.cta.button".localized, systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.accentColor.opacity(0.18), lineWidth: 1)
                    )
            )
            .sheet(isPresented: $showSheet) {
                AIWeeklyAnalysisSheetView()
            }
            .sheet(isPresented: $showDisclosure) {
                AIDisclosureView(
                    onContinue: {
                        disclosureAccepted = true
                        showDisclosure = false
                        AnalyticsService.logAIDisclosureAccepted()
                        showSheet = true
                    },
                    onCancel: {
                        showDisclosure = false
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private func didTapGenerate() {
        Haptics.impact(.light)
        if disclosureAccepted {
            showSheet = true
        } else {
            AnalyticsService.logAIDisclosureShown()
            showDisclosure = true
        }
    }
}
