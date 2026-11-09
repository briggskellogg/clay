#!/usr/bin/env swift
import AppKit
import Foundation

// Package the supplied Clay artwork as opaque app icons. The original is unmodified.
// Run on a Mac with: xcrun swift scripts/prepare_assets.swift <project-root>
enum AssetError: LocalizedError {
    case failure(String)
    var errorDescription: String? { if case .failure(let text) = self { return text }; return nil }
}

func renderIcon(art: NSImage, pixels: Int, destination: URL) throws {
    // AppKit needs a supported 32-bit RGB stride; the unused byte is not alpha.
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
        pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
        samplesPerPixel: 3, hasAlpha: false, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: pixels * 4, bitsPerPixel: 32),
        let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw AssetError.failure("Cannot allocate app icon bitmap.")
    }
    let size = CGFloat(pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    NSColor(calibratedRed: 0.985, green: 0.985, blue: 0.98, alpha: 1).setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()
    let inset = size * 0.04
    art.draw(in: NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2),
             from: .zero, operation: .sourceOver, fraction: 1,
             respectFlipped: false, hints: nil)
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
    guard let art = NSImage(contentsOf: source) else { throw AssetError.failure("Missing Clay artwork at \(source.path)") }
    let output = root.appendingPathComponent("Resources/Assets.xcassets/AppIcon.appiconset", isDirectory: true)
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    var images: [[String: String]] = []
    for points in [16, 32, 128, 256, 512] {
        for scale in [1, 2] {
            let name = "mac-\(points)@\(scale)x.png"
            try renderIcon(art: art, pixels: points * scale, destination: output.appendingPathComponent(name))
            images.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x", "filename": name])
        }
    }
    try renderIcon(art: art, pixels: 1024, destination: output.appendingPathComponent("ios-1024.png"))
    images.append(["idiom": "universal", "platform": "ios", "size": "1024x1024", "filename": "ios-1024.png"])
    let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
    let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    let manifest = output.appendingPathComponent("Contents.json")
    if (try? Data(contentsOf: manifest)) != json { try json.write(to: manifest, options: .atomic) }
    print("Prepared Clay app icons from the supplied artwork.")
} catch {
    FileHandle.standardError.write(Data("Clay assets: \(error.localizedDescription)\n".utf8))
    exit(1)
}
