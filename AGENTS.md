# AGENTS.md

Compact guide for OpenCode sessions. This is the canonical agent file.

## What this is

QML app for the Toon smart thermostat (ToonStore app `apps.calendar`). Displays ICS calendar events on the home tile and a full-screen list. No build step, no tests, no linter, no CI — do not look for or add them.

## Deploy / verify

```bash
scp -O -oHostKeyAlgorithms=+ssh-rsa *.qml *.js qmldir root@<toon-ip>:/qmf/qml/apps/calendar-<version>/
```

(`<version>` = `version.txt`, e.g. `calendar-1.1.17`; this is the only app in the workspace with a versioned device dir — `buienradar/` is unversioned. `-O` is required — no sftp-server on device — and so is `+ssh-rsa` for the old host key.) Then restart the GUI over ssh: `ssh -oHostKeyAlgorithms=+ssh-rsa root@<toon-ip>` + `killall qt-gui`. There is no local way to run or test the app; verification is by reading code carefully. Exception: the pure helpers (`convertDateToLocale`, `calcAlarmOffsetInMs`, `dayNumbers`, …) are engine-agnostic JS — they can be brace-extracted from the QML and regression-tested with `node`, which is the only real execution verification available.

## Device state beats code state

- The `calendarSettingsJson` defaults in `CalendarApp.qml` only take effect on a device that has no valid `/mnt/data/tsc/calendar.userSettings.json`. Editing default `Calendar_URL` entries does NOT reach already-configured devices — change the device file instead.
- The settings screen can only add/remove calendars from the public index (`https://raw.githubusercontent.com/ToonSoftwareCollective/calendar_public_calendars/main/public_calendars.json`, shape `{ public_calendars: [ { friendlyName, link } ] }`); there is no free-form URL input. Arbitrary URLs must be edited into the device JSON directly.
- Settings keys in `/mnt/data/tsc/calendar.userSettings.json`: `ShowNotifications`, `ShowColors`, `ShowAnimation`, `DimTileExtended`, `RefreshIntervalInMinutes`, `Calendar_URL` (array of ICS URLs).
- `Calendar_URL` entries whose feed contains weekday rules with ordinal BYDAY prefixes (`BYDAY=1MO`, "first Monday") were a known freeze source — recurrence loops are now capped, but treat RRULE parsing changes as high-risk (see the `recGuard` caps in `convertDateToLocale`).

## Non-obvious code facts

- `CalendarApp.qml` (~1000 lines) holds ALL fetching, ICS parsing, recurrence logic, timers, and settings. The other QML files are pure UI: `CalendarTile.qml` (3 next appointments), `CalendarListDatesScreen(.Delegate).qml` (paginated list, 16/page, 2 columns), `CalendarConfigurationScreen(.Delegate).qml` (settings), `calendar.js` (only wraps `Array.sort()` for QML import), `EditTextLabel4421.qml` (shared input-widget copy — mirror changes, don't dedupe).
- ICS parsing uses raw string indexing — no DOM, no regex. `calendarDatesString` entries are fixed-format lines; consumers use hardcoded offsets (`slice(57)` for title, `0–9`/`11–15`/`19–28`/`30–34` for datetimes, `38–52` trigger, `56` color digit). Any change to the entry format must be updated at every slice site.
- Recurring-event flags are embedded in the title prefix: `(j)` `(w)` `(m)` `(d)` `(*)`. All-day events use `T00:00`–`T23:59`.
- Widget registration goes in `function init()`, NOT `Component.onCompleted`.
- Fetch cycles are stamped with `fetchGeneration`; `finishFetchCycle()` is the single completion point (last callback, 2-min `fetchWatchdog`, or the empty-URL-list path). The generation/`requestDone` checks in `readGoogleCalendar` must not be removed — they drop stale callbacks from superseded or finished cycles.
- Colors must use `(typeof dimmableColors !== 'undefined') ? dimmableColors.X : colors.X` for dim mode; sizes/margins branch on `isNxt` (true = Toon 2/NXT, false = Toon 1). Never hardcode a single value for both platforms.
- All HTTP is `XMLHttpRequest` — the platform has no fetch API, and this old Qt5 build has no `XMLHttpRequest.timeout` (fetch-cycle bounding is done by the `fetchWatchdog` Timer). Settings read via `FileIO` (through the guarded `applySettings()`), written via XHR PUT to `/mnt/data/tsc/calendar.userSettings.json`.
- The device runs Qt5's JavaScriptCore: write ES5 only — `var`, no `let`/`const`, no arrow functions, no template strings, no ES6 string/array methods.
- Refresh: minimum 10 min enforced in the settings UI and `clampRefreshInterval()` (10–99); `endFirstAppointmentTimer` has a hard 5-minute floor; default 60.
- `drawables/` and `lang/` are not referenced by QML at runtime (icons use `qrc:` paths).

## Conventions

- UI strings are Dutch (translated via `qsTr` + compiled `lang/*.qm`).
- Version lives in `version.txt`; update it and `Changelog.txt` when changing behavior.
