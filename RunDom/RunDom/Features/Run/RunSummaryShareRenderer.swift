import SwiftUI
import UIKit

@MainActor
enum RunSummaryShareRenderer {
    static func makeImage(for session: RunSession) -> UIImage? {
        let viewModel = PostRunViewModel(session: session)
        let canvasSize = shareCanvasSize

        let shareCard = PostRunShareCardView(
            session: session,
            trailText: viewModel.trailText,
            modeText: viewModel.modeBadgeText,
            performanceText: viewModel.shareHeadlineText,
            subtitleText: viewModel.shareSubtitleText,
            avgSpeedText: viewModel.avgSpeedText,
            brandText: viewModel.shareBrandText,
            dateText: viewModel.shareDateText,
            canvasSize: canvasSize
        )
        .frame(width: canvasSize.width, height: canvasSize.height)
        .environment(\.colorScheme, .dark)

        let renderer = ImageRenderer(content: shareCard)
        renderer.proposedSize = ProposedViewSize(canvasSize)
        renderer.scale = max(UIScreen.main.scale, 1)
        return renderer.uiImage
    }

    private static var shareCanvasSize: CGSize {
        let bounds = UIScreen.main.bounds
        let smallerSide = min(bounds.width, bounds.height)
        let largerSide = max(bounds.width, bounds.height)

        guard smallerSide > 0, largerSide > 0 else {
            return CGSize(width: 390, height: 844)
        }

        return CGSize(width: smallerSide, height: largerSide)
    }
}
