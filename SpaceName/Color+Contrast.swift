import AppKit

extension NSColor {
    convenience init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(srgbRed: CGFloat((v >> 16) & 0xFF) / 255,
                  green: CGFloat((v >> 8) & 0xFF) / 255,
                  blue: CGFloat(v & 0xFF) / 255,
                  alpha: 1)
    }

    var hexString: String {
        let c = usingColorSpace(.sRGB) ?? self
        func byte(_ x: CGFloat) -> Int { Int((min(max(x, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(c.redComponent), byte(c.greenComponent), byte(c.blueComponent))
    }

    /// WCAG relative luminance.
    var relativeLuminance: CGFloat {
        let c = usingColorSpace(.sRGB) ?? self
        func lin(_ x: CGFloat) -> CGFloat { x <= 0.03928 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(c.redComponent) + 0.7152 * lin(c.greenComponent) + 0.0722 * lin(c.blueComponent)
    }

    /// White on mid and dark colors, black on light ones. Pure max-contrast picks
    /// black on system blue/red/purple, which looks wrong next to macOS; bold
    /// menu-bar text only needs ~3:1, which white clears up to this luminance.
    var contrastingTextColor: NSColor {
        relativeLuminance < 0.3 ? .white : .black
    }

    static let presets: [(name: String, hex: String)] = [
        ("Red", "#FF3B30"), ("Orange", "#FF9500"), ("Yellow", "#FFCC00"),
        ("Green", "#34C759"), ("Mint", "#00C7BE"), ("Teal", "#30B0C7"),
        ("Blue", "#007AFF"), ("Indigo", "#5856D6"), ("Purple", "#AF52DE"),
        ("Pink", "#FF2D55"), ("Gray", "#8E8E93"),
    ]
}
