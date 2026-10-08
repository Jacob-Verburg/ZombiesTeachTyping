# Frame probe (Story 5.3)

`frame_probe.js` measures frame times, key-to-frame latency and which browser keys the game blocks. You paste it into the browser console on the release build (the Pages link). It only watches: it never blocks keys, never saves anything and never sends anything. It is not part of the game and never ships.

## Paste it

1. Open the game link. Press **F12** to open DevTools and pick the **Console** tab.
2. Paste the probe:
   - **Chrome / Edge:** the first paste asks you to type `allow pasting` and press Enter. Then paste again and press Enter.
   - **Firefox:** type `allow pasting` and press Enter first, then paste and press Enter.
3. The console prints `[zts_probe] ready.`
4. Optional: `zts_probe.selftest()` should end with `selftest PASS`. It only checks the summary maths against fixed numbers, not the live capture.

## Measure a run (M1 frame rate, M2 latency)

1. Close any Network or Performance tab in DevTools; keep only the Console open.
2. In the game: title, then menu, then Zombie Run.
3. On the **"Type the letter to start!"** screen, type `zts_probe.arm()` in the Console and press Enter.
4. **Click the game** so it has focus. Type the first letter. Recording starts with it and runs 120 s.
5. Play the full 2:00 with real typing. Hug villagers so the conga line goes past 12 (the "×N" badge shows).
   **Horde Rush** (a 3:00 run, Story 6.7): use `zts_probe.arm({seconds: 180})` instead, and play the full 3:00.
6. **Don't click DevTools until the report card.** Clicking it pauses the run. The probe leaves out unfocused frames, but don't rely on that.
7. When the report card shows, the Console prints a summary. Copy everything:
   - Chrome / Edge: `copy(JSON.stringify(zts_probe.result()))`, then paste it into chat.
   - Firefox: `copy(JSON.stringify(zts_probe.result()))` works too. If it doesn't, run `JSON.stringify(zts_probe.result())` and copy the output by hand.

### Read the summary

| Line | Pass looks like |
| --- | --- |
| `> 33 ms:` | `0` (counted above 33.4 ms, see Thresholds) |
| `FPS` | 59 or more on a 60 Hz screen |
| `> 17.5 ms:` | Missed vsyncs. Not pass/fail; a few are normal. |
| `latency ... max` | 17.2 ms or less (one 60 Hz refresh plus 0.5 ms) |
| `frames while unfocused` | Missing, or 0. Otherwise DevTools got clicked. |

On a 120 or 144 Hz screen the refresh is 8.3 or 6.9 ms. NFR1 is still judged on `> 33 ms` and an FPS floor, and the latency limit stays 17.2 ms.

A `WARNING` line (focused gap over 1 s, frame buffer full, dropped samples) means the numbers may be incomplete; read it before trusting PASS.

### Thresholds (deliberately a little looser than the spec)

- **NFR1 FPS:** 59 or more, not 60, so 59.94 Hz panels pass.
- **NFR1 `> 33 ms`:** a frame counts only above 33.4 ms, because vsync-rounded timestamps make one dropped 60 Hz frame read 33.33 ms. A single dropped frame therefore does not fail NFR1; read `> 17.5 ms` and `max` as well.
- **NFR2 latency:** 17.2 ms or less (16.7 ms refresh plus 0.5 ms), a fixed limit. It is keydown to the next frame's start, not to the pixels on screen, so treat PASS as a lower bound on the real latency.
- **Load window runs** print "n/a (load window)" instead of PASS or FAIL.

### Load window (optional)

To catch the freeze before the first key (the music loading), type `zts_probe.arm({startNow: true})` on the title screen. Then click the game, go menu, then Zombie Run, and wait on "Type the letter to start!". `zts_probe.stop()` prints the summary, labelled "load window". It is a separate number, never the M1 row.

## Keys (M5)

The probe always records Space, `'`, `/`, Backspace, Tab and Escape presses. After pressing them during a run, while paused and in the menu, type `zts_probe.keys()` for the table:

- `defaultPrevented: true` means the game blocked the key's browser action.
- `zts_capture` is the game's "block keys now" flag: on during the run and pause, off in the menu.
- `defaultPrevented` is the reliable signal. `scrolled: true` means the page moved (a fail during a run), but `false` is not proof: smooth scrolling can finish after the 50 ms check, and a page with no overflow cannot scroll at all.
- `focus_after` should stay on `canvas` during a run.

## Browser tools

**Chrome / Edge**

- Throttle to 25 Mbit/s: Network tab, throttling dropdown (it says "No throttling"), then **Add…** a custom profile "25 Mbit/s": download `25000` kbit/s, upload `5000` kbit/s, latency `20` ms. Choose it.
- First load: tick **Disable cache** and reload. Read "transferred" at the bottom of the Network tab, and time the wait until the title screen shows.
- Cached load: untick Disable cache, keep throttling on and reload. The Size column shows "(disk cache)" or a 304.
- Evidence recording: Performance tab, tick **Screenshots**, record about 20 s mid-run, then stop. Screenshot the Frames track (long frames show red or yellow).

**Firefox**

- Throttling has presets only. Pick **Wi-Fi** (30 Mbit/s, the closest) and note it. Disable cache is in the Network tab's gear menu.
- Evidence recording: Performance tab (Firefox Profiler), preset **Graphics**, about 20 s mid-run.

Firefox with `privacy.resistFingerprinting` on rounds timestamps, which makes the frame and latency numbers meaningless; leave it off for a run.

Always measure in a visible, focused tab. A background tab slows frames to 1–2 per second, and the numbers mean nothing.
