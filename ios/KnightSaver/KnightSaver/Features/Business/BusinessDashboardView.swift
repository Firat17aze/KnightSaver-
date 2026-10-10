import SwiftUI

/// The fourth navigation destination: one focused, scrollable business dashboard.
/// RootView shows it with `BusinessDashboardView()`.
struct BusinessDashboardView: View {
    @StateObject private var store: BusinessStore
    @State private var sheet: BusinessSheet?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Pass a shared store to connect other tabs. Without one it uses demo data.
    init(store: BusinessStore? = nil) {
        _store = StateObject(wrappedValue: store ?? BusinessStore.demo())
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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            listSurplusButton
        }
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
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                BrandMark(brand: store.profile.brand, size: 50)
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.isDemo ? "BUSINESS · DEMO VIEW" : "BUSINESS")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(KnightTheme.goldDeep)
                    Text(store.profile.name)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(KnightTheme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                        Text(store.profile.pickupAddress)
                        Text("·")
                        Image(systemName: "star.fill")
                            .foregroundStyle(KnightTheme.goldDeep)
                        Text(String(format: "%.1f", store.profile.rating) + " (\(store.profile.feedbackCount))")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(KnightTheme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
            }

            Button {
                sheet = .scan(expected: nil)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(KnightTheme.gold)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Scan Knight Pass")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                        Text("Verify a student's pickup")
                            .font(.system(size: 12, weight: .medium))
                            .opacity(0.75)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .frame(minHeight: 64)
                .background(KnightTheme.ink, in: RoundedRectangle(cornerRadius: KnightTheme.controlRadius, style: .continuous))
            }
            .buttonStyle(PressScaleButtonStyle(reduceMotion: reduceMotion))
            .accessibilityHint("Opens the camera to scan a student's Knight Pass")
        }
    }

    // MARK: - 1. Current Surprise Bags

    private var currentBagsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            BizSectionHeader(
                title: "Current Surprise Bags",
                subtitle: "Live in Explore and KnightMap",
                trailing: "\(store.listings.filter { $0.isReservable }.count) available"
            )
            if store.listings.isEmpty {
                emptyCard(icon: "bag.badge.plus", text: "Nothing listed yet. Tap List surplus to publish Surprise Bags.")
            } else {
                ForEach(store.currentListings) { listing in
                    SurpriseBagListingCard(
                        listing: listing,
                        brand: store.profile.brand,
                        waitlistCount: store.waitlistCount(for: listing.id),
                        onEdit: { sheet = .edit(listing.id) },
                        onPauseToggle: { store.setPaused(listing.state != .paused, listingID: listing.id) },
                        onClose: { store.close(listingID: listing.id) },
                        onCancel: { store.cancelListing(listingID: listing.id) }
                    )
                }
            }
            if !store.feedback.isEmpty {
                FeedbackSummaryCard(feedback: store.feedback)
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
            BizSectionHeader(
                title: "Today's verified rescues",
                subtitle: "Only pickups confirmed with a Knight Pass scan",
                trailing: "\(store.todaysVerifiedRescues.count)"
            )
            if store.todaysVerifiedRescues.isEmpty {
                emptyCard(icon: "checkmark.seal", text: "Verified pickups will appear here.")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(store.todaysVerifiedRescues.enumerated()), id: \.element.id) { index, rescue in
                        if index > 0 {
                            Divider().overlay(KnightTheme.line)
                        }
                        VerifiedRescueRow(reservation: rescue)
                            .padding(.vertical, 12)
                    }
                }
                .bizCard()
            }
        }
    }

    // MARK: - + List surplus

    private var listSurplusButton: some View {
        Button {
            sheet = .listSurplus
        } label: {
            BizPrimaryLabel(title: "List surplus", icon: "plus")
                .shadow(color: KnightTheme.ink.opacity(0.12), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(PressScaleButtonStyle(reduceMotion: reduceMotion))
        .padding(.horizontal, KnightTheme.screenPadding)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(KnightTheme.paper.opacity(0.94))
        .accessibilityLabel("List surplus")
        .accessibilityHint("Publish new Surprise Bags with AI or manually")
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

// MARK: - Listing card

struct SurpriseBagListingCard: View {
    let listing: BusinessListing
    let brand: BagBrand
    let waitlistCount: Int
    let onEdit: () -> Void
    let onPauseToggle: () -> Void
    let onClose: () -> Void
    let onCancel: () -> Void

    private var isOpen: Bool { listing.state == .live || listing.state == .paused }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                BrandMark(brand: brand, size: 44)
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
                BizMetaRow(icon: "mappin.and.ellipse", text: listing.pickupAddress)
            }

            if !listing.inventory.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.top, 2)
                    Text("Staff only: \(listing.inventory.summaryText)")
                        .font(.system(size: 12, weight: .medium))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(KnightTheme.muted)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(KnightTheme.paper, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityLabel("Staff only inventory: \(listing.inventory.summaryText)")
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

// MARK: - Feedback summary

struct FeedbackSummaryCard: View {
    let feedback: [PickupFeedback]

    private var average: Double {
        Double(feedback.reduce(0) { $0 + $1.overall }) / Double(max(1, feedback.count))
    }

    private var reserveAgainShare: Int {
        Int((Double(feedback.filter { $0.wouldReserveAgain }.count) / Double(max(1, feedback.count)) * 100).rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "star.fill")
                    .foregroundStyle(KnightTheme.goldDeep)
                Text(String(format: "%.1f from verified pickups", average))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(KnightTheme.ink)
                Spacer(minLength: 0)
                Text("\(reserveAgainShare)% would reserve again")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(KnightTheme.muted)
            }
            if let latest = feedback.max(by: { $0.submittedAt < $1.submittedAt }) {
                Text("“\(latest.comment)”")
                    .font(.system(size: 13, weight: .medium))
                    .italic()
                    .foregroundStyle(KnightTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .bizCard()
        .accessibilityElement(children: .combine)
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

// MARK: - Verified rescue row

struct VerifiedRescueRow: View {
    let reservation: BusinessReservation

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 22))
                .foregroundStyle(KnightTheme.green)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text("\(reservation.studentDisplayName) · \(reservation.quantity) bag\(reservation.quantity == 1 ? "" : "s")")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(KnightTheme.ink)
                Text("\(reservation.code) · verified \(reservation.verifiedAt.map { PickupTime.time($0) } ?? "")")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(KnightTheme.muted)
                HStack(spacing: 6) {
                    BizChip(text: "Payment captured", tint: KnightTheme.green)
                    BizChip(text: "Verified rescue", tint: KnightTheme.goldDeep, icon: "checkmark")
                }
            }
            Spacer(minLength: 0)
            Text(PickupTime.money(reservation.total))
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(KnightTheme.ink)
        }
        .accessibilityElement(children: .combine)
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
                BizStatTile(title: "Bags collected", value: "\(impact.bagsCollected)",
                            note: "Verified Surprise Bags")
                BizStatTile(title: "Revenue recovered", value: PickupTime.money(impact.revenueRecovered),
                            note: "Payments captured")
                BizStatTile(title: "Measured weight", value: kg(impact.measuredWeightKg),
                            note: "Bags weighed by staff")
                BizStatTile(title: "Estimated weight", value: kg(impact.estimatedWeightKg),
                            note: "From staff inventory", isEstimate: true)
                BizStatTile(title: "CO₂e avoided", value: kg(impact.estimatedCO2eKg),
                            note: "Estimated from food weight", isEstimate: true)
                BizStatTile(title: "Pickup completion", value: percent(impact.pickupCompletionRate),
                            note: "Verified ÷ due pickups")
                BizStatTile(title: "Average rating", value: rating(impact.averageRating),
                            note: "\(impact.ratingCount) verified review\(impact.ratingCount == 1 ? "" : "s")")
            }

            Text("Estimated values are never shown as measured data.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(KnightTheme.muted)
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
    BusinessDashboardView()
}
