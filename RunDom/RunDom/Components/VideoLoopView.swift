import SwiftUI
import AVFoundation

/// A lightweight, seamlessly-looping, muted video player for onboarding /
/// marketing surfaces. Autoplays on appear and loops forever via
/// `AVPlayerLooper`. The user is never blocked — there is no completion
/// gating, so they can advance the onboarding at any time.
struct VideoLoopView: UIViewRepresentable {
    let resourceName: String
    let fileExtension: String
    var videoGravity: AVLayerVideoGravity = .resizeAspectFill

    func makeUIView(context: Context) -> LoopingPlayerUIView {
        LoopingPlayerUIView(
            resourceName: resourceName,
            fileExtension: fileExtension,
            videoGravity: videoGravity
        )
    }

    func updateUIView(_ uiView: LoopingPlayerUIView, context: Context) {}

    static func dismantleUIView(_ uiView: LoopingPlayerUIView, coordinator: ()) {
        uiView.teardown()
    }
}

final class LoopingPlayerUIView: UIView {
    private var playerLayer: AVPlayerLayer?
    private var queuePlayer: AVQueuePlayer?
    private var looper: AVPlayerLooper?

    init(resourceName: String, fileExtension: String, videoGravity: AVLayerVideoGravity) {
        super.init(frame: .zero)
        backgroundColor = .clear

        guard let url = Bundle.main.url(forResource: resourceName, withExtension: fileExtension) else {
            return
        }

        let item = AVPlayerItem(url: url)
        let player = AVQueuePlayer()
        player.isMuted = true
        player.actionAtItemEnd = .none

        let looper = AVPlayerLooper(player: player, templateItem: item)
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = videoGravity

        self.layer.addSublayer(layer)
        self.playerLayer = layer
        self.queuePlayer = player
        self.looper = looper

        player.play()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }

    func teardown() {
        queuePlayer?.pause()
        looper?.disableLooping()
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        queuePlayer = nil
        looper = nil
    }
}
