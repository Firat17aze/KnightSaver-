import SwiftUI
import CoreLocation

private struct ExploreShelf: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let bags: [SurpriseBag]
}

struct ExploreView: View {
    @Binding var activeReservations: [ActiveReservation]
    let student: KnightPass

    @State private var searchText = ""
    @State private var selectedBag: SurpriseBag?
    @State private var showLocationPicker = false
    @AppStorage("usesCurrentPickupLocation") private var usesCurrentLocation = false
    @AppStorage("preferredUCFCampus") private var selectedCampus = "UCF Main Campus"
    @AppStorage("currentPickupLatitude") private var currentLatitude = 0.0
    @AppStorage("currentPickupLongitude") private var currentLongitude = 0.0
    @AppStorage("currentPickupLabel") private var currentLocationLabel = "Current location"
    @AppStorage("currentPickupUpdatedAt") private var currentLocationUpdatedAt = 0.0
    @StateObject private var locationManager = PickupLocationManager()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject var businessStore: BusinessStore
    @EnvironmentObject var sessionStore: SessionStore

    /// Resolve distance once per Explore refresh, then reuse the result in every shelf.
    private var matchingBags: [SurpriseBag] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let bags = (businessStore.surpriseBagsForExplore
            + SurpriseBag.samples.filter { $0.business != businessStore.profile.name })
            .map(resolvingDistance)

