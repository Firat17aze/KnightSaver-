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
        .reservesTabBarSpace()
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
            KnightSaverBrandBar {
                ThemeToggleButton()
            }

            ScanKnightPassButton {
                sheet = .scan(expected: nil)
            }
            .tourTarget(.scanPass)
            .padding(.top, 4)

            Button {
                sheet = .listSurplus
            } label: {
                BizPrimaryLabel(title: "List surplus", icon: "plus")
            }
            .buttonStyle(PressScaleButtonStyle(reduceMotion: reduceMotion))
            .tourTarget(.listSurplus)
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
                .background(KnightTheme.forest, in: Capsule())
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
                .foregroundStyle(KnightTheme.muted)
                .frame(width: 40, height: 40)
                .background(KnightTheme.wash, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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

/// The one bold element on the page: a forest-green card with leaves tucked in from the
/// bottom-right corner and the knight framed by scan corners, like a QR code waiting to be read.
/// Flat fills only. The gold List surplus button sits under it.
struct ScanKnightPassButton: View {
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        LeafSprig(color: KnightTheme.sprout, accent: KnightTheme.sprout, vein: KnightTheme.forest, size: 14)
                        Text("KITCHEN")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(2.2)
                            .foregroundStyle(KnightTheme.sprout)
                    }
                    .padding(.bottom, 4)
                    Text("Scan Knight Pass")
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text("Verify a student's pickup")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(KnightTheme.mint)
                }

                Spacer(minLength: 4)

                ZStack {
                    ScanCorners(color: KnightTheme.gold, length: 14, lineWidth: 3, radius: 6, showsSprout: false)
                        .frame(width: 58, height: 58)
                    Image("KnightLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 42, height: 42)
                }
                .accessibilityHidden(true)

                Image(systemName: "arrow.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(KnightTheme.forest)
                    .frame(width: 34, height: 34)
                    .background(KnightTheme.sprout, in: Circle())
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
            .background {
                ZStack(alignment: .bottomTrailing) {
                    shape.fill(KnightTheme.forest)
                    CornerFoliage(back: KnightTheme.fern, front: KnightTheme.fern, vein: KnightTheme.forest, scale: 0.9)
                        .offset(x: 6, y: 4)
                    // A second, smaller sprig on the far left edge, behind the text.
                    Leaf(color: KnightTheme.fern, vein: KnightTheme.forest, width: 26, height: 52, angle: 64)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        .offset(x: -14, y: 18)
                }
                .clipShape(shape)
            }
            .contentShape(shape)
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

            BizMetaRow(icon: "clock.fill", text: "Pickup \(reservation.pickupWindowText)")

            HStack(spacing: 10) {
                if reservation.status == .authorized {
                    Button(action: onVerify) {
                        HStack(spacing: 7) {
                            Image(systemName: "qrcode.viewfinder")
                            Text("Verify pickup")
                        }
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(KnightTheme.onAccent)
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

/// One "Total" row for today's verified pickups. Tapping it shows each pickup's price.
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
                    Text("Total")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(KnightTheme.muted)
                    Spacer(minLength: 8)
                    Text(PickupTime.money(total))
                        .font(.system(size: 20, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(KnightTheme.ink)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(KnightTheme.muted)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Total, \(PickupTime.money(total))")
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
                                    .font(.system(size: 14, weight: .regular))
                                    .monospacedDigit()
                                    .foregroundStyle(KnightTheme.muted)
                                Spacer()
                                Text(PickupTime.money(rescue.total))
                                    .font(.system(size: 15, weight: .medium))
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
        VStack(alignment: .leading, spacing: 12) {
            BizSectionHeader(title: "Impact report", subtitle: "Updates only after a verified pickup")
                .padding(.bottom, 2)

            // The headline: CO₂e avoided with a green bar toward the goal.
            CO2eImpactCard(impact: impact)

            // Four supporting numbers, 2×2, so no tile sits alone on a row.
            LazyVGrid(columns: columns, spacing: 12) {
                BizStatTile(
                    title: "Bags collected",
                    value: "\(impact.bagsCollected)",
                    icon: "bag.fill",
                    caption: impact.verifiedPickups == 1 ? "1 verified pickup" : "\(impact.verifiedPickups) verified pickups"
                )
                BizStatTile(
                    title: "Revenue recovered",
                    value: PickupTime.money(impact.revenueRecovered),
                    icon: "dollarsign.circle.fill",
                    caption: "Captured at pickup"
                )
                BizStatTile(
                    title: "Pickup completion",
                    value: percent(impact.pickupCompletionRate),
                    icon: "checkmark.circle.fill",
                    caption: impact.pickupsDue == 0 ? "No pickups due yet" : "\(impact.verifiedPickups) of \(impact.pickupsDue) picked up",
                    progress: impact.pickupCompletionRate
                )
                BizStatTile(
                    title: "Average rating",
                    value: rating(impact.averageRating),
                    icon: "star.fill",
                    caption: impact.ratingCount == 1 ? "1 rating" : "\(impact.ratingCount) ratings"
                )
            }
        }
    }

    private func percent(_ value: Double?) -> String {
        guard let value else { return "—" }
        return "\(Int((value * 100).rounded()))%"
    }

    private func rating(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.1f", value)
    }
}

/// CO₂e avoided, with a green progress bar toward the goal and an everyday comparison.
private struct CO2eImpactCard: View {
    let impact: BusinessImpact
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShown = false

    private var goal: Double { BusinessRules.co2eGoalKg }
    private var progress: Double { goal > 0 ? min(impact.estimatedCO2eKg / goal, 1) : 0 }
    private var foodKg: Double { impact.measuredWeightKg + impact.estimatedWeightKg }
    private var kmNotDriven: Int { Int((impact.estimatedCO2eKg / BusinessRules.co2eKgPerCarKm).rounded()) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                LeafSprig(color: KnightTheme.green, accent: KnightTheme.green, vein: KnightTheme.greenWash, size: 20)
                    .frame(width: 34, height: 34)
                    .background(KnightTheme.greenWash, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text("CO₂e avoided")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(KnightTheme.ink)
                BizEstimateTag()
                Spacer(minLength: 0)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String(format: "%.1f", impact.estimatedCO2eKg))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(KnightTheme.ink)
                Text("kg")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(KnightTheme.muted)
                Spacer(minLength: 8)
                Text("≈ \(kmNotDriven) km not driven")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(KnightTheme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            BizProgressBar(progress: isShown ? progress : 0, tint: KnightTheme.green, height: 10)

            HStack {
                Text("\(Int((progress * 100).rounded()))% of the \(goalText) kg goal")
                Spacer(minLength: 8)
                Text(String(format: "From %.1f kg of food", foodKg))
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(KnightTheme.muted)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
        }
        .padding(17)
        .background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(KnightTheme.line, lineWidth: 1)
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.8).delay(0.1)) {
                isShown = true
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(
            format: "CO2e avoided, estimate, %.1f kilograms, %d percent of the %@ kilogram goal, about %d kilometers not driven",
            impact.estimatedCO2eKg, Int((progress * 100).rounded()), goalText, kmNotDriven
        ))
    }

    private var goalText: String {
        goal.rounded() == goal ? String(Int(goal)) : String(format: "%.1f", goal)
    }
}

#Preview("Business") {
    BusinessDashboardView(store: .demo())
}
