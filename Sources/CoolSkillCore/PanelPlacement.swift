import Foundation

public struct PanelPoint: Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct PanelSize: Equatable, Sendable {
    public let width: Double
    public let height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public struct PanelRect: Equatable, Sendable {
    public let origin: PanelPoint
    public let size: PanelSize

    public init(origin: PanelPoint, size: PanelSize) {
        self.origin = origin
        self.size = size
    }
}

public enum PanelPlacement {
    public static func clampedOrigin(
        desired: PanelPoint,
        panelSize: PanelSize,
        visibleFrame: PanelRect
    ) -> PanelPoint {
        let minX = visibleFrame.origin.x
        let minY = visibleFrame.origin.y
        let maxX = visibleFrame.origin.x + max(0, visibleFrame.size.width - panelSize.width)
        let maxY = visibleFrame.origin.y + max(0, visibleFrame.size.height - panelSize.height)
        return PanelPoint(
            x: min(max(desired.x, minX), maxX),
            y: min(max(desired.y, minY), maxY)
        )
    }
}
