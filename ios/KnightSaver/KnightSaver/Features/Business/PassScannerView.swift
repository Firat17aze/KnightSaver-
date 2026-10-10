import SwiftUI
import AVFoundation
import UIKit

/// Staff scan the student's reusable Knight Pass. Only reservations valid for this
/// business and pickup window match. Verification is protected against double scans.
struct PassScannerView: View {
    @ObservedObject var store: BusinessStore
    /// Set when staff tapped "Verify pickup" on a specific reservation.
    let expectedReservationID: UUID?
    @Environment(\.dismiss) private var dismiss

    private enum Phase: Equatable {
        case scanning
        case result(PassScanResult)
        case done(VerifyOutcome)
    }

    private enum CameraState {
        case checking
        case ready
        case unavailable
        case denied
    }

    @State private var phase: Phase = .scanning
    @State private var camera: CameraState = .checking
    @State private var selectedID: UUID?
    @State private var measuredWeight: Double = 0
    @State private var isVerifying = false

    init(store: BusinessStore, expectedReservationID: UUID? = nil) {
        _store = ObservedObject(wrappedValue: store)
        self.expectedReservationID = expectedReservationID
    }

    private var expectedReservation: BusinessReservation? {
        expectedReservationID.flatMap { store.reservation(id: $0) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch phase {
                    case .scanning:
                        scanningView
                    case .result(let result):
                        resultView(result)
                    case .done(let outcome):
                        doneView(outcome)
                    }
                }
                .padding(KnightTheme.screenPadding)
            }
            .background(KnightTheme.paper)
            .navigationTitle("Scan Knight Pass")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { BizKeyboard.hide() }
                }
            }
        }
        .tint(KnightTheme.ink)
        .task { await setUpCamera() }
    }

    // MARK: - Scanning

    @ViewBuilder
    private var scanningView: some View {
        if let expected = expectedReservation {
            BizMetaRow(icon: "person.fill", text: "Collecting: \(expected.studentDisplayName) · \(expected.code) · \(expected.quantity) bag\(expected.quantity == 1 ? "" : "s")")
        }

        ZStack {
            RoundedRectangle(cornerRadius: KnightTheme.cardRadius, style: .continuous)
                .fill(KnightTheme.ink)

            switch camera {
            case .ready:
                QRCodeScanner { value in handleScan(value) }
                    .clipShape(RoundedRectangle(cornerRadius: KnightTheme.cardRadius, style: .continuous))
            case .checking:
                ProgressView().tint(.white)
            case .unavailable:
                cameraMessage(icon: "camera.fill", text: "Camera isn't available here (for example in the Simulator). Use a demo scan below.")
            case .denied:
                cameraMessage(icon: "camera.badge.ellipsis", text: "Camera access is off. Turn it on in Settings › KnightSaver to scan passes.")
            }

            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(KnightTheme.gold, lineWidth: 4)
                .frame(width: 210, height: 210)
                .allowsHitTesting(false)
        }
        .frame(height: 320)
        .accessibilityLabel("Camera viewfinder for Knight Pass QR codes")

        Text("Point the camera at the QR code on the back of the student's Knight Pass.")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(KnightTheme.muted)

        if store.isDemo {
            VStack(alignment: .leading, spacing: 10) {
                Text("DEMO SCANS")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(KnightTheme.goldDeep)
                if let expected = expectedReservation, expected.passToken != KnightPass.sample.verificationToken {
                    demoScanButton("Scan \(expected.studentDisplayName)'s pass", value: "knightsaver://verify-user/\(expected.passToken)")
                }
                demoScanButton("Scan \(KnightPass.sample.displayName)'s pass (Profile)", value: KnightPass.sample.verificationPayload)
                demoScanButton("Scan a pass with no reservation", value: "knightsaver://verify-user/demo-UNKNOWN")
            }
            .bizCard()
        }
    }

    private func demoScanButton(_ title: String, value: String) -> some View {
        Button {
            handleScan(value)
        } label: {
            BizSecondaryLabel(title: title, icon: "qrcode")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private func cameraMessage(icon: String, text: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(KnightTheme.gold)
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
        }
        .padding(28)
    }

    private func handleScan(_ value: String) {
        guard phase == .scanning else { return }
        let result = store.scan(value)
        switch result {
        case .single(let reservation):
            selectedID = reservation.id
            haptic(.success)
        case .multiple(let list):
            selectedID = list.first(where: { $0.id == expectedReservationID })?.id
            haptic(.success)
        case .noValidPickup, .alreadyVerified:
            selectedID = nil
            haptic(.error)
        }
        measuredWeight = 0
        phase = .result(result)
    }

    // MARK: - Result

    @ViewBuilder
    private func resultView(_ result: PassScanResult) -> some View {
        switch result {
        case .noValidPickup:
            statusCard(
                icon: "xmark.octagon.fill",
                tint: KnightTheme.red,
                title: "No valid pickup",
                message: "This Knight Pass has no reservation to collect at \(store.profile.name) in the current pickup window."
            )
            scanAgainButton

        case .alreadyVerified(let reservation):
            statusCard(
                icon: "checkmark.circle.fill",
                tint: KnightTheme.goldDeep,
                title: "Already verified",
                message: "\(reservation.studentDisplayName)'s pickup (\(reservation.code)) was verified at \(reservation.verifiedAt.map { PickupTime.time($0) } ?? "earlier"). Payment was captured once and won't be charged again."
            )
            scanAgainButton

        case .single(let reservation):
            Text("Confirm this pickup")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(KnightTheme.ink)
            reservationCard(reservation, selectable: false)
            verifySection

        case .multiple(let reservations):
            Text("Select the pickup being collected")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(KnightTheme.ink)
            Text("This student has \(reservations.count) valid reservations here.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(KnightTheme.muted)
            ForEach(reservations) { reservation in
                reservationCard(reservation, selectable: true)
            }
            verifySection
        }
    }

    private func reservationCard(_ reservation: BusinessReservation, selectable: Bool) -> some View {
        let isSelected = selectedID == reservation.id
        return Button {
            if selectable { selectedID = reservation.id }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(reservation.studentDisplayName)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(KnightTheme.ink)
                        Text("\(reservation.code) · \(reservation.quantity) Surprise Bag\(reservation.quantity == 1 ? "" : "s")")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(KnightTheme.muted)
                    }
                    Spacer()
                    if selectable {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22))
                            .foregroundStyle(isSelected ? KnightTheme.green : KnightTheme.line)
                    }
                }
                BizMetaRow(icon: "clock.fill", text: "Pickup \(reservation.pickupWindowText)")
                BizMetaRow(icon: "creditcard.fill", text: "\(reservation.payment.rawValue) · \(PickupTime.money(reservation.total))")
            }
            .bizCard()
            .overlay {
                if isSelected && selectable {
                    RoundedRectangle(cornerRadius: KnightTheme.cardRadius, style: .continuous)
                        .stroke(KnightTheme.green, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!selectable)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var verifySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Weighed the bag? (optional)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(KnightTheme.ink)
                Spacer()
                BizDecimalField("0.00", value: $measuredWeight)
                    .frame(maxWidth: 70)
                Text("kg")
                    .foregroundStyle(KnightTheme.muted)
            }
            .padding(14)
            .background(KnightTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            Button {
                if let id = selectedID { verify(id) }
            } label: {
                BizPrimaryLabel(title: isVerifying ? "Verifying…" : "Verify pickup & capture payment", icon: "checkmark.seal.fill")
            }
            .buttonStyle(.plain)
            .disabled(selectedID == nil || isVerifying)
            .opacity(selectedID == nil ? 0.45 : 1)

            Text("Without a weight, the impact report uses an estimate and labels it as one.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(KnightTheme.muted)

            scanAgainButton
        }
    }

    private func verify(_ id: UUID) {
        guard !isVerifying else { return }
        isVerifying = true
        BizKeyboard.hide()
        let outcome = store.verifyPickup(id: id, measuredWeightKg: measuredWeight > 0 ? measuredWeight : nil)
        if case .verified = outcome {
            haptic(.success)
        } else {
            haptic(.warning)
        }
        phase = .done(outcome)
        isVerifying = false
    }

    // MARK: - Done

    @ViewBuilder
    private func doneView(_ outcome: VerifyOutcome) -> some View {
        switch outcome {
        case .verified(let reservation):
            statusCard(
                icon: "checkmark.seal.fill",
                tint: KnightTheme.green,
                title: "Pickup verified",
                message: "\(reservation.studentDisplayName) · \(reservation.code)"
            )
            VStack(spacing: 10) {
                BizMetaRow(icon: "creditcard.fill", text: "Payment captured: \(PickupTime.money(reservation.total))")
                BizMetaRow(icon: "list.bullet.rectangle", text: "Added to Today's verified rescues")
                BizMetaRow(icon: "leaf.fill", text: "Impact and Campus Rescue League updated")
                BizMetaRow(icon: "sparkles", text: "EcoKnight AI and Past Reveal unlocked for the student")
            }
            .bizCard()
            HStack(spacing: 10) {
                scanAgainButton
                Button {
                    dismiss()
                } label: {
                    BizPrimaryLabel(title: "Done")
                }
                .buttonStyle(.plain)
            }

        case .alreadyVerified(let reservation):
            statusCard(
                icon: "checkmark.circle.fill",
                tint: KnightTheme.goldDeep,
                title: "Already verified",
                message: "\(reservation.code) was already verified. Nothing was charged again."
            )
            scanAgainButton

        case .notAllowed(let message):
            statusCard(icon: "exclamationmark.triangle.fill", tint: KnightTheme.red, title: "Can't verify", message: message)
            scanAgainButton
        }
    }

    // MARK: - Pieces

    private var scanAgainButton: some View {
        Button {
            selectedID = nil
            measuredWeight = 0
            phase = .scanning
        } label: {
            BizSecondaryLabel(title: "Scan another pass", icon: "qrcode.viewfinder")
        }
        .buttonStyle(.plain)
    }

    private func statusCard(icon: String, tint: Color, title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(tint)
            Text(title)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(KnightTheme.ink)
            Text(message)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(KnightTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .bizCard()
        .accessibilityElement(children: .combine)
    }

    private func haptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }

    private func setUpCamera() async {
        #if targetEnvironment(simulator)
        camera = .unavailable
        #else
        guard AVCaptureDevice.default(for: .video) != nil else {
            camera = .unavailable
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            camera = .ready
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            camera = granted ? .ready : .denied
        default:
            camera = .denied
        }
        #endif
    }
}

// MARK: - Camera QR scanner

/// Live camera preview that reports QR code text. Requires NSCameraUsageDescription.
struct QRCodeScanner: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.onCode = onCode
        return controller
    }

    func updateUIViewController(_ controller: QRScannerViewController, context: Context) {
        controller.onCode = onCode
    }
}

final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((String) -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var lastValue: String?
    private var lastScanDate = Date.distantPast

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        previewLayer = layer
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let session = self.session
        DispatchQueue.global(qos: .userInitiated).async {
            if !session.isRunning { session.startRunning() }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        let session = self.session
        DispatchQueue.global(qos: .userInitiated).async {
            if session.isRunning { session.stopRunning() }
        }
    }

    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let code = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = code.stringValue else { return }
        // The delegate queue is .main, so this is already on the main thread.
        MainActor.assumeIsolated {
            self.handle(value)
        }
    }

    private func handle(_ value: String) {
        // Ignore the same code for 3 seconds so one pass isn't read many times.
        if value == lastValue && Date().timeIntervalSince(lastScanDate) < 3 { return }
        lastValue = value
        lastScanDate = Date()
        onCode?(value)
    }
}

#Preview {
    PassScannerView(store: .demo())
}
