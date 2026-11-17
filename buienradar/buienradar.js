function addMinutes(time/*"hh:mm"*/, minsToAdd/*"N"*/) {
  function z(n){
    return (n<10? '0':'') + n;
  }
  var bits = time.split(':');
  var mins = bits[0]*60 + (+bits[1]) + (+minsToAdd);

  return z(mins%(24*60)/60 | 0) + ':' + z(mins%60);  
}

function formatTemp(tempValue, locationName) {
//adapted to reflect locale settings
	var displayName = locationName === "Schiphol" ? "Amsterdam" : locationName;
	if (displayName) return displayName + ": " + i18n.number( Number( tempValue ), 1 ) + " °C";
	return "Even geduld..."
}


function dateFormat( dateStr ) {
    return  dateStr.substring(0, 10) + " " + dateStr.substring(11,16);
}


function formatWind(richting, bf) {
	return "wind: " + bf + " BFT, " + richting;
}


function formatZin(zin) {
	if (zin.length > 21) {
	return zin.substring(0,21) + "...";
	} else {
		return zin;
	}
}


function determineNight (tijdnu, zonop, zononder) {
	var zonoptimestr = zonop.substring(11,16);
	var zonondertimestr = zononder.substring(11,16);

	if (tijdnu.length == 4) {
		tijdnu = "0" + tijdnu;
	}

	function toMinutes(time) {
		var parts = time.split(':');
		return parseInt(parts[0], 10) * 60 + parseInt(parts[1], 10);
	}

	var nowMin = toMinutes(tijdnu);
	var sunriseMin = toMinutes(zonoptimestr);
	var sunsetMin = toMinutes(zonondertimestr);

	var isTodayDay = (nowMin >= sunriseMin && nowMin <= sunsetMin);
	return !isTodayDay;
}


function formatLuchtdruk(ld, humidity) {
	return i18n.number(ld, 0, i18n.general_rounding, 1) + " hPa; lv: " + humidity + " %";
}


function lineZonOpOnder(zonop, zononder) {
	return zonop.substr(11,5) + " / " + zononder.substr(11,5);
}


/**
* @brief Calculate a filename to choose weather icons, distinquishing day and night icons.
* @param sourceFileName : String
*	 This is the first part of the filename including the path.
* @param weatherId : String
*	 A string that holds an Id coming from buienradar.nl. This is the basis of the decision what icon to pick.
* @param weatherText : String
*	 If weatherId is "0", the icon is chosen on the basis of this string.
* @return relative path to weather icon as string
*/

function parseWeatherIdAndText(sourceFileName, weatherId, weatherText, zonop, zononder, tijdnu) {
    
	var isTodayNight = determineNight (tijdnu, zonop, zononder);

    switch (weatherId) {
    case 'a': sourceFileName += isTodayNight ? "ClearNight" : "Sunny";
	break;
    case 'b':
    case 'o':
	sourceFileName += isTodayNight ? "CloudedNight" : "SunnyIntervals";
	break;
    case 'f':
	sourceFileName += isTodayNight ? "LightRainNight" : "LightRainDay";
	break;
    case 'k':
	sourceFileName += isTodayNight ? "RainNight" : "RainDay";
	break;
    case 'h':
    case 'i':
	sourceFileName += isTodayNight ? "RainHailNight" : "RainHailDay";
	break;
    case 'g':
	sourceFileName += isTodayNight ? "ThunderNight" : "ThunderDay";
	break;
    case 'u':
	sourceFileName += isTodayNight ? "LightSnowNight" : "LightSnowDay";
	break;
    case 'd':
	sourceFileName += isTodayNight ? "FogNight" : "FogDay";
	break;
	//symbols with moon
    case 'aa':
	sourceFileName += "ClearNight";
	break;
    case 'bb':
    case 'oo':
	sourceFileName += "CloudedNight";
	break;
    case 'ff':
	sourceFileName += "LightRainNight";
	break;
    case 'kk':
	sourceFileName += "RainNight";
	break;
    case 'hh':
    case 'ii':
	sourceFileName += "RainHailNight";
	break;
    case 'gg':
	sourceFileName += "ThunderNight";
	break;
    case 'uu':
	sourceFileName += "LightSnowNight";
	break;
    case 'dd':
	sourceFileName += "FogNight";
	break;
	//just clouds
    case 'c':
    case 'p':
    case 'cc':
    case 'pp':
	sourceFileName += "Clouded";
	break;
    case 'm':
    case 'mm':
	sourceFileName += "LightRain";
	break;
    case 'l':
    case 'll':
    case 'q':
    case 'qq':
	sourceFileName += "Rain";
	break;
    case 'w':
    case 'ww':
	sourceFileName += "Sleet";
	break;
    case 's':
    case 'ss':
	sourceFileName += "Thunder";
	break;
    case 'v':
    case 'vv':
    case 'y':
    case 'yy':
	sourceFileName += "LightSnow";
	break;
    case '1':
    case '11':
    case 't':
    case 'tt':
    case 'x':
    case 'xx':
    case 'z':
    case 'zz':
	sourceFileName += "Snow";
	break;
    case 'e':
    case 'ee':
	sourceFileName += "Fog";
	break;
    case 'n':
    case 'nn':
	sourceFileName += "SlipRisk";
	break;
    case '0':
	if (weatherText !== "")
	{
	    if (weatherText === "zonnig") {
		sourceFileName += "Sunny";
	    } else if (weatherText === "zonnig en bewolkt") {
		sourceFileName += "SunnyIntervals";
	    } else if (weatherText === "zonnig met lichte regen" || weatherText == "zonnig, bewolkt en lichte regen") {
		sourceFileName += "LightRainDay";
	    } else if (weatherText === "zonnig met lichte sneeuwval" || weatherText == "zonnig, bewolkt en lichte sneeuwval") {
		sourceFileName += "LightSnowDay";
	    } else if (weatherText === "heldere nacht") {
		sourceFileName += "ClearNight";
	    } else if (weatherText === "heldere lucht en hier en daar bewolkt") {
		sourceFileName += "SunnyIntervals";
	    } else if (weatherText === "bewolkt") {
		sourceFileName += "Clouded";
	    } else if (weatherText === "bewolkt en lichte regen" || weatherText == "bewolkt met lichte regen" || weatherText == "bewolkt, mistig en lichte regen" || weatherText == "bewolkt, mistig met lichte regen") {
		sourceFileName += "LightRain";
	    } else if (weatherText === "bewolkt en regen" || weatherText == "bewolkt met regen") {
		sourceFileName += "Rain";
	    } else if (weatherText === "bewolkt met sneeuwval" || weatherText == "bewolkt en sneeuwval" || weatherText == "bewolkt en lichte sneeuwval") {
		sourceFileName += "Snow";
	    } else if (weatherText === "mistig") {
		sourceFileName += "Fog";
	    } else {
		sourceFileName += "SunnyIntervals";
	    }
	}
	break;
    default:
	sourceFileName += "Cross";
    }
    
    return sourceFileName += ".png"
}
