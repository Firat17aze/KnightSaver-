import AVFoundation
import UIKit
import Speech
import SwiftUI

/// Live speech-to-text for staff talking to the surplus assistant.
/// Words stream into the text box while the employee speaks; tapping the mic again stops.
final class VoiceDictation: ObservableObject {
    enum Status: Equatable {
        case idle
        case starting
        case listening
        case denied
        case unavailable
    }

    @Published private(set) var status: Status = .idle
    /// 0...1 loudness of the last audio buffer, used to animate the mic rings.
    @Published private(set) var level: CGFloat = 0

    var isListening: Bool { status == .listening || status == .starting }

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var session = 0

    /// Starts listening, or stops if already listening.
    /// `current` is kept and new words are added after it.
    func toggle(current: String, onText: @escaping (String) -> Void) {
        if isListening {
            stop()
        } else {
            start(current: current, onText: onText)
        }
    }

    func start(current: String, onText: @escaping (String) -> Void) {
        guard !isListening else { return }
        status = .starting
        session += 1
        let thisSession = session

        SFSpeechRecognizer.requestAuthorization { speechStatus in
            AVAudioApplication.requestRecordPermission { micAllowed in
                DispatchQueue.main.async {
                    guard self.session == thisSession, self.status == .starting else { return }
                    guard speechStatus == .authorized, micAllowed else {
                        self.status = .denied
                        return
                    }
                    guard let recognizer = self.recognizer, recognizer.isAvailable else {
                        self.status = .unavailable
                        return
                    }
                    do {
                        try self.beginRecognition(with: recognizer, current: current, session: thisSession, onText: onText)
                        self.status = .listening
                    } catch {
                        self.tearDown()
                        self.status = .unavailable
                    }
                }
            }
        }
    }

    func stop() {
        guard isListening else { return }
        session += 1
        tearDown()
        status = .idle
    }

    private func beginRecognition(
        with recognizer: SFSpeechRecognizer,
        current: String,
        session thisSession: Int,
        onText: @escaping (String) -> Void
    ) throws {
        tearDown()

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        request.contextualStrings = SurplusAssistant.speechHints
        self.request = request

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
            let loudness = VoiceDictation.loudness(of: buffer)
            DispatchQueue.main.async {
                guard self.session == thisSession else { return }
                self.level = loudness
            }
        }

        audioEngine.prepare()
        try audioEngine.start()

        let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = trimmed.isEmpty ? "" : trimmed + " "

        task = recognizer.recognitionTask(with: request) { result, error in
            let spoken = result?.bestTranscription.formattedString
            let finished = error != nil || (result?.isFinal ?? false)
            DispatchQueue.main.async {
                guard self.session == thisSession else { return }
                if let spoken, !spoken.isEmpty {
                    onText(prefix + spoken)
                }
                if finished {
                    self.stop()
                }
            }
        }
    }

    private func tearDown() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        level = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private static func loudness(of buffer: AVAudioPCMBuffer) -> CGFloat {
        guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        let count = Int(buffer.frameLength)
        var sum: Float = 0
        for index in 0..<count {
            sum += samples[index] * samples[index]
        }
        let rms = sqrt(sum / Float(count))
        // Speech sits roughly between -50 dB and -10 dB.
        let decibels = 20 * log10(max(rms, 0.000_01))
        return CGFloat(min(max((decibels + 50) / 40, 0), 1))
    }
}

