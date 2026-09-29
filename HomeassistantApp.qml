import QtQuick 2.1
import qb.components 1.0
import qb.base 1.0

import FileIO 1.0

App {
    id: homeassistantApp

    property int debug: 0

    property url tileUrl : "HomeassistantTile.qml"
    property url thumbnailIcon: "drawables/homeAssistant.png"

    property HomeassistantConfigurationScreen homeAssistantConfigurationScreen
    property url homeAssistantConfigurationScreenUrl : "HomeassistantConfigurationScreen.qml"

    property HomeassistantScreen homeAssistantScreen
    property url homeAssistantScreenUrl : "HomeassistantScreen.qml"

    // --- connection ---
    property int connected : 0
    property string url : ""
    property string homeAssistantServer : ""
    property string homeAssistantSSL : "no"
    property string homeAssistantPort : "8123"
    property string homeAssistantToken : ""

    // --- tile options ---
    property int clockTile : 0

    // --- entity configuration (slot arrays, fixed length) ---
    property var sensorEntities : ["", "", "", "", "", "", "", ""]
    property var switchEntities : ["", "", "", "", ""]
    property var sceneEntities : ["", "", "", ""]
    property string alarmEntity : ""
    property string alarmCode : ""
    property string sliderEntity : ""

    // slot indexes of the configured (non-empty) entities, in order; the UI
    // lists only these so gaps in the configuration never leave holes
    property var activeSensors : []
    property var activeSwitches : []
    property var activeScenes : []

    // --- fetched state: raw JSON per slot; always reassigned as a NEW array
    //     so bindings that read them re-evaluate (in-place mutation does not
    //     notify on this Qt5 build) ---
    property var sensorInfo : ["", "", "", "", "", "", "", ""]
    property var switchInfo : ["", "", "", "", ""]
    property var sceneInfo : ["", "", "", ""]
    property string alarmInfo : ""
    property string alarmState : ""
    property string sliderInfo : ""

    // --- alarm dialpad ---
    property string alarmInputCode : ""
    property string alarmInputLabel : ""

    // --- clock shown on tile ---
    property string timeStr : ""
    property string dateStr : ""

    // --- debug log ---
    property string message : ""
    property bool logShown : false

    // --- polling bookkeeping ---
    property int pollGeneration : 0
    property int pollInFlight : 0
    property int pollTotal : 0
    property int pollFailures : 0
    property int pollUnauthorized : 0
    property var pollMissing : []
    property real checkStarted : 0

    // --- user-visible status: statusText = persistent connection/config
    //     problem, noticeText = short-lived command failure ---
    property string statusText : ""
    property string noticeText : ""

    FileIO {
        id: userSettingsFile
        source: "file:///mnt/data/tsc/homeassistant.userSettings.json"
    }

    FileIO {
        id: tokenFile
        source: "file:///mnt/data/tsc/homeassistant.token.txt"
    }

    //
    // Clock
    //

    function updateClockInfo() {
        var now = new Date().getTime();
        timeStr = i18n.dateTime(now, i18n.time_yes);
        dateStr = i18n.dateTime(now, i18n.mon_full);
    }

    Timer {
        id: clockTimer
        interval: 1000
        triggeredOnStart: true
        running: true
        repeat: true
        onTriggered: updateClockInfo()
    }

    //
    // Polling: one timer drives both state refresh and re-check of the
    // connection while disconnected. Watchdog bounds a stuck fetch cycle
    // (xhr.timeout is unreliable on this Qt5 build).
    //

    Timer {
        id: refreshTimer
        interval: 60000
        triggeredOnStart: true
        running: true
        repeat: true
        onTriggered: {
            if (homeassistantApp.connected) {
                homeassistantApp.startRefreshCycle();
            } else {
                homeassistantApp.checkConnection();
            }
        }
    }

    Timer {
        id: pollWatchdog
        interval: 20000
        repeat: false
        running: false
        onTriggered: {
            if (homeassistantApp.pollInFlight > 0) {
                homeassistantApp.pollInFlight = 0;
                homeassistantApp.pollGeneration = homeassistantApp.pollGeneration + 1;
                homeassistantApp.connected = 0;
                homeassistantApp.statusText = qsTr("Geen antwoord van Home Assistant (time-out)");
                homeassistantApp.logText("Poll cycle timed out, callbacks from it are dropped");
            }
        }
    }

    Timer {
        id: noticeTimer
        interval: 8000
        repeat: false
        running: false
        onTriggered: homeassistantApp.noticeText = ""
    }

    function notify(text) {
        noticeText = text;
        noticeTimer.restart();
        logText(text);
    }

    function startRefreshCycle() {
        if (!connected || homeAssistantToken == "" || url == "") {
            return;
        }
        pollGeneration = pollGeneration + 1;
        var gen = pollGeneration;
        var i;

        pollInFlight = 0;
        pollTotal = 0;
        pollFailures = 0;
        pollUnauthorized = 0;
        pollMissing = [];

        for (i = 0; i < 8; i++) {
            if (sensorEntities[i] != "") {
                fetchState("sensor", i, sensorEntities[i], gen);
            }
        }
        for (i = 0; i < 5; i++) {
            if (switchEntities[i] != "") {
                fetchState("switch", i, switchEntities[i], gen);
            }
        }
        for (i = 0; i < 4; i++) {
            if (sceneEntities[i] != "") {
                fetchState("scene", i, sceneEntities[i], gen);
            }
        }
        if (alarmEntity != "") {
            fetchState("alarm", 0, alarmEntity, gen);
        }
        if (sliderEntity != "") {
            fetchState("slider", 0, sliderEntity, gen);
        }

        if (pollInFlight > 0) {
            pollWatchdog.restart();
        } else {
            pollWatchdog.stop();
            statusText = "";
        }
    }

    function fetchState(kind, index, entity, gen) {
        pollInFlight = pollInFlight + 1;
        pollTotal = pollTotal + 1;
        apiGet("/api/states/" + entity, function (status, body) {
            // callbacks of a superseded or timed-out cycle never touch the counters
            if (gen != pollGeneration) {
                return;
            }
            pollInFlight = pollInFlight - 1;
            if (status == 0) {
                pollFailures = pollFailures + 1;
            } else if (status == 401 || status == 403) {
                pollUnauthorized = pollUnauthorized + 1;
            } else if (status == 404) {
                pollMissing = pollMissing.concat([entity]);
            }

            // "!<status>" marks a failed fetch so the UI can tell it from "not loaded yet"
            var payload = (status == 200) ? body : "!" + status;
            if (kind == "sensor") {
                setSlotArray("sensorInfo", index, payload);
            } else if (kind == "switch") {
                setSlotArray("switchInfo", index, payload);
            } else if (kind == "scene") {
                setSlotArray("sceneInfo", index, payload);
            } else if (kind == "slider") {
                sliderInfo = payload;
            } else {
                alarmInfo = payload;
                var state = stateOf(payload);
                if (state != "") {
                    alarmState = state;
                    // don't clobber the label while a code is being typed
                    if (alarmInputCode.length == 0) {
                        alarmInputLabel = alarmLabel(state);
                    }
                }
            }

            if (pollInFlight <= 0) {
                finishRefreshCycle();
            }
        });
    }

    function finishRefreshCycle() {
        pollWatchdog.stop();
        if (pollUnauthorized > 0) {
            connected = 0;
            statusText = qsTr("Toegangstoken geweigerd door Home Assistant");
        } else if (pollTotal > 0 && pollFailures >= pollTotal) {
            connected = 0;
            statusText = qsTr("Geen verbinding met Home Assistant");
        } else if (pollMissing.length > 0) {
            statusText = qsTr("Niet gevonden in Home Assistant: ") + pollMissing.join(", ");
        } else {
            statusText = "";
        }
    }

    function setSlotArray(prop, index, value) {
        var arr;
        if (prop == "sensorInfo") {
            arr = sensorInfo.slice();
        } else if (prop == "switchInfo") {
            arr = switchInfo.slice();
        } else {
            arr = sceneInfo.slice();
        }
        arr[index] = value;
        if (prop == "sensorInfo") {
            sensorInfo = arr;
        } else if (prop == "switchInfo") {
            switchInfo = arr;
        } else {
            sceneInfo = arr;
        }
    }

    function refreshNow() {
        if (connected) {
            startRefreshCycle();
        } else {
            checkConnection();
        }
    }

    //
    // HTTP layer. Home Assistant REST API (https://developers.home-assistant.io/docs/api/rest/)
    // authenticated with a long-lived access token; api_password auth was removed in
    // Home Assistant 2023.7 and is no longer supported here.
    //

    function apiGet(path, callback) {
        callApi("GET", path, "", callback);
    }

    function apiPost(path, payload, callback) {
        callApi("POST", path, payload, callback);
    }

    function callApi(method, path, payload, callback) {
        var http = new XMLHttpRequest();
        http.onreadystatechange = function () {
            if (http.readyState == 4) {
                callback(http.status, http.responseText);
            }
        };
        http.open(method, url + path, true);
        if (homeAssistantToken != "") {
            http.setRequestHeader("Authorization", "Bearer " + homeAssistantToken);
        }
        if (method == "POST") {
            http.setRequestHeader("Content-Type", "application/json");
        }
        http.send(payload);
    }

    function buildUrl() {
        var scheme = (homeAssistantSSL == "yes") ? "https://" : "http://";
        if (homeAssistantServer == "") {
            return "";
        }
        return scheme + homeAssistantServer + ":" + homeAssistantPort;
    }

    // Accepts what people actually type: "192.168.1.5", "http://ha.local:8123/",
    // "https://ha.example.com". Returns the bare host plus any port/scheme found.
    function parseServer(text) {
        var s = ("" + text).trim();
        var result = {host: "", port: "", ssl: ""};
        if (/^https:\/\//i.test(s)) {
            result.ssl = "yes";
        } else if (/^http:\/\//i.test(s)) {
            result.ssl = "no";
        }
        s = s.replace(/^[a-z]+:\/\//i, "");
        var slash = s.indexOf("/");
        if (slash >= 0) {
            s = s.substring(0, slash);
        }
        var m = /^(.*):([0-9]+)$/.exec(s);
        if (m && m[1].indexOf(":") < 0) {
            s = m[1];
            result.port = m[2];
        }
        result.host = s;
        return result;
    }

    function readToken() {
        var raw = "";
        try {
            raw = "" + tokenFile.read();
        } catch (err) {
            raw = "";
        }
        // tolerate quotes, newlines and a pasted "Bearer " prefix
        raw = raw.replace(/^[\s"']+|[\s"']+$/g, "").replace(/^Bearer\s+/i, "");
        homeAssistantToken = raw;
        if (homeAssistantToken == "") {
            logText("No access token found: create a long-lived token in your HA profile and save it to /mnt/data/tsc/homeassistant.token.txt");
        }
    }

    function checkConnection() {
        // don't stack connection checks, but never wait on a hung one for long
        var now = new Date().getTime();
        if (checkStarted > 0 && now - checkStarted < 30000) {
            return;
        }
        readToken();
        url = buildUrl();
        if (url == "") {
            connected = 0;
            statusText = qsTr("Home Assistant is nog niet ingesteld: open Instellingen");
            return;
        }
        if (homeAssistantToken == "") {
            connected = 0;
            statusText = qsTr("Geen toegangstoken gevonden in /mnt/data/tsc/homeassistant.token.txt");
            return;
        }
        checkStarted = now;
        apiGet("/api/", function (status, body) {
            checkStarted = 0;
            if (status == 200) {
                if (!connected) {
                    logText("Connection established: " + body);
                }
                connected = 1;
                statusText = "";
                startRefreshCycle();
            } else {
                connected = 0;
                if (status == 401) {
                    statusText = qsTr("Toegangstoken geweigerd door Home Assistant");
                    logText("Connection refused: token rejected by " + url + " (HTTP 401)");
                } else {
                    statusText = qsTr("Geen verbinding met ") + url;
                    logText("Could not reach Home Assistant at " + url + " (HTTP " + status + ")");
                }
            }
        });
    }

    //
    // Settings I/O: one file, built from a whitelist so no stray property can leak in.
    //

    function saveSettings() {
        var settings = {
            "Server": homeAssistantServer,
            "SSL": homeAssistantSSL,
            "Port": homeAssistantPort,
            "Clock": clockTile,
            "Sensors": sensorEntities.slice(),
            "Switches": switchEntities.slice(),
            "Scenes": sceneEntities.slice(),
            "Alarm": alarmEntity,
            "AlarmCode": alarmCode,
            "Slider": sliderEntity
        };
        var http = new XMLHttpRequest();
        http.open("PUT", "file:///mnt/data/tsc/homeassistant.userSettings.json");
        http.send(JSON.stringify(settings));
    }

    function paddedArray(value, length) {
        var out = [];
        var i;
        for (i = 0; i < length; i++) {
            var item = (value && value[i]) ? "" + value[i] : "";
            out.push(item.trim());
        }
        return out;
    }

    function activeSlots(arr) {
        var out = [];
        var i;
        for (i = 0; i < arr.length; i++) {
            if (arr[i] != "") {
                out.push(i);
            }
        }
        return out;
    }

    function refreshActive() {
        activeSensors = activeSlots(sensorEntities);
        activeSwitches = activeSlots(switchEntities);
        activeScenes = activeSlots(sceneEntities);
    }

    function readSettings() {
        var settings = {};
        try {
            settings = JSON.parse(userSettingsFile.read());
        } catch (err) {
            logText("No valid settings file yet, using defaults: " + err);
        }
        if (!settings) {
            settings = {};
        }

        var server = parseServer(settings.Server ? settings.Server : "");
        homeAssistantServer = server.host;
        homeAssistantPort = server.port != "" ? server.port : (settings.Port ? ("" + settings.Port).trim() : "8123");
        homeAssistantSSL = server.ssl != "" ? server.ssl : ((settings.SSL == "yes") ? "yes" : "no");
        clockTile = settings.Clock ? 1 : 0;
        sensorEntities = paddedArray(settings.Sensors, 8);
        switchEntities = paddedArray(settings.Switches, 5);
        sceneEntities = paddedArray(settings.Scenes, 4);
        alarmEntity = settings.Alarm ? ("" + settings.Alarm).trim() : "";
        alarmCode = settings.AlarmCode ? "" + settings.AlarmCode : "";
        sliderEntity = settings.Slider ? ("" + settings.Slider).trim() : "";
        refreshActive();

        checkConnection();
    }

    // Called by the configuration screen when the user presses Opslaan.
    function saveConfiguration(server, port, ssl, clock, sensors, switches, scenes, alarmEntityId, alarmCodeValue, sliderEntityId) {
        var parsed = parseServer(server);
        homeAssistantServer = parsed.host;
        homeAssistantSSL = (parsed.ssl != "") ? parsed.ssl : ((ssl == "yes") ? "yes" : "no");
        if (parsed.port != "") {
            homeAssistantPort = parsed.port;
        } else if (/^[0-9]+$/.test(port.trim())) {
            homeAssistantPort = port.trim();
        }
        clockTile = clock ? 1 : 0;
        sensorEntities = paddedArray(sensors, 8);
        switchEntities = paddedArray(switches, 5);
        sceneEntities = paddedArray(scenes, 4);
        alarmEntity = alarmEntityId.trim();
        alarmCode = alarmCodeValue;
        sliderEntity = sliderEntityId.trim();
        refreshActive();

        // drop data of the previous configuration so it can't show under a new entity
        sensorInfo = ["", "", "", "", "", "", "", ""];
        switchInfo = ["", "", "", "", ""];
        sceneInfo = ["", "", "", ""];
        alarmInfo = "";
        alarmState = "";
        alarmInputCode = "";
        alarmInputLabel = "";
        sliderInfo = "";

        connected = 0;
        checkStarted = 0;
        saveSettings();
        checkConnection();
    }

    //
    // State helpers: every QML binding goes through one of these so no file has to
    // JSON.parse (or try/catch, which is not valid inside a property binding).
    //

    function slotEntity(arr, index) {
        var value = arr[index];
        return (value === undefined || value === null) ? "" : value;
    }

    function sensorEntity(index) { return slotEntity(sensorEntities, index); }
    function switchEntity(index) { return slotEntity(switchEntities, index); }
    function sceneEntity(index) { return slotEntity(sceneEntities, index); }

    function parseInfo(info) {
        if (!info || info.charAt(0) != "{") {
            return null;
        }
        try {
            return JSON.parse(info);
        } catch (err) {
            return null;
        }
    }

    function stateOf(info) {
        var data = parseInfo(info);
        return (data && data.state !== undefined) ? "" + data.state : "";
    }

    function nameOf(info, entity) {
        var data = parseInfo(info);
        if (data && data.attributes && data.attributes.friendly_name) {
            return "" + data.attributes.friendly_name;
        }
        if (data && data.entity_id) {
            return tailOf("" + data.entity_id);
        }
        return tailOf(entity);
    }

    function domainOf(entity) {
        var dot = entity.indexOf(".");
        return (dot >= 0) ? entity.substring(0, dot) : entity;
    }

    function tailOf(entity) {
        var dot = entity.indexOf(".");
        return (dot >= 0) ? entity.substring(dot + 1) : entity;
    }

    // "21.34000001" -> "21.34"; anything else is returned untouched
    function formatNumber(text) {
        if (!/^-?[0-9]+\.[0-9]{3,}$/.test(text)) {
            return text;
        }
        return "" + Math.round(parseFloat(text) * 100) / 100;
    }

    function binaryLabel(deviceClass, on) {
        if (deviceClass == "door" || deviceClass == "window" || deviceClass == "garage_door" || deviceClass == "opening") {
            return on ? qsTr("Open") : qsTr("Dicht");
        }
        if (deviceClass == "motion" || deviceClass == "moving") {
            return on ? qsTr("Beweging") : qsTr("Rustig");
        }
        if (deviceClass == "occupancy" || deviceClass == "presence") {
            return on ? qsTr("Aanwezig") : qsTr("Afwezig");
        }
        if (deviceClass == "smoke" || deviceClass == "gas" || deviceClass == "moisture" || deviceClass == "carbon_monoxide"
                || deviceClass == "safety" || deviceClass == "problem" || deviceClass == "tamper") {
            return on ? qsTr("Alarm") : qsTr("OK");
        }
        return on ? qsTr("Aan") : qsTr("Uit");
    }

    // Text shown as the value of a sensor slot. Never throws, never empty for a
    // configured entity: "..." = not loaded yet, "-" = fetch failed.
    function valueOf(info) {
        if (!info) {
            return "…";
        }
        var data = parseInfo(info);
        if (!data) {
            return "—";
        }
        var attrs = data.attributes ? data.attributes : {};
        var state = "" + data.state;
        var domain = domainOf(data.entity_id ? "" + data.entity_id : "");

        if (state == "unavailable") {
            return qsTr("n.b.");
        }
        if (state == "unknown") {
            return "?";
        }
        if (domain == "climate" && attrs.current_temperature !== undefined && attrs.current_temperature !== null) {
            return formatNumber("" + attrs.current_temperature) + "°";
        }
        if (domain == "weather" && attrs.temperature !== undefined && attrs.temperature !== null) {
            return formatNumber("" + attrs.temperature) + " " + (attrs.temperature_unit ? attrs.temperature_unit : "°");
        }
        if (domain == "binary_sensor") {
            return binaryLabel(attrs.device_class, state == "on");
        }
        if (domain == "person" || domain == "device_tracker") {
            if (state == "home") {
                return qsTr("Thuis");
            }
            if (state == "not_home") {
                return qsTr("Weg");
            }
        }
        if (state == "on") {
            return qsTr("Aan");
        }
        if (state == "off") {
            return qsTr("Uit");
        }
        var unit = attrs.unit_of_measurement ? " " + attrs.unit_of_measurement : "";
        return formatNumber(state) + unit;
    }

    function sensorName(index) { return nameOf(sensorInfo[index], sensorEntities[index]); }
    function sensorValue(index) { return valueOf(sensorInfo[index]); }
    function switchName(index) { return nameOf(switchInfo[index], switchEntities[index]); }
    function sceneName(index) { return nameOf(sceneInfo[index], sceneEntities[index]); }

    function switchOn(index) {
        var state = stateOf(switchInfo[index]);
        return (state == "on" || state == "active" || state == "true" || state == "open" || state == "opening");
    }

    //
    // Commands
    //

    // Domains a slot can drive. Returns the service path, or "" when unsupported.
    function serviceFor(domain, on) {
        if (domain == "scene" || domain == "script") {
            return domain + "/turn_on";
        }
        if (domain == "automation") {
            return "automation/trigger";
        }
        if (domain == "button" || domain == "input_button") {
            return domain + "/press";
        }
        if (domain == "cover") {
            return on ? "cover/open_cover" : "cover/close_cover";
        }
        if (domain == "switch" || domain == "light" || domain == "input_boolean" || domain == "fan"
                || domain == "siren" || domain == "humidifier" || domain == "remote") {
            return domain + (on ? "/turn_on" : "/turn_off");
        }
        if (domain == "group") {
            return "homeassistant" + (on ? "/turn_on" : "/turn_off");
        }
        return "";
    }

    function callService(service, data, entity) {
        if (!connected) {
            notify(qsTr("Niet verbonden met Home Assistant, commando niet verstuurd"));
            return;
        }
        if (homeAssistantToken == "") {
            notify(qsTr("Geen toegangstoken, commando niet verstuurd"));
            return;
        }
        callApi("POST", "/api/services/" + service, JSON.stringify(data), function (status, body) {
            if (status != 200) {
                notify(qsTr("Commando mislukt voor ") + entity + " (HTTP " + status + ")");
            }
            startRefreshCycle();
        });
    }

    function setEntity(entity, state) {
        if (!entity || entity == "") {
            return;
        }
        var service = serviceFor(domainOf(entity), state);
        if (service == "") {
            notify(qsTr("Niet ondersteund type: ") + domainOf(entity));
            return;
        }
        callService(service, {"entity_id": entity}, entity);
    }

    function setNumber(entity, value) {
        var domain = domainOf(entity);
        if (domain != "input_number" && domain != "number") {
            notify(qsTr("Slider verwacht een input_number of number entity"));
            return;
        }
        callService(domain + "/set_value", {"entity_id": entity, "value": value}, entity);
    }

    //
    // Slider (input_number / number): - and + buttons in steps of the entity's own step.
    //

    function sliderAttr(name, fallback) {
        var data = parseInfo(sliderInfo);
        var value = (data && data.attributes) ? parseFloat(data.attributes[name]) : NaN;
        return isNaN(value) ? fallback : value;
    }

    function sliderName() { return nameOf(sliderInfo, sliderEntity); }
    function sliderText() { return valueOf(sliderInfo); }

    function sliderStep(direction) {
        var data = parseInfo(sliderInfo);
        var current = data ? parseFloat(data.state) : NaN;
        if (isNaN(current)) {
            return;
        }
        var step = sliderAttr("step", 1);
        if (step <= 0) {
            step = 1;
        }
        var next = current + direction * step;
        next = Math.max(sliderAttr("min", next), Math.min(sliderAttr("max", next), next));
        var stepText = "" + step;
        var dot = stepText.indexOf(".");
        next = parseFloat(next.toFixed(dot >= 0 ? stepText.length - dot - 1 : 0));
        if (next == current) {
            return;
        }
        // show the new value right away so quick repeated taps keep stepping
        data.state = "" + next;
        sliderInfo = JSON.stringify(data);
        setNumber(sliderEntity, next);
    }

    //
    // Alarm control panel
    //

    function alarmLabel(state) {
        if (state == "disarmed") { return qsTr("Uitgeschakeld"); }
        if (state == "armed_away") { return qsTr("Aan (weg)"); }
        if (state == "armed_home") { return qsTr("Aan (thuis)"); }
        if (state == "armed_night") { return qsTr("Aan (nacht)"); }
        if (state == "armed_vacation") { return qsTr("Aan (vakantie)"); }
        if (state == "armed_custom_bypass") { return qsTr("Aan (aangepast)"); }
        if (state == "arming") { return qsTr("Inschakelen..."); }
        if (state == "pending") { return qsTr("In afwachting"); }
        if (state == "disarming") { return qsTr("Uitschakelen..."); }
        if (state == "triggered") { return qsTr("ALARM!"); }
        if (state == "unavailable") { return qsTr("Niet beschikbaar"); }
        return state.replace(/_/g, " ");
    }

    // True when the next press should disarm. Mirrors the enter-button icon in
    // HomeassistantScreen (locked icon <=> alarmIsActive()).
    function alarmIsActive() {
        return alarmState != "" && alarmState != "disarmed" && alarmState != "unavailable" && alarmState != "unknown";
    }

    // Whether the panel demands a code to disarm (attributes.code_format is null otherwise).
    function alarmNeedsCode() {
        var data = parseInfo(alarmInfo);
        if (!data || !data.attributes) {
            return true;
        }
        return data.attributes.code_format !== null && data.attributes.code_format !== undefined;
    }

    function alarmInput(num) {
        if (alarmInputCode.length >= 4) {
            return;
        }
        alarmInputCode = alarmInputCode + num;
        var masked = "";
        var i;
        for (i = 0; i < alarmInputCode.length - 1; i++) {
            masked = masked + "*";
        }
        alarmInputLabel = masked + num;
    }

    function alarmInputReset() {
        alarmInputCode = "";
        alarmInputLabel = alarmLabel(alarmState);
    }

    function alarmToggle() {
        if (alarmEntity == "") {
            return;
        }
        if (!connected || homeAssistantToken == "") {
            notify(qsTr("Niet verbonden met Home Assistant, commando niet verstuurd"));
            return;
        }
        var payload = {"entity_id": alarmEntity};
        var service;
        if (alarmIsActive()) {
            service = "alarm_disarm";
            if (alarmInputCode.length > 0) {
                payload.code = alarmInputCode;
            } else if (alarmNeedsCode()) {
                notify(qsTr("Voer eerst de alarmcode in"));
                return;
            }
        } else {
            service = "alarm_arm_away";
            if (alarmCode != "") {
                payload.code = alarmCode;
            }
        }
        callApi("POST", "/api/services/alarm_control_panel/" + service, JSON.stringify(payload), function (status) {
            if (status != 200) {
                notify(qsTr("Alarm commando mislukt (HTTP ") + status + ")");
            }
            alarmInputReset();
            startRefreshCycle();
        });
    }

    //
    // Debug log
    //

    function logText(log) {
        if (debug) {
            var d = new Date();
            var datetext = d.toTimeString().split(" ")[0];
            message = message + "\n[" + datetext + "." + d.getMilliseconds() + "] " + log;
            if (message.length > 6000) {
                message = message.slice(-5000);
            }
            logShown = true;
        }
    }

    //
    // Boot
    //

    function init() {
        registry.registerWidget("tile", tileUrl, this, null, {thumbLabel: qsTr("Home Assistant"), thumbIcon: thumbnailIcon, thumbCategory: "general", thumbWeight: 30, baseTileWeight: 10, baseTileSolarWeight: 10, thumbIconVAlignment: "center"});
        registry.registerWidget("screen", homeAssistantConfigurationScreenUrl, this, "homeAssistantConfigurationScreen");
        registry.registerWidget("screen", homeAssistantScreenUrl, this, "homeAssistantScreen");
    }

    Component.onCompleted: {
        updateClockInfo();
        readSettings();
    }
}
