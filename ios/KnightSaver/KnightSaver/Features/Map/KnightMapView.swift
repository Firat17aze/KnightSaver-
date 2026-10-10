import CoreLocation
import MapKit
import SwiftUI

/// KnightMap (student.md "KnightMap"): every kitchen on campus, its hours for the week,
/// live bags, and walking directions.
struct KnightMapView: View {
    @Binding var activeReservations: [ActiveReservation]
    let student: KnightPass
    /// Opens reservation management (Profile).
    let onManageReservation: () -> Void

    @EnvironmentObject private var businessStore: BusinessStore
    @StateObject private var locator = PickupLocationManager()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL

    @State private var position: MapCameraPosition = .region(KnightMapView.campusRegion)
    @State private var selectedID: String?
    @State private var filter: MapFilter = .all
    @State private var satellite = false
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var route: MKRoute?
    @State private var routeKitchenID: String?
    @State private var routeError: String?
    @State private var isRouting = false
    @State private var showHours = false
    @State private var detailBag: SurpriseBag?
    @State private var now = Date()
    /// Manual campus-area fallback when location permission is unavailable.
    @AppStorage("knightmap.fallbackSpot") private var fallbackSpot = PickupLocation.campusSpots[0].address

    static let campusRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 28.6030, longitude: -81.2012),
        span: MKCoordinateSpan(latitudeDelta: 0.0175, longitudeDelta: 0.0175)
    )

    var body: some View {
        let snapshots = KnightMapData.snapshots(
            store: businessStore,
            extraReservations: activeReservations,
            passToken: student.verificationToken,
            now: now
        )
        let shown = snapshots.filter { filter.matches($0) }
        let selected = snapshots.first { $0.id == selectedID }

        ZStack(alignment: .top) {
            map(shown: shown, selected: selected)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 10) {
                header(snapshots: snapshots)
                filterChips(snapshots: snapshots)
                originPill
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if selected == nil { mapControls.padding(.trailing, 14).padding(.bottom, 150) }
        }
        .overlay(alignment: .bottom) {
            bottomContent(shown: shown, selected: selected)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
        }
        .background(KnightTheme.paper)
        .task {
            // Keeps open / closed and "closes in" current while the map is on screen.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                now = Date()
            }
        }
        .onAppear {
            if locator.authorizationStatus == .authorizedWhenInUse || locator.authorizationStatus == .authorizedAlways {
                locator.requestCurrentLocation()
            }
        }
        .onChange(of: selectedID) { _, _ in
            showHours = false
            routeError = nil
            if routeKitchenID != selectedID {
                route = nil
                routeKitchenID = nil
            }
        }
        .sheet(item: $detailBag) { bag in
            BagDetailView(bag: withDistance(businessStore.liveBag(id: bag.id) ?? bag)) {
                reserve(bag)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: Map

    private func map(shown: [KitchenSnapshot], selected: KitchenSnapshot?) -> some View {
        Map(position: $position) {
            UserAnnotation()

            if usesFallbackOrigin {
                Annotation("Starting point", coordinate: origin.coordinate) {
                    FallbackOriginDot()
                }
                .annotationTitles(.hidden)
            }

            if let route, routeKitchenID == selected?.id {
                MapPolyline(route.polyline)
                    .stroke(.white, style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
                MapPolyline(route.polyline)
                    .stroke(KnightTheme.goldDeep, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
            }

            ForEach(shown) { snapshot in
                Annotation(snapshot.kitchen.name, coordinate: snapshot.kitchen.coordinate, anchor: .bottom) {
                    Button {
                        select(snapshot)
                    } label: {
                        KitchenMarker(snapshot: snapshot, isSelected: snapshot.id == selectedID)
                    }
                    .buttonStyle(.plain)
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(satellite
            ? .hybrid(elevation: .flat, pointsOfInterest: .excludingAll)
            : .standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            visibleRegion = context.region
        }
    }

    // MARK: Top

    private func header(snapshots: [KitchenSnapshot]) -> some View {
        let open = snapshots.filter { $0.status.isOpen }.count
        let withBags = snapshots.filter { $0.availability.hasBags }.count
        return VStack(alignment: .leading, spacing: 6) {
            KnightSaverBrandBar()
            HStack(alignment: .firstTextBaseline) {
                Text("KnightMap")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundStyle(KnightTheme.ink)
                Spacer()
                HStack(spacing: 10) {
                    Label("\(open) open", systemImage: "clock.fill")
                    Label("\(withBags) with bags", systemImage: "bag.fill")
                }
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(KnightTheme.muted)
                .labelStyle(TightLabelStyle())
            }
        }
        .padding(.horizontal, KnightTheme.screenPadding)
        .padding(.bottom, 10)
        .background {
            LinearGradient(
                colors: [KnightTheme.paper, KnightTheme.paper, KnightTheme.paper.opacity(0.92), KnightTheme.paper.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .padding(.bottom, -18)
            .ignoresSafeArea(edges: .top)
        }
    }

    private func filterChips(snapshots: [KitchenSnapshot]) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(MapFilter.options) { option in
                    let count = snapshots.filter { option.matches($0) }.count
                    Button {
                        withAnimation(reduceMotion ? nil : .snappy) {
                            filter = option
                            if let selectedID, !snapshots.contains(where: { $0.id == selectedID && option.matches($0) }) {
                                self.selectedID = nil
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: option.icon)
                                .font(.system(size: 12, weight: .bold))
                            Text(option.title)
                            if option != .all {
                                Text("\(count)")
                                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(filter == option ? KnightTheme.onAccent.opacity(0.12) : KnightTheme.line.opacity(0.7), in: Capsule())
                            }
                        }
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(filter == option ? KnightTheme.onAccent : KnightTheme.ink)
                        .padding(.horizontal, 13)
                        .frame(height: 38)
                        .background(filter == option ? KnightTheme.gold : KnightTheme.surface, in: Capsule())
                        .overlay(Capsule().stroke(KnightTheme.line, lineWidth: filter == option ? 0 : 1))
                        .shadow(color: KnightTheme.shadow, radius: 8, y: 3)
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(filter == option ? "Selected" : "")
                }
            }
            .padding(.horizontal, KnightTheme.screenPadding)
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
    }

    /// Where distances and routes start from. Shows the manual fallback when location is off.
    @ViewBuilder
    private var originPill: some View {
        if usesFallbackOrigin {
            HStack(spacing: 8) {
                Menu {
                    ForEach(PickupLocation.campusSpots) { spot in
                        Button(spot.address) { fallbackSpot = spot.address }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "figure.walk")
                        Text("From \(PickupLocation.matching(fallbackSpot).name)")
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .heavy))
                    }
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(KnightTheme.ink)
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(KnightTheme.surface, in: Capsule())
                    .shadow(color: KnightTheme.shadow, radius: 6, y: 2)
                }
                .accessibilityLabel("Starting point, \(PickupLocation.matching(fallbackSpot).name). Change")

                if locator.authorizationStatus != .denied && locator.authorizationStatus != .restricted {
                    Button {
                        locator.requestCurrentLocation()
                    } label: {
                        Label(locator.isLocating ? "Locating…" : "Use my location", systemImage: "location.fill")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(KnightTheme.goldDeep)
                            .padding(.horizontal, 12)
                            .frame(height: 34)
                            .background(KnightTheme.surface, in: Capsule())
                            .shadow(color: KnightTheme.shadow, radius: 6, y: 2)
                    }
                    .buttonStyle(.plain)
                    .disabled(locator.isLocating)
                } else {
                    Text("Location is off")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(KnightTheme.muted)
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                        .background(KnightTheme.surface.opacity(0.9), in: Capsule())
                }
            }
            .padding(.horizontal, KnightTheme.screenPadding)
        }
    }

    // MARK: Controls

    private var mapControls: some View {
        VStack(spacing: 0) {
            MapRoundButton(icon: "location.fill", label: "Show my location") {
                if let location = locator.currentLocation {
                    move(to: .region(MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 700, longitudinalMeters: 700)))
                } else {
                    locator.requestCurrentLocation()
                }
            }
            Divider().frame(width: 30)
            MapRoundButton(icon: "scope", label: "Back to campus") {
                move(to: .region(Self.campusRegion))
            }
            Divider().frame(width: 30)
            MapRoundButton(icon: satellite ? "map.fill" : "globe.americas.fill", label: satellite ? "Map view" : "Satellite view") {
                satellite.toggle()
            }
        }
        .background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: KnightTheme.shadow, radius: 10, y: 4)
    }

    // MARK: Bottom

    @ViewBuilder
    private func bottomContent(shown: [KitchenSnapshot], selected: KitchenSnapshot?) -> some View {
        if let selected {
            KitchenCard(
                snapshot: selected,
                now: now,
                distance: origin.distance(from: CLLocation(latitude: selected.destination.latitude, longitude: selected.destination.longitude)),
                route: routeKitchenID == selected.id ? route : nil,
                isRouting: isRouting,
                routeError: routeError,
                showHours: $showHours,
                onClose: { withAnimation(reduceMotion ? nil : .snappy) { selectedID = nil } },
                onViewBag: { detailBag = selected.bag },
                onDirections: { Task { await fetchRoute(to: selected) } },
                onAppleMaps: { openInAppleMaps(selected) },
                onGoogleMaps: { openInGoogleMaps(selected) },
                onManageReservation: onManageReservation
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else if shown.isEmpty {
            EmptyMapNotice(
                title: "No kitchens match “\(filter.title)”",
                detail: filter == .openNow ? "Everything nearby is closed right now. Check the hours on any kitchen." : "Try another filter.",
                action: "Show all"
            ) {
                withAnimation(reduceMotion ? nil : .snappy) { filter = .all }
            }
        } else if let region = visibleRegion, !shown.contains(where: { region.contains($0.kitchen.coordinate) }) {
            EmptyMapNotice(
                title: "No kitchens in this area",
                detail: "KnightSaver kitchens are on UCF Main Campus.",
                action: "Back to campus"
            ) {
                move(to: .region(Self.campusRegion))
            }
        } else {
            NearbyStrip(snapshots: sorted(shown), now: now, distance: distance(to:)) { select($0) }
        }
    }

    // MARK: Actions

    private func select(_ snapshot: KitchenSnapshot) {
        withAnimation(reduceMotion ? nil : .snappy) {
            selectedID = snapshot.id
        }
        // Keep the marker above the card.
        let center = CLLocationCoordinate2D(
            latitude: snapshot.kitchen.latitude - 0.0022,
            longitude: snapshot.kitchen.longitude
        )
        move(to: .region(MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 0.009, longitudeDelta: 0.009))))
    }

    private func move(to newPosition: MapCameraPosition) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.45)) {
            position = newPosition
        }
    }

    private func fetchRoute(to snapshot: KitchenSnapshot) async {
        isRouting = true
        routeError = nil
        defer { isRouting = false }

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: snapshot.destination))
        request.transportType = .walking

        do {
            let response = try await MKDirections(request: request).calculate()
            guard let first = response.routes.first, selectedID == snapshot.id else { return }
            route = first
            routeKitchenID = snapshot.id
            let rect = first.polyline.boundingMapRect
            // Pad more at the bottom so the card doesn't cover the route.
            let padded = MKMapRect(
                x: rect.minX - rect.width * 0.35,
                y: rect.minY - rect.height * 0.5,
                width: rect.width * 1.7,
                height: rect.height * 2.4
            )
            move(to: .rect(padded))
        } catch {
            routeError = "Couldn't load a walking route. Apple Maps can still guide you."
        }
    }

    private func mapItem(for snapshot: KitchenSnapshot) -> MKMapItem {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: snapshot.destination))
        item.name = snapshot.bag?.location ?? snapshot.kitchen.name
        return item
    }

    private func openInAppleMaps(_ snapshot: KitchenSnapshot) {
        mapItem(for: snapshot).openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }

    private func openInGoogleMaps(_ snapshot: KitchenSnapshot) {
        let destination = "\(snapshot.destination.latitude),\(snapshot.destination.longitude)"
        if let url = URL(string: "https://www.google.com/maps/dir/?api=1&destination=\(destination)&travelmode=walking") {
            openURL(url)
        }
    }

    private func reserve(_ bag: SurpriseBag) {
        if businessStore.isLiveBag(bag) {
            businessStore.reserve(bagID: bag.id, studentName: student.displayName, passToken: student.verificationToken)
        } else if bag.availableCount > 0 {
            activeReservations.append(ActiveReservation(
                bag: bag,
                status: .confirmed,
                paymentStatus: "Payment authorized",
                attentionMessage: "Your pickup is ready"
            ))
        }
    }

    // MARK: Origin and distance

    private var usesFallbackOrigin: Bool { locator.currentLocation == nil }

    private var origin: CLLocation {
        if let location = locator.currentLocation { return location }
        let spot = PickupLocation.matching(fallbackSpot)
        return CLLocation(latitude: spot.latitude, longitude: spot.longitude)
    }

    private func distance(to snapshot: KitchenSnapshot) -> CLLocationDistance {
        origin.distance(from: snapshot.kitchen.location)
    }

    private func withDistance(_ bag: SurpriseBag) -> SurpriseBag {
        var resolved = bag
        resolved.distance = origin.distance(from: CLLocation(latitude: bag.latitude, longitude: bag.longitude)) / 1_609.344
        return resolved
    }

    /// Bags first, then open kitchens, then closest.
    private func sorted(_ snapshots: [KitchenSnapshot]) -> [KitchenSnapshot] {
        snapshots.sorted { a, b in
            if a.hasReservation != b.hasReservation { return a.hasReservation }
            if a.availability.hasBags != b.availability.hasBags { return a.availability.hasBags }
            if a.status.isOpen != b.status.isOpen { return a.status.isOpen }
            return distance(to: a) < distance(to: b)
        }
    }
}

