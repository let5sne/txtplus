# TxtPlus

A Notepad++ style native macOS editor. AppKit only — no Electron, no Xcode project. Built straight with `swiftc` into `build/TxtPlus.app`.

## Build

```bash
./build.sh        # compiles Sources/*.swift -> build/TxtPlus.app, ad-hoc signs bundle
open build/TxtPlus.app
```

- Swift 6 / macOS 11+. No dependencies.
- No Xcode project, no SPM — `build.sh` calls `swiftc` directly.
- Ad-hoc signed; `codesign --deep` seals the bundle (helps the IMK input-method connection for CJK input).

## Release (tag-driven)

Bump `Info.plist` (`CFBundleShortVersionString` + `CFBundleVersion`), then:

```bash
git tag v1.1.0 && git push origin v1.1.0
```

`.github/workflows/release.yml` re-signs with Developer ID, notarizes the app + DMG, staples, and attaches `TxtPlus-<version>.dmg` to the GitHub release. Signing secrets (`MAC_CERTIFICATE_P12`, `MAC_CERTIFICATE_PASSWORD`, `APPLE_ID`, `APPLE_ID_PASSWORD`, `APPLE_TEAM_ID`) are already set in repo settings — don't add manual build/upload steps. `ci.yml` builds every push/PR.

## Architecture (what to know before editing)

- **`CodeTextStorage`** (NSTextStorage subclass) owns the backing `NSMutableAttributedString` and recolors on edit via `processEditing()`.
- **`CodeTextView`** (NSTextView subclass) coordinates IME and drag, because both interact with the storage's recolor path.
- **`SyntaxHighlighter`** paints tokens by regex into the storage's attributed string.
- **`EditorWindowController`** owns tabs (`Tab` = storage + textView + scrollView + ruler) and all menu actions.
- Highlighting recolors whole-doc below 200k chars, per-line above.

## Known traps (will bite again if ignored)

- **IME recolor timing** — recoloring must NOT run inside an editing transaction. During IME commit/unmark, keep `hasMarkedText = true` so `processEditing` skips; recolor after via `CodeTextStorage.recolorWholeDocument()`. Breaking this makes committed CJK text invisible. Detail: see agent memory `ime-marked-text-recolor`.
- **File drag handling** — handle file drops in `CodeTextView`'s drag overrides (`onDropFiles` callback → `openURL`), NOT a parent/sibling view. `unregisterDraggedTypes()` is ignored by NSTextView (dynamic `acceptableDragTypes`) and drags don't bubble past NSScrollView. Detail: see agent memory `nstextview-file-drag-trap`.
- **Text view must be vertically resizable** — `CodeTextView` sets `isVerticallyResizable = true`, else it collapses to 0 height in the scroll view (nothing renders, nothing editable).
- **Autosave clean-quit invariant** — `Autosave` keeps crash-recovery snapshots of dirty tabs; recovery at launch means "a snapshot survived" = "last run crashed". So EVERY clean exit path must clear them: `applicationWillTerminate` and `windowWillClose` both call `Autosave.clearAll()`. Adding a new quit/close path without clearing makes the app "recover" content the user already discarded.

## Adding a syntax language

Add a `LangRule` to `Languages.all` in `Sources/Theme.swift` (name, extensions, keyword regex, line/block comments, string regexes). Auto-detected by extension on open/save.
