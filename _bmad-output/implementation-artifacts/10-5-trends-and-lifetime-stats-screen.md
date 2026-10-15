---
baseline_commit: e3b4481cb77520703397ff4b5424c58d34d55500
---

# Story 10.5: Trends and Lifetime Stats Screen

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a parent,
I want a simple screen showing how my kid's typing is improving,
so that I can see the practice is working.

## Acceptance Criteria

1. **A Progress screen, one step from the main menu (FR77, FR24, FR25).** A new `Router.Screen.TRENDS` (appended **after** `KEYBOARD_TEST` so no existing enum value moves) maps to `res://scenes/screens/trends.tscn` (script `scripts/screens/trends.gd`). The main menu gets a `%TrendsButton` (a `PixelButton`, label "Progress" `[ASSUMPTION — copy, Gate 1]`) in the free top-right corner (`offset_left 480, top 16, right 624, bottom 48`; the logo's drawn pixels end at x 461, so nothing overlaps). Enter or a click on it goes to `TRENDS` through the menu's existing `_leave()` (one navigation, UI click). On the Progress screen, Esc, or Enter/click on its one `%MenuButton` ("Menu", with an "Esc" keycap beside it like the report card), goes back to `MAIN_MENU` exactly once. The payload is consumed and ignored. The menu loop keeps playing (`play_music(&"mus_menu")`, a no-op when it is already playing).
2. **Charts over recent runs (FR77).** With at least one recorded run, the screen shows three simple bar charts, each with a title: **"Words per minute"** (WPM of the newest `RECENT_RUNS = 20` recorded runs, oldest left, newest right), **"Accuracy"** (accuracy % of the same runs, fixed 0–100 scale) and **"Practice time"** (practice seconds per local calendar day, the newest `PRACTICE_DAYS = 7` days **that have practice**, oldest left; days with no runs are skipped, never shown as empty bars — no streak or guilt pressure, NFR11). Every recorded run of every level counts together (the rolling-average model already mixes levels, FR60). Bars are chalk on a chalkboard panel, built from palette `ColorRect`s (no `draw_*` calls, no `StyleBoxFlat`), whole pixels, bottom-aligned. A non-zero value always shows at least a 2 px bar; WPM and practice scale to the shown maximum (a floor of `WPM_SCALE_FLOOR = 10` WPM and `PRACTICE_SCALE_FLOOR_S = 600` s so a first slow run is not a full-height bar).
3. **Lifetime totals (FR77).** A chalkboard shows four totals, label over value: **"Keys Typed"**, **"Best WPM"**, **"Brains Earned"**, **"Time Practiced"**. Keys Typed and Time Practiced come from the new running totals (AC 5), Brains Earned from the new running brains total, Best WPM is the highest saved per-level best (`best_wpm`, which is already permanent and outlives the 500-run cap). Time is shown as `"N min"` under an hour and `"N hr N min"` from an hour (`"0 min"` for nothing) `[ASSUMPTION — copy, Gate 1]`; the other totals are plain whole numbers. Totals show in the empty state too.
4. **Plain words, no ranks, never the tier (NFR9, NFR10, FR60).** Every new string is added on purpose to `tests/unit/test_plain_words.gd` (`APPROVED_COPY` / `APPROVED_PATTERNS`) and passes its slang, technical, ranks and all-caps rules; EXPERIENCE.md Voice and Tone gets the new rows. Nothing on the screen reads or shows `tier`, `placement_done`, `letter_pool_or_tier`, `per_key`, the rolling average, a level difficulty, a grade, a goal line or a comparison to other kids. No timers on the screen (NFR11).
5. **Lifetime totals survive the 500-run cap (schema v5).** Each profile gets `"lifetime": {"runs": 0, "keys_typed": 0, "seconds": 0, "brains": 0}` (`SaveSchema.profile_defaults()`, `GameConstants.CURRENT_SCHEMA = 5`). `PlayerData.record_run()` adds the run (`runs + 1`, `keys_typed`, `seconds += the record's whole duration_s`, `brains += result.total_brains()`) inline, in the same single save request. `PlayerData.add_brains()` adds its amount to `lifetime.brains` (quit-run brains, the welcome gift, debug cheats). Spending (`buy_item`) never lowers it. A run that falls off the 500 cap leaves the totals unchanged.
6. **Migration v4 → v5 with fixture tests.** `SaveSchema.migrate_4_to_5` (registered at `migration_steps()` index 3) gives every Dictionary profile a `lifetime` Dictionary, **backfilled from what the save already knows**: `runs` = the number of Dictionary records in `run_history`; `keys_typed` / `seconds` = the sums of the records' `keys_typed` / `duration_s`; `brains` = `max(sum of the records' brains, the profile's current brains)` (the wallet can hold quit-run and gift brains that history never saw; a total below the wallet would look wrong to a parent). Only non-negative `int` values are summed; anything else counts 0. A profile that already has a Dictionary `lifetime` keeps it; a non-Dictionary is rebuilt. Junk (profiles not a Dictionary, a profile not a Dictionary) is skipped with the same warning shape as `migrate_3_to_4`. Fixtures: new `save_v5_fresh.json` (equals `SaveSchema.defaults()`), new `save_v4_history.json` (a v4 save with a few run records, one junk record, a wallet larger than the history's brains) → its exact backfilled totals; the v1–v4 fixtures stay byte-identical as migration inputs.
7. **Friendly empty state.** With no recorded run (empty `run_history`), the chart area shows one parchment sign instead of empty charts: "Finish a game to see your charts!" `[ASSUMPTION — copy, Gate 1]`. The totals still show (all `0`/`0 min`, or the brains a kid earned from quit runs). Junk records (non-Dictionary) are ignored; a history of only junk is the empty state.
8. **Robust and live (NFR16, Boundary 4).** The screen reads only through `PlayerData` getters (no save dictionary, no `SaveService`), writes nothing, and re-reads everything on `PlayerData.profile_replaced` (F8 reset while open) and `run_recorded` (never fired here in practice; harmless). A junk value anywhere (a negative, a float, a string, a missing key) reads as 0 and never logs an error to the kid's screen or stops the screen.
9. **Layout and readability (NFR7, DESIGN.md).** All text ≥ 16 px (theme default, Press Start 2P: **16 px per character** at 16 px), every focusable control ≥ 32 px tall, every control inside the 16 px margin, nothing overlaps, no text clipped (each label's minimum size fits its rect). Only `%MenuButton` is focusable on the Progress screen and it starts focused. The new scene and screen are walked by `test_no_placeholder_chrome.gd`, `test_plain_words.gd`, `test_readability.gd` and `test_screen_flow.gd` (it gets a temp-dir `PlayerData` like MAIN_MENU, so the real save is never touched).
10. **Main menu focus and existing behaviour preserved.** `%TrendsButton` joins focus wiring as its own top row: Up from any card → `%TrendsButton`; Down from `%TrendsButton` → the first choosable card (or `%ClosetButton` when none); Left/Right on it stay put; Tab order: cards → bottom row → `%TrendsButton` → wraps. Initial focus, the unlock moment (input finishes it; focus still goes to the new card), the storage notice, Ctrl+Shift+E, Esc-does-nothing and every existing `test_main_menu.gd` / `test_level_unlocks.gd` / `test_main_menu_fullscreen.gd` case still pass (update only the neighbour/Tab expectations that this AC changes).
11. **Approval gates.** Gate 1: a layout sketch of the Progress screen (both states) and the menu's new button, with the copy list, approved by Smuck **before** wiring visuals. Gate 2: in-game screenshots (filled state with ≥ 8 runs over ≥ 3 days, empty state, menu with the button focused, grayscale of the filled state) approved by Smuck. Each answer verbatim with the date in `### Review Findings

- [x] [Review][Decision] (resolved 1a: keep as is, dismissed) Debug/test brain grants and the welcome gift count as "Brains Earned" — `PlayerData.add_brains` now feeds `lifetime.brains` for every caller: CHEAT_BRAINS (`debug_overlay.gd:182`), `hat_fit_check.gd:236`, `keyboard_test.gd:116`, the welcome gift (`welcome_gift.gd:87`) and quit-run brains (`run_frame.gd:470`). Options: (a) keep as is, since quit-run brains were really earned and cheats are dev-only; (b) count only run and quit brains, via a separate path for the gift and debug grants.
- [x] [Review][Decision] (resolved 2a: keep floor-to-minutes, dismissed) "Time Practiced" reads "0 min" for a lifetime under 60 s — a kid's first 45 s game looks unrecorded [scripts/core/trends_calculator.gd:623]. Options: (a) keep floor-to-minutes; (b) show "<1 min" (needs plain-words approval); (c) show seconds under a minute.
- [x] [Review][Defer] `_whole` helper is duplicated in save_schema, trends_calculator and player_data [scripts/] — deferred, pre-existing pattern.

## Art Approval`. No new sound (UI click only): no Audio gate.
12. **No regressions.** Full GUT suite green, count only goes up; zero `Parse Error|Compile Error|Failed to load script`; `SCRIPT ERROR` / `WARNING` counts unchanged except deliberate, asserted ones. All existing PNG/WAV byte-identical. The real `user://save.json` sha256 identical before and after every suite run and manual check.

## Tasks / Subtasks

- [x] **Task 1: Baseline** (AC: 12)
  - [x] 1.1 `godot --headless --path . --import`, then the full suite: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` (log to a scratch file). Record tests/passing, `SCRIPT ERROR` count, `WARNING` count, and zero `Parse Error|Compile Error|Failed to load script`. Expected from 10.4: 2165 tests, 3 / 174 (re-measure; 10.4's review added tests).
  - [x] 1.2 Record the real save's sha256 (`%APPDATA%/Godot/app_userdata/<project name>/save.json`; find the folder via `OS.get_user_data_dir()` once if unsure).

- [x] **Task 2: Save schema v5** (AC: 5, 6) — pure, do first.
  - [x] 2.1 `scripts/core/save_schema.gd`: `"lifetime": {"runs": 0, "keys_typed": 0, "seconds": 0, "brains": 0}` in `profile_defaults()`; `migrate_4_to_5` (shape of `migrate_3_to_4` + the backfill of AC 6; warnings `"migrate_4_to_5: profiles is not a dictionary, skipping"` / `"migrate_4_to_5: profiles/%s is not a dictionary, skipping"`); register at index 3; class doc gains `## v5 (Story 10.5) adds profiles.<id>.lifetime ...`. A private static helper `_whole(value: Variant) -> int` (non-negative `int` → itself, anything else → 0) keeps the sums junk-proof. Migrations run after `normalize_numbers`, so JSON floats like `51.0` are already ints.
  - [x] 2.2 `scripts/core/game_constants.gd`: `CURRENT_SCHEMA = 5`. `tests/unit/test_smoke.gd:12`: expect 5, message `"Story 10.5: schema v5 (lifetime)"`.
  - [x] 2.3 New `tests/fixtures/saves/save_v5_fresh.json` from `JSON.stringify(SaveSchema.defaults(), "\t")` — match how `save_v4_fresh.json` is laid out (sorted keys, tabs, LF, same trailing newline). New `tests/fixtures/saves/save_v4_history.json`: schema 4, `brains` e.g. 500, three Dictionary records (keys 51/60/40, duration_s 60/120/120, brains 12/20/15) plus one junk entry (`"oops"`), so the expected backfill is `runs 3, keys_typed 151, seconds 300, brains 500`; then a second profile `p2` with the wallet below its history's brains to prove the `max`. Keep v1–v4 fixtures byte-identical.
  - [x] 2.4 `tests/unit/test_save_schema.gd`: `FRESH_PATH` → v5, add `V4_FRESH_PATH` and `V4_HISTORY_PATH`; rename `test_defaults_match_v4_fixture` → `_v5_`; `test_prepare_round_trips_full_fixture` expects `schema_version` 5 and the full fixture's backfilled `lifetime` (compute it from `save_v1_full.json`: 2 records; brains = max(their sum, 340)); `test_prepare_v1_reaches_v4` → `_v5`; new `test_migration_steps_register_4_to_5`, `test_migrate_4_to_5_adds_lifetime` (v4 fresh → prepare == defaults), `test_migrate_4_to_5_backfills_from_history` (the new fixture's exact totals, both profiles), `test_migrate_4_to_5_keeps_existing_dict`, `test_migrate_4_to_5_replaces_a_non_dict`, `test_migrate_4_to_5_ignores_junk_values` (negative, float that is not whole, string, missing fields → 0), `test_migrate_4_to_5_survives_junk` (with `assert_push_warning`). Check every other test that pins `schema_version` 4 or a migration count (`grep -rn "schema_version\|CURRENT_SCHEMA\|migration_steps" tests`) — `test_level_unlocks.gd`, `test_save_service.gd`, `test_player_data.gd`, `test_crypt_closet.gd` (the `save_v3_mvp_owned.json` path).