// MARK: - Filters

enum MapFilter: Hashable, Identifiable {
    case all
    case openNow
    case hasBags
    case kind(KitchenKind)

    static let options: [MapFilter] = [.all, .openNow, .hasBags] + KitchenKind.allCases.map { MapFilter.kind($0) }

    var id: String { title }

    var title: String {
        switch self {
        case .all: "All"
        case .openNow: "Open now"
        case .hasBags: "Has bags"
        case .kind(let kind): kind.rawValue
        }
    }

    var icon: String {
        switch self {
        case .all: "square.grid.2x2.fill"
        case .openNow: "clock.fill"
        case .hasBags: "bag.fill"
        case .kind(let kind): kind.icon
        }
    }

    func matches(_ snapshot: KitchenSnapshot) -> Bool {
        switch self {
        case .all: true
        case .openNow: snapshot.status.isOpen
        case .hasBags: snapshot.availability.hasBags
        case .kind(let kind): snapshot.kitchen.kind == kind
        }
    }
}

private extension MKCoordinateRegion {
    func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        abs(coordinate.latitude - center.latitude) <= span.latitudeDelta / 2
            && abs(coordinate.longitude - center.longitude) <= span.longitudeDelta / 2
    }
}

// MARK: - Marker

/// A kitchen's logo on the map. Its state is shown with a shape (count, lock, pause, moon),
/// never by color alone.
struct KitchenMarker: View {
    let snapshot: KitchenSnapshot
    let isSelected: Bool

