// calendarWorker.js
//
// Parses iCalendar (ICS) text and expands recurring events into the upcoming occurrences.
// Normally this runs in a WorkerScript thread so the Toon interface stays responsive while
// large calendars are processed. CalendarApp.qml also imports this file directly and uses
// processCalendars() in the interface thread as a fallback when the worker does not answer.
//
// Plain ES5 only: the Toon runs Qt 5.11 (no let/const, arrow functions, etc).
//
// Supported: DTSTART/DTEND/DURATION (date, local date-time, UTC date-time), SUMMARY, STATUS:CANCELLED,
// VALARM TRIGGER (relative and absolute), RRULE with FREQ=DAILY/WEEKLY/MONTHLY/YEARLY, INTERVAL, COUNT,
// UNTIL, BYDAY (with ordinals like 2TU or -1FR), BYMONTHDAY, BYMONTH, BYSETPOS, WKST, RDATE, EXDATE and
// RECURRENCE-ID (moved or changed single instances of a series).
// Times with a TZID are treated as local Toon time (calendars are normally in the same timezone).

var DAY_MS = 86400000;
var WEEKDAYS = { SU: 0, MO: 1, TU: 2, WE: 3, TH: 4, FR: 5, SA: 6 };
var MAX_PERIODS = 6000;		// safety limit on the number of recurrence periods examined per series
var FAR_FUTURE = 1e15;

function contains(arr, v) {
	for (var i = 0; i < arr.length; i++) if (arr[i] === v) return true;
	return false;
}

function pad2(n) {
	return (n < 10 ? "0" : "") + n;
}

function sortNums(arr) {
	arr.sort(function(a, b) { return a - b; });
	var out = [];
	for (var i = 0; i < arr.length; i++) if (i === 0 || arr[i] !== arr[i - 1]) out.push(arr[i]);
	return out;
}

// ---------------------------------------------------------------------------------------------
// Calendar arithmetic. Events with a UTC DTSTART recur in UTC, everything else in local time.

function parts(ms, utc) {
	var d = new Date(ms);
	if (utc) return { y: d.getUTCFullYear(), m: d.getUTCMonth(), d: d.getUTCDate(), h: d.getUTCHours(), mi: d.getUTCMinutes(), s: d.getUTCSeconds(), w: d.getUTCDay() };
	return { y: d.getFullYear(), m: d.getMonth(), d: d.getDate(), h: d.getHours(), mi: d.getMinutes(), s: d.getSeconds(), w: d.getDay() };
}

function make(y, m, d, h, mi, s, utc) {
	if (utc) return Date.UTC(y, m, d, h, mi, s);
	return new Date(y, m, d, h, mi, s).getTime();
}

function daysInMonth(y, m, utc) {
	return parts(make(y, m + 1, 0, 12, 0, 0, utc), utc).d;
}

function ymd(ms) {
	var p = parts(ms, false);
	return p.y + "-" + pad2(p.m + 1) + "-" + pad2(p.d);
}

function hm(ms) {
	var p = parts(ms, false);
	return pad2(p.h) + ":" + pad2(p.mi);
}

// adds whole days to a timestamp keeping the wall clock time (DST safe)
function addDays(ms, days, utc) {
	var p = parts(ms, utc);
	return make(p.y, p.m, p.d + days, p.h, p.mi, p.s, utc);
}

// ---------------------------------------------------------------------------------------------
// ICS text parsing

function unfold(text) {
	return text.replace(/\r\n|\r/g, "\n").replace(/\n[ \t]/g, "");
}

// The Toon's XMLHttpRequest decodes the response with the charset from the Content-Type header
// (Latin-1 when a server declares iso-8859-1 while actually sending UTF-8, as the astronomy calendar does),
// so UTF-8 text arrives as mojibake: two odd characters for an accented letter, four for an emoji.
// When a UTF-8 lead byte followed by a continuation byte is found, the text is decoded again as UTF-8.
// A windows-1252 decoding maps the bytes 0x80-0x9F to other code points; these are mapped back first.