- [x] **Task 3: PlayerData lifetime + reads** (AC: 3, 5, 8)
  - [x] 3.1 `record_run`: after the history append, add to `_lifetime()` (a helper that, like `_level_unlocks()`, replaces a non-Dictionary with defaults first, and treats each junk field as 0): `runs += 1`, `keys_typed += result.keys_typed` (≥ 0), `seconds += record["duration_s"]` (the int `to_record()` already floors), `brains += result.total_brains()` (≥ 0). Inline: still exactly **one** `request_save()`. No new signal (`run_recorded` already fires).
  - [x] 3.2 `add_brains`: `lifetime.brains += amount` inside the same mutation (still one save request, `brains_changed` unchanged). `buy_item` untouched.
  - [x] 3.3 New getters (doc comment each; extend the class doc with a `## Lifetime (Story 10.5, FR77): ...` paragraph): `get_lifetime() -> Dictionary` (a fresh `{"runs", "keys_typed", "seconds", "brains"}` of non-negative ints, junk → 0); `get_best_wpm_overall() -> int` (max over `best_wpm` values that are non-negative ints / whole floats; 0 when none); `get_run_history() -> Array[Dictionary]` (deep copies of the Dictionary records, oldest first, junk skipped — the screen must never be able to mutate the save).
  - [x] 3.4 `reset_all()` needs nothing (defaults include `lifetime`); `debug_set_all_unlocked` untouched.
  - [x] 3.5 `tests/unit/test_player_data.gd`: record_run adds to every total and makes one save request; two runs accumulate; a run beyond the cap (fill history to `RUN_HISTORY_CAP`, record one more) keeps totals = sum of all recorded, not of the kept history; add_brains adds to `lifetime.brains`, buy_item does not lower it; quit-shaped brains (add_brains) count; `get_lifetime` on junk (`lifetime` = "x", a field = -5, 3.5, "7") → 0s, no crash; `get_best_wpm_overall` over several levels and junk; `get_run_history` returns copies (mutating the result leaves `save_service.get_active_profile()` unchanged) and skips junk; survives a reload through a temp `SaveService` (existing temp-dir helpers; never the real save).

