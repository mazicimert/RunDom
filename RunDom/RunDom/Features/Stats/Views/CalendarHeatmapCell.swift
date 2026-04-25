import SwiftUI

struct CalendarHeatmapCell: View {
    let day: HeatmapDay?
    let baseColor: Color
    let size: CGFloat
    let accessibilityText: String
    let onTap: (HeatmapDay) -> Void

    var body: some View {
        Group {
            if let day {
                Button {
                    Haptics.selection()
                    onTap(day)
                } label: {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(fillColor(for: day))
                        .frame(width: size, height: size)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(
                                    Color.primary.opacity(0.6),
                                    style: StrokeStyle(lineWidth: 1.5, dash: [3, 2])
                                )
                                .opacity(day.isToday ? 1 : 0)
                        )
                        .overlay(alignment: .bottomTrailing) {
                            if day.isInStreak {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.orange)
                                    .offset(x: 1, y: 1)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityText)
            } else {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.clear)
                    .frame(width: size, height: size)
                    .accessibilityHidden(true)
            }
        }
    }

    private func fillColor(for day: HeatmapDay) -> Color {
        switch day.intensityLevel {
        case 1:
            return baseColor.opacity(0.25)
        case 2:
            return baseColor.opacity(0.5)
        case 3:
            return baseColor.opacity(0.75)
        case 4:
            return baseColor
        default:
            return Color(uiColor: .tertiarySystemFill)
        }
    }
}
