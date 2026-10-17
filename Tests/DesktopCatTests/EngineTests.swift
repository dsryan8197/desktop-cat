import Foundation
import Testing
@testable import DesktopCat

/// Seeded random numbers so behaviour tests are repeatable.
struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

/// The project folder (tests read the real manifest and art, not a copy).
let projectRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let manifest = try! Manifest.load(from: projectRoot.appendingPathComponent("specs/cats-and-actions.json"))
let assetRoot = projectRoot.appendingPathComponent("assets")
func library(_ index: Int) -> SpriteLibrary {
    SpriteLibrary(cat: manifest.cats[index], manifest: manifest, assetRoot: assetRoot)
}

@Suite struct AnimationPlayerTests {
    @Test func loopWraps() {
        var p = AnimationPlayer(frameCount: 4, secondsPerFrame: 0.1, playback: .loop)
        p.advance(by: 0.45)
        #expect(p.frameIndex == 0)
        #expect(!p.isFinished)
        #expect(p.completedLoops == 1)
    }

    @Test func onceFinishesAfterLastFrame() {
        var p = AnimationPlayer(frameCount: 4, secondsPerFrame: 0.1, playback: .once)
        p.advance(by: 0.35)
        #expect(p.frameIndex == 3)
        #expect(!p.isFinished)
        p.advance(by: 0.1)
        #expect(p.isFinished)
        #expect(p.frameIndex == 3)
    }

    @Test func holdStaysOnLastFrame() {
        var p = AnimationPlayer(frameCount: 4, secondsPerFrame: 0.1, playback: .hold)
        p.advance(by: 10)
        #expect(p.isFinished)
        #expect(p.frameIndex == 3)
    }

    @Test func reversed() {
        var p = AnimationPlayer(frameCount: 4, secondsPerFrame: 0.1, playback: .once, reversed: true)
        #expect(p.frameIndex == 3)
        p.advance(by: 0.31)
        #expect(p.frameIndex == 0)
    }
}

@Suite struct TransitionTests {
    let known: (String) -> Bool = { _ in true }

    @Test func sleepToWalkWakesAndGetsUpFirst() {
        #expect(Transitions.route(from: "sleep", to: "walk", known: known) == ["wake_up", "get_up", "walk"])
    }

    @Test func idleToSleepLiesDownFirst() {
        #expect(Transitions.route(from: "idle_sit", to: "sleep", known: known) == ["lie_down", "sleep"])
    }

    @Test func unknownTargetRefused() {
        #expect(Transitions.route(from: "idle_sit", to: "fly", known: { $0 != "fly" }) == nil)
    }

    @Test func getUpWhenStandingRefused() {
        #expect(Transitions.route(from: "walk", to: "get_up", known: known) == nil)
    }
}

@Suite struct LibraryAndEngineTests {
    @Test func readyArtLoadsCleanly() {
        let libs = [library(0), library(1)]
        for lib in libs { #expect(lib.problems == [], "\(lib.cat.id) asset problems") }
        #expect(libs.map(\.frameWidth) == [48, 40])
    }

    @Test func readyActionsHaveRealArtAndOthersArePlaceholders() {
        for lib in [library(0), library(1)] {
            for a in manifest.actions {
                let r = lib.action(a.id)!
                if a.assetStatus == .ready {
                    #expect(r.frames.allSatisfy { !$0.isPlaceholder }, "\(a.id) should be real art")
                } else if SpriteLibrary.borrowedFrames[a.id] == nil {
                    let allPlaceholders = r.frames.allSatisfy { $0.isPlaceholder }
                    #expect(allPlaceholders, "\(a.id) has no art and must show a placeholder")
                }
            }
        }
    }

    @Test func wakeUpIsLieDownBackwards() {
        let lib = library(0)
        let wake = lib.action("wake_up")!, lie = lib.action("lie_down")!
        #expect(wake.borrowedFrom == "lie_down")
        #expect(wake.frames.first!.alpha == lie.frames.last!.alpha)
        #expect(wake.frames.first!.alpha != lie.frames.first!.alpha)
    }

    @Test func missingFolderGivesPlaceholdersNotCrash() {
        let lib = SpriteLibrary(cat: manifest.cats[0], manifest: manifest, assetRoot: URL(fileURLWithPath: "/nonexistent"))
        let allPlaceholders = lib.action("walk")!.frames.allSatisfy { $0.isPlaceholder }
        #expect(allPlaceholders)
        #expect(!lib.problems.isEmpty)
    }

    @Test func engineRefusesUnknownAndRoutesFromSleep() {
        let engine = AnimationEngine(library: library(0))
        #expect(!engine.request("does_not_exist"))
        #expect(engine.request("sleep"))
        #expect(engine.currentID == "lie_down")
        engine.tick(5)
        #expect(engine.currentID == "sleep")
        engine.request("walk")
        #expect(engine.currentID == "wake_up")
        #expect(engine.queue == ["get_up", "walk"])
    }

    @Test func uninterruptibleActionQueuesRequest() {
        let engine = AnimationEngine(library: library(0))
        engine.request("jump")
        engine.request("walk")
        #expect(engine.currentID == "jump")
        #expect(engine.queue == ["walk"])
        engine.tick(1)
        #expect(engine.currentID == "walk")
    }

    @Test func switchingCatsKeepsAction() {
        let engine = AnimationEngine(library: library(0))
        engine.request("walk")
        engine.swapLibrary(library(1))
        #expect(engine.currentID == "walk")
        #expect(engine.frame.width == 40)
    }

    @Test func brainWalksWithinFloor() {
        let engine = AnimationEngine(library: library(0))
        let brain = Brain(engine: engine, rng: SeededRNG(state: 7))
        brain.floorRange = 0...500
        brain.x = 250
        var sawWalk = false
        for _ in 0..<(60 * 120) {
            engine.tick(1.0 / 60)
            brain.update(1.0 / 60)
            if engine.currentID == "walk" { sawWalk = true }
            #expect(brain.floorRange.contains(brain.x))
        }
        #expect(sawWalk)
    }
}

@Suite struct SettingsTests {
    @Test func persistsAndRejectsBadScale() {
        let defaults = UserDefaults(suiteName: "DesktopCatTests-\(UUID())")!
        let s = Settings(defaults: defaults)
        #expect(s.scale == 3)
        #expect(s.catID == "fluffy_b")
        s.scale = 99
        #expect(s.scale == 3)
        s.catID = "orange_c"
        s.position = SavedPosition(displayID: 1, fraction: 0.25, facingRight: false)
        let again = Settings(defaults: defaults)
        #expect(again.catID == "orange_c")
        #expect(again.position == SavedPosition(displayID: 1, fraction: 0.25, facingRight: false))
    }
}
