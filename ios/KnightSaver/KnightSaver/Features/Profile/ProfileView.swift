import SwiftUI
import CoreLocation
import UIKit

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
    let pass: KnightPass
    @Binding var activeReservations: [ActiveReservation]
    let action: () -> Void

    @State private var showSignOutConfirmation = false
    @State private var showDemoSignOutMessage = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    profileHeader

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
                            ProfileLinkItem(route: .pickupPreferences, title: "Pickup preferences", icon: "slider.horizontal.3")
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

                    Button(role: .destructive) {
                        showSignOutConfirmation = true
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
                }
                .padding(.horizontal, KnightTheme.screenPadding)
                .padding(.top, 16)
                .padding(.bottom, 34)
            }
            .scrollIndicators(.hidden)
            .background(KnightTheme.paper)
            .navigationBarHidden(true)
            .navigationDestination(for: ProfileRoute.self) { route in
                destination(for: route)
            }
            .confirmationDialog("Sign out of KnightSaver?", isPresented: $showSignOutConfirmation, titleVisibility: .visible) {
                Button("Sign out", role: .destructive) {
                    showDemoSignOutMessage = true
                }
                Button("Stay signed in", role: .cancel) { }
            }
            .alert("Demo account", isPresented: $showDemoSignOutMessage) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Account sign-out will be connected when authentication is added.")
            }
        }
    }

    private var profileHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            Text("Profile")
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(KnightTheme.ink)

            Spacer(minLength: 12)
            KnightMark()
        }
    }

    private var pickupsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProfileSectionHeader(
                title: "My pickups",
                subtitle: activeReservations.isEmpty ? "No upcoming pickups" : "Your next reservation"
            )

            if let reservation = activeReservations.first {
                NavigationLink(value: ProfileRoute.reservation(reservation.id)) {
                    UpcomingPickupCard(reservation: reservation)
                }
                .buttonStyle(PressScaleButtonStyle(reduceMotion: reduceMotion))
            } else {
                EmptyPickupCard()
            }

            NavigationLink(value: ProfileRoute.pickupHistory) {
                ProfileRow(
                    title: "Pickup history",
                    subtitle: "Completed and cancelled reservations",
                    icon: "clock.arrow.circlepath"
                )
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func destination(for route: ProfileRoute) -> some View {
        switch route {
        case .reservation(let id):
            if let reservation = activeReservations.first(where: { $0.id == id }) {
                ReservationDetailsView(reservation: reservation) {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                        activeReservations.removeAll { $0.id == id }
                    }
                }
            } else {
                MissingReservationView()
            }
        case .pickupHistory:
            PickupHistoryView()
        case .personalInformation:
            PersonalInformationView(pass: pass)
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
                BrandMark(brand: reservation.bag.brand, size: 48)

                VStack(alignment: .leading, spacing: 4) {
                    Text("UPCOMING PICKUP")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(KnightTheme.goldDeep)
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
                    .foregroundStyle(KnightTheme.goldDeep)
                    .accessibilityHidden(true)
            }
        }
        .padding(17)
        .background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: KnightTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: KnightTheme.cardRadius, style: .continuous)
                .stroke(KnightTheme.ink.opacity(0.07), lineWidth: 1)
        }
        .knightCardShadow()
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
                .foregroundStyle(KnightTheme.goldDeep)
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
                .foregroundStyle(KnightTheme.goldDeep)
                .frame(width: 44, height: 44)
                .background(KnightTheme.gold.opacity(0.18), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

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
                .foregroundStyle(KnightTheme.goldDeep)
                .frame(width: 34, height: 34)
                .background(KnightTheme.gold.opacity(0.16), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                            .font(.system(size: 24, weight: .black, design: .rounded))
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
                        .foregroundStyle(KnightTheme.ink)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(KnightTheme.gold, in: RoundedRectangle(cornerRadius: KnightTheme.controlRadius, style: .continuous))
                }
                .buttonStyle(.plain)

                HStack(alignment: .top, spacing: 11) {
                    Image(systemName: "qrcode")
                        .foregroundStyle(KnightTheme.goldDeep)
                        .accessibilityHidden(true)
                    Text("Use the reusable Knight Pass at the top of Profile when staff verifies your pickup.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(KnightTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .background(KnightTheme.gold.opacity(0.15), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

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
                .foregroundStyle(KnightTheme.goldDeep)
                .frame(width: 22)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .tracking(1)
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

private struct PersonalInformationView: View {
    let pass: KnightPass

    var body: some View {
        ScrollView {
            DetailCard(title: "Student account") {
                DetailLine(icon: "person.fill", label: "Name", value: pass.displayName)
                DetailLine(icon: "building.columns.fill", label: "Campus", value: pass.campusName)
                DetailLine(icon: "number", label: "Member ID", value: pass.memberID)
                DetailLine(icon: "graduationcap.fill", label: "Role", value: "Student")
            }
            .padding(KnightTheme.screenPadding)
        }
        .background(KnightTheme.paper)
        .navigationTitle("Personal information")
        .navigationBarTitleDisplayMode(.inline)
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
        .tint(KnightTheme.goldDeep)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private final class ProfileLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var isLocating = false
    @Published var errorMessage: String?

    private let manager = CLLocationManager()
    private var hasPendingRequest = false

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestCurrentLocation() {
        errorMessage = nil
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
        hasPendingRequest = false
        isLocating = false
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        hasPendingRequest = false
        isLocating = false

        if (error as? CLError)?.code != .denied {
            errorMessage = "We couldn’t find your location. Try again or choose a UCF campus."
        }
    }

    private func requestLocationUpdate() {
        isLocating = true
        manager.requestLocation()
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
    @StateObject private var locationManager = ProfileLocationManager()
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
        .tint(KnightTheme.goldDeep)
        .navigationTitle("Pickup preferences")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: locationManager.authorizationStatus) { _, status in
            if status == .authorizedAlways || status == .authorizedWhenInUse {
                usesCurrentLocation = true
            }
        }
        .alert("Location unavailable", isPresented: locationErrorBinding) {
            if locationManager.authorizationStatus == .denied {
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
            return "Automatically find nearby pickups"
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
        if locationManager.authorizationStatus == .authorizedAlways ||
            locationManager.authorizationStatus == .authorizedWhenInUse {
            usesCurrentLocation = true
        }
        locationManager.requestCurrentLocation()
    }
}

private struct LocationPreferenceRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let isLoading: Bool

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(KnightTheme.goldDeep)
                .frame(width: 38, height: 38)
                .background(KnightTheme.gold.opacity(0.16), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
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
                    .tint(KnightTheme.goldDeep)
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
                    .foregroundStyle(KnightTheme.goldDeep)
                    .frame(width: 56, height: 56)
                    .background(KnightTheme.gold.opacity(0.18), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
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
