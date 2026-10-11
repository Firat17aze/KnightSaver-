import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import PassKit
import UIKit

struct KnightMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(KnightTheme.night)
            Text("K")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(KnightTheme.gold)
        }
        .frame(width: 46, height: 46)
        .accessibilityHidden(true)
    }
}

struct KnightPassButton: View {
    let pass: KnightPass
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                KnightPassCard(pass: pass, showsQRCode: false)

                Label("Tap card to flip", systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(KnightTheme.muted)
                    .padding(.horizontal, 13)
                    .frame(minHeight: 36)
                    .overlay { Capsule().stroke(KnightTheme.line, lineWidth: 1) }
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(PressScaleButtonStyle(reduceMotion: reduceMotion))
        .accessibilityLabel("Knight Pass for \(pass.displayName)")
        .accessibilityHint("Opens your reusable pickup pass and shows its verification code")
    }
}

struct KnightPassOverlay: View {
    let pass: KnightPass
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsQRCode = false
    @State private var showWalletSetupMessage = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Button(action: onClose) {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                }
                .buttonStyle(.plain)
                .accessibilityHidden(true)

                VStack(spacing: 18) {
                    Spacer(minLength: max(proxy.safeAreaInsets.top + 48, 68))

                    Button {
                        flipCard()
                    } label: {
                        ZStack {
                            KnightPassCard(pass: pass, showsQRCode: false)
                                .opacity(showsQRCode ? 0 : 1)
                                .rotation3DEffect(
                                    .degrees(showsQRCode ? -180 : 0),
                                    axis: (x: 0, y: 1, z: 0),
                                    perspective: 0.72
                                )

                            KnightPassCard(pass: pass, showsQRCode: true)
                                .opacity(showsQRCode ? 1 : 0)
                                .rotation3DEffect(
                                    .degrees(showsQRCode ? 0 : 180),
                                    axis: (x: 0, y: 1, z: 0),
                                    perspective: 0.72
                                )
                        }
                    }
                    .buttonStyle(PressScaleButtonStyle(reduceMotion: reduceMotion))
                    .accessibilityLabel(showsQRCode
                        ? "Knight Pass code for \(pass.displayName)"
                        : "Knight Pass for \(pass.displayName)")
                    .accessibilityHint(showsQRCode ? "Shows the front of the card" : "Shows the QR code")

                    if showsQRCode {
                        AppleWalletAddButton {
                            showWalletSetupMessage = true
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    Spacer(minLength: max(proxy.safeAreaInsets.bottom, 24))
                }
                .frame(maxWidth: 420)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(.white.opacity(0.15), in: Circle())
                        .overlay {
                            Circle().stroke(.white.opacity(0.22), lineWidth: 1)
                        }
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close Knight Pass")
                .accessibilityHint("Returns to Profile")
                .padding(.top, max(proxy.safeAreaInsets.top, 12))
                .padding(.trailing, 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
        .onAppear {
            if reduceMotion {
                showsQRCode = true
            } else {
                DispatchQueue.main.async {
                    withAnimation(.spring(response: 0.52, dampingFraction: 0.84)) {
                        showsQRCode = true
                    }
                }
            }
        }
        .alert("Apple Wallet setup required", isPresented: $showWalletSetupMessage) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The reusable Knight Pass is ready for a signed Wallet pass. Connect KnightSaver’s pass service and Apple Developer pass certificate to enable adding it.")
        }
    }

    private func flipCard() {
        withAnimation(reduceMotion ? nil : .spring(response: 0.52, dampingFraction: 0.84)) {
            showsQRCode.toggle()
        }
    }
}

struct KnightPassCard: View {
    let pass: KnightPass
    let showsQRCode: Bool

    var body: some View {
        Group {
            if showsQRCode {
                verificationFace
                    .alwaysLight()
            } else {
                knightroFace
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1.586, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(showsQRCode ? 0.5 : 0.14), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.22), radius: 22, x: 0, y: 12)
        .accessibilityElement(children: .ignore)
    }

