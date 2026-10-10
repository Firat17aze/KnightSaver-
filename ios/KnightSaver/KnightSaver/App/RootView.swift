import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case explore = "Explore"
    case map = "Map"
    case impact = "Impact"
    case business = "Business"
    case profile = "Profile"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .explore: "safari"
        case .map: "map"
        case .impact: "leaf"
        case .business: "storefront"
        case .profile: "person"
        }
    }

    var selectedIcon: String {
        switch self {
        case .explore: "safari.fill"
        case .map: "map.fill"
        case .impact: "leaf.fill"
        case .business: "storefront.fill"
        case .profile: "person.fill"
        }
    }

    static func available(for role: AccountRole) -> [AppTab] {
        role == .business ? allCases : allCases.filter { $0 != .business }
    }
}

struct RootView: View {
    @StateObject private var sessionStore = SessionStore()
    @State private var selectedTab: AppTab = .explore
    /// Reservations for the sample restaurants only. Reservations for bags published from
    /// Business live in `businessStore` and are merged in by Explore and Profile.
    @State private var activeReservations: [ActiveReservation] = []
    /// One shared store for Business and the student side. Created once here, so it survives
    /// tab switches, and Explore, bag details, Profile and Business all see the same data.
    @StateObject private var businessStore = BusinessStore.demo()
    @State private var showKnightPass = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if let account = sessionStore.account {
                authenticatedApp(account: account)
            } else {
                AuthenticationView(store: sessionStore)
            }
        }
        .tint(KnightTheme.ink)
    }

    private func authenticatedApp(account: AppAccount) -> some View {
        ZStack {
            ZStack {
                KnightTheme.paper.ignoresSafeArea()

                Group {
                    switch selectedTab {
                    case .explore:
                        ExploreView(activeReservations: $activeReservations, student: account.knightPass)
                    case .map:
                        // When KnightMap is built, read live pins from the shared store:
                        // `businessStore.mapPins` (bag + latitude/longitude), not sample data.
                        PlaceholderView(title: "KnightMap", subtitle: "Live campus pickup locations will appear here.", icon: "map.fill")
                    case .impact:
                        PlaceholderView(title: "Your impact", subtitle: "Verified rescues and EcoKnight AI live here.", icon: "leaf.fill")
                    case .business:
                        if account.role == .business {
                            BusinessDashboardView(store: businessStore)
                        } else {
                            PlaceholderView(title: "Business access", subtitle: "An approved business account is required.", icon: "lock.fill")
                        }
                    case .profile:
                        ProfileView(
                            account: account,
                            pass: account.knightPass,
                            activeReservations: $activeReservations,
                            action: { showKnightPass = true },
                            onUpdateProfile: { name, email, phone, campus in
                                sessionStore.updateProfile(
                                    displayName: name,
                                    email: email,
                                    phoneNumber: phone,
                                    campusName: campus
                                )
                            },
                            onSignOut: {
                                showKnightPass = false
                                selectedTab = .explore
                                sessionStore.signOut()
                            }
                        )
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                KnightTabBar(selection: $selectedTab, tabs: AppTab.available(for: account.role))
            }
            .blur(radius: showKnightPass ? 12 : 0)
            .scaleEffect(!showKnightPass || reduceMotion ? 1 : 0.985)
            .allowsHitTesting(!showKnightPass)
            .accessibilityHidden(showKnightPass)

            if showKnightPass {
                KnightPassOverlay(
                    pass: account.knightPass,
                    onClose: { showKnightPass = false }
                )
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .environmentObject(businessStore)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: showKnightPass)
        .onAppear {
            if account.role == .business, let businessName = account.businessName, !businessName.isEmpty {
                businessStore.profile.name = businessName
            }
            if !AppTab.available(for: account.role).contains(selectedTab) {
                selectedTab = .explore
            }
        }
    }
}

private struct KnightTabBar: View {
    @Binding var selection: AppTab
    let tabs: [AppTab]
    @Namespace private var selectionAnimation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 2) {
            ForEach(tabs) { tab in
                Button {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.82)) {
                        selection = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: selection == tab ? tab.selectedIcon : tab.icon)
                            .font(.system(size: 18, weight: .semibold))
                        Text(tab.rawValue)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(selection == tab ? KnightTheme.onAccent : KnightTheme.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background {
                        if selection == tab {
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .fill(KnightTheme.gold)
                                .matchedGeometryEffect(id: "selected-tab", in: selectionAnimation)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.rawValue)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(KnightTheme.ink.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: KnightTheme.ink.opacity(0.12), radius: 20, x: 0, y: 8)
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(KnightTheme.paper.opacity(0.94))
    }
}

private struct PlaceholderView: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        VStack(spacing: 0) {
            KnightSaverBrandBar()
                .padding(.horizontal, KnightTheme.screenPadding)
                .padding(.top, 10)

            Spacer(minLength: 0)
            placeholderContent
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var placeholderContent: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 38, weight: .medium))
                .foregroundStyle(KnightTheme.goldDeep)
                .frame(width: 76, height: 76)
                .background(KnightTheme.gold.opacity(0.22), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            Text(title)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(KnightTheme.ink)
            Text(subtitle)
                .font(.system(size: 16))
                .foregroundStyle(KnightTheme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 290)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}
