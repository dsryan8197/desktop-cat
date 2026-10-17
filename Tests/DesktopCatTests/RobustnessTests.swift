import Foundation
import Testing
@testable import DesktopCat

@Suite struct TransitionMatrixTests {
    let ids = manifest.actions.map(\.id)

    /// Every action, requested from every other action: never crashes, always ends up
    /// showing a real manifest action, and accepted requests are actually reached.
    @Test func everyActionFromEveryAction() {
        let lib = library(0)
        for from in ids {
            for to in ids {
                let engine = AnimationEngine(library: lib)
                engine.request(from, force: true)
                var seen: [String] = []
                let accepted = engine.request(to)
                for _ in 0..<600 { // up to 10 s
                    if seen.last != engine.currentID { seen.append(engine.currentID) }
                    engine.tick(1.0 / 60)
                }
                #expect(lib.action(engine.currentID) != nil)
                if accepted {
                    #expect(seen.contains(to), "\(from) → \(to) accepted but never played (\(seen))")
                }
            }
        }
    }

    @Test func standingUpFromLyingAlwaysGoesThroughGetUp() {
        let standing = ids.filter { !Transitions.lying.contains($0) && $0 != "get_up" }
        for from in Transitions.lying where ids.contains(from) {
            for to in standing {
                let path = Transitions.route(from: from, to: to, known: { ids.contains($0) }) ?? []
                #expect(path.dropLast().contains("get_up"), "\(from) → \(to) skips get_up: \(path)")
            }
        }
    }

    @Test func randomRequestStormNeverBreaksTheEngine() {
        var rng = SeededRNG(state: 99)
        let engine = AnimationEngine(library: library(1))
        for _ in 0..<5000 {
            if Int.random(in: 0..<3, using: &rng) == 0 {
                engine.request(ids.randomElement(using: &rng)!, force: Bool.random(using: &rng))
            }
            if Int.random(in: 0..<50, using: &rng) == 0 { engine.request("no_such_action") }
            engine.tick(Double.random(in: 0...0.2, using: &rng))
            #expect(engine.player.frameIndex < engine.current.frames.count)
        }
    }

    @Test func placeholderActionsStayOnScreenLongEnoughToRead() {
        let a = library(0).action("shake")!
        #expect(!a.hasRealArt)
        #expect(a.secondsPerFrame >= 1)
        #expect(a.frames.allSatisfy { $0.placeholderText?.contains("shake") == true })
    }
}

@Suite struct PlaybackEdgeTests {
    @Test func zeroAndNegativeTimeChangeNothing() {
        var p = AnimationPlayer(frameCount: 4, secondsPerFrame: 0.1, playback: .loop)
        p.advance(by: 0)
        p.advance(by: -5)
        #expect(p.elapsed == 0 && p.frameIndex == 0)
    }

    @Test func nonsenseSettingsAreClampedNotFatal() {
        var p = AnimationPlayer(frameCount: 0, secondsPerFrame: 0, playback: .once)
        p.advance(by: 1)
        #expect(p.frameCount == 1 && p.frameIndex == 0 && p.isFinished)
    }

    @Test func aHugeTimeStepStillLandsOnAValidFrame() {
        var loop = AnimationPlayer(frameCount: 6, secondsPerFrame: 0.1, playback: .loop)
        loop.advance(by: 1_000_000.05)
        #expect((0..<6).contains(loop.frameIndex))
        var once = AnimationPlayer(frameCount: 6, secondsPerFrame: 0.1, playback: .once)
        once.advance(by: 1_000_000)
        #expect(once.frameIndex == 5 && once.isFinished)
    }

    @Test func eightFrameWalkTakesOneSecondPerCycle() {
        let walk = library(0).action("walk")!
        #expect(walk.frames.count == 8)
        var p = AnimationPlayer(frameCount: walk.frames.count, secondsPerFrame: walk.secondsPerFrame, playback: .loop)
        p.advance(by: 1.0)
        #expect(p.completedLoops == 1 && p.frameIndex == 0)
    }