var CP1252 = {};
(function() {
	var codes = [0x20AC, 0, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, 0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0, 0x017D, 0,
		     0, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014, 0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0, 0x017E, 0x0178];
	for (var i = 0; i < codes.length; i++) if (codes[i]) CP1252[codes[i]] = 0x80 + i;
})();

function byteAt(text, i) {		// the original byte of a Latin-1 / windows-1252 decoded character, or the code point
	var c = text.charCodeAt(i);
	return (c > 0xFF && CP1252[c]) ? CP1252[c] : c;
}

function looksLikeMisdecodedUtf8(text) {
	var n = text.length, c;
	for (var i = 0; i + 1 < n; i++) {
		c = byteAt(text, i);
		if (c >= 0xC2 && c <= 0xF4 && (byteAt(text, i + 1) & 0xC0) === 0x80) return true;
		if (c > 0xFF) return false;		// already properly decoded
	}
	return false;
}

function repairUtf8(text) {
	if (!looksLikeMisdecodedUtf8(text)) return text;
	var out = [], n = text.length, i = 0, run = 0, c, c2, c3, c4, cp;
	while (i < n) {
		c = byteAt(text, i);
		if (c < 0x80 || c > 0xFF) { i++; continue; }
		c2 = i + 1 < n ? byteAt(text, i + 1) : 0;
		c3 = i + 2 < n ? byteAt(text, i + 2) : 0;
		c4 = i + 3 < n ? byteAt(text, i + 3) : 0;
		if (c >= 0xC2 && c <= 0xDF && (c2 & 0xC0) === 0x80) {
			cp = ((c & 0x1F) << 6) | (c2 & 0x3F);
			out.push(text.substring(run, i), String.fromCharCode(cp));
			i += 2;
		} else if (c >= 0xE0 && c <= 0xEF && (c2 & 0xC0) === 0x80 && (c3 & 0xC0) === 0x80) {
			cp = ((c & 0x0F) << 12) | ((c2 & 0x3F) << 6) | (c3 & 0x3F);
			out.push(text.substring(run, i), String.fromCharCode(cp));
			i += 3;
		} else if (c >= 0xF0 && c <= 0xF4 && (c2 & 0xC0) === 0x80 && (c3 & 0xC0) === 0x80 && (c4 & 0xC0) === 0x80) {
			cp = (((c & 0x07) << 18) | ((c2 & 0x3F) << 12) | ((c3 & 0x3F) << 6) | (c4 & 0x3F)) - 0x10000;
			out.push(text.substring(run, i), String.fromCharCode(0xD800 + (cp >> 10), 0xDC00 + (cp & 0x3FF)));
			i += 4;
		} else {
			i++;				// a genuine Latin-1 character, keep it
			continue;
		}
		run = i;
	}
	out.push(text.substring(run));
	return out.join("");
}

function unescapeText(s) {
	s = s.replace(/\\n/gi, " ").replace(/\\,/g, ",").replace(/\\;/g, ";").replace(/\\\\/g, "\\");
	return stripEmoji(s);
}

// the Toon font has no emoji: remove characters outside the basic plane (surrogate pairs), the
// miscellaneous symbols / dingbats / arrows blocks and the invisible joiner and variation selectors
function stripEmoji(s) {
	return s.replace(/[\uD800-\uDFFF\u2600-\u27BF\u2B00-\u2BFF\u2300-\u23FF\uFE0F\u200D\u20E3]/g, "").replace(/\s+/g, " ").replace(/^\s+|\s+$/g, "");
}

