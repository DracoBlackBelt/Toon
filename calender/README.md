# Toon Calendar App

A QML app for the [Toon smart thermostat](https://www.quby.com/) that shows upcoming calendar events from any ICS URL (Google Calendar, iCloud, Office 365, public calendars) on the home screen tile and a paginated full-screen list.

## Features

- Displays the next 3 upcoming appointments on the home screen tile
- Full-screen paginated list of upcoming events (16 per page)
- Supports Google Calendar, iCloud, Office 365 and any public `.ics` URL
- Recurring events: daily, weekly (including specific weekdays), monthly, yearly
- Per-calendar color coding
- Appointment reminders as Toon notifications
- Birthday balloon animations for yearly recurring events
- Configurable refresh interval
- Dim-state tile: shows title and date of next appointment, or all three events

## Installation

Copy the app files to your Toon device. The app lives in a versioned directory (`calendar-<version>`, see `version.txt`), and the Toon's old SSH server needs legacy options (`-O` because the device has no sftp-server, `ssh-rsa` for the host key):

```bash
scp -O -oHostKeyAlgorithms=+ssh-rsa *.qml *.js qmldir root@<toon-ip>:/qmf/qml/apps/calendar-<version>/
```

Example for version 1.1.17:

```bash
scp -O -oHostKeyAlgorithms=+ssh-rsa *.qml *.js qmldir root@10.0.0.126:/qmf/qml/apps/calendar-1.1.17/
```

To apply changes, restart the Toon GUI (this restarts all apps):

```bash
ssh -oHostKeyAlgorithms=+ssh-rsa root@<toon-ip>
killall qt-gui
```

## Configuration

Open the calendar settings screen on your Toon to:

- Add or remove calendars by picking from a built-in list of public ICS calendars (there is no free-form URL input on the Toon; arbitrary private URLs must be edited into the settings JSON on the device)
- Toggle notifications, color coding, dim-tile extended view, and balloon animations
- Set the refresh interval (minimum 10 minutes via the UI)

Settings are stored at `/mnt/data/tsc/calendar.userSettings.json` on the device.

## Compatibility

Works on both Toon 1 and Toon 2 / NXT hardware. The app branches on the platform-provided `isNxt` boolean for layout differences between the two screen sizes.

## Version

Current version: **1.1.17** — see [Changelog.txt](Changelog.txt) for full history.
