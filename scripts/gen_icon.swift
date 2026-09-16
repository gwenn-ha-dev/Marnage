// Génère l'icône macOS de Marnage : squircle océan, courbe de marée,
// marqueur « maintenant » et lune. Redessin vectoriel à chaque taille.
//
//   swift scripts/gen_icon.swift App/Marnage/Marnage/Assets.xcassets/AppIcon.appiconset
//
// Aucune dépendance hors frameworks système.

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

func render(size: Int) -> CGImage {
    let s = CGFloat(size) / 1024.0
    let ctx = CGContext(data: nil, width: size, height: size,
                        bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

    func rgba(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
        CGColor(srgbRed: r, green: g, blue: b, alpha: a)
    }
    func gradient(_ colors: [CGColor]) -> CGGradient {
        CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                   colors: colors as CFArray, locations: nil)!
    }

    // Squircle : 824×824 centré sur un canevas 1024 (marge standard macOS).
    let inset = 100 * s
    let rect = CGRect(x: inset, y: inset,
                      width: CGFloat(size) - 2 * inset, height: CGFloat(size) - 2 * inset)
    let radius = 185 * s
    let squircle = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    ctx.addPath(squircle)
    ctx.clip()

    // Ciel nocturne dégradé
    ctx.drawLinearGradient(
        gradient([rgba(0.10, 0.30, 0.50), rgba(0.03, 0.11, 0.22)]),
        start: CGPoint(x: rect.midX, y: rect.maxY),
        end: CGPoint(x: rect.midX, y: rect.minY), options: [])

    // Lune et halo
    let moon = CGPoint(x: rect.minX + 0.70 * rect.width, y: rect.minY + 0.76 * rect.height)
    let moonR = 78 * s
    ctx.setFillColor(rgba(1, 0.97, 0.90, 0.12))
    ctx.fillEllipse(in: CGRect(x: moon.x - 2.1 * moonR, y: moon.y - 2.1 * moonR,
                               width: 4.2 * moonR, height: 4.2 * moonR))
    ctx.setFillColor(rgba(0.99, 0.96, 0.88))
    ctx.fillEllipse(in: CGRect(x: moon.x - moonR, y: moon.y - moonR,
                               width: 2 * moonR, height: 2 * moonR))

    // Courbe de marée : creux → crête, allure semi-diurne.
    func tide(_ f: CGFloat) -> CGPoint {
        let y = 0.40 + 0.14 * sin((f * 1.25 - 0.30) * 2 * .pi)
        return CGPoint(x: rect.minX + f * rect.width, y: rect.minY + y * rect.height)
    }
    let curve = CGMutablePath()
    let n = 96
    for i in 0...n {
        let pt = tide(CGFloat(i) / CGFloat(n))
        i == 0 ? curve.move(to: pt) : curve.addLine(to: pt)
    }

    // Eau sous la courbe
    let water = curve.mutableCopy()!
    water.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
    water.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
    water.closeSubpath()
    ctx.saveGState()
    ctx.addPath(water)
    ctx.clip()
    ctx.drawLinearGradient(
        gradient([rgba(0.16, 0.55, 0.75), rgba(0.02, 0.16, 0.30)]),
        start: CGPoint(x: rect.midX, y: rect.minY + 0.56 * rect.height),
        end: CGPoint(x: rect.midX, y: rect.minY), options: [])
    ctx.restoreGState()

    // Trait de la courbe
    ctx.addPath(curve)
    ctx.setStrokeColor(rgba(0.45, 0.85, 1.0))
    ctx.setLineWidth(24 * s)
    ctx.setLineCap(.round)
    ctx.strokePath()

    // Marqueur « maintenant » sur le flanc montant (rappel de l'UI)
    let mark = tide(0.62)
    let markR = 30 * s
    ctx.setFillColor(rgba(1.0, 0.62, 0.35))
    ctx.fillEllipse(in: CGRect(x: mark.x - markR, y: mark.y - markR,
                               width: 2 * markR, height: 2 * markR))
    ctx.setStrokeColor(rgba(1, 1, 1, 0.95))
    ctx.setLineWidth(9 * s)
    ctx.strokeEllipse(in: CGRect(x: mark.x - markR, y: mark.y - markR,
                                 width: 2 * markR, height: 2 * markR))

    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

guard CommandLine.arguments.count == 2 else {
    print("usage: swift scripts/gen_icon.swift <AppIcon.appiconset>")
    exit(1)
}
let outDir = URL(fileURLWithPath: CommandLine.arguments[1])

var images: [[String: String]] = []
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = size * scale
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        writePNG(render(size: px), to: outDir.appendingPathComponent(name))
        images.append(["idiom": "mac", "scale": "\(scale)x",
                       "size": "\(size)x\(size)", "filename": name])
    }
}

let manifest: [String: Any] = [
    "images": images,
    "info": ["author": "xcode", "version": 1],
]
let data = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
try data.write(to: outDir.appendingPathComponent("Contents.json"))
print("icône générée : \(images.count) fichiers dans \(outDir.path)")
