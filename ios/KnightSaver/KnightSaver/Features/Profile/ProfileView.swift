import SwiftUI
import CoreLocation
import UIKit
import PhotosUI

private enum ProfileRoute: Hashable {
    case reservation(UUID)
    case pickupHistory
    case personalInformation
    case notifications
    case pickupPreferences
    case howItWorks
    case cancellationPolicy
    case help
    case legal
}

struct ProfileView: View {
    let account: AppAccount
    let pass: KnightPass
    @Binding var activeReservations: [ActiveReservation]
    let action: () -> Void
    let onUpdateProfile: (String, String, String, String) -> String?
    let onSignOut: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Shared with Business: reservations, waitlist offers and verified pickups.
    @EnvironmentObject var businessStore: BusinessStore

    /// This student's reservations from the shared store, then sample-restaurant ones.
    private var allReservations: [ActiveReservation] {
        businessStore.studentReservations(passToken: pass.verificationToken) + activeReservations
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 12) {
                        KnightSaverBrandBar { ThemeToggleButton() }
                        profileHeader
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        ProfileSectionHeader(
                            title: "Knight Pass",
                            subtitle: "Your reusable pass for every pickup"
                        )
                        KnightPassButton(pass: pass, action: action)
                    }

                    pickupsSection

                    ProfileLinkGroup(
                        title: "Account",
                        rows: [
                            ProfileLinkItem(route: .personalInformation, title: "Personal information", icon: "person.crop.circle"),
                            ProfileLinkItem(route: .notifications, title: "Notification settings", icon: "bell"),
                            ProfileLinkItem(route: .pickupPreferences, title: "Pickup preferences", icon: "slider.horizontal.3"),
                            ProfileLinkItem(route: .pickupHistory, title: "Pickup history", icon: "clock.arrow.circlepath")
                        ]
                    )

                    ProfileLinkGroup(
                        title: "Help",
                        rows: [
                            ProfileLinkItem(route: .howItWorks, title: "How KnightSaver works", icon: "questionmark.circle"),
                            ProfileLinkItem(route: .cancellationPolicy, title: "Cancellation policy", icon: "calendar.badge.exclamationmark"),
                            ProfileLinkItem(route: .help, title: "Help and support", icon: "message"),
                            ProfileLinkItem(route: .legal, title: "Privacy and terms", icon: "lock.shield")
                        ]
                    )

