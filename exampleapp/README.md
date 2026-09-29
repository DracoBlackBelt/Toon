# Toon Example App

A minimal QML scaffold for the **Toon smart thermostat** (Quby/Eneco). Use this as a starting point when building a new Toon app.

## What's included

| File | Purpose |
|------|---------|
| `ExampleApp.qml` | App root — registers tile, screen, menu, and tray with the Toon shell |
| `ExampleTile.qml` | Home screen tile — shows "test", opens the screen on click |
| `ExampleScreen.qml` | Detail screen stub |
| `ExampleMenu.qml` | Settings menu entry stub |
| `ExampleTray.qml` | System tray icon stub |
| `qmldir` | Module declaration (`apps.example`) |
| `drawables/` | Place your image assets here |
| `lang/` | Place `.qm` translation files here |
| `AGENTS.md` | Canonical instructions for AI coding agents |

## How to use

1. Copy this project.
2. Rename every occurrence of `Example` / `example` to your app name — in file names, QML type names, `qmldir`, and the settings path in `ExampleApp.qml`.
3. Deploy the QML files to the Toon device (no build step required).
4. Restart the Toon GUI or reload the app.

## Platform notes

- **Two hardware variants:** `isNxt == true` is Toon 2 (higher resolution). Always branch on `isNxt` for sizes and positions.
- **Settings** are persisted as JSON to `/mnt/data/tsc/example.userSettings.json` on the device (`FileIO` for reading, `XMLHttpRequest PUT` for writing).
- **Widget registration** happens in `function init()` inside `ExampleApp.qml`, which is called by the Toon `App` base type at startup.
- All HTTP calls use `XMLHttpRequest` directly — there is no `fetch` API on this platform.

## Version

Current version: **1.0.0** — see `Changelog.txt` for release history.
