import AppKit
import Foundation

let size = 1024
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: false,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fatalError("Unable to create icon bitmap")
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor.black.setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()

let wave = NSBezierPath()
wave.lineWidth = 58
wave.lineCapStyle = .round
wave.lineJoinStyle = .round
wave.move(to: NSPoint(x: 155, y: 405))
wave.curve(to: NSPoint(x: 500, y: 535), controlPoint1: NSPoint(x: 280, y: 405), controlPoint2: NSPoint(x: 360, y: 535))
wave.curve(to: NSPoint(x: 870, y: 610), controlPoint1: NSPoint(x: 650, y: 535), controlPoint2: NSPoint(x: 710, y: 610))
NSColor.white.setStroke()
wave.stroke()

let upperWave = NSBezierPath()
upperWave.lineWidth = 34
upperWave.lineCapStyle = .round
upperWave.move(to: NSPoint(x: 215, y: 610))
upperWave.curve(to: NSPoint(x: 495, y: 690), controlPoint1: NSPoint(x: 310, y: 610), controlPoint2: NSPoint(x: 385, y: 690))
upperWave.curve(to: NSPoint(x: 805, y: 720), controlPoint1: NSPoint(x: 620, y: 690), controlPoint2: NSPoint(x: 670, y: 720))
NSColor(calibratedWhite: 0.72, alpha: 1).setStroke()
upperWave.stroke()

let lowerWave = NSBezierPath()
lowerWave.lineWidth = 34
lowerWave.lineCapStyle = .round
lowerWave.move(to: NSPoint(x: 210, y: 275))
lowerWave.curve(to: NSPoint(x: 515, y: 345), controlPoint1: NSPoint(x: 315, y: 275), controlPoint2: NSPoint(x: 390, y: 345))
lowerWave.curve(to: NSPoint(x: 810, y: 390), controlPoint1: NSPoint(x: 640, y: 345), controlPoint2: NSPoint(x: 690, y: 390))
NSColor(calibratedWhite: 0.46, alpha: 1).setStroke()
lowerWave.stroke()
NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Unable to encode icon PNG")
}

let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
let projectRoot = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let outputDirectory = projectRoot.appendingPathComponent("Tide/Resources/Assets.xcassets/AppIcon.appiconset", isDirectory: true)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
try png.write(to: outputDirectory.appendingPathComponent("TideIcon.png"), options: .atomic)