                    SignOutButton(onSignOut: onSignOut)
                }
                .padding(.horizontal, KnightTheme.screenPadding)
                .padding(.top, 16)
                .padding(.bottom, 34)
            }
            .scrollIndicators(.hidden)
            .reservesTabBarSpace()
            .background(KnightTheme.paper)
            .navigationBarHidden(true)
            .navigationDestination(for: ProfileRoute.self) { route in
                destination(for: route)
                    .reservesTabBarSpace()
            }
        }
    }

    private var profileHeader: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Profile")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(KnightTheme.ink)

            HStack(spacing: 14) {
                ProfileAvatar(accountID: account.id, size: 68)

                VStack(alignment: .leading, spacing: 4) {
                    Text(account.displayName)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(KnightTheme.ink)
                    Text(account.email)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(KnightTheme.muted)
                    Text(pass.memberID)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(KnightTheme.muted)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var pickupsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProfileSectionHeader(
                title: "My pickups",
                subtitle: allReservations.isEmpty ? "No upcoming pickups" : "Your next reservation"
            )

            if let reservation = allReservations.first {
                NavigationLink(value: ProfileRoute.reservation(reservation.id)) {
                    UpcomingPickupCard(reservation: reservation)
                }
                .buttonStyle(PressScaleButtonStyle(reduceMotion: reduceMotion))
            } else {
                EmptyPickupCard()
            }
        }
    }

    @ViewBuilder
    private func destination(for route: ProfileRoute) -> some View {
        switch route {
        case .reservation(let id):
            if let reservation = allReservations.first(where: { $0.id == id }) {
                ReservationDetailsView(reservation: reservation) {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                        if businessStore.isStoreReservation(id: id) {
                            // Releases the payment hold and frees the bag or offers it to the waitlist.
                            businessStore.cancelReservation(id: id)
                        } else {
                            activeReservations.removeAll { $0.id == id }
                        }
                    }
                }
            } else {
                MissingReservationView()
            }
        case .pickupHistory:
            PickupHistoryView()
        case .personalInformation:
            PersonalInformationView(account: account, pass: pass, onSave: onUpdateProfile)
        case .notifications:
            NotificationSettingsView()
        case .pickupPreferences:
            PickupPreferencesView()
        case .howItWorks:
            ProfileArticleView(
                title: "How KnightSaver works",
                icon: "takeoutbag.and.cup.and.straw",
                sections: [
                    ProfileArticleSection(title: "Reserve", body: "Choose an available Surprise Bag and authorize payment. Its exact contents stay a surprise until pickup."),
                    ProfileArticleSection(title: "Pick up", body: "Visit the listed campus location during its pickup window and show staff your reusable Knight Pass."),
                    ProfileArticleSection(title: "Verify", body: "Payment, impact, and feedback eligibility update only after staff verifies your pickup.")
                ]
            )
        case .cancellationPolicy:
            ProfileArticleView(
                title: "Cancellation policy",
                icon: "calendar.badge.exclamationmark",
                sections: [
                    ProfileArticleSection(title: "Before pickup", body: "You can cancel from the reservation details screen. Any payment authorization is released according to the business’s cancellation window."),
                    ProfileArticleSection(title: "Late cancellations", body: "The final policy and cutoff must be shown before a reservation is confirmed. This demo does not charge cancellation fees."),
                    ProfileArticleSection(title: "After cancellation", body: "The bag returns to live availability when the listing and pickup window are still active.")
                ]
            )
        case .help:
            ProfileArticleView(
                title: "Help and support",
                icon: "message",
                sections: [
                    ProfileArticleSection(title: "Pickup issue", body: "Open your active reservation first to confirm the location, pickup window, and payment status."),
                    ProfileArticleSection(title: "Pass issue", body: "Your Knight Pass is reusable. Close and reopen it to refresh the verification screen."),
                    ProfileArticleSection(title: "Contact support", body: "In-app support messaging will be connected before launch.")
                ]
            )
        case .legal:
            ProfileArticleView(
                title: "Privacy and terms",
                icon: "lock.shield",
                sections: [
                    ProfileArticleSection(title: "Privacy", body: "KnightSaver should collect only the account, reservation, payment, and verification data needed to operate the service."),
                    ProfileArticleSection(title: "Knight Pass", body: "The pass uses a renewable verification token and must not expose a raw student identifier or reservation details."),
                    ProfileArticleSection(title: "Terms", body: "Final privacy notices and service terms will be published before launch.")
                ]
            )
        }
    }
}

private struct ProfileSectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(KnightTheme.ink)
            Text(subtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(KnightTheme.muted)
        }
    }
}

private struct UpcomingPickupCard: View {
    let reservation: ActiveReservation

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Upcoming pickup")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(KnightTheme.muted)
                    Text(reservation.bag.business)
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(KnightTheme.ink)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Text(reservation.status.rawValue)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(KnightTheme.green)
                    .padding(.horizontal, 9)
                    .frame(minHeight: 28)
                    .background(KnightTheme.green.opacity(0.1), in: Capsule())
            }

            VStack(spacing: 10) {
                PickupMetadataRow(icon: "clock.fill", text: "Today · \(reservation.bag.pickupWindow)")
                PickupMetadataRow(icon: "mappin.and.ellipse", text: reservation.bag.location)
            }

            Divider().overlay(KnightTheme.line)

            HStack {
                Text("Manage reservation")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(KnightTheme.ink)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(KnightTheme.muted)
                    .accessibilityHidden(true)
            }
        }
        .padding(17)
        .background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: KnightTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: KnightTheme.cardRadius, style: .continuous)
                .stroke(KnightTheme.ink.opacity(0.07), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens reservation details")
    }
}

private struct PickupMetadataRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(KnightTheme.lake)
                .frame(width: 22)
                .accessibilityHidden(true)
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(KnightTheme.muted)
            Spacer(minLength: 0)
        }
    }
}

private struct EmptyPickupCard: View {
    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(KnightTheme.muted)
                .frame(width: 44, height: 44)
                .background(KnightTheme.wash, in: RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text("No upcoming pickups")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(KnightTheme.ink)
                Text("Your next reservation will appear here.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(KnightTheme.muted)
            }

            Spacer(minLength: 0)
        }
        .padding(15)
        .background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(KnightTheme.line, lineWidth: 1)
        }
    }
}

private struct ProfileLinkItem: Identifiable {
    let route: ProfileRoute
    let title: String
    let icon: String

    var id: ProfileRoute { route }
}

private struct ProfileLinkGroup: View {
    let title: String
    let rows: [ProfileLinkItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(KnightTheme.ink)

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    NavigationLink(value: row.route) {
                        ProfileRow(title: row.title, icon: row.icon)
                    }
                    .buttonStyle(.plain)

                    if index < rows.count - 1 {
                        Divider()
                            .overlay(KnightTheme.line)
                            .padding(.leading, 58)
                    }
                }
            }
            .background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(KnightTheme.ink.opacity(0.06), lineWidth: 1)
            }
        }
    }
}

