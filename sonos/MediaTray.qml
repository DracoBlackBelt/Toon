import QtQuick 2.1

import qb.components 1.0
import qb.base 1.0

SystrayIcon {
	id: mediaSystrayIcon
	visible: app.showSonosIcon
	posIndex: 9000
	property string objectName: "sonosSystray"

	onClicked: {
		if (app.mediaScreen)	
			app.mediaScreen.show();
	}

	Image {
		id: imgNewMessage
		anchors.centerIn: parent
		source: "qrc:/tsc/SonosSystrayIcon.png"
	}
}

//created by Harmen Bartelink, modified by Toonz