import AppKit

/// The menubar icon: three slider rows, knobs on / off / on, matching the
/// app icon. Drawn in code, so no image file is needed.
///
/// `isTemplate = true` tells macOS to use only the image's alpha: it tints the
/// shape black or white to suit the menubar, and highlights it when clicked.
/// Draw in pure black; the color is ignored.
enum MenuBarGlyph {
    static let image: NSImage = {
        // 18 x 18 pt is the standard menubar icon size. The drawing handler
        // runs at the screen's scale, so it stays sharp on Retina.
        let img = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.set()
            for (y, on) in zip([14.5, 9.0, 3.5] as [CGFloat], [true, false, true]) {
                let track = NSBezierPath()
                track.move(to: NSPoint(x: 2, y: y))
                track.line(to: NSPoint(x: 16, y: y))
                track.lineWidth = 1.5
                track.lineCapStyle = .round
                track.stroke()
                let x: CGFloat = on ? 12.8 : 5.2
                NSBezierPath(ovalIn: NSRect(x: x - 2.6, y: y - 2.6, width: 5.2, height: 5.2)).fill()
            }
            return true
        }
        img.isTemplate = true
        img.accessibilityDescription = "Levers"
        return img
    }()
}
