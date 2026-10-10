import SwiftUI

/// Opened by "+ List surplus". Staff pick AI voice or manual entry,
/// then always review the draft before publishing.
struct ListSurplusFlow: View {
    @ObservedObject var store: BusinessStore
    @Environment(\.dismiss) private var dismiss

    private enum Step {
        case chooseMethod
        case speak
        case review
    }

    @State private var step: Step = .chooseMethod
    @State private var spokenText = ""
    @State private var draft = ListingDraft()
    @State private var aiResult: ListingAssistant.DraftResult?
    @FocusState private var editorFocused: Bool

    init(store: BusinessStore) {
        _store = ObservedObject(wrappedValue: store)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .chooseMethod:
                    chooseMethodView
                case .speak:
                    speakView
                case .review:
                    ListingFormView(
                        draft: $draft,
                        mode: .create,
                        aiFilledFields: aiResult?.filledFields ?? [],
                        notes: aiResult?.notes ?? []
                    ) {
                        store.publish(draft)
                        dismiss()
                    }
                }
            }
            .navigationTitle(title)
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

    private var title: String {
        switch step {
        case .chooseMethod: return "List surplus"
        case .speak: return "Speak with AI"
        case .review: return "Review listing"
        }
    }

    private func goBack() {
        switch step {
        case .chooseMethod: break
        case .speak: step = .chooseMethod
        case .review: step = aiResult == nil ? .chooseMethod : .speak
        }
    }

    // MARK: - Step 1: choose method

    private var chooseMethodView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("How do you want to add this food?")
                    .font(.headline)
                    .padding(.bottom, 4)

                BusinessMethodButton(
                    title: "Speak with AI",
                    subtitle: "Describe the food, quantity, price and pickup time. AI makes a draft you can edit.",
                    systemImage: "mic.fill"
                ) {
                    step = .speak
                }

                BusinessMethodButton(
                    title: "Enter manually",
                    subtitle: "Fill in the short listing form yourself.",
                    systemImage: "square.and.pencil"
                ) {
                    aiResult = nil
                    draft = ListingDraft()
                    step = .review
                }

                Label("Staff always review a listing before students can see it.", systemImage: "checkmark.shield")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.top, 6)
            }
            .padding()
        }
        .background(BusinessTheme.pageBackground.ignoresSafeArea())
    }

    // MARK: - Step 2: speak with AI

    private var speakView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Describe the food")
                .font(.headline)
            Text("Tap the box, then the microphone on the keyboard, and talk. For example: “12 turkey sandwiches for $4, normally $9.49, pickup by 8 PM.”")
                .font(.subheadline)
                .foregroundColor(.secondary)

            TextEditor(text: $spokenText)
                .focused($editorFocused)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 140)
                .padding(8)
                .background(BusinessTheme.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Button {
                let result = ListingAssistant.makeDraft(from: spokenText)
                aiResult = result
                draft = result.draft
                editorFocused = false
                step = .review
            } label: {
                Label("Create draft", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(BusinessTheme.gold, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(spokenText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(spokenText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)

            Spacer()
        }
        .padding()
        .background(BusinessTheme.pageBackground.ignoresSafeArea())
        .onAppear { editorFocused = true }
    }
}

#Preview {
    ListSurplusFlow(store: .demo())
}
