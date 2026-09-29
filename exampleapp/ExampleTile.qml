import QtQuick 2.1
import qb.components 1.0

Tile {
    id: exampleTile

    onClicked: {
        if (app && app.exampleScreen)
            app.exampleScreen.show()
    }

    Text {
        id: testLabel
        text: "test"
        font.pixelSize: isNxt ? 22 : 18
        font.family: qfont.regular.name
        color: (typeof dimmableColors !== 'undefined') ? dimmableColors.clockTileColor : colors.clockTileColor
        anchors.centerIn: parent
    }
}