// splits "NAME;PARAM=value;PARAM2="quoted:value":the value" into its parts
function parseLine(line) {
	var inQuote = false, nameEnd = -1, colon = -1, i, c;
	for (i = 0; i < line.length; i++) {
		c = line.charAt(i);
		if (c === '"') {
			inQuote = !inQuote;
		} else if (!inQuote) {
			if (c === ';' && nameEnd < 0) nameEnd = i;
			else if (c === ':') { colon = i; break; }
		}
	}
	if (colon < 0) return null;
	var params = {};
	if (nameEnd >= 0) {
		var plist = line.substring(nameEnd + 1, colon).split(";");
		for (i = 0; i < plist.length; i++) {
			var eq = plist[i].indexOf("=");
			if (eq > 0) params[plist[i].substring(0, eq).toUpperCase()] = plist[i].substring(eq + 1).replace(/"/g, "");
		}
	}
	return { name: line.substring(0, nameEnd < 0 ? colon : nameEnd).toUpperCase(), params: params, value: line.substring(colon + 1) };
}

// returns {ms, allDay, utc} or null. Date-only values become local midnight.
function parseDate(params, value) {
	var v = value.replace(/\s/g, "");
	var m = /^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})?(Z)?)?$/.exec(v);
	if (!m) return null;
	var y = parseInt(m[1], 10), mo = parseInt(m[2], 10) - 1, d = parseInt(m[3], 10);
	if (!m[4] || params.VALUE === "DATE") {
		return { ms: make(y, mo, d, 0, 0, 0, false), allDay: true, utc: false };
	}
	var h = parseInt(m[4], 10), mi = parseInt(m[5], 10), s = m[6] ? parseInt(m[6], 10) : 0;
	var tz = (params.TZID || "").toUpperCase();
	var utc = !!m[7] || tz === "UTC" || tz === "GMT" || tz === "ETC/UTC" || tz === "Z";
	return { ms: make(y, mo, d, h, mi, s, utc), allDay: false, utc: utc };
}

// ISO 8601 duration like -P0DT0H20M0S or P1W, returns milliseconds (or null)
function parseDuration(value) {
	var m = /^([+-])?P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$/.exec(value.replace(/\s/g, ""));
	if (!m) return null;
	var ms = ((parseInt(m[2] || 0, 10) * 7 + parseInt(m[3] || 0, 10)) * 86400 + parseInt(m[4] || 0, 10) * 3600 + parseInt(m[5] || 0, 10) * 60 + parseInt(m[6] || 0, 10)) * 1000;
	return m[1] === "-" ? -ms : ms;
}

function newEvent(calIndex) {
	return { cal: calIndex, uid: "", summary: "", dtstart: null, dtend: null, duration: null, rrule: "", exdates: [], rdates: [], recurrenceId: null, status: "", sequence: 0, triggers: [], valid: false };
}

function finishEvent(ev) {
	if (!ev.dtstart) return;
	ev.valid = true;
	ev.start = ev.dtstart.ms;
	ev.allDay = ev.dtstart.allDay;
	ev.utc = ev.dtstart.utc;
	if (ev.dtend) {
		ev.end = ev.dtend.ms;
	} else if (ev.duration !== null) {
		ev.end = ev.start + ev.duration;
	} else {
		ev.end = ev.allDay ? addDays(ev.start, 1, false) : ev.start;
	}
	if (ev.end < ev.start) ev.end = ev.start;
	if (ev.allDay && ev.end <= ev.start) ev.end = addDays(ev.start, 1, false);
	ev.durationDays = ev.allDay ? Math.round((ev.end - ev.start) / DAY_MS) : 0;

	// reminder: keep the earliest trigger, expressed as milliseconds relative to the start
	ev.alarm = null;
	for (var i = 0; i < ev.triggers.length; i++) {
		var t = ev.triggers[i], offset = null;
		if (t.params.VALUE === "DATE-TIME" || /^\d{8}T/.test(t.value)) {
			var abs = parseDate(t.params, t.value);
			if (abs) offset = abs.ms - ev.start;
		} else {
			var dur = parseDuration(t.value);
			if (dur !== null) offset = (t.params.RELATED === "END") ? (ev.end - ev.start) + dur : dur;
		}
		if (offset !== null && (ev.alarm === null || offset < ev.alarm)) ev.alarm = offset;
	}
}