    private var knightroFace: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.055, green: 0.053, blue: 0.05),
                        Color(red: 0.14, green: 0.125, blue: 0.095)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .stroke(KnightTheme.gold.opacity(0.14), lineWidth: 1)
                    .frame(width: proxy.size.width * 0.72)
                    .offset(x: proxy.size.width * 0.44, y: -proxy.size.height * 0.42)

                VStack(alignment: .leading, spacing: 0) {
                    Text("KNIGHTSAVER")
                        .font(.system(size: 13, weight: .semibold, design: .default))
                        .tracking(2.2)
                        .foregroundStyle(KnightTheme.gold)

                    Spacer()

                    HStack(alignment: .bottom) {
                        Text(pass.displayName.uppercased())
                            .font(.system(size: 13, weight: .medium, design: .default))
                            .tracking(1.5)
                            .foregroundStyle(.white)

                        Spacer()

                        Image("KnightLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 74, height: 74)
                            .accessibilityHidden(true)
                    }
                }
                .padding(18)
            }
        }
    }

    private var verificationFace: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [Color.white, KnightTheme.paper],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(spacing: 8) {
                    Spacer(minLength: 10)

                    QRCodeView(value: pass.verificationPayload)
                        .frame(
                            width: min(proxy.size.height * 0.62, 136),
                            height: min(proxy.size.height * 0.62, 136)
                        )
                        .padding(7)
                        .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    Text(pass.displayName.uppercased())
                        .font(.system(size: 11, weight: .semibold, design: .default))
                        .tracking(1.4)
                        .foregroundStyle(KnightTheme.ink)

                    Text(pass.memberID)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(KnightTheme.muted)

                    Spacer(minLength: 10)
                }
            }
        }
    }
}

struct ReservationPassStack: View {
    let reservations: [ActiveReservation]
    let onSelect: (ActiveReservation) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var visibleReservations: [ActiveReservation] {
        Array(reservations.prefix(3))
    }

    var body: some View {
        ZStack(alignment: .top) {
            ForEach(Array(visibleReservations.enumerated()).reversed(), id: \.element.id) { index, reservation in
                Button {
                    onSelect(reservation)
                } label: {
                    PickupPassCard(reservation: reservation, showsQRCode: false)
                }
                .buttonStyle(PressScaleButtonStyle(reduceMotion: reduceMotion))
                .scaleEffect(1 - CGFloat(index) * 0.026, anchor: .top)
                .offset(y: CGFloat(index) * 15)
                .zIndex(Double(visibleReservations.count - index))
                .accessibilityLabel("Pickup pass for \(reservation.bag.business), today \(reservation.bag.pickupWindow)")
                .accessibilityHint("Opens the pass. Tap the focused pass to reveal its pickup code.")
            }
        }
        .padding(.bottom, CGFloat(min(max(reservations.count - 1, 0), 2)) * 15)
        .overlay(alignment: .bottomTrailing) {
            if reservations.count > 1 {
                Text("\(reservations.count) ACTIVE PASSES")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(KnightTheme.onAccent)
                    .padding(.horizontal, 11)
                    .frame(minHeight: 30)
                    .background(KnightTheme.gold, in: Capsule())
                    .offset(y: 4)
                    .accessibilityLabel("\(reservations.count) active pickup passes")
            }
        }
    }
}

