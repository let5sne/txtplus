import AppKit

enum SyntaxHighlighter {

    static func apply(_ storage: CodeTextStorage, range: NSRange) {
        // Reset to base attributes for the recolored range first.
        storage.setAttributes(Prefs.baseAttributes(), range: range)
        guard let lang = storage.language else { return }

        let text = storage.string as NSString
        var occupied: [NSRange] = []

        func occupies(_ r: NSRange) -> Bool {
            occupied.contains { NSIntersectionRange($0, r).length > 0 }
        }
        func paint(_ r: NSRange, _ color: NSColor, _ bold: Bool) {
            guard r.length > 0, !occupies(r) else { return }
            occupied.append(r)
            var attrs = Prefs.baseAttributes()
            attrs[.foregroundColor] = color
            if bold { attrs[.font] = Prefs.boldFont() }
            storage.setAttributes(attrs, range: r)
        }

        // Comments first (highest priority).
        if let bc = lang.blockComment {
            let pat = NSRegularExpression.escapedPattern(for: bc.start) + "[\\s\\S]*?" + NSRegularExpression.escapedPattern(for: bc.end)
            paintAll(pat, text, range) { paint($0, Theme.comment, false) }
        }
        for lc in lang.lineComments {
            let pat = NSRegularExpression.escapedPattern(for: lc) + "[^\\n]*"
            paintAll(pat, text, range) { paint($0, Theme.comment, false) }
        }
        // Strings.
        for sp in lang.strings {
            paintAll(sp, text, range) { paint($0, Theme.string, false) }
        }
        // Numbers.
        paintAll("\\b0x[0-9a-fA-F_]+\\b|\\b\\d[\\d_]*(?:\\.\\d+)?\\b", text, range) { paint($0, Theme.number, false) }
        // Keywords.
        if let kw = lang.keywordRegex {
            paintAll("\\b(?:" + kw + ")\\b", text, range) { paint($0, Theme.keyword, true) }
        }
    }

    private static func paintAll(_ pattern: String, _ text: NSString, _ range: NSRange, _ work: (NSRange) -> Void) {
        guard let re = try? NSRegularExpression(pattern: pattern, options: []) else { return }
        re.enumerateMatches(in: text as String, range: range) { m, _, _ in
            guard let m = m else { return }
            // Restrict to the recolored range (enumerateMatches may report matches starting inside).
            let r = m.range
            guard r.location >= range.location && NSMaxRange(r) <= NSMaxRange(range) else { return }
            work(r)
        }
    }
}
