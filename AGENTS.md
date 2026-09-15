# AGENTS.md

Compact guide for OpenCode sessions. `CLAUDE.md` has the full architecture write-up; this file lists what an agent would otherwise get wrong.

## What this is

QML app for the Toon smart thermostat (ToonStore app `apps.calendar`). Displays ICS calendar events on the home tile and a full-screen list. No build step, no tests, no linter, no CI — do not look for or add them.

## Deploy / verify

```bash
scp *.qml *.js qmldir root@<toon-ip>:/qmf/apps/calendar/
```

Then restart the app on device (or reboot). There is no local way to run or test the app; verification is by reading code carefully. Exception: the pure helpers (`convertDateToLocale`, `calcAlarmOffsetInMs`, `dayNumbers`, …) are engine-agnostic JS — they can be brace-extracted from the QML and regression-tested with `node`, which is the only real execution verification available.

## Device state beats code state

- The `calendarSettingsJson` defaults in `CalendarApp.qml` only take effect on a device that has no valid `/mnt/data/tsc/calendar.userSettings.json`. Editing default `Calendar_URL` entries does NOT reach already-configured devices — change the device file instead.
- The settings screen can only add/remove calendars from the public index; there is no free-form URL input. Arbitrary URLs must be edited into the device JSON directly.
- `Calendar_URL` entries whose feed contains weekday rules with ordinal BYDAY prefixes (`BYDAY=1MO`, "first Monday") were a known freeze source — recurrence loops are now capped, but treat RRULE parsing changes as high-risk (see the `recGuard` caps in `convertDateToLocale`).

## Non-obvious code facts

- `CalendarApp.qml` (~870 lines) holds ALL fetching, ICS parsing, recurrence logic, timers, and settings. The other QML files are pure UI.
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
