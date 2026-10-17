import AppKit

/// The opt-in extras: jumping onto windows, climbing up a window's side, hanging off
/// an edge, peeking from behind a window, and chasing the cursor. Each one is a short
/// script of steps; while a script runs it drives the cat, then hands back to the Brain.
final class ExtrasController {
    unowned let pet: PetController

    enum Step {
        case walk(toX: Double, run: Bool)
        case face(right: Bool)
        case leap(toX: Double, toY: Double, onto: Surface)
        case climb(toY: Double)
        case place(x: Double, y: Double)
        case start(String)                 // begin an action, don't wait
        case play(String, seconds: Double) // begin an action and wait
        case wait(Double)
        case slide(toY: Double, seconds: Double)
        case hideBehind(windowID: Int)
        case comeForward
        case drop
        case chase
        case pounce
    }

    private var steps: [Step] = []
    private var current: Step?
    private var t = 0.0
    private var from = (x: 0.0, y: 0.0)
    private var leap: (vx: Double, vy0: Double, duration: Double, prep: Double)?
    private var pounceDir = 1.0
    /// The window the cat is hiding behind or climbing, if any (abort if it goes away).
    private var involvedWindow: Int?
    private var hidden = false

    // Cursor chase bookkeeping
    private var lastMouse = CGPoint.zero
    private var lastMouseMoved = 0.0
    private var clock = 0.0
    private var chaseCooldown = 0.0
    private var chaseStarted = 0.0

    static let gravity = 2600.0

    init(pet: PetController) { self.pet = pet }

    var isActive: Bool { current != nil }
    private var brain: Brain { pet.brain }
    private var engine: AnimationEngine { pet.engine }
    private var scale: Double { Double(pet.settings.scale) }
    private var catW: Double { brain.spriteWidth }
    private var catH: Double { Double(pet.window.frame.height) }
    private var frameH: Double { Double(engine.library.frameHeight) }
    private var motionAllowed: Bool { !pet.reduceMotion }

    // MARK: - Choosing an adventure (called from the Brain when it decides what to do)

    func tryStart() -> Bool {
        var plans: [() -> [Step]?] = []
        if pet.settings.jumpOnWindows && motionAllowed { plans += [planJump, planClimb] }
        if pet.settings.hangOffEdges && motionAllowed { plans.append(planHang) }
        if pet.settings.peekBehindWindows { plans.append(planPeek) }
        for plan in plans.shuffled() {
            if let s = plan() { run(s); return true }
        }
        return false
    }

    /// Testing aid: start one named extra right now ("jump", "climb", "hang", "peek").
    func start(plan name: String) -> Bool {
        let plans: [String: () -> [Step]?] = ["jump": planJump, "climb": planClimb, "hang": planHang, "peek": planPeek]
        guard !isActive, let plan = plans[name], let s = plan() else { return false }
        run(s)
        return true
    }

    /// Chasing starts on its own when the pointer is moving near the cat's level.
    func maybeChase(dt: Double) {
        clock += dt
        chaseCooldown -= dt
        let mouse = NSEvent.mouseLocation
        if hypot(mouse.x - lastMouse.x, mouse.y - lastMouse.y) > 2 { lastMouseMoved = clock }
        lastMouse = mouse
        guard pet.settings.chaseCursor, motionAllowed, !isActive, chaseCooldown <= 0,
              brain.bowl == nil, brain.yarn == nil,
              ["idle_sit", "walk", "run", "blink", "look_up", "look_down", "sit_back"].contains(engine.currentID),
              clock - lastMouseMoved < 0.3,
              pet.currentScreen().frame.contains(mouse), !pet.window.frame.contains(mouse),
              Double(mouse.y) < pet.y + catH * 3,
              abs(Double(mouse.x) - (brain.x + catW / 2)) > catW * 0.8 else { return }
        chaseStarted = clock
        run([.chase])
    }

    private func run(_ s: [Step]) {
        steps = s
        brain.pauseForExtras()
        next()
    }

    // MARK: - Plans

    private var surfaceY: Double { pet.surfaceY }
    private var screen: CGRect { pet.currentScreen().visibleFrame }
    private var maxJump: Double { catH * 1.6 }

