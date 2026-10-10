import PhotosUI
import SwiftUI

/// EcoKnight AI (student.md): after a verified pickup the student photographs or types what was
/// in the bag, confirms the items, says what their kitchen has, and gets ideas to use the food,
/// what to eat first, storage tips and a plain explanation of the estimated impact.
struct EcoKnightView: View {
    let rescue: StudentRescue?

    @Environment(\.dismiss) private var dismiss

    private enum Step { case capture, confirm, plan }

    @State private var step: Step
    @State private var photoItem: PhotosPickerItem?
    @State private var photoJPEG: Data?
    @State private var photoPreview: UIImage?
    @State private var note = ""
    @State private var items: [EcoItem] = []
    @State private var aiNote: String?
    @State private var kitchen = EcoKitchen()
    @State private var plan: EcoPlan?
    @State private var isWorking = false
    @State private var problem: String?
    @State private var usedOffline = false
    @State private var chat: [(role: String, text: String)] = []
    @State private var question = ""
    @State private var isAnswering = false
    @State private var showKeySheet = false
    @State private var hasKey = EcoKnightClient.hasKey
    @FocusState private var focused: Bool

    private let client = EcoKnightClient()

    init(rescue: StudentRescue?) {
        self.rescue = rescue
        _step = State(initialValue: rescue == nil ? .plan : .capture)
    }

