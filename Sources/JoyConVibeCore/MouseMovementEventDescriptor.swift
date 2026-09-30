import Foundation

/// A display's frame in the global coordinate space used by mouse events.
public struct ScreenBounds: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    func contains(x pointX: Double, y pointY: Double) -> Bool {
        pointX >= x && pointX < x + width && pointY >= y && pointY < y + height
    }

    func clampedX(_ pointX: Double) -> Double {
        min(max(pointX, x), x + width - 1)
    }

    func clampedY(_ pointY: Double) -> Double {
        min(max(pointY, y), y + height - 1)
    }
}

public struct MouseMovementEventDescriptor: Equatable, Sendable {
    public var destinationX: Double
    public var destinationY: Double
    public var relativeDeltaX: Int64
    public var relativeDeltaY: Int64
}

/// Turns a pointer delta into the mouse event a physical mouse would produce.
///
/// A real mouse pushed against a screen edge keeps the pointer on the edge
/// while still reporting the outward motion. Edge-triggered system UI such as
/// the auto-hidden Dock depends on both halves, so the destination is kept on
/// a screen and the relative delta is reported unclamped.
public struct MouseMovementPlanner: Sendable {
    private var remainderX = 0.0
    private var remainderY = 0.0

    public init() {}

    public mutating func plan(
        currentX: Double,
        currentY: Double,
        delta: PointerDelta,
        screens: [ScreenBounds]
    ) -> MouseMovementEventDescriptor {
        var destinationX = currentX + delta.dx
        var destinationY = currentY + delta.dy
        if !screens.contains(where: { $0.contains(x: destinationX, y: destinationY) }),
           let screen = screens.first(where: { $0.contains(x: currentX, y: currentY) }) ?? screens.first
        {
            destinationX = screen.clampedX(destinationX)
            destinationY = screen.clampedY(destinationY)
        }

        // Relative deltas are whole counts; carry the fraction so slow motion
        // is reported instead of rounding to zero on every sample.
        remainderX += delta.dx
        remainderY += delta.dy
        let wholeX = remainderX.rounded(.towardZero)
        let wholeY = remainderY.rounded(.towardZero)
        remainderX -= wholeX
        remainderY -= wholeY

        return MouseMovementEventDescriptor(
            destinationX: destinationX,
            destinationY: destinationY,
            relativeDeltaX: Int64(wholeX),
            relativeDeltaY: Int64(wholeY)
        )
    }

    public mutating func reset() {
        remainderX = 0
        remainderY = 0
    }
}