- [x] **Task 4: Pure trends helper** (AC: 2, 3, 7)
  - [x] 4.1 New `scripts/core/trends_calculator.gd`, `class_name TrendsCalculator` (pure, static, no autoloads/nodes — Boundary 1), with typed static funcs:
    - `recent_runs(history: Array, count: int) -> Array[Dictionary]` — the newest `count` Dictionary records, oldest first.
    - `wpm_series(runs: Array[Dictionary]) -> Array[int]`, `accuracy_series(...) -> Array[int]` — junk → 0, accuracy clamped 0..100.
    - `daily_seconds(history: Array, day_count: int, bias_minutes: int) -> Array[int]` — sums `duration_s` per local day (`floori((timestamp + bias_minutes * 60) / 86400.0)`), returns the newest `day_count` days that have > 0 s, oldest first. Records with a junk/zero timestamp are skipped for this chart only.
    - `bar_heights(values: Array[int], max_px: int, scale_floor: int) -> Array[int]` — `scale = max(max(values), scale_floor)`; `h = roundi(v * max_px / scale)`; any `v > 0` gives at least `MIN_BAR_PX = 2`; 0 → 0; never above `max_px`.
    - `format_practice_time(seconds: int) -> String` — `< 3600`: `"%d min" % (seconds / 60)`; else `"%d hr %d min"`. Negative → `"0 min"`.
  - [x] 4.2 `tests/unit/test_trends_calculator.gd` (architecture rule: every `scripts/core/` class has a unit test): ordering and count, fewer runs than count, junk records, accuracy clamp, day grouping across midnight with a positive and a negative bias, skipped empty days, newest-7 cut, zero/negative/huge durations, bar floor/min/max, format boundaries (0, 59, 60, 3599, 3600, 3660, 36000+).

- [x] **Task 5: Gate 1 — layout sketch and copy** (AC: 11) — **stop for approval before Task 6/7 visuals.**
  - [x] 5.1 Put a sketch in `_bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/sketches/trends-10-5.md` (follow `hud-band-2-5.md` / `crypt-closet-4-4.md` style: ASCII at 640×360 with rects, tokens, copy list, focus map) for: the Progress screen filled, the empty state, and the main menu with `%TrendsButton`. Start from the proposed layout in Dev Notes.
  - [x] 5.2 Ask Smuck to approve layout + every new string (Dev Notes copy list). Record the verbatim answer with date under `## Art Approval`. Apply any copy change everywhere (scene, script consts, `test_plain_words.gd`, EXPERIENCE.md).

- [x] **Task 6: Chart widget** (AC: 2, 9)
  - [x] 6.1 New `scenes/ui/trend_chart.tscn` + `scripts/ui/trend_chart.gd` (`class_name TrendChart extends Control`): a `Chalkboard`-variation `Panel` background, a `%Title` Label (16 px, chalk-dim `#A8C4A6`), a `%Bars` Control area. `set_title(text)`, `show_values(values: Array[int], scale_floor: int)` builds one `ColorRect` per value (chalk `#F4F1E4`, width `BAR_W = 12`, gap `BAR_GAP = 4`, bottom-aligned, `mouse_filter = IGNORE`), freeing old bars first; `get_bar_heights() -> Array[int]` for tests. Uses `TrendsCalculator.bar_heights`. Never focusable. **No `draw_rect`/`draw_*` anywhere in `scripts/ui/`** (`test_no_placeholder_chrome.gd::test_no_code_drawn_shapes_in_ui_scripts` greps it); no `StyleBoxFlat`/`corner_radius` in the scene.
  - [x] 6.2 `tests/unit/test_trend_chart.gd`: N values → N bars with the computed heights, bottom-aligned inside `%Bars`, all inside the panel; a second call replaces (no leftover bars after `await` a frame / `queue_free`); empty list → no bars; 20 bars fit the width; bars and panel never take focus or the mouse.