function parseCalendar(text, calIndex) {
	var lines = unfold(repairUtf8(text)).split("\n");
	var events = [], ev = null, inAlarm = false, depth = 0, i, j, prop, vals, dt;
	for (i = 0; i < lines.length; i++) {
		if (!lines[i]) continue;
		prop = parseLine(lines[i]);
		if (!prop) continue;
		if (prop.name === "BEGIN") {
			var comp = prop.value.toUpperCase();
			if (comp === "VEVENT") { ev = newEvent(calIndex); inAlarm = false; depth = 0; }
			else if (ev) { depth++; if (comp === "VALARM") inAlarm = true; }
			continue;
		}
		if (prop.name === "END") {
			var ecomp = prop.value.toUpperCase();
			if (ecomp === "VEVENT" && ev) { finishEvent(ev); if (ev.valid) events.push(ev); ev = null; }
			else if (ev) { depth--; if (ecomp === "VALARM") inAlarm = false; }
			continue;
		}
		if (!ev) continue;
		if (inAlarm) { if (prop.name === "TRIGGER") ev.triggers.push(prop); continue; }
		if (depth > 0) continue;
		switch (prop.name) {
			case "UID": ev.uid = prop.value; break;
			case "SUMMARY": ev.summary = unescapeText(prop.value); break;
			case "DTSTART": ev.dtstart = parseDate(prop.params, prop.value); break;
			case "DTEND": ev.dtend = parseDate(prop.params, prop.value); break;
			case "DURATION": ev.duration = parseDuration(prop.value); break;
			case "RRULE": if (!ev.rrule) ev.rrule = prop.value; break;
			case "RECURRENCE-ID": ev.recurrenceId = parseDate(prop.params, prop.value); break;
			case "STATUS": ev.status = prop.value.toUpperCase(); break;
			case "SEQUENCE": ev.sequence = parseInt(prop.value, 10) || 0; break;
			case "EXDATE":
			case "RDATE":
				vals = prop.value.split(",");
				for (j = 0; j < vals.length; j++) {
					dt = parseDate(prop.params, vals[j].split("/")[0]);	// RDATE may be a period "start/end"
					if (dt) (prop.name === "EXDATE" ? ev.exdates : ev.rdates).push(dt);
				}
				break;
			default: break;
		}
	}
	return events;
}

// ---------------------------------------------------------------------------------------------
// Recurrence rules

function parseRRule(str) {
	var rule = { freq: "", interval: 1, count: FAR_FUTURE, until: FAR_FUTURE, byday: [], bymonthday: [], bymonth: [], bysetpos: [], wkst: 1 };
	var items = str.split(";"), i, j, kv, key, val, list, m;
	for (i = 0; i < items.length; i++) {
		kv = items[i].split("=");
		if (kv.length < 2) continue;
		key = kv[0].toUpperCase();
		val = kv[1].toUpperCase();
		switch (key) {
			case "FREQ": rule.freq = val; break;
			case "INTERVAL": rule.interval = Math.max(1, parseInt(val, 10) || 1); break;
			case "COUNT": rule.count = parseInt(val, 10) || FAR_FUTURE; break;
			case "UNTIL":
				var u = parseDate({}, val);
				if (u) rule.until = u.allDay ? make(parts(u.ms, false).y, parts(u.ms, false).m, parts(u.ms, false).d, 23, 59, 59, false) : u.ms;
				break;
			case "WKST": if (WEEKDAYS[val] !== undefined) rule.wkst = WEEKDAYS[val]; break;
			case "BYDAY":
				list = val.split(",");
				for (j = 0; j < list.length; j++) {
					m = /^([+-]?\d+)?(SU|MO|TU|WE|TH|FR|SA)$/.exec(list[j]);
					if (m) rule.byday.push({ ord: m[1] ? parseInt(m[1], 10) : 0, day: WEEKDAYS[m[2]] });
				}
				break;
			case "BYMONTHDAY":
			case "BYMONTH":
			case "BYSETPOS":
				list = val.split(",");
				for (j = 0; j < list.length; j++) {
					var n = parseInt(list[j], 10);
					if (!isNaN(n)) (key === "BYMONTHDAY" ? rule.bymonthday : key === "BYMONTH" ? rule.bymonth : rule.bysetpos).push(n);
				}
				break;
			default: break;
		}
	}
	if (rule.freq !== "DAILY" && rule.freq !== "WEEKLY" && rule.freq !== "MONTHLY" && rule.freq !== "YEARLY") return null;
	return rule;
}

