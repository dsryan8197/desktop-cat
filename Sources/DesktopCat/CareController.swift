import AppKit

/// Food, water and the yarn ball: puts the props on the floor, sends the cat on
/// errands, and keeps hunger / thirst / fun up to date (saved with timestamps).
final class CareController {
    private let settings: Settings
    private let brain: Brain
    private let catWindow: NSWindow
    private(set) var needs: Needs
    private(set) var props: PropSet
    private var scale: Double

    private struct Bowl { let window: PropWindow; let kind: PropKind; let need: Need; var fadeIn: Double? }
    private struct Ball { let window: PropWindow; var physics: YarnPhysics; var held = false; var finishing = false; var removeIn: Double? }
    private var bowl: Bowl?
    private var ball: Ball?
    private var saveIn = 30.0

    init(settings: Settings, brain: Brain, catWindow: NSWindow, props: PropSet, scale: Double) {
        self.settings = settings
        self.brain = brain
        self.catWindow = catWindow
        self.props = props
        self.scale = scale
        var n = settings.needs ?? Needs()
        n.advance(to: Date()) // Catch up on time the app was closed.
        needs = n
        brain.lowNeeds = needs.low
    }

    var canPutBowlDown: Bool { bowl == nil }
    var canTossYarn: Bool { ball == nil && props.has(.yarn) }
    func hasArt(for kind: PropKind) -> Bool { props.has(kind) }

    // MARK: - Menu commands

    func feed(floor: NSRect) { putBowl(.foodBowl, need: .hunger, floor: floor) }
    func fillWater(floor: NSRect) { putBowl(.waterBowl, need: .thirst, floor: floor) }

    func tossYarn(floor: NSRect) {
        guard canTossYarn, let image = props.images[.yarn], let start = props.placement(.yarn), let end = props.yarnEnd else { return }
        let size = Double(image.width) * scale
        let x = spot(width: size, floor: floor)
        // Dropped in from near the top of the screen, drifting toward the cat.
        var physics = YarnPhysics(x: x, y: Double(floor.maxY) - size - 20, size: size)
        physics.vx = x < brain.x ? 120 : -120
        let window = PropWindow(image: image, scale: scale)
        ball = Ball(window: window, physics: physics)
        show(window, at: NSPoint(x: x, y: physics.y))
        brain.startYarn(YarnErrand(roundsLeft: Int.random(in: 3...5), placement: start, endPlacement: end))
    }

    private func putBowl(_ kind: PropKind, need: Need, floor: NSRect) {
        guard canPutBowlDown, let image = props.images[kind], let placement = props.placement(kind) else { return }
        let width = Double(image.width) * scale
        let x = spot(width: width, floor: floor)
        let window = PropWindow(image: image, scale: scale)
        bowl = Bowl(window: window, kind: kind, need: need, fadeIn: nil)
        show(window, at: NSPoint(x: x, y: Double(floor.minY) + Double(placement.bottom) * scale))
        brain.startBowl(BowlErrand(need: need, propX: x, propWidth: width, placement: placement))
    }

    /// A spot a short walk from the cat, on whichever side has more room.
    private func spot(width: Double, floor: NSRect) -> Double {
        let center = brain.x + brain.spriteWidth / 2
        let distance = 260 * scale / 3
        let roomy = Double(floor.maxX) - center > center - Double(floor.minX)
        let x = roomy ? center + distance : center - distance - width
        let lo = Double(floor.minX) + brain.spriteWidth, hi = Double(floor.maxX) - brain.spriteWidth - width
        return lo <= hi ? min(max(x, lo), hi) : Double(floor.midX) - width / 2
    }

    private func show(_ window: PropWindow, at origin: NSPoint) {
        window.setFrameOrigin(origin)
        window.orderFrontRegardless()
        catWindow.orderFrontRegardless() // The cat stays in front of its props.
    }

    // MARK: - Clock

    func tick(_ dt: Double, floor: NSRect) {
        needs.advance(to: Date())
        brain.lowNeeds = needs.low
        for signal in brain.takeSignals() { handle(signal, floor: floor) }
        updateBall(dt, floor: floor)
        updateBowlFade(dt)
        saveIn -= dt
        if saveIn <= 0 { save() }
    }

