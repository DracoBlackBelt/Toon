# Example Toon App — Design Spec

**Date:** 2026-05-21
**Status:** Approved

## Goal

A minimal but complete scaffold for a Toon QML app. Displays the word "test" on a home screen tile. All standard Toon app wiring is in place so a developer can start adding real functionality without any setup work.

## File Layout

```
example/
├── qmldir
├── ExampleApp.qml         # App root — state, registration
├── ExampleTile.qml        # Home screen tile — shows "test"
├── ExampleScreen.qml      # Detail screen — empty stub
├── ExampleMenu.qml        # Menu entry — empty stub
├── ExampleTray.qml        # System tray icon — empty stub
├── drawables/             # Images (empty)
├── lang/                  # Translation files (empty)
├── version.txt            # 1.0.0
└── Changelog.txt
```

## Architecture

`ExampleApp.qml` is the central `App` object. It owns all URL properties pointing at the other QML files, typed screen properties, and registers every widget with the Toon `registry` in `function init()` (called by the `App` base type — NOT in `Component.onCompleted`, which is reserved for a settings-read stub). It has `// TODO` stubs for state properties, timers, and API functions.

The module is `apps.example`. `qmldir` exports `ExampleApp` and `ExampleScreen`.

## Components

### ExampleApp.qml
- Extends `App`
- Properties: `tileUrl`, `menuUrl`, `trayUrl`, `screenUrl`, `thumbnailIcon` (`qrc:/tsc/ExampleThumb.png`, with a commented-out `drawables/` alternative for development), typed screen property
- `function init()`: registers tile, screen, menu, tray via `registry`
- `Component.onCompleted`: settings-read stub comment only
- Stub comments: state properties, timers, helper functions, settings read/write

### ExampleTile.qml
- Extends `Tile`
- Centered `Text { text: "test" }` with `isNxt`-aware pixel size (22px NXT / 18px Toon 1)
- `onClicked`: opens `ExampleScreen` via `app.exampleScreen.show()`
- Works in both normal and `dimState` (same text, dimmed color)

### ExampleScreen.qml
- Extends `Screen`
- Empty content with `// TODO` stub

### ExampleMenu.qml
- Extends the Toon menu base type
- Empty body with `// TODO` stub

### ExampleTray.qml
- Extends `SystrayIcon`
- Empty body with `// TODO` stub

## Conventions Followed

- `isNxt` used for all size/position values — never hardcoded for one device
- Module namespace: `apps.example`
- Settings would go to `/mnt/data/tsc/example.userSettings.json` (stub comment only)
- `version.txt` + `Changelog.txt` present and populated

## Out of Scope

- No HTTP calls, timers, or state — those are left as stubs
- No drawables or translations — folders exist but are empty
- No settings persistence — stub comment only
