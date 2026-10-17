import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import DesktopCat

/// Checks the real art against specs/cats-and-actions.json and specs/SPRITE_PRODUCTION.md.
@Suite struct AssetValidationTests {
    let cats = manifest.cats
    let ready = manifest.actions.filter { $0.assetStatus == .ready }
    /// Poses drawn centred on the body rather than standing on the ground line.
    let airborne: Set<String> = ["fall", "climb"]

    func frame(_ cat: CatDefinition, _ file: String) -> SpriteFrame? {
        let url = assetRoot.appendingPathComponent(SpriteLibrary.folderName(cat)).appendingPathComponent(file)
        guard let image = SpriteLibrary.loadImage(url) else { return nil }
        return SpriteFrame(image: image, alpha: SpriteLibrary.alphaMask(image), width: image.width,
                           height: image.height, placeholderText: nil)
    }

    @Test func actionIDsAreUniqueAndFramesFollowTheNamingRule() {
        #expect(Set(manifest.actions.map(\.id)).count == manifest.actions.count)
        for a in manifest.actions {
            #expect(!a.frames.isEmpty, "\(a.id) lists no frames")
            for (i, f) in a.frames.enumerated() {
                #expect(f == String(format: "%@_%02d.png", a.id, i + 1), "\(a.id) frame \(i + 1) is named \(f)")
            }
        }
    }

    @Test func everyReadyFrameExistsForBothCatsAtTheRightSize() {
        for cat in cats {
            let expected = cat.id == "fluffy_b" ? 48 : 40
            for a in ready {
                for f in a.frames {
                    let fr = frame(cat, f)
                    #expect(fr != nil, "\(cat.id)/\(f) missing")
                    #expect(fr?.width == expected && fr?.height == expected, "\(cat.id)/\(f) wrong size")
                }
            }
        }
    }

    @Test func noFrameIsEmptyOrDuplicatedWithinAnAction() {
        for cat in cats {
            for a in ready {
                let alphas = a.frames.compactMap { frame(cat, $0)?.alpha }
                for (i, alpha) in alphas.enumerated() {
                    #expect(alpha.contains { $0 > 40 }, "\(cat.id)/\(a.frames[i]) is empty")
                }
                // Real movement, not the same drawing repeated (spec: "check frames depict actual movement").
                #expect(Set(a.frames.compactMap { f -> Data? in
                    guard let img = frame(cat, f)?.image, let data = img.dataProvider?.data else { return nil }
                    return data as Data
                }).count == a.frames.count, "\(cat.id)/\(a.id) repeats a frame")
            }
        }
    }

    @Test func groundedPosesShareOneFootBaseline() {
        for cat in cats {
            let expected = cat.id == "fluffy_b" ? 46 : 38 // one row above the bottom, for every cat pose
            for a in ready where !airborne.contains(a.id) {
                for f in a.frames {
                    guard let fr = frame(cat, f) else { continue }
                    #expect(fr.opaqueBounds.maxY == expected, "\(cat.id)/\(f) feet on row \(fr.opaqueBounds.maxY)")
                }
            }
        }
    }

    @Test func airbornePosesFitInsideTheirFrame() {
        for cat in cats {
            for id in airborne {
                for f in manifest.action(id)!.frames {
                    let b = frame(cat, f)!.opaqueBounds
                    #expect(b.minX > 0 && b.minY > 0 && b.maxX < frame(cat, f)!.width - 1, "\(cat.id)/\(f) touches the edge")
                }
            }
        }
    }

    @Test func pixelsAreFullyOpaqueOrFullyTransparent() {
        // Crisp pixel art: no soft edges, halos or leftover backdrop.
        for cat in cats {
            for a in ready {
                for f in a.frames {
                    let alpha = frame(cat, f)!.alpha
                    #expect(alpha.allSatisfy { $0 == 0 || $0 == 255 }, "\(cat.id)/\(f) has semi-transparent pixels")
                }
            }
        }
    }

    @Test func outlineColourIsTheDarkestColourInEveryFrame() {
        for cat in cats {
            for a in ready {
                guard let img = frame(cat, a.frames[0])?.image else { continue }
                var px = [UInt8](repeating: 0, count: img.width * img.height * 4)
                px.withUnsafeMutableBytes { buf in
                    let ctx = CGContext(data: buf.baseAddress, width: img.width, height: img.height, bitsPerComponent: 8,
                                        bytesPerRow: img.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                    ctx.draw(img, in: CGRect(x: 0, y: 0, width: img.width, height: img.height))
                }
                let darkest = stride(from: 0, to: px.count, by: 4).filter { px[$0 + 3] == 255 }
                    .map { Int(px[$0]) + Int(px[$0 + 1]) + Int(px[$0 + 2]) }.min()
                #expect(darkest == 28 + 20 + 24, "\(cat.id)/\(a.id) outline isn't the shared dark outline")
            }
        }
    }

    @Test func borrowedFramesComeFromFinishedArt() {
        for (id, borrow) in SpriteLibrary.borrowedFrames {
            #expect(manifest.action(id) != nil, "\(id) isn't in the manifest")
            #expect(manifest.action(borrow.source)?.assetStatus == .ready, "\(id) borrows unfinished \(borrow.source)")
            #expect(manifest.action(id)?.assetStatus == .toCreate, "\(id) has its own art now; drop the borrow")
        }
    }

    @Test func everyActionHasAPositivePlaybackSpeed() {
        for a in manifest.actions { #expect(FrameTiming.secondsPerFrame(a.id) > 0) }
    }

    @Test func propsSitInsideTheirSourceFrames() {
        for i in 0..<2 {
            for (name, p) in props(i).placements {
                #expect(p.left >= 0 && p.left + p.width <= p.frameWidth, "\(name) runs off its frame")
                #expect(p.bottom >= 0)
            }
        }
    }

    @Test func manifestCatsPointAtRealFolders() {
        for cat in cats {
            var isDir: ObjCBool = false
            let path = assetRoot.appendingPathComponent(SpriteLibrary.folderName(cat)).path
            #expect(FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue)
        }
    }
}
