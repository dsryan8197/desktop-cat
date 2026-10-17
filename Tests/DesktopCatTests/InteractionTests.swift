import Foundation
import Testing
@testable import DesktopCat

/// Feeds a cursor path (60 samples per second) into the gesture reader.
func events(_ g: inout CursorGestures, from t0: Double, seconds: Double, inside: Bool = true,
            path: (Double) -> (Double, Double)) -> [GestureEvent] {
    var out: [GestureEvent] = []
    var t = t0
    while t < t0 + seconds {
        let (x, y) = path(t - t0)
        if let e = g.feed(time: t, x: x, y: y, inside: inside) { out.append(e) }
        t += 1.0 / 60
    }
    return out
}

@Suite struct GestureTests {
    // Fast wiggle: 50 points side to side, 4 times a second (~800 pt/s).
    let wiggle: (Double) -> (Double, Double) = { t in (100 + 25 * sin(t * 2 * .pi * 4), 100) }
    // Slow stroke: 120 pt/s back and forth across the cat.
    let stroke: (Double) -> (Double, Double) = { t in (100 + 60 * sin(t * 2), 100) }

    @Test func fastWiggleIsATickle() {
        var g = CursorGestures()
        #expect(events(&g, from: 0, seconds: 1.5, path: wiggle) == [.tickle])
    }

    @Test func tickleHasACooldown() {
        var g = CursorGestures()
        let e = events(&g, from: 0, seconds: 5, path: wiggle)
        #expect(e == [.tickle])
        #expect(events(&g, from: 5, seconds: 3, path: wiggle) == [.tickle])
    }

    @Test func wigglingBesideTheCatDoesNothing() {
        var g = CursorGestures()
        #expect(events(&g, from: 0, seconds: 2, inside: false, path: wiggle).isEmpty)
    }

    @Test func fastStraightSwipeIsNotATickle() {
        var g = CursorGestures()
        #expect(events(&g, from: 0, seconds: 0.5) { t in (t * 1500, 100) }.isEmpty)
    }

    @Test func slowStrokesArePettingThenStop() {
        var g = CursorGestures()
        #expect(events(&g, from: 0, seconds: 0.5, path: stroke).isEmpty)
        #expect(events(&g, from: 0.5, seconds: 2, path: stroke) == [.pettingBegan])
        #expect(g.isPetting)
        #expect(events(&g, from: 2.5, seconds: 2) { _ in (100, 100) } == [.pettingEnded])
    }
}

@Suite struct ReactionTests {
    func quietSim(seed: UInt64 = 1) -> Sim {
        let sim = Sim(seed: seed)
        sim.brain.tuning.weights = .init(idle: 1, walk: 0, groom: 0, rest: 0, look: 0)
        sim.brain.tuning.blinkEvery = 1000...1000
        return sim
    }

    @Test func tickleGigglesRollsOverThenGetsUp() {
        let sim = quietSim()
        sim.run(seconds: 1)
        sim.brain.react(.tickle)
        sim.run(seconds: 12)
        // The revised roll passes through belly-up and ends lying down, so it gets up next.
        #expect(Array(sim.seen.prefix(5)) == ["idle_sit", "happy", "roll_over", "get_up", "idle_sit"])
    }

    @Test func ticklingASleepingCatRollsItStraightOver() {
        let sim = quietSim()
        sim.brain.playExplicit("sleep")
        sim.run(seconds: 2.5)
        #expect(sim.engine.currentID == "sleep")
        sim.brain.react(.tickle)
        #expect(sim.engine.currentID == "roll_over")
    }

    @Test func pettingKneadsUntilYouStopThenHappy() {
        let sim = quietSim()
        sim.run(seconds: 1)
        sim.brain.react(.pettingBegan)
        sim.run(seconds: 30)
        #expect(sim.engine.currentID == "knead", "keeps kneading while petted")
        sim.brain.react(.pettingEnded)
        #expect(sim.engine.currentID == "happy")
        sim.run(seconds: 2)
        #expect(sim.engine.currentID == "idle_sit")
    }

    @Test func wavesWhenYouComeBack() {
        let sim = quietSim()
        sim.brain.tuning.sleepWhenAwaySeconds = 10_000...10_000
        sim.brain.resetToIdle()
        var idle = 0.0
        sim.run(seconds: 70) { _ in idle += 1.0 / 30; sim.brain.userIdleSeconds = idle }
        #expect(!sim.seen.contains("wave"))
        sim.brain.userIdleSeconds = 0
        sim.run(seconds: 0.1)
        #expect(sim.engine.currentID == "wave")
        sim.run(seconds: 3)
        #expect(sim.seen.filter { $0 == "wave" }.count == 1) // two waves back to back
        #expect(sim.engine.currentID == "idle_sit")
    }

    @Test func wakesThenWavesAfterSleepingWhileAway() {
        let sim = quietSim(seed: 4)
        sim.brain.userIdleSeconds = 10_000
        sim.run(seconds: 20)
        #expect(sim.engine.currentID == "sleep")
        sim.brain.userIdleSeconds = 0
        sim.seen = []
        sim.run(seconds: 10)
        #expect(Array(sim.seen.prefix(4)) == ["sleep", "wake_up", "get_up", "wave"])
    }

    @Test func clickWakesANappingCat() {
        let sim = quietSim()
        sim.brain.playExplicit("sleep")
        sim.run(seconds: 2.5)
        sim.brain.poked()
        #expect(sim.engine.currentID == "wake_up")
    }

    @Test func waveAndCarriedBorrowRealFrames() {
        let lib = library(0)
        #expect(lib.action("wave")?.borrowedFrom == "play_paw")
        #expect(lib.action("carried")?.borrowedFrom == "dangle")
        #expect(lib.action("wave")!.hasRealArt)
    }
}
