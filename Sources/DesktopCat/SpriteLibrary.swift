import CoreGraphics
import Foundation
import ImageIO

/// One drawable frame: either real pixel art or a labelled placeholder.
struct SpriteFrame {
    let image: CGImage?
    /// Row-major alpha values (top row first), used for click hit-testing.
    let alpha: [UInt8]
    let width: Int
    let height: Int
    /// Non-nil when there is no art for this frame. Shown on screen as a label.
    let placeholderText: String?

    var isPlaceholder: Bool { image == nil }

    /// Smallest box around the visible pixels, in sprite pixels (origin top-left, facing right).
    var opaqueBounds: (minX: Int, minY: Int, maxX: Int, maxY: Int) {
        guard !isPlaceholder else { return (0, 0, width - 1, height - 1) }
        var b = (minX: width, minY: height, maxX: -1, maxY: -1)
        for y in 0..<height {
            for x in 0..<width where alpha[y * width + x] > 40 {
                b = (min(b.minX, x), min(b.minY, y), max(b.maxX, x), max(b.maxY, y))
            }
        }
        return b.maxX < 0 ? (0, 0, width - 1, height - 1) : b
    }

    /// x/y in sprite pixels, origin top-left, cat facing right.
    func isOpaque(x: Int, y: Int) -> Bool {
        guard x >= 0, y >= 0, x < width, y < height else { return false }
        if isPlaceholder { return true }
        return alpha[y * width + x] > 40
    }
}

/// An action with its frames resolved for one cat.
struct ResolvedAction {
    let definition: ActionDefinition
    let frames: [SpriteFrame]
    /// Set when this action reuses another action's finished frames.
    let borrowedFrom: String?

    var id: String { definition.id }
    var playback: Playback { definition.playback }
    var hasRealArt: Bool { frames.contains { !$0.isPlaceholder } }
    var secondsPerFrame: Double {
        hasRealArt ? FrameTiming.secondsPerFrame(id) : FrameTiming.placeholderSeconds
    }
}

/// Loads every frame for one cat from the bundle, resolves borrowed frames, and
/// builds placeholders for anything that has no art. Never invents art.
final class SpriteLibrary {
    /// Actions with no art of their own that reuse finished frames.
    /// (source action, play backwards?)
    static let borrowedFrames: [String: (source: String, reversed: Bool)] = [
        "chase": ("run", false),
        "wake_up": ("lie_down", true),
        "sit_blink": ("blink", false),
        "wave": ("play_paw", false),     // a raised, batting paw
        "carried": ("dangle", false),    // held by the scruff
        "bored": ("sit_back", false),    // turns its back on you
    ]

    let cat: CatDefinition
    let manifest: Manifest
    let frameWidth: Int
    let frameHeight: Int
    private(set) var problems: [String] = []
    private var cache: [String: ResolvedAction] = [:]
    private let assetRoot: URL

    /// `assetRoot` is the folder that contains the per-cat folders (fluffy_b, orange_c).
    init(cat: CatDefinition, manifest: Manifest, assetRoot: URL) {
        self.cat = cat
        self.manifest = manifest
        self.assetRoot = assetRoot

        // Frame size comes from the art itself (48 for fluffy_b, 40 for orange_c).
        let probe = manifest.actions.first { $0.assetStatus == .ready }
            .flatMap { $0.frames.first }
            .flatMap { Self.loadImage(assetRoot.appendingPathComponent(Self.folderName(cat)).appendingPathComponent($0)) }
        frameWidth = probe?.width ?? 48
        frameHeight = probe?.height ?? 48

        for action in manifest.actions { cache[action.id] = resolve(action) }
    }

    static func bundledAssetRoot(_ bundle: Bundle = .main) -> URL {
        bundle.resourceURL!.appendingPathComponent("assets")
    }

    /// "assets/fluffy_b" in the manifest → "fluffy_b".
    static func folderName(_ cat: CatDefinition) -> String {
        (cat.assetDirectory as NSString).lastPathComponent
    }

    func action(_ id: String) -> ResolvedAction? { cache[id] }

    // MARK: - Resolving

    private func resolve(_ action: ActionDefinition) -> ResolvedAction {
        if action.assetStatus == .toCreate,
           let borrow = Self.borrowedFrames[action.id],
           let source = manifest.action(borrow.source), source.assetStatus == .ready {
            var frames = source.frames.map { loadFrame($0, actionID: action.id) }
            if borrow.reversed { frames.reverse() }
            return ResolvedAction(definition: action, frames: frames, borrowedFrom: source.id)
        }

        guard action.assetStatus == .ready else {
            // No art yet: one placeholder frame per planned frame, clearly labelled.
            let frame = placeholder("No art yet:\n\(action.id)")
            return ResolvedAction(definition: action, frames: Array(repeating: frame, count: max(1, action.frames.count)), borrowedFrom: nil)
        }
        let frames = action.frames.map { loadFrame($0, actionID: action.id) }
        return ResolvedAction(definition: action, frames: frames.isEmpty ? [placeholder("No frames:\n\(action.id)")] : frames, borrowedFrom: nil)
    }

    private func loadFrame(_ file: String, actionID: String) -> SpriteFrame {
        let url = assetRoot.appendingPathComponent(Self.folderName(cat)).appendingPathComponent(file)
        guard let image = Self.loadImage(url) else {
            problems.append("\(cat.id): missing or unreadable \(file) (action \(actionID))")
            return placeholder("Missing file:\n\(file)")
        }
        if image.width != frameWidth || image.height != frameHeight {
            problems.append("\(cat.id): \(file) is \(image.width)x\(image.height), expected \(frameWidth)x\(frameHeight)")
        }
        let alpha = Self.alphaMask(image)
        if !alpha.contains(where: { $0 > 40 }) {
            problems.append("\(cat.id): \(file) is fully transparent")
        }
        return SpriteFrame(image: image, alpha: alpha, width: image.width, height: image.height, placeholderText: nil)
    }

    private func placeholder(_ text: String) -> SpriteFrame {
        SpriteFrame(image: nil, alpha: [], width: frameWidth, height: frameHeight, placeholderText: text)
    }

    static func loadImage(_ url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    static func alphaMask(_ image: CGImage) -> [UInt8] {
        let w = image.width, h = image.height
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        pixels.withUnsafeMutableBytes { buffer in
            guard let ctx = CGContext(data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8,
                                      bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        // CGContext memory is top row first, matching our hit-test coordinates.
        return stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] }
    }
}
