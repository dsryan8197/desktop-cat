import AppKit

/// The menu-bar icon: the app icon's cat face (same head, ears and whiskers) as a line drawing,
/// made a template image so macOS colours it for light and dark menu bars.
enum MenuBarIcon {
    /// The face is drawn in the app icon's 104-unit box (y down); this is the part we show.
    private static let crop = CGRect(x: 6, y: 14, width: 92, height: 76)

    static let image: NSImage = {
        let height: CGFloat = 16
        let unit = height / crop.height
        let img = NSImage(size: NSSize(width: crop.width * unit, height: height), flipped: true) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.scaleBy(x: unit, y: unit)
            ctx.translateBy(x: -crop.minX, y: -crop.minY)
            ctx.setFillColor(.black)
            ctx.setStrokeColor(.black)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            // Head and ears as one outline.
            ctx.addPath(head())
            ctx.setLineWidth(6)
            ctx.strokePath()
            // Eyes and nose.
            for x in [CGFloat(39), 65] { ctx.addEllipse(in: CGRect(x: x - 4.4, y: 54, width: 8.8, height: 10.5)) }
            ctx.move(to: CGPoint(x: 47.5, y: 65)); ctx.addLine(to: CGPoint(x: 56.5, y: 65))
            ctx.addQuadCurve(to: CGPoint(x: 52, y: 70.5), control: CGPoint(x: 56, y: 68.5))
            ctx.addQuadCurve(to: CGPoint(x: 47.5, y: 65), control: CGPoint(x: 48, y: 68.5))
            ctx.fillPath()
            // Two whiskers each side.
            for (dy, endDy) in [(CGFloat(-2), CGFloat(-7)), (3, 8)] {
                ctx.move(to: CGPoint(x: 30, y: 68 + dy)); ctx.addLine(to: CGPoint(x: 9, y: 68 + endDy))
                ctx.move(to: CGPoint(x: 74, y: 68 + dy)); ctx.addLine(to: CGPoint(x: 95, y: 68 + endDy))
            }
            ctx.setLineWidth(4)
            ctx.strokePath()
            return true
        }
        img.isTemplate = true
        img.accessibilityDescription = "Desktop Cat"
        return img
    }()

    /// Same shape as the app icon's face (tools/make-icon.swift, "desktop-cat").
    private static func head() -> CGPath {
        var head: CGPath = CGPath(ellipseIn: CGRect(x: 20, y: 34, width: 64, height: 52), transform: nil)
        for flip in [false, true] {
            let x: (CGFloat) -> CGFloat = { flip ? 104 - $0 : $0 }
            let ear = CGMutablePath()
            ear.move(to: CGPoint(x: x(23), y: 54))
            ear.addLine(to: CGPoint(x: x(26), y: 22))
            ear.addQuadCurve(to: CGPoint(x: x(33), y: 20), control: CGPoint(x: x(27), y: 15))
            ear.addLine(to: CGPoint(x: x(50), y: 38))
            ear.closeSubpath()
            head = head.union(ear)
        }
        return head
    }
}
