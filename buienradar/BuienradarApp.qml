import QtQuick 2.1
import qb.components 1.0
import qb.base 1.0
import FileIO 1.0
import "buienradar.js" as BuienradarJS

App {
	id: buienradarApp
	objectName: "BuienradarApp"

		// default weerstation after cold boot if no saved location exists	
	property string location : "6344";
		// default coordinates voor 2-uurs regenradardata if no saved location exists
	property string lat : "52.21"
	property string lon : "4.53"

	property url tileUrl : "BuienradarTile.qml"
	property url tileUrlRegen : "BuienradarRegenTile.qml"
	property url tileSunrise : "BuienradarSunriseTile.qml"
	property url thumbnailIcon: "qrc:/tsc/buienradar.png"
	property BuienradarDetailsScreen buienradarDetailsScreen
	property BuienradarStationScreen buienradarStationScreen
	property BuienradarActualRadarScreen buienradarActualRadarScreen
	property BuienradarEditLonLatScreen buienradarEditLonLatScreen
	property BuienradarFullWeatherForecastScreen buienradarFullWeatherForecastScreen
	property string timeStr

	property string locationName
	property variant regenVerwachting : []
	property string regenVerwachtingVanaf
	property string regenVerwachtingMidden
	property string regenVerwachtingTot
	property real regenMaxValue
	property bool showRain : false
	property variant stationArray : []
	property variant locationArray : []
	property int indexStation
	property variant latArray : []
	property variant lonArray : []

	property string temperatuurGC
	property string gevoelstemperatuur
	property string windsnelheidBF
	property string windsnelheidMS
	property string windrichting
	property string icoonlink
	property string icoonid
	property string icoonzin
	property string icoonimageDim
	property string luchtvochtigheid
	property string luchtdruk
	property string zichtmeters
	property string weersverwachtingTitel
	property string weersverwachtingTekst
	property string datumupdate
	property string stillimagesurl
	property string radarimagesurl
	property string radarimagesSmallurl
	property string zonopkomst
	property string zononder

	property variant fivedayforecast: []
	property variant actualweather: []

	// user settings from config file
	property variant buienradarSettingsJson : {}

	FileIO {
		id: buienradarSettingsFile
		source: "file:///mnt/data/tsc/buienradar.userSettings.json"
 	}

	QtObject {
		id: p

		property url buienradarDetailsScreenUrl : "BuienradarDetailsScreen.qml"
		property url buienradarStationScreenUrl : "BuienradarStationScreen.qml"
		property url buienradarActualRadarScreenUrl : "BuienradarActualRadarScreen.qml"
		property url buienradarEditLonLatScreenUrl : "BuienradarEditLonLatScreen.qml"
		property url buienradarFullWeatherForecastScreenUrl : "BuienradarFullWeatherForecastScreen.qml"
		property url buienradarMenuUrl   : "BuienradarMenu.qml"
		property url buienradarTrayUrl: "BuienradarTray.qml"

		property variant pendingBuienradar: null
		property variant pendingRegenkans: null
	}

	
	function init() {
		registry.registerWidget("tile", tileUrl, this, null, {thumbLabel: qsTr("Buienradar"), thumbIcon: thumbnailIcon, thumbCategory: "general", thumbWeight: 30, baseTileWeight: 10, thumbIconVAlignment: "center"});
		registry.registerWidget("tile", tileUrlRegen, this, null, {thumbLabel: qsTr("Regenverw."), thumbIcon: thumbnailIcon, thumbCategory: "general", thumbWeight: 30, baseTileWeight: 10, thumbIconVAlignment: "center"});
		registry.registerWidget("tile", tileSunrise, this, null, {thumbLabel: qsTr("Zon op/onder"), thumbIcon: thumbnailIcon, thumbCategory: "general", thumbWeight: 30, baseTileWeight: 10, thumbIconVAlignment: "center"});
		registry.registerWidget("screen", p.buienradarDetailsScreenUrl, this, "buienradarDetailsScreen");
		registry.registerWidget("screen", p.buienradarStationScreenUrl, this, "buienradarStationScreen");
		registry.registerWidget("screen", p.buienradarActualRadarScreenUrl, this, "buienradarActualRadarScreen");
		registry.registerWidget("screen", p.buienradarEditLonLatScreenUrl, this, "buienradarEditLonLatScreen");
		registry.registerWidget("screen", p.buienradarFullWeatherForecastScreenUrl, this, "buienradarFullWeatherForecastScreen");
		registry.registerWidget("menuItem", p.buienradarMenuUrl, this, "buienradarMenu", {weight: 110});
		registry.registerWidget("systrayIcon", p.buienradarTrayUrl, buienradarApp);
	}

	Component.onCompleted: {

		//read user settings

		try {
			buienradarSettingsJson = JSON.parse(buienradarSettingsFile.read());
			if (buienradarSettingsJson['selectedStation']) location = buienradarSettingsJson['selectedStation'];		
			if (buienradarSettingsJson['selectedLongitude']) lon = buienradarSettingsJson['selectedLongitude'];		
			if (buienradarSettingsJson['selectedLatitude']) lat = buienradarSettingsJson['selectedLatitude'];		
		} catch(e) {
			console.log("Buienradar: Error reading user settings: " + e);
		}
	}

	function saveSettings() {
		
		// save user settings
 		var tmpUserSettingsJson = {
			"selectedStation": location,
			"selectedLongitude": lon,
			"selectedLatitude": lat
		}

  		var doc3 = new XMLHttpRequest();
		doc3.onreadystatechange = function() {
			if (doc3.readyState == 4 && doc3.status != 0 && doc3.status != 200) {
				console.log("Buienradar: saving user settings failed with status: " + doc3.status);
			}
		};
   		doc3.open("PUT", "file:///mnt/data/tsc/buienradar.userSettings.json");
   		doc3.send(JSON.stringify(tmpUserSettingsJson ));
	}

	function updateBuienradar() {

	var weekday = new Array(7);
	weekday[0] = "Zo";
	weekday[1] = "Ma";
	weekday[2] = "Di";
	weekday[3] = "Wo";
	weekday[4] = "Do";
	weekday[5] = "Vr";
	weekday[6] = "Za";

		timeStr = i18n.dateTime(new Date().getTime(), i18n.time_yes);

		var xmlhttp = new XMLHttpRequest();
		xmlhttp.onreadystatechange=function() {

			if (xmlhttp.readyState == 4) {
				p.pendingBuienradar = null;
				buienradarWatchdog.stop();
				if (xmlhttp.status == 200) {

					var brJson = JSON.parse(xmlhttp.responseText);
					indexStation = -1;

						// rebuild the station arrays from scratch each fetch

					var tmpStationArray = [];
					var tmpLocationArray = [];
					var tmpLatArray = [];
					var tmpLonArray = [];
					var metingen = brJson['actual']['stationmeasurements'];

					for (var i=0; i < metingen.length; i++) {
						var stationName = metingen[i]['stationname'];
						tmpStationArray[i] = stationName.length > 12 ? stationName.slice(12) : stationName;
						tmpLocationArray[i] = metingen[i]['stationid'];
						tmpLatArray[i] = metingen[i]['lat'];
						tmpLonArray[i] = metingen[i]['lon'];
						if (location == metingen[i]['stationid']) indexStation = i;
					}

					stationArray = tmpStationArray;
					locationArray = tmpLocationArray;
					latArray = tmpLatArray;
					lonArray = tmpLonArray;

						// read specific selected location weather data

					if ( indexStation > -1 ) {
						var meting = metingen[indexStation];

							// save actual temp for use in TemperatureLogger app

						var doc2 = new XMLHttpRequest();
						doc2.open("PUT", "file:///var/volatile/tmp/actualBuienradarTemp.txt");
						doc2.send(meting['temperature'] + ":" + meting['timestamp']);

						windsnelheidMS = meting['windspeed'];
						windsnelheidBF = meting['windspeedBft'];
						windrichting = (typeof meting['winddirection'] === "string") ? meting['winddirection'].toUpperCase() : "";
						luchtdruk = meting['airpressure'];
						zichtmeters = meting['visibility'];
						temperatuurGC = meting['temperature'];
						gevoelstemperatuur = meting['feeltemperature'];
						luchtvochtigheid = meting['humidity'];

						icoonzin = meting['weatherdescription'];
						var tmpUrl = meting['iconurl'].split("/");
						icoonid = tmpUrl[tmpUrl.length - 1].substring(0, tmpUrl[tmpUrl.length - 1].length - 4);
						icoonlink = "qrc:/tsc/" + icoonid + ".png";

							// fill model for grid of weather station data on detail screen

						var tmpActual = [];
						tmpActual.push({'location': stationArray[indexStation],
							  'temperature': qsTr("Temperatuur:"),
							  'windsnelheid': qsTr("Windsnelheid:"),
							  'windrichting': qsTr("Windrichting:"),
							  'luchtvochtigheid': qsTr("Luchtvochtigheid:"),
							  'luchtdruk': qsTr("Luchtdruk:"),
							  'zicht': qsTr("Zicht:"),
							  'zonoponder': qsTr("Zon op/onder")});
						tmpActual.push({'location': BuienradarJS.dateFormat(meting['timestamp']),
							  'temperature': temperatuurGC,
							  'windrichting': windrichting,
							  'windsnelheid': windsnelheidBF,
							  'luchtvochtigheid': luchtvochtigheid,
							  'luchtdruk': luchtdruk,
							  'zicht': zichtmeters,
							  'zonoponder': BuienradarJS.lineZonOpOnder(brJson['actual']['sunrise'], brJson['actual']['sunset'])});
						actualweather = tmpActual;

						zonopkomst = brJson['actual']['sunrise'];
						zononder = brJson['actual']['sunset'];
					}

						// read 5-days weather forecast

					var tmpForecast = [];
					tmpForecast.push({'dagweek': '',
						  'kanszon': qsTr("zon %"),
						  'kansregen': qsTr("regen %"),
						  'mintemp': qsTr("min"),
						  'maxtemp': qsTr("max"),
						  'wind': qsTr("wind")});

					var fiveday = brJson['forecast']['fivedayforecast'];
					for (var i = 0; i < fiveday.length && i < 5; i++) {
						var tmpNewDate = new Date(fiveday[i]['day']);
						var tmpdagweek = weekday[tmpNewDate.getDay()];
						var tmpUrlDp = fiveday[i]['iconurl'].split("/");
						var dpicoonid = tmpUrlDp[tmpUrlDp.length - 1].substring(0, tmpUrlDp[tmpUrlDp.length - 1].length - 4);
						tmpForecast.push({'dagweek': tmpdagweek,
							  'kanszon': fiveday[i]['sunChance'].toString(),
							  'kansregen': fiveday[i]['rainChance'].toString(),
							  'mintemp': fiveday[i]['mintemperatureMin'].toString(),
							  'maxtemp': fiveday[i]['maxtemperatureMax'].toString(),
							  'wind': (fiveday[i]['windDirection'] + "").toUpperCase() + " " + fiveday[i]['wind'].toString(),
							  'icoon': "qrc:/tsc/" + dpicoonid + ".png"});
					}
					fivedayforecast = tmpForecast;

						//forecast title and text, decode html entities

					weersverwachtingTitel = brJson['forecast']['weatherreport']['title'];
					weersverwachtingTekst = brJson['forecast']['weatherreport']['text'].replace(/&nbsp;/g, " ").replace(/&rsquo;/g, "'");

						// link to icon image for dim mode

					icoonimageDim = BuienradarJS.parseWeatherIdAndText("file:///qmf/qml/apps/buienradar/drawables/Dim", icoonid, icoonzin, zonopkomst, zononder, timeStr);
				} else {
					console.log("Buienradar: updateBuienradar failed with status: " + xmlhttp.status);
				}
			}
		}
		p.pendingBuienradar = xmlhttp;
		xmlhttp.open("GET", "https://data.buienradar.nl/2.0/feed/json", true);
		xmlhttp.send();
		buienradarWatchdog.restart();
	}

	function updateRegenkans() {
		var xmlhttp = new XMLHttpRequest();
		var newArray = [];
		var mmRegen = 0;
		var maxValue = 0;
		regenMaxValue = 0;
		var startForecasts = 0;
		var forecastCounter = 0;
		showRain = false;

		xmlhttp.onreadystatechange=function() {
			if (xmlhttp.readyState == 4) {
				p.pendingRegenkans = null;
				regenWatchdog.stop();
				if (xmlhttp.status == 200) {

					var response = xmlhttp.responseText;
					if (response.length > 0) {

						var rainJson = JSON.parse(response);
						var forecasts = rainJson['forecasts'];
						var now = new Date();
						var tmpNewDate = new Date();
						var startFound = false;

						if (forecasts && forecasts.length > 0) {

							// find start of actual forecast

							for (var i = 0; i < forecasts.length ; i++) {
								tmpNewDate = new Date(forecasts[i]['datetime']);
								if (now < tmpNewDate) {
									startForecasts = i;
									startFound = true;
									break;
								}
							}

							if (startFound) {

								regenVerwachtingVanaf = forecasts[startForecasts]['datetime'].substring(11,16);

								// fill array with the next 24 values

								for (var i = startForecasts; i < forecasts.length ; i++) {
									// NOTE: 'precipation' is a typo in the Buienradar API payload, but it is still served; fallback to the correctly spelled key.
									mmRegen = forecasts[i]['precipation'];
									if (typeof mmRegen !== "number") mmRegen = forecasts[i]['precipitation'];
									if (typeof mmRegen !== "number") mmRegen = 0;
									newArray.push(mmRegen);
									if (mmRegen > 0) showRain = true;
									if (mmRegen > maxValue) maxValue = mmRegen;
									forecastCounter = forecastCounter + 1;
									if (forecastCounter == 24) break;
								}

								// fill remaining slots , just in case we didn't had 24 datapoints

								if (forecastCounter < 24) {
									for (var i = forecastCounter; i < 24 ; i++) {  // add empty columns
										newArray.push(0);
									}
								}

								regenVerwachtingMidden = BuienradarJS.addMinutes(regenVerwachtingVanaf, 60);
								regenVerwachtingTot = BuienradarJS.addMinutes(regenVerwachtingVanaf, 120);
								regenVerwachting = newArray;
								regenMaxValue = Math.round(maxValue + 0.5);
							}
						}
					}
				} else {
					console.log("Buienradar: updateRegenkans failed with status: " + xmlhttp.status);
				}
			}
		}

		p.pendingRegenkans = xmlhttp;
		xmlhttp.open("GET", "https://graphdata.buienradar.nl/2.0/forecast/geo/RainHistoryForecast?lat="+lat+"&lon="+lon, true);
		xmlhttp.send();
		regenWatchdog.restart();
	}

	Timer {
		id: datetimeTimer
		interval: 600000
		triggeredOnStart: true
		running: true
		repeat: true
		onTriggered: updateBuienradar()
	}


	Timer {
		id: datetimeTimer2
		interval: 300000
		triggeredOnStart: true
		running: true
		repeat: true
		onTriggered: updateRegenkans()
	}

	Timer {
		id: buienradarWatchdog
		interval: 90000
		repeat: false
		onTriggered: {
			if (p.pendingBuienradar) {
				console.log("Buienradar: updateBuienradar timed out; aborting request");
				p.pendingBuienradar.abort();
				p.pendingBuienradar = null;
			}
		}
	}

	Timer {
		id: regenWatchdog
		interval: 60000
		repeat: false
		onTriggered: {
			if (p.pendingRegenkans) {
				console.log("Buienradar: updateRegenkans timed out; aborting request");
				p.pendingRegenkans.abort();
				p.pendingRegenkans = null;
			}
		}
	}
}
