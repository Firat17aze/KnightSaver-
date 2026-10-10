import SwiftUI
import CoreLocation

enum ExploreSort: String, CaseIterable, Identifiable {
    case recommended = "Recommended"
    case nearest = "Nearest"
    case pickupTime = "Pickup time"
    case highestRated = "Highest rated"

    var id: String { rawValue }
}

private enum ExplorePickupTimeFilter: String, CaseIterable, Identifiable {
    case any = "Any time"
    case nextHour = "Next hour"
    case afternoon = "Afternoon"
    case evening = "Evening"

    var id: String { rawValue }

    func includes(_ date: Date?) -> Bool {
        guard self != .any else { return true }
        guard let date else { return false }
        switch self {
        case .any:
            return true
        case .nextHour:
            return date >= Date() && date <= Date().addingTimeInterval(60 * 60)
        case .afternoon:
            return (12..<17).contains(Calendar.current.component(.hour, from: date))
        case .evening:
            return Calendar.current.component(.hour, from: date) >= 17
        }
    }
}

struct ExploreView: View {
    @Binding var activeReservations: [ActiveReservation]
    let student: KnightPass

    @State private var searchText = ""
    @State private var availableOnly = false
    @State private var maximumDistance: Double?
    @State private var minimumRating: Double?
    @State private var pickupTimeFilter: ExplorePickupTimeFilter = .any
    @State private var sort: ExploreSort = .recommended
    @State private var selectedBag: SurpriseBag?
    @State private var showLocationPicker = false
    @AppStorage("usesCurrentPickupLocation") private var usesCurrentLocation = false
    @AppStorage("preferredUCFCampus") private var selectedCampus = "UCF Main Campus"
    @AppStorage("currentPickupLatitude") private var currentLatitude = 0.0
    @AppStorage("currentPickupLongitude") private var currentLongitude = 0.0
    @AppStorage("currentPickupLabel") private var currentLocationLabel = "Current location"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Shared with Business: bags published there appear here right away.
    @EnvironmentObject var businessStore: BusinessStore

    /// Live bags from Business first, then the sample restaurants (minus the business that is live).
    private var allBags: [SurpriseBag] {
        (businessStore.surpriseBagsForExplore
            + SurpriseBag.samples.filter { $0.business != businessStore.profile.name })
            .map(resolvingDistance)
    }

    private var pickupLocationTitle: String {
        usesCurrentLocation ? currentLocationLabel : selectedCampus
    }

    private var hasActiveFilters: Bool {
        maximumDistance != nil || minimumRating != nil || pickupTimeFilter != .any || availableOnly
    }

    private var visibleBags: [SurpriseBag] {
        var bags = allBags.filter { bag in
            let matchesSearch = searchText.isEmpty ||
                bag.business.localizedCaseInsensitiveContains(searchText) ||
                "Surprise Bag".localizedCaseInsensitiveContains(searchText)
            let matchesDistance = maximumDistance.map { bag.distance <= $0 } ?? true
            let matchesRating = minimumRating.map { bag.rating >= $0 } ?? true
            let matchesPickupTime = pickupTimeFilter.includes(bag.pickupStart)
            let matchesAvailability = !availableOnly || bag.availableCount > 0
            return matchesSearch && matchesDistance && matchesRating && matchesPickupTime && matchesAvailability
        }

        switch sort {
        case .recommended:
            break
        case .nearest:
            bags.sort { $0.distance < $1.distance }
        case .pickupTime:
            bags.sort { ($0.pickupStart ?? .distantFuture) < ($1.pickupStart ?? .distantFuture) }
        case .highestRated:
            bags.sort { $0.rating > $1.rating }
        }
        return bags
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    KnightSaverBrandBar()
                        .padding(.bottom, 12)

                    header

                    discoveryControls
                        .padding(.top, 20)

                    resultsHeader
                        .padding(.top, 26)

                    if visibleBags.isEmpty {
                        EmptyExploreState(searchText: searchText) {
                            clearDiscovery()
                        }
                        .padding(.top, 26)
                    } else {
                        LazyVStack(spacing: 20) {
                            ForEach(visibleBags) { bag in
                                Button {
                                    selectedBag = bag
                                } label: {
                                    SurpriseBagCard(bag: bag)
                                }
                                .buttonStyle(PressScaleButtonStyle(reduceMotion: reduceMotion))
                                .accessibilityLabel("\(bag.business), Surprise Bag, \(bag.availabilityText), \(bag.formattedPrice), pickup \(bag.pickupWindow)")
                            }
                        }
                        .padding(.top, 16)
                    }
                }
                .padding(.horizontal, KnightTheme.screenPadding)
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .background(KnightTheme.paper)
            .navigationBarHidden(true)
            .sheet(item: $selectedBag) { bag in
                // Always show the latest version of a live bag (quantity, price, pickup time).
                BagDetailView(bag: resolvingDistance(businessStore.liveBag(id: bag.id) ?? bag)) {
                    reserve(bag)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .onChange(of: businessStore.listings) { _, _ in
                // Close the details if Business paused, closed or cancelled this bag.
                if let bag = selectedBag, businessStore.isLiveBag(bag), businessStore.liveBag(id: bag.id) == nil {
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
        VStack(alignment: .leading, spacing: 0) {
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
                .accessibilityHint("Change pickup area")

                Spacer()
            }
        }
    }

    /// Live bags reserve through the shared store, so the reservation shows up in Business
    /// and in Profile. Sample restaurants keep the local demo behaviour.
    private func reserve(_ bag: SurpriseBag) {
        if businessStore.isLiveBag(bag) {
            businessStore.reserve(
                bagID: bag.id,
                studentName: student.displayName,
                passToken: student.verificationToken
            )
        } else if bag.availableCount > 0 {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.24)) {
                activeReservations.append(ActiveReservation(
                    bag: bag,
                    status: .confirmed,
                    paymentStatus: "Payment authorized",
                    attentionMessage: "Your pickup is ready"
                ))
            }
        }
    }

