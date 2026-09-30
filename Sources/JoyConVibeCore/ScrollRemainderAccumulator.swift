import Foundation

/// Carries the fractional part of per-report scroll distances.
///
/// Scroll events only accept whole points, while a light stick deflection asks
/// for a fraction of a point per report. Rounding each report on its own drops
/// that motion entirely and quantizes every other speed.
public struct ScrollRemainderAccumulator: Sendable {
    private var remainder = 0.0

    public init() {}

    public mutating func wholePoints(adding points: Double) -> Int32 {
        if points * remainder < 0 {
            // A pending fraction from the opposite direction would delay the
            // first point after the user reverses the stick.
            remainder = 0
        }
        remainder += points
        let whole = remainder.rounded(.towardZero)
        remainder -= whole
        return Int32(max(Double(Int32.min), min(Double(Int32.max), whole)))
    }

    public mutating func reset() {
        remainder = 0
    }
}