private struct ProfileRow: View {
    let title: String
    var subtitle: String? = nil
    let icon: String

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(KnightTheme.muted)
                .frame(width: 34, height: 34)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(KnightTheme.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(KnightTheme.muted)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(KnightTheme.muted)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: subtitle == nil ? 56 : 64)
        .contentShape(Rectangle())
    }
}

private struct ReservationDetailsView: View {
    let reservation: ActiveReservation
    let onCancel: () -> Void

    @State private var confirmCancellation = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top, spacing: 14) {
                    BrandMark(brand: reservation.bag.brand, size: 58)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(reservation.bag.business)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(KnightTheme.ink)
                        Text("Surprise Bag · \(reservation.bag.formattedPrice)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(KnightTheme.muted)
                    }

                    Spacer(minLength: 8)
                }

                DetailCard(title: "Pickup details") {
                    DetailLine(icon: "clock.fill", label: "Time", value: "Today · \(reservation.bag.pickupWindow)")
                    DetailLine(icon: "mappin.and.ellipse", label: "Location", value: reservation.bag.location)
                    DetailLine(icon: "checkmark.seal.fill", label: "Status", value: reservation.status.rawValue)
                }

                Button {
                    openDirections()
                } label: {
                    Label("Open directions", systemImage: "location.fill")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(KnightTheme.onAccent)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(KnightTheme.gold, in: RoundedRectangle(cornerRadius: KnightTheme.controlRadius, style: .continuous))
                }
                .buttonStyle(.plain)

                HStack(alignment: .top, spacing: 11) {
                    Image(systemName: "qrcode")
                        .foregroundStyle(KnightTheme.lake)
                        .accessibilityHidden(true)
                    Text("Use the reusable Knight Pass at the top of Profile when staff verifies your pickup.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(KnightTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .background(KnightTheme.lake.opacity(0.09), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                if reservation.status != .verified {
                    Button(role: .destructive) {
                        confirmCancellation = true
                    } label: {
                        Label("Cancel reservation", systemImage: "xmark.circle")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(KnightTheme.red)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: KnightTheme.controlRadius, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: KnightTheme.controlRadius, style: .continuous)
                                    .stroke(KnightTheme.red.opacity(0.28), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(KnightTheme.screenPadding)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(KnightTheme.paper)
        .navigationTitle("Manage reservation")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Cancel this reservation?", isPresented: $confirmCancellation, titleVisibility: .visible) {
            Button("Cancel reservation", role: .destructive) {
                onCancel()
                dismiss()
            }
            Button("Keep reservation", role: .cancel) { }
        } message: {
            Text("The payment authorization will be released according to the cancellation policy.")
        }
    }

    private func openDirections() {
        let query = reservation.bag.location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "http://maps.apple.com/?q=\(query)") {
            openURL(url)
        }
    }
}

private struct DetailCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(KnightTheme.ink)
            content
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(KnightTheme.ink.opacity(0.06), lineWidth: 1)
        }
    }
}