    private func planJump() -> [Step]? {
        let here = pet.surface
        // Up onto a nearby higher ledge.
        let ups = pet.ledges.filter {
            .ledge(windowID: $0.windowID) != here && $0.y - surfaceY >= catH * 0.3 && $0.y - surfaceY <= maxJump
        }
        if let l = ups.randomElement() {
            let range = l.catRange(catWidth: catW)
            let landing = min(max(brain.x, range.lowerBound + catW * 0.2), range.upperBound - catW * 0.2)
            let dir: Double = landing >= brain.x ? 1 : -1
            let takeoff = clampToSurface(landing - dir * 50 * scale / 3)
            return [.walk(toX: takeoff, run: false), .leap(toX: landing, toY: l.y, onto: .ledge(windowID: l.windowID))]
        }
        // Down off the end of the ledge we're on.
        guard case let .ledge(id) = here, let l = pet.ledge(id) else { return nil }
        let right = Bool.random()
        let range = l.catRange(catWidth: catW)
        let edge = right ? range.upperBound : range.lowerBound
        let landingX = right ? l.maxX + 4 * scale : l.minX - catW - 4 * scale
        guard landingX >= Double(screen.minX), landingX + catW <= Double(screen.maxX) else { return nil }
        let below = pet.standableLedges.filter { $0.y < l.y - 1 && $0.supports(catX: landingX, catWidth: catW) }.max { $0.y < $1.y }
        return [.walk(toX: edge, run: false), .face(right: right),
                .leap(toX: landingX, toY: below?.y ?? Double(screen.minY), onto: below.map { .ledge(windowID: $0.windowID) } ?? .floor)]
    }

    private func planClimb() -> [Step]? {
        guard pet.surface == .floor else { return nil }
        let floorY = Double(screen.minY)
        let climbFrame = engine.library.action("climb")?.frames.first
        let b = climbFrame?.opaqueBounds ?? (minX: 10, minY: 10, maxX: 38, maxY: 47)
        for w in pet.windows.shuffled() {
            let f = w.frame
            guard Double(f.minY) <= floorY + catH * 0.4, Double(f.maxY) - floorY > maxJump,
                  Double(f.maxY) + catH <= Double(screen.maxY) else { continue }
            let tops = pet.ledges.filter { $0.windowID == w.id }
            // Climb the left side (facing right) or the right side (facing left), where the top is reachable.
            var sides: [Bool] = []
            if tops.contains(where: { $0.minX <= Double(f.minX) + 2 }) && Double(f.minX) - catW >= Double(screen.minX) { sides.append(true) }
            if tops.contains(where: { $0.maxX >= Double(f.maxX) - 2 }) && Double(f.maxX) + catW <= Double(screen.maxX) { sides.append(false) }
            guard let facingRight = sides.randomElement(),
                  let top = tops.first(where: { facingRight ? $0.minX <= Double(f.minX) + 2 : $0.maxX >= Double(f.maxX) - 2 }) else { continue }
            // Paws just touch the window's side (the sprite is mirrored when facing left).
            let w = Double(engine.library.frameWidth)
            let climbX = facingRight ? Double(f.minX) + scale - Double(b.maxX + 1) * scale
                                     : Double(f.maxX) - scale - (w - 1 - Double(b.maxX)) * scale
            // Climb until the top of the sprite reaches the window's top edge.
            let toY = Double(f.maxY) - (frameH - Double(b.minY)) * scale
            let range = top.catRange(catWidth: catW)
            let landing = facingRight ? range.lowerBound + catW * 0.2 : range.upperBound - catW * 0.2
            return [.walk(toX: clampToSurface(climbX), run: false), .face(right: facingRight),
                    .climb(toY: toY), .leap(toX: landing, toY: top.y, onto: .ledge(windowID: top.windowID))]
        }
        return nil
    }

    private func planHang() -> [Step]? {
        guard case let .ledge(id) = pet.surface, let l = pet.ledge(id),
              let hangFrame = engine.library.action("hang_edge")?.frames.first else { return nil }
        let right = Bool.random()
        let range = l.catRange(catWidth: catW)
        let pawTop = Double(hangFrame.opaqueBounds.minY)
        // Hang from the corner: centre just inside the end, paws gripping the top edge.
        let center = right ? l.maxX - 3 * scale : l.minX + 3 * scale
        let hangY = l.y + 2 * scale - (frameH - pawTop) * scale
        guard hangY > Double(screen.minY) else { return nil }
        var s: [Step] = [.walk(toX: right ? range.upperBound : range.lowerBound, run: false), .face(right: right),
                         .place(x: center - catW / 2, y: hangY), .play("hang_edge", seconds: Double.random(in: 3...6))]
        if Bool.random() {
            s.append(.leap(toX: right ? range.upperBound - catW * 0.3 : range.lowerBound + catW * 0.3, toY: l.y, onto: .ledge(windowID: id)))
        } else {
            s.append(.drop)
        }
        involvedWindow = id
        return s
    }

