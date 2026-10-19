// Draws the app icon (a white SF Symbol on a rounded gradient square) into an .iconset folder.
// Usage: swift tools/make-icon.swift <out.iconset> <symbol> <top r,g,b> <bottom r,g,b>
// Then: iconutil -c icns <out.iconset> -o AppIcon.icns
import AppKit

let args = CommandLine.arguments
let out = args[1], symbol = args[2]
func color(_ s: String) -> NSColor {
    let c = s.split(separator: ",").map { CGFloat(Double($0)!) }
    return NSColor(red: c[0], green: c[1], blue: c[2], alpha: 1)
}
let top = color(args[3]), bottom = color(args[4])
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

func draw(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)
    let rect = NSRect(x: s * 0.1, y: s * 0.1, width: s * 0.8, height: s * 0.8)
    let shape = NSBezierPath(roundedRect: rect, xRadius: s * 0.18, yRadius: s * 0.18)
    NSGradient(colors: [top, bottom])!.draw(in: shape, angle: -90)
    let cfg = NSImage.SymbolConfiguration(pointSize: s * 0.40, weight: .medium)
        .applying(.init(paletteColors: [NSColor.white]))
    if let img = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(cfg) {
        let sz = img.size
        img.draw(in: NSRect(x: (s - sz.width) / 2, y: (s - sz.height) / 2, width: sz.width, height: sz.height))
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    try! draw(base).write(to: URL(fileURLWithPath: "\(out)/icon_\(base)x\(base).png"))
    try! draw(base * 2).write(to: URL(fileURLWithPath: "\(out)/icon_\(base)x\(base)@2x.png"))
}