struct PickupPassOverlay: View {
    let reservation: ActiveReservation
    let onClose: () -> Void
    let onCancel: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsQRCode = true
    @State private var confirmCancellation = false
    @State private var showWalletSetupMessage = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.48)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            ScrollView {
                VStack(spacing: 18) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Pickup pass")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text(showsQRCode ? "Ready to scan" : "Tap the pass to reveal your code")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(KnightTheme.paleText)
                        }

                        Spacer()

                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(.white.opacity(0.14), in: Circle())
                        }
                        .accessibilityLabel("Close pickup pass")
                    }

                    Button {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.52, dampingFraction: 0.82)) {
                            showsQRCode.toggle()
                        }
                    } label: {
                        ZStack {
                            PickupPassCard(reservation: reservation, showsQRCode: false)
                                .opacity(showsQRCode ? 0 : 1)
                                .rotation3DEffect(
                                    .degrees(showsQRCode ? -180 : 0),
                                    axis: (x: 0, y: 1, z: 0),
                                    perspective: 0.72
                                )

                            PickupPassCard(reservation: reservation, showsQRCode: true)
                                .opacity(showsQRCode ? 1 : 0)
                                .rotation3DEffect(
                                    .degrees(showsQRCode ? 0 : 180),
                                    axis: (x: 0, y: 1, z: 0),
                                    perspective: 0.72
                                )
                        }
                    }
                    .buttonStyle(PressScaleButtonStyle(reduceMotion: reduceMotion))
                    .accessibilityLabel(showsQRCode
                        ? "Pickup code for \(reservation.bag.business), \(reservation.pickupCode)"
                        : "Pickup pass for \(reservation.bag.business)")
                    .accessibilityHint(showsQRCode ? "Hides the pickup code" : "Reveals the pickup code")

                    if showsQRCode {
                        VStack(spacing: 12) {
                            AppleWalletAddButton {
                                showWalletSetupMessage = true
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)

                            Button(role: .destructive) {
                                confirmCancellation = true
                            } label: {
                                Label("Cancel reservation", systemImage: "xmark.circle")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity, minHeight: 50)
                                    .background(.white.opacity(0.13), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(.white.opacity(0.22), lineWidth: 1)
                                    }
                            }
                            .buttonStyle(.plain)

                            Text("This single-use code is tied only to this reservation.")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(KnightTheme.paleText)
                                .multilineTextAlignment(.center)
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .frame(maxWidth: 420)
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 30)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .confirmationDialog("Cancel this reservation?", isPresented: $confirmCancellation, titleVisibility: .visible) {
            Button("Cancel reservation", role: .destructive, action: onCancel)
            Button("Keep reservation", role: .cancel) { }
        } message: {
            Text("The payment authorization will be released according to the cancellation policy.")
        }
        .alert("Apple Wallet setup required", isPresented: $showWalletSetupMessage) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This interface is ready for a signed Wallet pass. Connect KnightSaver’s pass service and Apple Developer pass certificate to enable adding it.")
        }
    }
}

struct PickupPassCard: View {
    let reservation: ActiveReservation
    let showsQRCode: Bool

