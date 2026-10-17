import Foundation

/// Mirrors specs/cats-and-actions.json. The manifest is the single source of
/// truth for which actions exist, how they play back and which frames they use.
struct Manifest: Decodable {
    let schemaVersion: Int
    let cats: [CatDefinition]
    let actions: [ActionDefinition]

    func action(_ id: String) -> ActionDefinition? { actionsByID[id] }
    func cat(_ id: String) -> CatDefinition? { cats.first { $0.id == id } }

    private var actionsByID: [String: ActionDefinition] {
        Dictionary(actions.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    static func load(from url: URL) throws -> Manifest {
        try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: url))
    }

    /// The copy bundled into the app (Resources/cats-and-actions.json).
    static func loadBundled(_ bundle: Bundle = .main) throws -> Manifest {
        guard let url = bundle.url(forResource: "cats-and-actions", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try load(from: url)
    }
}

struct CatDefinition: Decodable, Equatable {
    let id: String
    let name: String
    let assetDirectory: String
}

enum Playback: String, Decodable {
    /// Repeats until something else is chosen.
    case loop
    /// Plays once, then the engine moves on.
    case once
    /// Plays once, then stays on the last frame until something else is chosen.
    case hold
}

enum AssetStatus: String, Decodable {
    case ready = "READY"
    case toCreate = "TO_CREATE"
}

struct ActionDefinition: Decodable, Equatable {
    let id: String
    let label: String
    let category: String
    let playback: Playback
    let frames: [String]
    let assetStatus: AssetStatus

    init(id: String, label: String, category: String, playback: Playback, frames: [String], assetStatus: AssetStatus) {
        self.id = id
        self.label = label
        self.category = category
        self.playback = playback
        self.frames = frames
        self.assetStatus = assetStatus
    }

    init(from decoder: Decoder) throws {
        enum Keys: String, CodingKey { case id, label, category, playback, frames, assetStatus }
        let c = try decoder.container(keyedBy: Keys.self)
        id = try c.decode(String.self, forKey: .id)
        label = try c.decode(String.self, forKey: .label)
        category = try c.decode(String.self, forKey: .category)
        // An unknown playback value must not break loading the whole manifest.
        playback = Playback(rawValue: (try? c.decode(String.self, forKey: .playback)) ?? "") ?? .once
        frames = try c.decode([String].self, forKey: .frames)
        assetStatus = AssetStatus(rawValue: (try? c.decode(String.self, forKey: .assetStatus)) ?? "") ?? .toCreate
    }
}

/// Seconds per frame for each action. Not in the manifest, so tuned here.
enum FrameTiming {
    static func secondsPerFrame(_ actionID: String) -> Double {
        switch actionID {
        // Revised cycles (Oct 2026) use the art notes' starting rates.
        case "run", "chase": return 0.1          // 10 fps
        case "walk": return 0.125                // 8 fps, 8 frames
        case "sleep", "sleep_2": return 0.5      // 2 fps
        case "knead", "climb": return 1.0 / 6    // 6 fps
        case "idle_sit", "eat", "drink": return 0.3
        case "blink", "sit_blink": return 0.1
        case "fall", "jump", "pounce": return 0.1
        case "look_up", "look_down": return 0.4
        case "stretch", "yawn", "lie_down", "get_up": return 0.25
        case "groom": return 0.2
        case "wave", "happy": return 0.16
        case "roll_over": return 0.125           // 8 fps
        default: return 0.18
        }
    }

    /// How long a placeholder (no art) stays on screen for a once/hold action.
    static let placeholderSeconds = 1.6
}