    private var size: CGFloat { isSelected ? 48 : 38 }
    private var dimmed: Bool {
        switch snapshot.availability {
        case .closed, .paused, .fullyReserved: true
        default: false
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                KitchenLogo(kitchen: snapshot.kitchen, size: size)
                    .saturation(dimmed ? 0.25 : 1)
                    .padding(3)
                    .background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: size * 0.36, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: size * 0.36, style: .continuous)
                            .stroke(snapshot.hasReservation ? KnightTheme.gold : (isSelected ? KnightTheme.ink : .clear), lineWidth: 3)
                    }
                    .shadow(color: .black.opacity(0.22), radius: 6, y: 3)

                badge
                    .offset(x: 9, y: -9)
            }

            Triangle()
                .fill(snapshot.hasReservation ? KnightTheme.gold : KnightTheme.surface)
                .frame(width: 14, height: 8)
                .shadow(color: .black.opacity(0.12), radius: 2, y: 2)

        }
        // The label hangs below the tip, so the tip stays on the kitchen's coordinate.
        .overlay(alignment: .bottom) {
            if isSelected || snapshot.hasReservation {
                Text(snapshot.hasReservation ? "Your pickup" : snapshot.kitchen.name)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(snapshot.hasReservation ? KnightTheme.onAccent : KnightTheme.ink)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(snapshot.hasReservation ? KnightTheme.gold : KnightTheme.surface, in: Capsule())
                    .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
                    .fixedSize()
                    .alignmentGuide(.bottom) { dimensions in dimensions[.top] - 3 }
            }
        }
        .animation(.snappy, value: isSelected)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(snapshot.kitchen.name), \(snapshot.availability.label), \(MapFormat.status(snapshot.status))\(snapshot.hasReservation ? ", your reservation" : "")")
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var badge: some View {
        switch snapshot.availability {
        case .available(let count):
            Text("\(count)")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .frame(minWidth: 22, minHeight: 22)
                .padding(.horizontal, count > 9 ? 4 : 0)
                .background(KnightTheme.green, in: Capsule())
                .overlay(Capsule().stroke(KnightTheme.surface, lineWidth: 2))
        default:
            if let icon = snapshot.availability.badgeIcon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(KnightTheme.night.opacity(0.85), in: Circle())
                    .overlay(Circle().stroke(KnightTheme.surface, lineWidth: 2))
            }
        }
    }
}

