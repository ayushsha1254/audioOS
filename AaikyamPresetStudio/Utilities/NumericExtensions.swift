import Foundation

// MARK: - Float clamping helpers

extension Float {
    /// Clamps the value to [0.0, 1.0].
    var clamped01: Float { Swift.max(0.0, Swift.min(1.0, self)) }

    func clamped(to r: ClosedRange<Float>) -> Float {
        Swift.max(r.lowerBound, Swift.min(r.upperBound, self))
    }
}

// MARK: - Int clamping helpers

extension Int {
    func clamped(to r: ClosedRange<Int>) -> Int {
        Swift.max(r.lowerBound, Swift.min(r.upperBound, self))
    }
}
