import SwiftUI
import UIKit

// MARK: - Theme

enum BusinessTheme {
    /// UCF gold, #FFC904
    static let gold = Color(red: 1.0, green: 0.788, blue: 0.016)
    static let pageBackground = Color(UIColor.systemGroupedBackground)
    static let cardBackground = Color(UIColor.secondarySystemGroupedBackground)
}

extension ListingStatus {
    var color: Color {
        switch self {
        case .available: return .green
        case .fullyReserved: return .orange
        case .paused: return .gray
        case .closed: return .red
        }
    }
}

// MARK: - Small shared views

struct BusinessCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BusinessTheme.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

extension View {
    func businessCard() -> some View {
        modifier(BusinessCardStyle())
    }
}

struct BusinessBadge: View {
    let text: String
    let color: Color
    var systemImage: String?

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage = systemImage {
                Image(systemName: systemImage)
            }
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.15), in: Capsule())
        .foregroundColor(color)
    }
}

struct BusinessSectionHeader: View {
    let title: String
    var detail: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.weight(.bold))
            Spacer()
            if let detail = detail {
                Text(detail)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct BusinessInfoItem: View {
    let systemImage: String
    let text: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .labelStyle(.titleAndIcon)
    }
}

struct BusinessEmptyCard: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .businessCard()
    }
}

/// A number field backed by text, so the value updates while typing
/// (a decimal pad has no Return key to "commit" a formatted TextField).
struct BusinessDecimalField: View {
    let placeholder: String
    @Binding var value: Double
    @State private var text = ""

    init(placeholder: String, value: Binding<Double>) {
        self.placeholder = placeholder
        _value = value
    }

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .onAppear {
                text = value == 0 ? "" : String(format: "%.2f", value)
            }
            .onChange(of: text) { newValue in
                let cleaned = newValue
                    .replacingOccurrences(of: ",", with: ".")
                    .replacingOccurrences(of: "$", with: "")
                    .trimmingCharacters(in: .whitespaces)
                value = Double(cleaned) ?? 0
            }
    }
}

enum BusinessKeyboard {
    static func hide() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

/// Big tappable option used in the "How do you want to…" screens.
struct BusinessMethodButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundColor(.black)
                    .frame(width: 44, height: 44)
                    .background(BusinessTheme.gold, in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .businessCard()
        }
        .buttonStyle(.plain)
    }
}
