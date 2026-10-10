import SwiftUI

/// Opened by "Edit listing". Staff edit by voice (AI proposes changes, staff approve)
/// or manually in the form.
struct EditListingFlow: View {
    @ObservedObject var store: BusinessStore
    let listing: Listing
    @Environment(\.dismiss) private var dismiss

    private enum Step {
        case chooseMethod
        case voice
        case proposal
        case manual
    }

    @State private var step: Step = .chooseMethod
    @State private var instruction = ""
    @State private var proposal: ListingAssistant.EditProposal?
    @State private var draft: ListingDraft
    @FocusState private var editorFocused: Bool

    init(store: BusinessStore, listing: Listing) {
        _store = ObservedObject(wrappedValue: store)
        self.listing = listing
        _draft = State(initialValue: ListingDraft(listing: listing))
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .chooseMethod:
                    chooseMethodView
                case .voice:
                    voiceView
                case .proposal:
                    proposalView
                case .manual:
                    ListingFormView(draft: $draft, mode: .edit) {
                        store.update(listingID: listing.id, with: draft)
                        dismiss()
                    }
                }
            }
            .navigationTitle(listing.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if step == .chooseMethod {
                        Button("Cancel") { dismiss() }
                    } else {
                        Button {
                            goBack()
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                        }
                    }
                }
            }
        }
    }

    private func goBack() {
        switch step {
        case .chooseMethod: break
        case .voice: step = .chooseMethod
        case .proposal: step = .voice
        case .manual: step = proposal == nil ? .chooseMethod : .proposal
        }
    }

    // MARK: - Choose method

    private var chooseMethodView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("How do you want to edit this listing?")
                    .font(.headline)
                    .padding(.bottom, 4)

                BusinessMethodButton(
                    title: "Edit with voice",
                    subtitle: "Say what to change. AI shows the changes and you approve them.",
                    systemImage: "mic.fill"
                ) {
                    step = .voice
                }

                BusinessMethodButton(
                    title: "Edit manually",
                    subtitle: "Change quantity, price, food details or pickup time in the form.",
                    systemImage: "square.and.pencil"
                ) {
                    proposal = nil
                    draft = ListingDraft(listing: listing)
                    step = .manual
                }
            }
            .padding()
        }
        .background(BusinessTheme.pageBackground.ignoresSafeArea())
    }

    // MARK: - Voice

    private var voiceView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What should change?")
                .font(.headline)
            Text("Tap the box, then the microphone on the keyboard. For example: “Change to six portions and move pickup to 7:30.”")
                .font(.subheadline)
                .foregroundColor(.secondary)

            TextEditor(text: $instruction)
                .focused($editorFocused)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 120)
                .padding(8)
                .background(BusinessTheme.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Button {
                proposal = ListingAssistant.proposeEdit(for: listing, instruction: instruction)
                editorFocused = false
                step = .proposal
            } label: {
                Label("Show proposed changes", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(BusinessTheme.gold, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(instructionIsEmpty)
            .opacity(instructionIsEmpty ? 0.5 : 1)

            Spacer()
        }
        .padding()
        .background(BusinessTheme.pageBackground.ignoresSafeArea())
        .onAppear { editorFocused = true }
    }

    private var instructionIsEmpty: Bool {
        instruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Proposal (staff approve before anything changes)

    @ViewBuilder
    private var proposalView: some View {
        if let proposal = proposal {
            List {
                Section {
                    Text(instruction)
                        .italic()
                } header: {
                    Text("You said")
                }

                if !proposal.changes.isEmpty {
                    Section {
                        ForEach(proposal.changes) { change in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(change.field)
                                    .font(.subheadline.weight(.semibold))
                                HStack(spacing: 8) {
                                    Text(change.oldValue)
                                        .strikethrough()
                                        .foregroundColor(.secondary)
                                    Image(systemName: "arrow.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(change.newValue)
                                        .fontWeight(.semibold)
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
                                .font(.footnote)
                        }
                    }
                }

                Section {
                    Button {
                        apply(proposal)
                    } label: {
                        Text("Approve and update")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(proposal.changes.isEmpty)

                    Button("Edit manually instead") {
                        draft = proposal.draft
                        step = .manual
                    }

                    Button("Try again") {
                        step = .voice
                    }
                }
            }
        } else {
            Text("Nothing to review yet.")
                .foregroundColor(.secondary)
        }
    }

    private func apply(_ proposal: ListingAssistant.EditProposal) {
        let hasFieldChanges = proposal.changes.contains { $0.field != "Status" }
        if hasFieldChanges {
            store.update(listingID: listing.id, with: proposal.draft)
        }
        switch proposal.statusAction {
        case .pause:
            store.setPaused(true, listingID: listing.id)
        case .resume:
            store.setPaused(false, listingID: listing.id)
        case .close:
            store.close(listingID: listing.id)
        case nil:
            break
        }
        dismiss()
    }
}

#Preview {
    let store = BusinessStore.demo()
    return EditListingFlow(store: store, listing: store.listings[0])
}
