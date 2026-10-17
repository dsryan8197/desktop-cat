import Foundation
import Testing
@testable import DesktopCat

func props(_ index: Int) -> PropSet {
    PropSet.load(catFolder: assetRoot.appendingPathComponent(SpriteLibrary.folderName(manifest.cats[index])))
}

@Suite struct NeedsTests {
    let start = Date(timeIntervalSince1970: 1_000_000)

    @Test func drainsByTheHourAndStopsAtZero() {
        var n = Needs(now: start)
        n.advance(to: start.addingTimeInterval(4 * 3600))
        #expect(abs(n.hunger - 0.5) < 1e-9)       // empty after 8 h
        #expect(abs(n.thirst - (1 - 4.0 / 6)) < 1e-9)
        #expect(n.fun == 0)                       // empty after 4 h
        #expect(n.low == [.fun])
        n.advance(to: start.addingTimeInterval(100 * 3600))
        #expect(n.hunger == 0 && n.thirst == 0 && n.fun == 0)
    }

    @Test func clockGoingBackwardsDrainsNothing() {
        var n = Needs(now: start)
        n.advance(to: start.addingTimeInterval(-3600))
        #expect(n.hunger == 1)
    }

    @Test func satisfyCapsAtFullAndStampsTime() {
        var n = Needs(now: start)
        let later = start.addingTimeInterval(2 * 3600)
        n.satisfy(.hunger, by: 1, at: later)
        #expect(n.hunger == 1)
        #expect(n.lastFed == later)
    }

    @Test func savedWithTimestampsAndCaughtUpOnLoad() {
        let defaults = UserDefaults(suiteName: "DesktopCatCare-\(UUID())")!
        let s = Settings(defaults: defaults)
        var n = Needs(now: start)
        n.satisfy(.thirst, by: 1, at: start)
        s.needs = n
        var loaded = Settings(defaults: defaults).needs!
        #expect(loaded == n)
        loaded.advance(to: start.addingTimeInterval(3 * 3600))
        #expect(abs(loaded.thirst - 0.5) < 1e-9)
    }
}

@Suite struct PropTests {
    @Test func bothCatsHaveAllProps() {
        for i in 0..<2 {
            let p = props(i)
            for kind in PropKind.allCases { #expect(p.has(kind), "\(manifest.cats[i].id) missing \(kind)") }
            #expect(p.yarnEnd != nil)
        }
    }

    @Test func alignmentRoundTripsInBothDirections() {
        let bowl = props(0).placement(.foodBowl)!
        for right in [true, false] {
            let catX = bowl.catX(forPropX: 500, facingRight: right, scale: 3)
            #expect(bowl.propX(forCatX: catX, facingRight: right, scale: 3) == 500)
        }
        // Facing right the bowl is in front (to the right) of the cat's left edge.
        #expect(bowl.catX(forPropX: 500, facingRight: true, scale: 3) == 500 - Double(bowl.left) * 3)
    }

    @Test func yarnFallsBouncesAndComesToRest() {
        var ball = YarnPhysics(x: 100, y: 800, size: 39)
        ball.vx = 400
        var bounced = false
        for _ in 0..<(60 * 10) {
            let wasGoingDown = ball.vy < 0
            ball.step(1.0 / 60, floorY: 0, minX: 0, maxX: 1000)
            if wasGoingDown && ball.vy > 0 { bounced = true }
            #expect(ball.x >= 0 && ball.x <= 1000 - 39)
            #expect(ball.y >= 0)
        }
        #expect(bounced)
        #expect(ball.isResting)
    }
}

/// Plays the controller's part for the ball in tests.
func runYarn(_ sim: Sim, seconds: Double, ball start: YarnPhysics) -> [BrainSignal] {
    var ball = start
    var signals: [BrainSignal] = []
    var held = false
    sim.run(seconds: seconds) { _ in
        for s in sim.brain.takeSignals() {
            signals.append(s)
            switch s {
            case .pickedUpYarn: held = true
            case let .battedYarn(fromX, direction, _):
                held = false
                ball.x = fromX
                ball.vx = direction * 400
                ball.vy = direction == 0 ? 0 : 260
                ball.onGround = direction == 0
            default: break
            }
        }
        if !held { ball.step(1.0 / 30, floorY: 0, minX: 0, maxX: 1200) }
        sim.brain.yarnBall = YarnBallState(x: ball.x, width: ball.size, vx: ball.vx, onGround: ball.onGround)
    }
    return signals
}

@Suite struct ErrandTests {
    func quietSim(seed: UInt64 = 1) -> Sim {
        let sim = Sim(seed: seed)
        sim.brain.tuning.weights = .init(idle: 1, walk: 0, groom: 0, rest: 0, look: 0)
        sim.brain.tuning.blinkEvery = 1000...1000
        sim.brain.spriteWidth = 144
        return sim
    }