struct KitchenLogo: View {
    let kitchen: CampusKitchen
    let size: CGFloat

    var body: some View {
        if let brand = kitchen.brand {
            BrandMark(brand: brand, size: size)
        } else {
            Text(kitchen.monogram)
                .font(.system(size: size * 0.42, weight: .black, design: .rounded))
                .foregroundStyle(kitchen.ink)
                .frame(width: size, height: size)
                .background(kitchen.tint, in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                        .stroke(.white.opacity(0.4), lineWidth: 1)
                }
                .accessibilityHidden(true)
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct FallbackOriginDot: View {
    var body: some View {
        ZStack {
            Circle().fill(KnightTheme.gold.opacity(0.25)).frame(width: 34, height: 34)
            Circle().fill(KnightTheme.night).frame(width: 16, height: 16)
                .overlay(Circle().stroke(.white, lineWidth: 3))
        }
        .accessibilityLabel("Your starting point")
    }
}

private struct MapRoundButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(KnightTheme.ink)
                .frame(width: 46, height: 46)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

private struct TightLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon.font(.system(size: 10, weight: .bold))
            configuration.title
        }
    }
}

// MARK: - Nearby strip (nothing selected)

private struct NearbyStrip: View {
    let snapshots: [KitchenSnapshot]
    let now: Date
    let distance: (KitchenSnapshot) -> CLLocationDistance
    let onSelect: (KitchenSnapshot) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(snapshots) { snapshot in
                    Button {
                        onSelect(snapshot)
                    } label: {
                        HStack(spacing: 10) {
                            KitchenLogo(kitchen: snapshot.kitchen, size: 42)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(snapshot.kitchen.name)
                                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                                    .foregroundStyle(KnightTheme.ink)
                                    .lineLimit(1)
                                StatusDotText(status: snapshot.status, now: now, compact: true)
                                HStack(spacing: 4) {
                                    Image(systemName: snapshot.availability.hasBags ? "bag.fill" : (snapshot.availability.badgeIcon ?? "bag"))
                                    Text(snapshot.availability.label)
                                    Text("·")
                                    Text("~\(MapFormat.estimatedWalkMinutes(distance(snapshot))) min")
                                }
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(snapshot.availability.hasBags ? KnightTheme.green : KnightTheme.muted)
                                .lineLimit(1)
                            }
                        }
                        .padding(12)
                        .frame(width: 236, alignment: .leading)
                        .background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(snapshot.hasReservation ? KnightTheme.gold : KnightTheme.line, lineWidth: snapshot.hasReservation ? 2 : 1)
                        }
                        .shadow(color: KnightTheme.shadow, radius: 10, y: 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .scrollIndicators(.hidden)
    }
}