private struct DetailLine: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(KnightTheme.lake)
                .frame(width: 22)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(KnightTheme.muted)
                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(KnightTheme.ink)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct MissingReservationView: View {
    var body: some View {
        ContentUnavailableView(
            "Reservation unavailable",
            systemImage: "calendar.badge.exclamationmark",
            description: Text("This reservation is no longer active.")
        )
        .navigationTitle("Manage reservation")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PickupHistoryView: View {
    var body: some View {
        ContentUnavailableView(
            "No pickup history yet",
            systemImage: "clock.arrow.circlepath",
            description: Text("Completed and cancelled pickups will appear here.")
        )
        .navigationTitle("Pickup history")
        .navigationBarTitleDisplayMode(.inline)
        .background(KnightTheme.paper)
    }
}

private enum PersonalInfoField: Hashable {
    case name
    case email
    case phone
}

private struct PersonalInformationView: View {
    let account: AppAccount
    let pass: KnightPass
    let onSave: (String, String, String, String) -> String?

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var email: String
    @State private var phone: String
    @State private var campus: String
    @State private var validationMessage: String?
    @State private var editingField: PersonalInfoField?
    @FocusState private var focusedField: PersonalInfoField?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let campuses = [
        "UCF Main Campus",
        "UCF Downtown",
        "Health Sciences Campus",
        "Rosen College"
    ]

    init(
        account: AppAccount,
        pass: KnightPass,
        onSave: @escaping (String, String, String, String) -> String?
    ) {
        self.account = account
        self.pass = pass
        self.onSave = onSave
        _name = State(initialValue: account.displayName)
        _email = State(initialValue: account.email)
        _phone = State(initialValue: account.phoneNumber ?? "")
        _campus = State(initialValue: account.campusName ?? pass.campusName)
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    ProfileAvatar(accountID: account.id, size: 60)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(name.isEmpty ? "Your profile" : name)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(KnightTheme.ink)
                        Text("Tap your photo to change it. Edit the information businesses use for pickups.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(KnightTheme.muted)
                    }
                }
                .padding(.vertical, 5)
            }

            Section {
                editableContactRow(
                    title: "Full name",
                    field: .name,
                    text: $name,
                    placeholder: "Name",
                    keyboard: .default
                )

                editableContactRow(
                    title: "Email",
                    field: .email,
                    text: $email,
                    placeholder: "Email",
                    keyboard: .emailAddress
                )

                editableContactRow(
                    title: "Phone",
                    field: .phone,
                    text: $phone,
                    placeholder: "Not provided",
                    keyboard: .phonePad
                )
            } header: {
                Text("Contact information")
            } footer: {
                Text("Tap a pencil to unlock that field, then save your changes.")
            }

            Section("University") {
                Picker("Campus", selection: $campus) {
                    ForEach(campuses, id: \.self) { campus in
                        Text(campus).tag(campus)
                    }
                }

                LabeledContent("Account type", value: account.role.rawValue)
            }

            Section {
                LabeledContent("Member ID", value: pass.memberID)
                    .textSelection(.enabled)
            } header: {
                Text("Account")
            } footer: {
                Text("Your member ID is created by KnightSaver and can’t be edited.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(KnightTheme.paper)
        .navigationTitle("Personal information")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save", action: save)
                    .fontWeight(.semibold)
                    .disabled(!hasChanges)
            }
        }
        .alert("Unable to save", isPresented: validationAlert) {
            Button("OK", role: .cancel) { validationMessage = nil }
        } message: {
            Text(validationMessage ?? "Check your information and try again.")
        }
    }

    @ViewBuilder
    private func editableContactRow(
        title: String,
        field: PersonalInfoField,
        text: Binding<String>,
        placeholder: String,
        keyboard: UIKeyboardType
    ) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .foregroundStyle(KnightTheme.ink)

            Spacer(minLength: 12)

            if editingField == field {
                TextField(placeholder, text: text)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(keyboard)
                    .textContentType(contentType(for: field))
                    .textInputAutocapitalization(field == .email ? .never : .words)
                    .autocorrectionDisabled(field != .name)
                    .focused($focusedField, equals: field)
                    .submitLabel(.done)
                    .onSubmit { finishEditing(field) }
                    .transition(.opacity)
            } else {
                Text(text.wrappedValue.isEmpty ? placeholder : text.wrappedValue)
                    .foregroundStyle(KnightTheme.muted)
                    .lineLimit(1)
                    .transition(.opacity)
            }

            Button {
                if editingField == field {
                    finishEditing(field)
                } else {
                    beginEditing(field)
                }
            } label: {
                Image(systemName: editingField == field ? "checkmark" : "pencil")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(editingField == field ? KnightTheme.onAccent : KnightTheme.muted)
                    .frame(width: 34, height: 34)
                    .background(
                        editingField == field ? KnightTheme.gold : KnightTheme.wash,
                        in: Circle()
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(editingField == field ? "Finish editing \(title)" : "Edit \(title)")
        }
        .frame(minHeight: 44)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: editingField)
    }

    private func contentType(for field: PersonalInfoField) -> UITextContentType? {
        switch field {
        case .name: .name
        case .email: .emailAddress
        case .phone: .telephoneNumber
        }
    }

    private func beginEditing(_ field: PersonalInfoField) {
        editingField = field
        DispatchQueue.main.async {
            focusedField = field
        }
    }

    private func finishEditing(_ field: PersonalInfoField) {
        guard editingField == field else { return }
        focusedField = nil
        editingField = nil
    }

    private var hasChanges: Bool {
        name != account.displayName
            || email != account.email
            || phone != (account.phoneNumber ?? "")
            || campus != (account.campusName ?? pass.campusName)
    }

    private var validationAlert: Binding<Bool> {
        Binding(
            get: { validationMessage != nil },
            set: { if !$0 { validationMessage = nil } }
        )
    }

    private func save() {
        focusedField = nil
        editingField = nil
        if let error = onSave(name, email, phone, campus) {
            validationMessage = error
        } else {
            dismiss()
        }
    }
}

