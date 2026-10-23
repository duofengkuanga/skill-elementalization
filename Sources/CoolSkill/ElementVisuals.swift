import AppKit
import CoolSkillCore
import SwiftUI

enum AppTheme {
    static func accent(for scheme: ColorScheme) -> Color {
        rgb(scheme == .dark ? 0xA5A6FF : 0x5556C9)
    }

    static func canvas(for scheme: ColorScheme) -> Color {
        rgb(scheme == .dark ? 0x181C29 : 0xFAFBFE)
    }

    static func sidebar(for scheme: ColorScheme) -> Color {
        rgb(scheme == .dark ? 0x202536 : 0xF0F2F8)
    }

    static func ink(for scheme: ColorScheme) -> Color {
        rgb(scheme == .dark ? 0xECEFFA : 0x252B43)
    }

    static func selection(for scheme: ColorScheme) -> Color {
        rgb(scheme == .dark ? 0x343959 : 0xE1E4F7)
    }

    static func rgb(_ hex: UInt32) -> Color {
        Color(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

extension Element {
    func color(for scheme: ColorScheme) -> Color {
        switch (self, scheme) {
        case (.wind, .light): return AppTheme.rgb(0x4C7D87)
        case (.wind, .dark): return AppTheme.rgb(0x93C4CE)
        case (.fire, .light): return AppTheme.rgb(0xA56773)
        case (.fire, .dark): return AppTheme.rgb(0xD9A0AD)
        case (.water, .light): return AppTheme.rgb(0x627CBC)
        case (.water, .dark): return AppTheme.rgb(0xA0B8EB)
        case (.mountain, .light): return AppTheme.rgb(0x817291)
        case (.mountain, .dark): return AppTheme.rgb(0xBFB0D0)
        @unknown default: return AppTheme.accent(for: scheme)
        }
    }
}

struct ElementGlyph: View {
    let element: Element
    let color: Color

    var body: some View {
        Image(systemName: symbolName)
            .resizable()
            .scaledToFit()
            .foregroundStyle(color)
            .padding(1)
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private var symbolName: String {
        switch element {
        case .wind: return "wind"
        case .fire: return "flame"
        case .water: return "drop"
        case .mountain: return "mountain.2"
        }
    }
}

struct BrandMark: View {
    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                RoundedRectangle(cornerRadius: side * 0.24, style: .continuous)
                    .fill(LinearGradient(
                        colors: [AppTheme.rgb(0x7577E8), AppTheme.rgb(0x494AB4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                Canvas { context, size in
                    let scale = min(size.width, size.height)
                    let stem = CGRect(x: scale * 0.26, y: scale * 0.22,
                                      width: scale * 0.12, height: scale * 0.56)
                    context.fill(Path(roundedRect: stem, cornerRadius: scale * 0.06),
                                 with: .color(.white))
                    var lowerArm = Path()
                    lowerArm.move(to: CGPoint(x: scale * 0.45, y: scale * 0.52))
                    lowerArm.addLine(to: CGPoint(x: scale * 0.70, y: scale * 0.72))
                    context.stroke(lowerArm, with: .color(AppTheme.rgb(0xC3C9FF)),
                                   style: StrokeStyle(lineWidth: scale * 0.12, lineCap: .round))
                    var upperArm = Path()
                    upperArm.move(to: CGPoint(x: scale * 0.45, y: scale * 0.52))
                    upperArm.addLine(to: CGPoint(x: scale * 0.68, y: scale * 0.28))
                    context.stroke(upperArm, with: .color(.white),
                                   style: StrokeStyle(lineWidth: scale * 0.12, lineCap: .round))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("kcoisga")
    }
}
