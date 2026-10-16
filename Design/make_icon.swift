// Generates Switkher's Icon Composer document (AppIcon.icon) and menu bar icon.
//
// Layers are flat artwork on a transparent 1024×1024 canvas; macOS 26 adds the
// Liquid Glass material, specular highlights, shadows and dark/tinted variants.
//
// Usage: swift make_icon.swift <AppIcon.icon output path> <menu bar imageset dir>
import AppKit
import CoreGraphics

let iconURL = URL(fileURLWithPath: CommandLine.arguments[1])
let menuBarDir = URL(fileURLWithPath: CommandLine.arguments[2])
let assetsURL = iconURL.appendingPathComponent("Assets")
try? FileManager.default.createDirectory(at: assetsURL, withIntermediateDirectories: true)
try? FileManager.default.createDirectory(at: menuBarDir, withIntermediateDirectories: true)

// MARK: - Drawing helpers

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
}

func roundedRect(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

/// Rounded triangle pointing right (or left) centred at `center`.
func triangle(center: CGPoint, size: CGFloat, pointingRight: Bool) -> CGPath {
    let w = size * 0.92
    let tip = CGPoint(x: center.x + (pointingRight ? w / 2 : -w / 2), y: center.y)
    let top = CGPoint(x: center.x + (pointingRight ? -w / 2 : w / 2), y: center.y - size / 2)
    let bottom = CGPoint(x: top.x, y: center.y + size / 2)
    let path = CGMutablePath()
    let r = size * 0.14
    path.move(to: CGPoint(x: top.x, y: center.y))
    path.addArc(tangent1End: top, tangent2End: tip, radius: r)
    path.addArc(tangent1End: tip, tangent2End: bottom, radius: r)
    path.addArc(tangent1End: bottom, tangent2End: top, radius: r)
    path.closeSubpath()
    return path
}

func makeContext(_ size: Int) -> CGContext {
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.translateBy(x: 0, y: CGFloat(size)) // top-left origin
    ctx.scaleBy(x: 1, y: -1)
    return ctx
}

func save(_ ctx: CGContext, to url: URL) {
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
}

func layer(_ name: String, draw: (CGContext) -> Void) {
    let ctx = makeContext(1024)
    draw(ctx)
    save(ctx, to: assetsURL.appendingPathComponent(name))
}

// MARK: - Geometry (1024 canvas; the system masks it to the icon shape)

let keyWidth: CGFloat = 212
let keyGap: CGFloat = 26
let keysX = 512 - (keyWidth * 3 + keyGap * 2) / 2
let keyTop: CGFloat = 196
let pressedKeyTop: CGFloat = 272
let keyBottom: CGFloat = 620
let keyRadius: CGFloat = 46
let titleBarHeight: CGFloat = 66

let lip = CGRect(x: 124, y: 584, width: 776, height: 276)
let lipRadius: CGFloat = 92

func keyRect(_ index: Int) -> CGRect {
    let top = index == 1 ? pressedKeyTop : keyTop
    return CGRect(x: keysX + CGFloat(index) * (keyWidth + keyGap), y: top, width: keyWidth, height: keyBottom - top)
}

// MARK: - Layers

/// Keys are rounded on top and square at the bottom, where they run into the deck.
func keyPath(_ rect: CGRect) -> CGPath {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
    path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.minY), radius: keyRadius)
    path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.maxY), radius: keyRadius)
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
    path.closeSubpath()
    return path
}

layer("keys.png") { ctx in
    for index in 0..<3 {
        ctx.addPath(keyPath(keyRect(index)))
        ctx.setFillColor(color(index == 1 ? 0xFFF1DC : 0xFFFFFF))
        ctx.fillPath()
    }
}

layer("glyphs.png") { ctx in
    let glyphs: [(count: Int, right: Bool)] = [(2, false), (1, true), (2, true)]
    for (index, glyph) in glyphs.enumerated() {
        let key = keyRect(index)
        let center = CGPoint(x: key.midX, y: key.minY + titleBarHeight + 92)
        let size: CGFloat = 68
        ctx.setFillColor(color(index == 1 ? 0xF2385A : 0x2B2230))
        if glyph.count == 1 {
            ctx.addPath(triangle(center: CGPoint(x: center.x + 5, y: center.y), size: size, pointingRight: true))
        } else {
            for g in 0..<2 {
                let dx = (CGFloat(g) - 0.5) * 46
                ctx.addPath(triangle(center: CGPoint(x: center.x + dx, y: center.y), size: size, pointingRight: glyph.right))
            }
        }
        ctx.fillPath()
    }
}

