import QtQuick 2.1
import qb.components 1.0

Screen {
    id: homeAssistantScreen

    screenTitle: "Home Assistant"
    hasBackButton: true

    // --- layout metrics ---
    // Everything scales with the real screen width (800 = design size), so the
    // same layout works on every Toon resolution instead of guessing from isNxt.
    // Heights that could overflow are derived from the space that is really left.
    property real u: (width > 0) ? width / 800 : 1
    property int pad: Math.round(30 * u)
    property int gap: Math.round(8 * u)
    property int titleFont: Math.max(9, Math.round(16 * u))
    property int bodyFont: Math.max(8, Math.round(13 * u))
    property int titleH: Math.round(titleFont * 1.3) + gap
    property int sensorRowH: Math.round(24 * u)
    property int logoSize: Math.round(80 * u)
    property int sceneBtnW: Math.round(120 * u)
    property int sliderBlockH: Math.round(46 * u)
    property int alarmLabelH: Math.round(30 * u)
    property color cardColor: "#e8e8e8"
    property color textColor: "Black"

    // what is configured (compacted lists, see app.refreshActive())
    property int sensorCount: app.activeSensors.length
    property int sceneCount: app.activeScenes.length
    property int switchCount: app.activeSwitches.length
    property bool hasSlider: app.sliderEntity != ""
    property bool hasAlarm: app.alarmEntity != ""

    // derived sizes, all bounded by lowerArea.height
    property int sceneRows: Math.ceil(sceneCount / 2)
    property int leftW: (sceneCount > 0 || hasSlider) ? 2 * sceneBtnW + gap : 0
    property int sceneBtnH: sceneRows > 0 ? Math.max(Math.round(24 * u), Math.min(Math.round(75 * u), Math.floor((lowerArea.height - titleH - (hasSlider ? sliderBlockH + gap : 0) - (sceneRows - 1) * gap) / sceneRows))) : 0
    property int switchRowH: switchCount > 0 ? Math.max(Math.round(24 * u), Math.min(Math.round(50 * u), Math.floor((lowerArea.height - titleH) / switchCount))) : 0
    property int dialSize: Math.max(Math.round(24 * u), Math.min(Math.round(52 * u), Math.floor((lowerArea.height - titleH - alarmLabelH - 4 * gap) / 4)))
    property int alarmW: hasAlarm ? 3 * dialSize + 2 * gap : 0

    onShown: {
        addCustomTopRightButton(qsTr("Instellingen"));
        app.refreshNow();
        app.logShown = false;
    }

    onCustomButtonClicked: {
        if (app.homeAssistantConfigurationScreen) {
            app.homeAssistantConfigurationScreen.show();
        }
    }

    //
    // Top: sensors (two balanced columns) + HA logo (tap = manual refresh)
    //

    Rectangle {
        id: sensorRect
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            leftMargin: pad
            rightMargin: pad
            topMargin: gap
        }
        height: Math.max(logoSize, sensorGrid.height) + 2 * gap
        radius: 10
        color: cardColor

        Grid {
            id: sensorGrid
            anchors {
                left: parent.left
                right: logoImage.left
                verticalCenter: parent.verticalCenter
                leftMargin: 2 * gap
                rightMargin: gap
            }
            flow: Grid.TopToBottom
            columns: 2
            rows: Math.ceil(sensorCount / 2)
            columnSpacing: pad
            rowSpacing: 0

            Repeater {
                model: sensorCount
                delegate: Item {
                    readonly property int slot: app.activeSensors[index]
                    width: (sensorGrid.width - sensorGrid.columnSpacing) / 2
                    height: sensorRowH

                    Text {
                        anchors {
                            left: parent.left
                            right: sensorValueText.left
                            verticalCenter: parent.verticalCenter
                            rightMargin: gap
                        }
                        text: app.sensorName(slot)
                        font.pixelSize: bodyFont
                        elide: Text.ElideRight
                        color: textColor
                    }

                    Text {
                        id: sensorValueText
                        anchors {
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                        }
                        width: Math.min(implicitWidth, parent.width * 0.55)
                        text: app.sensorValue(slot)
                        font.pixelSize: bodyFont
                        font.family: qfont.semiBold.name
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                        color: textColor
                    }
                }
            }
        }

        Image {
            id: logoImage
            anchors {
                right: parent.right
                rightMargin: gap
                verticalCenter: parent.verticalCenter
            }
            width: logoSize
            height: logoSize
            source: "drawables/homeAssistantIconBig.png"
            fillMode: Image.PreserveAspectFit
            cache: false

            MouseArea {
                anchors.fill: parent
                onClicked: app.refreshNow()
            }
        }
    }

    // Why nothing shows (no token, wrong entity id, server down, failed command).
    Item {
        id: banner
        anchors {
            left: parent.left
            right: parent.right
            top: sensorRect.bottom
            leftMargin: pad
            rightMargin: pad
            topMargin: bannerText.text != "" ? gap / 2 : 0
        }
        height: bannerText.text != "" ? bannerText.contentHeight : 0

        Text {
            id: bannerText
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
            }
            text: app.statusText != "" ? app.statusText : app.noticeText
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            font.pixelSize: bodyFont
            color: "#b71c1c"
        }
    }

    //
    // Lower area: scenes + slider | switches | alarm
    //

    Item {
        id: lowerArea
        anchors {
            left: parent.left
            right: parent.right
            top: banner.bottom
            bottom: parent.bottom
            topMargin: gap
            bottomMargin: gap
        }

        // --- left: scenes (2 per row) and slider ---
        Item {
            id: leftCol
            anchors {
                left: parent.left
                top: parent.top
                leftMargin: pad
            }
            width: leftW
            height: parent.height

            Text {
                id: sceneTitle
                text: qsTr("Scenes")
                visible: sceneCount > 0
                font.pixelSize: titleFont
                font.family: qfont.semiBold.name
                color: textColor
            }

            Grid {
                id: sceneGrid
                anchors {
                    left: parent.left
                    top: parent.top
                    topMargin: titleH
                }
                columns: 2
                spacing: gap

                Repeater {
                    model: sceneCount
                    delegate: IconButton {
                        readonly property int slot: app.activeScenes[index]
                        width: sceneBtnW
                        height: sceneBtnH
                        bottomClickMargin: 3
                        text: app.sceneName(slot)
                        onClicked: app.setEntity(app.sceneEntity(slot), true)
                    }
                }
            }

            Item {
                id: sliderBlock
                visible: hasSlider
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    topMargin: sceneCount > 0 ? titleH + sceneGrid.height + gap : titleH
                }
                height: sliderBlockH

                IconButton {
                    id: sliderMinus
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                    }
                    width: sliderBlockH
                    height: sliderBlockH
                    text: "-"
                    onClicked: app.sliderStep(-1)
                }

                Column {
                    anchors {
                        left: sliderMinus.right
                        right: sliderPlus.left
                        verticalCenter: parent.verticalCenter
                        leftMargin: gap
                        rightMargin: gap
                    }

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: app.sliderName()
                        font.pixelSize: bodyFont - 1
                        elide: Text.ElideRight
                        color: textColor
                    }

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: app.sliderText()
                        font.pixelSize: titleFont
                        font.family: qfont.semiBold.name
                        elide: Text.ElideRight
                        color: textColor
                    }
                }

                IconButton {
                    id: sliderPlus
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    width: sliderBlockH
                    height: sliderBlockH
                    text: "+"
                    onClicked: app.sliderStep(1)
                }
            }
        }

        // --- right: alarm control panel ---
        Item {
            id: alarmCol
            anchors {
                right: parent.right
                top: parent.top
                rightMargin: pad
            }
            width: alarmW
            height: parent.height
            visible: hasAlarm

            Text {
                text: qsTr("Alarm")
                font.pixelSize: titleFont
                font.family: qfont.semiBold.name
                color: textColor
            }

            Column {
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    topMargin: titleH
                }
                spacing: gap

                Rectangle {
                    width: parent.width
                    height: alarmLabelH
                    radius: 10
                    color: cardColor

                    Text {
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            leftMargin: gap
                            rightMargin: gap
                        }
                        horizontalAlignment: Text.AlignHCenter
                        text: app.alarmInputLabel
                        font.pixelSize: bodyFont
                        font.family: qfont.semiBold.name
                        elide: Text.ElideRight
                        color: textColor
                    }
                }

                Grid {
                    columns: 3
                    spacing: gap

                    Repeater {
                        model: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "reset", "0", "enter"]
                        delegate: Item {
                            width: dialSize
                            height: dialSize

                            Image {
                                anchors.fill: parent
                                smooth: true
                                source: modelData == "reset" ? "drawables/dialpadReset.png" :
                                        (modelData == "enter" ?
                                            (app.alarmIsActive() ? "drawables/dialpadLocked.png" : "drawables/dialpadUnlocked.png") :
                                            "drawables/dialpadButton.png")

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        if (modelData == "reset") {
                                            app.alarmInputReset();
                                        } else if (modelData == "enter") {
                                            app.alarmToggle();
                                        } else {
                                            app.alarmInput(modelData);
                                        }
                                    }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: modelData != "reset" && modelData != "enter"
                                text: modelData
                                font.pixelSize: bodyFont + 2
                                color: "#757575"
                            }
                        }
                    }
                }
            }
        }

        // --- middle: switches, in the space between the two other columns ---
        Item {
            id: switchCol
            anchors {
                left: leftCol.right
                right: alarmCol.left
                top: parent.top
                leftMargin: leftW > 0 ? pad : 0
                rightMargin: alarmW > 0 ? pad : 0
            }
            height: parent.height

            Text {
                text: qsTr("Schakelaars")
                visible: switchCount > 0
                font.pixelSize: titleFont
                font.family: qfont.semiBold.name
                color: textColor
            }

            Column {
                anchors {
                    left: parent.left
                    top: parent.top
                    topMargin: titleH
                }
                width: Math.min(parent.width, Math.round(340 * u))

                Repeater {
                    model: switchCount
                    delegate: Item {
                        readonly property int slot: app.activeSwitches[index]
                        width: parent.width
                        height: switchRowH

                        Text {
                            anchors {
                                left: parent.left
                                right: switchToggle.left
                                verticalCenter: parent.verticalCenter
                                rightMargin: gap
                            }
                            text: app.switchName(slot)
                            font.pixelSize: bodyFont
                            elide: Text.ElideRight
                            color: textColor
                        }

                        ToggleSwitch {
                            id: switchToggle
                            anchors {
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                            }
                            height: Math.min(Math.round(36 * u), switchRowH - 4)
                            width: Math.round(height * 1.5)
                            checked: app.switchOn(slot)
                            onToggled: app.setEntity(app.switchEntity(slot), !checked)
                        }
                    }
                }
            }
        }
    }

    //
    // Debug log overlay (only ever visible when app.debug is on)
    //

    Rectangle {
        id: logRect
        z: 100
        anchors.centerIn: parent
        width: parent.width - 2 * pad
        height: Math.min(300, parent.height - 2 * pad)
        radius: 10
        border.color: "#9e9e9e"
        border.width: 1
        color: "#f5f5f5"
        visible: app.debug && app.logShown
        clip: true

        Text {
            x: 15
            y: 10
            width: parent.width - 30
            text: app.message
            font.pixelSize: 10
            font.family: qfont.semiBold.name
            color: "#212121"
            wrapMode: Text.WordWrap
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                app.logShown = false;
                app.message = "";
            }
        }
    }
}
