import SwiftUI
import MapKit

/// Map annotation view for active dropzones.
struct DropzoneAnnotationView: View {
    let dropzone: Dropzone

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(.yellow.gradient)
                    .frame(width: 44, height: 44)
                    .shadow(color: .yellow.opacity(0.5), radius: 8)

                Image(systemName: dropzone.isActive ? "bolt.fill" : "bolt")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
            }
            .overlay {
                if dropzone.isActive {
                    Circle()
                        .stroke(.yellow, lineWidth: 2)
                        .frame(width: 52, height: 52)
                        .opacity(0.6)
                }
            }

            if dropzone.isActive {
                Text("dropzone.active".localized)
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.yellow.gradient, in: Capsule())
            }
        }
    }
}

// MARK: - Dropzone Map Annotation

/// Wraps a Dropzone as an MKAnnotation for MapKit.
final class DropzoneAnnotation: NSObject, MKAnnotation, Identifiable {
    let id: String
    let dropzone: Dropzone

    var coordinate: CLLocationCoordinate2D {
        dropzone.coordinate
    }

    var title: String? {
        dropzone.isActive ? "dropzone.active".localized : nil
    }

    init(dropzone: Dropzone) {
        self.id = dropzone.id
        self.dropzone = dropzone
    }
}
