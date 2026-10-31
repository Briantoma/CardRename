import AppKit

// Draws the app icon: a camera card with an amber reel label being renamed.
// Run with ./build.sh icon, which turns the PNG into Resources/AppIcon.icns.

let size: CGFloat = 1024
let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                              colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

// Background: macOS icon grid, 824 px rounded square centred on a 1024 canvas.
let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = color(0x000000, 0.35)
shadow.shadowOffset = NSSize(width: 0, height: -12)
shadow.shadowBlurRadius = 28
shadow.set()
color(0x1B1E23).setFill()
tilePath.fill()
NSGraphicsContext.restoreGraphicsState()
NSGradient(starting: color(0x343941), ending: color(0x14161A))!.draw(in: tilePath, angle: -90)

// Card: rounded rectangle with the top-right corner cut, like an SD card.
let card = NSRect(x: 297, y: 205, width: 430, height: 590)
let cut: CGFloat = 115, r: CGFloat = 34
let cardPath = NSBezierPath()
cardPath.move(to: NSPoint(x: card.minX + r, y: card.minY))
cardPath.line(to: NSPoint(x: card.maxX - r, y: card.minY))
cardPath.curve(to: NSPoint(x: card.maxX, y: card.minY + r),
               controlPoint1: NSPoint(x: card.maxX, y: card.minY), controlPoint2: NSPoint(x: card.maxX, y: card.minY))
cardPath.line(to: NSPoint(x: card.maxX, y: card.maxY - cut))
cardPath.line(to: NSPoint(x: card.maxX - cut, y: card.maxY))
cardPath.line(to: NSPoint(x: card.minX + r, y: card.maxY))
cardPath.curve(to: NSPoint(x: card.minX, y: card.maxY - r),
               controlPoint1: NSPoint(x: card.minX, y: card.maxY), controlPoint2: NSPoint(x: card.minX, y: card.maxY))
cardPath.line(to: NSPoint(x: card.minX, y: card.minY + r))
cardPath.curve(to: NSPoint(x: card.minX + r, y: card.minY),
               controlPoint1: NSPoint(x: card.minX, y: card.minY), controlPoint2: NSPoint(x: card.minX, y: card.minY))
cardPath.close()

NSGraphicsContext.saveGraphicsState()
let cardShadow = NSShadow()
cardShadow.shadowColor = color(0x000000, 0.45)
cardShadow.shadowOffset = NSSize(width: 0, height: -10)
cardShadow.shadowBlurRadius = 24
cardShadow.set()
color(0xE6E7EA).setFill()
cardPath.fill()
NSGraphicsContext.restoreGraphicsState()
NSGradient(starting: color(0xF7F7F8), ending: color(0xD3D5DA))!.draw(in: cardPath, angle: -90)

// Grip ridges near the top of the card.
color(0x9EA2AA).setFill()
for i in 0..<5 {
    let x = card.minX + 52 + CGFloat(i) * 46
    NSBezierPath(roundedRect: NSRect(x: x, y: card.maxY - 150, width: 24, height: 92), xRadius: 8, yRadius: 8).fill()
}

// Amber label with the reel name and a text cursor: the card being named.
let label = NSRect(x: card.minX + 34, y: card.minY + 70, width: card.width - 68, height: 200)
color(0xFF9F0A).setFill()
NSBezierPath(roundedRect: label, xRadius: 30, yRadius: 30).fill()

let font = NSFont.monospacedSystemFont(ofSize: 112, weight: .heavy)
let text = NSAttributedString(string: "A001", attributes: [.font: font, .foregroundColor: color(0x1C1C1E)])
let textSize = text.size()
let cursorGap: CGFloat = 14, cursorWidth: CGFloat = 12
let textX = label.midX - (textSize.width + cursorGap + cursorWidth) / 2
let textY = label.midY - textSize.height / 2
text.draw(at: NSPoint(x: textX, y: textY))
color(0x1C1C1E).setFill()
NSBezierPath(roundedRect: NSRect(x: textX + textSize.width + cursorGap, y: label.midY - 62, width: cursorWidth, height: 124),
             xRadius: 4, yRadius: 4).fill()

NSGraphicsContext.current = nil
try! bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
print("Wrote \(output)")
