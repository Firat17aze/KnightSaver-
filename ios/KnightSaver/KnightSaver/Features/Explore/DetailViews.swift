import SwiftUI
import CoreLocation
import UIKit

struct BagDetailView: View {
    let bag: SurpriseBag
    let onReserve: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    BrandBanner(bag: bag)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                    VStack(alignment: .leading, spacing: 24) {
                        titleBlock
                        quickFacts
                        descriptionBlock
                        pickupBlock
                        pastReveals
                        expectationNotice
                    }
                    .padding(.top, 22)
                }
                .padding(.horizontal, KnightTheme.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .background(KnightTheme.paper)
            .navigationTitle("Surprise Bag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                reserveBar
            }
            .alert(bag.availableCount == 0 ? "Waitlist joined" : "Reservation confirmed", isPresented: $showConfirmation) {
                Button("Done") {
                    // ExploreView decides: reserve, or join the waitlist for live bags.
                    onReserve()
                    dismiss()
                }
            } message: {
                Text(bag.availableCount == 0
                     ? "We’ll notify you if a Surprise Bag becomes available."
                     : "Your payment is authorized and will be captured after staff verifies pickup.")
            }
        }
    }

    private var titleBlock: some View {
        HStack(alignment: .top, spacing: 14) {
            BrandMark(brand: bag.brand, size: 58)

            VStack(alignment: .leading, spacing: 5) {
                Text(bag.business)
                    .font(.system(size: 25, weight: .black, design: .rounded))
                    .foregroundStyle(KnightTheme.ink)
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(KnightTheme.goldDeep)
                    Text("\(bag.rating, specifier: "%.1f")")
                        .fontWeight(.bold)
                    Text("· \(bag.feedbackCount) verified reviews")
                        .foregroundStyle(KnightTheme.muted)
                }
                .font(.system(size: 13))
            }

            Spacer(minLength: 8)

            Text(bag.formattedPrice)
                .font(.system(size: 23, weight: .black, design: .rounded))
                .foregroundStyle(KnightTheme.ink)
        }
    }

    private var quickFacts: some View {
        HStack(spacing: 10) {
            DetailFact(icon: "clock.fill", label: "Pickup", value: bag.pickupWindow)
            DetailFact(icon: "figure.walk", label: "Distance", value: String(format: "%.1f mi", bag.distance))
            DetailFact(icon: "takeoutbag.and.cup.and.straw.fill", label: "Available", value: bag.availableCount == 0 ? "Waitlist" : "\(bag.availableCount) bags")
        }
    }

    private var descriptionBlock: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("About this pickup")
                .font(.system(size: 19, weight: .bold, design: .rounded))
            Text(bag.description)
                .font(.system(size: 15))
                .foregroundStyle(KnightTheme.muted)
                .lineSpacing(3)
        }
    }

    private var pickupBlock: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("Pickup details")
                .font(.system(size: 19, weight: .bold, design: .rounded))

            HStack(spacing: 13) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(KnightTheme.goldDeep)
                    .frame(width: 42, height: 42)
                    .background(KnightTheme.gold.opacity(0.22), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(bag.location)
                        .font(.system(size: 15, weight: .bold))
                    Text("UCF Main Campus · Pickup only")
                        .font(.system(size: 13))
                        .foregroundStyle(KnightTheme.muted)
                }

                Spacer()

                Button("Directions") { }
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(KnightTheme.ink)
                    .frame(minHeight: 44)
            }
            .padding(15)
            .background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var pastReveals: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text("Past Surprise Reveals")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                Spacer()
                Text("Verified pickups")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(KnightTheme.green)
            }

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    RevealCard(initials: "AM", rating: 5, comment: "Great portion and a smooth pickup.", tint: bag.brand.secondary)
                    RevealCard(initials: "JR", rating: 4, comment: "Fun surprise—everything was easy to use.", tint: KnightTheme.gold)
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var expectationNotice: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(KnightTheme.goldDeep)
            Text("Contents change with the business’s available surplus. Past Reveals show previous student experiences and do not guarantee future contents.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(KnightTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(KnightTheme.gold.opacity(0.16), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var reserveBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                showConfirmation = true
            } label: {
                HStack {
                    Text(bag.availableCount == 0 ? "Join waitlist" : bag.price == 0 ? "Reserve for free" : "Reserve with Apple Pay")
                    Spacer()
                    if bag.availableCount > 0 {
                        Text(bag.formattedPrice)
                    }
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(KnightTheme.ink)
                .padding(.horizontal, 19)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(KnightTheme.gold, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, KnightTheme.screenPadding)
            .padding(.vertical, 12)
        }
        .background(.ultraThinMaterial)
    }
}