    var body: some View {
        Group {
            if showsQRCode {
                pickupCodeFace
                    .alwaysLight()
            } else {
                knightroFace
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1.586, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(showsQRCode ? 0.52 : 0.14), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
    }

    private var knightroFace: some View {
        GeometryReader { proxy in
            ZStack {
                reservation.bag.brand.primary

                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        BusinessWordmark(bag: reservation.bag, inverse: true)
                        Spacer()
                        Text(reservation.status.rawValue.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .tracking(0.8)
                            .foregroundStyle(KnightTheme.onAccent)
                            .padding(.horizontal, 9)
                            .frame(minHeight: 27)
                            .background(KnightTheme.gold, in: Capsule())
                    }

                    Spacer()

                    HStack(spacing: 12) {
                        KnightroPassMark()
                        VStack(alignment: .leading, spacing: 2) {
                            Text("KNIGHTRO")
                                .font(.system(size: 25, weight: .bold, design: .rounded))
                                .tracking(0.4)
                                .foregroundStyle(.white)
                            Text("CAMPUS PICKUP PASS")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .tracking(1.7)
                                .foregroundStyle(reservation.bag.brand.secondary)
                        }
                    }

                    Spacer()

                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("TODAY · \(reservation.bag.pickupWindow)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text(reservation.bag.location)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(KnightTheme.paleText)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "wave.3.right")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(KnightTheme.paleText)
                            .accessibilityHidden(true)
                    }
                }
                .padding(18)
            }
        }
    }

    private var pickupCodeFace: some View {
        GeometryReader { proxy in
            ZStack {
                KnightTheme.paper

                Circle()
                    .fill(reservation.bag.brand.secondary.opacity(0.16))
                    .frame(width: proxy.size.width * 0.58)
                    .offset(x: proxy.size.width * 0.44, y: -proxy.size.height * 0.42)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top) {
                        BusinessWordmark(bag: reservation.bag, inverse: false)
                        Spacer()
                        Text("SCAN ONCE")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .tracking(0.9)
                            .foregroundStyle(KnightTheme.green)
                    }

                    Spacer(minLength: 6)

                    HStack(spacing: 14) {
                        QRCodeView(value: reservation.pickupCode)
                            .frame(width: min(proxy.size.height * 0.54, 124), height: min(proxy.size.height * 0.54, 124))
                            .padding(7)
                            .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                        VStack(alignment: .leading, spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("PICKUP")
                                    .font(.system(size: 8, weight: .bold, design: .rounded))
                                    .tracking(1.1)
                                    .foregroundStyle(KnightTheme.muted)
                                Text(reservation.bag.pickupWindow)
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(KnightTheme.ink)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("PASS ID")
                                    .font(.system(size: 8, weight: .bold, design: .rounded))
                                    .tracking(1.1)
                                    .foregroundStyle(KnightTheme.muted)
                                Text(reservation.pickupCode)
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(KnightTheme.ink)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.74)
                            }

                            Text("Show this code to staff")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(KnightTheme.green)
                        }
                    }

                    Spacer(minLength: 5)

                    Text("Valid only for \(reservation.bag.business) · \(reservation.paymentStatus)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(KnightTheme.muted)
                        .lineLimit(1)
                }
                .padding(18)
            }
        }
    }
}

private struct BusinessWordmark: View {
    let bag: SurpriseBag
    let inverse: Bool

    var body: some View {
        HStack(spacing: 7) {
            Text(bag.brand.mark)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(bag.brand.primary)
                .frame(width: 27, height: 27)
                .background(bag.brand.secondary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(bag.brand.wordmark)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.4)
                .foregroundStyle(inverse ? Color.white : bag.brand.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

private struct KnightroPassMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(KnightTheme.gold)
            Text("K")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(KnightTheme.onAccent)
        }
        .frame(width: 48, height: 48)
        .accessibilityHidden(true)
    }
}

struct QRCodeView: View {
    let value: String

    var body: some View {
        if let image = Self.makeQRCode(from: value) {
            Image(uiImage: image)
                .resizable()
                .interpolation(.none)
                .accessibilityHidden(true)
        } else {
            Image(systemName: "qrcode")
                .resizable()
                .foregroundStyle(KnightTheme.ink)
                .accessibilityHidden(true)
        }
    }

    private static func makeQRCode(from value: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(value.utf8)
        filter.correctionLevel = "M"

        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)) else {
            return nil
        }

        let context = CIContext()
        guard let cgImage = context.createCGImage(output, from: output.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}

private struct AppleWalletAddButton: UIViewRepresentable {
    let action: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    func makeUIView(context: Context) -> PKAddPassButton {
        let button = PKAddPassButton(addPassButtonStyle: .black)
        button.addTarget(context.coordinator, action: #selector(Coordinator.didTap), for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: PKAddPassButton, context: Context) {
        context.coordinator.action = action
    }

    final class Coordinator: NSObject {
        var action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func didTap() {
            action()
        }
    }
}

struct FilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: isSelected ? "checkmark" : icon)
                    .font(.system(size: 13, weight: .bold))
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }
            .foregroundStyle(isSelected ? KnightTheme.onAccent : KnightTheme.muted)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(
                isSelected ? KnightTheme.gold : KnightTheme.surface,
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .stroke(isSelected ? KnightTheme.ink.opacity(0.12) : KnightTheme.line, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct FilterMenuChip: View {
    let title: String
    let icon: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: isSelected ? "checkmark" : icon)
                .font(.system(size: 13, weight: .bold))
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
        }
        .foregroundStyle(isSelected ? KnightTheme.ink : KnightTheme.muted)
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .background(isSelected ? KnightTheme.gold : KnightTheme.surface, in: Capsule())
        .overlay {
            Capsule()
                .stroke(isSelected ? KnightTheme.ink.opacity(0.12) : KnightTheme.line, lineWidth: 1)
        }
        .contentShape(Capsule())
    }
}
struct SurpriseBagCard: View {
    let bag: SurpriseBag

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BrandBanner(bag: bag)
                .frame(height: 140)
                .overlay(alignment: .topLeading) {
                    AvailabilityChip(count: bag.availableCount, text: bag.availabilityText)
                        .padding(12)
                }

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(bag.business)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(KnightTheme.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        Spacer(minLength: 8)

                        Text(bag.formattedPrice)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(KnightTheme.ink)
                            .fixedSize()
                    }

