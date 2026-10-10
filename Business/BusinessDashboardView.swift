import SwiftUI

/// The 4th tab of the shared app: one scrollable business page.
///
/// Usage inside the shared TabView:
///
///     BusinessDashboardView()
///         .tabItem { Label("Business", systemImage: "storefront") }
///
struct BusinessDashboardView: View {
    @StateObject private var store: BusinessStore
    @State private var activeSheet: BusinessSheet?

    /// Pass a store to share data with other tabs. With no store it uses demo data.
    init(store: BusinessStore? = nil) {
        _store = StateObject(wrappedValue: store ?? BusinessStore.demo())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    currentListingsSection
                    reservedSpotsSection
                    todaysRescuesSection
                    BusinessImpactReport(impact: store.impact)
                }
                .padding(.horizontal)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .background(BusinessTheme.pageBackground.ignoresSafeArea())
            .navigationTitle("Business")
            .safeAreaInset(edge: .bottom) {
                listSurplusButton
            }
            .overlay(alignment: .top) {
                eventToast
            }
            .animation(.spring(), value: store.lastEvent)
            .sheet(item: $activeSheet) { sheet in
                sheetContent(for: sheet)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(store.businessName)
                .font(.headline)
            if store.isDemo {
                BusinessBadge(text: "Demo business view", color: .primary, systemImage: "info.circle")
            }
        }
    }

    // MARK: - 1. Current listings

    private var currentListingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BusinessSectionHeader(
                title: "Current listings",
                detail: "\(store.listings.filter { $0.status != .closed }.count) open"
            )
            if store.listings.isEmpty {
                BusinessEmptyCard(text: "No food listed yet. Tap + List surplus to add some.")
            } else {
                ForEach(store.sortedListings) { listing in
                    BusinessListingCard(
                        listing: listing,
                        waitlistCount: store.waitlistCount(for: listing.id),
                        onEdit: { activeSheet = .edit(listing.id) },
                        onTogglePause: { store.setPaused(!listing.isPaused, listingID: listing.id) },
                        onClose: { store.close(listingID: listing.id) }
                    )
                }
            }
        }
    }

    // MARK: - 2. Reserved spots

    private var reservedSpotsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BusinessSectionHeader(title: "Reserved spots", detail: "\(store.reservations.count) waiting")
            if store.reservations.isEmpty {
                BusinessEmptyCard(text: "No upcoming pickups right now.")
            } else {
                ForEach(store.upcomingReservations) { reservation in
                    BusinessReservationCard(
                        reservation: reservation,
                        showDemoActions: store.isDemo,
                        onVerify: { activeSheet = .verify(reservation.id) },
                        onSimulateCancel: { store.cancelReservation(reservationID: reservation.id) }
                    )
                }
            }
        }
    }

    // MARK: - 3. Today's rescues

    private var todaysRescuesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BusinessSectionHeader(title: "Today's rescues", detail: "\(store.todaysRescues.count) verified")
            if store.todaysRescues.isEmpty {
                BusinessEmptyCard(text: "Verified pickups will show up here.")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(store.todaysRescues.enumerated()), id: \.element.id) { index, rescue in
                        if index > 0 {
                            Divider()
                        }
                        BusinessRescueRow(rescue: rescue)
                            .padding(.vertical, 10)
                    }
                }
                .businessCard()
            }
        }
    }

    // MARK: - + List surplus

    private var listSurplusButton: some View {
        Button {
            activeSheet = .newListing
        } label: {
            Label("List surplus", systemImage: "plus")
                .font(.headline)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(BusinessTheme.gold, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Toast after actions

    @ViewBuilder
    private var eventToast: some View {
        if let message = store.lastEvent {
            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.85), in: Capsule())
                .padding(.horizontal)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onTapGesture { store.lastEvent = nil }
                .task(id: message) {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    if store.lastEvent == message {
                        store.lastEvent = nil
                    }
                }
        }
    }

    // MARK: - Sheets

    @ViewBuilder
    private func sheetContent(for sheet: BusinessSheet) -> some View {
        switch sheet {
        case .newListing:
            ListSurplusFlow(store: store)
        case .edit(let id):
            if let listing = store.listing(id: id) {
                EditListingFlow(store: store, listing: listing)
            }
        case .verify(let id):
            if let reservation = store.reservation(id: id) {
                VerifyPickupSheet(store: store, reservation: reservation)
            }
        }
    }
}

enum BusinessSheet: Identifiable {
    case newListing
    case edit(UUID)
    case verify(UUID)

    var id: String {
        switch self {
        case .newListing: return "new"
        case .edit(let id): return "edit-\(id.uuidString)"
        case .verify(let id): return "verify-\(id.uuidString)"
        }
    }
}

// MARK: - Cards

