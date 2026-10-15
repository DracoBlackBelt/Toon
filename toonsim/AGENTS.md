# AGENTS.md (toonsim)

`toonsim` is a **vendored upstream tool** (github.com/ToonSoftwareCollective/toonsim, MIT): it runs the Toon GUI on a PC with the daemons simulated. It is not one of the five apps, so the root rules "no build step, no tests" do **not** apply here: it has a qmake build (C++/Qt 5.15), Python helpers and integration tests (`tests/`, `tools/run_tests.py`).

- Change it as little as possible and prefer sending fixes upstream; refresh the folder by re-copying upstream rather than hand-merging.
- Never commit `firmware/` (Eneco's GUI, pulled from your own Toon), `data*/`, `bin/`, `src/build*/` or installed apps (all git-ignored).
- Never touch a real Toon from here except the read-only `tools/pull_firmware.py`, and only when asked.
- The in-app updater is switched off here by the `NO-UPDATE` file (it would overwrite this vendored copy). When enabled, it only applies a release that publishes `<asset>.sha256`, and extracts safely.
- Local changes to upstream files (updater checksum, safe extraction, ToonStore name checks, macOS support in `toonsim.sh`/`build.sh`/`build_compat.py`, Python version check in `pull_firmware.py`) should be sent upstream; re-apply them when refreshing.

## macOS (Apple Silicon): Qt 5.15 from nixpkgs (preferred) or Homebrew

nixpkgs (`shell.nix` gives qmake, rcc and every QML module, and sets `QML2_IMPORT_PATH` / `QT_PLUGIN_PATH`; run everything inside it, the binary needs them at run time):

```bash
cd toonsim
nix-shell --run 'sh tools/build.sh'                                       # -> bin/toonsim
nix-shell --run 'python3 tools/pull_firmware.py <toon-ip> root <password> --apps --settings'   # once
nix-shell --run './toonsim.sh --size toon2'                                # or: bin/toonsim --home "$PWD" --size toon2
```

First start with nix Qt takes 1 to 2 minutes before the home screen shows (nixpkgs disables the QML cache); later starts are faster.

Homebrew (`qt@5` is deprecated and gets disabled on 2027-05-19):

```bash
brew install qt@5
sh tools/build.sh            # finds /opt/homebrew/opt/qt@5 when qmake is not on the PATH
export PATH=/opt/homebrew/opt/qt@5/bin:$PATH   # build_compat.py needs rcc on the PATH
python3 tools/pull_firmware.py <toon-ip> root <password> --apps --settings   # once; needs Python >= 3.12
bin/toonsim --home "$PWD" --size toon2
```

The control port (127.0.0.1:5555) is unauthenticated by choice.
