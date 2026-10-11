import SwiftUI

/// EcoKnight AI as a bar at the top of Impact: "How can I help you?". The student types a
/// question and the answer opens under the bar, pushing the page down. EcoKnight can look up the student's own
/// stats with tools when a question needs them. It asks Gemini when a key is set, then Apple's
/// on-device model, then simple offline answers.
struct EcoKnightAskBar: View {
    let stats: EcoStats

    private struct Exchange: Identifiable {
        let id = UUID()
        let question: String
        var answer: String?
    }

    @State private var question = ""
    @State private var exchanges: [Exchange] = []
    @State private var onDeviceChat: EcoOnDeviceChat?
    /// The Gemini conversation in API format, so follow-up questions keep their context.
    @State private var geminiContents: [[String: Any]] = []
    @State private var isAnswering = false
    @FocusState private var focused: Bool

    private var canSend: Bool {
        !isAnswering && !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        // The answers open under the bar and push the page down, so nothing is covered.
        VStack(spacing: 8) {
            bar
            if !exchanges.isEmpty {
                dropdown
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: Bar

    private var bar: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 17))
                .foregroundStyle(KnightTheme.goldDeep)
                .accessibilityHidden(true)

            TextField("How can I help you?", text: $question)
                .font(.system(size: 16))
                .foregroundStyle(KnightTheme.ink)
                .focused($focused)
                .submitLabel(.send)
                .onSubmit { Task { await send() } }
                .accessibilityLabel("Ask EcoKnight AI")

            if isAnswering {
                ProgressView()
                    .tint(KnightTheme.muted)
            } else if !question.isEmpty {
                Button {
                    Task { await send() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(canSend ? KnightTheme.ink : KnightTheme.line)
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .accessibilityLabel("Send")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 54)
        .background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(focused ? KnightTheme.ink.opacity(0.35) : KnightTheme.line, lineWidth: 1)
        }
        .contentShape(Rectangle())
        .onTapGesture { focused = true }
    }

    // MARK: Dropdown

    private var dropdown: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("EcoKnight")
                    .font(.system(size: 13))
                    .foregroundStyle(KnightTheme.muted)
                Spacer()
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { close() }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13))
                        .foregroundStyle(KnightTheme.muted)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close answers")
            }
            .padding(.leading, 14)
            .padding(.trailing, 6)
            .padding(.top, 4)

            Divider().overlay(KnightTheme.line)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(exchanges) { exchange in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(exchange.question)
                                    .font(.system(size: 14))
                                    .foregroundStyle(KnightTheme.muted)
                                if let answer = exchange.answer {
                                    Text(answer)
                                        .font(.system(size: 15))
                                        .foregroundStyle(KnightTheme.ink)
                                        .textSelection(.enabled)
                                        .fixedSize(horizontal: false, vertical: true)
                                } else {
                                    Text("Thinking…")
                                        .font(.system(size: 15))
                                        .foregroundStyle(KnightTheme.muted)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(exchange.id)
                        }
                    }
                    .padding(14)
                }
                .frame(maxHeight: 340)
                .fixedSize(horizontal: false, vertical: true)
                .onChange(of: exchanges.count) { _, _ in
                    if let last = exchanges.last { proxy.scrollTo(last.id, anchor: .top) }
                }
            }
        }
        .background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(KnightTheme.line, lineWidth: 1)
        }
    }

    // MARK: Actions

    private func close() {
        exchanges = []
        onDeviceChat = nil
        geminiContents = []
        focused = false
    }

    private func send() async {
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isAnswering else { return }
        question = ""
        focused = false
        let exchange = Exchange(question: text)
        withAnimation(.easeOut(duration: 0.15)) { exchanges.append(exchange) }
        isAnswering = true
        defer { isAnswering = false }

        var answer: String?
        if GeminiAPI.isConfigured {
            // Start over before a long conversation gets slow.
            var contents = geminiContents.count > 40 ? [] : geminiContents
            contents.append(EcoKnightClient.studentMessage(text: text, photoJPEG: nil))
            do {
                answer = try await EcoKnightClient().reply(contents: &contents, stats: stats).text
                geminiContents = contents
            } catch EcoKnightError.refused {
                answer = EcoKnightError.refused.errorDescription
            } catch {
                answer = nil
            }
        }
        if answer == nil, EcoKnightOnDeviceSupport.isAvailable {
            let chat = onDeviceChat ?? EcoOnDeviceChat(stats: stats)
            onDeviceChat = chat
            do {
                answer = try await chat.reply(to: text).text
            } catch EcoKnightError.refused {
                answer = EcoKnightError.refused.errorDescription
            } catch {
                answer = nil
            }
        }
        let final = Self.plain(answer ?? EcoKnightOffline.answer(text, stats: stats).text)
        if let index = exchanges.firstIndex(where: { $0.id == exchange.id }) {
            exchanges[index].answer = final
        }
    }

    /// Plain text only: drop markdown emphasis the model sometimes adds.
    private static func plain(_ text: String) -> String {
        text.replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .replacingOccurrences(of: "\n* ", with: "\n- ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
