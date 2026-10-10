import SwiftUI

/// The review form staff see before a listing is published or changed.
/// Used for manual entry, for checking an AI draft, and for manual edits.
struct ListingFormView: View {
    enum Mode {
        case create
        case edit
    }

    @Binding var draft: ListingDraft
    let mode: Mode
    var aiFilledFields: [String] = []
    var notes: [String] = []
    let onSubmit: () -> Void

    var body: some View {
        Form {
            if !aiFilledFields.isEmpty || !notes.isEmpty {
                Section {
                    if !aiFilledFields.isEmpty {
                        Label("AI filled: \(aiFilledFields.joined(separator: ", "))", systemImage: "sparkles")
                            .font(.subheadline)
                    }
                    ForEach(notes, id: \.self) { note in
                        Text(note)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Check the AI draft")
                }
            }

            Section {
                TextField("Food name", text: $draft.name)
                TextField("Details (optional)", text: $draft.details, axis: .vertical)
                    .lineLimit(1...4)
            } header: {
                Text("Food")
            }

            Section {
                Stepper(value: $draft.quantity, in: 1...999) {
                    Text("Portions: \(draft.quantity)")
                }
                HStack {
                    Text("Price per portion")
                    Spacer()
                    Text("$").foregroundColor(.secondary)
                    BusinessDecimalField(placeholder: "0.00", value: $draft.price)
                        .frame(maxWidth: 90)
                }
                HStack {
                    Text("Normal menu price")
                    Spacer()
                    Text("$").foregroundColor(.secondary)
                    BusinessDecimalField(placeholder: "0.00", value: $draft.originalPrice)
                        .frame(maxWidth: 90)
                }
            } header: {
                Text("Quantity and price")
            } footer: {
                Text("The normal price is used to show how much students save.")
            }

            Section {
                DatePicker("Pickup by", selection: $draft.pickupDeadline, displayedComponents: .hourAndMinute)
            } header: {
                Text("Pickup")
            }

            Section {
                TextField("e.g. Wheat, milk, sesame", text: $draft.allergens, axis: .vertical)
                    .lineLimit(1...3)
                Toggle("Staff confirmed allergen info", isOn: $draft.staffConfirmedAllergens)
                Toggle("Staff confirmed food safety", isOn: $draft.staffConfirmedFoodSafety)
            } header: {
                Text("Allergens and food safety")
            } footer: {
                Text("Only staff fill this in. AI never adds allergens or approves food safety.")
            }

            Section {
                HStack {
                    Text("Weight per portion")
                    Spacer()
                    BusinessDecimalField(placeholder: "0.30", value: $draft.weightPerPortionKg)
                        .frame(maxWidth: 70)
                    Text("kg").foregroundColor(.secondary)
                }
                Toggle("Weighed on a scale", isOn: $draft.weightIsMeasured)
            } header: {
                Text("Food weight")
            } footer: {
                Text(draft.weightIsMeasured
                     ? "Shown as measured weight in the impact report."
                     : "Shown as estimated weight in the impact report.")
            }

            Section {
                ForEach(draft.problems, id: \.self) { problem in
                    Label(problem, systemImage: "exclamationmark.circle")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                }
                Button {
                    BusinessKeyboard.hide()
                    onSubmit()
                } label: {
                    Text(mode == .create ? "Publish listing" : "Save changes")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .disabled(!draft.isReady)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { BusinessKeyboard.hide() }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ListingFormView(draft: .constant(ListingDraft()), mode: .create, onSubmit: {})
            .navigationTitle("New listing")
    }
}
