# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this app is

A QML app for the **Toon smart thermostat** that displays ICS calendar events (Google, iCloud, Office365, public ICS URLs) on the home screen tile and a full-screen list. Distributed via ToonStore as `apps.calendar`.

## Deployment

No build step. Deploy QML files directly to the device:

```bash
scp *.qml *.js qmldir root@<toon-ip>:/qmf/apps/calendar/
```

Restart the app on device after changes (or reboot). There are no tests, no linter, no CI.

`drawables/` and `lang/` are part of the repo but not referenced by QML at runtime (icons use `qrc:` paths).

## Architecture

### Data flow

1. `CalendarApp.qml` (`App` root) starts on boot with a delayed timer (20 s on Toon 2, 150 s on Toon 1) to let the device finish booting.
2. `readCalendars()` fires for each URL in `Calendar_URL` settings, fetching the raw ICS text via `XMLHttpRequest`.
3. Each `readGoogleCalendar()` call parses the ICS text with direct string indexing (no DOM/regex), building entries in `calendarDatesString`.
4. When all calendars are fetched (`numberOfCalendersToRead == 0`), `sortCalendarDates()` sorts entries lexicographically (dates are ISO-formatted so string sort = chronological), then `processCollectedCalendarDates()` extracts the first 3 appointments into tile properties and sets notification/animation timers.
5. Auto-refresh: either when the first appointment ends, or at the configured interval (default 60 min), whichever comes first. The UI enforces a minimum of 10 minutes; the timer enforces a hard floor of 5 minutes. A midnight timer refreshes day-label strings ("Vandaag"/"Morgen"/"Overmorgen").

### Internal data format

`calendarDatesString` is a newline-separated list of fixed-format entries:

```
YYYY-MM-DDTHH:MM - YYYY-MM-DDTHH:MM - <trigger 15 chars> - <color digit><recflag><title>
```

Key offsets used throughout (hardcoded slice positions):
- `0–10` start date, `19–35` end date, `38–53` trigger, `56` color index digit, `57+` title
- All-day events: start `T00:00`, end `T23:59`
- Recurring flags embedded in title prefix: `(j)` yearly, `(w)` weekly, `(m)` monthly, `(d)` daily, `(*)` other

### Files

| File | Role |
|------|------|
| `CalendarApp.qml` | App root — all ICS fetching, parsing, recurrence logic, timers, state |
| `CalendarTile.qml` | Home screen tile — shows next 3 appointments; dim/normal state variants |
| `CalendarListDatesScreen.qml` | Full-screen paginated list (16 entries per page, 2 columns); reads `calendarDatesString` directly. Note: `navigatePage` starts at index 1 — the first entry in `calendarDatesString` is never shown (off-by-one bug). |
| `CalendarConfigurationScreen.qml` | Settings screen — toggles, refresh interval, calendar URL list |
| `CalendarConfigurationScreenDelegate.qml` | Row in the URL list (add/remove buttons, color bar) |
| `CalendarListDatesScreenDelegate.qml` | Row in the appointments grid |
| `calendar.js` | Thin JS module — only wraps `Array.sort()` (needed for QML import) |
| `EditTextLabel4421.qml` | Custom numeric/text input label used for refresh interval |

### Settings persistence

Settings file on device: `/mnt/data/tsc/calendar.userSettings.json`

Keys: `ShowNotifications`, `ShowColors`, `ShowAnimation`, `DimTileExtended`, `RefreshIntervalInMinutes`, `Calendar_URL` (array of ICS URLs).

Read via `FileIO`, written via `XMLHttpRequest PUT`.

`calendarListDates` is a formatted text block built by `processCollectedCalendarDates()` (up to 20 entries via `addCalendarListEntry()`), but it is not used — `CalendarListDatesScreen` reads `calendarDatesString` directly. Editing `addCalendarListEntry()` has no effect on the UI.

### Public calendars index

Fetched at config screen open from:
`https://raw.githubusercontent.com/ToonSoftwareCollective/calendar_public_calendars/main/public_calendars.json`

Returns `{ public_calendars: [ { friendlyName, link } ] }`.

## Platform conventions

- `isNxt` — `true` for Toon 2/NXT (larger screen), `false` for Toon 1. All pixel sizes and margins branch on this. Never hardcode a single value for both.
- Colors: always `(typeof dimmableColors !== 'undefined') ? dimmableColors.X : colors.X` to support dim mode.
- `registry.registerWidget(...)` calls go inside `function init()`, not `Component.onCompleted`.
- All HTTP is `XMLHttpRequest` — no fetch API on this platform.
- UI language is Dutch.