private struct NotificationSettingsView: View {
    @State private var pickupReminders = true
    @State private var waitlistOffers = true
    @State private var reservationUpdates = true

    var body: some View {
        Form {
            Section("Reservations") {
                Toggle("Pickup reminders", isOn: $pickupReminders)
                Toggle("Waitlist offers", isOn: $waitlistOffers)
                Toggle("Reservation updates", isOn: $reservationUpdates)
            }
        }
        .scrollContentBackground(.hidden)
        .background(KnightTheme.paper)
        .tint(KnightTheme.green)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}

final class PickupLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var accuracyAuthorization: CLAccuracyAuthorization
    @Published private(set) var isLocating = false
    @Published private(set) var hasCurrentLocation = false
    @Published private(set) var currentLocation: CLLocation?
    @Published private(set) var currentLocationLabel: String?
    @Published var errorMessage: String?

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var hasPendingRequest = false
    private var requestStartedAt: Date?
    private var bestLocation: CLLocation?
    private var timeoutWorkItem: DispatchWorkItem?
    private var isQuietRefresh = false

    override init() {
        authorizationStatus = manager.authorizationStatus
        accuracyAuthorization = manager.accuracyAuthorization
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = kCLDistanceFilterNone
    }

    /// Quietly refreshes the saved location when permission is already granted.
    /// Never prompts and never shows an error; used when Explore opens.
    func refreshIfAuthorized() {
        guard !hasPendingRequest else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            hasCurrentLocation = false
            hasPendingRequest = true
            isQuietRefresh = true
            requestLocationUpdate()
        default:
            break
        }
    }

    func requestCurrentLocation() {
        isQuietRefresh = false
        errorMessage = nil
        hasCurrentLocation = false
        currentLocation = nil
        currentLocationLabel = nil
        hasPendingRequest = true

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            requestLocationUpdate()
        case .denied:
            hasPendingRequest = false
            errorMessage = "Location access is turned off. Enable it in Settings to use your current location."
        case .restricted:
            hasPendingRequest = false
            errorMessage = "Location access is restricted on this device. Choose a UCF campus instead."
        @unknown default:
            hasPendingRequest = false
            errorMessage = "Your location is unavailable right now. Choose a UCF campus instead."
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        accuracyAuthorization = manager.accuracyAuthorization

        guard hasPendingRequest else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            requestLocationUpdate()
        case .denied:
            hasPendingRequest = false
            errorMessage = "Location access is turned off. Enable it in Settings to use your current location."
        case .restricted:
            hasPendingRequest = false
            errorMessage = "Location access is restricted on this device. Choose a UCF campus instead."
        case .notDetermined:
            break
        @unknown default:
            hasPendingRequest = false
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard hasPendingRequest else { return }
        // Core Location often supplies a recent high-quality cached fix first. Accept up to
        // 15 seconds of cache rather than discarding an accurate result and timing out.
        let earliestAllowedDate = requestStartedAt?.addingTimeInterval(-15) ?? .distantPast
        let candidates = locations.filter {
            $0.horizontalAccuracy >= 0 && $0.timestamp >= earliestAllowedDate
        }
        guard !candidates.isEmpty else { return }

        for location in candidates {
            if bestLocation == nil || location.horizontalAccuracy < bestLocation!.horizontalAccuracy {
                bestLocation = location
            }
        }

        guard let bestLocation else { return }
        if bestLocation.horizontalAccuracy <= 75 {
            finish(using: bestLocation)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let code = (error as? CLError)?.code
        if code == .locationUnknown, hasPendingRequest {
            return
        }
        finishWithError("We couldn’t find your location. Try again outdoors or choose a UCF campus.")
    }

    private func requestLocationUpdate() {
        timeoutWorkItem?.cancel()
        geocoder.cancelGeocode()
        requestStartedAt = Date()
        bestLocation = nil
        isLocating = true
        manager.startUpdatingLocation()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.hasPendingRequest else { return }
            if let best = self.bestLocation, best.horizontalAccuracy <= 250 {
                self.finish(using: best)
            } else if self.manager.accuracyAuthorization == .reducedAccuracy {
                self.finishWithError("Precise Location is off. Turn it on in Settings so KnightSaver can find nearby pickups accurately.")
            } else {
                self.finishWithError("We couldn’t get an accurate location. Try again outdoors or choose a UCF campus.")
            }
        }
        timeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: workItem)
    }

    private func finish(using location: CLLocation) {
        guard hasPendingRequest else { return }
        hasPendingRequest = false
        manager.stopUpdatingLocation()
        timeoutWorkItem?.cancel()
        currentLocation = location

        // GPS success must not depend on Apple's address service. Publish a useful local label
        // immediately; reverse geocoding may improve it afterward.
        currentLocationLabel = immediateLocationLabel(for: location)
        isLocating = false
        hasCurrentLocation = true

        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            DispatchQueue.main.async {
                guard let self, let placemark = placemarks?.first else { return }
                self.currentLocationLabel = self.locationLabel(for: placemark, fallback: location.coordinate)
            }
        }
    }

    private func immediateLocationLabel(for location: CLLocation) -> String {
        let campuses: [(String, CLLocation)] = [
            ("UCF Main Campus", CLLocation(latitude: 28.6024, longitude: -81.2001)),
            ("UCF Downtown", CLLocation(latitude: 28.5469, longitude: -81.3871)),
            ("Health Sciences Campus", CLLocation(latitude: 28.3664, longitude: -81.2818)),
            ("Rosen College", CLLocation(latitude: 28.4293, longitude: -81.4610))
        ]
        if let nearest = campuses.min(by: { location.distance(from: $0.1) < location.distance(from: $1.1) }),
           location.distance(from: nearest.1) <= 5_000 {
            return "Near \(nearest.0) · ±\(Int(location.horizontalAccuracy.rounded())) m"
        }
        return String(
            format: "%.4f, %.4f · ±%d m",
            location.coordinate.latitude,
            location.coordinate.longitude,
            Int(location.horizontalAccuracy.rounded())
        )
    }

    private func finishWithError(_ message: String) {
        hasPendingRequest = false
        manager.stopUpdatingLocation()
        timeoutWorkItem?.cancel()
        isLocating = false
        if !isQuietRefresh {
            errorMessage = message
        }
    }

    private func locationLabel(for placemark: CLPlacemark?, fallback coordinate: CLLocationCoordinate2D) -> String {
        guard let placemark else {
            return String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
        }

        let street = [placemark.subThoroughfare, placemark.thoroughfare]
            .compactMap { $0 }
            .joined(separator: " ")
        let city = placemark.locality ?? placemark.subAdministrativeArea

        if !street.isEmpty, let city, !city.isEmpty {
            return "\(street), \(city)"
        }
        if let name = placemark.name, !name.isEmpty {
            return name
        }
        if let city, !city.isEmpty {
            return [city, placemark.administrativeArea].compactMap { $0 }.joined(separator: ", ")
        }
        return String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
    }
}

