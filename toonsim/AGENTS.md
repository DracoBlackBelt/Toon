# AGENTS.md (toonsim)

`toonsim` is a **vendored upstream tool** (github.com/ToonSoftwareCollective/toonsim, MIT): it runs the Toon GUI on a PC with the daemons simulated. It is not one of the five apps, so the root rules "no build step, no tests" do **not** apply here: it has a qmake build (C++/Qt 5.15), Python helpers and integration tests (`tests/`, `tools/run_tests.py`).

- Change it as little as possible and prefer sending fixes upstream; refresh the folder by re-copying upstream rather than hand-merging.
- Never commit `firmware/` (Eneco's GUI, pulled from your own Toon), `data*/`, `bin/`, `src/build*/` or installed apps (all git-ignored).
- Never touch a real Toon from here except the read-only `tools/pull_firmware.py`, and only when asked.
- Do not use Ctrl+U / `--check-update` / TSC's update button: the updater overwrites files from an upstream release without verifying it.

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

`toonsim.sh` and `tools/build.sh` are Debian-oriented (apt, `nproc`); on macOS call the binary directly as above.