    @Test func walksToTheBowlLinesUpAndEats() {
        let sim = quietSim()
        let p = props(0).placement(.foodBowl)!
        sim.brain.startBowl(BowlErrand(need: .hunger, propX: 200, propWidth: 48, placement: p))
        var signals: [BrainSignal] = []
        sim.run(seconds: 10) { _ in signals += sim.brain.takeSignals() }
        #expect(signals.first == .startedEating(.hunger))
        #expect(sim.seen.contains("walk"))
        // The bowl drawn in the eat frames lands exactly on the bowl on screen.
        #expect(p.propX(forCatX: sim.brain.x, facingRight: sim.brain.facingRight, scale: 3) == 200)
        #expect(!sim.brain.facingRight) // came from the right, so it faces left
        sim.run(seconds: 8) { _ in signals += sim.brain.takeSignals() }
        #expect(signals.contains(.stoppedEating(.hunger, finished: true)))
        #expect(sim.seen.contains("eat") && sim.seen.contains("happy"))
        #expect(sim.brain.bowl == nil)
    }

    @Test func aBowlWakesASleepingCat() {
        let sim = quietSim()
        sim.brain.playExplicit("sleep")
        sim.run(seconds: 2.5)
        #expect(sim.engine.currentID == "sleep")
        sim.brain.startBowl(BowlErrand(need: .thirst, propX: 900, propWidth: 48, placement: props(0).placement(.waterBowl)!))
        sim.run(seconds: 15)
        #expect(sim.seen.contains("drink"))
    }

    @Test func pickedUpMidMealPutsBowlBackThenFinishes() {
        let sim = quietSim()
        sim.brain.x = 300
        sim.brain.startBowl(BowlErrand(need: .hunger, propX: 340, propWidth: 48, placement: props(0).placement(.foodBowl)!))
        sim.run(seconds: 2)
        #expect(sim.brain.eating)
        _ = sim.brain.takeSignals()
        sim.brain.interrupt()
        sim.brain.resetToIdle()
        #expect(sim.brain.takeSignals() == [.stoppedEating(.hunger, finished: false)])
        sim.brain.x = 800 // dropped somewhere else
        var signals: [BrainSignal] = []
        sim.run(seconds: 25) { _ in signals += sim.brain.takeSignals() }
        #expect(signals.contains(.stoppedEating(.hunger, finished: true)))
    }

    @Test func chasesAndBatsTheYarnThenIsHappy() {
        let sim = quietSim(seed: 2)
        let p = props(0)
        sim.brain.startYarn(YarnErrand(roundsLeft: 3, placement: p.placement(.yarn)!, endPlacement: p.yarnEnd!))
        let signals = runYarn(sim, seconds: 60, ball: YarnPhysics(x: 900, y: 600, size: 39))
        let bats = signals.compactMap { s -> Bool? in if case let .battedYarn(_, _, last) = s { return last } else { return nil } }
        #expect(bats == [false, false, true])
        #expect(sim.seen.contains("look_up"))   // watched it fall
        #expect(sim.seen.contains("chase") && sim.seen.contains("play_yarn") && sim.seen.contains("happy"))
        #expect(sim.brain.yarn == nil)
    }

    @Test func lowNeedsMakeItBegAndGetBoredWithRealArt() {
        let sim = Sim(seed: 11)
        sim.brain.lowNeeds = [.hunger, .thirst, .fun]
        sim.run(seconds: 1800)
        for id in ["beg", "sad", "bored"] { #expect(sim.seen.contains(id), "never saw \(id)") }
        let lib = library(0)
        for id in Set(sim.seen) { #expect(lib.action(id)!.hasRealArt, "\(id) has no art") }
    }
}
