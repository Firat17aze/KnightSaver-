import SwiftUI

/// "+ List surplus": staff describe the real surplus (AI or manual), confirm what was
/// understood, review the proposed Surprise Bag plan, then approve and publish.
struct ListSurplusFlow: View {
    @ObservedObject var store: BusinessStore
    @Environment(\.dismiss) private var dismiss

    private enum Step {
        case choose
        case speak
        case understood
        case plan
    }

    @State private var step: Step = .choose
    @State private var usingAI = false
    @State private var transcript = ""
    @State private var notes: [String] = []
    @State private var inventory: [SurplusItem] = []
    @State private var pickupStart: Date
    @State private var pickupEnd: Date
    @State private var heardPrice: Double?
    @State private var plan: BagPlan?
    @FocusState private var dictationFocused: Bool
    @StateObject private var dictation = VoiceDictation()

    static let exampleSentence = "We have 4 bagels and 6 cookies left. Pickup can be from 7:00 to 7:30 PM."

    init(store: BusinessStore) {
        _store = ObservedObject(wrappedValue: store)
        let start = PickupTime.roundedDown(Date().addingTimeInterval(30 * 60))
        _pickupStart = State(initialValue: start)
        _pickupEnd = State(initialValue: start.addingTimeInterval(BusinessRules.defaultPickupLength))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .choose:
                    chooseView
                case .speak:
                    speakView
                case .understood:
                    understoodView
                case .plan:
                    if let binding = Binding($plan) {
                        BagPlanEditor(plan: binding) {
                            if let plan {
                                store.publish(plan)
                            }
                            dismiss()
                        }
                    }
                }
            }
            .background(KnightTheme.paper)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if step == .choose {
                        Button("Cancel") { dismiss() }
                    } else {
                        Button {
                            goBack()
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                        }
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { BizKeyboard.hide() }
                }
            }
        }
        .tint(KnightTheme.ink)
    }

    private var title: String {
        switch step {
        case .choose: return "List surplus"
        case .speak: return "Speak with AI"
        case .understood: return usingAI ? "What I understood" : "Surplus inventory"
        case .plan: return usingAI ? "Proposed listing" : "Plan Surprise Bags"
        }
    }

    private func goBack() {
        switch step {
        case .choose: break
        case .speak:
            dictation.stop()
            step = .choose
        case .understood: step = usingAI ? .speak : .choose
        case .plan: step = .understood
        }
    }

    // MARK: - Choose

    private var chooseView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("What surplus do you have?")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(KnightTheme.ink)
                Text("Describe the real leftover items. You don't need to decide the number of bags.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(KnightTheme.muted)
                    .padding(.bottom, 6)

                BizMethodButton(
                    title: "Speak with AI",
                    subtitle: "Say what's left and when it can be picked up. AI shows what it understood, then proposes the bags.",
                    icon: "mic.fill"
                ) {
                    usingAI = true
                    step = .speak
                }

                BizMethodButton(
                    title: "Enter manually",
                    subtitle: "Type the items and quantities, then set bags, price and pickup time.",
                    icon: "square.and.pencil"
                ) {
                    usingAI = false
                    notes = []
                    heardPrice = nil
                    if inventory.isEmpty {
                        inventory = [SurplusItem(name: "", quantity: 1)]
                    }
                    step = .understood
                }

                Label("Nothing is published until you tap Approve and publish.", systemImage: "checkmark.shield.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(KnightTheme.muted)
                    .padding(.top, 6)
            }
            .padding(KnightTheme.screenPadding)
        }
    }

    // MARK: - Speak

    private var speakView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Tell me what's left")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(KnightTheme.ink)
                Text("Tap the mic and say what's left, when pickup is and the price if you have one. I'll write it down.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(KnightTheme.muted)

                BizVoiceComposer(prompt: "“\(Self.exampleSentence)”", text: $transcript, focus: $dictationFocused, voice: dictation)

                if store.isDemo && transcript.isEmpty && !dictation.isListening {
                    Button {
                        transcript = Self.exampleSentence
                    } label: {
                        BizSecondaryLabel(title: "Use example (demo)", icon: "text.quote")
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    understand()
                } label: {
                    BizPrimaryLabel(title: "Show what you understood", icon: "sparkles")
                }
                .buttonStyle(.plain)
                .disabled(transcriptIsEmpty)
                .opacity(transcriptIsEmpty ? 0.45 : 1)
            }
            .padding(KnightTheme.screenPadding)
        }
    }

    private var transcriptIsEmpty: Bool {
        transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func understand() {
        dictation.stop()
        let result = SurplusAssistant.interpret(transcript)
        inventory = result.inventory
        if let start = result.pickupStart { pickupStart = start }
        if let end = result.pickupEnd { pickupEnd = end }
        heardPrice = result.price
        notes = result.notes
        dictationFocused = false
        step = .understood
    }

    // MARK: - Stage 1: what I understood / inventory

    private var validInventory: [SurplusItem] {
        inventory.filter { $0.quantity > 0 && !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    private var understoodView: some View {
        Form {
            if usingAI {
                Section {
                    Text("“\(transcript)”")
                        .font(.system(size: 14, weight: .medium))
                        .italic()
                        .foregroundStyle(KnightTheme.muted)
                } header: {
                    Text("You said")
                }
            }

            Section {
                ForEach($inventory) { $item in
                    HStack(spacing: 10) {
                        TextField("Item, e.g. Bagels", text: $item.name)
                            .font(.system(size: 16, weight: .semibold))
                        Stepper(value: $item.quantity, in: 1...500) {
                            Text("\(item.quantity)")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .frame(minWidth: 28, alignment: .trailing)
                        }
                        .fixedSize()
                    }
                }
                .onDelete { offsets in
                    inventory.remove(atOffsets: offsets)
                }

                Button {
                    inventory.append(SurplusItem(name: "", quantity: 1))
                } label: {
                    Label("Add item", systemImage: "plus.circle.fill")
                }
            } header: {
                Text(usingAI ? "Surplus items I heard" : "Surplus items")
            } footer: {
                Text("\(validInventory.totalUnits) items in total. Staff only — students never see this list. Swipe left to remove an item.")
            }

            Section {
                DatePicker("Pickup starts", selection: $pickupStart, displayedComponents: .hourAndMinute)
                DatePicker("Pickup ends", selection: $pickupEnd, displayedComponents: .hourAndMinute)
                if let heardPrice {
                    LabeledContent("Price mentioned", value: PickupTime.money(heardPrice))
                }
            } header: {
                Text("Pickup and constraints")
            }

            if usingAI && !notes.isEmpty {
                Section {
                    ForEach(notes, id: \.self) { note in
                        Label(note, systemImage: "exclamationmark.circle")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(KnightTheme.goldDeep)
                    }
                } header: {
                    Text("Missing or uncertain")
                }
            }

            Section {
                if pickupEnd <= pickupStart {
                    Label("Pickup must end after it starts.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(KnightTheme.red)
                }
                Button {
                    confirmInventory()
                } label: {
                    BizPrimaryLabel(title: usingAI ? "Looks right — propose bags" : "Next: plan the bags",
                                    icon: "arrow.right")
                }
                .buttonStyle(.plain)
                .disabled(validInventory.isEmpty || pickupEnd <= pickupStart)
                .opacity(validInventory.isEmpty || pickupEnd <= pickupStart ? 0.45 : 1)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    private func confirmInventory() {
        BizKeyboard.hide()
        let confirmed = validInventory
        store.confirmInventory(confirmed)
        plan = SurplusAssistant.proposePlan(
            inventory: confirmed,
            price: heardPrice,
            pickupStart: pickupStart,
            pickupEnd: pickupEnd,
            createdByAI: usingAI
        )
        step = .plan
    }
}

// MARK: - Stage 2: proposed Surprise Bag plan

struct BagPlanEditor: View {
    @Binding var plan: BagPlan
    let onPublish: () -> Void

    @State private var isPublishing = false

    init(plan: Binding<BagPlan>, onPublish: @escaping () -> Void) {
        _plan = plan
        self.onPublish = onPublish
    }

    var body: some View {
        let allocation = plan.allocation
        let allocatedCount = allocation.bags.reduce(0) { $0 + $1.totalUnits }

        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(plan.bagCount) Surprise Bag\(plan.bagCount == 1 ? "" : "s")")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(KnightTheme.ink)
                    Text("\(PickupTime.money(plan.price)) each · Pickup \(PickupTime.window(plan.pickupStart, plan.pickupEnd))")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(KnightTheme.muted)
                }
                .padding(.vertical, 4)

                Stepper(value: $plan.bagCount, in: 1...max(1, plan.totalItems)) {
                    Text("Surprise Bags: \(plan.bagCount)")
                }
                HStack {
                    Text("Price per bag")
                    Spacer()
                    // "$" sits right next to the number; the field is only as wide as its text.
                    HStack(spacing: 1) {
                        Text("$").foregroundStyle(KnightTheme.muted)
                        BizDecimalField("5.99", value: $plan.price)
                            .fixedSize()
                    }
                }
                DatePicker("Pickup starts", selection: $plan.pickupStart, displayedComponents: .hourAndMinute)
                DatePicker("Pickup ends", selection: $plan.pickupEnd, displayedComponents: .hourAndMinute)
            } header: {
                Text(plan.createdByAI ? "AI proposal — edit anything" : "Your Surprise Bags")
            }

            Section {
                TextField("General description", text: $plan.publicDescription, axis: .vertical)
                    .lineLimit(1...3)
            } header: {
                Text("What students see")
            } footer: {
                Text("Keep it general. Surprise Bags never promise contents, allergens or dietary suitability.")
            }

            Section {
                PickupLocationPicker(selection: $plan.pickupLocation)
            } header: {
                Text("Pickup location")
            } footer: {
                Text("Students see this spot in the bag details.")
            }

            Section {
                Toggle(isOn: $plan.isSurprise) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Surprise Bag")
                        Text(plan.isSurprise ? "Contents stay a secret" : "Rescue Bag · students see what's inside")
                            .font(.system(size: 13))
                            .foregroundStyle(KnightTheme.muted)
                    }
                }
                LabeledContent("Inventory accounted for", value: "\(allocatedCount) of \(plan.totalItems) items")
                ForEach(Array(allocation.bags.enumerated()), id: \.offset) { index, bag in
                    BagLineupRow(index: index, items: bag, isSurprise: plan.isSurprise)
                }
                if !allocation.leftover.isEmpty {
                    Label("Not allocated: \(allocation.leftover.summaryText)", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(KnightTheme.red)
                }
            } header: {
                Text("The lineup · staff only")
            } footer: {
                Text(plan.isSurprise
                     ? "What's inside stays a surprise, even here. Pack the confirmed items across these bags."
                     : "Not a surprise, so each bag's contents are shown here and to students.")
            }

            Section {
                ForEach(plan.problems, id: \.self) { problem in
                    Label(problem, systemImage: "exclamationmark.circle")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(KnightTheme.goldDeep)
                }
                Button {
                    guard !isPublishing else { return }
                    isPublishing = true
                    BizKeyboard.hide()
                    onPublish()
                } label: {
                    BizPrimaryLabel(title: "Approve and publish", icon: "checkmark")
                }
                .buttonStyle(.plain)
                .disabled(!plan.isReady || isPublishing)
                .opacity(plan.isReady ? 1 : 0.45)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            } footer: {
                Text("Publishing updates Explore right away.")
            }
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }
}

/// All campus pickup spots as a tappable checklist, so long names never get cut off.
struct PickupLocationPicker: View {
    @Binding var selection: PickupLocation

    var body: some View {
        Picker("Pickup location", selection: $selection) {
            ForEach(PickupLocation.campusSpots) { spot in
                VStack(alignment: .leading, spacing: 2) {
                    Text(spot.name)
                        .foregroundStyle(KnightTheme.ink)
                    Text(spot.detail)
                        .font(.system(size: 13))
                        .foregroundStyle(KnightTheme.muted)
                }
                .tag(spot)
            }
        }
        .pickerStyle(.inline)
        .labelsHidden()
    }
}

/// One bag in the lineup: Roman numeral, a knight-themed name, and either a
/// sealed "surprise" line or the contents (Rescue Bags only).
struct BagLineupRow: View {
    let index: Int
    let items: [SurplusItem]
    let isSurprise: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(BagName.numeral(index))
                .font(.system(size: 13, weight: .bold, design: .serif))
                .foregroundStyle(KnightTheme.goldDeep)
                .frame(width: 34, height: 34)
                .background(KnightTheme.gold.opacity(0.18), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(BagName.name(index, isSurprise: isSurprise))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(KnightTheme.ink)
                if isSurprise {
                    Label("\(items.totalUnits) item\(items.totalUnits == 1 ? "" : "s"), sealed", systemImage: "lock.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(KnightTheme.muted)
                } else {
                    Text(items.isEmpty ? "Nothing assigned yet" : items.summaryText)
                        .font(.system(size: 13))
                        .foregroundStyle(KnightTheme.muted)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ListSurplusFlow(store: .demo())
}
