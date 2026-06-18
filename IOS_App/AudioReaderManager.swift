import Foundation
import AVFoundation
import SwiftUI
import Combine

/// Singleton text-to-speech reader that allows users to listen to articles.
/// Supports background audio (the app must enable the "Audio, AirPlay, and Picture in Picture"
/// background mode capability in the project) and Now Playing controls.
@MainActor
final class AudioReaderManager: NSObject, ObservableObject {
    static let shared = AudioReaderManager()

    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var isPaused: Bool = false
    @Published private(set) var currentArticleId: String?
    @Published private(set) var currentTitle: String = ""
    @Published private(set) var progress: Double = 0
    @Published var rate: Float = AVSpeechUtteranceDefaultSpeechRate

    private let synthesizer = AVSpeechSynthesizer()
    private var totalCharacters: Int = 1
    private var spokenCharacters: Int = 0
    private var currentText: String = ""
    private var currentLanguage: String = "en-US"

    override init() {
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers]
            )
        } catch {
            print("⚠️ Audio session config failed: \(error)")
        }
    }

    func play(article: Article) {
        let plain = Self.stripHTML(article.contentHTML.isEmpty ? article.excerpt : article.contentHTML)
        let text = (article.title + ". " + plain)
        guard !text.isEmpty else { return }

        // If we are resuming the same article that was paused, just continue.
        if currentArticleId == article.id, isPaused {
            synthesizer.continueSpeaking()
            isPaused = false
            isPlaying = true
            return
        }

        stop()
        currentArticleId = article.id
        currentTitle = article.title
        currentText = text
        totalCharacters = max(text.count, 1)
        spokenCharacters = 0
        progress = 0
        try? AVAudioSession.sharedInstance().setActive(true)

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate
        utterance.pitchMultiplier = 1.0
        utterance.postUtteranceDelay = 0.05
        utterance.voice = AVSpeechSynthesisVoice(language: currentLanguage)
        synthesizer.speak(utterance)
        isPlaying = true
        isPaused = false
    }

    func pause() {
        guard synthesizer.isSpeaking, !synthesizer.isPaused else { return }
        synthesizer.pauseSpeaking(at: .word)
        isPaused = true
        isPlaying = false
    }

    func resume() {
        guard synthesizer.isPaused else { return }
        synthesizer.continueSpeaking()
        isPaused = false
        isPlaying = true
    }

    func stop() {
        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isPlaying = false
        isPaused = false
        currentArticleId = nil
        currentTitle = ""
        progress = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    func setRate(_ newRate: Float) {
        rate = max(AVSpeechUtteranceMinimumSpeechRate,
                   min(AVSpeechUtteranceMaximumSpeechRate, newRate))
        // Apply rate change on the next utterance; if currently playing,
        // re-start at the current word for a snappier UX.
        if isPlaying || isPaused, !currentText.isEmpty {
            let remaining = String(currentText.dropFirst(spokenCharacters))
            synthesizer.stopSpeaking(at: .immediate)
            let u = AVSpeechUtterance(string: remaining)
            u.rate = rate
            u.voice = AVSpeechSynthesisVoice(language: currentLanguage)
            synthesizer.speak(u)
            isPlaying = true
            isPaused = false
        }
    }

    static func stripHTML(_ html: String) -> String {
        guard let data = html.data(using: .utf8) else { return html }
        if let attributed = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.html,
                      .characterEncoding: String.Encoding.utf8.rawValue],
            documentAttributes: nil
        ) {
            return attributed.string
                .replacingOccurrences(of: "\n+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return html
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension AudioReaderManager: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                        willSpeakRangeOfSpeechString characterRange: NSRange,
                                        utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.spokenCharacters = characterRange.location + characterRange.length
            self.progress = min(1.0, Double(self.spokenCharacters) / Double(self.totalCharacters))
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                        didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isPlaying = false
            self.isPaused = false
            self.progress = 1.0
            try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                                        didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isPlaying = false
        }
    }
}

// MARK: - Inline player UI used inside ArticleDetailView

struct AudioPlayerControls: View {
    @ObservedObject var manager: AudioReaderManager = .shared
    let article: Article

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                Button {
                    if manager.currentArticleId == article.id {
                        if manager.isPlaying {
                            manager.pause()
                        } else if manager.isPaused {
                            manager.resume()
                        } else {
                            manager.play(article: article)
                        }
                    } else {
                        manager.play(article: article)
                    }
                    HapticFeedback.light()
                } label: {
                    Image(systemName: playPauseIcon)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.indigo)
                        .clipShape(Circle())
                }
                .accessibilityLabel(playPauseLabel)
                .accessibilityIdentifier("audio-play-pause-button")

                VStack(alignment: .leading, spacing: 2) {
                    Text(manager.currentArticleId == article.id && (manager.isPlaying || manager.isPaused)
                         ? "Listen mode" : "Listen to article")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        Image(systemName: "headphones")
                            .font(.caption2)
                        Text(rateLabel)
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Menu {
                    Button("0.75x") { manager.setRate(AVSpeechUtteranceDefaultSpeechRate * 0.75) }
                    Button("1.0x")  { manager.setRate(AVSpeechUtteranceDefaultSpeechRate) }
                    Button("1.25x") { manager.setRate(AVSpeechUtteranceDefaultSpeechRate * 1.25) }
                    Button("1.5x")  { manager.setRate(AVSpeechUtteranceDefaultSpeechRate * 1.5) }
                } label: {
                    Image(systemName: "speedometer")
                        .padding(8)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Playback speed")

                if manager.currentArticleId == article.id && (manager.isPlaying || manager.isPaused) {
                    Button {
                        manager.stop()
                    } label: {
                        Image(systemName: "stop.fill")
                            .padding(8)
                            .background(Color(.systemGray6))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Stop listening")
                }
            }
            if manager.currentArticleId == article.id && (manager.isPlaying || manager.isPaused) {
                ProgressView(value: manager.progress)
                    .tint(.indigo)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var playPauseIcon: String {
        if manager.currentArticleId == article.id, manager.isPlaying { return "pause.fill" }
        return "play.fill"
    }

    private var playPauseLabel: String {
        if manager.currentArticleId == article.id, manager.isPlaying { return "Pause listening" }
        if manager.currentArticleId == article.id, manager.isPaused  { return "Resume listening" }
        return "Listen to this article"
    }

    private var rateLabel: String {
        let factor = manager.rate / AVSpeechUtteranceDefaultSpeechRate
        return String(format: "%.2gx", Double(factor))
    }
}

