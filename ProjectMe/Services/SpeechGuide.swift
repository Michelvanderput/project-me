import AVFoundation

/// Rustige Nederlandse stem voor meditaties en oefeningen (optioneel).
@MainActor
final class SpeechGuide {
    static let shared = SpeechGuide()
    private let synthesizer = AVSpeechSynthesizer()

    var isEnabled: Bool { AppGroup.defaults.bool(forKey: PrefKey.voiceGuidance) }

    func speak(_ text: String) {
        guard isEnabled else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        synthesizer.stopSpeaking(at: .word)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "nl-NL")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.82
        utterance.pitchMultiplier = 0.95
        utterance.preUtteranceDelay = 0.2
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
