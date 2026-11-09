#!/usr/bin/env swift
import AppKit
import Foundation

// Compose the original Clay symbol and maker mark without redrawing either.
// Mac and iOS Dark preserve transparency; iOS Any remains opaque for distribution.
// Run on a Mac with: xcrun swift scripts/prepare_assets.swift <project-root>
enum AssetError: LocalizedError {
    case failure(String)
    var errorDescription: String? { if case .failure(let text) = self { return text }; return nil }
}

func fittedRect(for image: NSImage, inside bounds: NSRect) -> NSRect {
    let scale = min(bounds.width / image.size.width, bounds.height / image.size.height)
    let width = image.size.width * scale
    let height = image.size.height * scale
    return NSRect(x: bounds.midX - width / 2, y: bounds.midY - height / 2, width: width, height: height)
}

func renderIcon(symbol: NSImage, maker: NSImage, pixels: Int, opaque: Bool, destination: URL) throws {
    // Both representations need AppKit's supported 32-bit stride. The unused
    // fourth byte of the opaque RGB representation is not an alpha channel.
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
        pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
        samplesPerPixel: opaque ? 3 : 4, hasAlpha: !opaque, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: pixels * 4, bitsPerPixel: 32),
        let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw AssetError.failure("Cannot allocate app icon bitmap.")
    }
    let size = CGFloat(pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    let background = opaque
        ? NSColor(calibratedRed: 0.985, green: 0.985, blue: 0.98, alpha: 1)
        : NSColor.clear
    background.setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill(using: .copy)
    // A little space below/right of the symbol keeps the small maker mark
    // distinct. Both source images retain their proportions and original color.
    let symbolBox = NSRect(x: size * 0.08, y: size * 0.18, width: size * 0.84, height: size * 0.74)
    let makerBox = NSRect(x: size * 0.72, y: size * 0.10, width: size * 0.18, height: size * 0.14)
    for (image, box) in [(symbol, symbolBox), (maker, makerBox)] {
        image.draw(in: fittedRect(for: image, inside: box), from: .zero,
                   operation: .sourceOver, fraction: 1, respectFlipped: false, hints: nil)
    }
    NSGraphicsContext.restoreGraphicsState()
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw AssetError.failure("Cannot encode app icon PNG.")
    }
    // Avoid touching unchanged files on incremental builds.
    if (try? Data(contentsOf: destination)) != data { try data.write(to: destination, options: .atomic) }
}

do {
    let root = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? FileManager.default.currentDirectoryPath)
    let source = root.appendingPathComponent("Resources/Assets.xcassets/ClayMark.imageset/clay.png")
    let makerSource = root.appendingPathComponent("Resources/Assets.xcassets/MakerMark.imageset/maker-mark.png")
    guard let symbol = NSImage(contentsOf: source), symbol.size.width > 0, symbol.size.height > 0 else {
        throw AssetError.failure("Missing Clay symbol at \(source.path)")
    }
    guard let maker = NSImage(contentsOf: makerSource), maker.size.width > 0, maker.size.height > 0 else {
        throw AssetError.failure("Missing maker mark at \(makerSource.path)")
    }
    let output = root.appendingPathComponent("Resources/Assets.xcassets/AppIcon.appiconset", isDirectory: true)
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    var images: [[String: Any]] = []
    for points in [16, 32, 128, 256, 512] {
        for scale in [1, 2] {
            let name = "mac-\(points)@\(scale)x.png"
            try renderIcon(symbol: symbol, maker: maker, pixels: points * scale, opaque: false,
                           destination: output.appendingPathComponent(name))
            images.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x", "filename": name])
        }
    }
    try renderIcon(symbol: symbol, maker: maker, pixels: 1024, opaque: true,
                   destination: output.appendingPathComponent("ios-1024.png"))
    images.append(["idiom": "universal", "platform": "ios", "size": "1024x1024", "filename": "ios-1024.png"])
    try renderIcon(symbol: symbol, maker: maker, pixels: 1024, opaque: false,
                   destination: output.appendingPathComponent("ios-dark-1024.png"))
    images.append(["idiom": "universal", "platform": "ios", "size": "1024x1024", "filename": "ios-dark-1024.png",
                   "appearances": [["appearance": "luminosity", "value": "dark"]]])
    let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
    let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    let manifest = output.appendingPathComponent("Contents.json")
    if (try? Data(contentsOf: manifest)) != json { try json.write(to: manifest, options: .atomic) }
    let previews = root.appendingPathComponent("build/IconPreviews", isDirectory: true)
    try FileManager.default.createDirectory(at: previews, withIntermediateDirectories: true)
    try renderIcon(symbol: symbol, maker: maker, pixels: 1024, opaque: false,
                   destination: previews.appendingPathComponent("Clay-icon-transparent-1024.png"))
    print("Prepared Clay symbol and maker icons: transparent Mac/iOS Dark, opaque iOS Any.")
} catch {
    FileHandle.standardError.write(Data("Clay assets: \(error.localizedDescription)\n".utf8))
    exit(1)
}