function recurFlag(rrule) {
	if (!rrule) return "";
	if (rrule.indexOf("FREQ=YEARLY") > -1) return "(j)";
	if (rrule.indexOf("FREQ=MONTHLY") > -1) return "(m)";
	if (rrule.indexOf("FREQ=WEEKLY") > -1) return "(w)";
	if (rrule.indexOf("FREQ=DAILY") > -1) return "(d)";
	return "(*)";
}

function matchesByDay(rule, weekday) {
	if (!rule.byday.length) return true;
	for (var i = 0; i < rule.byday.length; i++) if (rule.byday[i].day === weekday) return true;
	return false;
}

function matchesByMonthDay(rule, p, utc) {
	if (!rule.bymonthday.length) return true;
	var dim = daysInMonth(p.y, p.m, utc);
	for (var i = 0; i < rule.bymonthday.length; i++) {
		var d = rule.bymonthday[i];
		if (d < 0) d = dim + d + 1;
		if (d === p.d) return true;
	}
	return false;
}

function matchesByMonth(rule, month) {
	return !rule.bymonth.length || contains(rule.bymonth, month + 1);
}

// all days with the given weekday between the first of month mFrom and the first of month mToExcl,
// reduced to the requested ordinal (0 = all, 1 = first, -1 = last, ...)
function pickWeekdays(y, mFrom, mToExcl, bd, st, utc, out) {
	var endMs = make(y, mToExcl, 1, st.h, st.mi, st.s, utc), found = [], k, c;
	for (k = 0; k < 400; k++) {
		c = make(y, mFrom, 1 + k, st.h, st.mi, st.s, utc);
		if (c >= endMs) break;
		if (parts(c, utc).w === bd.day) found.push(c);
	}
	if (bd.ord === 0) {
		for (k = 0; k < found.length; k++) out.push(found[k]);
	} else {
		var idx = bd.ord > 0 ? bd.ord - 1 : found.length + bd.ord;
		if (idx >= 0 && idx < found.length) out.push(found[idx]);
	}
}

function monthCandidates(rule, y, m, st, utc, out) {
	var dim = daysInMonth(y, m, utc), i, d, c;
	if (rule.bymonthday.length) {
		for (i = 0; i < rule.bymonthday.length; i++) {
			d = rule.bymonthday[i];
			if (d < 0) d = dim + d + 1;
			if (d >= 1 && d <= dim) {
				c = make(y, m, d, st.h, st.mi, st.s, utc);
				if (matchesByDay(rule, parts(c, utc).w)) out.push(c);
			}
		}
	} else if (rule.byday.length) {
		for (i = 0; i < rule.byday.length; i++) pickWeekdays(y, m, m + 1, rule.byday[i], st, utc, out);
	} else if (st.d <= dim) {
		out.push(make(y, m, st.d, st.h, st.mi, st.s, utc));
	}
}

