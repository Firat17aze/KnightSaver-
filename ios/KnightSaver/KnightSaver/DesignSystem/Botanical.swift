import SwiftUI

// Flat, cut-paper leaves for the Kitchen (business) side. Solid fills and a thin vein only:
// no gradients, shadows or blur, so they match the rest of the plain KnightSaver look.

/// A pointed leaf, stem at the bottom and tip at the top of its frame.
struct LeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let bulge = rect.width * 0.62
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control: CGPoint(x: rect.midX + bulge, y: rect.midY + rect.height * 0.08)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control: CGPoint(x: rect.midX - bulge, y: rect.midY + rect.height * 0.08)
        )
        path.closeSubpath()
        return path
    }
}

/// The center vein of `LeafShape`, from the stem to just short of the tip.
struct LeafVeinShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.14),
            control: CGPoint(x: rect.midX + rect.width * 0.06, y: rect.midY)
        )
        return path
    }
}

/// One leaf, turned around its stem. `vein` is usually the color the leaf sits on.
struct Leaf: View {
    var color: Color
    var vein: Color
    var width: CGFloat
    var height: CGFloat
    var angle: Double = 0

    var body: some View {
        ZStack {
            LeafShape().fill(color)
            LeafVeinShape().stroke(vein, style: StrokeStyle(lineWidth: max(1, width * 0.06), lineCap: .round))
        }
        .frame(width: width, height: height)
        .rotationEffect(.degrees(angle), anchor: .bottom)
        .accessibilityHidden(true)
    }
}

/// A small sprig: three leaves fanning out from one point at the bottom center.
struct LeafSprig: View {
    var color: Color = KnightTheme.green
    var accent: Color = KnightTheme.sprout
    var vein: Color = KnightTheme.surface
    var size: CGFloat = 28

    var body: some View {
        ZStack(alignment: .bottom) {
            Leaf(color: color, vein: vein, width: size * 0.42, height: size * 0.78, angle: -42)
            Leaf(color: color, vein: vein, width: size * 0.42, height: size * 0.78, angle: 42)
            Leaf(color: accent, vein: vein, width: size * 0.46, height: size, angle: 0)
        }
        .frame(width: size, height: size, alignment: .bottom)
        .accessibilityHidden(true)
    }
}

/// Big leaves growing in from a card's bottom-right corner. Place it in an overlay and clip
/// the card, so the leaves look like they're tucked behind its edge.
struct CornerFoliage: View {
    var back: Color = KnightTheme.fern
    var front: Color = KnightTheme.sprout
    var vein: Color = KnightTheme.forest
    var scale: CGFloat = 1

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Leaf(color: back, vein: vein, width: 54 * scale, height: 104 * scale, angle: -58)
                .offset(x: -6 * scale, y: 22 * scale)
            Leaf(color: back, vein: vein, width: 50 * scale, height: 96 * scale, angle: -18)
                .offset(x: 10 * scale, y: 26 * scale)
            Leaf(color: front, vein: vein, width: 30 * scale, height: 58 * scale, angle: -36)
                .offset(x: -30 * scale, y: 16 * scale)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Square scan corners, like on a QR code, with a sprout growing off the top-left corner.
struct ScanCorners: View {
    var color: Color = KnightTheme.sprout
    var length: CGFloat = 30
    var lineWidth: CGFloat = 5
    var radius: CGFloat = 14
    var showsSprout = true

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            Path { path in
                // Top left
                path.move(to: CGPoint(x: 0, y: length))
                path.addLine(to: CGPoint(x: 0, y: radius))
                path.addQuadCurve(to: CGPoint(x: radius, y: 0), control: .zero)
                path.addLine(to: CGPoint(x: length, y: 0))
                // Top right
                path.move(to: CGPoint(x: w - length, y: 0))
                path.addLine(to: CGPoint(x: w - radius, y: 0))
                path.addQuadCurve(to: CGPoint(x: w, y: radius), control: CGPoint(x: w, y: 0))
                path.addLine(to: CGPoint(x: w, y: length))
                // Bottom right
                path.move(to: CGPoint(x: w, y: h - length))
                path.addLine(to: CGPoint(x: w, y: h - radius))
                path.addQuadCurve(to: CGPoint(x: w - radius, y: h), control: CGPoint(x: w, y: h))
                path.addLine(to: CGPoint(x: w - length, y: h))
                // Bottom left
                path.move(to: CGPoint(x: length, y: h))
                path.addLine(to: CGPoint(x: radius, y: h))
                path.addQuadCurve(to: CGPoint(x: 0, y: h - radius), control: CGPoint(x: 0, y: h))
                path.addLine(to: CGPoint(x: 0, y: h - length))
            }
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))

            if showsSprout {
                Leaf(color: color, vein: .clear, width: length * 0.5, height: length * 0.95, angle: -40)
                    .position(x: length * 0.18, y: -length * 0.42)
                Leaf(color: color, vein: .clear, width: length * 0.42, height: length * 0.75, angle: 38)
                    .position(x: length * 0.32, y: -length * 0.32)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview("Botanical") {
    VStack(spacing: 30) {
        LeafSprig(size: 40)
        ZStack {
            RoundedRectangle(cornerRadius: 22).fill(KnightTheme.forest)
            CornerFoliage().frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        ScanCorners().frame(width: 200, height: 200)
    }
    .padding(40)
    .background(KnightTheme.paper)
}
