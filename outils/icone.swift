// Shared icon generator — gwenn-ha-dev project charter §7.
//
// Copy this file to <Project>/outils/icone.swift, set FAMILY and NAME, then
// write the glyph in `drawGlyph`. Everything else — squircle, margin, gradient,
// sizes — is fixed by the charter and must not be edited per project.
//
//   swift outils/icone.swift "$PWD"
//   iconutil -c icns Resources/AppIcon.iconset -o Resources/AppIcon.icns
//
// `make icon` does both, and only when this file is newer than the .icns.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// ---------------------------------------------------------------- per project

let NAME = "Marnage"
let FAMILY = Family.tools

/// The glyph, white, inside `box` — the centred 56 % of the canvas.
/// This is the only part a project rewrites.
func drawGlyph(_ ctx: CGContext, _ box: CGRect) {
    // The falling tide, over its mark.
    let w = box.width
    ctx.setStrokeColor(white(1)); ctx.setLineWidth(w * 0.08)
    ctx.setLineCap(.round); ctx.setLineJoin(.round)
    var first = true
    for step in 0...56 {
        let t = Double(step) / 56
        let x = box.minX + w * t
        let y = box.minY + box.height * (0.74 - t * 0.30) + sin(t * .pi * 2.2) * box.height * 0.22
        if first { ctx.move(to: CGPoint(x: x, y: y)); first = false }
        else { ctx.addLine(to: CGPoint(x: x, y: y)) }
    }
    ctx.strokePath()
    ctx.setStrokeColor(white(0.5)); ctx.setLineWidth(w * 0.055)
    ctx.move(to: CGPoint(x: box.minX, y: box.minY + w * 0.06))
    ctx.addLine(to: CGPoint(x: box.maxX, y: box.minY + w * 0.06))
    ctx.strokePath()
}

// ---------------------------------------------------------------- the charter

enum Family {
    case audio, image, tools

    /// Linear gradient, top-left → bottom-right. Charter §7.
    var ramp: [[CGFloat]] {
        switch self {
        case .audio: return [[0.106, 0.227, 0.294, 1], [0.180, 0.545, 0.659, 1]]  // #1B3A4B → #2E8BA8
        case .image: return [[0.169, 0.129, 0.094, 1], [0.784, 0.529, 0.227, 1]]  // #2B2118 → #C8873A
        case .tools: return [[0.086, 0.200, 0.165, 1], [0.243, 0.557, 0.420, 1]]  // #16332A → #3E8E6B
        }
    }
}

let rgb = CGColorSpaceCreateDeviceRGB()
func white(_ a: CGFloat) -> CGColor { CGColor(colorSpace: rgb, components: [1, 1, 1, a])! }
func squircle(_ r: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func render(_ side: Int) -> CGImage {
    let t = CGFloat(side)
    let ctx = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8,
                        bytesPerRow: 0, space: rgb,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setAllowsAntialiasing(true)
    ctx.interpolationQuality = .high

    // Squircle background: 5.5 % margin, 22.5 % corner radius — macOS proportions.
    let margin = t * 0.055
    let plate = CGRect(x: margin, y: margin, width: t - 2 * margin, height: t - 2 * margin)
    ctx.saveGState()
    ctx.addPath(squircle(plate, t * 0.225))
    ctx.clip()
    let ramp = FAMILY.ramp
    let gradient = CGGradient(colorsSpace: rgb, colors: [
        CGColor(colorSpace: rgb, components: ramp[0])!,
        CGColor(colorSpace: rgb, components: ramp[1])!,
    ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: t), end: CGPoint(x: t, y: 0), options: [])
    ctx.restoreGState()

    // The glyph occupies the centred 56 % of the canvas. Charter §7.
    let g = t * 0.56
    drawGlyph(ctx, CGRect(x: (t - g) / 2, y: (t - g) / 2, width: g, height: g))

    return ctx.makeImage()!
}

// ---------------------------------------------------------------- iconset

let root = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath
let out = URL(fileURLWithPath: root).appendingPathComponent("Resources/AppIcon.iconset")
try? FileManager.default.removeItem(at: out)
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

for side in [16, 32, 128, 256, 512] {
    for (scale, suffix) in [(1, ""), (2, "@2x")] {
        let image = render(side * scale)
        let file = out.appendingPathComponent("icon_\(side)x\(side)\(suffix).png")
        let dest = CGImageDestinationCreateWithURL(file as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
    }
}
print("› \(NAME): Resources/AppIcon.iconset written (10 images)")
