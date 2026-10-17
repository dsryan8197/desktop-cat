import Foundation

/// What the cursor did over the cat.
enum GestureEvent: Equatable {
    case tickle        // fast side-to-side wiggling
    case pettingBegan  // slow strokes
    case pettingEnded
}

/// Reads tickling and petting from plain cursor positions (no permissions needed:
/// the app already knows where the pointer is). Pure logic, fed once per frame.
struct CursorGestures {
    // Tickle: at least this many quick direction changes within the window.
    var tickleReversals = 4
    var tickleWindow = 1.0
    var tickleMinSpeed = 600.0      // points per second
    var tickleCooldown = 6.0
    // Petting: slow movement over the cat, adding up to this much time.
    var petSpeed: ClosedRange<Double> = 20...400
    var petStartSeconds = 0.8
    var petStopAfter = 1.0          // no stroking this long ends petting

    private(set) var isPetting = false
    private var last: (t: Double, x: Double, y: Double)?
    private var lastDirection = 0
    private var reversals: [Double] = []
    private var lastTickle = -Double.infinity
    private var strokeTime = 0.0
    private var lastStroke = -Double.infinity
    private var lastFast = -Double.infinity

    /// `inside` = the pointer is over the cat. Returns at most one event per sample.
    mutating func feed(time t: Double, x: Double, y: Double, inside: Bool) -> GestureEvent? {
        defer { last = (t, x, y) }
        guard let prev = last, t > prev.t else { return nil }
        let dt = t - prev.t
        let dx = x - prev.x
        let speed = hypot(dx, y - prev.y) / dt

        // Tickle: count direction flips of fast horizontal movement over the cat.
        if inside && speed >= tickleMinSpeed && abs(dx) > 0.5 {
            let dir = dx > 0 ? 1 : -1
            if lastDirection != 0 && dir != lastDirection { reversals.append(t) }
            lastDirection = dir
        }
        reversals.removeAll { t - $0 > tickleWindow }
        if reversals.count >= tickleReversals && t - lastTickle >= tickleCooldown {
            reversals.removeAll()
            lastTickle = t
            strokeTime = 0
            if isPetting { isPetting = false }
            return .tickle
        }

        // Petting: slow strokes over the cat. Any fast movement (like the slow turns of a
        // wiggle) cancels it, so a tickle is never mistaken for petting.
        if inside && speed > petSpeed.upperBound {
            lastFast = t
            strokeTime = 0
        }
        if inside && petSpeed.contains(speed) && t - lastFast > 0.5 {
            strokeTime += dt
            lastStroke = t
            if !isPetting && strokeTime >= petStartSeconds {
                isPetting = true
                return .pettingBegan
            }
        } else if t - lastStroke > petStopAfter {
            strokeTime = 0
            if isPetting {
                isPetting = false
                return .pettingEnded
            }
        }
        return nil
    }
}