private struct DetailFact: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(KnightTheme.goldDeep)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .black, design: .rounded))
                .tracking(1)
                .foregroundStyle(KnightTheme.muted)
            Text(value)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(KnightTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct RevealCard: View {
    let initials: String
    let rating: Int
    let comment: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(initials)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.32), in: Circle())
                Spacer()
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { index in
                        Image(systemName: index < rating ? "star.fill" : "star")
                    }
                }
                .font(.system(size: 9))
                .foregroundStyle(KnightTheme.goldDeep)
            }
            Text(comment)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(KnightTheme.ink)
                .lineLimit(2)
        }
        .padding(14)
        .frame(width: 226, height: 110, alignment: .topLeading)
        .background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(KnightTheme.line, lineWidth: 1)
        }
    }
}

struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage("usesCurrentPickupLocation") private var usesCurrentLocation = false
    @AppStorage("preferredUCFCampus") private var selectedLocation = "UCF Main Campus"
    @AppStorage("currentPickupLatitude") private var currentLatitude = 0.0
    @AppStorage("currentPickupLongitude") private var currentLongitude = 0.0
    @AppStorage("currentPickupLabel") private var storedCurrentLocationLabel = "Current location"
    @StateObject private var locationManager = PickupLocationManager()

    private let locations = [
        "UCF Main Campus",
        "UCF Downtown",
        "Health Sciences Campus",
        "Rosen College"
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        locationManager.requestCurrentLocation()
                    } label: {
                        LocationPreferenceRow(
                            icon: "location.fill",
                            title: "My Current Location",
                            subtitle: currentLocationSubtitle,
                            isSelected: usesCurrentLocation,
                            isLoading: locationManager.isLocating
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(usesCurrentLocation ? "Selected" : "Not selected")
                }

                Section("UCF campuses") {
                    ForEach(locations, id: \.self) { location in
                        Button {
                            usesCurrentLocation = false
                            selectedLocation = location
                            dismiss()
                        } label: {
                            HStack {
                                Text(location)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(KnightTheme.ink)

                                Spacer()

                                if !usesCurrentLocation && selectedLocation == location {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(KnightTheme.goldDeep)
                                        .accessibilityHidden(true)
                                }
                            }
                            .frame(minHeight: 48)
                        }
                        .buttonStyle(.plain)
                        .accessibilityValue(!usesCurrentLocation && selectedLocation == location ? "Selected" : "Not selected")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(KnightTheme.paper)
            .navigationTitle("Pickup area")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .onChange(of: locationManager.hasCurrentLocation) { _, hasCurrentLocation in
                if hasCurrentLocation {
                    persistCurrentLocation()
                    usesCurrentLocation = true
                    dismiss()
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
            return usesCurrentLocation ? storedCurrentLocationLabel : "Use your device location"
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

    private func persistCurrentLocation() {
        guard let location = locationManager.currentLocation else { return }
        currentLatitude = location.coordinate.latitude
        currentLongitude = location.coordinate.longitude
        storedCurrentLocationLabel = locationManager.currentLocationLabel ?? "Current location"
    }
}
