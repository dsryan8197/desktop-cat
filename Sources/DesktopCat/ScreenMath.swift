import CoreGraphics
import Foundation

/// Pure screen and position maths, kept apart from AppKit so it can be tested with
/// made-up monitor layouts (side by side, stacked, negative coordinates, gaps).
enum ScreenMath {
    /// Where the cat's left edge may be on a screen's floor.
    /// A cat wider than the screen just sits at the left edge.
    static func floorRange(visibleFrame v: CGRect, catWidth: Double) -> ClosedRange<Double> {
        let lo = Double(v.minX)
        return lo...max(lo, Double(v.maxX) - catWidth)
    }

    /// Index of the screen containing a point, if any.
    static func screen(containing p: CGPoint, in frames: [CGRect]) -> Int? {
        frames.firstIndex { $0.contains(p) }
    }

    /// The screen a window belongs to: the one under its bottom-centre (where the feet
    /// are), otherwise the nearest one, otherwise the first.
    static func screen(for window: CGRect, in frames: [CGRect]) -> Int {
        if let i = screen(containing: CGPoint(x: window.midX, y: window.minY + 1), in: frames) { return i }
        let nearest = frames.indices.min { distance(frames[$0], window) < distance(frames[$1], window) }
        return nearest ?? 0
    }

    static func distance(_ a: CGRect, _ b: CGRect) -> CGFloat {
        hypot(a.midX - b.midX, a.midY - b.midY)
    }

    /// The cat's position along its floor as 0 (left) ... 1 (right), for saving.
    static func fraction(of x: Double, in range: ClosedRange<Double>) -> Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0, x.isFinite else { return 0 }
        return min(max((x - range.lowerBound) / span, 0), 1)
    }

    /// The x position for a saved fraction. Bad or missing values put the cat near the right.
    static func x(forFraction f: Double?, in range: ClosedRange<Double>) -> Double {
        let f = (f.map { $0.isFinite ? $0 : 0.8 }) ?? 0.8
        return range.lowerBound + (range.upperBound - range.lowerBound) * min(max(f, 0), 1)
    }

    /// Which display to restore onto: the saved one if it's still attached, else the main one (index 0).
    static func restoreScreen(savedID: UInt32?, attachedIDs: [UInt32]) -> Int {
        savedID.flatMap { attachedIDs.firstIndex(of: $0) } ?? 0
    }

    /// Keep the cat's centre in place when its size changes (new scale or cat).
    static func x(keepingCenter centerX: Double, newWidth: Double) -> Double {
        centerX - newWidth / 2
    }
}

extension Manifest {
    /// The saved cat, or the first cat if that one no longer exists.
    func resolveCat(_ id: String) -> CatDefinition {
        cat(id) ?? cats[0]
    }
}
