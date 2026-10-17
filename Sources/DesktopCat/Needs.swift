import Foundation

enum Need: String, CaseIterable, Codable {
    case hunger, thirst, fun

    var title: String {
        switch self {
        case .hunger: return "Food"
        case .thirst: return "Water"
        case .fun: return "Fun"
        }
    }

    /// Hours for a full need to run all the way down.
    var hoursToEmpty: Double {
        switch self {
        case .hunger: return 8
        case .thirst: return 6
        case .fun: return 4
        }
    }
}

/// Hunger, thirst and fun as 0...1 (1 = fully satisfied), with timestamps so they keep
/// draining while the app is closed. Nothing bad ever happens at zero: the cat just
/// begs, looks sad or gets bored until you help.
struct Needs: Codable, Equatable {
    var hunger = 1.0
    var thirst = 1.0
    var fun = 1.0
    /// When the values above were last brought up to date.
    var updatedAt: Date
    var lastFed: Date?
    var lastWatered: Date?
    var lastPlayed: Date?

    static let lowThreshold = 0.3

    init(now: Date = Date()) { updatedAt = now }

    subscript(need: Need) -> Double {
        get {
            switch need {
            case .hunger: return hunger
            case .thirst: return thirst
            case .fun: return fun
            }
        }
        set {
            let v = min(max(newValue, 0), 1)
            switch need {
            case .hunger: hunger = v
            case .thirst: thirst = v
            case .fun: fun = v
            }
        }
    }

    /// Drain for the time since `updatedAt`. A clock that went backwards drains nothing.
    mutating func advance(to now: Date) {
        let hours = now.timeIntervalSince(updatedAt) / 3600
        guard hours > 0 else { updatedAt = min(updatedAt, now); return }
        for need in Need.allCases { self[need] -= hours / need.hoursToEmpty }
        updatedAt = now
    }

    var low: Set<Need> { Set(Need.allCases.filter { self[$0] < Self.lowThreshold }) }

    mutating func satisfy(_ need: Need, by amount: Double, at now: Date) {
        advance(to: now)
        self[need] += amount
        switch need {
        case .hunger: lastFed = now
        case .thirst: lastWatered = now
        case .fun: lastPlayed = now
        }
    }
}
