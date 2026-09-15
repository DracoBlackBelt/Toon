# Toon Buienradar App

A QML app for the [Toon smart thermostat](https://www.quby.com/) that shows live weather from Buienradar.nl: current conditions, rain prediction, animated radar, and full forecast, right on the Toon dashboard. Distributed via ToonStore as `apps.buienradar`.

## Features

- Main weather tile: temperature, wind, and a condition icon (separate icon sets for normal and dim mode)
- Regen tile: 2-hour rain prediction bar chart
- Sunrise/sunset tile
- Full-screen animated radar with buttons for UV index, pollen, mosquito radar, temperature and wind maps (national weather maps, hourly for temp/wind)
- Scrollable full-text weather forecast screen
- Weather station picker and free lon/lat editor (rain forecast is location-based)
- Optional system tray icon and settings menu entry
- Weather data refreshes every 10 minutes, rain forecast every 5 minutes
- Writes the current temperature to `/var/volatile/tmp/actualBuienradarTemp.txt` for the companion TemperatureLogger app

## Installation

Unlike most Toon apps, this one must be deployed to the **unversioned** path `/qmf/qml/apps/buienradar/` — the weather icons are loaded from an absolute path — and the `drawables/` folder is required on device. The Toon's old SSH server needs legacy options (`-O` because the device has no sftp-server, `ssh-rsa` for the host key):

```bash
scp -O -r -oHostKeyAlgorithms=+ssh-rsa *.qml *.js qmldir drawables root@<toon-ip>:/qmf/qml/apps/buienradar/
```

To apply changes, restart the Toon GUI (this restarts all apps):

```bash
ssh -oHostKeyAlgorithms=+ssh-rsa root@<toon-ip>
killall qt-gui
```

## Configuration

Open the Buienradar menu entry on your Toon to select a weather station or set a custom lon/lat position. Settings are stored at `/mnt/data/tsc/buienradar.userSettings.json` on the device.

## Compatibility

Works on both Toon 1 and Toon 2 / NXT hardware (radar images and layout branch on the platform-provided `isNxt` boolean).

## Version

Current version: **9.0.11** — see [Changelog.txt](Changelog.txt) for full history.
