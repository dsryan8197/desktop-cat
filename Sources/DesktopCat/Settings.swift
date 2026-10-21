import Foundation

/// User preferences, saved in UserDefaults. Switching cats changes only `catID`;
/// position and everything else are kept.
final class Settings {
    static let scales = [1, 2, 3, 4, 5, 6]
    static let defaultScale = 3

    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var catID: String {
        get { defaults.string(forKey: "catID") ?? "fluffy_b" }
        set { defaults.set(newValue, forKey: "catID") }
    }

    var scale: Int {
        get {
            let s = defaults.integer(forKey: "scale")
            return Self.scales.contains(s) ? s : Self.defaultScale
        }
        set { defaults.set(Self.scales.contains(newValue) ? newValue : Self.defaultScale, forKey: "scale") }
    }

    var energy: Energy {
        get { Energy(rawValue: defaults.string(forKey: "energy") ?? "") ?? .normal }
        set { defaults.set(newValue.rawValue, forKey: "energy") }
    }

    /// Hunger, thirst and fun with their timestamps.
    var needs: Needs? {
        get {
            guard let data = defaults.data(forKey: "needs") else { return nil }
            return try? JSONDecoder().decode(Needs.self, from: data)
        }
        set { defaults.set(newValue.flatMap { try? JSONEncoder().encode($0) }, forKey: "needs") }
    }

    // Opt-in extras (all off until you turn them on).
    var chaseCursor: Bool { get { defaults.bool(forKey: "chaseCursor") } set { defaults.set(newValue, forKey: "chaseCursor") } }
    var jumpOnWindows: Bool { get { defaults.bool(forKey: "jumpOnWindows") } set { defaults.set(newValue, forKey: "jumpOnWindows") } }
    var hangOffEdges: Bool { get { defaults.bool(forKey: "hangOffEdges") } set { defaults.set(newValue, forKey: "hangOffEdges") } }
    var peekBehindWindows: Bool { get { defaults.bool(forKey: "peekBehindWindows") } set { defaults.set(newValue, forKey: "peekBehindWindows") } }
    /// On unless you turn it off: sit and watch along when a video is playing.
    var watchVideos: Bool { get { bool("watchVideos", default: true) } set { defaults.set(newValue, forKey: "watchVideos") } }
    /// On unless you turn it off: pounce at the pointer when it comes close.
    var pounceAtCursor: Bool { get { bool("pounceAtCursor", default: true) } set { defaults.set(newValue, forKey: "pounceAtCursor") } }

    // Being considerate (on unless you turn them off).
    var pauseInFullScreen: Bool { get { bool("pauseInFullScreen", default: true) } set { defaults.set(newValue, forKey: "pauseInFullScreen") } }
    var pauseInLowPower: Bool { get { bool("pauseInLowPower", default: true) } set { defaults.set(newValue, forKey: "pauseInLowPower") } }

    private func bool(_ key: String, default value: Bool) -> Bool {
        defaults.object(forKey: key) == nil ? value : defaults.bool(forKey: key)
    }

    var paused: Bool {
        get { defaults.bool(forKey: "paused") }
        set { defaults.set(newValue, forKey: "paused") }
    }

    var hidden: Bool {
        get { defaults.bool(forKey: "hidden") }
        set { defaults.set(newValue, forKey: "hidden") }
    }

    /// Where the cat was: which display, and how far along its floor (0 = left, 1 = right).
    var position: SavedPosition? {
        get {
            guard let data = defaults.data(forKey: "position") else { return nil }
            return try? JSONDecoder().decode(SavedPosition.self, from: data)
        }
        set { defaults.set(newValue.flatMap { try? JSONEncoder().encode($0) }, forKey: "position") }
    }
}

struct SavedPosition: Codable, Equatable {
    var displayID: UInt32
    var fraction: Double
    var facingRight: Bool
}
