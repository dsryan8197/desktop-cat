import Foundation

/// Pure frame-timing logic for one action. No drawing, no clocks: you feed it
/// elapsed time and ask which frame to show. That keeps it deterministic and testable.
struct AnimationPlayer {
    let frameCount: Int
    let secondsPerFrame: Double
    let playback: Playback
    let reversed: Bool
    private(set) var elapsed: Double = 0

    init(frameCount: Int, secondsPerFrame: Double, playback: Playback, reversed: Bool = false) {
        self.frameCount = max(1, frameCount)
        self.secondsPerFrame = max(0.01, secondsPerFrame)
        self.playback = playback
        self.reversed = reversed
    }

    mutating func advance(by dt: Double) {
        guard dt > 0 else { return }
        elapsed += dt
    }

    /// Steps taken so far (unbounded).
    private var step: Int { Int((elapsed / secondsPerFrame).rounded(.down)) }

    var frameIndex: Int {
        let i: Int
        switch playback {
        case .loop: i = step % frameCount
        case .once, .hold: i = min(step, frameCount - 1)
        }
        return reversed ? frameCount - 1 - i : i
    }

    /// once: true after the last frame has had its full time on screen.
    /// hold: true once the last frame is reached (it then stays there).
    /// loop: never finishes on its own.
    var isFinished: Bool {
        switch playback {
        case .loop: return false
        case .once: return step >= frameCount
        case .hold: return step >= frameCount - 1
        }
    }

    var completedLoops: Int { playback == .loop ? step / frameCount : (isFinished ? 1 : 0) }
}
