import CoreLocation
import SwiftUI
import UIKit

/// Persistent nudge shown on the Map tab when location permission is missing
/// (notDetermined / denied / restricted). Hidden once the user grants any
/// authorization (whenInUse or always) — upgrade-to-always is handled
/// elsewhere (e.g. pre-run flow).
struct LocationPermissionBanner: View {
    @ObservedObject var locationManager: LocationManager

    @State private var didLogShown = false

    var body: some View {
        Group {
            if needsPrompt {
                bannerContent
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        if !didLogShown {
                            AnalyticsService.logMapLocationBannerShown(
                                status: Self.statusName(locationManager.authorizationStatus)
                            )
                            didLogShown = true
                        }
                    }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: needsPrompt)
    }

    private var needsPrompt: Bool {
        switch locationManager.authorizationStatus {
        case .notDetermined, .denied, .restricted:
            return true
        case .authorizedAlways, .authorizedWhenInUse:
            return false
        @unknown default:
            return false
        }
    }

    private var bannerContent: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.18))
                    .frame(width: 36, height: 36)

                Image(systemName: "location.slash.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("map.banner.locationOff.title".localized)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("map.banner.locationOff.subtitle".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button {
                handleAction()
            } label: {
                Text("map.banner.locationOff.action".localized)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.accentColor))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius, style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius, style: .continuous)
                .stroke(Color.accentColor.opacity(0.25), lineWidth: 1)
        )
    }

    private func handleAction() {
        Haptics.impact(.light)
        AnalyticsService.logMapLocationBannerTapped(
            status: Self.statusName(locationManager.authorizationStatus)
        )

        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestAlwaysAuthorization()
        case .denied, .restricted:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        default:
            break
        }
    }

    private static func statusName(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "notDetermined"
        case .denied: return "denied"
        case .restricted: return "restricted"
        case .authorizedAlways: return "authorizedAlways"
        case .authorizedWhenInUse: return "authorizedWhenInUse"
        @unknown default: return "unknown"
        }
    }
}

#Preview {
    VStack {
        LocationPermissionBanner(locationManager: LocationManager())
            .padding()
        Spacer()
    }
    .background(Color.gray.opacity(0.1))
}