// candidate occurrences for recurrence period number p (0 = the period containing DTSTART)
// returns {start: first ms of the period, list: sorted candidate timestamps}
function periodCandidates(rule, st, p, utc) {
	var iv = rule.interval, out = [], i, ms, pr, c;
	if (rule.freq === "DAILY") {
		ms = make(st.y, st.m, st.d + p * iv, st.h, st.mi, st.s, utc);
		pr = parts(ms, utc);
		if (matchesByDay(rule, pr.w) && matchesByMonthDay(rule, pr, utc) && matchesByMonth(rule, pr.m)) out.push(ms);
		return { start: make(pr.y, pr.m, pr.d, 0, 0, 0, utc), list: out };
	}
	if (rule.freq === "WEEKLY") {
		ms = make(st.y, st.m, st.d + p * iv * 7, st.h, st.mi, st.s, utc);
		pr = parts(ms, utc);
		var back = (pr.w - rule.wkst + 7) % 7;		// days since the start of this week
		if (rule.byday.length) {
			for (i = 0; i < rule.byday.length; i++) {
				c = make(pr.y, pr.m, pr.d - back + ((rule.byday[i].day - rule.wkst + 7) % 7), st.h, st.mi, st.s, utc);
				if (matchesByMonth(rule, parts(c, utc).m)) out.push(c);
			}
		} else {
			out.push(ms);
		}
		return { start: make(pr.y, pr.m, pr.d - back, 0, 0, 0, utc), list: applySetPos(rule, sortNums(out)) };
	}
	if (rule.freq === "MONTHLY") {
		pr = parts(make(st.y, st.m + p * iv, 1, 12, 0, 0, utc), utc);
		if (matchesByMonth(rule, pr.m)) monthCandidates(rule, pr.y, pr.m, st, utc, out);
		return { start: make(pr.y, pr.m, 1, 0, 0, 0, utc), list: applySetPos(rule, sortNums(out)) };
	}
	// YEARLY
	var y = st.y + p * iv;
	if (rule.bymonth.length) {
		for (i = 0; i < rule.bymonth.length; i++) monthCandidates(rule, y, rule.bymonth[i] - 1, st, utc, out);
	} else if (rule.byday.length && !rule.bymonthday.length) {
		for (i = 0; i < rule.byday.length; i++) pickWeekdays(y, 0, 12, rule.byday[i], st, utc, out);	// n-th weekday of the year
	} else {
		monthCandidates(rule, y, st.m, st, utc, out);		// same month as DTSTART
	}
	return { start: make(y, 0, 1, 0, 0, 0, utc), list: applySetPos(rule, sortNums(out)) };
}

function applySetPos(rule, list) {
	if (!rule.bysetpos.length || !list.length) return list;
	var out = [];
	for (var i = 0; i < rule.bysetpos.length; i++) {
		var idx = rule.bysetpos[i] > 0 ? rule.bysetpos[i] - 1 : list.length + rule.bysetpos[i];
		if (idx >= 0 && idx < list.length) out.push(list[idx]);
	}
	return sortNums(out);
}

// calls sink(startMs) for every occurrence of the series that ends after nowMs and starts before windowEnd
function expandRule(ev, rule, nowMs, windowEnd, sink) {
	var st = parts(ev.start, ev.utc);
	var duration = ev.end - ev.start;
	var emitted = 0, p, i, period, list, c;
	for (p = 0; p < MAX_PERIODS; p++) {
		period = periodCandidates(rule, st, p, ev.utc);
		if (period.start > windowEnd || period.start > rule.until) return;
		list = period.list;
		if (p === 0 && !contains(list, ev.start)) {		// DTSTART always counts as the first occurrence
			list.push(ev.start);
			list = sortNums(list);
		}
		for (i = 0; i < list.length; i++) {
			c = list[i];
			if (c < ev.start) continue;
			if (c > rule.until) return;
			emitted++;
			if (c <= windowEnd && c + duration > nowMs) sink(c);
			if (emitted >= rule.count) return;
		}
	}
}

// ---------------------------------------------------------------------------------------------
// Building the result list

function makeEntry(ev, startMs, endMs, flag) {
	var showEnd = ev.allDay ? endMs - 60000 : endMs;	// all day events end at 23:59 of the last day
	return {
		start: startMs,
		end: endMs,
		allDay: ev.allDay,
		cal: ev.cal,
		flag: flag,
		yearly: (flag === "(j)"),
		alarm: ev.alarm,
		title: ev.summary || "(geen titel)",
		date: ymd(startMs),
		time: ev.allDay ? "" : hm(startMs),
		endDate: ymd(showEnd),
		endTime: ev.allDay ? "" : hm(showEnd)
	};
}

function emit(out, ev, startMs, endMs, flag, nowMs, windowEnd) {
	if (ev.status === "CANCELLED") return;
	if (endMs <= nowMs || startMs > windowEnd) return;
	out.push(makeEntry(ev, startMs, endMs, flag));
}

function exclusionKey(dt) {
	return dt.allDay ? "D" + ymd(dt.ms) : "T" + dt.ms;
}

function isExcluded(excl, ms) {
	return excl["T" + ms] === true || excl["D" + ymd(ms)] === true;
}

