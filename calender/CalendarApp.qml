import QtQuick 2.1
import qb.components 1.0
import qb.base 1.0
import FileIO 1.0
import "calendarWorker.js" as CalendarWorker

// Application to show Google (and other) calendar ICS files on Toon
//
// The ICS files are downloaded in the interface thread (asynchronous, cheap) and then handed to a
// WorkerScript thread (calendarWorker.js) which parses them and expands the recurring appointments.
// The worker returns a sorted list of upcoming appointments; only the light work of filling the tile
// labels and the list screen is done in the interface thread, so the Toon stays responsive.

App {
	id: calendarApp

	property url tileUrl : "CalendarTile.qml"
	property CalendarListDatesScreen calendarListDatesScreen
	property url calendarListDatesScreenUrl : "CalendarListDatesScreen.qml"
	property CalendarConfigurationScreen calendarConfigurationScreen
	property url calendarConfigurationScreenUrl : "CalendarConfigurationScreen.qml"
	property url thumbnailIcon: "qrc:/tsc/calendar.png"

	// values to show on the tile for the next three appointments

	property string calendarDateNext1Label : "even geduld a.u.b"
	property string calendarDateNext1Time
	property string calendarDateNext1LabelDim : "even geduld a.u.b"
	property string calendarDateNext1DateDim
	property string calendarDateNext2Label
	property string calendarDateNext2Time
	property string calendarDateNext3Label
	property string calendarDateNext3Time
	property string calendarDate1Color
	property string calendarDate2Color
	property string calendarDate3Color
	property bool animationStarted : false

	// all upcoming appointments, sorted by start time, as delivered by the worker. Each entry has:
	// start, end (ms), allDay, cal (index of the calendar), flag ("(w)" etc), yearly, alarm (ms before start or null),
	// title, date ("yyyy-mm-dd"), time ("hh:mm"), endDate, endTime

	property var calendarEvents: []
	property string statusText: "even geduld a.u.b"	// shown on the list screen while loading or when nothing is found

	// other variables

	property double endDateFirstAppointment: 0	// ms, used to calculate the interval for the timer to trigger the next screen refresh
	property string textNotification		// text of notification to show
	property string showNotificationSetting : "Yes"	// parameters from the userSettings.json file
	property string showColorsSetting : "Yes"	// parameters from the userSettings.json file
	property string showAnimationSetting : "No"	// parameters from the userSettings.json file
	property string showDimTileExtended: "No"	// parameters from the userSettings.json file
	property int refreshIntervalInMinutes: 60	// parameters from the userSettings.json file
	property int horizonDays: 366			// how far ahead appointments are collected
	property int maxListItems: 224			// 14 pages of 16 on the list screen
	property variant calendarSettingsJson : {
		'ShowNotifications': "Yes",
		'ShowColors': "Yes",
		'DimTileExtended': "No",
		'RefreshIntervalInMinutes': 60,
		'Calendar_URL': ["https://calendar.google.com/calendar/ical/nl.dutch%23holiday%40group.v.calendar.google.com/public/basic.ics"]
	}

	// state of the current refresh cycle

	property int fetchSeq: 0			// incremented for every refresh, replies from older cycles are ignored
	property int numberOfCalendersToRead: 0		// calendars still being downloaded
	property var fetchedCalendars: []		// [{index, text}] downloaded so far
	property var pendingRequest: null		// request handed to the worker, kept for the fallback

	FileIO {
		id: userSettingsFile
		source: "file:///mnt/data/tsc/calendar.userSettings.json"
	}

	WorkerScript {
		id: calendarWorker
		source: "calendarWorker.js"
		onMessage: workerReply(messageObject)
	}

	function init() {
		registry.registerWidget("tile", tileUrl, this, null, {thumbLabel: "Kalender", thumbIcon: thumbnailIcon, thumbCategory: "general", thumbWeight: 30, baseTileWeight: 10, thumbIconVAlignment: "center"});
		registry.registerWidget("screen", calendarListDatesScreenUrl, this, "calendarListDatesScreen");
		registry.registerWidget("screen", calendarConfigurationScreenUrl, this, "calendarConfigurationScreen");
		notifications.registerType("kalender", notifications.prio_HIGHEST, Qt.resolvedUrl("qrc:/tsc/notification-update.svg"), calendarListDatesScreenUrl , {"categoryUrl": calendarListDatesScreenUrl }, "Kalender notificaties");
		notifications.registerSubtype("kalender", "herinnering", calendarListDatesScreenUrl , {"categoryUrl": calendarListDatesScreenUrl });
	}

	Component.onCompleted: {
		endFirstAppointmentTimer.start();	// kickoff timer for the first processing (delayed start of the app to allow Toon's to complete the boot process)
		midnightTimer.interval = getMSecTill12oclock();
		midnightTimer.start();
		readSettings();
	}

	function readSettings() {				// parse userSettings.json, keep the current values on a missing or corrupt file
		try {
			var json = JSON.parse(userSettingsFile.read());
			if ((json === null) || (typeof json !== "object") || (json instanceof Array)) {
				console.log("calendar: settings file is not a JSON object, keeping current settings");
				return;
			}
			calendarSettingsJson = json;
			if (calendarSettingsJson['ShowNotifications']) showNotificationSetting = calendarSettingsJson['ShowNotifications'];
			if (calendarSettingsJson['ShowColors']) showColorsSetting = calendarSettingsJson['ShowColors'];
			if (calendarSettingsJson['DimTileExtended']) showDimTileExtended = calendarSettingsJson['DimTileExtended'];
			if (calendarSettingsJson['ShowAnimation']) showAnimationSetting = calendarSettingsJson['ShowAnimation'];
			if (calendarSettingsJson['RefreshIntervalInMinutes']) refreshIntervalInMinutes = clampRefreshInterval(calendarSettingsJson['RefreshIntervalInMinutes']);
			if (!(calendarSettingsJson['Calendar_URL'] instanceof Array)) calendarSettingsJson['Calendar_URL'] = [];
		} catch(e) {
			console.log("calendar: could not read settings: " + e);
		}
	}

	function clampRefreshInterval(value) {			// the settings screen only allows 10-99 minutes, defend against hand-edited files
		var v = parseInt(value, 10);
		if (isNaN(v)) return 60;
		if (v < 10) return 10;
		if (v > 99) return 99;
		return v;
	}

	function sendNotification() {
		notifications.send("kalender", "herinnering", false, "Kalender herinnering: "+ textNotification, "category=herinnering");
	}

	function saveSettings() {				// writes back userSettings.json
 		var tmpcalendarSettingsJson = {
			"ShowNotifications" : showNotificationSetting,
			"ShowColors" : showColorsSetting,
			"ShowAnimation" : showAnimationSetting,
			"DimTileExtended" : showDimTileExtended,
			"RefreshIntervalInMinutes" : refreshIntervalInMinutes,
			"Calendar_URL" : calendarSettingsJson['Calendar_URL']
		}
  		var doc3 = new XMLHttpRequest();
   		doc3.open("PUT", "file:///mnt/data/tsc/calendar.userSettings.json");
   		doc3.send(JSON.stringify(tmpcalendarSettingsJson));
	}

	function startOrRefresh() {				// called by 'Verversen' button on screen
		endFirstAppointmentTimer.stop();
		readCalendars();
	}

	// ---------------------------------------------------------------------------------------------
	// step 1: download all calendars

	function readCalendars() {

		readSettings();		// re-read settings (URL's can be changed in the mean time by the user)

		fetchSeq = fetchSeq + 1;
		fetchTimeoutTimer.stop();
		workerWatchdog.stop();
		fetchedCalendars = [];
		pendingRequest = null;

		// clear tile labels

		calendarDateNext1Label = "ophalen kalenders";
		calendarDateNext1LabelDim = "ophalen kalenders";
		calendarDateNext1Time = "";
		calendarDateNext1DateDim = "";
		calendarDateNext2Label = "";
		calendarDateNext2Time = "";
		calendarDateNext3Label = "";
		calendarDateNext3Time = "";
		statusText = "ophalen kalenders";

		var urls = calendarSettingsJson['Calendar_URL'];
		numberOfCalendersToRead = urls.length;
		if (numberOfCalendersToRead === 0) {
			applyEvents([]);
			return;
		}
		for (var i = 0; i < urls.length; i++) {
			fetchCalendar(urls[i], i, fetchSeq);
		}
		fetchTimeoutTimer.start();	// continue with what we have when a calendar server does not answer
	}

	function fetchCalendar(calendarURL, indexCal, seq) {
		var xmlhttp = new XMLHttpRequest();
		xmlhttp.onreadystatechange = function() {
			if (xmlhttp.readyState !== XMLHttpRequest.DONE) return;
			if (seq !== fetchSeq) return;		// a newer refresh has started in the meantime
			if (xmlhttp.status === 200 && xmlhttp.responseText.length > 0) {
				fetchedCalendars.push({"index": indexCal, "text": xmlhttp.responseText});
			} else {
				console.log("calendar: failed to download calendar " + indexCal + " (http status " + xmlhttp.status + ")");
			}
			numberOfCalendersToRead = numberOfCalendersToRead - 1;
			if (numberOfCalendersToRead <= 0) startProcessing();
		}
		xmlhttp.open("GET", calendarURL, true);
		xmlhttp.send();
	}

	// ---------------------------------------------------------------------------------------------
	// step 2: parse and expand in the worker thread

	function startProcessing() {
		fetchTimeoutTimer.stop();
		statusText = "verwerken kalenders";
		pendingRequest = {
			"seq": fetchSeq,
			"nowMs": new Date().getTime(),
			"horizonDays": horizonDays,
			"maxItems": maxListItems,
			"calendars": fetchedCalendars
		};
		fetchedCalendars = [];
		workerWatchdog.start();
		calendarWorker.sendMessage(pendingRequest);
	}

	function workerReply(reply) {
		if (reply.seq !== fetchSeq) return;	// result of an old refresh
		workerWatchdog.stop();
		if (reply.error) {
			console.log("calendar: worker failed (" + reply.error + "), processing in the interface thread");
			processInInterfaceThread();
			return;
		}
		console.log("calendar: " + reply.info);
		pendingRequest = null;
		applyEvents(reply.events);
	}

	function processInInterfaceThread() {		// fallback when the WorkerScript is not available
		if (!pendingRequest) return;
		var request = pendingRequest;
		pendingRequest = null;
		try {
			var result = CalendarWorker.processCalendars(request);
			console.log("calendar (fallback): " + result.info);
			applyEvents(result.events);
		} catch (e) {
			console.log("calendar: processing failed: " + e);
			applyEvents([]);
		}
	}

	// ---------------------------------------------------------------------------------------------
	// step 3: fill the tile, notifications and timers from the list of upcoming appointments

	function applyEvents(events) {
		calendarEvents = events;
		processCollectedCalendarDates();
	}

	function upcomingEvents() {			// appointments in calendarEvents which have not ended yet
		var now = new Date().getTime();
		var result = [];
		for (var i = 0; i < calendarEvents.length; i++) {
			if (calendarEvents[i].end > now) result.push(calendarEvents[i]);
		}
		return result;
	}

	function dayMonth(dateStr) {			// "yyyy-mm-dd" -> "dd-mm"
		return dateStr.slice(8, 10) + "-" + dateStr.slice(5, 7);
	}

	function tileLabel(ev) {
		return dayMonth(ev.date) + ": " + ev.flag + ev.title;
	}

	function timeText(ev) {				// time line for tile and list screen
		if (ev.allDay) {
			if (ev.endDate !== ev.date) return "t/m " + dayMonth(ev.endDate);
			return " ";
		}
		return ev.time + " - " + ev.endTime;
	}

	function colorForEvent(ev) {
		return colorCodes(ev.cal > 9 ? "9" : ev.cal.toString());
	}

	function processCollectedCalendarDates() {

		var now = new Date().getTime();
		var events = upcomingEvents();
		var i, ev;

		// tile labels for the first three appointments

		calendarDateNext1Label = "geen afspraken";
		calendarDateNext1LabelDim = "geen afspraken";
		calendarDateNext1Time = "";
		calendarDateNext1DateDim = "";
		calendarDateNext2Label = "";
		calendarDateNext2Time = "";
		calendarDateNext3Label = "";
		calendarDateNext3Time = "";
		statusText = (events.length === 0) ? "geen afspraken gevonden" : "";
		endDateFirstAppointment = 0;

		if (events.length > 0) {
			ev = events[0];
			calendarDate1Color = colorForEvent(ev);
			calendarDateNext1Label = tileLabel(ev);
			calendarDateNext1Time = timeText(ev);
			calendarDateNext1LabelDim = ev.title.length > 20 ? ev.title.slice(0, 20) + "..." : ev.title;
			calendarDateNext1DateDim = formatCalendarDateTile(ev.date);
			endDateFirstAppointment = ev.end;
		}
		if (events.length > 1) {
			ev = events[1];
			calendarDate2Color = colorForEvent(ev);
			calendarDateNext2Label = tileLabel(ev);
			calendarDateNext2Time = timeText(ev);
		}
		if (events.length > 2) {
			ev = events[2];
			calendarDate3Color = colorForEvent(ev);
			calendarDateNext3Label = tileLabel(ev);
			calendarDateNext3Time = timeText(ev);
		}

		// earliest reminder within the next 6 hours (a later one is picked up by the next refresh)

		notificationsTimer.stop();
		var notificationAt = now + 21600000;
		textNotification = "";
		for (i = 0; i < events.length; i++) {
			ev = events[i];
			if (ev.alarm === null || ev.alarm === undefined) continue;
			var fireAt = ev.start + ev.alarm;
			if (fireAt > now && fireAt < notificationAt) {
				notificationAt = fireAt;
				textNotification = ev.title;
			}
		}
		if (textNotification !== "" && showNotificationSetting == "Yes") {
			notificationsTimer.interval = Math.max(1000, notificationAt - now);
			notificationsTimer.start();
		}

		// balloons on days with a yearly (birthday) appointment

		startAnimationTimer.stop();
		var balloonsNow = false;
		for (i = 0; i < events.length; i++) {
			ev = events[i];
			if (!ev.yearly || !ev.allDay) continue;
			if (ev.start <= now) {
				balloonsNow = true;
			} else if (ev.start - now < 2000000000) {	// timer interval must fit in an int, midnight refresh covers the rest
				startAnimationTimer.interval = ev.start - now;
				startAnimationTimer.start();
			}
			break;		// events are sorted, so this was the first yearly one
		}
		if (showAnimationSetting == "Yes" && balloonsNow) {
			startBalloons();
		} else if (animationStarted) {		// switch off animation if we started it before
			animationscreen.animationRunning = false;
			animationStarted = false;
		}

		endFirstAppointmentTimer.interval = getMSecTillEndTimeNextAppointment();
		endFirstAppointmentTimer.start();

		console.log("calendar: " + events.length + " upcoming, tile: [" + calendarDateNext1Label + " " + calendarDateNext1Time + "] [" + calendarDateNext2Label + " " + calendarDateNext2Time + "] [" + calendarDateNext3Label + " " + calendarDateNext3Time + "], dim: " + calendarDateNext1DateDim + ", next refresh in " + Math.round(endFirstAppointmentTimer.interval / 60000) + " min");
	}

	function startBalloons() {
		animationscreen.qmlAnimationURL = "https://raw.githubusercontent.com/ToonSoftwareCollective/toonanimations/master/Balloon.qml";
		animationscreen.animationInterval = isNxt ? 4500 : 10000;
		animationscreen.isVisibleinDimState = true;
		animationscreen.animationRunning = true;
		animationStarted = true;
	}

	function colorCodes(colorStr) {
		switch (colorStr) {
			case "0": return "#FF0000";
			case "1": return "#00FF00";
			case "2": return "#0000FF";
			case "3": return "#FFFF00";
			case "4": return "#00FFFF";
			case "5": return "#FF00FF";
			case "6": return "#008000";
			case "7": return "#000080";
			case "8": return "#800000";
			case "9": return "#800080";
			default: return "#808080";
		}
	}

	function fullMonth(monthNum) {			// convert the month number to long description for the tile in dim state
		switch (monthNum) {
			case "01": return "januari";
			case "02": return "februari";
			case "03": return "maart";
			case "04": return "april";
			case "05": return "mei";
			case "06": return "juni";
			case "07": return "juli";
			case "08": return "augustus";
			case "09": return "september";
			case "10": return "oktober";
			case "11": return "november";
			case "12": return "december";
			default: break;
		}
		return "error_month";
	}

		// format dates as yyyy-mm-dd

	function formatDate(date) {
    		var d = new Date(date),
        	month = '' + (d.getMonth() + 1),
        	day = '' + d.getDate(),
        	year = d.getFullYear();
		if (month.length < 2) month = '0' + month;
		if (day.length < 2) day = '0' + day;
		return [year, month, day].join('-');
	}

		// display next appointment date as 'morgen', 'overmorgen' or 'vandaag' on the tile in dim state

	function formatCalendarDateTile(dateyymmdd) {
		var today = new Date();
		var todayPlus1Date = new Date(today.getFullYear(), today.getMonth(), today.getDate() + 1, 12, 0, 0);
		var todayPlus2Date = new Date(today.getFullYear(), today.getMonth(), today.getDate() + 2, 12, 0, 0);
		var inputDate = new Date(dateyymmdd.slice(0,4), parseInt(dateyymmdd.slice(5,7), 10) - 1, dateyymmdd.slice(8,10), 11, 0, 0);

		if (dateyymmdd <= formatDate(today)) {
			return "Vandaag";
		} else if (dateyymmdd == formatDate(todayPlus1Date)) {
			return "Morgen";
		} else if (dateyymmdd == formatDate(todayPlus2Date)) {
			return "Overmorgen";
		} else {
			return i18n.daysExtraShort[inputDate.getDay()] + " " + dateyymmdd.slice(8,10) + " " + fullMonth(dateyymmdd.slice(5,7));
		}
	}

	/// calculates miliseconds till end date of next appointment (to refresh the tile and calendar file)

	function getMSecTillEndTimeNextAppointment() {
		var now = new Date().getTime();
		var maxInterval = 60000 * refreshIntervalInMinutes;	// at least refresh every refresh cycle
		if (endDateFirstAppointment === 0 || (endDateFirstAppointment - now) > maxInterval) {
			return maxInterval;
		}
		if ((endDateFirstAppointment - now) < 300000) {
			return 300000;	// minimal refresh interval is 5 minutes
		}
		return endDateFirstAppointment - now + 1000;
	}

		// calculates miliseconds till 00:00:02 to update date label on the tile in dim state

	function getMSecTill12oclock() {
		var now = new Date();
		var twelveOclock = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1, 0, 0, 2, 0);
		return Math.max(1000, twelveOclock.getTime() - now.getTime());
	}

		// timer to start the balloons when a yearly all-day appointment starts

	Timer {
		id: startAnimationTimer
		repeat: false
		running: false
		onTriggered: {
			if (showAnimationSetting == "Yes") startBalloons();
		}
	}

		// timer to refresh data when first appointment has ended

	Timer {
		id: endFirstAppointmentTimer		// timer is started in the onCompleted() function, after that when first appointment is ending or every refresh cycle
		repeat: false
		running: false
		interval: isNxt ? 20000 : 150000	//wait 20 sec (Toon 2) or 150 sec (Toon 1) after reboot before reading ics file for the first time
		onTriggered: {
			readCalendars();		//get new calender update
		}
	}

		// timer to show first notification

	Timer {
		id: notificationsTimer
		repeat: false
		running: false
		onTriggered: {
			sendNotification();
		}
	}

		// timer to refresh labels at midnight (especially for the date label in dimstate (vandaag, morgen, overmorgen)

	Timer {
		id: midnightTimer
		repeat: false
		running: false
		onTriggered: {
			processCollectedCalendarDates();
			interval = getMSecTill12oclock();
			start();
		}
	}

		// a calendar server that does not answer should not block the others

	Timer {
		id: fetchTimeoutTimer
		repeat: false
		running: false
		interval: 90000
		onTriggered: {
			console.log("calendar: timeout, " + numberOfCalendersToRead + " calendar(s) not downloaded");
			numberOfCalendersToRead = 0;
			startProcessing();
		}
	}

		// when the worker thread does not answer, process in the interface thread instead

	Timer {
		id: workerWatchdog
		repeat: false
		running: false
		interval: 120000
		onTriggered: {
			console.log("calendar: no answer from the worker thread, processing in the interface thread");
			processInInterfaceThread();
		}
	}
}
