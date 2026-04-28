import SwiftUI
import MapKit

struct RunHistoryDetailView: View {
    @EnvironmentObject private var appState: AppState
    let run: RunSession
    @State private var isGalleryPresented = false
    @State private var showReviewSheet = false
    @State private var reviewBinding: RunReview?
    @State private var rating: Int?
    @State private var tags: [String]
    @State private var note: String?

    private let presetTagKeys: Set<String> = [
        "tag.morning", "tag.evening", "tag.rainy", "tag.hot", "tag.tempo", "tag.long", "tag.race"
    ]
    private let firestoreService = FirestoreService()

    init(run: RunSession) {
        self.run = run
        _rating = State(initialValue: run.rating)
        _tags = State(initialValue: run.tags)
        _note = State(initialValue: run.note)
    }

    private var hasReview: Bool {
        rating != nil || !tags.isEmpty || !(note?.isEmpty ?? true)
    }

    /// Reconstructs the multiplier breakdown for an already-saved run so the AI launcher
    /// has something to show. Streak / dropzone / daily-cap context is not persisted, so
    /// we treat them as unknown and derive only from RunSession fields.
    private var derivedTrailResult: TrailCalculator.TrailResult {
        let calculator = TrailCalculator()
        let distanceKm = run.distance / 1000.0
        let durationMinutes = run.duration / 60.0
        let base = calculator.basePoints(distanceKm: distanceKm)
        let speed = calculator.speedMultiplier(avgSpeedKmh: run.avgSpeed)
        let duration = calculator.durationMultiplier(minutes: durationMinutes)
        let zone = calculator.zoneMultiplier(newZones: run.uniqueZonesVisited)
        let mode = calculator.modeMultiplier(mode: run.mode, isBoostActive: run.isBoostActive)
        let antiFarm = calculator.antiFarmMultiplier(uniqueRatio: run.uniqueZoneRatio)

        return TrailCalculator.TrailResult(
            totalTrail: run.trail,
            basePoints: base,
            speedMultiplier: speed,
            durationMultiplier: duration,
            zoneMultiplier: zone,
            streakMultiplier: 1.0,
            modeMultiplier: mode,
            antiFarmMultiplier: antiFarm,
            dropzoneMultiplier: 1.0,
            wasCapped: run.trail >= AppConstants.Game.maxTrailPerRun,
            wasDailyCapped: false
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Route Map
                if !run.route.isEmpty {
                    routeMap
                }

                // Mode Badge
                HStack {
                    Label(
                        run.mode == .boost ? "run.boostMode".localized : "run.normalMode".localized,
                        systemImage: run.mode == .boost ? "bolt.fill" : "figure.run"
                    )
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(run.mode == .boost ? Color.orange.opacity(0.15) : Color.blue.opacity(0.15))
                    .foregroundStyle(run.mode == .boost ? .orange : .blue)
                    .clipShape(Capsule())

                    Spacer()

                    Text(run.startDate.formattedDateTime())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .screenPadding()

                // Stats Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatCardView(
                        icon: "point.topleft.down.to.point.bottomright.curvepath.fill",
                        value: run.distance.formattedDistanceFromMeters,
                        label: "run.distance".localized,
                        iconColor: .green
                    )
                    StatCardView(
                        icon: "clock.fill",
                        value: run.duration.formattedDuration,
                        label: "run.duration".localized,
                        iconColor: .blue
                    )
                    StatCardView(
                        icon: "speedometer",
                        value: run.avgSpeed.formattedSpeed,
                        label: "run.avgSpeed".localized,
                        iconColor: .purple
                    )
                    StatCardView(
                        icon: "flame.fill",
                        value: run.trail.formattedTrail,
                        label: "run.trailEarned".localized,
                        iconColor: .orange
                    )
                }
                .screenPadding()

                // Territories
                HStack(spacing: 12) {
                    Image(systemName: "hexagon.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(run.territoriesCaptured)")
                            .font(.headline)
                        Text("run.territoriesCaptured".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(run.uniqueZonesVisited)")
                            .font(.headline)
                        Text("stats.uniqueZones".localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .cardStyle()
                .screenPadding()

                reviewSection
                    .screenPadding()

                AIRunAnalysisLauncher(
                    session: run,
                    trailResult: derivedTrailResult,
                    neighborhood: appState.currentUser?.neighborhood
                )
                .screenPadding()
            }
            .padding(.vertical)
        }
        .navigationTitle("run.summary".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: openGallery) {
                    Image(systemName: "photo.on.rectangle.angled")
                }
                .accessibilityLabel("run.gallery".localized)
            }
        }
        .fullScreenCover(isPresented: $isGalleryPresented) {
            RunGalleryView(session: run)
        }
        .sheet(isPresented: $showReviewSheet) {
            RunReviewSheet(review: $reviewBinding) { review in
                applyReview(review)
            }
        }
    }

    // MARK: - Review Section

    @ViewBuilder
    private var reviewSection: some View {
        if hasReview {
            VStack(alignment: .leading, spacing: 12) {
                if let rating {
                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: rating >= star ? "star.fill" : "star")
                                .foregroundStyle(rating >= star ? Color.yellow : Color.secondary.opacity(0.4))
                                .font(.subheadline)
                        }
                    }
                }

                if !tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(tags, id: \.self) { tag in
                                Text(displayText(for: tag))
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(Color.secondary.opacity(0.15))
                                    )
                            }
                        }
                    }
                }

                if let note, !note.isEmpty {
                    Text(note)
                        .font(.caption.italic())
                        .foregroundStyle(.secondary)
                }

                Button {
                    reviewBinding = currentReview
                    showReviewSheet = true
                } label: {
                    Label("run.review.edit".localized, systemImage: "pencil")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
        } else {
            Button {
                reviewBinding = currentReview
                showReviewSheet = true
            } label: {
                Label("run.review.button".localized, systemImage: "star")
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }

    private var currentReview: RunReview {
        RunReview(rating: rating, tags: tags, note: note)
    }

    private func displayText(for tag: String) -> String {
        presetTagKeys.contains(tag) ? tag.localized : tag
    }

    private func applyReview(_ review: RunReview) {
        rating = review.rating
        tags = review.tags
        note = review.note

        let runId = run.id
        Task {
            do {
                try await firestoreService.updateRunReview(runId: runId, review: review)
            } catch {
                AppLogger.firebase.warning("Failed to update run review: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Route Map

    private var routeMap: some View {
        Map {
            if run.route.count >= 2 {
                MapPolyline(coordinates: run.route.map { $0.coordinate })
                    .stroke(.blue, lineWidth: 4)
            }

            if let first = run.route.first {
                Annotation("run.startPoint".localized, coordinate: first.coordinate) {
                    Circle()
                        .fill(.green)
                        .frame(width: 12, height: 12)
                }
            }

            if let last = run.route.last {
                Annotation("run.endPoint".localized, coordinate: last.coordinate) {
                    Circle()
                        .fill(.red)
                        .frame(width: 12, height: 12)
                }
            }
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius, style: .continuous))
        .screenPadding()
        .allowsHitTesting(false)
    }

    private func openGallery() {
        isGalleryPresented = true
    }
}

#Preview {
    NavigationStack {
        RunHistoryDetailView(run: RunSession(
            id: "1", userId: "u1", mode: .boost,
            startDate: Date().addingTimeInterval(-1800),
            endDate: Date(),
            distance: 5240, avgSpeed: 10.5, trail: 850,
            territoriesCaptured: 12, uniqueZonesVisited: 10, totalZonesVisited: 14
        ))
        .environmentObject(AppState())
    }
}
