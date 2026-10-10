import SwiftUI

enum ExploreSort: String, CaseIterable, Identifiable {
    case recommended = "Recommended"
    case nearest = "Nearest"
    case pickupTime = "Pickup time"
    case highestRated = "Highest rated"

    var id: String { rawValue }
}

struct ExploreView: View {
    @Binding var activeReservations: [ActiveReservation]

    @State private var searchText = ""
    @State private var availableOnly = false
    @State private var sort: ExploreSort = .recommended
    @State private var selectedBag: SurpriseBag?
    @State private var showLocationPicker = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Shared with Business: bags published there appear here right away.
    @EnvironmentObject var businessStore: BusinessStore

    /// Signed-in student. Demo account until authentication is added.
    private var student: KnightPass { KnightPass.sample }

    /// Live bags from Business first, then the sample restaurants (minus the business that is live).
    private var allBags: [SurpriseBag] {
        businessStore.surpriseBagsForExplore
            + SurpriseBag.samples.filter { $0.business != businessStore.profile.name }
    }

    private var visibleBags: [SurpriseBag] {
        var bags = allBags.filter { bag in
            let matchesSearch = searchText.isEmpty ||
                bag.business.localizedCaseInsensitiveContains(searchText) ||
                "Surprise Bag".localizedCaseInsensitiveContains(searchText)
            return matchesSearch && (!availableOnly || bag.availableCount > 0)
        }

        switch sort {
        case .recommended:
            break
        case .nearest:
            bags.sort { $0.distance < $1.distance }
        case .pickupTime:
            bags.sort { $0.pickupWindow < $1.pickupWindow }
        case .highestRated:
            bags.sort { $0.rating > $1.rating }
        }
        return bags
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    header

                    discoveryControls
                        .padding(.top, 20)

                    resultsHeader
                        .padding(.top, 26)

                    if visibleBags.isEmpty {
                        EmptyExploreState(searchText: searchText) {
                            searchText = ""
                            availableOnly = false
                            sort = .recommended
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
                BagDetailView(bag: businessStore.liveBag(id: bag.id) ?? bag) {
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
                                Text("UCF Main Campus")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundStyle(KnightTheme.ink)
                        }
                    }
                }
                .buttonStyle(.plain)
                .frame(minHeight: 48)
                .accessibilityLabel("Pickup area, UCF Main Campus")
                .accessibilityHint("Change pickup area")

                Spacer()

                KnightMark()
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
                    FilterChip(title: "Distance", icon: "location", isSelected: sort == .nearest) {
                        sort = sort == .nearest ? .recommended : .nearest
                    }
                    FilterChip(title: "Pickup time", icon: "clock", isSelected: sort == .pickupTime) {
                        sort = sort == .pickupTime ? .recommended : .pickupTime
                    }
                    FilterChip(title: "Rating", icon: "star", isSelected: sort == .highestRated) {
                        sort = sort == .highestRated ? .recommended : .highestRated
                    }
                    FilterChip(title: "Available now", icon: "checkmark.circle", isSelected: availableOnly) {
                        availableOnly.toggle()
                    }
                }
            }
            .scrollIndicators(.hidden)
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
}
