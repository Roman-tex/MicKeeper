import AppKit
import Foundation
// Vector app icon using the supplied microphone silhouette; no raster source is edited.
let output = CommandLine.arguments[1]
let sizes = [(16,1),(16,2),(32,1),(32,2),(128,1),(128,2),(256,1),(256,2),(512,1),(512,2)]
var entries: [[String:String]] = []
for (size, scale) in sizes {
    let pixels = size * scale
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                  isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)!
    let transform = AffineTransform(scale: CGFloat(pixels) / 1024)
    (transform as NSAffineTransform).concat()
    NSColor(calibratedWhite: 0.95, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 60, y: 60, width: 904, height: 904), xRadius: 200, yRadius: 200).fill()
    NSColor(calibratedWhite: 0.13, alpha: 1).setStroke()
    let t = NSAffineTransform()
    t.translateX(by: 142, yBy: 862); t.scaleX(by: 31, yBy: -31); t.concat()
    let head = NSBezierPath()
    // SVG's first path is a 5-unit circle arc, with endpoints at (15,12.9) and (11.098,9).
    head.appendArc(withCenter: NSPoint(x: 16, y: 8), radius: 5,
                   startAngle: 101.534, endAngle: 168.47, clockwise: true)
    head.lineWidth = 2; head.lineCapStyle = .round; head.stroke()
    let handle = NSBezierPath()
    handle.move(to: NSPoint(x: 15, y: 12.9)); handle.line(to: NSPoint(x: 11.098, y: 9.001))
    handle.line(to: NSPoint(x: 3.585, y: 17.585))
    handle.curve(to: NSPoint(x: 6.412, y: 20.415), controlPoint1: NSPoint(x: 1.8, y: 19.6), controlPoint2: NSPoint(x: 4.4, y: 22.2))
    handle.close(); handle.lineWidth = 2; handle.lineCapStyle = .round; handle.lineJoinStyle = .round; handle.stroke()
    NSGraphicsContext.restoreGraphicsState()
    let name = "icon_\(size)x\(size)@\(scale)x.png"
    try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output).appendingPathComponent(name))
    entries.append(["idiom":"mac","size":"\(size)x\(size)","scale":"\(scale)x","filename":name])
}
let json: [String:Any] = ["images":entries,"info":["author":"xcode","version":1]]
try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted,.sortedKeys]).write(to: URL(fileURLWithPath: output).appendingPathComponent("Contents.json"))