function expandEvents(events, nowMs, windowEnd, out) {
	var masters = {}, overrides = {}, order = [], i, j, ev, key;

	// group the events of a series (same UID): the master with the RRULE and the changed instances
	for (i = 0; i < events.length; i++) {
		ev = events[i];
		key = ev.uid || ("#" + i);
		if (ev.recurrenceId) {
			if (!overrides[key]) overrides[key] = [];
			overrides[key].push(ev);
		} else {
			if (!masters[key]) { masters[key] = []; order.push(key); }
			masters[key].push(ev);
		}
	}

	for (i = 0; i < order.length; i++) {
		key = order[i];
		var ovs = overrides[key] || [];
		delete overrides[key];
		for (j = 0; j < masters[key].length; j++) {
			ev = masters[key][j];
			var flag = recurFlag(ev.rrule);
			var rule = ev.rrule ? parseRRule(ev.rrule) : null;
			if (!rule && !ev.rdates.length) {
				emit(out, ev, ev.start, ev.end, flag, nowMs, windowEnd);
				continue;
			}
			var excl = {}, k;
			for (k = 0; k < ev.exdates.length; k++) excl[exclusionKey(ev.exdates[k])] = true;
			for (k = 0; k < ovs.length; k++) excl[exclusionKey(ovs[k].recurrenceId)] = true;
			var produced = {};
			var sink = (function(master) {
				return function(startMs) {
					if (isExcluded(excl, startMs) || produced[startMs]) return;
					produced[startMs] = true;
					var endMs = master.allDay ? addDays(startMs, master.durationDays, false) : startMs + (master.end - master.start);
					emit(out, master, startMs, endMs, flag, nowMs, windowEnd);
				};
			})(ev);
			if (rule) expandRule(ev, rule, nowMs, windowEnd, sink);
			else sink(ev.start);
			for (k = 0; k < ev.rdates.length; k++) sink(ev.rdates[k].ms);
		}
		// changed instances (moved, renamed, ...) are shown at their new date and time
		for (j = 0; j < ovs.length; j++) emit(out, ovs[j], ovs[j].start, ovs[j].end, recurFlag(masters[key][0].rrule), nowMs, windowEnd);
	}

	// changed instances whose master is not in this file
	for (key in overrides) {
		if (!overrides.hasOwnProperty(key)) continue;
		for (j = 0; j < overrides[key].length; j++) emit(out, overrides[key][j], overrides[key][j].start, overrides[key][j].end, "", nowMs, windowEnd);
	}
}

// request: { nowMs, horizonDays, maxItems, calendars: [ { index, text } ] }
// result:  { events: [ entry, ... ] sorted by start, info: "debug string" }
function processCalendars(request) {
	var nowMs = request.nowMs || new Date().getTime();
	var windowEnd = nowMs + (request.horizonDays || 366) * DAY_MS;
	var maxItems = request.maxItems || 224;
	var out = [], info = [], i;
	for (i = 0; i < request.calendars.length; i++) {
		var cal = request.calendars[i];
		try {
			var events = parseCalendar(cal.text || "", cal.index);
			var before = out.length;
			expandEvents(events, nowMs, windowEnd, out);
			info.push("calendar " + cal.index + ": " + events.length + " events, " + (out.length - before) + " upcoming");
		} catch (e) {
			info.push("calendar " + cal.index + ": error " + e);
		}
	}
	out.sort(function(a, b) {
		if (a.start !== b.start) return a.start - b.start;
		if (a.cal !== b.cal) return a.cal - b.cal;
		return a.title < b.title ? -1 : (a.title > b.title ? 1 : 0);
	});
	if (out.length > maxItems) out.length = maxItems;
	return { events: out, info: info.join("; ") };
}

// ---------------------------------------------------------------------------------------------
// WorkerScript entry point (not present when this file is imported by CalendarApp.qml)

if (typeof WorkerScript !== "undefined") {
	WorkerScript.onMessage = function(message) {
		var reply = { seq: message.seq };
		try {
			var result = processCalendars(message);
			reply.events = result.events;
			reply.info = result.info;
		} catch (e) {
			reply.error = String(e);
		}
		WorkerScript.sendMessage(reply);
	};
}
