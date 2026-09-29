import QtQuick 2.1
import qb.components 1.0
import qb.base 1.0

App {
    id: root
    objectName: "ExampleApp"

    property url tileUrl:      "ExampleTile.qml"
    property url menuUrl:      "ExampleMenu.qml"
    property url trayUrl:      "ExampleTray.qml"
    property url screenUrl:    "ExampleScreen.qml"
    property url thumbnailIcon: "qrc:/tsc/ExampleThumb.png"
    // TODO: replace with actual resource, or use a drawables/ path during development:
    // property url thumbnailIcon: "drawables/example_thumb.png"

    property ExampleScreen exampleScreen

    // TODO: add state properties here, e.g.:
    // property string someValue: ""

    function init() {
        registry.registerWidget("tile", tileUrl, this, null, {
            thumbLabel: qsTr("Example"),
            thumbIcon: thumbnailIcon,
            thumbCategory: "general",
            thumbWeight: 30,
            baseTileWeight: 10,
            thumbIconVAlignment: "center"
        })
        registry.registerWidget("screen", Qt.resolvedUrl(screenUrl), this, "exampleScreen")
        registry.registerWidget("menuItem", menuUrl, this, "exampleMenu", {weight: 200})
        registry.registerWidget("systrayIcon", trayUrl, this, "exampleTray")
    }

    Component.onCompleted: {
        // TODO: read persisted settings here, e.g. via FileIO
    }

    // TODO: add timers here, e.g.:
    // Timer {
    //     id: updateTimer
    //     interval: 60000
    //     repeat: true
    //     onTriggered: fetchData()
    // }

    // TODO: add functions here, e.g.:
    // function fetchData() { ... }

    // TODO: persist settings — add "import FileIO 1.0" then read/write JSON to:
    // /mnt/data/tsc/example.userSettings.json
    // (FileIO for reading, XMLHttpRequest PUT for writing — see SonosApp.qml)
}
