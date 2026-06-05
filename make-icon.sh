#!/bin/bash
set -e

ICONSET=AppIcon.iconset
mkdir -p $ICONSET

swift - <<'EOF'
import Cocoa
import CoreGraphics

// Apple-style continuous squircle (superellipse, n≈5) centered in the canvas.
func squirclePath(rect: CGRect, n: CGFloat = 5.0, steps: Int = 720) -> CGPath {
    let a = rect.width / 2, b = rect.height / 2
    let cx = rect.midX, cy = rect.midY
    let path = CGMutablePath()
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps) * 2 * .pi
        let ct = cos(t), st = sin(t)
        let x = cx + copysign(a * pow(abs(ct), 2 / n), ct)
        let y = cy + copysign(b * pow(abs(st), 2 / n), st)
        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
        else      { path.addLine(to: CGPoint(x: x, y: y)) }
    }
    path.closeSubpath()
    return path
}

func makeIcon(size: Int) {
    let s = CGFloat(size)
    guard let ctx = CGContext(
        data: nil, width: size, height: size,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return }

    let rgb = CGColorSpaceCreateDeviceRGB()
    let locs: [CGFloat] = [0, 1]

    // macOS icon grid: body ~82% of canvas, leaving margin for shadow.
    let body = s * 0.82
    let rect = CGRect(x: (s - body) / 2, y: (s - body) / 2, width: body, height: body)
    let squircle = squirclePath(rect: rect)

    // ── Soft drop shadow beneath the tile ───────────────────────────────────
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.018), blur: s * 0.06,
                  color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.35))
    ctx.addPath(squircle)
    ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
    ctx.fillPath()
    ctx.restoreGState()

    // ── Background gradient (vibrant blue → indigo) ─────────────────────────
    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.clip()
    let bg = [
        CGColor(red: 0.27, green: 0.56, blue: 1.00, alpha: 1),
        CGColor(red: 0.10, green: 0.28, blue: 0.92, alpha: 1)
    ] as CFArray
    if let g = CGGradient(colorsSpace: rgb, colors: bg, locations: locs) {
        ctx.drawLinearGradient(g,
            start: CGPoint(x: rect.midX, y: rect.maxY),
            end:   CGPoint(x: rect.midX, y: rect.minY), options: [])
    }

    // Top sheen — subtle radial highlight for that glassy Tahoe depth
    let sheen = [
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.22),
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.0)
    ] as CFArray
    if let g = CGGradient(colorsSpace: rgb, colors: sheen, locations: locs) {
        ctx.drawRadialGradient(g,
            startCenter: CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.12), startRadius: 0,
            endCenter:   CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.12), endRadius: rect.width * 0.85,
            options: [])
    }
    ctx.restoreGState()

    // ── Thin top highlight stroke on the rim ────────────────────────────────
    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.20))
    ctx.setLineWidth(s * 0.006)
    ctx.strokePath()
    ctx.restoreGState()

    // ── SF Symbol glyph, white, centered ────────────────────────────────────
    let cfg = NSImage.SymbolConfiguration(pointSize: s * 0.42, weight: .semibold)
    if let sym = NSImage(systemSymbolName: "cursorarrow.click.2", accessibilityDescription: nil)?
        .withSymbolConfiguration(cfg),
       let tiff = sym.tiffRepresentation,
       let rep  = NSBitmapImageRep(data: tiff),
       let cg   = rep.cgImage {

        let gw = sym.size.width  / sym.size.height * (s * 0.42)
        let gh = s * 0.42
        let gx = (s - gw) / 2
        let gy = (s - gh) / 2

        // Soft shadow under glyph
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.008), blur: s * 0.025,
                      color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.30))
        // Tint template glyph white by clipping to its mask
        ctx.clip(to: CGRect(x: gx, y: gy, width: gw, height: gh), mask: cg)
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: gx, y: gy, width: gw, height: gh))
        ctx.restoreGState()
    }

    guard let img = ctx.makeImage() else { return }
    let out = NSBitmapImageRep(cgImage: img)
    guard let png = out.representation(using: .png, properties: [:]) else { return }
    try? png.write(to: URL(fileURLWithPath: "AppIcon.iconset/icon_\(size)x\(size).png"))
}

[16, 32, 64, 128, 256, 512, 1024].forEach { makeIcon(size: $0) }
print("Icons rendered.")
EOF

cp $ICONSET/icon_32x32.png     $ICONSET/icon_16x16@2x.png
cp $ICONSET/icon_64x64.png     $ICONSET/icon_32x32@2x.png
cp $ICONSET/icon_256x256.png   $ICONSET/icon_128x128@2x.png
cp $ICONSET/icon_512x512.png   $ICONSET/icon_256x256@2x.png
cp $ICONSET/icon_1024x1024.png $ICONSET/icon_512x512@2x.png

iconutil -c icns $ICONSET -o AppIcon.icns
rm -rf $ICONSET

mkdir -p ClickGuard/Resources
cp AppIcon.icns ClickGuard/Resources/AppIcon.icns
rm AppIcon.icns
echo "Icon created."
