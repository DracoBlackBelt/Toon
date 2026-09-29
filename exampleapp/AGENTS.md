# AGENTS.md

Compact guide for OpenCode sessions. This is the canonical agent file.

## What this is

A minimal QML scaffold for the Toon smart thermostat (module `apps.example`) to copy as the starting point for any new Toon app. Shows "test" on a tile; everything else is `// TODO` stubs wired the way the platform expects. No build step, no tests, no linter, no CI, not a git repo — do not look for or add them.

## Copy-me checklist

1. Copy the folder, rename files: `Example*` → `<YourApp>*`.
2. Update `qmldir`: module `apps.example` → `apps.<yourapp>`, type names.
3. Rename type/property references inside the QML (`ExampleApp`, `exampleScreen`, `exampleMenu`, `exampleTray`, objectNames).
4. Change the settings path stub to `/mnt/data/tsc/<yourapp>.userSettings.json`.
5. `thumbnailIcon` points at `qrc:/tsc/ExampleThumb.png` — a placeholder in the device's installed resources; switch to the commented-out `drawables/` path during development (relative paths resolve inside the install dir, so deploy `drawables/` with the app).

## Deploy / verify

```bash
scp -O -r -oHostKeyAlgorithms=+ssh-rsa *.qml qmldir drawables root@<toon-ip>:/qmf/qml/apps/<yourapp>-<version>/
ssh -oHostKeyAlgorithms=+ssh-rsa root@<toon-ip> killall qt-gui
```

`-O` (no sftp-server on device) and `+ssh-rsa` (old host key) are both required. No local way to run QML; verify by careful reading.

## Wiring the scaffold already gets right

- All `registry.registerWidget(...)` calls (tile, screen, menuItem, systrayIcon with per-widget option maps) live in `function init()`, called by the Toon `App` base type — NOT `Component.onCompleted` (which is reserved for the settings-read TODO).
- `ExampleTile` demonstrates the sizing/color idiom: `isNxt ? 22 : 18` and `(typeof dimmableColors !== 'undefined') ? dimmableColors.clockTileColor : colors.clockTileColor`.
- Screens open via `app.exampleScreen.show()` with a null guard (`if (app && app.exampleScreen)`).
- Settings pattern for real apps: read via `FileIO` from `/mnt/data/tsc/<app>.userSettings.json`, write via XHR PUT to the same path; see `sonos/SonosApp.qml` for the reference implementation.

## Platform rules (apply to every file)

- **ES5 only** — Qt5 JavaScriptCore: `var`, no `let`/`const`, no arrow functions, no template strings, no ES6 methods.
- **No fetch API** — all HTTP and file writes via `XMLHttpRequest`; `timeout` support is unreliable, bound long fetches with `Timer`s.
- UI strings are Dutch, wrapped in `qsTr()`; `lang/` holds compiled `.qm` files.

## Conventions

- Bump `version.txt` and prepend a block to `Changelog.txt` together when changing behavior.
- `docs/superpowers/` holds the original (dated) design spec and implementation plan for this scaffold; they've been corrected to match the shipped code.
