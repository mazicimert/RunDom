import SwiftUI

struct AIDisclosureView: View {

    let onContinue: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "sparkle")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                    Text("ai.disclosure.title".localized)
                        .font(.title3.weight(.bold))
                }

                Text("ai.disclosure.body".localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 10) {
                disclosureBullet(
                    icon: "checkmark.shield.fill",
                    text: "ai.disclosure.point.anonymized".localized,
                    tint: .green
                )
                disclosureBullet(
                    icon: "xmark.shield.fill",
                    text: "ai.disclosure.point.noPII".localized,
                    tint: .red
                )
                disclosureBullet(
                    icon: "gearshape.fill",
                    text: "ai.disclosure.point.toggle".localized,
                    tint: .blue
                )
            }

            Spacer(minLength: 0)

            VStack(spacing: 10) {
                Button(action: onContinue) {
                    Text("ai.disclosure.continue".localized)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())

                Button(action: onCancel) {
                    Text("common.cancel".localized)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(24)
    }

    private func disclosureBullet(icon: String, text: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 24, alignment: .center)
                .padding(.top, 2)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }
}
