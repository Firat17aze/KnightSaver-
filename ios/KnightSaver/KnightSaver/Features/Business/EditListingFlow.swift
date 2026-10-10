import SwiftUI

/// "Edit listing": by voice (AI proposes changes, staff approve) or manually.
struct EditListingFlow: View {
    @ObservedObject var store: BusinessStore
    let listing: BusinessListing
    @Environment(\.dismiss) private var dismiss

    private enum Step {
        case choose
        case voice
        case proposal
        case manual
    }

    @State private var step: Step = .choose
    @State private var instruction = ""
    @State private var proposal: ListingEditProposal?
    @State private var remaining: Int
    @State private var price: Double
    @State private var pickupStart: Date
    @State private var pickupEnd: Date
    @State private var publicDescription: String
    @State private var pickupLocation: PickupLocation
    @FocusState private var dictationFocused: Bool
    @StateObject private var dictation = VoiceDictation()

    static let exampleInstruction = "Change the quantity to six bags and move pickup to 7:15–7:45 PM."

    init(store: BusinessStore, listing: BusinessListing) {
        _store = ObservedObject(wrappedValue: store)
        self.listing = listing
        _remaining = State(initialValue: listing.remainingQuantity)
        _price = State(initialValue: listing.price)
        _pickupStart = State(initialValue: listing.pickupStart)
        _pickupEnd = State(initialValue: listing.pickupEnd)
        _publicDescription = State(initialValue: listing.publicDescription)
        _pickupLocation = State(initialValue: PickupLocation.matching(listing.pickupAddress))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .choose: chooseView
                case .voice: voiceView
                case .proposal: proposalView
                case .manual: manualView
                }
            }
            .background(KnightTheme.paper)
            .navigationTitle("Edit Surprise Bag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if step == .choose {
                        Button("Cancel") { dismiss() }
                    } else {
                        Button {
                            switch step {
                            case .choose: break
                            case .voice, .manual:
                                dictation.stop()
                                step = .choose
                            case .proposal: step = .voice
                            }
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

    // MARK: - Choose

    private var chooseView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(listing.label) · \(PickupTime.money(listing.price))")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(KnightTheme.ink)
                    Text("Pickup \(listing.pickupWindowText) · \(listing.remainingQuantity) of \(listing.totalQuantity) left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(KnightTheme.muted)
                }
                .padding(.bottom, 6)

                BizMethodButton(
                    title: "Edit with voice",
                    subtitle: "Say what to change. You'll see the proposed changes before anything goes live.",
                    icon: "mic.fill"
                ) {
                    step = .voice
                }

                BizMethodButton(
                    title: "Edit manually",
                    subtitle: "Change bags available, price, pickup time or description.",
                    icon: "square.and.pencil"
                ) {
                    step = .manual
                }
            }
            .padding(KnightTheme.screenPadding)
        }
    }

    // MARK: - Voice

    private var voiceView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("What should change?")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(KnightTheme.ink)
                Text("Tap the mic and say what to change: bags, price, pickup time or spot.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(KnightTheme.muted)

                BizVoiceComposer(prompt: "“\(Self.exampleInstruction)”", text: $instruction, focus: $dictationFocused, voice: dictation)

                if store.isDemo && instruction.isEmpty && !dictation.isListening {
                    Button {
                        instruction = Self.exampleInstruction
                    } label: {
                        BizSecondaryLabel(title: "Use example (demo)", icon: "text.quote")
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    dictation.stop()
                    proposal = SurplusAssistant.proposeEdit(for: listing, instruction: instruction)
                    dictationFocused = false
                    step = .proposal
                } label: {
                    BizPrimaryLabel(title: "Show proposed changes", icon: "sparkles")
                }
                .buttonStyle(.plain)
                .disabled(instructionIsEmpty)
                .opacity(instructionIsEmpty ? 0.45 : 1)
            }
            .padding(KnightTheme.screenPadding)
        }
    }

    private var instructionIsEmpty: Bool {
        instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Proposal

    @ViewBuilder
    private var proposalView: some View {
        if let proposal {
            Form {
                Section {
                    Text("“\(instruction)”")
                        .font(.system(size: 14, weight: .medium))
                        .italic()
                        .foregroundStyle(KnightTheme.muted)
                } header: {
                    Text("You said")
                }

                if !proposal.changes.isEmpty {
                    Section {
                        ForEach(proposal.changes) { change in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(change.field)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(KnightTheme.muted)
                                HStack(spacing: 8) {
                                    Text(change.oldValue)
                                        .strikethrough()
                                        .foregroundStyle(KnightTheme.muted)
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(KnightTheme.goldDeep)
                                    Text(change.newValue)
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundStyle(KnightTheme.ink)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    } header: {
                        Text("Proposed changes")
                    } footer: {
                        Text("Nothing changes until you approve.")
                    }
                }

                if !proposal.notes.isEmpty {
                    Section {
                        ForEach(proposal.notes, id: \.self) { note in
                            Label(note, systemImage: "info.circle")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(KnightTheme.goldDeep)
                        }
                    }
                }

                Section {
                    Button {
                        approve(proposal)
                    } label: {
                        BizPrimaryLabel(title: "Approve changes", icon: "checkmark")
                    }
                    .buttonStyle(.plain)
                    .disabled(proposal.changes.isEmpty)
                    .opacity(proposal.changes.isEmpty ? 0.45 : 1)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())

                    Button("Edit manually instead") {
                        if let value = proposal.remainingQuantity { remaining = value }
                        if let value = proposal.price { price = value }
                        if let value = proposal.pickupStart { pickupStart = value }
                        if let value = proposal.pickupEnd { pickupEnd = value }
                        step = .manual
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
    }

    private func approve(_ proposal: ListingEditProposal) {
        let hasFieldChanges = proposal.remainingQuantity != nil || proposal.price != nil || proposal.pickupStart != nil
        if hasFieldChanges {
            store.applyEdit(
                listingID: listing.id,
                remaining: proposal.remainingQuantity,
                price: proposal.price,
                pickupStart: proposal.pickupStart,
                pickupEnd: proposal.pickupEnd
            )
        }
        if let action = proposal.stateAction {
            store.apply(action, listingID: listing.id)
        }
        dismiss()
    }

    // MARK: - Manual

    private var manualView: some View {
        Form {
            Section {
                Stepper(value: $remaining, in: 0...500) {
                    Text("Bags available: \(remaining)")
                }
                HStack {
                    Text("Price per bag")
                    Spacer()
                    // "$" sits right next to the number; the field is only as wide as its text.
                    HStack(spacing: 1) {
                        Text("$").foregroundStyle(KnightTheme.muted)
                        BizDecimalField("5.99", value: $price)
                            .fixedSize()
                    }
                }
                DatePicker("Pickup starts", selection: $pickupStart, displayedComponents: .hourAndMinute)
                DatePicker("Pickup ends", selection: $pickupEnd, displayedComponents: .hourAndMinute)
            } header: {
                Text("Listing")
            } footer: {
                Text("Reserved bags stay reserved. Changing bags available only changes what students can still reserve.")
            }

            Section {
                PickupLocationPicker(selection: $pickupLocation)
            } header: {
                Text("Pickup location")
            }

            Section {
                TextField("General description", text: $publicDescription, axis: .vertical)
                    .lineLimit(1...3)
            } header: {
                Text("What students see")
            } footer: {
                Text("Keep it general. Never promise contents, allergens or dietary suitability.")
            }

            Section {
                if pickupEnd <= pickupStart {
                    Label("Pickup must end after it starts.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(KnightTheme.red)
                }
                Button {
                    BizKeyboard.hide()
                    store.applyEdit(
                        listingID: listing.id,
                        remaining: remaining,
                        price: price,
                        pickupStart: pickupStart,
                        pickupEnd: pickupEnd,
                        description: publicDescription,
                        location: pickupLocation
                    )
                    dismiss()
                } label: {
                    BizPrimaryLabel(title: "Save changes", icon: "checkmark")
                }
                .buttonStyle(.plain)
                .disabled(pickupEnd <= pickupStart)
                .opacity(pickupEnd <= pickupStart ? 0.45 : 1)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }
}

#Preview {
    let store = BusinessStore.demo()
    return EditListingFlow(store: store, listing: store.listings[0])
}
