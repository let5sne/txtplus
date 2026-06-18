import AppKit

// ponytail: manual bootstrap instead of @main/Info.plist NSPrincipalClass —
// fewer moving parts for a CLI-built .app.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
