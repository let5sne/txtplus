import AppKit

/// NSTextStorage subclass that owns its backing string and re-highlights on edits.
final class CodeTextStorage: NSTextStorage {

    private let backing = NSMutableAttributedString()
    var language: LangRule?

    private var isHighlighting = false
    /// True while an IME has an active marked-text composition. We skip recolor
    /// in that window so we don't clobber the attributes the input method set,
    /// which can abort the composition (CJK input dies, ASCII still works).
    var hasMarkedText = false

    override var string: String { backing.string }

    override func attributes(at location: Int, effectiveRange range: NSRangePointer?) -> [NSAttributedString.Key: Any] {
        backing.attributes(at: location, effectiveRange: range)
    }

    override func replaceCharacters(in range: NSRange, with str: String) {
        beginEditing()
        backing.replaceCharacters(in: range, with: str)
        edited([.editedCharacters, .editedAttributes], range: range, changeInLength: str.utf16.count - range.length)
        endEditing()
    }

    override func setAttributes(_ attrs: [NSAttributedString.Key: Any]?, range: NSRange) {
        beginEditing()
        backing.setAttributes(attrs, range: range)
        edited(.editedAttributes, range: range, changeInLength: 0)
        endEditing()
    }

    override func processEditing() {
        super.processEditing()
        guard !isHighlighting else { return }
        // Don't touch attributes mid-composition; recolor happens on commit
        // (insertText sets hasMarkedText=false before super, triggering this).
        if hasMarkedText { return }
        isHighlighting = true
        defer { isHighlighting = false }

        let length = (self.string as NSString).length
        // ponytail: whole-doc recolor below 200k chars; per-line above that.
        // Whole-doc keeps block-comment state correct; ceiling noted for very large files.
        let range: NSRange
        if length < 200_000 {
            range = NSRange(location: 0, length: length)
        } else {
            range = (self.string as NSString).lineRange(for: self.editedRange)
        }
        SyntaxHighlighter.apply(self, range: range)
    }

    func setString(_ s: String) {
        replaceCharacters(in: NSRange(location: 0, length: (string as NSString).length), with: s)
    }

    /// Recolor the whole document outside any edit transaction. Used after an
    /// IME commit/unmark so we don't recolor mid-transaction (caret corruption).
    func recolorWholeDocument() {
        guard !isHighlighting else { return }
        let length = (string as NSString).length
        guard length > 0 else { return }
        isHighlighting = true
        defer { isHighlighting = false }
        beginEditing()
        SyntaxHighlighter.apply(self, range: NSRange(location: 0, length: length))
        edited(.editedAttributes, range: NSRange(location: 0, length: length), changeInLength: 0)
        endEditing()
    }
}
