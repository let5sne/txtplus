import AppKit

/// Vertical ruler that draws line numbers aligned with the text layout.
final class LineNumberRuler: NSRulerView {

    weak var codeView: CodeTextView?

    init(textView: CodeTextView) {
        self.codeView = textView
        super.init(scrollView: nil, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 48
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        Theme.gutterBg.setFill()
        NSBezierPath(rect: bounds).fill()
        // Divider on the right edge.
        NSColor.separatorColor.setFill()
        NSBezierPath(rect: NSRect(x: bounds.maxX - 1, y: 0, width: 1, height: bounds.height)).fill()

        guard let tv = codeView, let lm = tv.layoutManager, let tc = tv.textContainer else { return }

        let attrs: [NSAttributedString.Key: Any] = [.font: Prefs.gutterFont(), .foregroundColor: Theme.gutterText]
        let originY = tv.visibleRect.origin.y
        let glyphRange = lm.glyphRange(forBoundingRect: tv.visibleRect, in: tc)

        var glyph = glyphRange.location
        while glyph < NSMaxRange(glyphRange) {
            var lineGlyphRange = NSRange()
            let lineRect = lm.lineFragmentRect(forGlyphAt: glyph, effectiveRange: &lineGlyphRange)
            let charIndex = lm.characterIndexForGlyph(at: glyph)
            let lineNum = lineNumber(forChar: charIndex, in: tv.string)
            let numStr = "\(lineNum)" as NSString
            let size = numStr.size(withAttributes: attrs)
            // Ruler is flipped: y from top = lineRect.minY - scroll origin.
            let y = lineRect.minY - originY + (lineRect.height - size.height) / 2
            numStr.draw(at: NSPoint(x: bounds.maxX - size.width - 6, y: y), withAttributes: attrs)
            if lineGlyphRange.length == 0 { break }
            glyph = NSMaxRange(lineGlyphRange)
        }
    }

    // ponytail: O(n) per visible line via substring; cache lineStarts if huge files lag on scroll.
    private func lineNumber(forChar index: Int, in s: String) -> Int {
        let ns = s as NSString
        let safe = min(max(index, 0), ns.length)
        let prefix = ns.substring(to: safe)
        return prefix.components(separatedBy: "\n").count
    }
}
