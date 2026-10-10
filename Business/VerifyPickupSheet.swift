import SwiftUI

/// Staff check the student's QR pickup pass, then capture the payment.
/// For the hackathon, staff compare the code printed under the QR.
/// A camera scanner can replace the text field later.
struct VerifyPickupSheet: View {
    @ObservedObject var store: BusinessStore
    let reservation: Reservation
    @Environment(\.dismiss) private var dismiss
    @State private var enteredCode = ""

    init(store: BusinessStore, reservation: Reservation) {
        _store = ObservedObject(wrappedValue: store)
        self.reservation = reservation
    }

    /// Accepts "KS-4821", "ks 4821" or just "4821".
    private var codeMatches: Bool {
        let entered = enteredCode.filter { $0.isNumber }
        let expected = reservation.code.filter { $0.isNumber }
        return !entered.isEmpty && entered == expected
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Student", value: reservation.studentName)
                    LabeledContent("Item", value: "\(reservation.quantity) × \(reservation.itemName)")
                    LabeledContent("Pickup by", value: ListingAssistant.time(reservation.pickupDeadline))
                    LabeledContent("Total", value: ListingAssistant.money(reservation.total))
                    LabeledContent("Payment", value: reservation.payment.label)
                } header: {
                    Text("Reservation")
                }

                Section {
                    TextField("Code under the QR, e.g. KS-4821", text: $enteredCode)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    if !enteredCode.isEmpty && !codeMatches {
                        Label("This code doesn't match the reservation.", systemImage: "xmark.octagon")
                            .foregroundColor(.red)
                    } else if codeMatches {
                        Label("Code matches.", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                    if store.isDemo {
                        Button("Fill in code (demo)") {
                            enteredCode = reservation.code
                        }
                    }
                } header: {
                    Text("Check the QR pickup pass")
                }

                Section {
                    Button {
                        store.verifyPickup(reservationID: reservation.id)
                        dismiss()
                    } label: {
                        Text("Verify pickup and capture payment")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!codeMatches)
                } footer: {
                    Text("The payment is only charged after this step. The pickup then moves to Today's rescues and the impact report updates.")
                }
            }
            .navigationTitle("Verify pickup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    let store = BusinessStore.demo()
    return VerifyPickupSheet(store: store, reservation: store.reservations[0])
}
