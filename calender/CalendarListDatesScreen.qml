import QtQuick 2.1
import qb.components 1.0

Screen {
	id: calendarListDatesScreen
	screenTitle: "Kalender"

	property int itemsPerPage: 16
	property int currentPage: 0

	onShown: {
		addCustomTopRightButton("Instellingen");
		navigatePage(0);		// populate gridview first page
	}

		// refresh the list when new calendar data arrives while the screen is open

	Connections {
		target: app
		onCalendarEventsChanged: if (calendarListDatesScreen.visible) navigatePage(currentPage)
		onStatusTextChanged: if (calendarListDatesScreen.visible) statusLabel.text = app.statusText
	}

	function navigatePage(page) {

		var events = app.upcomingEvents();
		var pageCount = Math.max(1, Math.ceil(events.length / itemsPerPage));
		if (page >= pageCount) page = pageCount - 1;
		if (page < 0) page = 0;
		currentPage = page;

		calendarModel.clear();
		for (var i = page * itemsPerPage; i < events.length && i < (page + 1) * itemsPerPage; i++) {
			var ev = events[i];
			calendarModel.append({appointmentDate: ev.date, appointmentTitle: ev.flag + ev.title, appointmentColor: app.colorForEvent(ev), appointmentTime: app.timeText(ev)});
		}
		widgetNavBar.pageCount = pageCount;
		statusLabel.text = app.statusText;
	}

	onCustomButtonClicked: {
		if (app.calendarConfigurationScreen) {
			 app.calendarConfigurationScreen.show();
		}
	}

	hasBackButton : true

	Rectangle {
		id: gridBack
		height: isNxt ? 480 : 384
		width: isNxt ? 984 : 760
		anchors {
			top: parent.top
			topMargin: isNxt ? 45 : 36
			left: parent.left
			leftMargin: 20
		}
       		visible: true
	}

	GridView {
		id: calendarListView

		model: 	calendarModel
		delegate: CalendarListDatesScreenDelegate {}
		cellWidth: gridBack.width / 2
		cellHeight: isNxt ? 60 : 48

		interactive: false
		flow: GridView.TopToBottom

		anchors {
			fill: gridBack
		}
	}

	ListModel {
		id: calendarModel
	}

		// message while loading or when there are no appointments

	Text {
		id: statusLabel
		anchors {
			top: gridBack.top
			topMargin: isNxt ? 30 : 24
			horizontalCenter: gridBack.horizontalCenter
		}
		font {
			family: qfont.regular.name
			pixelSize: isNxt ? 22 : 18
		}
		visible: text.length > 0
	}

	StandardButton {
		id: btnRefreshCalendars
		width: isNxt ? 125 : 100
		text: "Verversen"
		anchors.right: gridBack.right
		anchors.bottom: gridBack.top
		anchors.bottomMargin: 5
		leftClickMargin: 3
		bottomClickMargin: 5
		onClicked: {
			app.startOrRefresh();
		}
	}

	DottedSelector {
		id: widgetNavBar
		width: isNxt ? 625 : 500
		anchors {
			horizontalCenter: parent.horizontalCenter
			bottom: gridBack.top
		}
		maxPageCount: 14
		pageCount: 1
		onNavigate: navigatePage(page)
	}

}
