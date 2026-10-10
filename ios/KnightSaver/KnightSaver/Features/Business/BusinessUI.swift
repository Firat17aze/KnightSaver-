import SwiftUI
import UIKit

// Small building blocks for the Business tab, styled with KnightTheme
// so it matches Explore and Profile.

extension SurpriseBagStatus {
    var tint: Color {
        switch self {
        case .available: return KnightTheme.green
        case .fullyReserved: return KnightTheme.goldDeep
        case .paused, .draft: return KnightTheme.muted
        case .closed: return KnightTheme.ink
        case .cancelled: return KnightTheme.red
        }
    }
}

extension PickupStatus {
    var tint: Color {
        switch self {
        case .authorized: return KnightTheme.green
        case .offerSent: return KnightTheme.goldDeep
        case .waitlisted: return KnightTheme.muted
        case .pickupVerified, .paymentCaptured: return KnightTheme.green
        case .cancelled, .refunded, .missed: return KnightTheme.red
        }
    }
}

struct BizCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(17)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: KnightTheme.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: KnightTheme.cardRadius, style: .continuous)
                    .stroke(KnightTheme.ink.opacity(0.07), lineWidth: 1)
            }
            .knightCardShadow()
    }
}

extension View {
    func bizCard() -> some View {
        modifier(BizCardModifier())
    }
}

struct BizSectionHeader: View {
    let title: String
    var subtitle: String?
    var trailing: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(KnightTheme.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(KnightTheme.muted)
                }
            }
            Spacer(minLength: 8)
            if let trailing {
                Text(trailing)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(KnightTheme.muted)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

struct BizChip: View {
    let text: String
    let tint: Color
    var icon: String?

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
            }
            Text(text)
                .font(.system(size: 10, weight: .bold, design: .rounded))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 9)
        .frame(minHeight: 26)
        .background(tint.opacity(0.11), in: Capsule())
    }
}

struct BizMetaRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(KnightTheme.goldDeep)
                .frame(width: 22)
                .accessibilityHidden(true)
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(KnightTheme.muted)
            Spacer(minLength: 0)
        }
    }
}

/// Gold, full-width primary action.
struct BizPrimaryLabel: View {
    let title: String
    var icon: String?

    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
            }
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
        }
        .foregroundStyle(KnightTheme.ink)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 52)
        .background(KnightTheme.gold, in: RoundedRectangle(cornerRadius: KnightTheme.controlRadius, style: .continuous))
    }
}

/// Outlined, smaller secondary action.
struct BizSecondaryLabel: View {
    let title: String
    var icon: String?

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
            }
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
        }
        .foregroundStyle(KnightTheme.ink)
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .background(KnightTheme.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(KnightTheme.line, lineWidth: 1)
        }
    }
}

/// Big option row for "Speak with AI" / "Enter manually".
struct BizMethodButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(KnightTheme.ink)
                    .frame(width: 46, height: 46)
                    .background(KnightTheme.gold, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(KnightTheme.ink)
                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(KnightTheme.muted)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(KnightTheme.goldDeep)
                    .padding(.top, 14)
            }
            .bizCard()
        }
        .buttonStyle(.plain)
    }
}

struct BizStatTile: View {
    let title: String
    let value: String
    let note: String
    var isEstimate = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(KnightTheme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if isEstimate {
                    Text("EST.")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundStyle(KnightTheme.goldDeep)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(KnightTheme.gold.opacity(0.22), in: Capsule())
                }
            }
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(KnightTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(note)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(KnightTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .padding(14)
        .background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(KnightTheme.ink.opacity(0.07), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Number field that updates while typing (a decimal pad has no Return key).
struct BizDecimalField: View {
    let placeholder: String
    @Binding var value: Double
    @State private var text = ""

    init(_ placeholder: String, value: Binding<Double>) {
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
            .onChange(of: text) { _, newValue in
                let cleaned = newValue
                    .replacingOccurrences(of: ",", with: ".")
                    .replacingOccurrences(of: "$", with: "")
                    .trimmingCharacters(in: .whitespaces)
                value = Double(cleaned) ?? 0
            }
    }
}

enum BizKeyboard {
    static func hide() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

/// Text box for dictation with the keyboard microphone.
struct BizDictationBox: View {
    let prompt: String
    @Binding var text: String
    var focus: FocusState<Bool>.Binding

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .focused(focus)
                .scrollContentBackground(.hidden)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(KnightTheme.ink)
                .padding(10)
            if text.isEmpty {
                Text(prompt)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(KnightTheme.muted.opacity(0.7))
                    .padding(.horizontal, 15)
                    .padding(.vertical, 18)
                    .allowsHitTesting(false)
            }
        }
        .frame(minHeight: 150)
        .background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(KnightTheme.line, lineWidth: 1)
        }
    }
}
