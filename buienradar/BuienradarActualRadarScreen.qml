import QtQuick 2.1
import qb.components 1.0

Screen {
	id: buienradarActualRadarScreen

	screenTitle: qsTr("Actuele Buienradar");
	property variant rightNow
	property string todayStr
	property string todayStrFormatted
	property string currentHours

	onCustomButtonClicked: {
		if (app.buienradarEditLonLatScreen) {
			app.buienradarEditLonLatScreen.show();
		}
	}

	onShown: {
		addCustomTopRightButton(qsTr("Locatie"));
		stillRadarImage.visible = false;
		bigRadarImage.visible = true;

		rightNow = new Date();
		todayStr = zfill4(rightNow.getFullYear()) + zfill2(rightNow.getMonth() + 1) + zfill2(rightNow.getDate());
		todayStrFormatted = todayStr.substring(0,4) + "-" + todayStr.substring(4,6) + "-" + todayStr.substring(6,8) 
		currentHours = rightNow.getHours();
		if (currentHours < 10)  currentHours = '0' + currentHours;
	}

	function zfill4(n) {
		var s = "" + n;
		while (s.length < 4) s = "0" + s;
		return s;
	}

	function zfill2(n) {
		return (n < 10 ? "0" : "") + n;
	}


	Rectangle {
		id:bigRadarImage
		width: isNxt ? 600 : 400
		height: isNxt ? 600 : 400
		anchors {
			baseline: parent.top
			left: parent.left
			leftMargin: 50
		}
		visible: true
   		AnimatedImage { id: animation; source: app.radarimagesurl }
	}

	Image {
		id: stillRadarImage
		source: app.stillimagesurl
		anchors {
			baseline: parent.top
			left: parent.left
			leftMargin: 50
		}
		height: isNxt ? 494 : 380    // original: 820 x 988
		width: isNxt ? 410 : 315 
		visible: false
	}

	StandardButton {
		id: btnBuienradar
		width: isNxt ? 350 : 305
		text: "Buienradar"
		anchors {
			baseline: parent.top
			left: parent.left
			leftMargin: isNxt ? 660 : 475
		}
		onClicked: {
			stillRadarImage.visible = false;
			bigRadarImage.visible = true;
			app.radarimagesurl = "http://toon/";  //resetimage
			if (isNxt) {
				app.radarimagesurl = "https://api.buienradar.nl/image/1.0/RadarMapNL?width=600&height=600";
			} else {
				app.radarimagesurl = "https://api.buienradar.nl/image/1.0/RadarMapNL?width=400&height=400";
			}
			setTitle(qsTr("Actuele Buienradar"));
		}
	}

	StandardButton {
		id: btnUVindexradar
		width: isNxt ? 350 : 305
		text: qsTr("UV index")
		anchors {
			top: btnBuienradar.bottom
			topMargin: 10
			left: btnBuienradar.left
		}
		onClicked: {
			stillRadarImage.visible = true;
			bigRadarImage.visible = false;
			app.stillimagesurl = "https://processing-cdn.buienradar.nl/processing/nl/weathermaps/uvindex/default/" + todayStr + ".png";
			setTitle(qsTr("UV index vandaag"));
		}
	}

	StandardButton {
		id: btnMuggenradar
		width: isNxt ? 350 : 305
		text: qsTr("Muggenradar")
		anchors {
			top: btnUVindexradar.bottom
			topMargin: 10
			left: btnBuienradar.left
		}
		onClicked: {
			setTitle(qsTr("Muggenradar vandaag"));
			stillRadarImage.visible = true;
			bigRadarImage.visible = false;
			app.stillimagesurl = "https://processing-cdn.buienradar.nl/processing/nl/weathermaps/mosquitoradar/default/" + todayStr + ".png";
		}
	}

	StandardButton {
		id: btnPollenradar
		width: isNxt ? 350 : 305
		text: qsTr("Pollenradar")
		anchors {
			top: btnMuggenradar.bottom
			topMargin: 10
			left: btnMuggenradar.left
		}
		onClicked: {
			stillRadarImage.visible = true;
			bigRadarImage.visible = false;
			app.stillimagesurl = "https://processing-cdn.buienradar.nl/processing/nl/weathermaps/pollenradar/default/" + todayStr + ".png";
			setTitle(qsTr("Pollenradar vandaag"));
		}
	}

	StandardButton {
		id: btnActueleTemperatuur
		width: isNxt ? 350 : 305
		text: qsTr("Actuele Temperatuur")
		anchors {
			top: btnPollenradar.bottom
			topMargin: 10
			left: btnPollenradar.left
		}
		onClicked: {
			stillRadarImage.visible = true;
			bigRadarImage.visible = false;
			app.stillimagesurl = "https://processing-cdn.buienradar.nl/processing/nl/weathermaps/Temperature/default/" + todayStr + currentHours + "00.png";
			setTitle(qsTr("Actuele temperatuur op ") + "  " + todayStrFormatted + "  " + currentHours + ":00"); 
		}
	}

	StandardButton {
		id: btnMinTemperatuur
		width: isNxt ? 100 : 80
		text: qsTr("Minimum")
		anchors {
			top: btnActueleTemperatuur.bottom
			topMargin: 10
			left: btnActueleTemperatuur.left
		}
		onClicked: {
			stillRadarImage.visible = true;
			bigRadarImage.visible = false;
			app.stillimagesurl = "https://processing-cdn.buienradar.nl/processing/nl/weathermaps/Mintemperature/default/" + todayStr + currentHours + "00.png";
			setTitle(qsTr("Minimum temperatuur vandaag")); 
		}
	}

	StandardButton {
		id: btnMaxTemperatuur
		width: isNxt ? 240 : 215
		text: qsTr("Maximum Temperatuur")
		anchors {
			top: btnActueleTemperatuur.bottom
			topMargin: 10
			left: btnMinTemperatuur.right
			leftMargin: 10
		}
		onClicked: {
			stillRadarImage.visible = true;
			bigRadarImage.visible = false;
			app.stillimagesurl = "https://processing-cdn.buienradar.nl/processing/nl/weathermaps/Maxtemperature/default/" + todayStr + currentHours + "00.png";
			setTitle(qsTr("Maximum temperatuur vandaag"));
		}
	}

	StandardButton {
		id: btnActueleWind
		width: isNxt ? 350 : 305
		text: qsTr("Actuele Windkracht")
		anchors {
			top: btnMinTemperatuur.bottom
			topMargin: 10
			left: btnMinTemperatuur.left
		}
		onClicked: {
			stillRadarImage.visible = true;
			bigRadarImage.visible = false;
			app.stillimagesurl = "https://processing-cdn.buienradar.nl/processing/nl/weathermaps/WindspeedBft/default/" + todayStr + currentHours + "00.png";
			setTitle(qsTr("Actuele windkracht op ") + "  " + todayStrFormatted + "  " + currentHours + ":00"); 
		}
	}

	StandardButton {
		id: btnMinimumGroundTemp
		width: isNxt ? 350 : 305
		text: qsTr("Minimum grondtemperatuur")
		anchors {
			top: btnActueleWind.bottom
			topMargin: 10
			left: btnActueleWind.left
		}
		onClicked: {
			stillRadarImage.visible = true;
			bigRadarImage.visible = false;
			app.stillimagesurl = "https://processing-cdn.buienradar.nl/processing/nl/weathermaps/Mingroundtemperature/default/" + todayStr + currentHours + "00.png";
			setTitle(qsTr("Minimum grondtemperatuur vandaag"));
		}
	}
}
