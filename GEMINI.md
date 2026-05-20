# Project: Buienradar for Toon

A QML-based weather application for the **Toon thermostat** (Quby/Eneco Dutch smart home device) that integrates data from Buienradar.nl. It is distributed via the ToonStore.

## Project Overview

This application provides real-time weather information, animated radar maps, and rain predictions directly on the Toon dashboard. It supports both **Toon 1** (standard) and **Toon 2** (NXT) hardware variants.

### Key Technologies
- **QML**: UI declaration and layout.
- **JavaScript**: Business logic, data parsing, and formatting.
- **Buienradar JSON 2.0 API**: Primary data source.

### Architecture
- **`BuienradarApp.qml`**: The central application controller. It manages shared state, handles all network requests (XMLHttpRequest), persists user settings, and registers widgets (tiles, screens, tray) with the Toon system.
- **`buienradar.js`**: A shared library containing pure utility functions for data formatting, date manipulation, and weather icon mapping.
- **Widgets**:
  - **Tiles**: Small dashboard widgets (`BuienradarTile.qml`, `BuienradarRegenTile.qml`, `BuienradarSunriseTile.qml`).
  - **Screens**: Full-screen views for detailed info (`BuienradarDetailsScreen.qml`, `BuienradarActualRadarScreen.qml`, etc.).
  - **Tray/Menu**: Integration with the Toon status bar and main menu.

## Building and Running

There is no local build or compilation step. The application is interpreted by the Toon's `qt-gui` process.

### Deployment Workflow
1.  **Transfer Files**: Copy the project files to the Toon device at `/qmf/qml/apps/buienradar/`.
2.  **Restart GUI**: To apply changes, restart the GUI process on the Toon:
    ```bash
    killall qt-gui
    ```
3.  **ToonStore**: For public distribution, the app is packaged and updated via the ToonStore repository.

## Development Conventions

### Hardware Compatibility
- Always use the built-in global **`isNxt`** to distinguish between Toon 1 (`false`) and Toon 2/NXT (`true`).
- Radar image sizes are typically **600x600** on NXT and **400x400** on Toon 1.

### UI & Assets
- **Icons**: Weather icons follow the pattern `Dim<Condition>.png` (for dimmed/night mode) and `Home<Condition>.png` (for standard home screen).
- **Drawables**: All images are located in the `drawables/` directory.

### Data & Persistence
- **Polling**:
  - Weather Feed: Every 10 minutes.
  - Rain Forecast: Every 5 minutes.
- **User Settings**: Persisted as JSON to `/mnt/data/tsc/buienradar.userSettings.json`.
- **Inter-app Communication**: Current temperature is written to `/var/volatile/tmp/actualBuienradarTemp.txt` for use by other apps like `TemperatureLogger`.

### Versioning
- **`version.txt`**: Contains the current version string (e.g., `9.0.11`).
- **`Changelog.txt`**: Maintain a chronological list of changes, with the latest version at the top. Update both files simultaneously when releasing.

### Localization
- **`lang/`**: Contains compiled translation files (`.qm`). The app supports multiple languages (e.g., Dutch `nl_NL`, English `en_GB`) via the Toon `i18n` object.

## Key Files
- `BuienradarApp.qml`: Main entry point and state manager.
- `buienradar.js`: Formatting and mapping logic.
- `qmldir`: Module definition for the Toon environment.
- `version.txt`: Current application version.