private struct UCFCampusLocation: Identifiable {
    let name: String
    let address: String

    var id: String { name }
}

private struct PickupPreferencesView: View {
    @AppStorage("usesCurrentPickupLocation") private var usesCurrentLocation = false
    @AppStorage("preferredUCFCampus") private var selectedCampus = "UCF Main Campus"
    @AppStorage("currentPickupLatitude") private var currentLatitude = 0.0
    @AppStorage("currentPickupLongitude") private var currentLongitude = 0.0
    @AppStorage("currentPickupLabel") private var storedCurrentLocationLabel = "Current location"
    @AppStorage("currentPickupUpdatedAt") private var currentLocationUpdatedAt = 0.0
    @StateObject private var locationManager = PickupLocationManager()
    @Environment(\.openURL) private var openURL

    private let campuses = [
        UCFCampusLocation(name: "UCF Main Campus", address: "4000 Central Florida Blvd."),
        UCFCampusLocation(name: "UCF Downtown", address: "500 W. Livingston St."),
        UCFCampusLocation(name: "Health Sciences Campus", address: "6850 Lake Nona Blvd."),
        UCFCampusLocation(name: "Rosen College", address: "9907 Universal Blvd.")
    ]

    var body: some View {
        Form {
            Section("Current location") {
                Button {
                    selectCurrentLocation()
                } label: {
                    LocationPreferenceRow(
                        icon: "location.fill",
                        title: "Use My Location",
                        subtitle: currentLocationSubtitle,
                        isSelected: usesCurrentLocation,
                        isLoading: locationManager.isLocating
                    )
                }
                .buttonStyle(.plain)
                .accessibilityValue(usesCurrentLocation ? "Selected" : "Not selected")
            }

            Section {
                ForEach(campuses) { campus in
                    Button {
                        usesCurrentLocation = false
                        selectedCampus = campus.name
                    } label: {
                        LocationPreferenceRow(
                            icon: "building.columns.fill",
                            title: campus.name,
                            subtitle: campus.address,
                            isSelected: !usesCurrentLocation && selectedCampus == campus.name,
                            isLoading: false
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(!usesCurrentLocation && selectedCampus == campus.name ? "Selected" : "Not selected")
                }
            } header: {
                Text("UCF campuses")
            } footer: {
                Text("KnightSaver will prioritize available pickups near your selected location.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(KnightTheme.paper)
        .tint(KnightTheme.lake)
        .navigationTitle("Pickup preferences")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: locationManager.hasCurrentLocation) { _, hasCurrentLocation in
            if hasCurrentLocation {
                persistCurrentLocation()
                usesCurrentLocation = true
            }
        }
        .alert("Location unavailable", isPresented: locationErrorBinding) {
            if locationManager.authorizationStatus == .denied || locationManager.accuracyAuthorization == .reducedAccuracy {
                Button("Open Settings") {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        openURL(settingsURL)
                    }
                }
            }
            Button("Choose a campus", role: .cancel) { }
        } message: {
            Text(locationManager.errorMessage ?? "Choose a UCF campus instead.")
        }
    }

    private var currentLocationSubtitle: String {
        if locationManager.isLocating {
            return "Finding your location…"
        }

        switch locationManager.authorizationStatus {
        case .denied:
            return "Location access is off"
        case .restricted:
            return "Location access is restricted"
        default:
            return usesCurrentLocation ? storedCurrentLocationLabel : "Automatically find nearby pickups"
        }
    }

    private var locationErrorBinding: Binding<Bool> {
        Binding(
            get: { locationManager.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    locationManager.errorMessage = nil
                }
            }
        )
    }

    private func selectCurrentLocation() {
        locationManager.requestCurrentLocation()
    }

    private func persistCurrentLocation() {
        guard let location = locationManager.currentLocation else { return }
        currentLatitude = location.coordinate.latitude
        currentLongitude = location.coordinate.longitude
        storedCurrentLocationLabel = locationManager.currentLocationLabel ?? "Current location"
        currentLocationUpdatedAt = Date().timeIntervalSince1970
    }
}

struct LocationPreferenceRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let isLoading: Bool

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(KnightTheme.lake)
                .frame(width: 38, height: 38)
                .background(KnightTheme.lake.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(KnightTheme.ink)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(KnightTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if isLoading {
                ProgressView()
                    .tint(KnightTheme.lake)
                    .accessibilityLabel("Finding your location")
            } else if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(KnightTheme.green)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: 54)
        .contentShape(Rectangle())
    }
}

private struct ProfileArticleSection: Identifiable {
    let title: String
    let body: String

