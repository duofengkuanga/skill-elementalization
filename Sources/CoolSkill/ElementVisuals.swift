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
            let lineWidth = max(1.35, scale * 0.062)
            switch element {
            case .wind:
                var upper = Path()
                upper.move(to: point(0.10, 0.34, size))
                upper.addCurve(
                    to: point(0.76, 0.28, size),
                    control1: point(0.28, 0.16, size),
                    control2: point(0.52, 0.43, size)
                )
                upper.addCurve(
                    to: point(0.88, 0.19, size),
                    control1: point(0.86, 0.27, size),
                    control2: point(0.91, 0.23, size)
                )
                context.stroke(
                    upper,
                    with: .color(color.opacity(0.78)),
                    style: StrokeStyle(lineWidth: lineWidth * 0.78, lineCap: .round, lineJoin: .round)
                )

                var middle = Path()
                middle.move(to: point(0.08, 0.54, size))
                middle.addCurve(
                    to: point(0.88, 0.50, size),
                    control1: point(0.29, 0.31, size),
                    control2: point(0.61, 0.72, size)
                )
                context.stroke(
                    middle,
                    with: .color(color),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                )

                var lower = Path()
                lower.move(to: point(0.18, 0.73, size))
                lower.addCurve(
                    to: point(0.72, 0.70, size),
                    control1: point(0.34, 0.58, size),
                    control2: point(0.53, 0.85, size)
                )
                context.stroke(
                    lower,
                    with: .color(color.opacity(0.66)),
                    style: StrokeStyle(lineWidth: lineWidth * 0.72, lineCap: .round, lineJoin: .round)
                )

                var motes = Path()
                motes.addEllipse(in: CGRect(
                    x: size.width * 0.08,
                    y: size.height * 0.20,
                    width: scale * 0.07,
                    height: scale * 0.07
                ))
                motes.addEllipse(in: CGRect(
                    x: size.width * 0.82,
                    y: size.height * 0.72,
                    width: scale * 0.045,
                    height: scale * 0.045
                ))
                context.fill(motes, with: .color(color.opacity(0.48)))
            case .fire:
                var outer = Path()
                outer.move(to: point(0.50, 0.91, size))
                outer.addCurve(
                    to: point(0.24, 0.56, size),
                    control1: point(0.27, 0.85, size),
                    control2: point(0.18, 0.70, size)
                )
                outer.addCurve(
                    to: point(0.58, 0.10, size),
                    control1: point(0.37, 0.43, size),
                    control2: point(0.49, 0.29, size)
                )
                outer.addCurve(
                    to: point(0.80, 0.60, size),
                    control1: point(0.76, 0.27, size),
                    control2: point(0.86, 0.43, size)
                )
                outer.addCurve(
                    to: point(0.50, 0.91, size),
                    control1: point(0.78, 0.80, size),
                    control2: point(0.65, 0.90, size)
                )
                outer.closeSubpath()
                context.fill(outer, with: .color(color.opacity(0.15)))
                context.stroke(
                    outer,
                    with: .color(color),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                )

                var inner = Path()
                inner.move(to: point(0.49, 0.79, size))
                inner.addCurve(
                    to: point(0.38, 0.62, size),
                    control1: point(0.39, 0.76, size),
                    control2: point(0.35, 0.68, size)
                )
                inner.addCurve(
                    to: point(0.55, 0.37, size),
                    control1: point(0.44, 0.54, size),
                    control2: point(0.50, 0.46, size)
                )
                inner.addCurve(
                    to: point(0.67, 0.63, size),
                    control1: point(0.65, 0.46, size),
                    control2: point(0.71, 0.55, size)
                )
                inner.addCurve(
                    to: point(0.49, 0.79, size),
                    control1: point(0.65, 0.75, size),
                    control2: point(0.57, 0.80, size)
                )
                inner.closeSubpath()
                context.fill(inner, with: .color(color.opacity(0.58)))

                var ember = Path()
                ember.addEllipse(in: CGRect(
                    x: size.width * 0.75,
                    y: size.height * 0.13,
                    width: scale * 0.07,
                    height: scale * 0.07
                ))
                context.fill(ember, with: .color(color.opacity(0.62)))
            case .water:
                var droplet = Path()
                droplet.move(to: point(0.50, 0.08, size))
                droplet.addCurve(
                    to: point(0.38, 0.29, size),
                    control1: point(0.46, 0.16, size),
                    control2: point(0.38, 0.21, size)
                )
                droplet.addCurve(
                    to: point(0.62, 0.29, size),
                    control1: point(0.38, 0.43, size),
                    control2: point(0.62, 0.43, size)
                )
                droplet.addCurve(
                    to: point(0.50, 0.08, size),
                    control1: point(0.62, 0.21, size),
                    control2: point(0.54, 0.16, size)
                )
                droplet.closeSubpath()
                context.fill(droplet, with: .color(color.opacity(0.18)))
                context.stroke(
                    droplet,
                    with: .color(color.opacity(0.74)),
                    style: StrokeStyle(lineWidth: lineWidth * 0.68, lineCap: .round, lineJoin: .round)
                )

                for (offset, opacity) in [(0.47, 0.72), (0.65, 1.0), (0.82, 0.58)] {
                    var wave = Path()
                    wave.move(to: point(0.08, offset, size))
                    wave.addCurve(
                        to: point(0.92, offset, size),
                        control1: point(0.28, offset - 0.18, size),
                        control2: point(0.70, offset + 0.18, size)
                    )
                    context.stroke(
                        wave,
                        with: .color(color.opacity(opacity)),
                        style: StrokeStyle(
                            lineWidth: opacity == 1 ? lineWidth : lineWidth * 0.72,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                }
            case .mountain:
                var sun = Path()
                sun.addEllipse(in: CGRect(
                    x: size.width * 0.12,
                    y: size.height * 0.13,
                    width: scale * 0.14,
                    height: scale * 0.14
                ))
                context.fill(sun, with: .color(color.opacity(0.28)))

                var ridge = Path()
                ridge.move(to: point(0.05, 0.83, size))
                ridge.addLine(to: point(0.34, 0.39, size))
                ridge.addLine(to: point(0.49, 0.58, size))
                context.stroke(
                    ridge,
                    with: .color(color.opacity(0.55)),
                    style: StrokeStyle(lineWidth: lineWidth * 0.72, lineCap: .round, lineJoin: .round)
                )

                var mountain = Path()
                mountain.move(to: point(0.18, 0.84, size))
                mountain.addLine(to: point(0.58, 0.20, size))
                mountain.addLine(to: point(0.94, 0.84, size))
                mountain.closeSubpath()
                context.fill(mountain, with: .color(color.opacity(0.13)))
                context.stroke(
                    mountain,
                    with: .color(color),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                )

                var snow = Path()
                snow.move(to: point(0.46, 0.39, size))
                snow.addLine(to: point(0.58, 0.20, size))
                snow.addLine(to: point(0.70, 0.42, size))
                snow.addLine(to: point(0.62, 0.37, size))
                snow.addLine(to: point(0.56, 0.45, size))
                snow.closeSubpath()
                context.fill(snow, with: .color(color.opacity(0.44)))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .shadow(color: color.opacity(0.20), radius: 2, y: 1)
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
