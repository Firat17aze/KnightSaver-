import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case explore = "Explore"
    case impact = "Impact"
    case rewards = "Rewards"
    /// Shown as "Kitchen" in the tab bar: where restaurant staff list their surplus.
    case business = "Kitchen"
    case profile = "Profile"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .explore: "safari"
        case .impact: "leaf"
        case .rewards: "trophy"
        case .business: "storefront"
        case .profile: "person"
        }
    }

    var selectedIcon: String {
        switch self {
        case .explore: "safari.fill"
        case .impact: "leaf.fill"
        case .rewards: "trophy.fill"
        case .business: "storefront.fill"
        case .profile: "person.fill"
        }
    }

    /// Students and business owners get separate apps: students find and reserve bags,
    /// business owners run their Kitchen.
    static func available(for role: AccountRole) -> [AppTab] {
        switch role {
        case .student: [.explore, .impact, .rewards, .profile]
        case .business: [.business, .profile]
        }
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
    @State private var tabBarHeight: CGFloat = 0
    @StateObject private var profilePhotos = ProfilePhotoStore()
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
                    case .impact:
                        ImpactView(student: account.knightPass)
                    case .rewards:
                        RewardsView(student: account.knightPass)
                    case .business:
                        BusinessDashboardView(store: businessStore)
                    case .profile where account.role == .business:
                        BusinessAccountView(
                            account: account,
                            onSignOut: { signOut() }
                        )
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
                            onSignOut: { signOut() }
                        )
                    }
                }
                .environment(\.tabBarInset, tabBarHeight)
            }
            .overlay(alignment: .bottom) {
                KnightTabBar(selection: $selectedTab, tabs: AppTab.available(for: account.role))
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.height
                    } action: { height in
                        tabBarHeight = height
                    }
                    .ignoresSafeArea(.keyboard)
            }
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
        .environmentObject(sessionStore)
        .environmentObject(profilePhotos)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: showKnightPass)
        .onAppear {
            if account.role == .business, let businessName = account.businessName, !businessName.isEmpty {
                businessStore.profile.name = businessName
            }
            let tabs = AppTab.available(for: account.role)
            if !tabs.contains(selectedTab), let first = tabs.first {
                selectedTab = first
            }
        }
        .task(id: account.id) {
            if account.role == .student {
                await businessStore.refreshFromBackend()
            }
        }
    }

    private func signOut() {
        showKnightPass = false
        selectedTab = .explore
        sessionStore.signOut()
    }
}

/// The tab bar icon. Kitchen uses the custom Sprout Storefront glyph (vector assets
/// "TabKitchen" / "TabKitchenFill"); the Impact leaf is drawn a little larger.
private struct TabGlyph: View {
    let tab: AppTab
    let isSelected: Bool

    var body: some View {
        if tab == .business {
            Image(isSelected ? "TabKitchenFill" : "TabKitchen")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
                .accessibilityHidden(true)
        } else {
            Image(systemName: isSelected ? tab.selectedIcon : tab.icon)
                .font(.system(size: tab == .impact ? 22 : 18, weight: .semibold))
                .frame(height: 22)
                .accessibilityHidden(true)
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
                        TabGlyph(tab: tab, isSelected: selection == tab)
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
        .background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(KnightTheme.line, lineWidth: 1)
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(KnightTheme.paper.ignoresSafeArea(edges: .bottom))
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
                .foregroundStyle(KnightTheme.lake)
                .frame(width: 76, height: 76)
                .background(KnightTheme.lake.opacity(0.12), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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
