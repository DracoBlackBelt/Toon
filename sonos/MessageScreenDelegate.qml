import QtQuick 2.1
import BasicUIControls 1.0
import qb.components 1.0

Rectangle
{
	width: isNxt ? 320 : 250
	height: isNxt ? 50 : 40
	color: colors.canvas
	property string kpiPrefix: "zoneSelectscreen"

	StandardButton {
		id: zoneButton
		controlGroup: zoneGroup
		width: isNxt ? 270 : 220
		height: isNxt ? 45 : 36
		radius: 5
		text: (app.messageSonosName == zoneName) ? zoneName + " (*)" : zoneName
		fontPixelSize: isNxt ? 25 : 20
		x: isNxt ? 25 : 20
		onClicked: {
			app.messageSonosName = zoneName;
			app.saveSettings();
		}
	}
}