    var id: String { title }
}

private struct ProfileArticleView: View {
    let title: String
    let icon: String
    let sections: [ProfileArticleSection]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: icon)
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(KnightTheme.muted)
                    .frame(width: 56, height: 56)
                    .background(KnightTheme.wash, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                    .accessibilityHidden(true)

                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 7) {
                        Text(section.title)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(KnightTheme.ink)
                        Text(section.body)
                            .font(.system(size: 15))
                            .foregroundStyle(KnightTheme.muted)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(KnightTheme.screenPadding)
            .padding(.bottom, 24)
        }
        .background(KnightTheme.paper)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Profile photo

/// Profile photos chosen from the photo library, kept on this device (one per account).
@MainActor
final class ProfilePhotoStore: ObservableObject {
    @Published private(set) var photos: [UUID: UIImage] = [:]
    private let directory: URL

    init() {
        directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ProfilePhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for file in files {
            if let id = UUID(uuidString: file.deletingPathExtension().lastPathComponent),
               let image = UIImage(contentsOfFile: file.path) {
                photos[id] = image
            }
        }
    }

    func save(_ data: Data, for accountID: UUID) {
        guard let image = UIImage(data: data) else { return }
        let resized = image.resizedToFit(maxSide: 600)
        if let jpeg = resized.jpegData(compressionQuality: 0.85) {
            try? jpeg.write(to: fileURL(for: accountID), options: .atomic)
        }
        photos[accountID] = resized
    }

    func remove(for accountID: UUID) {
        try? FileManager.default.removeItem(at: fileURL(for: accountID))
        photos[accountID] = nil
    }

    private func fileURL(for accountID: UUID) -> URL {
        directory.appendingPathComponent("\(accountID.uuidString).jpg")
    }
}

private extension UIImage {
    func resizedToFit(maxSide: CGFloat) -> UIImage {
        let scale = min(1, maxSide / max(size.width, size.height))
        guard scale < 1 else { return self }
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        return UIGraphicsImageRenderer(size: target).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}

/// Round profile photo with a camera badge. Tap to pick a new photo, or remove the current one.
struct ProfileAvatar: View {
    let accountID: UUID
    var size: CGFloat = 64

