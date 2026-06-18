import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var windowController: EditorWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = buildMenu()
        let wc = EditorWindowController()
        wc.showWindow(nil)
        // Open one empty tab so the window isn't blank.
        wc.newTab(self)
        windowController = wc
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationOpenFile(_ sender: NSApplication, filename: String) -> Bool {
        windowController?.openURL(URL(fileURLWithPath: filename))
        return true
    }

    // MARK: - Menu

    private func buildMenu() -> NSMenu {
        let main = NSMenu()
        main.addItem(appItem())
        main.addItem(fileItem())
        main.addItem(editItem())
        main.addItem(viewItem())
        return main
    }

    private func appItem() -> NSMenuItem {
        let item = NSMenuItem()
        item.submenu = NSMenu(title: "TxtPlus")
        item.submenu?.addItem(withTitle: "About TxtPlus", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        item.submenu?.addItem(NSMenuItem.separator())
        item.submenu?.addItem(withTitle: "Hide TxtPlus", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        item.submenu?.addItem(withTitle: "Quit TxtPlus", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return item
    }

    private func fileItem() -> NSMenuItem {
        let item = NSMenuItem()
        item.submenu = NSMenu(title: "File")
        item.submenu?.addItem(withTitle: "New Tab", action: #selector(EditorWindowController.newTab(_:)), keyEquivalent: "n")
        item.submenu?.addItem(withTitle: "Open…", action: #selector(EditorWindowController.openDocument(_:)), keyEquivalent: "o")
        item.submenu?.addItem(NSMenuItem.separator())
        item.submenu?.addItem(withTitle: "Save", action: #selector(EditorWindowController.saveDocument(_:)), keyEquivalent: "s")
        item.submenu?.addItem(withTitle: "Save As…", action: #selector(EditorWindowController.saveDocumentAs(_:)), keyEquivalent: "S")
        item.submenu?.addItem(NSMenuItem.separator())
        item.submenu?.addItem(withTitle: "Close Tab", action: #selector(EditorWindowController.closeCurrentTab(_:)), keyEquivalent: "w")
        return item
    }

    private func editItem() -> NSMenuItem {
        let item = NSMenuItem()
        item.submenu = NSMenu(title: "Edit")
        item.submenu?.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        item.submenu?.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        item.submenu?.addItem(NSMenuItem.separator())
        item.submenu?.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        item.submenu?.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        item.submenu?.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        item.submenu?.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        item.submenu?.addItem(NSMenuItem.separator())
        // NSTextView handles performFindPanelAction: via the responder chain.
        item.submenu?.addItem(withTitle: "Find…", action: Selector(("performFindPanelAction:")), keyEquivalent: "f").tagged(1)
        item.submenu?.addItem(withTitle: "Find Next", action: Selector(("performFindPanelAction:")), keyEquivalent: "g").tagged(2)
        item.submenu?.addItem(withTitle: "Find Previous", action: Selector(("performFindPanelAction:")), keyEquivalent: "G").tagged(3)
        item.submenu?.addItem(NSMenuItem.separator())
        item.submenu?.addItem(withTitle: "Go to Line…", action: #selector(EditorWindowController.goToLine(_:)), keyEquivalent: "l")
        return item
    }

    private func viewItem() -> NSMenuItem {
        let item = NSMenuItem()
        item.submenu = NSMenu(title: "View")
        item.submenu?.addItem(withTitle: "Bigger Font", action: #selector(EditorWindowController.biggerFont(_:)), keyEquivalent: "+")
        item.submenu?.addItem(withTitle: "Smaller Font", action: #selector(EditorWindowController.smallerFont(_:)), keyEquivalent: "-")
        item.submenu?.addItem(NSMenuItem.separator())
        item.submenu?.addItem(withTitle: "Toggle Word Wrap", action: #selector(EditorWindowController.toggleWrap(_:)), keyEquivalent: "")
        return item
    }
}

private extension NSMenuItem {
    @discardableResult
    func tagged(_ t: Int) -> NSMenuItem {
        self.tag = t
        return self
    }
}
