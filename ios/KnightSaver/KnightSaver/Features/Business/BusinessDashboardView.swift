import SwiftUI

/// The fourth navigation destination: one focused, scrollable business dashboard.
/// RootView owns the shared BusinessStore and passes it in, so the data survives
/// tab switches and the student side sees the same listings and reservations.
struct BusinessDashboardView: View {
    @ObservedObject var store: BusinessStore
    @State private var sheet: BusinessSheet?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(store: BusinessStore) {
        _store = ObservedObject(wrappedValue: store)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                header
                currentBagsSection
                reservedPickupsSection
                verifiedRescuesSection
                BusinessImpactSection(impact: store.impact)
            }
            .padding(.horizontal, KnightTheme.screenPadding)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(KnightTheme.paper)
        .overlay(alignment: .top) {
            toastView
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.3), value: store.toast)
        .sheet(item: $sheet) { sheet in
            sheetContent(sheet)
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "storefront.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(KnightTheme.goldDeep)
                    .frame(width: 50, height: 50)
                    .background(KnightTheme.gold.opacity(0.22), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.isDemo ? "BUSINESS · DEMO VIEW" : "BUSINESS")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(KnightTheme.goldDeep)
                    Text("Restaurant")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(KnightTheme.ink)
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)

            ScanKnightPassButton {
                sheet = .scan(expected: nil)
            }
            .padding(.top, 4)

            Button {
                sheet = .listSurplus
            } label: {
                BizPrimaryLabel(title: "List surplus", icon: "plus")
            }
            .buttonStyle(PressScaleButtonStyle(reduceMotion: reduceMotion))
            .accessibilityLabel("List surplus")
            .accessibilityHint("Publish new Surprise Bags with AI or manually")
        }
    }

    // MARK: - 1. Current Surprise Bags

    private var currentBagsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            BizSectionHeader(
                title: "Current Surprise Bags",
                trailing: "\(store.listings.filter { $0.isReservable }.count) available"
            )
            if store.listings.isEmpty {
                emptyCard(icon: "bag.badge.plus", text: "Nothing listed yet. Tap List surplus to publish Surprise Bags.")
            } else {
                ForEach(store.currentListings) { listing in
                    SurpriseBagListingCard(
                        listing: listing,
                        waitlistCount: store.waitlistCount(for: listing.id),
                        onEdit: { sheet = .edit(listing.id) },
                        onPauseToggle: { store.setPaused(listing.state != .paused, listingID: listing.id) },
                        onClose: { store.close(listingID: listing.id) },
                        onCancel: { store.cancelListing(listingID: listing.id) }
                    )
                }
            }
        }
    }

    // MARK: - 2. Reserved pickups

    private var reservedPickupsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            BizSectionHeader(
                title: "Reserved pickups",
                subtitle: "Verify by scanning the student's Knight Pass",
                trailing: "\(store.upcomingPickups.filter { $0.status == .authorized }.count) to collect"
            )
            if store.upcomingPickups.isEmpty {
                emptyCard(icon: "calendar.badge.clock", text: "No upcoming pickups right now.")
            } else {
                ForEach(store.upcomingPickups) { reservation in
                    ReservedPickupCard(
                        reservation: reservation,
                        showDemoActions: store.isDemo,
                        onVerify: { sheet = .scan(expected: reservation.id) },
                        onSimulateCancel: { store.cancelReservation(id: reservation.id) },
                        onSimulateAccept: { store.acceptOffer(id: reservation.id) },
                        onMarkMissed: { store.markMissed(id: reservation.id) }
                    )
                }
            }
        }
    }

    // MARK: - 3. Today's verified rescues

    private var verifiedRescuesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            BizSectionHeader(title: "Today's verified rescues")
            TodaysTotalCard(rescues: store.todaysVerifiedRescues, total: store.todaysVerifiedTotal)
        }
    }

    // MARK: - Toast

    @ViewBuilder
    private var toastView: some View {
        if let message = store.toast {
            Text(message)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(KnightTheme.ink.opacity(0.92), in: Capsule())
                .padding(.horizontal, KnightTheme.screenPadding)
                .padding(.top, 6)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onTapGesture { store.toast = nil }
                .task(id: message) {
                    try? await Task.sleep(nanoseconds: 3_500_000_000)
                    if store.toast == message { store.toast = nil }
                }
                .accessibilityAddTraits(.isStaticText)
        }
    }

    // MARK: - Sheets

    @ViewBuilder
    private func sheetContent(_ sheet: BusinessSheet) -> some View {
        switch sheet {
        case .listSurplus:
            ListSurplusFlow(store: store)
        case .edit(let id):
            if let listing = store.listing(id: id) {
                EditListingFlow(store: store, listing: listing)
            }
        case .scan(let expected):
            PassScannerView(store: store, expectedReservationID: expected)
        }
    }

    private func emptyCard(icon: String, text: String) -> some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(KnightTheme.goldDeep)
                .frame(width: 40, height: 40)
                .background(KnightTheme.gold.opacity(0.18), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(KnightTheme.muted)
            Spacer(minLength: 0)
        }
        .bizCard()
    }
}

