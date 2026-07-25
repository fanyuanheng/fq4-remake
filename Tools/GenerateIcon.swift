import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: swift GenerateIcon.swift <iconset-directory>\n", stderr)
    exit(64)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(
    at: outputURL,
    withIntermediateDirectories: true
)

let representations: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

func colour(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> NSColor {
    NSColor(red: red, green: green, blue: blue, alpha: 1)
}

for (name, pixels) in representations {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw CocoaError(.fileWriteUnknown)
    }

    bitmap.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

    let canvas = NSRect(x: 0, y: 0, width: pixels, height: pixels)
    NSColor.clear.setFill()
    canvas.fill()

    let inset = CGFloat(pixels) * 0.055
    let face = canvas.insetBy(dx: inset, dy: inset)
    let radius = CGFloat(pixels) * 0.205
    let background = NSBezierPath(roundedRect: face, xRadius: radius, yRadius: radius)
    colour(0.09, 0.085, 0.075).setFill()
    background.fill()

    let borderInset = CGFloat(pixels) * 0.075
    let border = NSBezierPath(
        roundedRect: face.insetBy(dx: borderInset, dy: borderInset),
        xRadius: radius * 0.72,
        yRadius: radius * 0.72
    )
    border.lineWidth = max(1, CGFloat(pixels) * 0.018)
    colour(0.43, 0.24, 0.60).setStroke()
    border.stroke()

    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let fontSize = CGFloat(pixels) * 0.36
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont(name: "NewYork-Bold", size: fontSize)
            ?? NSFont.systemFont(ofSize: fontSize, weight: .bold),
        .foregroundColor: colour(0.93, 0.90, 0.84),
        .paragraphStyle: paragraph,
        .kern: -CGFloat(pixels) * 0.018,
    ]
    let monogram = NSAttributedString(string: "FQ", attributes: attributes)
    let monogramSize = monogram.size()
    monogram.draw(
        at: NSPoint(
            x: (CGFloat(pixels) - monogramSize.width) / 2,
            y: CGFloat(pixels) * 0.40
        )
    )

    let ruleWidth = CGFloat(pixels) * 0.42
    let rule = NSBezierPath()
    rule.move(
        to: NSPoint(
            x: (CGFloat(pixels) - ruleWidth) / 2,
            y: CGFloat(pixels) * 0.38
        )
    )
    rule.line(
        to: NSPoint(
            x: (CGFloat(pixels) + ruleWidth) / 2,
            y: CGFloat(pixels) * 0.38
        )
    )
    rule.lineWidth = max(1, CGFloat(pixels) * 0.014)
    colour(0.82, 0.42, 0.22).setStroke()
    rule.stroke()

    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    try png.write(to: outputURL.appendingPathComponent(name))
}
