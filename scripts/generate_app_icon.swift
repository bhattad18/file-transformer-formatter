import AppKit
import Foundation

let fileManager = FileManager.default
let rootURL = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let assetsURL = rootURL.appendingPathComponent("Assets", isDirectory: true)
let iconsetURL = assetsURL.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let icnsURL = assetsURL.appendingPathComponent("AppIcon.icns")

try? fileManager.createDirectory(at: assetsURL, withIntermediateDirectories: true)
try? fileManager.removeItem(at: iconsetURL)
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let baseSize = NSSize(width: 1024, height: 1024)
let baseImage = NSImage(size: baseSize)
baseImage.lockFocus()

let canvasRect = NSRect(origin: .zero, size: baseSize)
NSColor.clear.setFill()
canvasRect.fill()

let shieldPath = NSBezierPath()
shieldPath.move(to: NSPoint(x: 512, y: 942))
shieldPath.curve(
    to: NSPoint(x: 874, y: 790),
    controlPoint1: NSPoint(x: 630, y: 866),
    controlPoint2: NSPoint(x: 730, y: 818)
)
shieldPath.line(to: NSPoint(x: 874, y: 412))
shieldPath.curve(
    to: NSPoint(x: 512, y: 58),
    controlPoint1: NSPoint(x: 874, y: 226),
    controlPoint2: NSPoint(x: 684, y: 126)
)
shieldPath.curve(
    to: NSPoint(x: 150, y: 412),
    controlPoint1: NSPoint(x: 340, y: 126),
    controlPoint2: NSPoint(x: 150, y: 226)
)
shieldPath.line(to: NSPoint(x: 150, y: 790))
shieldPath.curve(
    to: NSPoint(x: 512, y: 942),
    controlPoint1: NSPoint(x: 294, y: 818),
    controlPoint2: NSPoint(x: 394, y: 866)
)
shieldPath.close()

NSGraphicsContext.current?.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor(calibratedRed: 0.02, green: 0.18, blue: 0.42, alpha: 0.28)
shadow.shadowOffset = NSSize(width: 0, height: -18)
shadow.shadowBlurRadius = 30
shadow.set()
let shieldGradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.00, green: 0.78, blue: 0.82, alpha: 1.0),
    NSColor(calibratedRed: 0.09, green: 0.34, blue: 0.92, alpha: 1.0)
])!
shieldGradient.draw(in: shieldPath, angle: 0)
NSGraphicsContext.current?.restoreGraphicsState()

NSGraphicsContext.current?.saveGraphicsState()
shieldPath.addClip()
NSColor(calibratedWhite: 1.0, alpha: 0.12).setFill()
NSBezierPath(rect: NSRect(x: 512, y: 40, width: 380, height: 920)).fill()
NSColor(calibratedRed: 0.0, green: 0.30, blue: 0.55, alpha: 0.13).setFill()
NSBezierPath(rect: NSRect(x: 140, y: 40, width: 372, height: 920)).fill()
NSGraphicsContext.current?.restoreGraphicsState()

let checkPath = NSBezierPath()
checkPath.lineWidth = 72
checkPath.lineCapStyle = .round
checkPath.lineJoinStyle = .round
NSColor.white.setStroke()
checkPath.move(to: NSPoint(x: 344, y: 532))
checkPath.line(to: NSPoint(x: 476, y: 398))
checkPath.line(to: NSPoint(x: 704, y: 674))
checkPath.stroke()

NSColor.white.withAlphaComponent(0.24).setStroke()
shieldPath.lineWidth = 5
shieldPath.stroke()

baseImage.unlockFocus()

func resizedPNG(from image: NSImage, size: Int, to destination: URL) throws {
    let targetSize = NSSize(width: size, height: size)
    let resized = NSImage(size: targetSize)
    resized.lockFocus()
    image.draw(
        in: NSRect(origin: .zero, size: targetSize),
        from: NSRect(origin: .zero, size: image.size),
        operation: .copy,
        fraction: 1.0
    )
    resized.unlockFocus()

    guard let tiff = resized.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconGeneration", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to generate PNG."])
    }
    try png.write(to: destination)
}

let iconEntries: [(name: String, size: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for entry in iconEntries {
    try resizedPNG(
        from: baseImage,
        size: entry.size,
        to: iconsetURL.appendingPathComponent(entry.name)
    )
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", icnsURL.path]
try process.run()
process.waitUntilExit()

if process.terminationStatus != 0 {
    throw NSError(domain: "IconGeneration", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "iconutil failed."])
}

print("Generated icon at \(icnsURL.path)")