struct BusinessListingCard: View {
    let listing: Listing
    let waitlistCount: Int
    let onEdit: () -> Void
    let onTogglePause: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(listing.name)
                    .font(.headline)
                Spacer()
                BusinessBadge(text: listing.status.label, color: listing.status.color)
            }

            HStack(spacing: 14) {
                BusinessInfoItem(systemImage: "takeoutbag.and.cup.and.straw", text: "\(listing.quantityRemaining) left")
                BusinessInfoItem(systemImage: "dollarsign.circle", text: ListingAssistant.money(listing.price))
                BusinessInfoItem(systemImage: "clock", text: "by \(ListingAssistant.time(listing.pickupDeadline))")
            }

            if waitlistCount > 0 {
                Text("\(waitlistCount) waiting on the waitlist")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if listing.status != .closed {
                HStack {
                    Button(action: onEdit) {
                        Label("Edit listing", systemImage: "pencil")
                    }
                    .buttonStyle(.bordered)
                    .tint(.primary)

                    Spacer()

                    Menu {
                        Button(action: onTogglePause) {
                            if listing.isPaused {
                                Label("Resume listing", systemImage: "play.circle")
                            } else {
                                Label("Pause listing", systemImage: "pause.circle")
                            }
                        }
                        Button(role: .destructive, action: onClose) {
                            Label("Close listing", systemImage: "xmark.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .businessCard()
        .opacity(listing.status == .closed ? 0.6 : 1)
    }
}

struct BusinessReservationCard: View {
    let reservation: Reservation
    let showDemoActions: Bool
    let onVerify: () -> Void
    let onSimulateCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(reservation.studentName)
                    .font(.headline)
                Spacer()
                if reservation.fromWaitlist {
                    BusinessBadge(text: "From waitlist", color: .purple)
                }
            }

            Text("\(reservation.quantity) × \(reservation.itemName)")
                .font(.subheadline)

            HStack(spacing: 14) {
                BusinessInfoItem(systemImage: "clock", text: "by \(ListingAssistant.time(reservation.pickupDeadline))")
                BusinessInfoItem(systemImage: "creditcard", text: reservation.payment.label)
            }

            HStack {
                Button(action: onVerify) {
                    Label("Verify pickup", systemImage: "qrcode.viewfinder")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(BusinessTheme.gold, in: Capsule())
                }
                .buttonStyle(.plain)

                Spacer()

                if showDemoActions {
                    Menu {
                        Button(role: .destructive, action: onSimulateCancel) {
                            Label("Simulate student cancel (demo)", systemImage: "person.crop.circle.badge.xmark")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .businessCard()
    }
}

struct BusinessRescueRow: View {
    let rescue: Rescue

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title3)
                .foregroundColor(.green)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(rescue.quantity) × \(rescue.itemName)")
                    .font(.subheadline.weight(.semibold))
                Text("\(rescue.studentName) · \(rescue.reservationCode) · \(ListingAssistant.time(rescue.pickedUpAt))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack(spacing: 6) {
                    BusinessBadge(text: "Payment captured", color: .green)
                    BusinessBadge(text: "Verified rescue", color: .blue)
                }
            }
            Spacer(minLength: 0)
            Text(ListingAssistant.money(rescue.amountCaptured))
                .font(.subheadline.weight(.semibold))
        }
    }
}

// MARK: - 4. Impact report

struct BusinessImpactReport: View {
    let impact: ImpactSummary

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            BusinessSectionHeader(title: "Impact report")

            LazyVGrid(columns: columns, spacing: 12) {
                tile(title: "Portions rescued", value: "\(impact.portionsRescued)", note: "Verified pickups only")
                tile(title: "Food weight", value: kgAndPounds(impact.totalWeightKg), note: weightNote)
                tile(title: "Revenue recovered", value: ListingAssistant.money(impact.revenueRecovered), note: "Payments captured")
                tile(title: "Student savings", value: ListingAssistant.money(impact.studentSavings), note: "vs. normal menu price")
                tile(title: "Pickup completion", value: completionText, note: "Verified ÷ due pickups")
            }

            Text("Numbers update only after staff verify a pickup.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var completionText: String {
        guard let rate = impact.pickupCompletionRate else { return "—" }
        return "\(Int((rate * 100).rounded()))%"
    }

    private var weightNote: String {
        String(format: "%.2f kg measured · %.2f kg estimated", impact.measuredWeightKg, impact.estimatedWeightKg)
    }

    private func kgAndPounds(_ kg: Double) -> String {
        String(format: "%.1f kg (%.1f lb)", kg, kg * 2.20462)
    }

    private func tile(title: String, value: String, note: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3.weight(.bold))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(note)
                .font(.caption2)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .businessCard()
    }
}

// MARK: - Previews

#Preview("Business tab") {
    BusinessDashboardView()
}

#Preview("Inside the 5-tab app") {
    TabView(selection: .constant(4)) {
        Text("Explore").tabItem { Label("Explore", systemImage: "magnifyingglass") }.tag(1)
        Text("My Rescues").tabItem { Label("My Rescues", systemImage: "bag") }.tag(2)
        Text("Impact").tabItem { Label("Impact", systemImage: "leaf") }.tag(3)
        BusinessDashboardView().tabItem { Label("Business", systemImage: "storefront") }.tag(4)
        Text("Profile").tabItem { Label("Profile", systemImage: "person.crop.circle") }.tag(5)
    }
}
