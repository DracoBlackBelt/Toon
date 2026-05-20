# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project is

A QML plugin for the **Toon thermostat** (Quby/Eneco Dutch smart home device) that displays Buienradar weather data. Distributed via ToonStore. There is no build system, compiler, or test suite — changes are deployed directly to the Toon device.

There are two hardware variants, distinguished throughout QML by the built-in boolean `isNxt`:
- **Toon 1** — smaller screen, older hardware
- **Toon 2 / NXT** (`isNxt == true`) — larger screen, more pixels

## Architecture

**`BuienradarApp.qml`** is the central App object. It owns all shared state as properties (`temperatuurGC`, `radarimagesurl`, `lat`, `lon`, etc.), handles all HTTP fetching, persists user settings, and registers every screen/tile/tray widget with the Toon `registry`.

Two data loops run on timers:
- `updateBuienradar()` — every 10 min, fetches `https://data.buienradar.nl/2.0/feed/json`, populates weather station data and 5-day forecast
- `updateRegenkans()` — every 5 min, fetches `https://graphdata.buienradar.nl/2.0/forecast/geo/RainHistoryForecast?lat=&lon=`, populates the rain-prediction tile

**`buienradar.js`** contains pure utility functions: formatting helpers, weather icon selection (`parseWeatherIdAndText`), date manipulation.

**Screens** (each registered via `registry.registerWidget("screen", ...)`):
- `BuienradarDetailsScreen.qml` — detail view with small radar, 5-day forecast table, station data
- `BuienradarActualRadarScreen.qml` — full-screen animated radar + buttons for UV index, pollen, temperature maps, etc.
- `BuienradarStationScreen.qml` — weather station picker
- `BuienradarEditLonLatScreen.qml` — lon/lat coordinate editor
- `BuienradarFullWeatherForecastScreen.qml` — scrollable full-text weather forecast

**Tiles** (registered as `"tile"`):
- `BuienradarTile.qml` — main tile showing temperature, wind, weather icon
- `BuienradarRegenTile.qml` — 2-hour rain prediction bar chart
- `BuienradarSunriseTile.qml` — sunrise/sunset times

**Other**: `BuienradarMenu.qml` (menu entry), `BuienradarTray.qml` (systray icon).

## External APIs

| API | URL pattern |
|-----|-------------|
| Main JSON feed | `https://data.buienradar.nl/2.0/feed/json` |
| Rain forecast | `https://graphdata.buienradar.nl/2.0/forecast/geo/RainHistoryForecast?lat=N&lon=N` |
| Animated radar | `https://api.buienradar.nl/image/1.0/RadarMapNL?width=N&height=N` |
| Static weather maps | `https://processing-cdn.buienradar.nl/processing/nl/weathermaps/<type>/default/<date>.png` |

Radar image sizes: **600×600** on NXT, **400×400** on Toon 1.

## Key conventions

- **`isNxt`** is a Toon-provided QML global — always use it for device-specific sizing, never hardcode one size for both.
- Weather icon filenames follow `Dim<Condition>.png` / `Home<Condition>.png` pattern in `drawables/`. `Dim*` = dim/dark mode, `Home*` = normal mode. Icon selection logic lives in `parseWeatherIdAndText()` in `buienradar.js`.
- User settings (selected station, lon/lat) are persisted as JSON to `/mnt/data/tsc/buienradar.userSettings.json` on the device via XMLHttpRequest PUT.
- Actual temperature is also written to `/var/volatile/tmp/actualBuienradarTemp.txt` for the TemperatureLogger app.

## Versioning and release

- `version.txt` — single line with current version (e.g. `9.0.11`)
- `Changelog.txt` — prepend new version block at the top; each entry is brief (one or two lines)

When bumping a version, update both files together in one commit.
