import CoreGraphics
import Foundation
import Testing
@testable import DesktopCat

/// Made-up monitor layouts, in Cocoa coordinates (the main display's bottom-left is 0,0).
enum Layouts {
    static let laptop = CGRect(x: 0, y: 0, width: 1728, height: 1117)
    /// A big monitor to the LEFT of the laptop: negative x, and taller.
    static let leftMonitor = CGRect(x: -2560, y: 0, width: 2560, height: 1440)
    /// A monitor stacked ABOVE the laptop.
    static let aboveMonitor = CGRect(x: 200, y: 1117, width: 1920, height: 1080)
    /// A monitor to the right, set lower, leaving a gap below the laptop's bottom.
    static let rightLow = CGRect(x: 1728, y: -300, width: 1920, height: 1080)
    static let all = [laptop, leftMonitor, aboveMonitor, rightLow]
}

@Suite struct ScreenBoundaryTests {
    let catW = 144.0

    @Test func floorRangeKeepsTheWholeCatOnScreen() {
        let r = ScreenMath.floorRange(visibleFrame: Layouts.laptop, catWidth: catW)
        #expect(r == 0...(1728 - 144))
    }

    @Test func floorRangeOnANegativeCoordinateMonitor() {
        let r = ScreenMath.floorRange(visibleFrame: Layouts.leftMonitor, catWidth: catW)
        #expect(r == -2560...(-144))
    }

    @Test func dockOnTheLeftNarrowsTheFloor() {
        let visible = CGRect(x: 80, y: 0, width: 1648, height: 1084) // Dock on the left
        #expect(ScreenMath.floorRange(visibleFrame: visible, catWidth: catW).lowerBound == 80)
    }

    @Test func catWiderThanTheScreenSitsAtTheLeftEdge() {
        let tiny = CGRect(x: 0, y: 0, width: 100, height: 100)
        #expect(ScreenMath.floorRange(visibleFrame: tiny, catWidth: catW) == 0...0)
    }

    @Test func picksTheScreenUnderTheCatsFeet() {
        let onLeft = CGRect(x: -500, y: 0, width: 144, height: 144)
        let onTop = CGRect(x: 600, y: 1117, width: 144, height: 144)
        let onRight = CGRect(x: 2000, y: -300, width: 144, height: 144)
        #expect(ScreenMath.screen(for: onLeft, in: Layouts.all) == 1)
        #expect(ScreenMath.screen(for: onTop, in: Layouts.all) == 2)
        #expect(ScreenMath.screen(for: onRight, in: Layouts.all) == 3)
    }

    @Test func straddlingTwoScreensUsesTheOneUnderItsCentre() {
        let straddle = CGRect(x: -100, y: 0, width: 144, height: 144) // centre at x=-28: left monitor
        #expect(ScreenMath.screen(for: straddle, in: Layouts.all) == 1)
        let other = CGRect(x: -20, y: 0, width: 144, height: 144)     // centre at x=52: laptop
        #expect(ScreenMath.screen(for: other, in: Layouts.all) == 0)
    }

    @Test func inAGapBetweenScreensFallsBackToTheNearest() {
        // Below the laptop, left of the low right monitor: no screen there.
        let lost = CGRect(x: 1500, y: -250, width: 144, height: 144)
        #expect(ScreenMath.screen(containing: CGPoint(x: lost.midX, y: lost.minY + 1), in: Layouts.all) == nil)
        let i = ScreenMath.screen(for: lost, in: Layouts.all)
        #expect(i == 0 || i == 3)
    }

    @Test func noScreensAtAllDoesNotCrash() {
        #expect(ScreenMath.screen(for: CGRect(x: 0, y: 0, width: 10, height: 10), in: []) == 0)
    }

    @Test func positionRoundTripsThroughAFraction() {
        let r = ScreenMath.floorRange(visibleFrame: Layouts.leftMonitor, catWidth: catW)
        for x in [r.lowerBound, -1300.0, r.upperBound] {
            let f = ScreenMath.fraction(of: x, in: r)
            #expect(abs(ScreenMath.x(forFraction: f, in: r) - x) < 1e-9)
        }
    }

    @Test func savedPositionMovesToASmallerScreenProportionally() {
        let big = ScreenMath.floorRange(visibleFrame: Layouts.leftMonitor, catWidth: catW)
        let small = ScreenMath.floorRange(visibleFrame: Layouts.laptop, catWidth: catW)
        let f = ScreenMath.fraction(of: big.upperBound, in: big) // far right of the big one
        #expect(ScreenMath.x(forFraction: f, in: small) == small.upperBound)
    }

    @Test func badSavedValuesAreClampedOrDefaulted() {
        let r = 0.0...1000.0
        #expect(ScreenMath.x(forFraction: 7, in: r) == 1000)
        #expect(ScreenMath.x(forFraction: -3, in: r) == 0)
        #expect(ScreenMath.x(forFraction: .nan, in: r) == 800)
        #expect(ScreenMath.x(forFraction: nil, in: r) == 800)
        #expect(ScreenMath.fraction(of: .infinity, in: r) == 0)
        #expect(ScreenMath.fraction(of: 5, in: 3...3) == 0)
    }

    @Test func restoresOntoTheSavedDisplayOrTheMainOne() {
        #expect(ScreenMath.restoreScreen(savedID: 42, attachedIDs: [1, 42, 7]) == 1)
        #expect(ScreenMath.restoreScreen(savedID: 99, attachedIDs: [1, 42]) == 0)   // unplugged
        #expect(ScreenMath.restoreScreen(savedID: nil, attachedIDs: [1, 42]) == 0)
    }

    @Test func changingSizeKeepsTheCentre() {
        // fluffy at 3× (144) → orange at 3× (120): centre stays at 572.
        let x = ScreenMath.x(keepingCenter: 500 + 72, newWidth: 120)
        #expect(x + 60 == 572)
    }

    @Test func brainNeverWalksOffAMonitorWithNegativeCoordinates() {
        let sim = Sim(seed: 21)
        sim.brain.floorRange = ScreenMath.floorRange(visibleFrame: Layouts.leftMonitor, catWidth: catW)
        sim.brain.x = -2000
        sim.run(seconds: 1200) { _ in #expect(sim.brain.floorRange.contains(sim.brain.x)) }
    }

    @Test func windowLedgesStayOnTheirOwnScreen() {
        // A window spilling off the left monitor onto the laptop: the ledge is clipped to the monitor.
        let w = WindowRect(id: 1, frame: CGRect(x: -800, y: 100, width: 1400, height: 500))
        let l = WindowGeometry.ledges(windows: [w], screen: Layouts.leftMonitor, catSize: CGSize(width: 144, height: 144))
        #expect(l.count == 1 && l[0].maxX == 0)
    }
}