- [x] **Task 7: Progress screen** (AC: 1–4, 7–9)
  - [x] 7.1 New `scenes/screens/trends.tscn` + `scripts/screens/trends.gd` (`extends Control`), per the approved sketch: night `Background` ColorRect (palette night, like the menu), `%Heading` Sign "Progress", `%Totals` chalkboard with four label/value pairs (`%KeysValue`, `%BestWpmValue`, `%BrainsValue`, `%TimeValue`), three `TrendChart` instances (`%WpmChart`, `%AccuracyChart`, `%PracticeChart`), `%EmptySign` (Sign + wrapped Label), `%MenuButton` (PixelButton "Menu") with an "Esc" `Keycap` label beside it.
  - [x] 7.2 Seams (assigned before `add_child`, like `report_card.gd`/`main_menu.gd`): `navigate: Callable` (→ `Router.go`), `player_data` (→ `PlayerData`), `play_sfx` / `play_music` (→ `AudioManager`), `time_zone_bias: Callable` (→ a func returning `Time.get_time_zone_from_system().get("bias", 0)`; on web this may be 0 — UTC days are an acceptable fallback). `_ready`: `Router.take_payload()`, `play_music.call(&"mus_menu")`, connect `profile_replaced` and `run_recorded` (disconnect in `_exit_tree`, architecture Event rule), `_show()`, `%MenuButton.grab_focus()`.
  - [x] 7.3 `_show()`: totals from `get_lifetime()` + `get_best_wpm_overall()`; `history := player_data.get_run_history()`; empty → hide the three charts, show `%EmptySign`; else hide it, `recent_runs(history, RECENT_RUNS)` → WPM (`WPM_SCALE_FLOOR`) and accuracy (floor 100, so 100 % is full height) charts, `daily_seconds(history, PRACTICE_DAYS, bias)` → practice chart (`PRACTICE_SCALE_FLOOR_S`). Consts at the top with "Look value, not a GDD number" comments.
  - [x] 7.4 Input: `_unhandled_input` Esc (`ui_cancel`) → `_leave()`; `%MenuButton.pressed` → `_leave()`. `_leave()` is the only navigation, at most once (`_leaving` guard, `Router.is_transitioning` seam like the menu), plays `sfx_ui_click`, then `navigate.call(Router.Screen.MAIN_MENU, {})`. No input guard is needed (not a mash-through screen).
  - [x] 7.5 `scripts/autoloads/router.gd`: append `TRENDS` to `enum Screen` (after `KEYBOARD_TEST`) and `Screen.TRENDS: "res://scenes/screens/trends.tscn"` to `SCREEN_PATHS`. Nothing else in the Router changes.
  - [x] 7.6 `tests/unit/test_trends.gd` (temp-dir `SaveService` + `PlayerData`, recorder seams; never the autoload's save): empty save → empty sign visible, charts hidden, totals `0`/`0`/`0`/`0 min`; one run → charts visible with 1 bar each and the right heights; 25 runs → 20 WPM bars, newest last; runs over 9 days → 7 practice bars oldest-first, empty days skipped; bias seam moves a run across midnight; totals match `get_lifetime()` (and survive a capped history); Best WPM = max level best; Esc → one `[MAIN_MENU, {}]` navigation + one click, a second Esc/click nothing; MenuButton starts focused and is the only focusable control; payload consumed; `profile_replaced` after a reset re-reads to the empty state; nothing writes the save (save request count unchanged / file untouched); no string contains "tier" or a pool label.
  - [x] 7.7 Layout tests (in `test_trends.gd`, mirroring `test_main_menu.gd::test_every_control_is_inside_the_margin`, `test_text_fits_and_is_at_least_16px`): inside the 16 px margin, ≥ 16 px text, labels' minimum size fits (longest values: `"999999"`, `"99 hr 59 min"`), no overlaps between the totals board, the charts, the empty sign and the button row, button ≥ 32 px tall.

- [x] **Task 8: Main menu button + focus** (AC: 1, 10)
  - [x] 8.1 `scenes/screens/main_menu.tscn`: add `%TrendsButton` (`Button`, `theme_type_variation = &"PixelButton"`, `pixel_button.gd` script, `text = "Progress"`, rect from AC 1). Update `load_steps` only if you add an ext_resource (the PixelButton script is already `5_pixel_button`).
  - [x] 8.2 `scripts/screens/main_menu.gd`: `%TrendsButton.pressed.connect(_on_trends_button_pressed)` → `_leave(Router.Screen.TRENDS, {})`. `_wire_focus()`: cards' `focus_neighbor_top` → `%TrendsButton`; `%TrendsButton` bottom → `_first_choosable_card()` (or `%ClosetButton` when null), left/right/top → itself; Tab order `cards + bottom + [%TrendsButton]`. Keep `_wire_row`'s semantics for the other two rows. Extend the class doc (`## Story 10.5: ...`).
  - [x] 8.3 Update `tests/unit/test_main_menu.gd`: `test_card_row_neighbours` (top now `%TrendsButton`), `test_tab_order_walks_cards_then_bottom_row` (Trends last, wraps to first card), new `test_trends_button_opens_progress` (one `[TRENDS, {}]` nav), `test_trends_button_neighbours`, and make sure `test_every_control_is_inside_the_margin` / `test_text_fits_and_is_at_least_16px` / `test_notice_overlaps_no_control` / `test_hat_and_pet_overlap_nothing` cover the new button. Run `test_level_unlocks.gd` (focus after a moment) unchanged.

- [x] **Task 9: Cross-screen tests and copy contract** (AC: 4, 9, 12)
  - [x] 9.1 `tests/integration/test_screen_flow.gd`: in `_instance`, give `TRENDS` a temp `PlayerData` (and a `navigate` recorder); add `"TRENDS": ["%MenuButton"]` and `"MAIN_MENU": ["%ClosetButton", "%TrendsButton"]` to `FLOW_BUTTONS`; a `test_trends_consumes_the_payload`. Extend its class doc line.
  - [x] 9.2 `tests/unit/test_plain_words.gd`: approve "Progress", "Words per minute", "Practice time", "Best WPM", "Brains Earned", "Time Practiced", "Finish a game to see your charts!" (Keys Typed, Accuracy, Menu, Esc already approved); patterns `"^\\d+ min$"`, `"^\\d+ hr \\d+ min$"`; add the trends screen's script copy to the collected strings the way the report card's is. `scenes/screens/` is already walked. Note the RANKS regex (`\\blevel \\d`, `\\btier`, `easy`, `hard`, `grade`, `rank`…) — do not use those words.
  - [x] 9.3 `tests/unit/test_readability.gd`: add the Progress screen (filled with a temp `PlayerData` holding several runs, so charts and totals show) to the walked screens.
  - [x] 9.4 `tests/unit/test_no_placeholder_chrome.gd`: nothing to change (it walks `scenes/ui/` and `scenes/screens/`, and greps `scripts/ui/` for draw calls) — confirm both new files are walked (`test_the_walk_finds_the_ui`).
  - [x] 9.5 `_bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/EXPERIENCE.md`: add a Progress row to Information Architecture (from Main Menu → Main Menu), the copy to Voice and Tone, the two states to State Patterns (empty / filled). DESIGN.md: one Components bullet "Trend chart" (chalkboard panel, chalk bars, ColorRect, no outline).

- [x] **Task 10: Gate 2 — in-game check** (AC: 11, 12)
  - [x] 10.1 Captures without touching the real save: a scratch windowed runner (`tools/_scratch_10_5/`, deleted after) on a temp `user://capture_10_5/` `SaveService` seeded through `PlayerData.record_run` with ~12 code-built `RunResult`s spread over 4–5 days (timestamps set by `RunResult.create`), plus an empty one. Save to `_bmad-output/implementation-artifacts/screenshots/10-5/` (`progress-filled.png`, `progress-filled-gray.png`, `progress-empty.png`, `menu-progress-focused.png`). Show them to Smuck; record the verbatim answer with date.
  - [x] 10.2 Web smoke (optional but recommended, as in 10.1/10.4): web debug export served by the `web-debug` launch config in the browser pane (browser storage, never the real save): menu → Progress → Esc → menu; play one Zombie Run to 0:00 (or F6), menu → Progress shows one bar each and the totals; F8 reset while on Progress → empty state. Check the console for errors.

- [x] **Task 11: Wrap-up** (AC: 12)
  - [x] 11.1 Full suite: count up, all passing, `SCRIPT ERROR`/`WARNING` deltas explained (expected: + the asserted `migrate_4_to_5` junk warnings, and existing junk-save prepare tests that now run one more step — 10.1 saw exactly this: `migrate_3_to_4: profiles is not a dictionary` appeared twice), zero parse/compile/load errors. Real save sha256 unchanged.
  - [x] 11.2 Mutation pass (scratch, then restore; each must turn a test red): `migrate_4_to_5` not registered; backfill ignores the wallet (`max` dropped); `record_run` forgets `seconds`; `add_brains` forgets `lifetime.brains`; `buy_item` lowers `lifetime.brains`; `recent_runs` returns newest-first; `daily_seconds` ignores the bias; empty state shown when history has runs; `%TrendsButton` not wired up; `get_run_history` returns the live array.
  - [x] 11.3 Update `deferred-work.md` with anything consciously left (e.g. per-level filters, chart value labels, a full 5:00 web run). Story file: Debug Log, Completion Notes, File List, Change Log; status → review.

## Dev Notes

### What this story is (and isn't)

- **Is:** schema v5 running totals + backfill, three read-only `PlayerData` getters, a pure `TrendsCalculator`, a `TrendChart` widget, one new screen, one new Router screen id, one new main-menu button, copy/doc updates. Parent-facing but kid-visible, so every kid rule still applies (plain words, no ranks, no tier, no pressure).
- **Isn't:** per-key heatmaps (FR9 data stays hidden; the GDD says per-key data "feeds ... the trends screen", but FR77 and the AC list WPM/accuracy/practice time + four totals only — do not add per-key views), per-level filters, goals, streaks, badges, exports, a parent PIN, new art sprites, new sounds, any change to how runs are recorded beyond the lifetime sums.

### Design decisions made for this story (follow them; record any change and why)

1. **Lifetime brains = every brain ever gained** (`add_brains` + `record_run`), never reduced by spending. **Keys / time / runs = recorded (completed) runs only**, matching FR13 (quit runs are not stats history) and what `run_history` holds. A parent sees "Brains Earned" ≥ the wallet, always.
2. **Backfill brains = max(history sum, wallet).** Pre-v5 gift and quit brains cannot be recovered exactly; the max is the honest lower bound. Migrations are pure and never read the catalogue or registry (10.1 rule), so owned-item prices are **not** added back.
3. **Best WPM** comes from `best_wpm` (already permanent), not from a new field.
4. **Practice chart is per local day with practice**, not per run (per-run durations are almost constant 2:00/3:00 and say nothing). Days without practice are skipped (no empty "you missed a day" bars, NFR11). If Gate 1 prefers per-run, switch `daily_seconds` for a per-run series; keep the helper tested either way.
5. **All levels mixed** in the charts (same as the tier's rolling average). Debug-only `test_level` runs exist only in debug builds; no filter needed.
6. **Bars are `ColorRect`s, chalk on chalkboard.** No outline (chalk marks), no hue-only meaning (one colour for all bars), no numbers on bars (totals carry the numbers). No `draw_*`: `test_no_placeholder_chrome.gd` greps `scripts/ui/` for `draw_rect`, `draw_line`, etc.
7. **Router enum appended**, not inserted: values are ints (`test_debug_overlay.gd:549` and others pass them around); appending changes nothing existing.
8. **One screen id `TRENDS`, copy "Progress".** The id follows FR77's name; the kid-facing word is the Gate 1 call.

### Proposed layout (starting point for the Gate 1 sketch; 640×360, 4 px grid, 16 px margin; Press Start 2P = 16 px per glyph at 16 px, 24 px per glyph at 24 px)

```
┌──────────────────────────────────────────────────────────────── 640 ─┐
│                     ┌─ Sign: "Progress" (24px) ─┐                     │ y16-48, x220-420 (8 glyphs×24=192 +pad)
│ ┌─ Totals (Chalkboard) x16-272 ─┐ ┌─ WpmChart x288-624, y64-136 ─────┐│
│ │ Keys Typed            (dim)   │ │ Words per minute                  ││ title 20 px + bars 44 px
│ │              12345   (chalk)  │ │ ▂▃▃▅▄▆▅▇ ...  (20 × 16 px slots)  ││
│ │ Best WPM                      │ └───────────────────────────────────┘│
│ │                 14            │ ┌─ AccuracyChart y144-216 ──────────┐│
│ │ Brains Earned                 │ │ Accuracy                          ││
│ │                940            │ └───────────────────────────────────┘│
│ │ Time Practiced                │ ┌─ PracticeChart y224-296 ──────────┐│
│ │           1 hr 5 min          │ │ Practice time   (≤7 day bars,     ││
│ └───────────────────────────────┘ │                  40 px slots)     ││
│                                   └───────────────────────────────────┘│
│                                              [Esc] [  Menu  ]          │ y312-344 (keycap + PixelButton)
└───────────────────────────────────────────────────────────────────────┘
Empty state: the three charts hide; one parchment Sign at x288-624, y64-296 with the wrapped
line "Finish a game to see your charts!" (≤ 20 glyphs per line at 16 px inside 336 px).
Main menu: %TrendsButton "Progress" at x480-624, y16-48 (8 glyphs = 128 px + 16 px padding).
```

- Widths are tight: "Time Practiced" = 14 glyphs = 224 px inside a 256 px board (8 px padding each side → 240 px). "Words per minute" = 16 glyphs = 256 px inside 336 px. "99 hr 59 min" = 12 glyphs = 192 px. Do not shrink fonts (16 px floor); enlarge panels or change copy at the Gate.
- 20 WPM/accuracy bars × 16 px (12 bar + 4 gap) = 320 px inside 336 px. 7 practice bars use `PRACTICE_BAR_W = 32` + 8 gap (or a `bar_w` parameter on `show_values`).

### Copy list for Gate 1 (all `[ASSUMPTION]` until approved)

| Where | Copy |
|---|---|
| Menu button, screen heading | "Progress" |
| Chart titles | "Words per minute", "Accuracy", "Practice time" |
| Totals labels | "Keys Typed", "Best WPM", "Brains Earned", "Time Practiced" (title case, matching the report card's approved "Keys Typed") |
| Time values | "45 min", "1 hr 5 min", "0 min" |
| Empty state | "Finish a game to see your charts!" |
| Back | "Menu" + keycap "Esc" (already approved) |

### Existing code: current state, what changes, what must be preserved

- **`scripts/core/save_schema.gd`** (v4: `level_unlocks`, `used_passages`, `last_themes`). Add the v5 field, step and doc line. Preserve: migrations before fill, never assume types, `_merge` keeps unknown keys and repairs wrong types (a `lifetime` with a missing `"brains"` key is filled to 0 by `_merge` because the default is a Dictionary — good), the frozen-past rule.
- **`scripts/autoloads/player_data.gd`**: `record_run` builds the record, caps history with one slice, updates best, adds brains inline (not `add_brains`, to keep one save request), unlocks, tier, then one `request_save()`. Add the lifetime sums inline **before** the single `request_save()`; do **not** call `add_brains` from `record_run` (that would double-count lifetime brains and request two saves). `add_brains` keeps its contract (negative → error, zero → nothing). No getter caches anything (class doc: getters read through `SaveService.get_active_profile()` every call — keep that; Epic 11 swaps profiles).
- **`scripts/autoloads/router.gd`**: `enum Screen` + `SCREEN_PATHS` only. The fade, payload and fallback logic stay untouched.
- **`scripts/screens/main_menu.gd` / `.tscn`**: two-row focus wiring, unlock moment focus (`_initial_focus`, `_on_unlock_moment_finished`), `_leave()` once-guard with transition release, Fullscreen per-frame sync, storage notice, export chord. The button is one more `_leave` caller; the wiring gains a third row.
- **`tests/integration/test_screen_flow.gd::test_every_screen_instantiates`** loops over **every** `Router.Screen` value — the new screen is instanced automatically; without a temp `PlayerData` it would read (not write) the live autoload. Inject one anyway (10.1 real-save incident: a screen that writes, instanced on the live autoload, changed `save.json`).
- **`run_frame.gd`** (`_quit_to_menu` → `add_brains`, `_record_result` → `record_run`): **no change**; lifetime follows automatically.
- **Welcome gift** (`add_brains(economy.welcome_bonus)`): no change; counts toward Brains Earned.

### Known test fallout (so you are not surprised)

| Test | Why | Fix |
|---|---|---|
| `test_smoke.gd:12` | pins `CURRENT_SCHEMA == 4` | 5 (Task 2.2) |
| `test_save_schema.gd` (`FRESH_PATH`, `_v4_fixture`, `round_trips_full_fixture`, `prepare_v1_reaches_v4`, steps count) | new field + step | Task 2.4 |
| `test_save_service.gd` / `test_player_data.gd` / `test_level_unlocks.gd` / `test_crypt_closet.gd` | any literal `4` for schema or a fresh-defaults equality | use `GameConstants.CURRENT_SCHEMA` / defaults |
| `test_main_menu.gd` neighbours / Tab order | new top row | Task 8.3 |
| `test_screen_flow.gd`, `test_plain_words.gd`, `test_readability.gd` | new screen walked / new copy | Task 9 |
| Junk-save prepare tests | one more migration step → one more asserted warning | expected; assert it (10.1 precedent) |

### Testing notes

- Commands as in Task 1. Run `--import` after adding `class_name TrendsCalculator` / `TrendChart` (class cache: stale caches give "Could not find type" parse errors).
- GUT silently skips a script that fails to parse and still exits 0 — always grep the log for `Parse Error|Compile Error|Failed to load script`.
- Never the real save: temp-dir `SaveService` + injected `PlayerData` (`test_player_data.gd::_put_fixture`, `test_screen_flow.gd::_temp_player_data`). Check the real save's sha256 after every run.
- `assert_push_warning` / `assert_push_warning_count` / `assert_push_error_count` for deliberate logs. Sort `String`s, not `StringName`s. Type every variable, including `for` loop variables (`untyped_declaration = Error`, tests too).
- Build `RunResult`s with `RunResult.create(...)` (timestamps are a parameter — perfect for day-grouping tests); never hand-write records in PlayerData tests unless testing junk.
- Freed bars: `queue_free()` frees at frame end — `await get_tree().process_frame` before counting children, or remove them from the parent before freeing.
- Flaky `test_audio_manager` pool test: rerun once before investigating.

### Previous story intelligence

- **10.4 (done, latest):** final 2165 tests, `SCRIPT ERROR` 3, `WARNING` 174 at its wrap-up (review patches added a few tests since — re-measure). Two approval gates recorded verbatim with dates; review patched stale doc/test wording — update every doc comment you touch. Captures via a scratch windowed runner on a temp `user://` save dir, deleted after; web smoke via the `web-debug` launch config (browser storage). Synthetic key events in the browser pane drop capitals (not an issue here: arrows/Enter/Esc).
- **10.1 (schema v4):** the exact template for this migration (`migrate_3_to_4`, `save_v4_fresh.json` = `SaveSchema.defaults()`, renamed fixture tests, the "profiles not a dictionary" warning counted twice because an existing junk test runs one more step). **Real-save incident:** a screen instanced on the live `PlayerData` wrote `save.json` — inject temp `PlayerData` everywhere a screen can write (this one doesn't write, inject anyway).
- **4.2 / 6.8 (main menu):** focus wiring helpers `_wire_row` / `_wire_focus`, unlock moment rules, hover moves focus (PixelButton does it), `_leave()` once-guard released if the transition ends without freeing the menu.
- **2.9 / 5.0 (report card):** the chalkboard + keycap + PixelButton composition, `Chalkboard`/`Keycap`/`Sign` theme variations, the `navigate`/`play_sfx`/`play_music` seam pattern.
- **5.2 (plain words, readability):** new copy must be added to `test_plain_words.gd` on purpose and to EXPERIENCE.md Voice and Tone; readability walks every screen.
- **Traps:** files LF (`.gitattributes eol=lf`); hand-edited `.tscn`: `format=3`, correct `load_steps`, unique ids; Godot rewrites uids on import — commit what it writes.

### Git intelligence

- Recent: `e3b4481 Story 10.4: code review patches applied, done`, `0495db9 Story 10.4: ...`, `e5ec1d6 Story 10.3: ... done`, `1e45d78 Story 10.3 ...`, `bb5f9f8 Story 10.2 ...`. One commit per story with code, data, tests, screenshots, story file, `deferred-work.md` and `sprint-status.yaml` together.
- Expected shape: new `scripts/core/trends_calculator.gd`, `scripts/ui/trend_chart.gd`, `scripts/screens/trends.gd` (+ `.uid`s), `scenes/ui/trend_chart.tscn`, `scenes/screens/trends.tscn`, 2 fixtures, ~3 new + ~9 updated test files, `save_schema.gd`, `game_constants.gd`, `player_data.gd`, `router.gd`, `main_menu.gd`/`.tscn`, the sketch, EXPERIENCE/DESIGN rows, screenshots. Suggested message: `Story 10.5: trends and lifetime stats screen`.

### Latest tech notes (Godot 4.7.2, GUT 9.7.1)

- No new libraries. `Time.get_time_zone_from_system()` returns `{"bias": minutes, "name": ...}` (bias = local − UTC in minutes, e.g. −300 for US Eastern standard time); keep it behind a seam and default to 0 if the key is missing. Run timestamps are `Time.get_unix_time_from_system()` (UTC seconds, `run_frame.gd::_record_result`).
- `ColorRect` with `mouse_filter = MOUSE_FILTER_IGNORE` and `focus_mode = FOCUS_NONE` for bars; set `position`/`size` in whole pixels (`snap_2d_transforms_to_pixel` is on).
- Integer division warning: GDScript warns on `int / int` (`INTEGER_DIVISION`). Copy `StatsCalculator.format_time`: `floori(whole / 60.0)` and `whole % 60`; day keys as `floori(local_seconds / 86400.0)`.
- After adding a `class_name`, run `--import` to rebuild `.godot/global_script_class_cache.cfg`.

### Project Structure Notes

- `scripts/core/trends_calculator.gd` (pure helper → core, with its unit test; like `save_schema.gd`); `scripts/ui/trend_chart.gd` + `scenes/ui/trend_chart.tscn` (reusable widget, mirrored paths); `scripts/screens/trends.gd` + `scenes/screens/trends.tscn` (screen, mirrored); fixtures in `tests/fixtures/saves/`; sketch in `ux-designs/.../sketches/trends-10-5.md`; screenshots in `_bmad-output/implementation-artifacts/screenshots/10-5/`; scratch in `tools/_scratch_10_5/` (deleted). No variance from the architecture tree.

### Project Context Rules

- There is no `project-context.md`. Rules from the architecture and earlier stories:
  - Only `SaveService` touches files; only `PlayerData` mutates profile state (screens read via getters, navigate via `Router`). Boundary 4.
  - `scripts/core/` is pure (no autoloads, no scene tree); every class in it has `tests/unit/test_*.gd`.
  - Static typing everywhere; `untyped_declaration = Error`. Typed signals connected in code; disconnect autoload connections in `_exit_tree`.
  - No GDD gameplay number as a literal; UI look values are consts with a "Look value" comment.
  - Kid-facing text: words a 6-year-old can read, no slang, no technical text, no ranks/difficulty, never the tier (FR60, NFR9, NFR10). No timers outside runs (NFR11).
  - DESIGN.md: palette colours only, 16 px text floor, 1 px ink outlines on panels (theme boxes provide them), candy yellow = focus only, no `StyleBoxFlat`, no anti-aliased shapes.
  - Errors never reach the kid; junk save values read as safe defaults (NFR16).
  - Visible changes wait for Smuck's approval (Gate 1 before wiring visuals, Gate 2 in game), recorded verbatim with dates.
  - Debug code only in `scenes/debug/` / `scripts/debug/` (nothing needed here).

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 10.5: Trends and Lifetime Stats Screen]; FR77, FR60 (never show the tier), FR13 (quit runs not recorded), FR22/FR51 (history, 500 cap), FR24/FR25 (flow, navigation); NFR7, NFR9, NFR10, NFR11, NFR16
- [Source: _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd-epics-overview.md#Epic 10] ("trends screen showing WPM, accuracy and practice time over recent runs, plus lifetime totals")
- [Source: _bmad-output/game-architecture.md#Data Persistence] (schema versions, migrations with fixtures, defaults fill), [#Screen Flow], [#Architectural Boundaries], [#Consistency Rules], [#Event System]
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/DESIGN.md] (Colors, Typography, Components: chalkboard, sign, pixel button, key hint), [EXPERIENCE.md] (Voice and Tone, Component Patterns, Accessibility Floor)
- [Source: scripts/core/save_schema.gd], [scripts/autoloads/player_data.gd record_run/add_brains], [scripts/autoloads/router.gd], [scripts/screens/main_menu.gd + main_menu.tscn], [scripts/screens/report_card.gd + report_card.tscn], [scripts/typing/run_result.gd to_record], [scripts/run/run_frame.gd _quit_to_menu/_record_result]
- [Source: tests/unit/test_save_schema.gd], [tests/unit/test_smoke.gd], [tests/unit/test_player_data.gd], [tests/unit/test_main_menu.gd], [tests/integration/test_screen_flow.gd], [tests/unit/test_plain_words.gd], [tests/unit/test_readability.gd], [tests/unit/test_no_placeholder_chrome.gd], [tests/fixtures/saves/]
- [Source: _bmad-output/implementation-artifacts/10-1-random-theme-rotation.md] (schema v4 template, real-save incident), [10-4-cornfield-path-and-spooky-forest-bridge.md] (gates, captures, baseline counts), [deferred-work.md]

## Art Approval

<!-- Gate 1 (layout sketch + copy) and Gate 2 (in-game captures): Smuck's verbatim answers with dates. -->

- **Gate 1 (layout sketch `sketches/trends-10-5.md` + copy list), 2026-10-14:** "Approve as drawn". No copy changes.
- **Gate 2 (in-game captures `screenshots/10-5/progress-filled.png`, `progress-filled-gray.png`, `progress-empty.png`, `menu-progress-focused.png`), 2026-10-14:** "Approve". Shown with one change since the sketch: text and bars moved 2–8 px in from the chalkboard frames (bar area 316 × 32 px instead of 320 × 36).

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Debug Log References

- Baseline (Task 1): `Godot.exe --headless --path . --import`, then the full suite: **2166 / 2166**, `SCRIPT ERROR` 3, `WARNING` 175, zero `Parse Error|Compile Error|Failed to load script`. (`Godot_v4.7.2-stable_win64_console.exe` in `C:\Program Files\Godot\` can't find its main exe there; `Godot.exe` in the same folder is the 4.7.2 standard build and was used throughout.)
- Real save `%APPDATA%/Godot/app_userdata/ZombiesTeachTyping/save.json` sha256 `2859cbaa...647a`, unchanged after every suite run, the capture runs and the web smoke (browser storage only).
- First full run after the menu wiring: 78 failures from `cards + bottom + [trends]` (an untyped Array assigned to `Array[Control]`); fixed with `order.append(trends)`.
- `test_typing_input.gd::test_unhandled_input_forwards_key_events` went red only when it ran after `test_trends.gd`: calling `_unhandled_input()` by hand leaves GUT's viewport input marked handled. `test_trends.gd` now pushes a no-op `InputEventAction` in `after_each` (the existing `_reset_input_handled` pattern from `test_report_card.gd` / `test_pause_panel.gd`).
- Gate 2 first capture: chalk text and bars sat flush against the chalkboard frames. Insets added (totals text x + 16; chart title x + 12, y + 10; bar area x 10–326, y 30–62 = 316 × 32 px) before showing Smuck; the sketch updated to match.
- Web smoke (Task 10.2): web debug export (`--export-debug "Web"`), `web-debug` launch config in the browser pane. The browser's old v4 save migrated to v5 and the Progress screen showed the backfilled totals; menu → Progress (Up, Enter) → Esc → menu; F3 + F8 + F8 reset while on Progress → empty state live; one Zombie Run (3 keys, F6) → report card → Welcome Gift → Closet → menu → Progress: one bar per chart, Brains Earned 110 (10 + the 100 gift). No console errors. The pane's `type` action does not reach the run; single key presses do.

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created
- **Schema v5 (AC 5, 6):** `profiles.<id>.lifetime = {"runs", "keys_typed", "seconds", "brains"}` in `profile_defaults()`; `CURRENT_SCHEMA = 5`; `SaveSchema.migrate_4_to_5` (index 3) backfills from `run_history` (Dictionary records counted, non-negative ints summed through `_whole`, brains = max(history sum, wallet)); keeps an existing Dictionary, rebuilds a non-Dictionary, skips junk with the `migrate_3_to_4`-shaped warnings. Fixtures: `save_v5_fresh.json` (= `SaveSchema.defaults()`), `save_v4_history.json` (p1: 3 records + `"oops"`, wallet 500 → 3 / 151 / 300 / 500; p2: wallet 5 below its history's 55 → 2 / 75 / 300 / 55). v1–v4 fixtures untouched. The v1 full fixture now round-trips with `lifetime` 2 / 121 / 120 / 340.
- **PlayerData (AC 3, 5, 8):** `record_run` adds runs / keys / the record's floored `duration_s` / brains inline before `brains_changed` (one save request still); `add_brains` adds to lifetime brains in the same mutation; `buy_item` untouched. New getters `get_lifetime()` (fresh copy, junk → 0), `get_best_wpm_overall()` (max of `best_wpm`, whole floats count) and `get_run_history()` (deep copies, junk skipped). Class doc extended.
- **TrendsCalculator (AC 2, 3, 7):** pure static helper in `scripts/core/`: `recent_runs`, `wpm_series`, `accuracy_series` (clamped 0–100), `daily_seconds` (local days via the bias, newest N days that have practice, empty days skipped, zero/junk timestamps left out), `bar_heights` (scale = max(values, floor), min 2 px, never above max), `format_practice_time` ("N min" / "N hr N min").
- **TrendChart (AC 2, 9):** `scenes/ui/trend_chart.tscn` + `scripts/ui/trend_chart.gd`: Chalkboard panel, chalk-dim `%Title`, chalk `ColorRect` bars bottom-aligned in `%Bars`, freed and replaced on each `show_values`; never focusable or clickable; no draw calls, no `StyleBoxFlat`.
- **Progress screen (AC 1–4, 7–9):** `Router.Screen.TRENDS` appended after `KEYBOARD_TEST` → `scenes/screens/trends.tscn` / `scripts/screens/trends.gd`, laid out per the approved sketch: Sign heading "Progress", totals chalkboard, three charts (20 recent runs for WPM / accuracy, 7 practice days), parchment empty sign, `%MenuButton` + "Esc" keycap. Read-only through PlayerData getters; re-reads on `profile_replaced` and `run_recorded` (disconnected in `_exit_tree`); Esc / Menu → `MAIN_MENU` once with a UI click (released if a transition ends without freeing the screen); payload consumed; `mus_menu`. Seams: navigate, player_data, play_sfx, play_music, is_transitioning, time_zone_bias.
- **Main menu (AC 1, 10):** `%TrendsButton` (PixelButton "Progress", x 480–624, y 16–48) → `_leave(TRENDS, {})`. Its own top focus row: Up from any card → Progress; Down → first choosable card or Closet; Left/Right/Up stay; Tab cards → bottom row → Progress → wraps. Existing menu, unlock and fullscreen tests pass unchanged apart from the neighbour/Tab expectations this AC changes.
- **Copy and docs (AC 4, 9):** all new strings approved in `test_plain_words.gd` (+ patterns `^\d+ min$`, `^\d+ hr \d+ min$`; the filled Progress screen and its script titles are walked); EXPERIENCE.md IA / Voice and Tone / State Patterns rows; DESIGN.md "Trend chart" component; sketch `sketches/trends-10-5.md`. The screen is walked by `test_screen_flow.gd` (temp PlayerData + recorder), `test_readability.gd` (filled), `test_no_placeholder_chrome.gd` (both new scenes and the new UI script, no change needed) and `test_plain_words.gd`.
- **Gates (AC 11):** Gate 1 "Approve as drawn" and Gate 2 "Approve" (2026-10-14), recorded under Art Approval.
- **Tests (AC 12):** new `test_trends_calculator.gd` (17), `test_trend_chart.gd` (6), `test_trends.gd` (27); `test_save_schema.gd` (+7, 3 renamed/updated), `test_player_data.gd` (+11), `test_main_menu.gd` (+4, 2 updated), `test_screen_flow.gd` (+1), `test_router.gd` (enum order now ends with TRENDS), `test_smoke.gd`, `test_save_service.gd`, `test_plain_words.gd`, `test_readability.gd` updated. **Final: 2239 / 2239** (baseline 2166, +73), `SCRIPT ERROR` 3 (unchanged), `WARNING` 178 (+3: the two asserted `migrate_4_to_5` junk warnings in `test_migrate_4_to_5_survives_junk`, and one more `migrate_N_to_N: profiles is not a dictionary` from an existing junk-save prepare test that now runs one more step — the 10.1 precedent), zero `Parse Error|Compile Error|Failed to load script`. No existing PNG/WAV changed.
- **Mutation pass (Task 11.2):** a scratch harness applied each mutation, ran the full suite and restored the file; every one turned tests red: `migrate_4_to_5` not registered (21 failing); backfill ignores the wallet (4); `record_run` forgets `seconds` (8); `add_brains` forgets `lifetime.brains` (5); `buy_item` lowers `lifetime.brains` (1, `test_add_brains_counts_toward_lifetime_and_spending_never_lowers_it`); `recent_runs` newest-first (4); `daily_seconds` ignores the bias (3); empty state shown with runs (7); `%TrendsButton` not wired (1, `test_trends_button_opens_progress`); `get_run_history` returns the live records (1, `test_get_run_history_returns_copies_and_skips_junk`). Final rerun after restoring: 2239 / 2239.
- Deferred items (per-level filter, bar labels, web UTC days, backfill lower bound, logo rect overlap, short web smoke) added to `deferred-work.md`.


### File List

- `scripts/core/save_schema.gd` (modified)
- `scripts/core/game_constants.gd` (modified)
- `scripts/core/trends_calculator.gd` (new) + `.uid`
- `scripts/autoloads/player_data.gd` (modified)
- `scripts/autoloads/router.gd` (modified)
- `scripts/ui/trend_chart.gd` (new) + `.uid`
- `scripts/screens/trends.gd` (new) + `.uid`
- `scripts/screens/main_menu.gd` (modified)
- `scenes/ui/trend_chart.tscn` (new)
- `scenes/screens/trends.tscn` (new)
- `scenes/screens/main_menu.tscn` (modified)
- `tests/fixtures/saves/save_v5_fresh.json` (new)
- `tests/fixtures/saves/save_v4_history.json` (new)
- `tests/unit/test_trends_calculator.gd` (new) + `.uid`
- `tests/unit/test_trend_chart.gd` (new) + `.uid`
- `tests/unit/test_trends.gd` (new) + `.uid`
- `tests/unit/test_save_schema.gd` (modified)
- `tests/unit/test_save_service.gd` (modified)
- `tests/unit/test_smoke.gd` (modified)
- `tests/unit/test_player_data.gd` (modified)
- `tests/unit/test_main_menu.gd` (modified)
- `tests/unit/test_router.gd` (modified)
- `tests/unit/test_plain_words.gd` (modified)
- `tests/unit/test_readability.gd` (modified)
- `tests/integration/test_screen_flow.gd` (modified)
- `_bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/sketches/trends-10-5.md` (new)
- `_bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/EXPERIENCE.md` (modified)
- `_bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/DESIGN.md` (modified)
- `_bmad-output/implementation-artifacts/screenshots/10-5/progress-filled.png`, `progress-filled-gray.png`, `progress-empty.png`, `menu-progress-focused.png` (new)
- `_bmad-output/implementation-artifacts/deferred-work.md` (modified)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified)
- `_bmad-output/implementation-artifacts/10-5-trends-and-lifetime-stats-screen.md` (this file)

### Change Log

- 2026-10-14: Story 10.5 implemented: save schema v5 (lifetime totals + v4 backfill), PlayerData lifetime sums and read-only getters, TrendsCalculator, TrendChart widget, Progress screen (Router TRENDS) and the main menu's Progress button; copy contract, readability, screen-flow and docs updated; Gates 1 and 2 approved; 2166 → 2239 tests. Status → review.