                    Text("Surprise Bag")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(KnightTheme.muted)
                }

                VStack(alignment: .leading, spacing: 7) {
                    MetadataItem(icon: "clock", text: bag.pickupWindow)
                    MetadataItem(icon: "figure.walk", text: String(format: "%.1f mi · %@", bag.distance, bag.location))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: KnightTheme.cardRadius, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: KnightTheme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: KnightTheme.cardRadius, style: .continuous)
                .stroke(KnightTheme.line, lineWidth: 1)
        }
    }
}

struct BrandBanner: View {
    let bag: SurpriseBag

    var body: some View {
        // The photo fills the space it is given; it never sets the width itself,
        // so cards keep the width their shelf assigns.
        Color.clear
            .overlay {
                Image(bag.bannerAssetName)
                    .resizable()
                    .interpolation(.medium)
                    .scaledToFill()
            }
            .clipped()
            .overlay(alignment: .topTrailing) {
                Label(String(format: "%.1f", bag.rating), systemImage: "star.fill")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(KnightTheme.ink)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 30)
                    .background(.white.opacity(0.94), in: Capsule())
                    .alwaysLight()
                    .padding(12)
            }
            .accessibilityHidden(true)
    }
}

struct BrandMark: View {
    let brand: BagBrand
    let size: CGFloat

    var body: some View {
        Text(brand.mark)
            .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
            .foregroundStyle(brand.primary)
            .frame(width: size, height: size)
            .background(brand.secondary, in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
            .accessibilityHidden(true)
    }
}

private struct MetadataItem: View {
    let icon: String
    let text: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(KnightTheme.muted)
            .lineLimit(1)
    }
}

/// Sits on the card photo, so it uses a solid fill; the fill color carries the stock level:
/// frosted white when plenty is left, citrus when it's almost gone, red when sold out.
private struct AvailabilityChip: View {
    let count: Int
    let text: String

    private var fill: Color {
        count == 0 ? KnightTheme.red : count <= 2 ? KnightTheme.citrus : Color.white.opacity(0.94)
    }

    private var textColor: Color {
        count > 2 ? KnightTheme.ink : .white
    }

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(textColor)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .frame(minHeight: 30)
            .background(fill, in: Capsule())
            .alwaysLight()
    }
}

struct EmptyExploreState: View {
    let searchText: String
    let reset: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "takeoutbag.and.cup.and.straw")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(KnightTheme.muted)
                .frame(width: 68, height: 68)
                .background(KnightTheme.wash, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            Text("No Surprise Bags found")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(KnightTheme.ink)
            Text(searchText.isEmpty ? "New campus pickups will appear here as businesses publish them." : "Try another business, food, or location name.")
                .font(.system(size: 14))
                .foregroundStyle(KnightTheme.muted)
                .multilineTextAlignment(.center)
            if !searchText.isEmpty {
                Button("Clear search", action: reset)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(KnightTheme.onAccent)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 46)
                    .background(KnightTheme.gold, in: Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 42)
        .padding(.horizontal, 24)
        .background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: KnightTheme.cardRadius, style: .continuous))
    }
}

struct PressScaleButtonStyle: ButtonStyle {
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.9 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