private struct StatusDotText: View {
    let status: KitchenStatus
    let now: Date
    var compact = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: status.isOpen ? "circle.fill" : "moon.fill")
                .font(.system(size: status.isOpen ? 7 : 9, weight: .bold))
            Text(MapFormat.status(status, now: now))
                .lineLimit(1)
        }
        .font(.system(size: compact ? 11 : 13, weight: .bold))
        .foregroundStyle(status.isOpen ? KnightTheme.green : KnightTheme.muted)
    }
}

private struct EmptyMapNotice: View {
    let title: String
    let detail: String
    let action: String
    let onAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(KnightTheme.goldDeep)
                .frame(width: 40, height: 40)
                .background(KnightTheme.gold.opacity(0.2), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(KnightTheme.ink)
                Text(detail)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(KnightTheme.muted)
            }
            Spacer(minLength: 4)
            Button(action, action: onAction)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(KnightTheme.onAccent)
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(KnightTheme.gold, in: Capsule())
                .buttonStyle(.plain)
        }
        .padding(14)
        .background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: KnightTheme.shadow, radius: 12, y: 4)
    }
}

// MARK: - Selected kitchen card

private struct KitchenCard: View {
    let snapshot: KitchenSnapshot
    let now: Date
    let distance: CLLocationDistance
    let route: MKRoute?
    let isRouting: Bool
    let routeError: String?
    @Binding var showHours: Bool
    let onClose: () -> Void
    let onViewBag: () -> Void
    let onDirections: () -> Void
    let onAppleMaps: () -> Void
    let onGoogleMaps: () -> Void
    let onManageReservation: () -> Void

