import AVFoundation
import UIKit

/// A short, synthesized capture cue so the effect stays lightweight and needs no audio asset.
@MainActor
final class TerritoryConquestFeedback {
    static let shared = TerritoryConquestFeedback()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate = 44_100.0
    private var playbackGeneration = 0

    private init() {
        engine.attach(player)
        let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 1
        )!
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    func prepare() {
        guard !engine.isRunning else { return }
        engine.prepare()
    }

    func playBreak() {
        let haptic = UIImpactFeedbackGenerator(style: .rigid)
        haptic.prepare()
        haptic.impactOccurred(intensity: 0.9)

        playbackGeneration += 1
        let generation = playbackGeneration

        do {
            if !engine.isRunning {
                try engine.start()
            }

            player.stop()
            player.scheduleBuffer(makeEnergyBuffer())
            player.play()

            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(240))
                guard let self, self.playbackGeneration == generation else { return }
                self.stopAudio()
            }
        } catch {
            AppLogger.run.warning("Territory conquest sound could not play: \(error.localizedDescription)")
        }
    }

    func stop() {
        playbackGeneration += 1
        stopAudio()
    }

    private func stopAudio() {
        player.stop()
        engine.stop()
    }

    private func makeEnergyBuffer() -> AVAudioPCMBuffer {
        let duration = 0.19
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: 1
        )!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        guard let samples = buffer.floatChannelData?[0] else { return buffer }
        var noiseState: UInt32 = 0xA341_316C

        for frame in 0..<Int(frameCount) {
            let time = Double(frame) / sampleRate
            let progress = time / duration
            let envelope = pow(max(0, 1 - progress), 2.4)
            let frequency = 1_260 - (760 * progress)
            let sweep = sin(2 * .pi * frequency * time)
            let shimmer = sin(2 * .pi * (frequency * 1.93) * time) * 0.26
            let thumpFrequency = 96 - (28 * progress)
            let thumpEnvelope = pow(max(0, 1 - progress), 4.2)
            let thumpAttack = min(time / 0.008, 1)
            let thump = sin(2 * .pi * thumpFrequency * time) * thumpEnvelope * thumpAttack

            noiseState = 1_664_525 &* noiseState &+ 1_013_904_223
            let noise = (Double(noiseState) / Double(UInt32.max)) * 2 - 1
            let clickEnvelope = exp(-time * 92)

            samples[frame] = Float(
                ((sweep + shimmer) * envelope * 0.2)
                    + (noise * clickEnvelope * 0.14)
                    + (thump * 0.29)
            )
        }

        return buffer
    }
}
