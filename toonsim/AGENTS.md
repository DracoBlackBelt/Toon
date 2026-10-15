# AGENTS.md (toonsim)

`toonsim` is a **vendored upstream tool** (github.com/ToonSoftwareCollective/toonsim, MIT): it runs the Toon GUI on a PC with the daemons simulated. It is not one of the five apps, so the root rules "no build step, no tests" do **not** apply here: it has a qmake build (C++/Qt 5.15), Python helpers and integration tests (`tests/`, `tools/run_tests.py`).

- Change it as little as possible and prefer sending fixes upstream; refresh the folder by re-copying upstream rather than hand-merging.
- Never commit `firmware/` (Eneco's GUI, pulled from your own Toon), `data*/`, `bin/`, `src/build*/` or installed apps (all git-ignored).
- Never touch a real Toon from here except the read-only `tools/pull_firmware.py`, and only when asked.
- The in-app updater is switched off here by the `NO-UPDATE` file (it would overwrite this vendored copy). When enabled, it only applies a release that publishes `<asset>.sha256`, and extracts safely.
- Local changes to upstream files (updater checksum, safe extraction, ToonStore name checks, macOS support in `toonsim.sh`/`build.sh`/`build_compat.py`, Python version check in `pull_firmware.py`) should be sent upstream; re-apply them when refreshing.

## ReToon in the simulator

`sh tools/add_retoon.sh` puts the QML of `../ReToon` in `apps/retoon/` (git-ignored, like any installed app). `retoon.sh` is **not** copied: the real one mounts `/dev/mmcblk3p1`/`p3`, writes boot files and runs `/sbin/reboot`, and must never run on a PC. `tools/retoon-sim.sh` takes its place and only writes the `/tmp/retoon.status` messages (check, 7 install steps, ready), so the tile and setup screen can be tried; `RETOON_SIM_FAIL=1` makes the install end in the error screen. Keep it in step with the status JSON that `ReToon/retoon.sh` writes.

## macOS (Apple Silicon), Homebrew `qt@5` (Qt 5.15, keg-only)

```bash
brew install qt@5
cd toonsim/src && mkdir -p build && cd build
/opt/homebrew/opt/qt@5/bin/qmake ../toonsim.pro CONFIG+=release CONFIG-=app_bundle CONFIG+=sdk_no_version_check
make -j8 && cd ../..                       # -> bin/toonsim (without CONFIG-=app_bundle you get toonsim.app)
export PATH=/opt/homebrew/opt/qt@5/bin:$PATH   # build_compat.py needs rcc on the PATH
python3 tools/pull_firmware.py <toon-ip> root <password> --apps --settings   # once; needs Python >= 3.12
bin/toonsim --home "$PWD" --size toon2
```

`tools/build.sh` and `toonsim.sh` also work on macOS now (they find Homebrew's `qt@5`); the commands above are what they do. The control port (127.0.0.1:5555) is unauthenticated by choice.