// Each key doubles as a window: a title bar with window controls. The pressed
// (selected) key gets live traffic-light colors, like the focused window.
layer("chrome.png") { ctx in
    for index in 0..<3 {
        let key = keyRect(index)
        ctx.saveGState()
        ctx.addPath(keyPath(key))
        ctx.clip()
        ctx.setFillColor(color(0x2B2230, 0.07))
        ctx.fill(CGRect(x: key.minX, y: key.minY, width: key.width, height: titleBarHeight))
        ctx.setFillColor(color(0x2B2230, 0.14))
        ctx.fill(CGRect(x: key.minX, y: key.minY + titleBarHeight - 3, width: key.width, height: 3))
        ctx.restoreGState()

        let dotColors: [CGColor] = index == 1
            ? [color(0xFF5F57), color(0xFEBC2E), color(0x28C840)]
            : Array(repeating: color(0x2B2230, 0.3), count: 3)
        for (dot, dotColor) in dotColors.enumerated() {
            ctx.setFillColor(dotColor)
            let center = CGPoint(x: key.minX + 38 + CGFloat(dot) * 28, y: key.minY + titleBarHeight / 2)
            ctx.fillEllipse(in: CGRect(x: center.x - 9.5, y: center.y - 9.5, width: 19, height: 19))
        }
    }
}

layer("lip.png") { ctx in
    ctx.addPath(roundedRect(lip, lipRadius))
    ctx.setFillColor(color(0x3A2849))
    ctx.fillPath()
}

layer("stripes.png") { ctx in
    let stripeColors: [UInt32] = [0xFFD25E, 0xFF8A3D, 0xFF4775]
    for (index, hex) in stripeColors.enumerated() {
        let stripe = CGRect(x: lip.minX + 92, y: lip.minY + 96 + CGFloat(index) * 38, width: lip.width - 184, height: 22)
        ctx.addPath(roundedRect(stripe, 11))
        ctx.setFillColor(color(hex))
        ctx.fillPath()
    }
}

// MARK: - Icon Composer document

let document = """
{
  "fill" : {
    "linear-gradient" : [
      "srgb:0.14902,0.14902,0.15686,1.00000",
      "srgb:0.14902,0.14902,0.15686,1.00000"
    ],
    "orientation" : {
      "start" : { "x" : 0.5, "y" : 0 },
      "stop" : { "x" : 0.5, "y" : 1 }
    }
  },
  "groups" : [
    {
      "name" : "Deck",
      "layers" : [
        { "name" : "Stripes", "image-name" : "stripes.png", "glass" : false },
        { "name" : "Lip", "image-name" : "lip.png", "glass" : true }
      ],
      "shadow" : { "kind" : "layer-color", "opacity" : 0.5 },
      "translucency" : { "enabled" : true, "value" : 0.1 },
      "specular" : true,
      "lighting" : "combined"
    },
    {
      "name" : "Keys",
      "layers" : [
        { "name" : "Glyphs", "image-name" : "glyphs.png", "glass" : false },
        { "name" : "Window Chrome", "image-name" : "chrome.png", "glass" : false },
        { "name" : "Keys", "image-name" : "keys.png", "glass" : true }
      ],
      "shadow" : { "kind" : "neutral", "opacity" : 0.5 },
      "translucency" : { "enabled" : true, "value" : 0.25 },
      "specular" : true,
      "lighting" : "individual"
    }
  ],
  "supported-platforms" : {
    "squares" : "shared"
  }
}
"""
try! document.write(to: iconURL.appendingPathComponent("icon.json"), atomically: true, encoding: .utf8)

// MARK: - Menu bar template icon (stacked windows + cassette fast-forward)

func drawMenuBarIcon(pixels: Int, name: String) {
    let ctx = makeContext(pixels)
    let s = CGFloat(pixels) / 18
    ctx.scaleBy(x: s, y: s)
    ctx.setFillColor(color(0x000000))
    ctx.setStrokeColor(color(0x000000))

    // Back window, peeking out at the top right.
    let back = CGRect(x: 5.6, y: 1.6, width: 11, height: 9)
    ctx.setLineWidth(1.3)
    ctx.addPath(roundedRect(back, 2))
    ctx.strokePath()

    // Front window: cut a gap around it so it reads as on top, then fill it.
    let front = CGRect(x: 1.2, y: 5.4, width: 12.6, height: 11)
    ctx.setBlendMode(.clear)
    ctx.addPath(roundedRect(front.insetBy(dx: -1.1, dy: -1.1), 3))
    ctx.fillPath()
    ctx.setBlendMode(.normal)
    ctx.addPath(roundedRect(front, 2.2))
    ctx.fillPath()

    // Knock out the title bar line and a fast-forward glyph.
    ctx.setBlendMode(.clear)
    ctx.fill(CGRect(x: front.minX, y: front.minY + 2.6, width: front.width, height: 0.9))
    for dx in [-1.55, 1.55] {
        ctx.addPath(triangle(center: CGPoint(x: front.midX + dx, y: front.minY + 7.05), size: 4.4, pointingRight: true))
    }
    ctx.fillPath()
    ctx.setBlendMode(.normal)

    save(ctx, to: menuBarDir.appendingPathComponent(name))
}

drawMenuBarIcon(pixels: 18, name: "MenuBarIcon.png")
drawMenuBarIcon(pixels: 36, name: "MenuBarIcon@2x.png")
drawMenuBarIcon(pixels: 54, name: "MenuBarIcon@3x.png")