    private var discoveryControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 11) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(KnightTheme.muted)

                TextField(
                    "",
                    text: $searchText,
                    prompt: Text("Search businesses or Surprise Bags")
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

            ScrollView(.horizontal) {
                HStack(spacing: 9) {
                    Menu {
                        Button("Any distance") { maximumDistance = nil }
                        Button("Within 0.5 mi") { maximumDistance = 0.5 }
                        Button("Within 1 mi") { maximumDistance = 1 }
                        Button("Within 2 mi") { maximumDistance = 2 }
                    } label: {
                        FilterMenuChip(
                            title: maximumDistance.map { "Within \(formatDistance($0)) mi" } ?? "Distance",
                            icon: "location",
                            isSelected: maximumDistance != nil
                        )
                    }
                    .accessibilityLabel("Distance filter")

                    Menu {
                        Picker("Pickup time", selection: $pickupTimeFilter) {
                            ForEach(ExplorePickupTimeFilter.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                    } label: {
                        FilterMenuChip(
                            title: pickupTimeFilter == .any ? "Pickup time" : pickupTimeFilter.rawValue,
                            icon: "clock",
                            isSelected: pickupTimeFilter != .any
                        )
                    }
                    .accessibilityLabel("Pickup time filter")

                    Menu {
                        Button("Any rating") { minimumRating = nil }
                        Button("4.0 and up") { minimumRating = 4.0 }
                        Button("4.5 and up") { minimumRating = 4.5 }
                        Button("4.8 and up") { minimumRating = 4.8 }
                    } label: {
                        FilterMenuChip(
                            title: minimumRating.map { String(format: "%.1f+", $0) } ?? "Rating",
                            icon: "star",
                            isSelected: minimumRating != nil
                        )
                    }
                    .accessibilityLabel("Rating filter")

                    FilterChip(title: "Available now", icon: "checkmark.circle", isSelected: availableOnly) {
                        availableOnly.toggle()
                    }
                }
            }
            .scrollIndicators(.hidden)

            if hasActiveFilters {
                Button("Clear filters", action: clearFilters)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(KnightTheme.goldDeep)
                    .frame(minHeight: 44)
                    .accessibilityHint("Shows every listing near the selected pickup area")
            }
        }
    }

    private var resultsHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Available near you")
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(KnightTheme.ink)
                Text("\(visibleBags.count) pickup\(visibleBags.count == 1 ? "" : "s")")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(KnightTheme.muted)
            }

            Spacer()

            Menu {
                Picker("Sort Surprise Bags", selection: $sort) {
                    ForEach(ExploreSort.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text("Sort")
                    Image(systemName: "arrow.up.arrow.down")
                }
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(KnightTheme.ink)
                .frame(minWidth: 68, minHeight: 44)
            }
            .accessibilityLabel("Sort Surprise Bags, currently \(sort.rawValue)")
        }
    }

    private func clearFilters() {
        maximumDistance = nil
        minimumRating = nil
        pickupTimeFilter = .any
        availableOnly = false
    }

    private func clearDiscovery() {
        searchText = ""
        clearFilters()
        sort = .recommended
    }

    private func formatDistance(_ distance: Double) -> String {
        distance.rounded() == distance ? String(Int(distance)) : String(format: "%.1f", distance)
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
