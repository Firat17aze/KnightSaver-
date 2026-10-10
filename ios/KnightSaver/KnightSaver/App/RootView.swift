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
}

struct RootView: View {
    @State private var selectedTab: AppTab = .explore
    @State private var activeReservations: [ActiveReservation] = [.sample]
    @State private var showKnightPass = false
    private let knightPass = KnightPass.sample
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ZStack {
                KnightTheme.paper.ignoresSafeArea()

                Group {
                    switch selectedTab {
                    case .explore:
                        ExploreView(activeReservations: $activeReservations)
                    case .map:
                        PlaceholderView(title: "KnightMap", subtitle: "Live campus pickup locations will appear here.", icon: "map.fill")
                    case .impact:
                        PlaceholderView(title: "Your impact", subtitle: "Verified rescues and EcoKnight AI live here.", icon: "leaf.fill")
                    case .business:
                        PlaceholderView(title: "Business", subtitle: "Scan a Knight Pass to verify pickups for this location.", icon: "storefront.fill")
                    case .profile:
                        ProfileView(
                            pass: knightPass,
                            activeReservations: $activeReservations,
                            action: { showKnightPass = true }
                        )
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                KnightTabBar(selection: $selectedTab)
            }
            .blur(radius: showKnightPass ? 12 : 0)
            .scaleEffect(!showKnightPass || reduceMotion ? 1 : 0.985)
            .allowsHitTesting(!showKnightPass)
            .accessibilityHidden(showKnightPass)

            if showKnightPass {
                KnightPassOverlay(
                    pass: knightPass,
                    onClose: { showKnightPass = false }
                )
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .tint(KnightTheme.ink)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: showKnightPass)
    }
}

private struct KnightTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: selection == tab ? tab.selectedIcon : tab.icon)
                            .font(.system(size: 18, weight: .semibold))
                        Text(tab.rawValue)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(KnightTheme.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background {
                        if selection == tab {
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .fill(KnightTheme.gold)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
