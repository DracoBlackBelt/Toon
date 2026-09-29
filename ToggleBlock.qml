import QtQuick 2.1

Item {
    id: toggleBlock

    width: 200
    height: 36

    property string labelText: ""
    property bool checked: false
    // proportional to the block height, so it follows the screen scale
    property int labelFont: Math.max(9, Math.round(height * 0.36))
    property int labelMargin: Math.round(height * 0.3)

    signal toggled()

    Text {
        id: blockLabel
        anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
            leftMargin: labelMargin
        }
        width: parent.width - labelMargin - blockSwitch.width - 8
        text: labelText
        font.pixelSize: labelFont
        elide: Text.ElideRight
        color: "Black"
    }

    ToggleSwitch {
        id: blockSwitch
        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        height: Math.round(parent.height * 0.9)
        width: Math.round(height * 1.5)
        checked: toggleBlock.checked
        onToggled: toggleBlock.toggled()
    }

    MouseArea {
        anchors.fill: parent
        onClicked: toggleBlock.toggled()
    }
}