    private func planPeek() -> [Step]? {
        guard pet.surface == .floor else { return nil }
        let floorY = Double(screen.minY)
        for w in pet.windows.shuffled() {
            let f = w.frame
            guard Double(f.minY) <= floorY + catH * 0.5, Double(f.maxY) - floorY >= catH * 1.3,
                  Double(f.maxY) + catH <= Double(screen.maxY) else { continue }
            // A visible stretch of its top edge, wide enough, that the cat can get under.
            let tops = pet.ledges.filter { $0.windowID == w.id && $0.width >= catW * 1.4 }
            guard let top = tops.randomElement() else { continue }
            let lo = max(top.minX, Double(f.minX)) + catW * 0.2, hi = min(top.maxX, Double(f.maxX)) - catW * 1.2
            guard lo <= hi else { continue }
            let x = Double.random(in: lo...hi)
            let hiddenY = Double(f.maxY) - frameH * scale - 2 * scale
            let peekY = Double(f.maxY) - scale
            // Out the nearer side afterwards.
            let outLeft = x - Double(f.minX) < Double(f.maxX) - x
            let outX = outLeft ? Double(f.minX) - catW - 2 : Double(f.maxX) + 2
            guard outX >= Double(screen.minX), outX + catW <= Double(screen.maxX) else { continue }
            involvedWindow = w.id
            return [.walk(toX: x, run: false), .hideBehind(windowID: w.id), .place(x: x, y: hiddenY),
                    .start("peek"), .slide(toY: peekY, seconds: 0.4), .wait(Double.random(in: 3...5)),
                    .slide(toY: hiddenY, seconds: 0.4), .place(x: x, y: floorY),
                    .walk(toX: outX, run: false), .comeForward]
        }
        return nil
    }

    private func clampToSurface(_ x: Double) -> Double {
        min(max(x, brain.floorRange.lowerBound), brain.floorRange.upperBound)
    }

    // MARK: - Running steps

    func tick(_ dt: Double) {
        guard let step = current else { return }
        t += dt
        if update(step, dt) { next() }
        pet.placeWindowExactly()
    }

    private func next() {
        guard !steps.isEmpty else { finish(); return }
        let step = steps.removeFirst()
        current = step
        t = 0
        from = (brain.x, pet.y)
        begin(step)
    }

    private func begin(_ step: Step) {
        switch step {
        case let .walk(toX, run):
            if abs(toX - brain.x) > 1 {
                brain.facingRight = toX > brain.x
                engine.request(run ? "run" : "walk", force: true)
            }
        case let .face(right):
            brain.facingRight = right
        case let .leap(toX, toY, _):
            let apex = max(from.y, toY) + 25 * scale
            let g = Self.gravity
            let vy0 = (2 * g * (apex - from.y)).squareRoot()
            let duration = vy0 / g + (2 * (apex - toY) / g).squareRoot()
            let vx = (toX - from.x) / max(duration, 0.01)
            if abs(vx) > 1 { brain.facingRight = vx > 0 }
            leap = (vx, vy0, duration, 0.2)
            engine.request("jump", force: true) // First frame is the crouch.
            engine.freeze(for: 0.2)
            engine.sustainLastFrame = true
        case .climb:
            engine.request("climb", force: true)
        case let .place(x, y):
            brain.x = x
            pet.y = y
        case let .start(id):
            engine.request(id, force: true)
        case let .play(id, _):
            engine.request(id, force: true)
        case .wait, .slide:
            break
        case let .hideBehind(id):
            // Drop to normal window level and tuck in just below that window.
            pet.window.level = .normal
            pet.window.order(.below, relativeTo: id)
            hidden = true
        case .comeForward:
            restoreLevel()
        case .drop:
            pet.startFall(vy: 0)
        case .chase:
            engine.request("chase", force: true) // chase reuses run's frames
        case .pounce:
            engine.request("pounce", force: true) // First frame is the crouch.
            engine.freeze(for: Double.random(in: 0.3...0.6))
        }
    }

