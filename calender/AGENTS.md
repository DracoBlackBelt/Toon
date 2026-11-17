# AGENTS.md

Canonical agent guide for this app.

## What this is

QML app for the Toon smart thermostat (ToonStore app `apps.calendar`). Displays ICS calendar events on the home tile and a full-screen list. No build step, no tests, no linter, no CI — do not look for or add them.

## Deploy / verify

```bash
scp -O -oHostKeyAlgorithms=+ssh-rsa *.qml *.js qmldir root@<toon-ip>:/qmf/qml/apps/calendar-<version>/
```

(`<version>` = `version.txt`, e.g. `calendar-1.2.1-jh1`; this is the only app in the workspace with a versioned device dir — `buienradar/` is unversioned. `-O` is required — no sftp-server on device — and so is `+ssh-rsa` for the old host key.) Then restart the GUI over ssh: `ssh -oHostKeyAlgorithms=+ssh-rsa root@<toon-ip>` + `killall qt-gui`. There is no local way to run or test the app; verification is by reading code carefully. Exception: the pure helpers (`calendarWorker.js`, `clampRefreshInterval`, …) are engine-agnostic JS — they can be brace-extracted from the QML and regression-tested with `node`, which is the only real execution verification available.

## Device state beats code state

- The `calendarSettingsJson` defaults in `CalendarApp.qml` only take effect on a device that has no valid `/mnt/data/tsc/calendar.userSettings.json`. Editing default `Calendar_URL` entries does NOT reach already-configured devices — change the device file instead.
- The settings screen can only add/remove calendars from the public index (`https://raw.githubusercontent.com/ToonSoftwareCollective/calendar_public_calendars/main/public_calendars.json`, shape `{ public_calendars: [ { friendlyName, link } ] }`); there is no free-form URL input. Arbitrary URLs must be edited into the device JSON directly.
- Settings keys in `/mnt/data/tsc/calendar.userSettings.json`: `ShowNotifications`, `ShowColors`, `ShowAnimation`, `DimTileExtended`, `RefreshIntervalInMinutes`, `Calendar_URL` (array of ICS URLs).
- Base is upstream ToonSoftwareCollective/calendar 1.2.1 (rewrite) plus a few fork edits (version `1.2.1-jh1`). The old 1.1.x fork fixes for BYDAY freeze, VALARM and missing SUMMARY are superseded by the new parser in `calendarWorker.js`; do not reintroduce them.

## Non-obvious code facts

- `CalendarApp.qml` (~540 lines) holds fetching (XHR per calendar, `fetchSeq` stamp drops stale replies, 90 s `fetchTimeoutTimer`), settings, timers and tile/notification logic. ICS parsing and recurrence expansion live in `calendarWorker.js` (run in a `WorkerScript`; `workerWatchdog` falls back to calling it in the GUI thread). The worker returns structured event objects (`start`, `end`, `title`, `date`, `time`, `alarm`, ...) in `app.calendarEvents`; there are no fixed-format string offsets any more. Any parser fix goes in `calendarWorker.js`. Other QML: `CalendarTile.qml`, `CalendarListDatesScreen(.Delegate).qml` (paginated list, 16/page, self-refreshes), `CalendarConfigurationScreen(.Delegate).qml` (settings), `calendar.js` (stub), `EditTextLabel4421.qml` (shared input-widget copy — mirror changes, don't dedupe).
- Widget registration goes in `function init()`, NOT `Component.onCompleted`.
- Colors must use `(typeof dimmableColors !== 'undefined') ? dimmableColors.X : colors.X` for dim mode; sizes/margins branch on `isNxt` (true = Toon 2/NXT, false = Toon 1). Never hardcode a single value for both platforms.
- All HTTP is `XMLHttpRequest` — the platform has no fetch API, and this old Qt5 build has no `XMLHttpRequest.timeout` (fetch-cycle bounding is done by `fetchTimeoutTimer`). Settings read via `FileIO` (through the guarded `readSettings()`), written via XHR PUT to `/mnt/data/tsc/calendar.userSettings.json`.
- The device runs Qt5's JavaScriptCore: write ES5 only — `var`, no `let`/`const`, no arrow functions, no template strings, no ES6 string/array methods.
- Refresh: 10–99 min enforced in the settings UI and `clampRefreshInterval()`; `endFirstAppointmentTimer` has a 5-minute floor; default 60.
- `drawables/` and `lang/` (only compiled `.qm`, no `.ts`) are not referenced by QML at runtime (icons use `qrc:` paths).

## Conventions

- UI strings are Dutch (translated via `qsTr` + compiled `lang/*.qm`).
- Version lives in `version.txt`; update it and `Changelog.txt` when changing behavior.
