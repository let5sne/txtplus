# TxtPlus — a Notepad++ style macOS editor

Native AppKit (no Electron, no Xcode project). Tabs, line-number gutter, syntax
highlighting, find bar, status bar. Compiled straight with `swiftc` into a `.app`.

## Build & run

```bash
./build.sh
open build/TxtPlus.app
```

Requires Swift 6 / macOS 11+. No external dependencies.

## Features

- **Tabs** — open multiple files; click to switch, hover × to close. `Cmd+N` new tab, `Cmd+W` close.
- **Drag to open** — drag files onto the editor to open them as new tabs.
- **Line numbers** — gutter aligned to text layout, drawn via a custom `NSRulerView`.
- **Syntax highlighting** — regex-based, per-language: Swift, JS/TS, Python, JSON, HTML/XML, Markdown. Auto-detected by extension.
- **Find/Replace** — `Cmd+F` (NSTextView find bar), `Cmd+G` / `Cmd+Shift+G` next/prev.
- **Status bar** — language, char count, Ln/Col, selection size.
- **Go to Line** — `Cmd+L`.
- **Font / wrap** — `Cmd+±` font size, View → Toggle Word Wrap.
- **Dark mode** — colors follow the system appearance (light/dark).
- **CJK input** — IME composition works; recoloring is paused during composition and applied on commit.
- **Window persistence** — last window position/size is restored on next launch.

## Structure

| File | Role |
|------|------|
| `Sources/main.swift` | NSApplication bootstrap |
| `Sources/AppDelegate.swift` | Menu bar |
| `Sources/EditorWindowController.swift` | Window, tabs, layout, all actions |
| `Sources/TabBar.swift` | Custom tab strip |
| `Sources/CodeTextView.swift` | NSTextView subclass (IME + drag coordination) |
| `Sources/CodeTextStorage.swift` | NSTextStorage subclass + recolor hook |
| `Sources/SyntaxHighlighter.swift` | Regex token painter |
| `Sources/LineNumberRuler.swift` | Gutter |
| `Sources/StatusBar.swift` | Bottom status bar |
| `Sources/Theme.swift` | Colors, fonts, language definitions |

## Notes

- Highlighting recolors the whole document below 200k chars, per-line above.
- Plain-text mode (`isRichText = false`); recoloring is paused during IME composition and re-applied after commit (see `CodeTextView.recolorNow`).
- File drags are handled in `CodeTextView`'s drag overrides (not a parent view) — see `CLAUDE.md` known traps.
