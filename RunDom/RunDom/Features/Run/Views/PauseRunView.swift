import SwiftUI

struct PauseRunView: View {
    let elapsedTime: String
    let distance: Double // km
    let onResume: () -> Void
    let onStop: () -> Void

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Pause icon
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.white)

                Text("run.paused".localized)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                // Current stats
                HStack(spacing: 32) {
                    VStack(spacing: 4) {
                        Text(String(format: "%.2f", distance))
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                        Text("km")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    VStack(spacing: 4) {
                        Text(elapsedTime)
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                        Text("run.time".localized)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }

                Spacer()

                // Action buttons
                VStack(spacing: 16) {
                    Button {
                        onResume()
                    } label: {
                        Label("run.resume".localized, systemImage: "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius))
                    }

                    Button {
                        onStop()
                    } label: {
                        Label("run.stop".localized, systemImage: "stop.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.8))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius))
                    }
                }
                .padding(.horizontal, AppConstants.UI.screenPadding)
                .padding(.bottom, 40)
            }
        }
    }
}
