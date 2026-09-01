import AppKit
import CoolSkillCore
import SwiftUI

extension Element {
    func color(for scheme: ColorScheme) -> Color {
        switch (self, scheme) {
        case (.wind, .light): return Color(red: 0.08, green: 0.61, blue: 0.51)
        case (.wind, .dark): return Color(red: 0.38, green: 0.84, blue: 0.74)
        case (.fire, .light): return Color(red: 0.91, green: 0.25, blue: 0.14)
        case (.fire, .dark): return Color(red: 1.00, green: 0.42, blue: 0.29)
        case (.water, .light): return Color(red: 0.16, green: 0.43, blue: 0.90)
        case (.water, .dark): return Color(red: 0.36, green: 0.62, blue: 1.00)
        case (.mountain, .light): return Color(red: 0.55, green: 0.42, blue: 0.22)
        case (.mountain, .dark): return Color(red: 0.77, green: 0.64, blue: 0.42)
        @unknown default: return .accentColor
        }
    }
}

struct ElementGlyph: View {
    let element: Element
    let color: Color

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height)
            var path = Path()
            switch element {
            case .wind:
                for offset in [0.30, 0.50, 0.70] {
                    path.move(to: point(0.12, offset, size))
                    path.addCurve(
                        to: point(0.86, offset - 0.04, size),
                        control1: point(0.34, offset - 0.18, size),
                        control2: point(0.62, offset + 0.13, size)
                    )
                }
            case .fire:
                path.move(to: point(0.51, 0.90, size))
                path.addCurve(
                    to: point(0.24, 0.56, size),
                    control1: point(0.27, 0.85, size),
                    control2: point(0.18, 0.70, size)
                )
                path.addCurve(
                    to: point(0.58, 0.10, size),
                    control1: point(0.37, 0.43, size),
                    control2: point(0.49, 0.29, size)
                )
                path.addCurve(
                    to: point(0.80, 0.60, size),
                    control1: point(0.76, 0.27, size),
                    control2: point(0.86, 0.43, size)
                )
                path.addCurve(
                    to: point(0.51, 0.90, size),
                    control1: point(0.78, 0.80, size),
                    control2: point(0.65, 0.90, size)
                )
                path.closeSubpath()
                context.fill(path, with: .color(color.opacity(0.14)))
            case .water:
                for offset in [0.39, 0.61] {
                    path.move(to: point(0.10, offset, size))
                    path.addCurve(
                        to: point(0.90, offset, size),
                        control1: point(0.30, offset - 0.25, size),
                        control2: point(0.68, offset + 0.25, size)
                    )
                }
            case .mountain:
                path.move(to: point(0.08, 0.82, size))
                path.addLine(to: point(0.38, 0.30, size))
                path.addLine(to: point(0.54, 0.57, size))
                path.addLine(to: point(0.67, 0.39, size))
                path.addLine(to: point(0.92, 0.82, size))
                path.move(to: point(0.08, 0.82, size))
                path.addLine(to: point(0.92, 0.82, size))
            }
            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(
                    lineWidth: max(1.6, scale * 0.075),
                    lineCap: .round,
                    lineJoin: .round
                )
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private func point(_ x: Double, _ y: Double, _ size: CGSize) -> CGPoint {
        CGPoint(x: size.width * x, y: size.height * y)
    }
}

struct BrandMark: View {
    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let center = CGPoint(x: side * 16 / 18, y: side * 15.5 / 18)
            let bands: [(Double, Color)] = [
                (14, Color(red: 1, green: 107.0 / 255, blue: 74.0 / 255)),
                (12, Color(red: 196.0 / 255, green: 163.0 / 255, blue: 107.0 / 255)),
                (10, Color(red: 97.0 / 255, green: 214.0 / 255, blue: 189.0 / 255)),
                (8, Color(red: 92.0 / 255, green: 158.0 / 255, blue: 1))
            ]
            for (radius, color) in bands {
                var band = Path()
                band.addArc(center: center, radius: side * radius / 18,
                            startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
                band.addArc(center: center, radius: side * (radius - 2) / 18,
                            startAngle: .degrees(270), endAngle: .degrees(180), clockwise: true)
                band.closeSubpath()
                context.fill(band, with: .color(color))
            }
        }
        .accessibilityLabel("CoolSkill")
    }
}