    @Test func blinkPlaysOnceAndReturnsToSitting() {
        let engine = AnimationEngine(library: library(1))
        engine.request("blink")
        engine.tick(0.3)
        #expect(engine.currentID == "blink")
        engine.tick(1)
        #expect(engine.currentID == "idle_sit")
    }
}

@Suite struct SettingsEdgeTests {
    func fresh() -> Settings { Settings(defaults: UserDefaults(suiteName: "DesktopCatEdge-\(UUID())")!) }

    @Test func defaultsAreSafe() {
        let s = fresh()
        #expect(!s.chaseCursor && !s.jumpOnWindows && !s.hangOffEdges && !s.peekBehindWindows) // opt-in
        #expect(s.pauseInFullScreen && s.pauseInLowPower)                                       // considerate
        #expect(!s.paused && !s.hidden)
        #expect(s.energy == .normal)
        #expect(s.position == nil && s.needs == nil)
    }

    @Test func everyToggleSurvivesARestart() {
        let defaults = UserDefaults(suiteName: "DesktopCatEdge-\(UUID())")!
        let s = Settings(defaults: defaults)
        s.chaseCursor = true; s.jumpOnWindows = true; s.hangOffEdges = true; s.peekBehindWindows = true
        s.pauseInFullScreen = false; s.pauseInLowPower = false; s.paused = true; s.hidden = true
        s.energy = .lively; s.scale = 5
        let t = Settings(defaults: defaults)
        #expect(t.chaseCursor && t.jumpOnWindows && t.hangOffEdges && t.peekBehindWindows)
        #expect(!t.pauseInFullScreen && !t.pauseInLowPower && t.paused && t.hidden)
        #expect(t.energy == .lively && t.scale == 5)
    }

    @Test func corruptSavedDataIsIgnored() {
        let defaults = UserDefaults(suiteName: "DesktopCatEdge-\(UUID())")!
        defaults.set(Data("not json".utf8), forKey: "position")
        defaults.set(Data([0, 1, 2]), forKey: "needs")
        defaults.set("hyper", forKey: "energy")
        defaults.set(0, forKey: "scale")
        let s = Settings(defaults: defaults)
        #expect(s.position == nil && s.needs == nil && s.energy == .normal && s.scale == 3)
    }

    @Test func switchingCatsKeepsEverythingElse() {
        let s = fresh()
        s.scale = 4; s.energy = .calm; s.jumpOnWindows = true
        s.position = SavedPosition(displayID: 3, fraction: 0.4, facingRight: true)
        s.catID = "orange_c"
        #expect(s.scale == 4 && s.energy == .calm && s.jumpOnWindows)
        #expect(s.position == SavedPosition(displayID: 3, fraction: 0.4, facingRight: true))
    }

    @Test func unknownSavedCatFallsBackToTheFirstCat() {
        #expect(manifest.resolveCat("tabby_z").id == "fluffy_b")
        #expect(manifest.resolveCat("orange_c").id == "orange_c")
    }
}

@Suite struct ManifestRobustnessTests {
    @Test func unknownPlaybackOrStatusDoesNotBreakLoading() throws {
        let json = """
        {"schemaVersion": 1, "cats": [{"id": "x", "name": "X", "assetDirectory": "assets/x"}],
         "actions": [{"id": "a", "label": "A", "category": "idle", "playback": "bounce",
                      "frames": ["a_01.png"], "assetStatus": "MAYBE"}]}
        """
        let m = try JSONDecoder().decode(Manifest.self, from: Data(json.utf8))
        #expect(m.actions[0].playback == .once)
        #expect(m.actions[0].assetStatus == .toCreate) // unknown status never claims art exists
    }

    @Test func brokenManifestIsAnErrorNotACrash() {
        #expect(throws: (any Error).self) { try JSONDecoder().decode(Manifest.self, from: Data("{".utf8)) }
        #expect(throws: (any Error).self) { try Manifest.load(from: URL(fileURLWithPath: "/nope.json")) }
    }
}
