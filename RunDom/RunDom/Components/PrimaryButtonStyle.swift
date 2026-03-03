import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    var isDestructive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.bold())
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius, style: .continuous)
                    .fill(isDestructive ? Color.red : Color.accentColor)
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: AppConstants.Animation.quick), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.bold())
            .foregroundStyle(Color.accentColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius, style: .continuous)
                    .stroke(Color.accentColor, lineWidth: 2)
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: AppConstants.Animation.quick), value: configuration.isPressed)
    }
}

#Preview {
    VStack(spacing: 16) {
        Button("run.start".localized) {}
            .buttonStyle(PrimaryButtonStyle())

        Button("common.cancel".localized) {}
            .buttonStyle(SecondaryButtonStyle())

        Button("common.delete".localized) {}
            .buttonStyle(PrimaryButtonStyle(isDestructive: true))
    }
    .padding()
}