        guard !query.isEmpty else { return bags }
        return bags.filter { bag in
            bag.business.localizedCaseInsensitiveContains(query)
                || bag.location.localizedCaseInsensitiveContains(query)
                || "Surprise Bag".localizedCaseInsensitiveContains(query)
        }
    }

    private var shelves: [ExploreShelf] {
        let bags = matchingBags
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty else {
            return bags.isEmpty ? [] : [
                ExploreShelf(
                    id: "search",
                    title: "Search results",
                    subtitle: "Matches for “\(query)”",
                    bags: bags
                )
            ]
        }

        let now = Date()
        let available = bags.filter { $0.availableCount > 0 }
        let pickupSoon = available
            .filter { bag in
                guard let start = bag.pickupStart else { return false }
                let end = bag.pickupEnd ?? start.addingTimeInterval(60 * 60)
                return end >= now && start <= now.addingTimeInterval(2 * 60 * 60)
            }
            .sorted { ($0.pickupStart ?? .distantFuture) < ($1.pickupStart ?? .distantFuture) }
        let nearby = available.sorted { $0.distance < $1.distance }
        let topRated = bags.sorted {
            $0.rating == $1.rating ? $0.feedbackCount > $1.feedbackCount : $0.rating > $1.rating
        }
        let later = available
            .filter { ($0.pickupStart ?? .distantPast) > now.addingTimeInterval(2 * 60 * 60) }
            .sorted { ($0.pickupStart ?? .distantFuture) < ($1.pickupStart ?? .distantFuture) }

        return [
            ExploreShelf(
                id: "pickup-now",
                title: "Pick up now",
                subtitle: "Ready now or starting within two hours",
                bags: pickupSoon
            ),
            ExploreShelf(
                id: "nearby",
                title: "Near you",
                subtitle: "Closest to \(pickupLocationTitle)",
                bags: Array(nearby.prefix(8))
            ),
            ExploreShelf(
                id: "top-rated",
                title: "Community favorites",
                subtitle: "Highest rated by KnightSaver members",
                bags: Array(topRated.prefix(8))
            ),
            ExploreShelf(
                id: "later",
                title: "Later today",
                subtitle: "Plan your next campus pickup",
                bags: later
            )
        ]
        .filter { !$0.bags.isEmpty }
    }

    private var pickupLocationTitle: String {
        usesCurrentLocation ? currentLocationLabel : selectedCampus
    }

    var body: some View {
        let currentShelves = shelves

        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 30) {
                    VStack(alignment: .leading, spacing: 16) {
                        KnightSaverBrandBar()
                        header
                        searchField
                    }
                    .padding(.horizontal, KnightTheme.screenPadding)

                    if currentShelves.isEmpty {
                        EmptyExploreState(searchText: searchText) {
                            searchText = ""
                        }
                        .padding(.horizontal, KnightTheme.screenPadding)
                    } else {
                        ForEach(currentShelves) { shelf in
                            shelfView(shelf)
                        }
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .reservesTabBarSpace()
            .background(KnightTheme.paper)
            .navigationBarHidden(true)
            .sheet(item: $selectedBag) { bag in
                BagDetailView(bag: resolvingDistance(businessStore.liveBag(id: bag.id) ?? bag)) {
                    reserve(bag)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .onChange(of: businessStore.listings) { _, _ in
                if let bag = selectedBag,
                   businessStore.isLiveBag(bag),
                   businessStore.liveBag(id: bag.id) == nil {
                    selectedBag = nil
                }
            }
            .task {
                refreshCurrentLocationIfStale()
            }
            .onChange(of: locationManager.hasCurrentLocation) { _, found in
                guard found, let location = locationManager.currentLocation else { return }
                currentLatitude = location.coordinate.latitude
                currentLongitude = location.coordinate.longitude
                currentLocationLabel = locationManager.currentLocationLabel ?? "Current location"
                currentLocationUpdatedAt = Date().timeIntervalSince1970
            }
            .sheet(isPresented: $showLocationPicker) {
                LocationPickerView()
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var header: some View {
        Button {
            showLocationPicker = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "location.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(KnightTheme.lake)
                    .frame(width: 36, height: 36)
                    .background(KnightTheme.lake.opacity(0.14), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Pickup near")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(KnightTheme.muted)
                    Text(pickupLocationTitle)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(KnightTheme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Spacer(minLength: 8)

                Text("Change")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(KnightTheme.lake)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(minHeight: 48)
        .accessibilityLabel("Pickup area, \(pickupLocationTitle)")
        .accessibilityHint("Change or refresh your pickup location")
    }

    private var searchField: some View {
        HStack(spacing: 11) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(KnightTheme.muted)

            TextField(
                "",
                text: $searchText,
                prompt: Text("Search food and businesses")
                    .foregroundStyle(KnightTheme.muted)
            )
            .font(.system(size: 15, weight: .medium))
            .textInputAutocapitalization(.words)
            .submitLabel(.search)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(KnightTheme.muted)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: KnightTheme.controlRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: KnightTheme.controlRadius, style: .continuous)
                .stroke(KnightTheme.line, lineWidth: 1)
        }
    }

    private func shelfView(_ shelf: ExploreShelf) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(shelf.title)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(KnightTheme.ink)
                        .lineLimit(1)
                    Text(shelf.subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(KnightTheme.muted)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Text("\(shelf.bags.count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(KnightTheme.ink)
                    .frame(minWidth: 28, minHeight: 28)
                    .padding(.horizontal, 4)
                    .background(KnightTheme.surface, in: Capsule())
                    .overlay {
                        Capsule().stroke(KnightTheme.line, lineWidth: 1)
                    }
                    .accessibilityLabel("\(shelf.bags.count) bags")
            }
            .padding(.horizontal, KnightTheme.screenPadding)

            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: Self.cardSpacing) {
                    ForEach(shelf.bags) { bag in
                        Button {
                            selectedBag = bag
                        } label: {
                            SurpriseBagCard(bag: bag)
                        }
                        .buttonStyle(PressScaleButtonStyle(reduceMotion: reduceMotion))
                        // Width follows the screen (minus the page gutters), leaving a peek of
                        // the next card so the shelf reads as scrollable on every iPhone size.
                        .containerRelativeFrame(.horizontal) { availableWidth, _ in
                            min(Self.maxCardWidth, availableWidth - Self.nextCardPeek)
                        }
                        .accessibilityLabel("\(bag.business), Surprise Bag, \(bag.availabilityText), \(bag.formattedPrice), pickup \(bag.pickupWindow)")
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, KnightTheme.screenPadding, for: .scrollContent)
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
        }
    }

    private static let cardSpacing: CGFloat = 14
    private static let nextCardPeek: CGFloat = 40
    private static let maxCardWidth: CGFloat = 340

    /// "Current location" was only saved once when picked. Refresh it when Explore opens
    /// (at most every two minutes) so distances follow the student around campus.
    private func refreshCurrentLocationIfStale() {
        guard usesCurrentLocation else { return }
        let age = Date().timeIntervalSince1970 - currentLocationUpdatedAt
        guard age > 120 else { return }
        locationManager.refreshIfAuthorized()
    }

    private func reserve(_ bag: SurpriseBag) {
        if businessStore.isLiveBag(bag), !businessStore.isDemo, let accessToken = sessionStore.accessToken {
            Task { @MainActor in
                do {
                    let result = try await KnightSaverBackend.shared.reserve(
                        listingID: bag.id,
                        accessToken: accessToken
                    )
                    let isWaitlisted = result.kind == "waitlisted"
                    activeReservations.append(ActiveReservation(
                        id: result.reservationID ?? result.waitlistID ?? UUID(),
                        bag: bag,
                        status: isWaitlisted ? .waitlisted : .confirmed,
                        paymentStatus: isWaitlisted ? "Not charged" : "Payment authorized",
                        attentionMessage: isWaitlisted
                            ? "Waitlist position \(result.position ?? 1)"
                            : "Pickup code \(result.code ?? "Ready")"
                    ))
                    businessStore.toast = isWaitlisted ? "You joined the waitlist." : "Surprise Bag reserved."
                    selectedBag = nil
                    await businessStore.refreshFromBackend()
                } catch {
                    businessStore.toast = error.localizedDescription
                }
            }
        } else if businessStore.isLiveBag(bag) {
            businessStore.reserve(
                bagID: bag.id,
                studentName: student.displayName,
                passToken: student.verificationToken
            )
        } else if bag.availableCount > 0 {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                activeReservations.append(ActiveReservation(
                    bag: bag,
                    status: .confirmed,
                    paymentStatus: "Payment authorized",
                    attentionMessage: "Your pickup is ready"
                ))
            }
        }
    }

    private func resolvingDistance(_ bag: SurpriseBag) -> SurpriseBag {
        var resolved = bag
        let destination = CLLocation(latitude: bag.latitude, longitude: bag.longitude)
        resolved.distance = pickupOrigin.distance(from: destination) / 1_609.344
        return resolved
    }

    private var pickupOrigin: CLLocation {
        if usesCurrentLocation, currentLatitude != 0, currentLongitude != 0 {
            return CLLocation(latitude: currentLatitude, longitude: currentLongitude)
        }

        let coordinate: (Double, Double)
        switch selectedCampus {
        case "UCF Downtown":
            coordinate = (28.5447, -81.3799)
        case "Health Sciences Campus":
            coordinate = (28.3688, -81.2788)
        case "Rosen College":
            coordinate = (28.4284, -81.4428)
        default:
            coordinate = (28.6024, -81.2001)
        }
        return CLLocation(latitude: coordinate.0, longitude: coordinate.1)
    }
}