    @EnvironmentObject private var photoStore: ProfilePhotoStore
    @State private var pickerItem: PhotosPickerItem?
    @State private var showPicker = false
    @State private var showOptions = false

    private var photo: UIImage? { photoStore.photos[accountID] }

    var body: some View {
        Button {
            if photo == nil {
                showPicker = true
            } else {
                showOptions = true
            }
        } label: {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let photo {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: size * 0.42, weight: .semibold))
                            .foregroundStyle(KnightTheme.muted)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(KnightTheme.wash)
                    }
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay {
                    Circle().stroke(KnightTheme.line, lineWidth: 1)
                }

                Image(systemName: "camera.fill")
                    .font(.system(size: size * 0.16, weight: .bold))
                    .foregroundStyle(KnightTheme.onAccent)
                    .frame(width: size * 0.36, height: size * 0.36)
                    .background(KnightTheme.gold, in: Circle())
                    .overlay {
                        Circle().stroke(KnightTheme.paper, lineWidth: 2.5)
                    }
                    .offset(x: 2, y: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(photo == nil ? "Add profile photo" : "Change profile photo")
        .photosPicker(isPresented: $showPicker, selection: $pickerItem, matching: .images)
        .confirmationDialog("Profile photo", isPresented: $showOptions, titleVisibility: .visible) {
            Button("Choose new photo") { showPicker = true }
            Button("Remove photo", role: .destructive) { photoStore.remove(for: accountID) }
            Button("Cancel", role: .cancel) { }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    photoStore.save(data, for: accountID)
                }
                pickerItem = nil
            }
        }
    }
}

// MARK: - Sign out

private struct SignOutButton: View {
    let onSignOut: () -> Void
    @State private var showConfirmation = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(role: .destructive) {
            showConfirmation = true
        } label: {
            Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(KnightTheme.red)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: KnightTheme.controlRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: KnightTheme.controlRadius, style: .continuous)
                        .stroke(KnightTheme.line, lineWidth: 1)
                }
        }
        .buttonStyle(PressScaleButtonStyle(reduceMotion: reduceMotion))
        .confirmationDialog("Sign out of KnightSaver?", isPresented: $showConfirmation, titleVisibility: .visible) {
            Button("Sign out", role: .destructive, action: onSignOut)
            Button("Stay signed in", role: .cancel) { }
        }
    }
}

// MARK: - Business profile

/// Profile tab for business owners: their photo, business details, and sign out.
/// Students see `ProfileView` instead.
struct BusinessAccountView: View {
    let account: AppAccount
    let onSignOut: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 12) {
                        KnightSaverBrandBar { ThemeToggleButton() }
                        header
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Business details")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(KnightTheme.ink)

                        VStack(spacing: 0) {
                            BusinessDetailRow(icon: "storefront", title: "Business", value: account.businessName ?? "Not set")
                            Divider().overlay(KnightTheme.line).padding(.leading, 58)
                            BusinessDetailRow(icon: "person", title: "Manager", value: account.displayName)
                            Divider().overlay(KnightTheme.line).padding(.leading, 58)
                            BusinessDetailRow(icon: "envelope", title: "Email", value: account.email)
                            Divider().overlay(KnightTheme.line).padding(.leading, 58)
                            BusinessDetailRow(icon: "phone", title: "Phone", value: account.phoneNumber ?? "Not provided")
                        }
                        .background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(KnightTheme.ink.opacity(0.06), lineWidth: 1)
                        }
                    }

                    SignOutButton(onSignOut: onSignOut)
                }
                .padding(.horizontal, KnightTheme.screenPadding)
                .padding(.top, 16)
                .padding(.bottom, 34)
            }
            .scrollIndicators(.hidden)
            .reservesTabBarSpace()
            .background(KnightTheme.paper)
            .navigationBarHidden(true)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Profile")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(KnightTheme.ink)

            HStack(spacing: 14) {
                ProfileAvatar(accountID: account.id, size: 68)

                VStack(alignment: .leading, spacing: 4) {
                    Text(account.businessName ?? account.displayName)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(KnightTheme.ink)
                    Text(account.email)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(KnightTheme.muted)
                    Text("Business account")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(KnightTheme.muted)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

private struct BusinessDetailRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(KnightTheme.muted)
                .frame(width: 34, height: 34)
                .accessibilityHidden(true)

            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(KnightTheme.ink)

            Spacer(minLength: 12)

            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(KnightTheme.muted)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 56)
        .accessibilityElement(children: .combine)
    }
}
