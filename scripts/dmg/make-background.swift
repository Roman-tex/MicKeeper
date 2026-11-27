import AppKit

// Renders the disk image window background at 1x and 2x.
// Usage: swift scripts/dmg/make-background.swift <output-dir>
// The layout matches scripts/dmg/settings.py: a 640x400 window with the app
// at x=160 and Applications at x=480, both centred at y=190 (from the top).

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let size = NSSize(width: 640, height: 400)
let accent = NSColor(srgbRed: 0.09, green: 0.40, blue: 0.90, alpha: 1)

func render(scale: CGFloat) -> Data {
    let pixels = NSSize(width: size.width * scale, height: size.height * scale)
    let context = CGContext(data: nil, width: Int(pixels.width), height: Int(pixels.height), bitsPerComponent: 8,
                            bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.scaleBy(x: scale, y: scale)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)

    // A near-white wash keeps Finder's icon labels legible.
    NSGradient(starting: NSColor(srgbRed: 0.97, green: 0.98, blue: 1.0, alpha: 1),
               ending: NSColor(srgbRed: 0.90, green: 0.94, blue: 0.99, alpha: 1))!
        .draw(in: NSRect(origin: .zero, size: size), angle: -90)

    // Arrow from the app towards Applications (y is measured from the bottom here).
    let y = size.height - 190
    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: 262, y: y))
    arrow.line(to: NSPoint(x: 370, y: y))
    arrow.move(to: NSPoint(x: 354, y: y + 14))
    arrow.line(to: NSPoint(x: 372, y: y))
    arrow.line(to: NSPoint(x: 354, y: y - 14))
    arrow.lineWidth = 5
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    accent.withAlphaComponent(0.85).setStroke()
    arrow.stroke()

    let style = NSMutableParagraphStyle()
    style.alignment = .center
    NSAttributedString(string: "Drag MicKeeper to Applications", attributes: [
        .font: NSFont.systemFont(ofSize: 14, weight: .medium),
        .foregroundColor: NSColor(srgbRed: 0.35, green: 0.40, blue: 0.48, alpha: 1),
        .paragraphStyle: style,
    ]).draw(in: NSRect(x: 0, y: 60, width: size.width, height: 22))
    // The build is not notarized: tell people where macOS hides the way to open it.
    NSAttributedString(string: "First launch blocked? System Settings → Privacy & Security → Open Anyway", attributes: [
        .font: NSFont.systemFont(ofSize: 11, weight: .regular),
        .foregroundColor: NSColor(srgbRed: 0.45, green: 0.50, blue: 0.58, alpha: 1),
        .paragraphStyle: style,
    ]).draw(in: NSRect(x: 0, y: 36, width: size.width, height: 18))

    NSGraphicsContext.restoreGraphicsState()
    return NSBitmapImageRep(cgImage: context.makeImage()!).representation(using: .png, properties: [:])!
}

try! render(scale: 1).write(to: output.appendingPathComponent("background.png"))
try! render(scale: 2).write(to: output.appendingPathComponent("background@2x.png"))
