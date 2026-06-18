import AppKit

final class Tab {
    var id = UUID()
    var fileURL: URL?
    var displayName: String
    let storage: CodeTextStorage
    let textView: CodeTextView
    let scrollView: NSScrollView
    let ruler: LineNumberRuler
    var isDirty: Bool = false
    var encoding: String.Encoding = .utf8

    init(displayName: String) {
        self.displayName = displayName
        self.storage = CodeTextStorage()
        self.textView = CodeTextView(storage: storage)
        self.scrollView = NSScrollView()
        self.ruler = LineNumberRuler(textView: textView)
        textView.delegate = nil // set by controller
    }
}

final class EditorWindowController: NSWindowController, NSWindowDelegate, NSTextViewDelegate, TabBarDelegate {

    private var tabs: [Tab] = []
    private var selectedIndex: Int = 0
    private var untitledCounter = 0

    private let tabBar = TabBar()
    private let editorHost = NSView()
    private let statusBar = StatusBar()
    private var autosaveTimer: Timer?

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        window.title = "TxtPlus"
        window.center()
        window.minSize = NSSize(width: 480, height: 320)
        // Native frame persistence: restores last position/size on next launch.
        window.setFrameAutosaveName("TxtPlusWindow")
        self.init(window: window)
        window.delegate = self
        tabBar.delegate = self
        buildUI()
        startAutosaveTimer()
    }

    // MARK: - Autosave (crash recovery)

    private func startAutosaveTimer() {
        // ponytail: 5s poll, flushes dirty tabs. Fine for a text editor; no need
        // for change-debounced writes until someone edits a huge file and notices.
        autosaveTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.flushAutosave()
        }
    }

    func flushAutosave() {
        for tab in tabs where tab.isDirty {
            Autosave.write(Autosave.Record(
                id: tab.id,
                name: tab.displayName,
                urlPath: tab.fileURL?.path,
                content: tab.textView.string))
        }
    }

    /// Rebuild tabs from snapshots left by a previous crashed run. Returns true if
    /// anything was recovered. Call before the first `newTab`.
    @discardableResult
    func recoverIfNeeded() -> Bool {
        let records = Autosave.scan()
        guard !records.isEmpty else { return false }
        for record in records {
            let tab = Tab(displayName: record.name)
            tab.id = record.id   // keep the snapshot's id so flush overwrites it
            if let path = record.urlPath {
                let url = URL(fileURLWithPath: path)
                tab.fileURL = url
                tab.storage.language = Languages.detect(url.pathExtension)
            }
            wireTextView(tab.textView)
            wireScrollView(tab)
            tab.storage.setString(record.content)
            tab.isDirty = true   // unsaved by definition — force the user to re-save
            tabs.append(tab)
        }
        tabBar.tabs = tabs.map { TabModel(title: $0.displayName, dirty: $0.isDirty) }
        select(0)
        return true
    }

    private func wireTextView(_ tv: CodeTextView) {
        tv.delegate = self
        tv.onDropFiles = { [weak self] urls in
            for url in urls { self?.openURL(url) }
        }
    }

    private func buildUI() {
        guard let window = window, let content = window.contentView else { return }
        for v in [tabBar, editorHost, statusBar] {
            v.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(v)
        }
        NSLayoutConstraint.activate([
            tabBar.topAnchor.constraint(equalTo: content.topAnchor),
            tabBar.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            tabBar.heightAnchor.constraint(equalToConstant: 28),

            editorHost.topAnchor.constraint(equalTo: tabBar.bottomAnchor),
            editorHost.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            editorHost.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            editorHost.bottomAnchor.constraint(equalTo: statusBar.topAnchor),

            statusBar.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            statusBar.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            statusBar.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
    }

    /// Called by CodeTextView when the effective appearance flips (light/dark).
    func appearanceDidChange() {
        for tab in tabs {
            tab.textView.refont()
            tab.ruler.needsDisplay = true
            tab.textView.needsDisplay = true
        }
        tabBar.needsDisplay = true
        statusBar.needsDisplay = true
    }

    // MARK: - Tab lifecycle

    @objc func newTab(_ sender: Any?) {
        untitledCounter += 1
        let tab = Tab(displayName: "Untitled \(untitledCounter)")
        wireTextView(tab.textView)
        wireScrollView(tab)
        tabs.append(tab)
        tabBar.tabs = tabs.map { TabModel(title: $0.displayName, dirty: $0.isDirty) }
        select(tabs.count - 1)
    }

    private func wireScrollView(_ tab: Tab) {
        let sv = tab.scrollView
        sv.hasVerticalScroller = true
        sv.hasHorizontalRuler = false
        sv.hasVerticalRuler = true
        sv.rulersVisible = true
        sv.autohidesScrollers = true
        sv.borderType = .noBorder
        sv.verticalRulerView = tab.ruler
        sv.documentView = tab.textView

        // Redraw gutter on scroll.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clipBoundsChanged(_:)),
            name: NSView.boundsDidChangeNotification,
            object: sv.contentView)
    }

    @objc private func clipBoundsChanged(_ note: Notification) {
        guard let clip = note.object as? NSView,
              let sv = clip.enclosingScrollView,
              let tab = tabs.first(where: { $0.scrollView === sv }) else { return }
        tab.ruler.needsDisplay = true
    }

    func select(_ index: Int) {
        guard tabs.indices.contains(index) else { return }
        selectedIndex = index
        let tab = tabs[index]
        // Swap the editor into the host.
        editorHost.subviews.forEach { $0.removeFromSuperview() }
        editorHost.addSubview(tab.scrollView)
        tab.scrollView.frame = editorHost.bounds
        tab.scrollView.autoresizingMask = [.width, .height]
        tabBar.selectedIndex = index
        window?.title = "\(tab.displayName)\(tab.isDirty ? " — Edited" : "") — TxtPlus"
        window?.makeFirstResponder(tab.textView)
        tab.ruler.needsDisplay = true
        updateStatus(for: tab)
    }

    func tabBar(_ bar: TabBar, didSelect index: Int) {
        select(index)
    }

    func tabBar(_ bar: TabBar, didClose index: Int) {
        closeTab(at: index)
    }

    private func closeTab(at index: Int) {
        guard tabs.indices.contains(index) else { return }
        let tab = tabs[index]
        if tab.isDirty {
            let alert = NSAlert()
            alert.messageText = "Close \"\(tab.displayName)\"?"
            alert.informativeText = "Your changes will be lost."
            alert.addButton(withTitle: "Close Anyway")
            alert.addButton(withTitle: "Cancel")
            if alert.runModal() == .alertSecondButtonReturn { return }
        }
        tabs.remove(at: index)
        Autosave.remove(tab.id)   // discarded → drop its recovery snapshot
        tabBar.tabs = tabs.map { TabModel(title: $0.displayName, dirty: $0.isDirty) }
        if tabs.isEmpty {
            newTab(self)
            return
        }
        let newIndex = min(index, tabs.count - 1)
        select(newIndex)
    }

    @objc func closeCurrentTab(_ sender: Any?) {
        closeTab(at: selectedIndex)
    }

    // MARK: - Open / Save

    @objc func openDocument(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        if panel.runModal() == .OK {
            for url in panel.urls { openURL(url) }
        }
    }

    func openURL(_ url: URL) {
        if let existing = tabs.firstIndex(where: { $0.fileURL == url }) {
            select(existing)
            return
        }
        guard let data = try? Data(contentsOf: url) else {
            NSSound.beep()
            return
        }
        var usedEncoding: String.Encoding = .utf8
        var text = String(data: data, encoding: .utf8)
        if text == nil {
            // Not UTF-8. Fall back to Latin-1 (lossless byte→char) but warn so the
            // user knows the original encoding wasn't recognized and a re-save will
            // rewrite it as UTF-8.
            text = String(data: data, encoding: .isoLatin1)
            usedEncoding = .isoLatin1
            let alert = NSAlert()
            alert.messageText = "Couldn't decode \"\(url.lastPathComponent)\" as UTF-8"
            alert.informativeText = "Opened with Latin-1 fallback. Saving will rewrite the file as UTF-8."
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
        guard let text else {
            NSSound.beep()
            return
        }
        let tab = Tab(displayName: url.lastPathComponent)
        tab.fileURL = url
        tab.encoding = usedEncoding
        wireTextView(tab.textView)
        wireScrollView(tab)
        let ext = url.pathExtension
        tab.storage.language = Languages.detect(ext)
        tab.storage.setString(text)
        tab.isDirty = false
        tabs.append(tab)
        tabBar.tabs = tabs.map { TabModel(title: $0.displayName, dirty: $0.isDirty) }
        select(tabs.count - 1)
    }

    @objc func saveDocument(_ sender: Any?) {
        guard tabs.indices.contains(selectedIndex) else { return }
        let tab = tabs[selectedIndex]
        guard let url = tab.fileURL else { saveDocumentAs(sender); return }
        write(tab: tab, to: url)
    }

    @objc func saveDocumentAs(_ sender: Any?) {
        guard tabs.indices.contains(selectedIndex) else { return }
        let tab = tabs[selectedIndex]
        let panel = NSSavePanel()
        panel.nameFieldStringValue = tab.displayName
        if panel.runModal() == .OK, let url = panel.url {
            write(tab: tab, to: url)
        }
    }

    private func write(tab: Tab, to url: URL) {
        let text = tab.textView.string
        // Write back in the file's original encoding when the content still fits it;
        // otherwise fall back to UTF-8 (e.g. a Latin-1 file that now has CJK text).
        var encoding = tab.encoding
        var data = text.data(using: encoding)
        if data == nil {
            encoding = .utf8
            data = text.data(using: .utf8)
        }
        guard let data else { NSSound.beep(); return }
        do {
            try data.write(to: url, options: .atomic)
            tab.fileURL = url
            tab.encoding = encoding
            tab.displayName = url.lastPathComponent
            tab.isDirty = false
            Autosave.remove(tab.id)   // saved → no longer needs recovery
            tab.storage.language = Languages.detect(url.pathExtension) ?? tab.storage.language
            tabBar.tabs = tabs.map { TabModel(title: $0.displayName, dirty: $0.isDirty) }
            window?.title = "\(tab.displayName) — TxtPlus"
            updateStatus(for: tab)
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }

    // MARK: - Edit actions

    @objc func goToLine(_ sender: Any?) {
        guard tabs.indices.contains(selectedIndex) else { return }
        let tab = tabs[selectedIndex]
        let alert = NSAlert()
        alert.messageText = "Go to Line"
        alert.addButton(withTitle: "Go")
        alert.addButton(withTitle: "Cancel")
        let field = NSTextField(string: "1")
        alert.accessoryView = field
        if alert.runModal() == .alertFirstButtonReturn, let n = Int(field.stringValue) {
            let ns = tab.textView.string as NSString
            let line = max(1, min(n, ns.components(separatedBy: "\n").count))
            var index = 0
            for _ in 0..<(line - 1) {
                index = ns.lineRange(for: NSRange(location: index, length: 0)).upperBound
            }
            tab.textView.setSelectedRange(NSRange(location: index, length: 0))
            tab.textView.scrollRangeToVisible(NSRange(location: index, length: 0))
            window?.makeFirstResponder(tab.textView)
        }
    }

    @objc func biggerFont(_ sender: Any?) {
        Prefs.fontSize = min(40, Prefs.fontSize + 1)
        refontAll()
    }

    @objc func smallerFont(_ sender: Any?) {
        Prefs.fontSize = max(8, Prefs.fontSize - 1)
        refontAll()
    }

    @objc func toggleWrap(_ sender: Any?) {
        Prefs.wraps.toggle()
        tabs.forEach { $0.textView.applyWrap() }
    }

    private func refontAll() {
        for tab in tabs {
            tab.textView.refont()
            tab.ruler.needsDisplay = true
        }
        updateStatus(for: tabs[selectedIndex])
    }

    // MARK: - NSTextViewDelegate

    func textDidChange(_ notification: Notification) {
        guard let tv = notification.object as? CodeTextView,
              let tab = tabs.first(where: { $0.textView === tv }) else { return }
        if !tab.isDirty {
            tab.isDirty = true
            tabBar.tabs = tabs.map { TabModel(title: $0.displayName, dirty: $0.isDirty) }
            window?.title = "\(tab.displayName) — Edited — TxtPlus"
        }
        tab.ruler.needsDisplay = true
        updateStatus(for: tab)
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        guard let tv = notification.object as? CodeTextView,
              let tab = tabs.first(where: { $0.textView === tv }) else { return }
        if tabs.firstIndex(where: { $0.textView === tv }) == selectedIndex {
            updateStatus(for: tab)
        }
    }

    private func updateStatus(for tab: Tab) {
        let tv = tab.textView
        let ns = tv.string as NSString
        let sel = tv.selectedRange()
        let caret = max(0, min(sel.location, ns.length))
        let lineRange = ns.lineRange(for: NSRange(location: caret, length: 0))
        let lineNum = ns.substring(to: caret).components(separatedBy: "\n").count
        let col = caret - lineRange.location + 1
        let lang = tab.storage.language?.name ?? "Plain Text"
        let selected = sel.length
        statusBar.update(line: lineNum, column: col, language: lang, chars: ns.length, selection: selected)
    }

    // MARK: - Window delegate

    func windowDidResize(_ notification: Notification) {
        for tab in tabs where tab.scrollView.superview != nil {
            tab.scrollView.frame = editorHost.bounds
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        let dirty = dirtyTabs()
        guard !dirty.isEmpty else { return true }

        let alert = NSAlert()
        alert.messageText = "Close window?"
        if dirty.count == 1 {
            alert.informativeText = "\"\(dirty[0].displayName)\" has unsaved changes."
        } else {
            alert.informativeText = "\(dirty.count) tabs have unsaved changes."
        }
        alert.addButton(withTitle: "Close Anyway")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    func windowWillClose(_ notification: Notification) {
        autosaveTimer?.invalidate()
        // User dismissed the window (confirming any unsaved loss). Drop snapshots
        // so a later crash doesn't "recover" content they chose to discard.
        Autosave.clearAll()
        NotificationCenter.default.removeObserver(self)
    }

    func dirtyTabs() -> [Tab] {
        tabs.filter { $0.isDirty }
    }
}