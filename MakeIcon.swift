import Cocoa

// Superellipse ("squircle") matching the macOS icon silhouette.
func squircle(in rect: NSRect, n: CGFloat = 5.0) -> NSBezierPath {
    let path = NSBezierPath()
    let a = rect.width / 2, b = rect.height / 2
    let steps = 1024
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps) * 2 * .pi
        let ct = cos(t), st = sin(t)
        let x = rect.midX + a * (ct < 0 ? -1 : 1) * pow(abs(ct), 2 / n)
        let y = rect.midY + b * (st < 0 ? -1 : 1) * pow(abs(st), 2 / n)
        i == 0 ? path.move(to: NSPoint(x: x, y: y)) : path.line(to: NSPoint(x: x, y: y))
    }
    path.close()
    return path
}

func renderIcon(size: CGFloat) -> NSBitmapImageRep {
    let px = Int(size)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                               isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let s = size / 1024.0                     // everything below is authored at 1024
    let plate = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    let shape = squircle(in: plate)

    // Cool neutral gray plate, light source top-left, matching Caffeine's plate
    // so the two icons sit together comfortably in the Dock/Finder.
    NSGradient(colorsAndLocations:
        (NSColor(srgbRed: 0.969, green: 0.969, blue: 0.980, alpha: 1), 0.0),
        (NSColor(srgbRed: 0.922, green: 0.922, blue: 0.949, alpha: 1), 0.55),
        (NSColor(srgbRed: 0.839, green: 0.839, blue: 0.878, alpha: 1), 1.0)
    )!.draw(in: shape, angle: -90)

    // Soft top highlight for a little depth.
    shape.setClip()
    NSGradient(starting: NSColor(white: 1, alpha: 0.15), ending: NSColor(white: 1, alpha: 0))!
        .draw(in: NSRect(x: plate.minX, y: plate.midY, width: plate.width, height: plate.height / 2),
              angle: -90)

    // Mail-forward glyph, red ramp evoking Gmail's envelope color (not the
    // logo itself) so the icon reads as "forward this mail" at a glance.
    let cfg = NSImage.SymbolConfiguration(pointSize: 430 * s, weight: .regular)
    if let sym = NSImage(systemSymbolName: "envelope.arrow.triangle.branch", accessibilityDescription: nil)?
        .withSymbolConfiguration(cfg) {
        let red = NSGradient(colorsAndLocations:
            (NSColor(srgbRed: 0.918, green: 0.263, blue: 0.208, alpha: 1), 0.0),   // #EA4335
            (NSColor(srgbRed: 0.882, green: 0.212, blue: 0.169, alpha: 1), 0.40),  // #E1362B
            (NSColor(srgbRed: 0.831, green: 0.161, blue: 0.137, alpha: 1), 0.72),  // #D42923
            (NSColor(srgbRed: 0.773, green: 0.133, blue: 0.122, alpha: 1), 1.0)    // #C5221F
        )!

        // Draw the glyph for its alpha, then lay the gradient in with .sourceAtop
        // so the ramp lives inside the glyph instead of behind it.
        let tinted = NSImage(size: sym.size)
        tinted.lockFocus()
        sym.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.current?.compositingOperation = .sourceAtop
        red.draw(in: NSRect(origin: .zero, size: sym.size), angle: -90)
        tinted.unlockFocus()

        let box = NSRect(x: plate.midX - tinted.size.width / 2,
                         y: plate.midY - tinted.size.height / 2,
                         width: tinted.size.width, height: tinted.size.height)
        tinted.draw(in: box, from: .zero, operation: .sourceOver, fraction: 1)
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let outDir = CommandLine.arguments[1]
for size in [16, 32, 64, 128, 256, 512, 1024] {
    let rep = renderIcon(size: CGFloat(size))
    let png = rep.representation(using: .png, properties: [:])!
    try! png.write(to: URL(fileURLWithPath: "\(outDir)/\(size).png"))
}
print("rendered")
