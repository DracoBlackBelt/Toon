import QtQuick 2.1
import qb.components 1.0
import BxtClient 1.0

Screen {
	id: wasteConfigurationScreen

	property url calendarIndexUrl : "https://raw.githubusercontent.com/ToonSoftwareCollective/calendar_public_calendars/main/public_calendars.json"

	screenTitle: "Kalender configuratie"

	onShown: {
		addCustomTopRightButton("Opslaan");
		enableNotificationsToggle.isSwitchedOn = (app.showNotificationSetting == "Yes");
		enableColorsToggle.isSwitchedOn = (app.showColorsSetting == "Yes");
		enableAnimationToggle.isSwitchedOn = (app.showAnimationSetting == "Yes");
		enableDimExtendedToggle.isSwitchedOn = (app.showDimTileExtended == "Yes");
		refreshIntervalLabel.inputText = app.refreshIntervalInMinutes;
		getPublicCalendars()
	}

	function getPublicCalendars(){

		//get list of public calendars (the configured calendars are always shown, even when this fetch fails)

		var http = new XMLHttpRequest();
		http.onreadystatechange=function() {
			if (http.readyState === 4){
				if (http.status === 200) {
					var tmpArray = [];
					try {
						var availableCalendars = JSON.parse(http.responseText);
						if ((availableCalendars !== null) && (typeof availableCalendars === "object") && (availableCalendars.public_calendars instanceof Array)) {
							tmpArray = availableCalendars.public_calendars;
						}
					} catch(e) {
						tmpArray = [];		// bad json from the index: show configured calendars only
					}
					fillUrlModel(tmpArray);
				} else {
					fillUrlModel(null);		// offline or error: still show the configured calendars instead of a stale/empty list
				}
			}
		}
		http.open("GET",calendarIndexUrl, true)
		http.send()
	}

	function fillUrlModel(publicCalendars) {

		// (re)build the list model: configured calendars first, then the public ones not yet added, colors continue per index

		urlModel.clear();

		var urls = app.calendarSettingsJson['Calendar_URL'];
		if (!(urls instanceof Array)) {
			urls = [];
		}
		var nextColor = urls.length;

		for (var i = 0; i < urls.length; i++) {
			var friendlyName  = "-";
			if (publicCalendars) {
				for (var k = 0; k < publicCalendars.length; k++) {
					if (publicCalendars[k].link == urls[i]) {
						friendlyName = publicCalendars[k].friendlyName;
					}
				}
			}
			urlModel.append({urlName: urls[i], urlFriendlyName: friendlyName, urlColor: app.colorCodes(colorStrForIndex(i)), urlAlreadyAdded: true});
		}

		if (publicCalendars) {
			for (var p = 0; p < publicCalendars.length; p++) {
				if (urls.indexOf(publicCalendars[p].link) < 0) {
					urlModel.append({urlName: publicCalendars[p].link, urlFriendlyName: publicCalendars[p].friendlyName, urlColor: app.colorCodes(colorStrForIndex(nextColor)), urlAlreadyAdded: false});
					nextColor = nextColor + 1;
				}
			}
		}
	}

	function colorStrForIndex(index) {		// calendars beyond the tenth share the last color

		if (index > 9) {
			return "9";
		}
		return index.toString();
	}

	onCustomButtonClicked: {
		hide();
		app.saveSettings();
	}

	function saveRefreshIntervalLabel(text) {

		if (text) {
			app.refreshIntervalInMinutes = parseInt(text);
			refreshIntervalLabel.inputText = app.refreshIntervalInMinutes;
		}
	}


	function validateRefreshIntervalLabel(text, isFinalString) {
		if (isFinalString) {
			if (parseInt(text) > 9)
				return null;
			else
				return {title: "Ongeldige invoer", content: "aantal minuten moet minimaal 10 zijn"};
		}
		return null;
	}


	Text {
		id: enableNotificationsLabel
		width: isNxt ? 400 : 320
		height: isNxt ? 44 : 35
		text: "Herinneringen weergeven als notificaties?"
		anchors {
			left: parent.left
			leftMargin : 10
			top: parent.top
			topMargin : 30
		}
		font {
			family: qfont.regular.name
			pixelSize: isNxt ? 20 : 15		}
	}

	OnOffToggle {
		id: enableNotificationsToggle
		height: isNxt ? 45 : 36
		anchors.left: enableNotificationsLabel.right
		anchors.leftMargin: 10
		anchors.top: enableNotificationsLabel.top
		leftIsSwitchedOn: false
		onSelectedChangedByUser: {
			if (isSwitchedOn) {
				app.showNotificationSetting = "Yes"
			} else {
				app.showNotificationSetting = "No"
			}
		}
	}

	Text {
		id: enableColorsLabel
		width: isNxt ? 400 : 320
		height: isNxt ? 44 : 35
		text: "Kalenderkleuren weergeven bij afspraken?"
		anchors {
			left: enableNotificationsToggle.right
			leftMargin: isNxt ? 15 : 12
			top: enableNotificationsLabel.top
		}
		font {
			family: qfont.regular.name
			pixelSize: isNxt ? 20 : 15		}
	}

	OnOffToggle {
		id: enableColorsToggle
		height: isNxt ? 45 : 36
		anchors.left: enableColorsLabel.right
		anchors.leftMargin: 10
		anchors.top: enableColorsLabel.top
		leftIsSwitchedOn: false
		onSelectedChangedByUser: {
			if (isSwitchedOn) {
				app.showColorsSetting = "Yes"
			} else {
				app.showColorsSetting = "No"
			}
		}
	}

	Text {
		id: enableDimExtendedLabel
		width: isNxt ? 400 : 320
		height: isNxt ? 44 : 35
		text: "Drie regels op tegel in dim stand?"
		anchors {
			left: enableNotificationsLabel.left
			top: enableNotificationsLabel.bottom
			topMargin : 10
		}
		font {
			family: qfont.regular.name
			pixelSize: isNxt ? 20 : 15		}
	}

	OnOffToggle {
		id: enableDimExtendedToggle
		height: isNxt ? 45 : 36
		anchors.left: enableDimExtendedLabel.right
		anchors.leftMargin: 10
		anchors.top: enableDimExtendedLabel.top
		leftIsSwitchedOn: false
		onSelectedChangedByUser: {
			if (isSwitchedOn) {
				app.showDimTileExtended = "Yes"
			} else {
				app.showDimTileExtended = "No"
			}
		}
	}

	Text {
		id: enableAnimationLabel
		width: isNxt ? 400 : 320
		height: isNxt ? 44 : 35
		text: "Ballonnen tonen (jaarlijks)?"
		anchors {
			left: enableDimExtendedToggle.right
			top: enableDimExtendedLabel.top
			leftMargin: isNxt ? 15 : 12
		}
		font {
			family: qfont.regular.name
			pixelSize: isNxt ? 20 : 15		}
	}

	OnOffToggle {
		id: enableAnimationToggle
		height: isNxt ? 45 : 36
		anchors.left: enableAnimationLabel.right
		anchors.leftMargin: 10
		anchors.top: enableAnimationLabel.top
		leftIsSwitchedOn: false
		onSelectedChangedByUser: {
			if (isSwitchedOn) {
				app.showAnimationSetting = "Yes"
			} else {
				app.showAnimationSetting = "No"
				if (app.animationStarted) {  // switch off animation if we started it before
   					animationscreen.animationRunning= false;
					app.animationStarted = false;
				}
			}
		}
	}

	EditTextLabel4421 {
		id: refreshIntervalLabel
		width: isNxt ? 575 : 460
		height: isNxt ? 44 : 35
		leftTextAvailableWidth: isNxt ? 500 : 400
		leftText: "Ververs interval in minuten:"

		anchors {
			left: enableDimExtendedLabel.left
			top: enableDimExtendedLabel.bottom
			topMargin : 10
		}

		onClicked: {
			qnumKeyboard.open("Voer het aantal minuten in:", refreshIntervalLabel.inputText, refreshIntervalLabel, 1 , saveRefreshIntervalLabel, validateRefreshIntervalLabel);
			qnumKeyboard.maxTextLength = 2;
			qnumKeyboard.state = "num_integer_clear_backspace";
		}
	}

	Text {
		id: urlListLabel
		text: "Beschikbare kalenders:"
		anchors {
			left: refreshIntervalLabel.left
			top: refreshIntervalLabel.bottom
			topMargin : 30
		}
		font {
			family: qfont.bold.name
			pixelSize: isNxt ? 20 : 15		}
	}

	Rectangle {
		id: gridBack
		height: isNxt ? 265 : 210
		width: isNxt ? 1000 : 780
		color: "#FFFFFF"
		anchors {
			top: urlListLabel.bottom
			topMargin: 20
			left: urlListLabel.left
		}
       		visible: true
	}

	GridView {
		id: urlListGridView

		model: urlModel
		delegate: CalendarConfigurationScreenDelegate {}

		cellWidth: isNxt ? 500 : 400
		cellHeight: isNxt ? 50 : 40

		interactive: false
		flow: GridView.TopToBottom

		anchors {
			fill: gridBack
			topMargin: 10
			leftMargin: 10
		}
	}

	ListModel {
		id: urlModel
	}
}