/// Text box plus a big microphone. The employee taps the mic and talks;
/// the words appear in the box and can still be corrected by typing.
struct BizVoiceComposer: View {
    let prompt: String
    @Binding var text: String
    var focus: FocusState<Bool>.Binding
    @ObservedObject var voice: VoiceDictation

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 18) {
            BizDictationBox(prompt: prompt, text: $text, focus: focus, isLive: voice.isListening)

            VStack(spacing: 10) {
                micButton
                statusLine
            }
            .frame(maxWidth: .infinity)

            if voice.status == .denied || voice.status == .unavailable {
                permissionNote
            }
        }
        .onChange(of: focus.wrappedValue) { _, isTyping in
            if isTyping { voice.stop() }
        }
        .onDisappear { voice.stop() }
    }

    private var micButton: some View {
        Button {
            focus.wrappedValue = false
            BizKeyboard.hide()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            voice.toggle(current: text) { text = $0 }
        } label: {
            ZStack {
                if voice.isListening {
                    MicRings(level: voice.level, reduceMotion: reduceMotion)
                } else {
                    Circle()
                        .stroke(KnightTheme.gold.opacity(0.35), lineWidth: 1.5)
                        .frame(width: 104, height: 104)
                }

                Circle()
                    .fill(
                        voice.isListening
                            ? AnyShapeStyle(KnightTheme.red)
                            : AnyShapeStyle(LinearGradient(
                                colors: [Color(red: 0.99, green: 0.83, blue: 0.36), KnightTheme.gold],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                    )
                    .frame(width: 84, height: 84)
                    .shadow(color: (voice.isListening ? KnightTheme.red : KnightTheme.gold).opacity(0.35), radius: 14, y: 6)

                Image(systemName: voice.isListening ? "mic.fill" : "mic")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(voice.isListening ? Color.white : KnightTheme.onAccent)
                    .symbolEffect(.bounce, value: voice.isListening)
            }
            .frame(width: 128, height: 128)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(voice.isListening ? "Stop listening" : "Talk to the assistant")
        .accessibilityHint("Speak and your words are written into the box.")
    }

    @ViewBuilder
    private var statusLine: some View {
        switch voice.status {
        case .listening, .starting:
            HStack(spacing: 8) {
                LiveBars(level: voice.level, reduceMotion: reduceMotion)
                Text(voice.status == .starting ? "Getting the mic ready…" : "Listening… tap to stop")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(KnightTheme.red)
            }
        default:
            Text(text.isEmpty ? "Tap to talk" : "Tap to keep talking")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(KnightTheme.ink)
        }
    }

    private var permissionNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(
                voice.status == .denied
                    ? "Microphone or speech access is off."
                    : "Voice isn't available right now.",
                systemImage: "mic.slash"
            )
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(KnightTheme.ink)
            Text("You can still type, or use the microphone on the keyboard.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(KnightTheme.muted)
            if voice.status == .denied, let settings = URL(string: UIApplication.openSettingsURLString) {
                Button("Open Settings") { openURL(settings) }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(KnightTheme.goldDeep)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(KnightTheme.line, lineWidth: 1)
        }
    }
}

/// Two soft rings around the mic that breathe with the speaker's voice.
private struct MicRings: View {
    let level: CGFloat
    let reduceMotion: Bool
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(KnightTheme.red.opacity(0.10))
                .frame(width: 84, height: 84)
                .scaleEffect(reduceMotion ? 1.35 : 1.15 + level * 0.4)
            Circle()
                .stroke(KnightTheme.red.opacity(0.35), lineWidth: 2)
                .frame(width: 84, height: 84)
                .scaleEffect(reduceMotion ? 1.2 : (pulse ? 1.5 : 1.05))
                .opacity(reduceMotion ? 0.8 : (pulse ? 0 : 0.9))
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: level)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.3).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }
}

/// A tiny five-bar meter next to "Listening…".
private struct LiveBars: View {
    let level: CGFloat
    let reduceMotion: Bool
    private let shape: [CGFloat] = [0.45, 0.8, 1.0, 0.7, 0.4]

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(shape.indices, id: \.self) { index in
                Capsule()
                    .fill(KnightTheme.red)
                    .frame(width: 3, height: 4 + (reduceMotion ? 0.5 : level) * 14 * shape[index])
            }
        }
        .frame(height: 18)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: level)
        .accessibilityHidden(true)
    }
}