    private var kitchen: CampusKitchen { snapshot.kitchen }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(KnightTheme.line)
                .frame(width: 38, height: 5)
                .padding(.top, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    titleRow
                    statusRow
                    if snapshot.hasReservation { reservationBanner }
                    bagRow
                    walkRow
                    actions
                    hoursToggle
                    if showHours {
                        WeekHoursView(hours: kitchen.hours, now: now)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 16)
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: showHours ? 560 : 380)
            .fixedSize(horizontal: false, vertical: !showHours)
        }
        .background(KnightTheme.paper, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(KnightTheme.line, lineWidth: 1)
        }
        .shadow(color: KnightTheme.shadow, radius: 20, y: 6)
    }

    private var titleRow: some View {
        HStack(alignment: .top, spacing: 12) {
            KitchenLogo(kitchen: kitchen, size: 54)
            VStack(alignment: .leading, spacing: 3) {
                Text(kitchen.name)
                    .font(.system(size: 21, weight: .black, design: .rounded))
                    .foregroundStyle(KnightTheme.ink)
                    .lineLimit(2)
                HStack(spacing: 5) {
                    Image(systemName: kitchen.kind.icon)
                    Text("\(kitchen.kind.singular) · \(kitchen.building)")
                        .lineLimit(1)
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(KnightTheme.muted)
                HStack(spacing: 3) {
                    Image(systemName: "star.fill").foregroundStyle(KnightTheme.goldDeep)
                    Text(String(format: "%.1f", kitchen.rating))
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(KnightTheme.ink)
                .accessibilityLabel(String(format: "Rated %.1f", kitchen.rating))
            }
            Spacer(minLength: 0)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(KnightTheme.muted)
                    .frame(width: 32, height: 32)
                    .background(KnightTheme.line.opacity(0.6), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
    }

    private var statusRow: some View {
        HStack(spacing: 8) {
            StatusDotText(status: snapshot.status, now: now)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background((snapshot.status.isOpen ? KnightTheme.green : KnightTheme.muted).opacity(0.12), in: Capsule())
            HStack(spacing: 5) {
                Image(systemName: snapshot.availability.hasBags ? "bag.fill" : (snapshot.availability.badgeIcon ?? "bag"))
                Text(snapshot.availability.label)
            }
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(snapshot.availability.hasBags ? KnightTheme.goldDeep : KnightTheme.muted)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(KnightTheme.surface, in: Capsule())
            .overlay(Capsule().stroke(KnightTheme.line, lineWidth: 1))
        }
    }

    private var reservationBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "ticket.fill")
                .foregroundStyle(KnightTheme.onAccent)
                .frame(width: 34, height: 34)
                .background(KnightTheme.gold, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text("Your pickup is here")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                Text("Show your Knight Pass at the counter.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(KnightTheme.muted)
            }
            Spacer()
            Button("Manage", action: onManageReservation)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(KnightTheme.ink)
                .buttonStyle(.plain)
        }
        .padding(10)
        .background(KnightTheme.gold.opacity(0.16), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var bagRow: some View {
        if let bag = snapshot.bag {
            HStack(spacing: 12) {
                Image(systemName: "bag.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(KnightTheme.goldDeep)
                    .frame(width: 36, height: 36)
                    .background(KnightTheme.gold.opacity(0.2), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Surprise Bag · \(bag.formattedPrice)")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(KnightTheme.ink)
                    Text("Pickup \(bag.pickupWindow) · \(bag.availabilityText)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(KnightTheme.muted)
                    if snapshot.pickupDiffersFromKitchen {
                        Label("Pickup at \(bag.location)", systemImage: "mappin.and.ellipse")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(KnightTheme.goldDeep)
                    }
                }
                Spacer(minLength: 0)
            }
        } else {
            HStack(spacing: 10) {
                Image(systemName: "bell.badge")
                    .foregroundStyle(KnightTheme.goldDeep)
                Text(kitchen.usualDrop)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(KnightTheme.muted)
            }
        }
    }

    private var walkRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "figure.walk")
                    .font(.system(size: 15, weight: .bold))
                if let route {
                    Text("\(Int((route.expectedTravelTime / 60).rounded(.up))) min walk")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                    Text(MapFormat.distance(route.distance))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(KnightTheme.muted)
                } else {
                    Text("~\(MapFormat.estimatedWalkMinutes(distance)) min walk")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                    Text(MapFormat.distance(distance))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(KnightTheme.muted)
                }
            }
            .foregroundStyle(KnightTheme.ink)

            if let route, let bag = snapshot.bag, let line = LeaveBy.line(for: bag, travel: route.expectedTravelTime, now: now) {
                Label(line.text, systemImage: line.reachable ? "clock.badge.checkmark" : "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(line.reachable ? KnightTheme.green : KnightTheme.red)
            }
            if let routeError {
                Label(routeError, systemImage: "wifi.exclamationmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(KnightTheme.red)
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 10) {
            if snapshot.bag != nil {
                Button(action: onViewBag) {
                    Text("View Surprise Bag")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundStyle(KnightTheme.onAccent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(KnightTheme.gold, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            if route == nil {
                Button(action: onDirections) {
                    HStack(spacing: 6) {
                        if isRouting {
                            ProgressView().tint(KnightTheme.paper)
                        } else {
                            Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        }
                        Text("Directions")
                    }
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(KnightTheme.paper)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(KnightTheme.ink, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isRouting)
                .accessibilityLabel("Get directions")
            } else {
                Menu {
                    Button("Apple Maps", systemImage: "map", action: onAppleMaps)
                    Button("Google Maps", systemImage: "globe", action: onGoogleMaps)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "location.north.line.fill")
                        Text("Start walking")
                    }
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(KnightTheme.paper)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(KnightTheme.ink, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }

    private var hoursToggle: some View {
        Button {
            withAnimation(.snappy) { showHours.toggle() }
        } label: {
            HStack {
                Image(systemName: "calendar")
                Text("Hours this week")
                Spacer()
                Text(MapFormat.span(kitchen.hours.span(weekday: Calendar.current.component(.weekday, from: now))))
                    .foregroundStyle(KnightTheme.muted)
                Image(systemName: "chevron.down")
                    .rotationEffect(.degrees(showHours ? 180 : 0))
            }
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(KnightTheme.ink)
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(KnightTheme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityValue(showHours ? "Expanded" : "Collapsed")
    }
}

// MARK: - Leave by

enum LeaveBy {
    struct Line {
        let text: String
        let reachable: Bool
    }

    /// Uses only the current time, the walking route and the pickup interval (student.md).
    static func line(for bag: SurpriseBag, travel: TimeInterval, now: Date) -> Line? {
        guard let start = bag.pickupStart else { return nil }
        let end = bag.pickupEnd ?? start.addingTimeInterval(30 * 60)
        let leaveBy = start.addingTimeInterval(-travel)
        let arrival = now.addingTimeInterval(travel)
        let day = Calendar.current.isDateInToday(start) ? "" : " tomorrow"

        if now < leaveBy {
            return Line(text: "Leave by \(MapFormat.time(leaveBy))\(day) to arrive as pickup opens", reachable: true)
        }
        if arrival <= end {
            return Line(text: "Leave now · you'd arrive \(MapFormat.time(arrival)), before pickup ends", reachable: true)
        }
        return Line(text: "Pickup ends \(MapFormat.time(end)), before you'd arrive", reachable: false)
    }
}

// MARK: - Week hours

/// Each day as a bar from 6 AM to 2 AM, so late nights and early mornings are easy to compare.
/// Today is highlighted and shows a "now" needle.
struct WeekHoursView: View {
    let hours: WeeklyHours
    let now: Date

    private static let windowStart = 6 * 60
    private static let windowEnd = 26 * 60

    private var todayWeekday: Int { Calendar.current.component(.weekday, from: now) }

    private var nowMinutes: Int {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: now)
        let minutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        return minutes < Self.windowStart ? minutes + 1_440 : minutes
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("6 AM")
                Spacer()
                Text("Noon")
                Spacer()
                Text("6 PM")
                Spacer()
                Text("2 AM")
            }
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(KnightTheme.muted)
            .padding(.leading, 46)
            .padding(.trailing, 2)

            ForEach(WeeklyHours.displayOrder, id: \.self) { weekday in
                row(weekday: weekday)
            }
        }
        .padding(14)
        .background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(KnightTheme.line, lineWidth: 1))
    }

    private func row(weekday: Int) -> some View {
        let isToday = weekday == todayWeekday
        let span = hours.span(weekday: weekday)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Text(MapFormat.weekday(weekday))
                    .font(.system(size: 13, weight: isToday ? .black : .semibold, design: .rounded))
                    .foregroundStyle(isToday ? KnightTheme.onAccent : KnightTheme.ink)
                    .frame(width: 36, height: 22)
                    .background(isToday ? KnightTheme.gold : .clear, in: Capsule())

                GeometryReader { proxy in
                    let width = proxy.size.width
                    let total = CGFloat(Self.windowEnd - Self.windowStart)
                    ZStack(alignment: .leading) {
                        Capsule().fill(KnightTheme.line.opacity(0.55))
                        if let span {
                            let start = CGFloat(max(span.open, Self.windowStart) - Self.windowStart) / total * width
                            let end = CGFloat(min(span.close, Self.windowEnd) - Self.windowStart) / total * width
                            Capsule()
                                .fill(isToday ? KnightTheme.green : KnightTheme.green.opacity(0.55))
                                .frame(width: max(end - start, 6))
                                .offset(x: start)
                        }
                        if isToday, nowMinutes <= Self.windowEnd {
                            let x = CGFloat(nowMinutes - Self.windowStart) / total * width
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(KnightTheme.ink)
                                .frame(width: 3, height: 16)
                                .offset(x: x - 1.5)
                        }
                    }
                    .frame(height: 10)
                    .frame(maxHeight: .infinity)
                }
                .frame(height: 16)
            }
            Text(MapFormat.span(span))
                .font(.system(size: 11, weight: isToday ? .bold : .medium))
                .foregroundStyle(span == nil ? KnightTheme.red : KnightTheme.muted)
                .padding(.leading, 46)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Calendar.current.weekdaySymbols[weekday - 1])\(isToday ? ", today" : ""): \(MapFormat.span(span))")
    }
}
