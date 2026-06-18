import AppKit

/// Plain text view backed by CodeTextStorage.
final class CodeTextView: NSTextView {

    /// Set by the controller; called with file URLs dropped onto this view.
    var onDropFiles: (([URL]) -> Void)?

    init(storage: CodeTextStorage) {
        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)
        let container = NSTextContainer()
        container.size = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        container.widthTracksTextView = true
        container.lineFragmentPadding = 4
        layoutManager.addTextContainer(container)
        super.init(frame: .zero, textContainer: container)

        isRichText = false
        importsGraphics = false
        allowsUndo = true
        isEditable = true
        isSelectable = true
        // ponytail: must be vertically resizable or the text view collapses to
        // 0 height in a scroll view — nothing renders, nothing editable.
        isVerticallyResizable = true
        drawsBackground = true
        backgroundColor = Theme.background
        font = Prefs.font()
        textColor = Theme.text
        typingAttributes = Prefs.baseAttributes()
        usesFindBar = true
        isIncrementalSearchingEnabled = true
        smartInsertDeleteEnabled = false
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticLinkDetectionEnabled = false
        insertionPointColor = Theme.text

        applyWrap()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func applyWrap() {
        if Prefs.wraps {
            isHorizontallyResizable = false
            textContainer?.size = NSSize(width: bounds.width, height: CGFloat.greatestFiniteMagnitude)
            textContainer?.widthTracksTextView = true
        } else {
            isHorizontallyResizable = true
            textContainer?.widthTracksTextView = false
            textContainer?.size = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        }
        needsLayout = true
        needsDisplay = true
    }

    func refont() {
        font = Prefs.font()
        typingAttributes = Prefs.baseAttributes()
        // Re-apply colors with the new font.
        let len = (string as NSString).length
        textStorage?.setAttributes(Prefs.baseAttributes(), range: NSRange(location: 0, length: len))
    }

    // MARK: - IME marked-text coordination

    private var codeStorage: CodeTextStorage? { textStorage as? CodeTextStorage }

    override func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        // Pause recoloring so the input method's marked-text attributes survive.
        codeStorage?.hasMarkedText = true
        super.setMarkedText(string, selectedRange: selectedRange, replacementRange: replacementRange)
    }

    override func insertText(_ string: Any, replacementRange: NSRange) {
        // Keep recolor paused through the commit transaction — processEditing
        // fires mid-replace when self.string is in an intermediate state and
        // recoloring there corrupts attribute ranges / caret. Recolor after.
        codeStorage?.hasMarkedText = true
        super.insertText(string, replacementRange: replacementRange)
        codeStorage?.hasMarkedText = false
        recolorNow()
    }

    override func unmarkText() {
        super.unmarkText()
        codeStorage?.hasMarkedText = false
        recolorNow()
    }

    /// Recolor the whole document outside of any editing transaction.
    private func recolorNow() {
        codeStorage?.recolorWholeDocument()
    }

    // NSTextView re-registers file drag types dynamically, so unregisterDraggedTypes()
    // is ignored and drags don't bubble past the scroll view. Handle file drags here:
    // accept + forward URLs to the controller (opens new tabs) instead of inserting
    // the path as text.
    private func isFileDrag(_ sender: NSDraggingInfo) -> Bool {
        let pb = sender.draggingPasteboard
        return pb.canReadItem(withDataConformingToTypes: [NSPasteboard.PasteboardType.fileURL.rawValue])
            || pb.types?.contains(where: { $0.rawValue == "NSFilenamesPboardType" }) == true
    }
    private func droppedURLs(_ sender: NSDraggingInfo) -> [URL] {
        sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] ?? []
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if isFileDrag(sender) { return .copy }
        return super.draggingEntered(sender)
    }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        if isFileDrag(sender) { return .copy }
        return super.draggingUpdated(sender)
    }
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if isFileDrag(sender) { return true }
        return super.prepareForDragOperation(sender)
    }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if isFileDrag(sender) {
            let urls = droppedURLs(sender)
            if !urls.isEmpty { onDropFiles?(urls) }
            return !urls.isEmpty
        }
        return super.performDragOperation(sender)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        // Walk the responder chain to the window controller that owns this tab.
        var r: NSResponder? = self
        while let resp = r {
            if let ctrl = resp as? EditorWindowController {
                ctrl.appearanceDidChange()
                break
            }
            r = resp.nextResponder
        }
    }
}
