import AppKit

/// Shared look + language definitions for the editor.
enum Theme {
    static let background = NSColor.textBackgroundColor
    static let text = NSColor.textColor
    // Dynamic name-based colors: resolve correctly in both light and dark.
    static let comment = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .vibrantDark, .accessibilityHighContrastDarkAqua]) != nil
            ? NSColor(calibratedRed: 0.55, green: 0.78, blue: 0.45, alpha: 1)
            : NSColor(calibratedRed: 0.00, green: 0.50, blue: 0.00, alpha: 1)
    }
    static let keyword = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .vibrantDark, .accessibilityHighContrastDarkAqua]) != nil
            ? NSColor(calibratedRed: 0.62, green: 0.67, blue: 1.00, alpha: 1)
            : NSColor(calibratedRed: 0.00, green: 0.00, blue: 0.85, alpha: 1)
    }
    static let string = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .vibrantDark, .accessibilityHighContrastDarkAqua]) != nil
            ? NSColor(calibratedRed: 1.00, green: 0.55, blue: 0.55, alpha: 1)
            : NSColor(calibratedRed: 0.64, green: 0.08, blue: 0.08, alpha: 1)
    }
    static let number = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .vibrantDark, .accessibilityHighContrastDarkAqua]) != nil
            ? NSColor(calibratedRed: 0.50, green: 0.90, blue: 0.70, alpha: 1)
            : NSColor(calibratedRed: 0.04, green: 0.52, blue: 0.35, alpha: 1)
    }
    static let gutterText = NSColor.secondaryLabelColor
    static let gutterBg = NSColor.textBackgroundColor
    static let tabBarBg = NSColor.windowBackgroundColor
    static let tabActiveBg = NSColor.textBackgroundColor
    static let statusBg = NSColor.windowBackgroundColor
}

enum Prefs {
    static var fontSize: CGFloat = 13
    static var wraps: Bool = true

    static func font() -> NSFont {
        NSFont(name: "Menlo", size: fontSize) ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
    }
    static func gutterFont() -> NSFont {
        NSFont(name: "Menlo", size: max(9, fontSize - 2)) ?? NSFont.monospacedSystemFont(ofSize: max(9, fontSize - 2), weight: .regular)
    }
    static func boldFont() -> NSFont {
        NSFontManager.shared.convert(font(), toHaveTrait: .boldFontMask)
    }

    static func baseAttributes() -> [NSAttributedString.Key: Any] {
        let ps = NSMutableParagraphStyle()
        ps.defaultTabInterval = (font().maximumAdvancement.width) * 4
        return [.font: font(), .foregroundColor: Theme.text, .paragraphStyle: ps]
    }
}

struct LangRule {
    let name: String
    let exts: [String]
    let keywordRegex: String?      // alternation, no boundaries
    let lineComments: [String]
    let blockComment: (start: String, end: String)?
    let strings: [String]          // regex per delimiter
}

enum Languages {
    static let all: [LangRule] = [swift, js, python, json, html, markdown]

    static func detect(_ ext: String) -> LangRule? {
        let e = ext.lowercased()
        return all.first { $0.exts.contains(e) }
    }

    static let swift = LangRule(
        name: "Swift",
        exts: ["swift"],
        keywordRegex: "func|let|var|if|else|guard|for|in|while|repeat|return|class|struct|enum|protocol|extension|import|switch|case|default|break|continue|do|try|catch|throw|throws|rethrows|init|deinit|self|Self|super|nil|true|false|where|as|is|public|private|internal|fileprivate|open|static|final|defer|fallthrough|weak|unowned|async|await|actor|subscript|precedencegroup|operator|associatedtype|typealias|indirect|convenience|required|override|mutating|nonmutating|lazy|optional|inout|some|any",
        lineComments: ["//"],
        blockComment: ("/*", "*/"),
        strings: ["\"(?:[^\"\\\\]|\\\\.)*\""]
    )

    static let js = LangRule(
        name: "JavaScript",
        exts: ["js", "ts", "tsx", "jsx", "mjs", "cjs"],
        keywordRegex: "var|let|const|function|return|if|else|for|while|do|switch|case|break|continue|new|this|class|extends|super|import|export|from|default|try|catch|finally|throw|typeof|instanceof|in|of|async|await|yield|delete|void|null|undefined|true|false|console|window|document",
        lineComments: ["//"],
        blockComment: ("/*", "*/"),
        strings: ["\"(?:[^\"\\\\]|\\\\.)*\"", "'(?:[^'\\\\]|\\\\.)*'", "`(?:[^`\\\\]|\\\\.)*`"]
    )

    static let python = LangRule(
        name: "Python",
        exts: ["py", "pyw"],
        keywordRegex: "def|return|if|elif|else|for|while|in|not|and|or|is|None|True|False|import|from|as|class|try|except|finally|with|lambda|pass|break|continue|global|nonlocal|assert|raise|yield|async|await|del|print|self",
        lineComments: ["#"],
        blockComment: nil,
        strings: ["\"(?:[^\"\\\\]|\\\\.)*\"", "'(?:[^'\\\\]|\\\\.)*\""]
    )

    static let json = LangRule(
        name: "JSON",
        exts: ["json", "jsonc"],
        keywordRegex: "true|false|null",
        lineComments: [],
        blockComment: nil,
        strings: ["\"(?:[^\"\\\\]|\\\\.)*\""]
    )

    static let html = LangRule(
        name: "HTML",
        exts: ["html", "htm", "xml", "svg"],
        keywordRegex: nil,
        lineComments: [],
        blockComment: ("<!--", "-->"),
        strings: ["\"[^\"]*\"", "'[^']*'"]
    )

    static let markdown = LangRule(
        name: "Markdown",
        exts: ["md", "markdown"],
        keywordRegex: nil,
        lineComments: [],
        blockComment: nil,
        strings: []
    )
}
