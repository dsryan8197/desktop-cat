import CoreGraphics
import Foundation

/// Where a prop sits inside its source animation frame, in sprite pixels.
/// Made by tools/sprites/props.py, which cuts the props out of the finished frames.
struct PropPlacement: Decodable, Equatable {
    let left: Int
    let bottom: Int
    let width: Int
    let height: Int
    let frameWidth: Int

    /// Where the cat's left edge must be so this prop lines up with the one drawn in
    /// its animation, given the prop's left edge on screen.
    func catX(forPropX propX: Double, facingRight: Bool, scale: Double) -> Double {
        let offset = facingRight ? left : frameWidth - left - width
        return propX - Double(offset) * scale
    }

    /// The prop's left edge on screen when the cat's left edge is at `catX`.
    func propX(forCatX catX: Double, facingRight: Bool, scale: Double) -> Double {
        let offset = facingRight ? left : frameWidth - left - width
        return catX + Double(offset) * scale
    }
}

enum PropKind: String, CaseIterable {
    case foodBowl = "bowl_food"
    case waterBowl = "bowl_water"
    case yarn
}

/// One cat's props. Missing files simply leave a prop out (the menu then says so).
struct PropSet {
    var images: [PropKind: CGImage] = [:]
    var placements: [String: PropPlacement] = [:]

    func placement(_ kind: PropKind) -> PropPlacement? { placements[kind.rawValue] }
    /// Where the ball sits at the end of the bat animation (it's kicked from there).
    var yarnEnd: PropPlacement? { placements["yarn_end"] }
    func has(_ kind: PropKind) -> Bool { images[kind] != nil && placement(kind) != nil }

    static func load(catFolder: URL) -> PropSet {
        var set = PropSet()
        let dir = catFolder.appendingPathComponent("props")
        if let data = try? Data(contentsOf: dir.appendingPathComponent("props.json")),
           let decoded = try? JSONDecoder().decode([String: PropPlacement].self, from: data) {
            set.placements = decoded
        }
        for kind in PropKind.allCases {
            set.images[kind] = SpriteLibrary.loadImage(dir.appendingPathComponent(kind.rawValue + ".png"))
        }
        return set
    }
}

/// A bouncing, rolling yarn ball. Pure physics so it can be tested; units are screen points.
struct YarnPhysics {
    var x: Double           // left edge
    var y: Double           // bottom edge
    var vx: Double = 0
    var vy: Double = 0
    var size: Double
    var onGround = false
    /// How far it has rolled (drives the 90° spin frames).
    private(set) var rolled = 0.0

    var gravity = 2000.0
    var friction = 350.0
    var bounce = 0.45

    init(x: Double, y: Double, size: Double) {
        self.x = x; self.y = y; self.size = size
    }

    mutating func step(_ dt: Double, floorY: Double, minX: Double, maxX: Double) {
        if !onGround || y > floorY {
            vy -= gravity * dt
            y += vy * dt
            if y <= floorY {
                y = floorY
                if abs(vy) > 150 { vy = -vy * bounce } else { vy = 0; onGround = true }
            } else {
                onGround = false
            }
        }
        if onGround {
            let slow = friction * dt
            vx = abs(vx) <= slow ? 0 : vx - (vx > 0 ? slow : -slow)
        }
        x += vx * dt
        rolled += vx * dt
        let right = maxX - size
        if x < minX { x = minX; vx = -vx * 0.6 }
        if x > right { x = right; vx = -vx * 0.6 }
    }

    var isResting: Bool { onGround && vx == 0 }

    /// Quarter turns so far (0...3), for crisp 90° rotation of the pixel art.
    var spinStep: Int {
        let quarter = max(1, size * 0.4)
        return ((Int((rolled / quarter).rounded(.down)) % 4) + 4) % 4
    }
}
