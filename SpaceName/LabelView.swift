import AppKit

/// The rounded pill. Fills the width it needs for its text, centered in its bounds.
final class LabelView: NSView {
    var text = "" { didSet { needsDisplay = true } }
    var color: NSColor = .gray { didSet { needsDisplay = true } }
    var pillHeight: CGFloat = 18 { didSet { needsDisplay = true } }

    private let horizontalPadding: CGFloat = 10

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError() }

    private var font: NSFont {
        NSFont.boldSystemFont(ofSize: NSFont.menuBarFont(ofSize: 0).pointSize)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard !text.isEmpty else { return }

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        paragraph.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color.contrastingTextColor,
            .paragraphStyle: paragraph,
        ]

        let textWidth = ceil((text as NSString).size(withAttributes: attrs).width)
        let width = min(textWidth + horizontalPadding * 2, bounds.width)
        let pill = NSRect(x: (bounds.width - width) / 2,
                          y: (bounds.height - pillHeight) / 2,
                          width: width, height: pillHeight)

        color.setFill()
        NSBezierPath(roundedRect: pill, xRadius: pillHeight / 2, yRadius: pillHeight / 2).fill()

        let lineHeight = ceil(font.ascender - font.descender)
        let textRect = NSRect(x: pill.minX + horizontalPadding,
                              y: pill.midY - lineHeight / 2,
                              width: pill.width - horizontalPadding * 2,
                              height: lineHeight)
        (text as NSString).draw(with: textRect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], attributes: attrs)
    }
}
