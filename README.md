# Toon

QML apps for the [Toon smart thermostat](https://www.quby.com/) (Quby/Eneco). This repo is a monorepo of five independent apps, each deployed to the device separately — there's no shared build or cross-app code.

| App | Module | What it does |
|---|---|---|
| [`buienradar/`](buienradar/) | `apps.buienradar` | Buienradar.nl weather: temperature/wind tile, rain forecast, animated radar, station picker |
| [`calender/`](calender/) | `apps.calendar` | ICS calendar events on a home tile and full-screen list |
| [`exampleapp/`](exampleapp/) | `apps.example` | Minimal copy-me scaffold for building a new Toon app |
| [`sonos/`](sonos/) | `apps.sonos` | Sonos speaker control via [node-sonos-http-api](https://github.com/jishi/node-sonos-http-api), with Spotify playback |
| [`homeassistant/`](homeassistant/) | `apps.homeassistant` | Home Assistant sensors, scenes, switches, and alarm control panel |

Each app has its own `README.md` (user-facing) and `AGENTS.md` (developer/agent guide with deploy steps and hard-earned gotchas) — read the app's `AGENTS.md` before making changes to it.

## Repository history

This repo was assembled from five formerly-separate GitHub repositories (`buienradar`, `calender`, `exampleapp`, `sonos`, `homeassistant`), merged in with their full commit history intact via a subtree-style merge. Run `git log --graph` from the root to see the merge points, or `git log -- <app>/` scoped to one app. The `homeassistant` app also carries the `upstream-1.0.8` tag from its original fork point — diff against it with `git diff upstream-1.0.8 HEAD:homeassistant`.

## Working in this repo

There's no build step, no tests, no linter, no CI, and no package manifests for any app — don't look for or add them. QML can't be run locally; the Toon runtime only exists on the device. Verification is careful code reading, plus:

- **Qt 6.11** (Homebrew) provides `qmllint`/`qmlformat` for parse-checking QML, and `lupdate`/`lrelease` for compiling `lang/*.ts` → `lang/*.qm`.
- Pure JS helper functions (no QML/device dependencies) can be brace-extracted from the `.qml`/`.js` files and sanity-checked with `node`.

See the root [`AGENTS.md`](AGENTS.md) for the platform rules that apply across every app (ES5-only JS, `XMLHttpRequest` instead of `fetch`, settings file conventions, dim-mode color handling, etc.).

## Deploying an app

All apps deploy the same way: copy files over SCP, then restart the GUI over SSH. The Toon's SSH server is old enough to need legacy options (`-O` — no sftp-server on device — and `ssh-rsa` for the host key):

```bash
scp -O -r -oHostKeyAlgorithms=+ssh-rsa *.qml *.js qmldir drawables root@<toon-ip>:/qmf/qml/apps/<app-dir>/
ssh -oHostKeyAlgorithms=+ssh-rsa root@<toon-ip> killall qt-gui
```

`<app-dir>` differs per app — versioned for `calender` (`calendar-<version>`), unversioned and mandatory for `buienradar` and `homeassistant`, anything for `sonos`. See each app's `AGENTS.md` for the exact command and why.