    /// Returns true when the step is done.
    private func update(_ step: Step, _ dt: Double) -> Bool {
        switch step {
        case let .walk(toX, run):
            let speed = (run ? brain.tuning.runSpeed : brain.tuning.walkSpeed) * scale
            return move(toward: toX, speed: speed, dt: dt)
        case .face, .place, .start, .hideBehind, .comeForward:
            return true
        case let .leap(toX, toY, onto):
            guard let l = leap else { return true }
            let tt = t - l.prep
            if tt <= 0 { return false }
            if tt < l.duration {
                brain.x = from.x + l.vx * tt
                pet.y = from.y + l.vy0 * tt - Self.gravity * tt * tt / 2
                return false
            }
            if engine.currentID == "jump" {
                brain.x = toX
                pet.y = toY
                engine.sustainLastFrame = false
                pet.landed(on: onto)
                engine.request("land", force: true)
            }
            return engine.currentID != "land"
        case let .climb(toY):
            pet.y = min(toY, pet.y + 30 * scale * dt)
            return pet.y >= toY
        case let .play(_, seconds):
            return t >= seconds
        case let .wait(seconds):
            return t >= seconds
        case let .slide(toY, seconds):
            let k = min(1, t / seconds)
            pet.y = from.y + (toY - from.y) * k
            return k >= 1
        case .drop:
            return true
        case .chase:
            return updateChase(dt)
        case .pounce:
            if t > 0.3 && engine.currentID == "pounce" {
                brain.x = clampToSurface(brain.x + pounceDir * 70 * scale * dt)
            }
            return engine.currentID != "pounce" && engine.currentID != "land"
        }
    }

    private func updateChase(_ dt: Double) -> Bool {
        let mouse = NSEvent.mouseLocation
        clock += dt
        if hypot(mouse.x - lastMouse.x, mouse.y - lastMouse.y) > 2 { lastMouseMoved = clock }
        lastMouse = mouse
        // Lose interest after a while, or when the pointer stops or leaves.
        if clock - lastMouseMoved > 2.5 || clock - chaseStarted > 15 || !pet.currentScreen().frame.contains(mouse) {
            chaseCooldown = 20
            engine.request("idle_sit", force: true)
            return true
        }
        let target = clampToSurface(Double(mouse.x) - catW / 2)
        if abs(target - brain.x) < catW * 0.35 {
            if Double(mouse.y) < pet.y + catH * 1.5 {
                // Close and low: crouch, wiggle, pounce. Then keep chasing.
                pounceDir = Double(mouse.x) >= brain.x + catW / 2 ? 1 : -1
                brain.facingRight = pounceDir > 0
                steps = [.pounce, .chase]
            } else {
                // Out of reach above: just look up at it.
                steps = [.play("look_up", seconds: 1.5)]
                chaseCooldown = 10
            }
            return true
        }
        if engine.currentID != "chase" { engine.request("chase", force: true) }
        _ = move(toward: target, speed: brain.tuning.runSpeed * scale, dt: dt)
        return false
    }

    private func move(toward x: Double, speed: Double, dt: Double) -> Bool {
        let dx = x - brain.x
        if abs(dx) <= speed * dt { brain.x = x; return true }
        brain.facingRight = dx > 0
        brain.x += dx > 0 ? speed * dt : -speed * dt
        return false
    }

    private func finish() {
        current = nil
        involvedWindow = nil
        leap = nil
        engine.sustainLastFrame = false
        restoreLevel()
        brain.resumeAfterExtras()
    }

    private func restoreLevel() {
        guard hidden else { return }
        hidden = false
        pet.window.level = .floating
        pet.window.orderFrontRegardless()
    }

    /// Something took over (you picked the cat up) or the window it relied on vanished.
    func abort(dropping: Bool) {
        guard isActive else { return }
        steps = []
        current = nil
        involvedWindow = nil
        leap = nil
        engine.sustainLastFrame = false
        restoreLevel()
        if dropping { pet.startFall(vy: 0) }
        brain.resumeAfterExtras()
    }

    /// After each window scan: bail out if the window we're using closed or moved away.
    func windowsChanged() {
        guard isActive, let id = involvedWindow else { return }
        if !pet.windows.contains(where: { $0.id == id }) { abort(dropping: true) }
    }
}
