import MapKit
import UIKit

/// A compact, colour-neutral navigation pointer that stays legible over every territory colour.
final class RunDomUserLocationAnnotationView: MKAnnotationView {
    static let reuseIdentifier = "RunDomUserLocation"

    private let directionLayer = CAShapeLayer()

    private static let surfaceColor = UIColor(
        red: 98 / 255,
        green: 184 / 255,
        blue: 245 / 255,
        alpha: 1
    )
    private static let inkColor = UIColor(
        red: 23 / 255,
        green: 74 / 255,
        blue: 107 / 255,
        alpha: 1
    )

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(x: 0, y: 0, width: 36, height: 36)
        centerOffset = .zero
        canShowCallout = false
        isEnabled = false
        collisionMode = .none
        displayPriority = .required
        layer.masksToBounds = false
        configureLayers()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(
        userLocation: MKUserLocation?,
        preferredCourse: CLLocationDirection? = nil,
        mapHeading: CLLocationDirection = 0
    ) {
        let location = userLocation?.location
        let course = location.flatMap { value -> CLLocationDirection? in
            guard value.speed >= 0.7, value.course >= 0 else { return nil }
            return value.course
        }
        let heading = userLocation?.heading.flatMap { value -> CLLocationDirection? in
            let direction = value.trueHeading >= 0 ? value.trueHeading : value.magneticHeading
            return direction >= 0 ? direction : nil
        }
        let worldDirection = preferredCourse ?? course ?? heading
        let screenDirection = worldDirection.map {
            Self.normalizedDirection($0 - mapHeading)
        }
        updateDirection(screenDirection)
    }

    private func configureLayers() {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        directionLayer.frame = bounds

        let pointer = UIBezierPath()
        pointer.move(to: CGPoint(x: center.x, y: center.y - 12))
        pointer.addLine(to: CGPoint(x: center.x + 8.2, y: center.y + 10.5))
        pointer.addLine(to: CGPoint(x: center.x, y: center.y + 6.2))
        pointer.addLine(to: CGPoint(x: center.x - 8.2, y: center.y + 10.5))
        pointer.close()
        directionLayer.path = pointer.cgPath
        directionLayer.fillColor = Self.surfaceColor.cgColor
        directionLayer.strokeColor = Self.inkColor.withAlphaComponent(0.96).cgColor
        directionLayer.lineWidth = 1.8
        directionLayer.lineJoin = .round
        directionLayer.shadowColor = UIColor.black.cgColor
        directionLayer.shadowOpacity = 0.30
        directionLayer.shadowRadius = 3
        directionLayer.shadowOffset = CGSize(width: 0, height: 1.5)
        directionLayer.shadowPath = pointer.cgPath
        layer.addSublayer(directionLayer)
    }

    private func updateDirection(_ heading: CLLocationDirection?) {
        let heading = heading.flatMap { $0.isFinite ? $0 : nil } ?? 0
        directionLayer.setAffineTransform(
            CGAffineTransform(rotationAngle: CGFloat(heading * .pi / 180))
        )
    }

    private static func normalizedDirection(_ direction: CLLocationDirection) -> CLLocationDirection {
        (direction.truncatingRemainder(dividingBy: 360) + 360)
            .truncatingRemainder(dividingBy: 360)
    }
}
