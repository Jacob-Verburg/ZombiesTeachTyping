// Zombies Teach Typing — frame / latency / key probe (Story 5.3).
// Dev tool only: paste into the browser DevTools Console on the release build.
// Never shipped (tools/ is export-excluded). It only observes: no preventDefault,
// no storage, no network (NFR12).
//
//   zts_probe.arm()                 record 120 s from the next letter key (a-z)
//   zts_probe.arm({seconds: 180})   record 180 s instead (Horde Rush, Story 6.7); works with startNow
//   zts_probe.arm({startNow: true}) record now ("load window", not M1's RUNNING row)
//   zts_probe.stop()                end early and print the summary
//   zts_probe.summary()             print the last summary again
//   zts_probe.keys()                table of Space ' / Backspace Tab Escape presses
//   zts_probe.result()              one JSON-able object with everything
//   zts_probe.selftest()            checks the summary maths against fixed numbers
(function () {
	"use strict";
	var ZTS_PROBE_SECONDS = 120;
	var EXTRA_MS = 500;
	// Frames per second of recording the buffer holds (a 240 Hz screen fills it exactly).
	var BUFFER_HZ = 240;
	// The current arm's length; arm({seconds}) changes it and the buffer is sized from it.
	var probeSeconds = ZTS_PROBE_SECONDS;
	var MAX_FRAMES = bufferFrames(probeSeconds);
	var MAX_KEYS = 4000;
	var MAX_KEY_ROWS = 500;
	var NFR1_FAIL_MS = 33.4;
	var VSYNC_MISS_MS = 17.5;
	// NFR1: no frame over 33 ms. 33.4 (not 33.0) so a vsync-rounded 33.33 ms frame is not counted.
	// NFR1 FPS floor is 59 so 59.94 Hz panels pass. NFR2: one 60 Hz refresh (16.7) plus 0.5 ms.
	var NFR2_LIMIT_MS = 17.2;
	var LONG_GAP_MS = 1000;
	var WATCHED_KEYS = [" ", "'", "/", "Backspace", "Tab", "Escape"];

	if (window.zts_probe && window.zts_probe._teardown) {
		window.zts_probe._teardown();
	}

	function bufferFrames(seconds) {
		return Math.ceil((seconds + 1) * BUFFER_HZ);
	}

	var frameTimes = new Float64Array(MAX_FRAMES);
	var frameFocus = new Uint8Array(MAX_FRAMES);
	var frameCount = 0;
	var latencies = new Float64Array(MAX_KEYS);
	var latencyCount = 0;
	var pendingKeys = [];
	var keyRows = [];
	var droppedLatencies = 0;
	var droppedKeyRows = 0;
	var truncated = false;

	var state = "idle"; // idle | armed | recording | done
	var mode = "running"; // running | load window
	var startTs = 0;
	var focused = document.hasFocus() && !document.hidden;
	var focusTimer = 0;
	var rafId = 0;
	var lastSummary = null;
	var lastRun = null;

	function isLetter(evt) {
		if (typeof evt.key !== "string" || evt.key.length !== 1) { return false; }
		var k = evt.key.toLowerCase(); // Caps Lock / Shift give "A"
		return k >= "a" && k <= "z"
			&& !evt.ctrlKey && !evt.metaKey && !evt.altKey;
	}

	function percentile(sorted, p) {
		if (sorted.length === 0) { return 0; }
		var rank = Math.ceil(p / 100 * sorted.length);
		return sorted[Math.min(sorted.length - 1, Math.max(0, rank - 1))];
	}

	function round2(x) { return Math.round(x * 100) / 100; }

	// Pure: intervals in ms -> stats. Also used by selftest().
	function summarize(intervals, refreshSample) {
		var n = intervals.length;
		var sorted = Array.prototype.slice.call(intervals).sort(function (a, b) { return a - b; });
		var sum = 0, over33 = 0, over17 = 0;
		for (var i = 0; i < n; i++) {
			sum += intervals[i];
			if (intervals[i] > NFR1_FAIL_MS) { over33++; }
			if (intervals[i] > VSYNC_MISS_MS) { over17++; }
		}
		var refSorted = Array.prototype.slice.call(refreshSample || intervals).sort(function (a, b) { return a - b; });
		var fps = sum > 0 ? n / (sum / 1000) : 0;
		return {
			frames: n,
			mean_ms: n ? round2(sum / n) : 0,
			p50_ms: round2(percentile(sorted, 50)),
			p95_ms: round2(percentile(sorted, 95)),
			p99_ms: round2(percentile(sorted, 99)),
			max_ms: n ? round2(sorted[n - 1]) : 0,
			over_33ms: over33,
			over_17_5ms: over17,
			fps: round2(fps),
			refresh_ms: round2(percentile(refSorted, 50)),
			// 59 allows 59.94 Hz panels; NFR1 is "60 FPS, no frame over 33 ms".
			nfr1_pass: n > 0 && over33 === 0 && fps >= 59
		};
	}

	function latencySummary(values, refreshMs) {
		var sorted = Array.prototype.slice.call(values).sort(function (a, b) { return a - b; });
		var n = sorted.length;
		var maxMs = n ? sorted[n - 1] : 0;
		return {
			keys: n,
			p50_ms: round2(percentile(sorted, 50)),
			p95_ms: round2(percentile(sorted, 95)),
			max_ms: round2(maxMs),
			refresh_ms: round2(refreshMs),
			// Fixed limit, not derived from the measured refresh: a throttled (30 Hz) tab must fail.
			nfr2_pass: n > 0 && maxMs <= NFR2_LIMIT_MS,
			note: "keydown timeStamp -> next rAF frame timestamp; the visual is presented at the following vsync"
		};
	}

	function buildRun() {
		var all = [];
		var focusedOnly = [];
		var unfocusedFrames = 0;
		var longGaps = 0;
		for (var i = 1; i < frameCount; i++) {
			var dt = frameTimes[i] - frameTimes[i - 1];
			all.push(dt);
			if (frameFocus[i] && frameFocus[i - 1]) {
				focusedOnly.push(dt);
				if (dt > LONG_GAP_MS) { longGaps++; }
			} else {
				unfocusedFrames++;
			}
		}
		// refresh_ms is the median of the whole run, not the (hitchy) first second.
		var focusedStats = summarize(focusedOnly, null);
		var rawStats = summarize(all, null);
		var lat = latencySummary(latencies.subarray(0, latencyCount), focusedStats.refresh_ms);
		return {
			label: mode === "load window" ? "load window (not M1 RUNNING)" : "RUNNING (first letter -> " + probeSeconds + " s)",
			duration_s: frameCount > 1 ? round2((frameTimes[frameCount - 1] - frameTimes[0]) / 1000) : 0,
			is_running_row: mode !== "load window",
			frames_while_unfocused: unfocusedFrames,
			focused_gaps_over_1s: longGaps,
			truncated: truncated,
			dropped_latency_samples: droppedLatencies,
			dropped_key_rows: droppedKeyRows,
			nfr1: focusedStats,
			raw_including_unfocused: rawStats,
			nfr2_latency: lat
		};
	}

	function printSummary(run) {
		var s = run.nfr1, l = run.nfr2_latency;
		console.log("[zts_probe] " + run.label + ", " + run.duration_s + " s");
		console.log("[zts_probe] frames " + s.frames + " | mean " + s.mean_ms + " | p50 " + s.p50_ms
			+ " | p95 " + s.p95_ms + " | p99 " + s.p99_ms + " | max " + s.max_ms + " ms");
		console.log("[zts_probe] > 33 ms: " + s.over_33ms + " | > 17.5 ms: " + s.over_17_5ms
			+ " | FPS " + s.fps + " | refresh " + s.refresh_ms + " ms | NFR1 "
			+ (run.is_running_row ? (s.nfr1_pass ? "PASS" : "FAIL") : "n/a (load window)"));
		if (run.focused_gaps_over_1s > 0) {
			console.log("[zts_probe] WARNING " + run.focused_gaps_over_1s
				+ " focused gap(s) over 1 s: a real freeze, or the tab was hidden. They are counted in the numbers above.");
		}
		if (run.truncated) {
			console.log("[zts_probe] WARNING the frame buffer filled before the run ended (screen faster than 240 Hz); the run is incomplete.");
		}
		if (run.dropped_latency_samples > 0) {
			console.log("[zts_probe] WARNING " + run.dropped_latency_samples + " key latency samples dropped (buffer full).");
		}
		if (run.frames_while_unfocused > 0) {
			console.log("[zts_probe] " + run.frames_while_unfocused
				+ " frames while unfocused (left out of the numbers above; the run pauses on blur)");
		}
		console.log("[zts_probe] latency keys " + l.keys + " | p50 " + l.p50_ms + " | p95 " + l.p95_ms
			+ " | max " + l.max_ms + " ms | NFR2 " + (run.is_running_row ? (l.nfr2_pass ? "PASS" : "FAIL") : "n/a (load window)") + " (" + l.note + ")");
		console.log("[zts_probe] copy(JSON.stringify(zts_probe.result())) to copy everything");
	}

	function onFrame(ts) {
		if (state !== "recording") { return; }
		if (frameCount < MAX_FRAMES) {
			frameTimes[frameCount] = ts;
			frameFocus[frameCount] = focused ? 1 : 0;
			frameCount++;
		}
		// Frame start (rAF timestamp) minus the key's timestamp. A key that arrives after the
		// frame started but before its callbacks ran is handled in this frame: 0.
		for (var i = 0; i < pendingKeys.length; i++) {
			if (latencyCount < MAX_KEYS) {
				latencies[latencyCount++] = Math.max(0, ts - pendingKeys[i]);
			} else {
				droppedLatencies++;
			}
		}
		pendingKeys.length = 0;
		if (ts - startTs >= probeSeconds * 1000 + EXTRA_MS || frameCount >= MAX_FRAMES) {
			truncated = ts - startTs < probeSeconds * 1000;
			finish();
			return;
		}
		rafId = requestAnimationFrame(onFrame);
	}

	function updateFocus() {
		focused = document.hasFocus() && !document.hidden;
	}

	function startRecording() {
		frameCount = 0;
		latencyCount = 0;
		droppedLatencies = 0;
		truncated = false;
		pendingKeys.length = 0;
		state = "recording";
		startTs = performance.now();
		updateFocus();
		clearInterval(focusTimer);
		focusTimer = setInterval(updateFocus, 250);
		rafId = requestAnimationFrame(onFrame);
	}

	function finish() {
		if (state !== "recording") { return; }
		state = "done";
		cancelAnimationFrame(rafId);
		clearInterval(focusTimer);
		lastRun = buildRun();
		lastSummary = lastRun;
		printSummary(lastRun);
	}

	// Capture phase so the time is taken before anything else sees the key.
	function onKeyLatency(evt) {
		if (evt.repeat || !isLetter(evt)) { return; }
		if (state === "armed") {
			startRecording();
			pendingKeys.push(evt.timeStamp);
		} else if (state === "recording") {
			pendingKeys.push(evt.timeStamp);
		}
	}

	function scrollPos() {
		var el = document.scrollingElement || document.documentElement;
		return { y: window.scrollY, top: el ? el.scrollTop : 0 };
	}

	// Bubble phase: runs after the game's capture-phase listener has had its say.
	function onKeyWatch(evt) {
		if (evt.repeat || WATCHED_KEYS.indexOf(evt.key) === -1) { return; }
		if (keyRows.length >= MAX_KEY_ROWS) { droppedKeyRows++; return; }
		var before = scrollPos();
		var row = {
			t_s: round2(performance.now() / 1000),
			key: evt.key === " " ? "Space" : evt.key,
			repeat: evt.repeat,
			modifiers: evt.ctrlKey || evt.metaKey || evt.altKey,
			defaultPrevented: evt.defaultPrevented,
			zts_capture: !!(window.__zts && window.__zts.capture),
			scroll_before: before.y + "/" + before.top,
			scroll_after: "",
			scrolled: false,
			focus_after: ""
		};
		keyRows.push(row);
		setTimeout(function () {
			var after = scrollPos();
			row.scroll_after = after.y + "/" + after.top;
			row.scrolled = after.y !== before.y || after.top !== before.top;
			var a = document.activeElement;
			row.focus_after = a ? a.tagName.toLowerCase() + (a.id ? "#" + a.id : "") : "none";
		}, 50);
	}

	function canvasInfo() {
		var c = document.querySelector("canvas");
		if (!c) { return null; }
		return { width: c.width, height: c.height, css_width: c.clientWidth, css_height: c.clientHeight };
	}

	window.addEventListener("keydown", onKeyLatency, { capture: true, passive: true });
	window.addEventListener("keydown", onKeyWatch, { capture: false, passive: true });
	document.addEventListener("visibilitychange", updateFocus);
	window.addEventListener("blur", updateFocus);
	window.addEventListener("focus", updateFocus);

	window.zts_probe = {
		arm: function (opts) {
			if (state === "recording") { console.log("[zts_probe] already recording; stop() first"); return; }
			mode = opts && opts.startNow ? "load window" : "running";
			var seconds = opts && typeof opts.seconds === "number" && isFinite(opts.seconds) && opts.seconds > 0 && opts.seconds <= 3600 ? opts.seconds : ZTS_PROBE_SECONDS;
			if (seconds !== probeSeconds) {
				// Allocate first, commit after: a failed allocation leaves the old, consistent state.
				var frames = bufferFrames(seconds);
				var newTimes = new Float64Array(frames);
				var newFocus = new Uint8Array(frames);
				probeSeconds = seconds;
				MAX_FRAMES = frames;
				frameTimes = newTimes;
				frameFocus = newFocus;
			}
			lastRun = null;
			lastSummary = null;
			keyRows = [];
			droppedKeyRows = 0;
			if (mode === "load window") {
				startRecording();
				console.log("[zts_probe] recording the load window now for " + probeSeconds + " s");
			} else {
				state = "armed";
				console.log("[zts_probe] armed for " + probeSeconds + " s: click the game, then type the first letter. Don't touch DevTools until the report card.");
			}
		},
		stop: function () {
			if (state === "armed") { state = "idle"; console.log("[zts_probe] disarmed"); return; }
			finish();
		},
		summary: function () {
			if (lastSummary) { printSummary(lastSummary); } else { console.log("[zts_probe] no summary yet"); }
		},
		keys: function () {
			if (keyRows.length === 0) { console.log("[zts_probe] no watched keys pressed yet"); return; }
			console.table(keyRows);
		},
		result: function () {
			return {
				probe: "zts_probe 5.3",
				user_agent: navigator.userAgent,
				device_pixel_ratio: window.devicePixelRatio,
				screen: { width: screen.width, height: screen.height },
				inner: { width: window.innerWidth, height: window.innerHeight },
				canvas: canvasInfo(),
				state: state,
				dropped_key_rows: droppedKeyRows,
				run: lastRun,
				keys: keyRows
			};
		},
		selftest: function () {
			var input = [];
			for (var i = 0; i < 58; i++) { input.push(16.7); }
			input.push(40);
			input.push(16.7);
			var s = summarize(input, null);
			var lat = latencySummary([5, 10, 16, 20], 16.7);
			var checks = [
				["frames", s.frames, 60],
				["max_ms", s.max_ms, 40],
				["over_33ms", s.over_33ms, 1],
				["over_17_5ms", s.over_17_5ms, 1],
				["p50_ms", s.p50_ms, 16.7],
				["p99_ms", s.p99_ms, 40],
				["mean_ms", s.mean_ms, 17.09],
				["fps", s.fps, 58.52],
				["refresh_ms", s.refresh_ms, 16.7],
				["nfr1_pass", s.nfr1_pass, false],
				["latency max_ms", lat.max_ms, 20],
				["latency p50_ms", lat.p50_ms, 10],
				["nfr2_pass", lat.nfr2_pass, false]
			];
			var ok = true;
			for (var j = 0; j < checks.length; j++) {
				var pass = checks[j][1] === checks[j][2];
				ok = ok && pass;
				console.log("[zts_probe] selftest " + (pass ? "PASS" : "FAIL") + " " + checks[j][0]
					+ " = " + checks[j][1] + " (expected " + checks[j][2] + ")");
			}
			console.log("[zts_probe] selftest " + (ok ? "PASS" : "FAIL"));
			return ok;
		},
		_teardown: function () {
			cancelAnimationFrame(rafId);
			clearInterval(focusTimer);
			window.removeEventListener("keydown", onKeyLatency, { capture: true });
			window.removeEventListener("keydown", onKeyWatch, { capture: false });
			document.removeEventListener("visibilitychange", updateFocus);
			window.removeEventListener("blur", updateFocus);
			window.removeEventListener("focus", updateFocus);
		}
	};
	console.log("[zts_probe] ready. zts_probe.arm() on the 'Type the letter to start!' screen.");
})();
