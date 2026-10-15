import AppKit

// A site's colour, read off its icon: what the live pin is filled with, as
// in Dia.
//
// The icon is drawn small and its pixels averaged — the coloured ones only.
// White, black and greys are what most icons are drawn on or outlined with,
// and an average that counted them would come out a muddy grey for nearly
// every site. An icon with no colour to speak of has no tint, and its pin
// keeps the usual grey.

@MainActor
enum IconTint {
    private static let cache = NSCache<NSImage, NSColor>()
    /// What the cache holds for an icon with no colour, as it can't hold nil.
    private static let none = NSColor.clear

    static func colour(of icon: NSImage) -> NSColor? {
        if let known = cache.object(forKey: icon) { return known === none ? nil : known }
        let found = read(icon)
        cache.setObject(found ?? none, forKey: icon)
        return found
    }

    private static func read(_ icon: NSImage) -> NSColor? {
        let side = 16
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: side * 4, bitsPerPixel: 32
        ) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        icon.draw(in: NSRect(x: 0, y: 0, width: side, height: side))
        NSGraphicsContext.restoreGraphicsState()
        guard let data = bitmap.bitmapData else { return nil }

        var red = 0.0, green = 0.0, blue = 0.0, weight = 0.0
        for i in 0..<(side * side) {
            let a = Double(data[i * 4 + 3]) / 255
            guard a > 0.5 else { continue }
            // Premultiplied by the drawing; undone so a soft edge counts
            // as the colour it is, not a darker one.
            let r = Double(data[i * 4]) / 255 / a
            let g = Double(data[i * 4 + 1]) / 255 / a
            let b = Double(data[i * 4 + 2]) / 255 / a
            let high = max(r, g, b), low = min(r, g, b)
            let saturation = high == 0 ? 0 : (high - low) / high
            guard saturation > 0.25, high > 0.2 else { continue }
            // The more vivid a pixel, the more it says about the site.
            let w = saturation * a
            red += r * w; green += g * w; blue += b * w; weight += w
        }
        // A few coloured pixels in a grey icon are a detail, not its colour.
        guard weight > 6 else { return nil }
        return NSColor(srgbRed: red / weight, green: green / weight, blue: blue / weight, alpha: 1)
    }
}
