import Foundation

/// Plays manifest actions for one cat: tracks the current action and frame,
/// routes requests through `Transitions`, and queues follow-up actions.
final class AnimationEngine {
    private(set) var library: SpriteLibrary
    private(set) var current: ResolvedAction
    private(set) var player: AnimationPlayer
    private(set) var queue: [String] = []
    /// Called when a once/hold action completes. Return true if you requested
    /// something new; otherwise the engine picks `Transitions.naturalNext`.
    var onFinished: ((String) -> Bool)?
    /// Messages about refused requests, for logging and tests.
    private(set) var log: [String] = []
    private var finishReported = false
    /// While true, once/hold actions stay on their last frame instead of finishing
    /// (used while the cat is in the air: jumping, falling).
    var sustainLastFrame = false
    private var frozenFor: Double = 0

    init(library: SpriteLibrary, start: String = "idle_sit") {
        self.library = library
        let action = library.action(start) ?? library.action("idle_sit")!
        current = action
        player = Self.makePlayer(action)
    }

    var currentID: String { current.id }
    var frame: SpriteFrame { current.frames[min(player.frameIndex, current.frames.count - 1)] }
    /// A looping action never finishes on its own, so it can't hold others back (that would
    /// leave the cat stuck, e.g. climbing forever); scripted climbs are driven by ExtrasController.
    var isInterruptible: Bool {
        !Transitions.uninterruptible.contains(currentID) || player.isFinished || current.playback == .loop
    }

    /// Ask for an action. `force` (user drag, safety) skips routing and interrupts anything.
    /// Returns false if the action is unknown or can't be reached.
    @discardableResult
    func request(_ id: String, force: Bool = false) -> Bool {
        guard library.action(id) != nil else {
            note("refused unknown action '\(id)'")
            return false
        }
        if force {
            queue = []
            start(id)
            return true
        }
        guard let path = Transitions.route(from: currentID, to: id, known: { self.library.action($0) != nil }) else {
            note("refused \(currentID) → \(id)")
            return false
        }
        if !isInterruptible {
            queue = path // Plays after the current sequence finishes.
            return true
        }
        queue = Array(path.dropFirst())
        start(path[0])
        return true
    }

    /// Stop on the current frame for a moment (a crouch before a pounce or jump).
    func freeze(for seconds: Double) { frozenFor = seconds }

    /// Which frame of the current action is showing (0-based).
    var frameIndex: Int { player.frameIndex }

    func tick(_ dt: Double) {
        if frozenFor > 0 {
            frozenFor -= dt
            return
        }
        if sustainLastFrame && player.playback != .loop &&
            player.elapsed + dt >= Double(player.frameCount) * player.secondsPerFrame - 0.001 {
            return
        }
        player.advance(by: dt)
        guard player.isFinished, !finishReported else { return }
        finishReported = true
        if !queue.isEmpty {
            start(queue.removeFirst())
            return
        }
        let finished = currentID
        if onFinished?(finished) == true, currentID != finished || !player.isFinished { return }
        if current.playback == .hold { return } // Hold stays on its last frame.
        request(Transitions.naturalNext(after: finished))
    }

    /// Swap to another cat's art without changing what the cat is doing.
    func swapLibrary(_ newLibrary: SpriteLibrary) {
        library = newLibrary
        guard let same = newLibrary.action(currentID) else { start("idle_sit"); return }
        let elapsed = player.elapsed
        current = same
        player = Self.makePlayer(same)
        player.advance(by: elapsed)
    }

    private func start(_ id: String) {
        guard let action = library.action(id) else { return }
        frozenFor = 0
        current = action
        player = Self.makePlayer(action)
        finishReported = false
    }

    private static func makePlayer(_ action: ResolvedAction) -> AnimationPlayer {
        AnimationPlayer(frameCount: action.frames.count, secondsPerFrame: action.secondsPerFrame, playback: action.playback)
    }

    private func note(_ message: String) {
        log.append(message)
        if log.count > 50 { log.removeFirst() }
        #if DEBUG
        print("[engine] \(message)")
        #endif
    }
}
