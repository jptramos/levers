// Draws the Levers app icon in code and writes Resources/AppIcon.icns.
//
// Run: swift scripts/make-icon.swift   (bundle.sh runs it if the .icns is missing)
//
// Without Xcode there's no asset catalog (actool ships only with Xcode), so
// the icon is a classic .icns: one PNG per size in an .iconset folder, then
// `iconutil -c icns` packs them. iconutil is part of macOS itself.
//
// Design: black tile, three white slider rows, knobs on/off/on,
// mirroring the panel (on = right). Black, not white: with the icon style
// set to Dark, macOS darkens a classic .icns itself (it has no dark variant),
// and a white tile with black marks went near-invisible. A dark tile survives.
import AppKit

// Canvas 1024 x 1024, origin bottom-left. Apple's macOS icon grid: an 824 x 824
// rounded square centered, corner radius ~185, leaving room for the shadow.
// Filling that shape exactly keeps macOS 26+ from putting the icon in a gray tile.
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let tileRadius: CGFloat = 185

func gray(_ v: CGFloat, _ a: CGFloat = 1) -> CGColor { CGColor(gray: v, alpha: a) }
func rounded(_ r: CGRect, _ rad: CGFloat) -> CGPath {
    CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil)
}

func drawIcon(_ c: CGContext) {
    // Tile: soft drop shadow, then a charcoal → black gradient.
    c.saveGState()
    c.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: gray(0, 0.35))
    c.addPath(rounded(tile, tileRadius)); c.setFillColor(gray(0.05)); c.fillPath()
    c.restoreGState()
    c.saveGState()
    c.addPath(rounded(tile, tileRadius)); c.clip()
    let g = CGGradient(colorsSpace: nil, colors: [gray(0.2), gray(0.02)] as CFArray, locations: [0, 1])!
    c.drawLinearGradient(g, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    c.restoreGState()

    // Three rows: track, then a knob at the right (on) or left (off) end.
    for (y, on) in zip([700, 512, 324] as [CGFloat], [true, false, true]) {
        c.addPath(rounded(CGRect(x: 250, y: y - 14, width: 524, height: 28), 14))
        c.setFillColor(gray(0.92)); c.fillPath()
        let p = CGPoint(x: on ? 674 : 350, y: y), r: CGFloat = 66
        c.saveGState()
        c.setShadow(offset: CGSize(width: 0, height: -8), blur: 16, color: gray(0, 0.4))
        c.setFillColor(gray(1)); c.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r))
        c.restoreGState()
        // Soft shade on the lower half so the knob reads as a ball, not a dot.
        c.setFillColor(gray(0, 0.12))
        c.fillEllipse(in: CGRect(x: p.x - r * 0.55, y: p.y + r * 0.05, width: r * 0.7, height: r * 0.5).offsetBy(dx: 0, dy: -r * 0.75))
    }
}

func png(_ px: Int) -> Data {
    let c = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.scaleBy(x: CGFloat(px) / 1024, y: CGFloat(px) / 1024)
    drawIcon(c)
    return NSBitmapImageRep(cgImage: c.makeImage()!).representation(using: .png, properties: [:])!
}

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
// The ten files iconutil expects: 16–512 pt at 1x and 2x.
for pt in [16, 32, 128, 256, 512] {
    try! png(pt).write(to: iconset.appendingPathComponent("icon_\(pt)x\(pt).png"))
    try! png(pt * 2).write(to: iconset.appendingPathComponent("icon_\(pt)x\(pt)@2x.png"))
}
let out = root.appendingPathComponent("Resources/AppIcon.icns")
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", out.path]
try! p.run(); p.waitUntilExit()
precondition(p.terminationStatus == 0, "iconutil failed")
try? FileManager.default.removeItem(at: iconset)  // the PNGs are inside the .icns now
print("Wrote \(out.path)")
