import QtQuick 2.1
import qb.components 1.0
import qb.base 1.0

SystrayIcon {
    id: exampleSystrayIcon
    visible: true
    posIndex: 9100
    property string objectName: "exampleSystrayIcon"

    onClicked: {
        if (app && app.exampleScreen)
            app.exampleScreen.show()
    }

    Image {
        anchors.centerIn: parent
        source: "qrc:/tsc/BalloonIcon.png"
    }
}
