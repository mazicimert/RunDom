import AVFoundation
import Foundation

final class RunAudioService: NSObject {
    static let shared = RunAudioService()

    private let synthesizer = AVSpeechSynthesizer()
    private var isSessionActive = false

    override private init() {
        super.init()
        synthesizer.delegate = self
    }

    func announceKilometer(km: Int, paceSecondsPerKm: Double, useMiles: Bool) {
        let enabled = UserDefaults.standard.object(
            forKey: AppConstants.UserDefaultsKeys.voiceFeedbackEnabled
        ) as? Bool ?? true
        guard enabled else { return }

        let language = AppLanguage(rawValue: LocalizationManager.shared.selectedLanguageCode) ?? .english
        let totalSeconds = max(0, Int(paceSecondsPerKm.rounded()))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60

        let text: String
        let voiceLanguage: String
        switch language {
        case .turkish:
            let unitNoun = useMiles ? "mil" : "kilometre"
            text = "\(km) \(unitNoun). Tempo \(minutes) dakika \(seconds) saniye."
            voiceLanguage = "tr-TR"
        case .portuguese:
            let unitNoun = useMiles ? "milhas" : "quilômetros"
            text = "\(km) \(unitNoun). Ritmo \(minutes) minutos \(seconds) segundos."
            voiceLanguage = "pt-BR"
        case .spanish:
            let unitNoun = useMiles ? "millas" : "kilómetros"
            text = "\(km) \(unitNoun). Ritmo \(minutes) minutos \(seconds) segundos."
            voiceLanguage = "es-ES"
        case .german:
            let unitNoun = useMiles ? "Meilen" : "Kilometer"
            text = "\(km) \(unitNoun). Pace \(minutes) Minuten \(seconds) Sekunden."
            voiceLanguage = "de-DE"
        case .english:
            let unitNoun = useMiles ? "mile" : "kilometer"
            text = "\(km) \(unitNoun). Pace \(minutes) minutes \(seconds) seconds."
            voiceLanguage = "en-US"
        }

        if !isSessionActive {
            configureAudioSession()
            isSessionActive = true
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: voiceLanguage)
        synthesizer.speak(utterance)
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        if isSessionActive {
            resetAudioSession()
            isSessionActive = false
        }
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
        } catch {
            AppLogger.run.error("Audio session configure failed: \(error.localizedDescription)")
        }
    }

    private func resetAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            AppLogger.run.error("Audio session reset failed: \(error.localizedDescription)")
        }
    }
}

extension RunAudioService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        guard !synthesizer.isSpeaking else { return }
        if isSessionActive {
            resetAudioSession()
            isSessionActive = false
        }
    }
}
