# AGENTS.md

Workspace of five **independent QML apps for the Toon smart thermostat** (Quby/Eneco): `buienradar/` (weather), `calender/` (ICS calendar, module `apps.calendar`), `exampleapp/` (copy-me scaffold, `apps.example`), `sonos/` (Sonos/Spotify control), `homeassistant/` (Home Assistant sensors/scenes/switches/alarm, module `apps.homeassistant`). Not a git repo (exception: `sonos/`, `buienradar/` and `homeassistant/` each have their own private `.git`). No build step, no tests, no linter, no CI, no package manifests — do not look for or add them.

## Before touching an app

Each app has a **canonical `AGENTS.md`** (read that first — it holds the app's hard-earned gotchas). Keep all per-app guidance in `AGENTS.md`.

## Deploy / verify (all apps)

There is no local way to run QML. Deploy by copying files to the device and restarting the GUI:

```bash
scp -O -r -oHostKeyAlgorithms=+ssh-rsa *.qml *.js qmldir drawables root@<toon-ip>:/qmf/qml/apps/<app-dir>/
ssh -oHostKeyAlgorithms=+ssh-rsa root@<toon-ip> killall qt-gui
```

`-O` (legacy SCP — no sftp-server on device) and `+ssh-rsa` (old host key) are both required. `<app-dir>` differs per app: `calendar-<version>` (versioned, e.g. `calendar-1.1.17` from `version.txt`), `buienradar` (**unversioned — mandatory**, its QML loads icons from the absolute path `file:///qmf/qml/apps/buienradar/drawables/...`), `sonos/` (anything; icons use relative paths), `homeassistant` (anything — use unversioned; icons use relative `drawables/...`). Verification is careful code reading; pure JS helpers (e.g. `buienradar.js`, `calendar.js`) can be brace-extracted and sanity-checked with `node`.

Qt 6.11 is installed on this machine (Homebrew): `qmllint`/`qmlformat` (parse-check any QML — the device-only modules `qb.*`, `FileIO`, `BasicUIControls` always warn, so look only at actual *Error*s), and `lupdate`/`lrelease` for `lang/*.ts` → `lang/*.qm` (keep `.qm` in sync with `qsTr()` sources). QML still cannot be *run* locally — the Toon runtime is not available.

`sonos/spotify-login.sh` is a PC-side helper that runs the Spotify OAuth dance and writes tokens to the device via `sshpass` (hardcoded IP `192.168.10.68`, password `toon` — edit for your network before running).

## Platform rules that apply to every app

- **ES5 only.** Device runs Qt5 JavaScriptCore: `var`, no `let`/`const`, no arrow functions, no template strings, no ES6 methods.
- **No fetch API.** All HTTP (and file writes) go through `XMLHttpRequest`; `xhr.timeout`/`ontimeout` are unreliable on this old Qt5 build (sonos sets them, calender does not) — bound long-running fetches with `Timer`s and never rely on `timeout` alone.
- **Settings:** read via `FileIO` from `/mnt/data/tsc/<app>.userSettings.json`; write via XHR PUT to the same path. Defaults in code only apply to devices with no valid settings file.
- **Widget registration** (`registry.registerWidget(...)`) goes in `function init()`, NOT `Component.onCompleted`.
- **Two hardware variants:** branch sizes/margins on `isNxt` (true = Toon 2/NXT). Colors for dim mode: `(typeof dimmableColors !== 'undefined') ? dimmableColors.X : colors.X`.
- **UI strings are Dutch**, wrapped in `qsTr()`; `lang/*.qm` are compiled translations. Icon references differ per app — `qrc:/tsc/...` (calender), absolute `/qmf/qml/apps/buienradar/drawables/...` (buienradar), relative `drawables/...` (sonos) — see the per-app `AGENTS.md` before assuming `drawables/` is decorative.- **Releases:** bump `version.txt` and prepend a block to `Changelog.txt` together when changing behavior.

## Gotchas

- Folder is `calender` (sic) but the module/app name is `calendar`.
- `EditTextLabel4421.qml` is a shared custom input widget copy-pasted into several apps — changes may need mirroring, not deduping.
- Per-app quirks (calendar RRULE freeze history and fixed-format ICS string offsets, buienradar temperature side-file at `/var/volatile/tmp/actualBuienradarTemp.txt`, sonos Spotify secret/tokens living in a separate `/mnt/data/tsc/sonos.spotifyToken.json`, homeassistant's HA long-lived token living in a separate `/mnt/data/tsc/homeassistant.token.txt` which the app reads but must never write) are in the respective `AGENTS.md`.