enum BusinessSheet: Identifiable, Hashable {
    case listSurplus
    case edit(UUID)
    case scan(expected: UUID?)

    var id: String {
        switch self {
        case .listSurplus: return "list"
        case .edit(let id): return "edit-\(id.uuidString)"
        case .scan(let expected): return "scan-\(expected?.uuidString ?? "any")"
        }
    }
}

// MARK: - Scan Knight Pass button

/// The one bold element on the page. Same family as the Knight Pass card in Profile
/// (dark diagonal gradient, faint gold ring, gold wordmark, KnightLogo, 22pt corners,
/// thin white border), but shaped as a wide action with a gold chevron so it reads as a button.
struct ScanKnightPassButton: View {
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("KNIGHTSAVER")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(2.2)
                        .foregroundStyle(KnightTheme.gold)
                        .padding(.bottom, 4)
                    Text("Scan Knight Pass")
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Verify a student's pickup")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.68))
                }

                Spacer(minLength: 8)

                Image("KnightLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 58, height: 58)
                    .accessibilityHidden(true)

                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(KnightTheme.ink)
                    .frame(width: 38, height: 38)
                    .background(KnightTheme.gold, in: Circle())
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
            .background {
                GeometryReader { proxy in
                    ZStack {
                        LinearGradient(
                            colors: [
                                Color(red: 0.055, green: 0.053, blue: 0.05),
                                Color(red: 0.14, green: 0.125, blue: 0.095)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        Circle()
                            .stroke(KnightTheme.gold.opacity(0.14), lineWidth: 1)
                            .frame(width: proxy.size.width * 0.62)
                            .offset(x: proxy.size.width * 0.38, y: -proxy.size.height * 0.62)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(.white.opacity(0.14), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 8)
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(PressScaleButtonStyle(reduceMotion: reduceMotion))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Scan Knight Pass")
        .accessibilityHint("Verify a student's pickup with the camera")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Listing card

struct SurpriseBagListingCard: View {
    let listing: BusinessListing
    let waitlistCount: Int
    let onEdit: () -> Void
    let onPauseToggle: () -> Void
    let onClose: () -> Void
    let onCancel: () -> Void

    private var isOpen: Bool { listing.state == .live || listing.state == .paused }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(listing.label)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(KnightTheme.ink)
                    Text(PickupTime.money(listing.price) + " each")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(KnightTheme.muted)
                }
                Spacer(minLength: 8)
                BizChip(text: listing.status.rawValue, tint: listing.status.tint)
            }

            VStack(spacing: 9) {
                BizMetaRow(icon: "clock.fill", text: "Pickup \(listing.pickupWindowText)")
                BizMetaRow(icon: "bag.fill", text: "\(listing.remainingQuantity) of \(listing.totalQuantity) bags left"
                           + (waitlistCount > 0 ? " · \(waitlistCount) on waitlist" : ""))
            }

            let packingLines = listing.staffPackingLines
            if !packingLines.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("STAFF ONLY", systemImage: "lock.fill")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .tracking(0.9)
                        .foregroundStyle(KnightTheme.muted)
                    ForEach(Array(packingLines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(KnightTheme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(KnightTheme.paper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Staff only. " + packingLines.joined(separator: ". "))
            }

            if isOpen {
                HStack(spacing: 10) {
                    Button(action: onEdit) {
                        BizSecondaryLabel(title: "Edit listing", icon: "pencil")
                    }
                    .buttonStyle(.plain)

                    Button(action: onPauseToggle) {
                        BizSecondaryLabel(
                            title: listing.state == .paused ? "Resume" : "Pause",
                            icon: listing.state == .paused ? "play.fill" : "pause.fill"
                        )
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 0)

                    Menu {
                        Button(action: onClose) {
                            Label("Close listing", systemImage: "xmark.circle")
                        }
                        Button(role: .destructive, action: onCancel) {
                            Label("Cancel listing", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(KnightTheme.ink)
                            .frame(width: 44, height: 44)
                            .background(KnightTheme.paper, in: Circle())
                    }
                    .accessibilityLabel("More listing actions")
                }
            }
        }
        .bizCard()
        .opacity(isOpen ? 1 : 0.62)
    }
}

// MARK: - Reserved pickup card

struct ReservedPickupCard: View {
    let reservation: BusinessReservation
    let showDemoActions: Bool
    let onVerify: () -> Void
    let onSimulateCancel: () -> Void
    let onSimulateAccept: () -> Void
    let onMarkMissed: () -> Void

    private var statusText: String {
        if reservation.status == .waitlisted, let position = reservation.waitlistPosition {
            return "Waitlist #\(position)"
        }
        return reservation.status.rawValue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(reservation.studentDisplayName)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(KnightTheme.ink)
                    Text("\(reservation.code) · \(reservation.quantity) Surprise Bag\(reservation.quantity == 1 ? "" : "s")")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(KnightTheme.muted)
                }
                Spacer(minLength: 8)
                BizChip(text: statusText, tint: reservation.status.tint)
            }

            VStack(spacing: 9) {
                BizMetaRow(icon: "clock.fill", text: "Pickup \(reservation.pickupWindowText)")
                BizMetaRow(icon: "creditcard.fill", text: reservation.payment.rawValue)
            }

            HStack(spacing: 10) {
                if reservation.status == .authorized {
                    Button(action: onVerify) {
                        HStack(spacing: 7) {
                            Image(systemName: "qrcode.viewfinder")
                            Text("Verify pickup")
                        }
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(KnightTheme.ink)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .background(KnightTheme.gold, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                } else if reservation.status == .offerSent {
                    Text("Waiting for the student to accept")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(KnightTheme.muted)
                } else {
                    Text("Gets a bag if one frees up")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(KnightTheme.muted)
                }

                Spacer(minLength: 0)

                if showDemoActions {
                    Menu {
                        if reservation.status == .offerSent {
                            Button(action: onSimulateAccept) {
                                Label("Student accepts offer (demo)", systemImage: "hand.thumbsup")
                            }
                        }
                        if reservation.status == .authorized {
                            Button(action: onMarkMissed) {
                                Label("Mark as missed", systemImage: "clock.badge.xmark")
                            }
                        }
                        Button(role: .destructive, action: onSimulateCancel) {
                            Label("Student cancels (demo)", systemImage: "person.crop.circle.badge.xmark")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(KnightTheme.ink)
                            .frame(width: 44, height: 44)
                            .background(KnightTheme.paper, in: Circle())
                    }
                    .accessibilityLabel("More reservation actions")
                }
            }
        }
        .bizCard()
    }
}

// MARK: - Today's total

/// One row with today's verified total. Tapping it shows each verified pickup's price.
struct TodaysTotalCard: View {
    let rescues: [BusinessReservation]
    let total: Double

    @State private var isExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Text("Today's total")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(KnightTheme.ink)
                    Spacer(minLength: 8)
                    Text(PickupTime.money(total))
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(KnightTheme.ink)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(KnightTheme.goldDeep)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Today's total, \(PickupTime.money(total))")
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
            .accessibilityHint(isExpanded ? "Hides the individual pickups" : "Shows the price of each verified pickup")
            .accessibilityAddTraits(.isButton)

            if isExpanded {
                VStack(spacing: 0) {
                    if rescues.isEmpty {
                        Divider().overlay(KnightTheme.line)
                        Text("No verified pickups yet today.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(KnightTheme.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 12)
                    } else {
                        ForEach(rescues) { rescue in
                            Divider().overlay(KnightTheme.line)
                            HStack {
                                Text(rescue.verifiedAt.map { PickupTime.time($0) } ?? "")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(KnightTheme.muted)
                                Spacer()
                                Text(PickupTime.money(rescue.total))
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(KnightTheme.ink)
                            }
                            .padding(.vertical, 11)
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
                .padding(.top, 6)
                .transition(reduceMotion ? .identity : .opacity.combined(with: .move(edge: .top)))
            }
        }
        .bizCard()
        .clipped()
    }
}

// MARK: - 4. Impact report

struct BusinessImpactSection: View {
    let impact: BusinessImpact

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            BizSectionHeader(title: "Impact report", subtitle: "Updates only after a verified pickup")

            LazyVGrid(columns: columns, spacing: 12) {
                BizStatTile(title: "Bags collected", value: "\(impact.bagsCollected)")
                BizStatTile(title: "Revenue recovered", value: PickupTime.money(impact.revenueRecovered))
                BizStatTile(title: "Measured weight", value: kg(impact.measuredWeightKg))
                BizStatTile(title: "Estimated weight", value: kg(impact.estimatedWeightKg), isEstimate: true)
                BizStatTile(title: "CO₂e avoided", value: kg(impact.estimatedCO2eKg), isEstimate: true)
                BizStatTile(title: "Pickup completion", value: percent(impact.pickupCompletionRate))
                BizStatTile(title: "Average rating", value: rating(impact.averageRating))
            }
        }
    }

    private func kg(_ value: Double) -> String {
        String(format: "%.1f kg", value)
    }

    private func percent(_ value: Double?) -> String {
        guard let value else { return "—" }
        return "\(Int((value * 100).rounded()))%"
    }

    private func rating(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f ★", value)
    }
}

#Preview("Business") {
    BusinessDashboardView(store: .demo())
}
