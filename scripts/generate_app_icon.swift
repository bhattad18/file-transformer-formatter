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
let roundedRect = NSBezierPath(roundedRect: canvasRect, xRadius: 220, yRadius: 220)

let gradient = NSGradient(
    colors: [
        NSColor(calibratedRed: 0.07, green: 0.14, blue: 0.30, alpha: 1.0),
        NSColor(calibratedRed: 0.05, green: 0.30, blue: 0.45, alpha: 1.0)
    ]
)!
gradient.draw(in: roundedRect, angle: -35)

NSColor.white.withAlphaComponent(0.1).setFill()
let glow = NSBezierPath(ovalIn: NSRect(x: 150, y: 600, width: 720, height: 260))
glow.fill()

let cardRect = NSRect(x: 228, y: 190, width: 568, height: 650)
let card = NSBezierPath(roundedRect: cardRect, xRadius: 70, yRadius: 70)
NSColor.white.withAlphaComponent(0.18).setFill()
card.fill()
NSColor.white.withAlphaComponent(0.52).setStroke()
card.lineWidth = 8
card.stroke()

let contentRect = cardRect.insetBy(dx: 70, dy: 110)
let splitX = contentRect.midX

let grid = NSBezierPath()
grid.lineWidth = 12
grid.lineCapStyle = .round
NSColor(calibratedRed: 0.50, green: 0.89, blue: 1.0, alpha: 1.0).setStroke()

for row in 0...4 {
    let y = contentRect.minY + CGFloat(row) * (contentRect.height / 4.0)
    grid.move(to: NSPoint(x: contentRect.minX, y: y))
    grid.line(to: NSPoint(x: splitX - 42, y: y))
}
for col in 0...2 {
    let x = contentRect.minX + CGFloat(col) * ((splitX - 42 - contentRect.minX) / 2.0)
    grid.move(to: NSPoint(x: x, y: contentRect.minY))
    grid.line(to: NSPoint(x: x, y: contentRect.maxY))
}
grid.stroke()

let braces = NSBezierPath()
braces.lineWidth = 18
braces.lineCapStyle = .round
NSColor(calibratedRed: 1.0, green: 0.81, blue: 0.34, alpha: 1.0).setStroke()

let braceTop = contentRect.maxY
let braceMid = contentRect.midY
let braceBot = contentRect.minY
let leftBraceX = splitX + 48
let rightBraceX = contentRect.maxX
let notch: CGFloat = 32

braces.move(to: NSPoint(x: leftBraceX + notch, y: braceTop))
braces.curve(to: NSPoint(x: leftBraceX, y: braceMid + 35),
             controlPoint1: NSPoint(x: leftBraceX, y: braceTop),
             controlPoint2: NSPoint(x: leftBraceX, y: braceMid + 80))
braces.curve(to: NSPoint(x: leftBraceX + notch, y: braceMid),
             controlPoint1: NSPoint(x: leftBraceX, y: braceMid + 5),
             controlPoint2: NSPoint(x: leftBraceX + notch, y: braceMid + 5))
braces.curve(to: NSPoint(x: leftBraceX, y: braceMid - 35),
             controlPoint1: NSPoint(x: leftBraceX + notch, y: braceMid - 5),
             controlPoint2: NSPoint(x: leftBraceX, y: braceMid - 5))
braces.curve(to: NSPoint(x: leftBraceX + notch, y: braceBot),
             controlPoint1: NSPoint(x: leftBraceX, y: braceMid - 80),
             controlPoint2: NSPoint(x: leftBraceX, y: braceBot))

braces.move(to: NSPoint(x: rightBraceX - notch, y: braceTop))
braces.curve(to: NSPoint(x: rightBraceX, y: braceMid + 35),
             controlPoint1: NSPoint(x: rightBraceX, y: braceTop),
             controlPoint2: NSPoint(x: rightBraceX, y: braceMid + 80))
braces.curve(to: NSPoint(x: rightBraceX - notch, y: braceMid),
             controlPoint1: NSPoint(x: rightBraceX, y: braceMid + 5),
             controlPoint2: NSPoint(x: rightBraceX - notch, y: braceMid + 5))
braces.curve(to: NSPoint(x: rightBraceX, y: braceMid - 35),
             controlPoint1: NSPoint(x: rightBraceX - notch, y: braceMid - 5),
             controlPoint2: NSPoint(x: rightBraceX, y: braceMid - 5))
braces.curve(to: NSPoint(x: rightBraceX - notch, y: braceBot),
             controlPoint1: NSPoint(x: rightBraceX, y: braceMid - 80),
             controlPoint2: NSPoint(x: rightBraceX, y: braceBot))
braces.stroke()

let swapBadge = NSBezierPath(ovalIn: NSRect(x: 452, y: 470, width: 120, height: 120))
NSColor(calibratedRed: 0.02, green: 0.11, blue: 0.24, alpha: 0.92).setFill()
swapBadge.fill()

let swap = NSBezierPath()
swap.lineWidth = 12
swap.lineCapStyle = .round
NSColor.white.setStroke()
swap.move(to: NSPoint(x: 482, y: 530))
swap.line(to: NSPoint(x: 542, y: 530))
swap.move(to: NSPoint(x: 542, y: 530))
swap.line(to: NSPoint(x: 528, y: 544))
swap.move(to: NSPoint(x: 542, y: 530))
swap.line(to: NSPoint(x: 528, y: 516))

swap.move(to: NSPoint(x: 542, y: 506))
swap.line(to: NSPoint(x: 482, y: 506))
swap.move(to: NSPoint(x: 482, y: 506))
swap.line(to: NSPoint(x: 496, y: 520))
swap.move(to: NSPoint(x: 482, y: 506))
swap.line(to: NSPoint(x: 496, y: 492))
swap.stroke()

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
