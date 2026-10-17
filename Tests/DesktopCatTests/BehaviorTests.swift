import Foundation
import Testing
@testable import DesktopCat

/// Runs the brain and engine together on a fake clock.
final class Sim {
    let engine: AnimationEngine
    let brain: Brain
    var seen: [String] = []

    init(seed: UInt64, energy: Energy = .normal) {
        engine = AnimationEngine(library: library(0))
        brain = Brain(engine: engine, rng: SeededRNG(state: seed))
        brain.tuning = energy.tuning
        brain.floorRange = 0...1200
        brain.x = 600
    }

    func run(seconds: Double, dt: Double = 1.0 / 30, each: ((Double) -> Void)? = nil) {
        var t = 0.0
        while t < seconds {
            each?(t)
            engine.tick(dt)
            brain.update(dt)
            if seen.last != engine.currentID { seen.append(engine.currentID) }
            t += dt
        }
    }
}

@Suite struct BehaviorTests {
    @Test func twoHoursOnlyUseRealArtAndCoverTheBasics() {
        let sim = Sim(seed: 42)
        var idle = 0.0
        sim.run(seconds: 2 * 3600) { t in
            // 20 minutes of you working, then 15 minutes away, repeating.
            let away = t.truncatingRemainder(dividingBy: 2100) > 1200
            idle = away ? idle + 1.0 / 30 : 0
            sim.brain.userIdleSeconds = idle
            sim.brain.cursorOffset = Int(t) % 97 == 0 ? (dx: 20, dy: 120) : nil
            #expect(sim.brain.floorRange.contains(sim.brain.x))
        }
        let lib = library(0)
        for id in Set(sim.seen) {
            #expect(lib.action(id)!.hasRealArt, "behaviour picked \(id), which has no art")
        }
        for id in ["walk", "groom", "blink", "yawn", "lie_down", "sleep", "wake_up", "get_up", "look_up"] {
            #expect(sim.seen.contains(id), "never saw \(id)")
        }
    }

    @Test func sleepsWhileYouAreAwayAndWakesWhenYouReturn() {
        let sim = Sim(seed: 3)
        sim.brain.userIdleSeconds = 10_000
        sim.run(seconds: 20)
        #expect(sim.engine.currentID == "sleep")
        #expect(Array(sim.seen.suffix(3)) == ["yawn", "lie_down", "sleep"])
        sim.run(seconds: 600)
        #expect(sim.engine.currentID == "sleep", "keeps sleeping while you're away")

        sim.brain.userIdleSeconds = 0
        sim.seen = []
        sim.run(seconds: 10)
        #expect(Array(sim.seen.prefix(3)) == ["sleep", "wake_up", "get_up"])
        #expect(sim.engine.currentID != "sleep")
    }

    @Test func looksAtCursorAtMostEvery20Seconds() {
        let sim = Sim(seed: 5)
        sim.brain.tuning.weights = .init(idle: 1, walk: 0, groom: 0, rest: 0, look: 0)
        sim.brain.tuning.blinkEvery = 1000...1000
        sim.brain.cursorOffset = (dx: 30, dy: 150)
        sim.run(seconds: 19)
        #expect(sim.seen.filter { $0 == "look_up" }.count == 1)
        sim.run(seconds: 2)
        #expect(sim.seen.filter { $0 == "look_up" }.count == 2)
    }

    @Test func groomingRepeatsTwoToFourTimes() {
        for seed in UInt64(1)...20 {
            let sim = Sim(seed: seed)
            sim.brain.tuning.weights = .init(idle: 0, walk: 0, groom: 1, rest: 0, look: 0)
            sim.brain.tuning.blinkEvery = 1000...1000
            sim.brain.tuning.idleSeconds = 1...1
            sim.brain.resetToIdle() // Re-rolls the first wait with the new tuning.
            var grooms = 0
            var burstOver = false
            sim.run(seconds: 8) { _ in
                guard !burstOver else { return }
                if sim.engine.currentID == "groom" && sim.engine.player.elapsed == 0 { grooms += 1 }
                if grooms > 0 && sim.engine.currentID == "idle_sit" { burstOver = true }
            }
            #expect(burstOver)
            #expect((2...4).contains(grooms), "seed \(seed): groomed \(grooms) times")
        }
    }

    @Test func energyLevelsChangeHowOftenItDecides() {
        #expect(Energy.lively.tuning.idleSeconds.upperBound < Energy.normal.tuning.idleSeconds.lowerBound + 5)
        #expect(Energy.calm.tuning.weights.walk < Energy.lively.tuning.weights.walk)
    }
}
