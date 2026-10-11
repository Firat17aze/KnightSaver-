import SwiftUI

/// Nature colors flowing around the EcoKnight bar, like Gemini's moving border: leaf green,
/// a fresh sprout, Lake Claire blue and UCF sun gold. A crisp line only, no glow or blur.
/// It turns faster while EcoKnight is listening or answering, and stays still with Reduce Motion.
/// The turning runs in Core Animation, so SwiftUI doesn't redraw the page every frame.
struct EcoFlowBorder: View {
    var cornerRadius: CGFloat
    var isBusy = false
    var lineWidth: CGFloat = 2

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let colors: [Color] = [
        KnightTheme.green,
        KnightTheme.sprout,
        KnightTheme.lake,
        KnightTheme.gold,
        KnightTheme.green
    ]

    var body: some View {
        FlowBorderLayer(
            cornerRadius: cornerRadius,
            lineWidth: lineWidth,
            colors: Self.colors.map { UIColor($0) },
            lap: reduceMotion ? nil : (isBusy ? 2.4 : 6)
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct FlowBorderLayer: UIViewRepresentable {
    let cornerRadius: CGFloat
    let lineWidth: CGFloat
    let colors: [UIColor]
    /// Seconds per turn; nil keeps it still.
    let lap: Double?

    func makeUIView(context: Context) -> FlowBorderView { FlowBorderView() }

    func updateUIView(_ view: FlowBorderView, context: Context) {
        view.configure(cornerRadius: cornerRadius, lineWidth: lineWidth, colors: colors, lap: lap)
    }
}

/// A conic gradient, larger than the bar, turning behind a mask shaped like the bar's outline.
final class FlowBorderView: UIView {
    private let gradient = CAGradientLayer()
    private let outline = CAShapeLayer()
    private var cornerRadius: CGFloat = 0
    private var lineWidth: CGFloat = 2
    private var colors: [UIColor] = []
    private var lap: Double?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        gradient.type = .conic
        gradient.startPoint = CGPoint(x: 0.5, y: 0.5)
        gradient.endPoint = CGPoint(x: 0.5, y: 0)
        layer.addSublayer(gradient)
        outline.fillColor = nil
        outline.strokeColor = UIColor.black.cgColor
        layer.mask = outline
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: FlowBorderView, _) in
            view.applyColors()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(cornerRadius: CGFloat, lineWidth: CGFloat, colors: [UIColor], lap: Double?) {
        let lapChanged = lap != self.lap
        self.cornerRadius = cornerRadius
        self.lineWidth = lineWidth
        self.colors = colors
        self.lap = lap
        applyColors()
        setNeedsLayout()
        if lapChanged { spin() }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let side = hypot(bounds.width, bounds.height)
        gradient.bounds = CGRect(x: 0, y: 0, width: side, height: side)
        gradient.position = CGPoint(x: bounds.midX, y: bounds.midY)
        outline.frame = bounds
        outline.lineWidth = lineWidth
        let inset = bounds.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
        outline.path = UIBezierPath(roundedRect: inset, cornerRadius: max(0, cornerRadius - lineWidth / 2)).cgPath
        CATransaction.commit()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        // Core Animation drops animations when a view leaves the window (tab switch).
        spin()
    }

    private func applyColors() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradient.colors = colors.map { $0.resolvedColor(with: traitCollection).cgColor }
        CATransaction.commit()
    }

    /// Starts the turn from wherever the colors are now, so changing speed doesn't jump.
    private func spin() {
        let current = (gradient.presentation()?.value(forKeyPath: "transform.rotation.z") as? Double) ?? 0
        gradient.removeAnimation(forKey: "spin")
        guard let lap, window != nil else { return }
        let turn = CABasicAnimation(keyPath: "transform.rotation.z")
        turn.fromValue = current
        turn.toValue = current + 2 * Double.pi
        turn.duration = lap
        turn.repeatCount = .infinity
        turn.isRemovedOnCompletion = false
        gradient.add(turn, forKey: "spin")
    }
}

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
                .foregroundStyle(KnightTheme.lake)
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
            EcoFlowBorder(cornerRadius: 16, isBusy: isAnswering || focused)
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
