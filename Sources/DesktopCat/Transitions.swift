import Foundation

/// Which action may follow which, based on the state machine in specs/BEHAVIOR_RULES.md.
/// Instead of jumping straight from sleeping to walking, the router inserts the
/// in-between actions (sleep → wake_up → get_up → walk).
enum Transitions {
    /// Never cut these short except for a drag or safety stop.
    static let uninterruptible: Set<String> = ["jump_prep", "jump", "jump_up", "fall", "land", "climb", "pounce"]

    /// Lying-down poses. Leaving them means getting up first.
    static let lying: Set<String> = ["lie_down", "sleep", "sleep_2", "wake_up", "belly_up", "roll_over", "flop", "lap"]

    /// Actions that only make sense while already lying down.
    static let needsLying: Set<String> = ["sleep", "sleep_2", "wake_up", "belly_up"]

    /// Where an action goes when it finishes and nothing else was asked for.
    static func naturalNext(after id: String) -> String {
        switch id {
        case "lie_down", "flop": return "sleep"
        case "wake_up": return "get_up"
        case "roll_over": return "get_up" // The roll ends lying on its side.
        case "jump_prep": return "jump"
        case "jump", "jump_up", "fall", "pounce": return "land"
        default: return "idle_sit"
        }
    }

    /// Actions to play, in order, to get from `current` to `target` (ending with target).
    /// Returns nil when the target can't be reached safely.
    static func route(from current: String?, to target: String, known: (String) -> Bool) -> [String]? {
        guard known(target) else { return nil }
        guard let current, current != target else { return [target] }

        let fromLying = lying.contains(current)
        let toLying = lying.contains(target)

        if fromLying && !toLying {
            // Get up first. Sleepers wake up before they get up.
            var path: [String] = []
            if current == "sleep" || current == "sleep_2" { path.append("wake_up") }
            if target != "get_up" { path.append("get_up") }
            return (path + [target]).filter(known)
        }
        if !fromLying && needsLying.contains(target) {
            // Lie down first (e.g. idle → sleep becomes lie_down → sleep).
            return ["lie_down", target].filter(known)
        }
        if target == "get_up" && !fromLying {
            return nil // Nothing to get up from.
        }
        return [target]
    }
}
