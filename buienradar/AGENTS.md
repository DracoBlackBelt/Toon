# AGENTS.md

Compact guide for OpenCode sessions. This is the canonical agent file.

## What this is

QML app for the Toon smart thermostat (ToonStore app `apps.buienradar`). Shows Buienradar weather: temperature/wind tile, 2-hour rain tile, sunrise tile, animated radar, station picker, full-text forecast. No build step, no tests, no linter, no CI — do not look for or add them. This directory **does** have its own private `.git` repo (commits are made manually, e.g. before/after releases).

## Deploy / verify

```bash
scp -O -r -oHostKeyAlgorithms=+ssh-rsa *.qml *.js qmldir drawables root@<toon-ip>:/qmf/qml/apps/buienradar/
ssh -oHostKeyAlgorithms=+ssh-rsa root@<toon-ip> killall qt-gui
```

- **This app's device directory is UNVERSIONED** (`buienradar/`, not `buienradar-<version>/`): `BuienradarApp.qml` (`icoonimageDim = BuienradarJS.parseWeatherIdAndText(...)`) loads dim-mode weather icons via the absolute path `file:///qmf/qml/apps/buienradar/drawables/...`, and it is the only app here whose `drawables/` are needed at runtime. Deploying to a versioned dir breaks all dim icons.
- `-O` (no sftp-server on device) and `+ssh-rsa` (old host key) are both required.
- No local way to run QML; verify by careful reading. Pure helpers in `buienradar.js` can be brace-extracted and sanity-checked with `node`.

## Architecture

- `BuienradarApp.qml` — central `App`: all shared state, all HTTP, settings I/O, widget registration (in `function init()`, NOT `Component.onCompleted`). Other .qml files are screens/tiles that read `app.<prop>`.
- Two data loops: `updateBuienradar()` every 10 min (`interval: 600000`) fetches `https://data.buienradar.nl/2.0/feed/json`; `updateRegenkans()` every 5 min (`300000`) fetches `https://graphdata.buienradar.nl/2.0/forecast/geo/RainHistoryForecast?lat=&lon=`. Each fetch is bounded by a one-shot watchdog `Timer` (`buienradarWatchdog`/`regenWatchdog`) that aborts the in-flight XHR (tracked in `p.pendingBuienradar`/`p.pendingRegenkans`) — since `xhr.timeout` is unreliable here.
- Radar images: `https://api.buienradar.nl/image/1.0/RadarMapNL?width=600&height=600` on NXT, `400` on Toon 1 (small tile variants use `180`). Verified 2026-09: this endpoint 301-redirects to `image.buienradar.nl/2.0/image/animation/RadarmapRainNL`, which **ignores `w=`/`h=`** (returns default 550x512, ~128 KB) — always use `width=`/`height=`. Static weather maps (UV/pollen/mosquito/temp/wind) come from `https://processing-cdn.buienradar.nl/processing/nl/weathermaps/<type>/default/<date>.png` — note the temperature/wind maps append an hour: `<date><HH>00.png`, and `<date>` must be the **local** date (`toISOString()` is UTC and shows yesterday's map in the small hours).
- `buienradar.js` — pure utilities incl. `parseWeatherIdAndText()` which picks the dim-mode icon from the `Dim<Condition>.png` files in `drawables/` (only reachable via the absolute path, see Deploy). The non-dim tile icon and screen thumbnails come from the **firmware's** `qrc:/tsc/<weathercode>.png` / `qrc:/tsc/buienradar.png` resources, not from `drawables/` (the `Home*.png` and single-letter icon copies were removed as dead in 9.0.12).

## Platform rules (apply to every file here)

- **ES5 only** — Qt5 JavaScriptCore: `var`, no `let`/`const`, no arrow functions, no template strings, no ES6 methods.
- **No fetch API** — all HTTP and file writes via `XMLHttpRequest`. `timeout` support on the device is unreliable: bound long fetches with `Timer`s.
- Settings read via `FileIO` from `/mnt/data/tsc/buienradar.userSettings.json`, written via XHR PUT to the same path. Defaults in code only apply to devices with no valid settings file.
- Sizes/margins branch on `isNxt` (true = Toon 2/NXT, false = Toon 1); colors: `(typeof dimmableColors !== 'undefined') ? dimmableColors.X : colors.X`.
- UI strings are Dutch, wrapped in `qsTr()`; `lang/*.qm` are compiled translations.

## Gotchas

- The app also writes the current temperature to `/var/volatile/tmp/actualBuienradarTemp.txt` for the external TemperatureLogger app — don't remove or rename that side effect.
- Radar image URLs must use `width=`/`height=`; the backend (which the old endpoint 301-redirects to) silently ignores `w=`/`h=` and serves the full-size animation (fixed across all files in 9.0.12).
- UI strings are now wrapped in `qsTr()` (9.0.12), but `lang/*.qm` cannot be recompiled locally — strings added/changed after the last ToonStore packaging show untranslated (Dutch source) until the catalogs are rebuilt.
- `EditTextLabel4421.qml` is a shared input-widget copy (also in calender/sonos); changes may need mirroring, not deduping.

## Releases

Bump `version.txt` (single line, e.g. `9.0.11`) and prepend a brief block to `Changelog.txt` together when changing behavior.
