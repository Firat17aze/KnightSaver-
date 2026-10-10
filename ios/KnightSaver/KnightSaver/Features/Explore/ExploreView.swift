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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject var businessStore: BusinessStore

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
                LazyVStack(alignment: .leading, spacing: 0) {
                    KnightSaverBrandBar()
                        .padding(.bottom, 12)
                    header
                        .padding(.horizontal, KnightTheme.screenPadding)

                    searchField
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
                .padding(.top, 10)
                .padding(.bottom, 34)
            }
            .scrollIndicators(.hidden)
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
            .sheet(isPresented: $showLocationPicker) {
                LocationPickerView()
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Button {
                showLocationPicker = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(KnightTheme.goldDeep)
                        .frame(width: 34, height: 34)
                        .background(KnightTheme.gold.opacity(0.24), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("PICKUP NEAR")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(1.2)
                            .foregroundStyle(KnightTheme.muted)
                        HStack(spacing: 5) {
                            Text(pickupLocationTitle)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(KnightTheme.ink)
                    }
                }
            }
            .buttonStyle(.plain)
            .frame(minHeight: 48)
            .accessibilityLabel("Pickup area, \(pickupLocationTitle)")
            .accessibilityHint("Change or refresh your pickup location")

            Spacer(minLength: 12)
        }
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
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(shelf.title)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(KnightTheme.ink)
                    Text(shelf.subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(KnightTheme.muted)
                        .lineLimit(1)
                }

                Spacer(minLength: 12)

                Text("\(shelf.bags.count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(KnightTheme.muted)
            }
            .padding(.horizontal, KnightTheme.screenPadding)

            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 18) {
                    ForEach(shelf.bags) { bag in
                        Button {
                            selectedBag = bag
                        } label: {
                            SurpriseBagCard(bag: bag)
                                .containerRelativeFrame(.horizontal) { availableWidth, _ in
                                    min(320, max(274, availableWidth - 92))
                                }
                        }
                        .buttonStyle(PressScaleButtonStyle(reduceMotion: reduceMotion))
                        .accessibilityLabel("\(bag.business), Surprise Bag, \(bag.availabilityText), \(bag.formattedPrice), pickup \(bag.pickupWindow)")
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, 46, for: .scrollContent)
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
        }
    }

    private func reserve(_ bag: SurpriseBag) {
        if businessStore.isLiveBag(bag) {
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