    /// Hiding the cat hides its props too.
    func setPropsVisible(_ visible: Bool) {
        if let b = bowl, !brain.eating { visible ? show(b.window, at: b.window.frame.origin) : b.window.orderOut(nil) }
        if let b = ball, !b.held { visible ? show(b.window, at: b.window.frame.origin) : b.window.orderOut(nil) }
    }

    private func handle(_ signal: BrainSignal, floor: NSRect) {
        switch signal {
        case .startedEating:
            bowl?.window.orderOut(nil) // The eating frames draw this same bowl.
        case let .stoppedEating(need, finished):
            if let b = bowl { show(b.window, at: b.window.frame.origin) }
            guard finished else { return }
            needs.satisfy(need, by: 1.0, at: Date())
            bowl?.fadeIn = 4
            save()
        case .pickedUpYarn:
            ball?.held = true
            ball?.window.orderOut(nil) // play_yarn draws the ball.
        case let .battedYarn(fromX, direction, last):
            guard var b = ball else { return }
            b.held = false
            b.physics.x = fromX
            b.physics.y = Double(floor.minY) + Double(props.yarnEnd?.bottom ?? 1) * scale
            b.physics.vx = direction * Double.random(in: 260...520)
            b.physics.vy = direction == 0 ? 0 : 260
            b.physics.onGround = direction == 0
            b.finishing = last
            ball = b
            show(b.window, at: NSPoint(x: fromX, y: b.physics.y))
            if direction != 0 {
                needs.satisfy(.fun, by: 0.2, at: Date())
                save()
            }
        }
    }

    private func updateBall(_ dt: Double, floor: NSRect) {
        guard var b = ball else { brain.yarnBall = nil; return }
        if !b.held {
            b.physics.step(dt, floorY: Double(floor.minY) + Double(props.placement(.yarn)?.bottom ?? 1) * scale,
                           minX: Double(floor.minX), maxX: Double(floor.maxX))
            b.window.setFrameOrigin(NSPoint(x: b.physics.x.rounded(), y: b.physics.y.rounded()))
            b.window.setQuarterTurns(b.physics.spinStep)
        }
        if b.finishing && b.physics.isResting {
            b.removeIn = (b.removeIn ?? 6) - dt
            if b.removeIn! <= 0 {
                b.window.close()
                ball = nil
                brain.yarnBall = nil
                return
            }
            b.window.alphaValue = CGFloat(min(1, b.removeIn!))
        }
        ball = b
        brain.yarnBall = YarnBallState(x: b.physics.x, width: b.physics.size, vx: b.physics.vx, onGround: b.physics.onGround)
    }

    private func updateBowlFade(_ dt: Double) {
        guard var b = bowl, let left = b.fadeIn else { return }
        b.fadeIn = left - dt
        b.window.alphaValue = CGFloat(min(1, max(0, b.fadeIn!)))
        if b.fadeIn! <= 0 {
            b.window.close()
            bowl = nil
        } else {
            bowl = b
        }
    }

    // MARK: - Cat switch and scale

    /// New cat or new size: swap prop art and restart any errand with the new cat's alignment.
    func refresh(props newProps: PropSet, scale newScale: Double, floor: NSRect) {
        props = newProps
        scale = newScale
        brain.interrupt()
        _ = brain.takeSignals()
        if let b = bowl, b.fadeIn == nil, let image = props.images[b.kind], let placement = props.placement(b.kind) {
            b.window.update(image: image, scale: scale)
            let origin = NSPoint(x: b.window.frame.minX, y: floor.minY + CGFloat(Double(placement.bottom) * scale))
            show(b.window, at: origin)
            brain.startBowl(BowlErrand(need: b.need, propX: Double(origin.x), propWidth: Double(image.width) * scale, placement: placement))
        } else if let b = bowl, let image = props.images[b.kind] {
            b.window.update(image: image, scale: scale)
        }
        if var b = ball, let image = props.images[.yarn] {
            b.window.update(image: image, scale: scale)
            b.physics.size = Double(image.width) * scale
            b.held = false
            if !b.window.isVisible { show(b.window, at: NSPoint(x: b.physics.x, y: b.physics.y)) }
            ball = b
            if !b.finishing, let start = props.placement(.yarn), let end = props.yarnEnd {
                brain.startYarn(YarnErrand(roundsLeft: brain.yarn?.roundsLeft ?? 3, placement: start, endPlacement: end))
            }
        }
    }

    func save() {
        settings.needs = needs
        saveIn = 30
    }
}