    /// The numbers EcoKnight may quote. Never invented by the AI.
    private var impactLine: String {
        guard let rescue else { return "no rescue selected" }
        let food = rescue.foodKg
        return String(
            format: "%d bag%@, about %.1f kg of food (%@), about %.1f kg CO2e avoided (estimate)",
            rescue.bags, rescue.bags == 1 ? "" : "s", food,
            rescue.measuredKg == nil ? "estimated" : "weighed at pickup",
            food * ImpactRules.co2ePerFoodKg
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    modeBanner
                    switch step {
                    case .capture: captureView
                    case .confirm: confirmView
                    case .plan: planView
                    }
                }
                .padding(KnightTheme.screenPadding)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(KnightTheme.paper)
            .navigationTitle("EcoKnight AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if step == .confirm || (step == .plan && rescue != nil) {
                        Button {
                            step = step == .plan ? .confirm : .capture
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                        }
                    } else {
                        Button("Close") { dismiss() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showKeySheet = true
                    } label: {
                        Image(systemName: "key")
                    }
                    .accessibilityLabel("Live AI settings")
                }
            }
            .sheet(isPresented: $showKeySheet, onDismiss: { hasKey = EcoKnightClient.hasKey }) {
                APIKeySheet()
                    .presentationDetents([.medium])
            }
        }
        .tint(KnightTheme.ink)
    }

    // MARK: Mode

    private var modeBanner: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(hasKey ? KnightTheme.green : KnightTheme.goldDeep)
                .frame(width: 8, height: 8)
            Text(hasKey ? "Live AI" : "Offline mode · add a key for live AI")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(KnightTheme.muted)
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Step 1 — what was in the bag

    private var captureView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let rescue {
                Text("What was in your bag?")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(KnightTheme.ink)
                Text("\(rescue.business) · \(ImpactFormat.shortDate(rescue.verifiedAt)) · \(rescue.bags) bag\(rescue.bags == 1 ? "" : "s")")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(KnightTheme.muted)
            }

            PhotosPicker(selection: $photoItem, matching: .images) {
                ZStack {
                    if let photoPreview {
                        Image(uiImage: photoPreview)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 190)
                            .frame(maxWidth: .infinity)
                            .clipped()
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(KnightTheme.goldDeep)
                            Text("Add a photo of what you got")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(KnightTheme.ink)
                            Text(hasKey ? "EcoKnight will list what it sees. You confirm it." : "Photos need live AI. You can type instead.")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(KnightTheme.muted)
                        }
                        .frame(height: 150)
                        .frame(maxWidth: .infinity)
                    }
                }
                .background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(KnightTheme.line, style: StrokeStyle(lineWidth: 1, dash: photoPreview == nil ? [6, 5] : []))
                }
            }
            .buttonStyle(.plain)
            .onChange(of: photoItem) { _, item in
                Task { await loadPhoto(item) }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Or type it")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(KnightTheme.muted)
                TextField("2 bagels, a croissant and 3 cookies", text: $note, axis: .vertical)
                    .lineLimit(2...4)
                    .focused($focused)
                    .padding(14)
                    .background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(KnightTheme.line, lineWidth: 1)
                    }
            }

            if let problem {
                Label(problem, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(KnightTheme.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                Task { await identify() }
            } label: {
                primaryLabel(isWorking ? "Looking…" : "Identify items", icon: "sparkles")
            }
            .buttonStyle(.plain)
            .disabled(isWorking || (photoJPEG == nil && note.trimmingCharacters(in: .whitespaces).isEmpty))
            .opacity(photoJPEG == nil && note.trimmingCharacters(in: .whitespaces).isEmpty ? 0.45 : 1)

            disclaimer("EcoKnight can't confirm ingredients, allergens or freshness. Check the business's labels when it matters.")
        }
    }

    // MARK: Step 2 — confirm items and kitchen

    private var confirmView: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Is this right?")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(KnightTheme.ink)
            Text("Fix anything EcoKnight got wrong. Ideas only use what you confirm.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(KnightTheme.muted)

            VStack(spacing: 0) {
                ForEach(items) { item in
                    let row = binding(for: item.id)
                    HStack(spacing: 10) {
                        Button {
                            items.removeAll { $0.id == item.id }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(KnightTheme.red)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove \(item.name)")

                        TextField("Item", text: row.name)
                            .font(.system(size: 16, weight: .medium))
                        if item.confidence.lowercased() != "high" {
                            Text("Check")
                                .font(.system(size: 10, weight: .black, design: .rounded))
                                .foregroundStyle(KnightTheme.goldDeep)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(KnightTheme.gold.opacity(0.18), in: Capsule())
                                .accessibilityLabel("EcoKnight isn't sure about this one")
                        }
                        Text("\(item.quantity)")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .frame(minWidth: 22)
                        Stepper("Quantity", value: row.quantity, in: 1...50)
                            .labelsHidden()
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 54)
                    Divider().overlay(KnightTheme.line)
                }
                Button {
                    items.append(EcoItem(name: "", quantity: 1))
                } label: {
                    Label("Add item", systemImage: "plus.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(KnightTheme.green)
                        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                        .padding(.horizontal, 14)
                }
                .buttonStyle(.plain)
            }
            .background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            if let aiNote, !aiNote.isEmpty {
                Label(aiNote, systemImage: "info.circle")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(KnightTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Your kitchen")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(KnightTheme.ink)
                VStack(spacing: 0) {
                    kitchenToggle("Microwave", "microwave", $kitchen.microwave)
                    kitchenToggle("Mini-fridge", "refrigerator", $kitchen.miniFridge)
                    kitchenToggle("Electric kettle", "cup.and.saucer", $kitchen.kettle)
                    kitchenToggle("Stove or oven", "frying.pan", $kitchen.stove)
                }
                .background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            if let problem {
                Label(problem, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(KnightTheme.red)
            }

            Button {
                Task { await makePlan() }
            } label: {
                primaryLabel(isWorking ? "Thinking…" : "These are right, get ideas", icon: "checkmark")
            }
            .buttonStyle(.plain)
            .disabled(isWorking || validItems.isEmpty)
            .opacity(validItems.isEmpty ? 0.45 : 1)
        }
    }

    /// Safe binding by id, so removing a row never leaves a stale index behind.
    private func binding(for id: UUID) -> Binding<EcoItem> {
        Binding(
            get: { items.first { $0.id == id } ?? EcoItem(name: "", quantity: 1) },
            set: { newValue in
                if let index = items.firstIndex(where: { $0.id == id }) { items[index] = newValue }
            }
        )
    }

    private var validItems: [EcoItem] {
        items.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    // MARK: Step 3 — plan and chat

    private var planView: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let plan {
                Text("Your rescue plan")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(KnightTheme.ink)
                if usedOffline {
                    Label("Offline ideas. Add a key for live AI.", systemImage: "wifi.slash")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(KnightTheme.goldDeep)
                }

                if !plan.useFirst.isEmpty {
                    planCard(title: "Eat first", icon: "clock.badge.exclamationmark") {
                        ForEach(plan.useFirst, id: \.self) { entry in
                            bullet(bold: entry.item, text: entry.why)
                        }
                    }
                }

                ForEach(plan.meals) { meal in
                    planCard(title: meal.title, icon: "fork.knife", trailing: meal.minutes.map { "\($0) min" }) {
                        ForEach(Array(meal.steps.enumerated()), id: \.offset) { index, stepText in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(index + 1)")
                                    .font(.system(size: 12, weight: .black, design: .rounded))
                                    .foregroundStyle(KnightTheme.onAccent)
                                    .frame(width: 22, height: 22)
                                    .background(KnightTheme.gold, in: Circle())
                                Text(stepText)
                                    .font(.system(size: 14))
                                    .foregroundStyle(KnightTheme.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                if !plan.storage.isEmpty {
                    planCard(title: "Storing leftovers", icon: "refrigerator") {
                        ForEach(plan.storage, id: \.self) { entry in
                            bullet(bold: entry.item, text: entry.tip)
                        }
                    }
                }

                if let share = plan.share, !share.isEmpty {
                    planCard(title: "Share it", icon: "person.2") {
                        Text(share).font(.system(size: 14)).foregroundStyle(KnightTheme.ink)
                    }
                }

                if let impact = plan.impact, !impact.isEmpty {
                    planCard(title: "Your impact", icon: "leaf.fill", tint: KnightTheme.green) {
                        Text(impact).font(.system(size: 14)).foregroundStyle(KnightTheme.ink)
                    }
                }

                disclaimer("Suggestions only. EcoKnight can't confirm ingredients, allergens, freshness or safety. Impact numbers are estimates.")
            } else {
                Text("Ask EcoKnight")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(KnightTheme.ink)
                Text("Questions about using food, storing it, food waste or carbon footprint.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(KnightTheme.muted)
            }

            chatSection
        }
    }

    private var chatSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if plan != nil {
                Text("Ask a follow-up")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(KnightTheme.ink)
            }
            ForEach(Array(chat.enumerated()), id: \.offset) { _, turn in
                HStack {
                    if turn.role == "user" { Spacer(minLength: 40) }
                    Text(turn.text)
                        .font(.system(size: 14))
                        .foregroundStyle(turn.role == "user" ? KnightTheme.onAccent : KnightTheme.ink)
                        .padding(12)
                        .background(
                            turn.role == "user" ? KnightTheme.gold : KnightTheme.surface,
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                        .fixedSize(horizontal: false, vertical: true)
                    if turn.role != "user" { Spacer(minLength: 40) }
                }
            }
            if isAnswering {
                Label("EcoKnight is thinking…", systemImage: "ellipsis")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(KnightTheme.muted)
            }
            HStack(spacing: 8) {
                TextField("Can I freeze bagels?", text: $question, axis: .vertical)
                    .lineLimit(1...3)
                    .focused($focused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(KnightTheme.line, lineWidth: 1) }
                Button {
                    Task { await askQuestion() }
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(KnightTheme.onAccent)
                        .frame(width: 44, height: 44)
                        .background(KnightTheme.gold, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(isAnswering || question.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel("Send question")
            }
        }
    }

    // MARK: Pieces

    private func primaryLabel(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            if isWorking { ProgressView().tint(KnightTheme.onAccent) } else { Image(systemName: icon) }
            Text(title)
        }
        .font(.system(size: 16, weight: .bold, design: .rounded))
        .foregroundStyle(KnightTheme.onAccent)
        .frame(maxWidth: .infinity, minHeight: 54)
        .background(KnightTheme.gold, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func disclaimer(_ text: String) -> some View {
        Label(text, systemImage: "info.circle.fill")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(KnightTheme.muted)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KnightTheme.gold.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func kitchenToggle(_ title: String, _ icon: String, _ isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Label(title, systemImage: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(KnightTheme.ink)
        }
        .tint(KnightTheme.green)
        .padding(.horizontal, 14)
        .frame(minHeight: 50)
    }

    private func bullet(bold: String, text: String) -> some View {
        (Text(bold.capitalized).bold() + Text(" · " + text))
            .font(.system(size: 14))
            .foregroundStyle(KnightTheme.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func planCard<Content: View>(
        title: String,
        icon: String,
        tint: Color = KnightTheme.goldDeep,
        trailing: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(KnightTheme.ink)
                    .labelStyle(TintedIconLabelStyle(tint: tint))
                Spacer()
                if let trailing {
                    Text(trailing)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(KnightTheme.muted)
                }
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: Actions

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
        photoJPEG = EcoKnightClient.preparedJPEG(from: data)
        photoPreview = photoJPEG.flatMap(UIImage.init(data:))
        problem = nil
    }

    private func identify() async {
        focused = false
        problem = nil
        isWorking = true
        defer { isWorking = false }
        let typed = note.trimmingCharacters(in: .whitespacesAndNewlines)

        if hasKey {
            do {
                let result = try await client.identify(imageJPEG: photoJPEG, note: typed)
                items = result.items
                aiNote = result.note
                usedOffline = false
                step = .confirm
                return
            } catch {
                problem = (error as? LocalizedError)?.errorDescription ?? "Live AI didn't answer."
                if typed.isEmpty { return }
            }
        } else if typed.isEmpty {
            problem = "Reading photos needs live AI. Type what was in the bag instead."
            return
        }

        let offline = EcoKnightOffline.identify(note: typed)
        guard !offline.items.isEmpty else {
            problem = offline.note ?? "Couldn't find any items. Try \"2 bagels and a cookie\"."
            return
        }
        items = offline.items
        aiNote = offline.note
        usedOffline = true
        step = .confirm
    }

    private func makePlan() async {
        problem = nil
        isWorking = true
        defer { isWorking = false }
        let confirmed = validItems
        if hasKey {
            do {
                plan = try await client.plan(items: confirmed, kitchen: kitchen, impactLine: impactLine)
                usedOffline = false
                step = .plan
                return
            } catch {
                // Fall through to offline ideas so the student still gets help.
            }
        }
        plan = EcoKnightOffline.plan(items: confirmed, kitchen: kitchen, impactLine: impactLine)
        usedOffline = true
        step = .plan
    }

    private func askQuestion() async {
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        question = ""
        focused = false
        chat.append((role: "user", text: text))
        isAnswering = true
        defer { isAnswering = false }

        let items = validItems.map { "\($0.quantity) \($0.name)" }.joined(separator: ", ")
        let context = rescue == nil
            ? "The student has no verified rescue selected."
            : "Confirmed items: \(items.isEmpty ? "not confirmed yet" : items). Kitchen: \(kitchen.summary). Impact: \(impactLine)."
        if hasKey {
            do {
                let answer = try await client.ask(history: Array(chat.suffix(8)), context: context)
                chat.append((role: "assistant", text: answer))
                return
            } catch {
                // Offline answer below.
            }
        }
        chat.append((role: "assistant", text: EcoKnightOffline.answer(text)))
    }
}

private struct TintedIconLabelStyle: LabelStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.icon.foregroundStyle(tint)
            configuration.title
        }
    }
}

// MARK: - API key

/// Paste an AI API key once on this device. It goes to the Keychain, never to the repo.
private struct APIKeySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var key = ""
    @State private var hasKey = EcoKnightClient.hasKey

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("api-key-…", text: $key)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if hasKey {
                        Button("Remove saved key", role: .destructive) {
                            APIKeyStore.delete()
                            hasKey = false
                        }
                    }
                } header: {
                    Text(hasKey ? "A key is saved" : "AI API key")
                } footer: {
                    Text("Create one in your AI provider console. It's stored only in this iPhone's Keychain. Never put it in the code or commit it to GitHub. Without a key, EcoKnight uses offline ideas.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(KnightTheme.paper)
            .navigationTitle("Live AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        APIKeyStore.save(key)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(key.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
