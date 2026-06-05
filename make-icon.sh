#!/bin/bash
set -e

# Renders the app icon using a Swift one-liner that draws an SF Symbol onto a background
ICONSET=AppIcon.iconset
mkdir -p $ICONSET

swift - <<'EOF'
import Cocoa

func makeIcon(size: Int) {
    let s = CGFloat(size)
    let img = NSImage(size: NSSize(width: s, height: s))
    img.lockFocus()

    // Background gradient
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.15, green: 0.15, blue: 0.20, alpha: 1),
        NSColor(calibratedRed: 0.08, green: 0.08, blue: 0.14, alpha: 1)
    ])!
    let path = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: s, height: s),
                            xRadius: s * 0.22, yRadius: s * 0.22)
    gradient.draw(in: path, angle: -45)

    // SF Symbol
    let cfg = NSImage.SymbolConfiguration(pointSize: s * 0.52, weight: .medium)
    if let sym = NSImage(systemSymbolName: "cursorarrow.click.2", accessibilityDescription: nil)?
        .withSymbolConfiguration(cfg) {
        sym.isTemplate = true
        let tinted = NSImage(size: sym.size)
        tinted.lockFocus()
        NSColor.white.set()
        sym.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)
        tinted.unlockFocus()
        let x = (s - sym.size.width) / 2
        let y = (s - sym.size.height) / 2
        tinted.draw(at: NSPoint(x: x, y: y), from: .zero, operation: .sourceOver, fraction: 1)
    }

    img.unlockFocus()

    if let tiff = img.tiffRepresentation,
       let rep = NSBitmapImageRep(data: tiff),
       let png = rep.representation(using: .png, properties: [:]) {
        try? png.write(to: URL(fileURLWithPath: "AppIcon.iconset/icon_\(size)x\(size).png"))
        // @2x is the same file at half the logical size
    }
}

let sizes = [16, 32, 64, 128, 256, 512, 1024]
sizes.forEach { makeIcon(size: $0) }
print("Icons rendered.")
EOF

# Build .icns
iconutil -c icns $ICONSET -o AppIcon.icns
rm -rf $ICONSET

mkdir -p DoubleClickFix/Resources
cp AppIcon.icns DoubleClickFix/Resources/AppIcon.icns
echo "AppIcon.icns created."
