import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("usage: make-icon <output.png>\n", stderr)
    exit(2)
}

let side: CGFloat = 1024
let image = NSImage(size: NSSize(width: side, height: side))
image.lockFocus()

let canvas = NSRect(x: 0, y: 0, width: side, height: side)
NSColor.clear.setFill()
canvas.fill()

let tile = NSRect(x: 72, y: 72, width: 880, height: 880)
let tilePath = NSBezierPath(roundedRect: tile, xRadius: 220, yRadius: 220)
let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.30, green: 0.22, blue: 0.88, alpha: 1),
    NSColor(calibratedRed: 0.05, green: 0.55, blue: 0.96, alpha: 1)
])!
gradient.draw(in: tilePath, angle: -45)

NSGraphicsContext.current?.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.2)
shadow.shadowBlurRadius = 35
shadow.shadowOffset = NSSize(width: 0, height: -14)
shadow.set()

let keyboardRect = NSRect(x: 205, y: 290, width: 614, height: 430)
let keyboard = NSBezierPath(roundedRect: keyboardRect, xRadius: 70, yRadius: 70)
NSColor.white.withAlphaComponent(0.96).setFill()
keyboard.fill()
NSGraphicsContext.current?.restoreGraphicsState()

let keySize = NSSize(width: 112, height: 92)
let origins: [NSPoint] = [
    NSPoint(x: 260, y: 540), NSPoint(x: 392, y: 540), NSPoint(x: 524, y: 540),
    NSPoint(x: 260, y: 425), NSPoint(x: 392, y: 425), NSPoint(x: 524, y: 425)
]
for origin in origins {
    let keyPath = NSBezierPath(roundedRect: NSRect(origin: origin, size: keySize), xRadius: 24, yRadius: 24)
    NSColor(calibratedWhite: 0.83, alpha: 1).setFill()
    keyPath.fill()
}

let knobCenter = NSPoint(x: 704, y: 515)
let knobRect = NSRect(x: knobCenter.x - 65, y: knobCenter.y - 65, width: 130, height: 130)
let knob = NSBezierPath(ovalIn: knobRect)
NSColor(calibratedWhite: 0.28, alpha: 1).setFill()
knob.fill()
let marker = NSBezierPath(roundedRect: NSRect(x: 698, y: 548, width: 12, height: 42), xRadius: 6, yRadius: 6)
NSColor.white.withAlphaComponent(0.85).setFill()
marker.fill()

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let png = bitmap.representation(using: .png, properties: [:])
else {
    fputs("could not render icon\n", stderr)
    exit(1)
}

try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
