---
baseline_commit: 9866c54746a51a5221847a4fba21c0ff430c013b
---

# Story 6.8: Level Unlocks

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a kid,
I want the next level to open after I finish the one before it, with a fun moment when it does,
so that I have something to aim for, and a surprise when I get there.

## Acceptance Criteria

1. **The registry names each level's unlock.** `LevelEntry` gains `@export var unlocked_by: StringName = &""`. In `level_registry.tres`: `zombie_run` = `&""`, `horde_rush` = `&"zombie_run"`, `pitchfork_panic` = `&"horde_rush"`; debug-only levels stay `&""`. A new `LevelRegistry.validate() -> String` returns `""` for the shipped registry and a message when an `unlocked_by` names an unknown, debug-only or self id, or when the chain loops. (FR79)
2. **Save schema v2 with a backfilling migration.** `GameConstants.CURRENT_SCHEMA = 2`. `SaveSchema.profile_defaults()` gains `"level_unlocks": {}`. `SaveSchema.migrate_1_to_2(data)` is registered at index 0 of `migration_steps()` and, for **every** profile, adds `level_unlocks: {}` and backfills it: each level whose `unlocked_by` level has at least one `run_history` record with `end_reason == "timer"` is saved as `{"moment_seen": false, "chosen": false}`, so existing players see the moment on their next menu visit. It never crashes on junk (missing/non-dict profiles, non-array history, non-dict records). `test_save_schema.gd` covers the migration with a fixture file. (Architecture "Schema v2"; EXPERIENCE Level Unlocks "Persistence")
3. **A finished run unlocks the next level.** In `PlayerData.record_run(result)`: when `result.end_reason == GameConstants.END_REASON_TIMER`, every registry level with `unlocked_by == result.level_id` that is not yet unlocked is saved as `{"moment_seen": false, "chosen": false}` and `level_unlocked(level_id)` is emitted. Still exactly **one** save request per `record_run`. Quit runs never reach `record_run` (RunFrame `_quit_to_menu`), so they never unlock. An unlock is never removed by gameplay. (FR13, FR79)
4. **PlayerData owns the unlock state.** `get_unlock_state(level_id) -> Dictionary` returns `{"unlocked": bool, "moment_seen": bool, "chosen": bool}`; a level with empty `unlocked_by` (or unknown to the registry) is always `{true, true, true}`. `mark_unlock_seen(level_id)` and `mark_level_chosen(level_id)` set their field on an unlocked level, emit `unlocks_changed(level_id)` and request a save; on a locked level, or one already set, they change nothing. No other code writes `level_unlocks`.
5. **Locked card.** A card whose level is `available` but not unlocked shows the **Locked** state: picture tinted `dusk`, a big `stone-light` padlock over it, nothing else on the card at rest. While it has focus (arrow or hover), a parchment hint sign hangs on two strings just below it, reading "Finish <unlocked_by level's name> to open!" ("Finish Zombie Run to open!"); it hides when focus leaves. Enter or a click only wiggles the card: no signal, no sound. A level with `available = false` shows **Coming soon** whatever its lock state. (FR79, FR26, DESIGN.md level-card, EXPERIENCE.md level-card)
6. **The unlock moment.** When the main menu opens (from any route: report card, Closet, pause quit, title) and an `available` level is unlocked with `moment_seen == false`, the moment plays once after the menu's fade-in: ~0.3 s beat → padlock wiggles, pops off and falls away (a showing hint sign leaves with it) → dusk tint clears to full colour → "New!" badge thumps on with a short jingle → keyboard focus moves to that card. `PlayerData.mark_unlock_seen(level_id)` saves it, so it never plays again. **Input stays live:** any arrow key, Enter, Esc or left click during the moment finishes it instantly (end state, focus on the new card) and is then handled normally. (EXPERIENCE.md Level Unlocks)
7. **"New!" until first chosen.** An unlocked level whose `chosen == false` shows the **New** state: full-colour picture plus a `pumpkin` "New!" badge on the top-right corner overlapping the frame. Choosing it (Enter or click) starts the level like Available, calls `PlayerData.mark_level_chosen(level_id)`, and the badge is gone on every later menu visit.
8. **Debug tools.** The debug overlay (debug builds only) gains mouse-only **"Unlock all"** and **"Relock all"** buttons, enabled only on the main menu like the jump buttons. Unlock all saves every level with a non-empty `unlocked_by` as unlocked with its moment not seen and not chosen; Relock all empties `level_unlocks`. Both go through `PlayerData` and then reload the main menu (so the moment / locks show immediately).
9. **Tests.** GUT covers: unlock-on-timer, no-unlock-on-quit (no `record_run`) and on non-timer reasons, one-time moment, New cleared on first choice, backfill (fixture), state precedence (Coming soon > Locked > New > Available), the hint sign, input finishing the moment, the registry validation, and the debug buttons. In `test_player_data.gd`, the new `test_level_unlocks.gd`, plus updates to the existing schema / save / menu / card / overlay / plain-words tests. Full suite green.
10. **No regressions.** Fresh save: Zombie Run is the only choosable card and gets focus; Horde Rush is Locked; Pitchfork Panic is Coming soon. Menu focus wiring, toggles, storage notice, Ctrl+Shift+E export, hat/pet, report card, Play Again, Welcome Gift flow and the run frame behave as before. Plain words, 16 px floor, palette and grayscale rules hold for every new piece.

## Tasks / Subtasks

- [x] **Task 1: Registry `unlocked_by` + validation (AC: 1)**
  - [x] 1.1 `scripts/resources/level_entry.gd`: add `@export var unlocked_by: StringName = &""` with a `##` doc ("The level whose finished run (timer reached its end) opens this one; empty = open from the start. FR79"). Update the header doc (drop "Unlock rules arrive with Story 6.8").
  - [x] 1.2 `scripts/resources/level_registry.gd`: add `func validate() -> String` (each non-empty `unlocked_by` names an existing, non-debug, different entry; following `unlocked_by` from any entry never revisits an id). Add `func unlocks_of(level_id: StringName) -> Array[LevelEntry]` (entries whose `unlocked_by == level_id`, registry order) — `record_run` and the debug tool use it.
  - [x] 1.3 `data/levels/level_registry.tres`: `unlocked_by = &"zombie_run"` on `Resource_horde_rush`, `unlocked_by = &"horde_rush"` on `Resource_pitchfork_panic`. Leave `zombie_run` and the debug levels at the default. Do **not** change any `available` flag (Horde Rush stays `true`, Pitchfork Panic `false`).
  - [x] 1.4 Tests (`test_level_registry.gd`): shipped `validate() == ""`; shipped `unlocked_by` values; `validate()` catches unknown id, self, debug-only target and a 2-cycle; `unlocks_of(&"zombie_run")` = [horde_rush].
- [x] **Task 2: Schema v2 + migration (AC: 2)**
  - [x] 2.1 `scripts/core/game_constants.gd`: `CURRENT_SCHEMA = 2`.
  - [x] 2.2 `scripts/core/save_schema.gd`: `"level_unlocks": {}` in `profile_defaults()` (as the last key). The fixture tests compare exact `JSON.stringify(..., "\t")` text, and key order in that text depends on the dictionary, so generate the v2 fixture from the real `defaults()` output instead of typing it by hand. `migration_steps()` returns `[migrate_1_to_2]`. Update the header doc.
  - [x] 2.3 `static func migrate_1_to_2(data: Dictionary) -> Dictionary`. **Pure** (SaveSchema touches no files, nodes or autoloads), so it must **not** load `level_registry.tres`: use a frozen const `V2_UNLOCKED_BY: Dictionary = {"horde_rush": "zombie_run", "pitchfork_panic": "horde_rush"}` with a `##` saying it is the v2 unlock chain frozen at migration time (migrations describe the past; later registry changes don't rewrite old migrations). For each profile that is a Dictionary: if `level_unlocks` is not a Dictionary, set `{}`; for each `level → by` in `V2_UNLOCKED_BY`, if `run_history` (only when it is an Array) contains a Dictionary record with `str(level_id) == by` and `str(end_reason) == "timer"`, and `level_unlocks` doesn't already have the key, add `{"moment_seen": false, "chosen": false}`. Skip junk silently (a warn log at most); never crash; return `data`.
  - [x] 2.4 Fixtures: new `tests/fixtures/saves/save_v2_fresh.json` = `JSON.stringify(SaveSchema.defaults(), "\t")` + trailing newline (the format `test_defaults_match_v1_fixture` compares). Keep `save_v1_fresh.json` and `save_v1_full.json` **unchanged** — they are now migration inputs. Add `save_v1_backfill.json`: a v1 save with two profiles — `p1` with one `zombie_run` `"timer"` record and one `horde_rush` record whose `end_reason` is `"caught"` (not a timer, so only Horde Rush unlocks, not Pitchfork Panic), plus one junk history entry (a number) to prove skipping; `p2` with an empty history (nothing unlocks).
  - [x] 2.5 `test_save_schema.gd`: `FRESH_PATH` → the v2 fixture for the defaults/fill tests (`test_defaults_match_*`, `test_fill_adds_missing_fields`, `test_fill_repairs_*`, `test_migrate_noop_at_current`, `test_migrate_future_version_left_alone`). The stub-step chain tests (`_step_a` asserts version 1) need a **v1** input: add `_v1_fresh()` reading `save_v1_fresh.json` and use it in `test_migrate_runs_steps_in_order`, `test_migrate_treats_bad_version_as_1`, `test_migrate_missing_step_logs_error`, `test_migrate_step_returning_null_*`. New: `test_migrate_1_to_2_backfills_from_timer_runs` (backfill fixture → p1 has `horde_rush` unseen/unchosen and no `pitchfork_panic`; p2 `{}`), `test_migrate_1_to_2_on_full_fixture` (`save_v1_full.json` → `horde_rush` unlocked), `test_migrate_1_to_2_survives_junk` (profiles not a dict, history not an array, profile not a dict), `test_migrate_1_to_2_keeps_existing_entries`, `test_prepare_v1_reaches_v2` (`schema_version == 2`), `test_v2_chain_matches_registry` (`V2_UNLOCKED_BY` equals the shipped registry's non-empty `unlocked_by` map — loading the registry is fine in a **test**).
  - [x] 2.6 `test_save_service.gd`: the export test (line ~244) compares to the **v2** fresh fixture; `test_smoke.gd` `CURRENT_SCHEMA == 2`. Run the whole save suite; any deep-equality test fed `save_v1_full.json` must compare against `SaveSchema.prepare()` of it (it already does via `_prepared`), not a hand-built dict.
- [x] **Task 3: PlayerData unlock API (AC: 3, 4, 8)**
  - [x] 3.1 `scripts/autoloads/player_data.gd`: signals `level_unlocked(level_id: StringName)` and `unlocks_changed(level_id: StringName)` (`&""` = many changed, the debug tools). Test seam `var level_registry: LevelRegistry = null`; resolve it **lazily** (`_registry()` → `load("res://data/levels/level_registry.tres")` on first use), **never `preload`**: the registry references every level scene, and a preload in an autoload would load all levels at boot, before the title (load budget). RunFrame and the menu already load it, so the lazy load is a cache hit.
  - [x] 3.2 `record_run`: after the history/best/brains block and before `run_recorded.emit`, if `result.end_reason == GameConstants.END_REASON_TIMER`, for each entry in `_registry().unlocks_of(result.level_id)` not yet in `level_unlocks`: add `{"moment_seen": false, "chosen": false}` (key = `String(id)`), collect it. Emit `level_unlocked(id)` for each **after** `run_recorded`, keep the single `save_service.request_save()`. Log `Log.info(&"run", "unlocked %s" % id)`.
  - [x] 3.3 `get_unlock_state`, `mark_unlock_seen`, `mark_level_chosen` per AC 4. Reads tolerate a hand-edited save: key present = unlocked; a non-Dictionary entry or a missing/non-bool field reads as `true` (no surprise replays); a mark on such an entry rewrites it as a proper Dictionary. `_level_unlocks()` returns the profile Dictionary, replacing a non-Dictionary value with `{}`.
  - [x] 3.4 Debug: `debug_set_all_unlocked(on: bool)` — `on`: every registry entry with non-empty `unlocked_by` set to `{"moment_seen": false, "chosen": false}` (overwrites, so the moment replays); `off`: `level_unlocks` = `{}`. Emits `unlocks_changed(&"")`, one save request. Doc: debug overlay only.
  - [x] 3.5 Header doc: replace "Later methods, by story: …(6.8)" with the unlock API description; keep the "only PlayerData writes save fields" rule.
  - [x] 3.6 `reset_all()` needs no change: defaults have `level_unlocks: {}` and listeners re-read on `profile_replaced`.
- [x] **Task 4: LevelCard LOCKED / NEW + hint + moment (AC: 5, 6, 7)**
  - [x] 4.1 `scripts/ui/level_card.gd`: `enum State { AVAILABLE, COMING_SOON, LOCKED, NEW }` (append — never reorder, tests compare enum values). Add a static pure `state_for(entry: LevelEntry, unlock: Dictionary) -> State`: `not entry.available` → COMING_SOON; `not unlock.unlocked` → LOCKED; `not unlock.chosen` → NEW; else AVAILABLE. `setup(entry, unlock := {"unlocked": true, "moment_seen": true, "chosen": true})` keeps the old call sites working; add `set_state(state)` for the menu's re-read on `profile_replaced` / `unlocks_changed`. Add `set_hint_text(text)`.
  - [x] 4.2 `_activate()`: AVAILABLE **and NEW** emit `chosen(level_id)`; COMING_SOON and LOCKED wiggle (no sound). Add `is_choosable() -> bool`.
  - [x] 4.3 `scenes/ui/level_card.tscn` new nodes (all `mouse_filter = IGNORE`, unique names): `%Padlock` (TextureRect, centred on the picture, `menu/ui_padlock.png`); `%NewBadge` (Panel `BadgePumpkin` + Label "New!" in ink, 16 px, top-right corner overlapping the frame); `%Hint` (Control under the card at y ≈ 124 + 6: two 1 px ink "strings" + a `Sign` panel with an ink 16 px autowrap label, fixed width that fits "Finish Zombie Run to open!" on two lines at 16 px — Press Start 2P is 16 px per glyph, so ~224 px wide; centred on the card, but **clamped** so it never leaves the 16 px margin rect `Rect2(16, 16, 608, 328)` — the third card's hint would overflow the right edge otherwise). `%Hint` sets `z_index = 1` (or `top_level`) so it draws **over** the storage notice that sits below the cards (StorageNotice is a later sibling of `%Cards` at 288..624 × 200..280 and would cover the hint).
  - [x] 4.4 `_set_state`: COMING_SOON = today's look (stone tint, plank, grey sign). LOCKED = `%Tint` shown in `dusk #4A3366` (same alpha style as the stone tint), `%Padlock` shown, normal parchment sign, no plank. NEW = no tint, no padlock, `%NewBadge` shown. AVAILABLE = nothing extra. `%Hint` visible only when `state == LOCKED and has_focus()`; update it from `_show_focus`.
  - [x] 4.5 Moment API on the card: `play_unlock_moment()` (state must be LOCKED-looking at start, ends in NEW look) and `finish_unlock_moment()` (kill the tween, snap to the NEW end state: padlock hidden and reset, tint hidden, badge shown at scale 1) and `is_playing_moment() -> bool`. One `Tween` owned by the card (`create_tween()` binds it to the card, so it pauses while the Router's fade has the tree paused — the beat therefore starts after the fade-in, as EXPERIENCE asks). Look values as consts with the house comment ("Look value, not a GDD number"): `MOMENT_BEAT_S = 0.3`, padlock wiggle ~0.2 s (reuse `WIGGLE_PX`), pop up 6 px + fall 24 px with fade ~0.35 s, tint alpha → 0 ~0.3 s, badge scale 1.4 → 1.0 ~0.15 s. Whole-pixel positions (pixel-art rule). Signal `unlock_moment_finished(level_id)` at the end (natural or forced). The jingle is played by the card at the badge thump through a `play_sfx` Callable seam (default `AudioManager.play_sfx`) so tests stay silent.
  - [x] 4.6 Update the header doc (four states, hint, moment, precedence) and drop "Story 6.8 adds LOCKED and NEW".
- [x] **Task 5: Main menu wiring (AC: 5, 6, 7, 10)**
  - [x] 5.1 `scripts/screens/main_menu.gd` `_build_cards()`: `card.setup(entry, player_data.get_unlock_state(entry.id))`; for LOCKED cards `card.set_hint_text("Finish %s to open!" % <unlocked_by entry's display_name>)`. Keep the "available but no scene → Coming soon" guard.
  - [x] 5.2 `_first_available_card()` → first **choosable** card (AVAILABLE or NEW). It also drives the initial focus and the bottom row's Up target (`_wire_focus`).
  - [x] 5.3 `_on_card_chosen(level_id)`: if that card is NEW, `player_data.mark_level_chosen(level_id)` **before** `_leave(...)`. (Play Again on the report card doesn't pass through a card and never clears the badge — intended: "chosen" means picked on the menu.)
  - [x] 5.4 Moment: in `_ready()` after focus is set, collect cards whose state is LOCKED-by-look-but-pending — i.e. `entry.available` **and** `unlock.unlocked` **and not** `unlock.moment_seen`. Build such a card in the LOCKED look, call `player_data.mark_unlock_seen(id)` immediately (saved once even if the tab closes mid-animation), then `card.play_unlock_moment()`. If several are pending (only possible via backfill/debug), play them together and move focus to the first in registry order. A Coming-soon level's pending moment is **not** played or marked — it waits until that level becomes available (Pitchfork Panic later).
  - [x] 5.5 Live input: `_input(event)` (not `_unhandled_input`, which only sees what the GUI didn't take) — while any moment plays, a pressed non-echo arrow (`ui_left/right/up/down`), `ui_accept`, `ui_cancel` or left mouse button **press** calls `_finish_moment()` (finish every card, move focus to the new card) and does **not** mark the event handled, so it then runs normally (Enter on the now-focused new card starts it; Esc still goes nowhere). Mouse motion, other keys and the Ctrl+Shift+E chord don't finish it. On natural end, also move focus to the new card (`unlock_moment_finished`).
  - [x] 5.6 Re-read: on `profile_replaced` (F8 reset) and `unlocks_changed`, recompute every card's state with `LevelCard.state_for` + `set_state` (no moment), re-wire focus (`_wire_focus`) because the first choosable card may change, and keep focus valid (a focused card that became LOCKED keeps focus — Locked cards stay focusable).
  - [x] 5.7 Header doc: replace "Later: Locked/New card states and the hint sign (6.8)…" with the unlock behaviour (states, hint copy source, moment, mark_level_chosen).
- [x] **Task 6: Art + jingle (AC: 5, 6, 7)**
  - [x] 6.1 `tools/gen_ui_art.gd` `_write_menu()`: a big padlock `menu/ui_padlock.png` (suggested 32×40: `stone-light` body and shackle, `stone` shade, ink 1 px outline, ink keyhole), palette-only, hard alpha, no `candy-yellow`/`stamp-red`. Run it headless the way 5.0 did and commit the PNG + `.import` (Nearest, no mipmaps — copy an existing menu sprite's import settings).
  - [x] 6.2 `docs/art-style-sheet.md` section 7 table: add the padlock row (`test_art_ui.gd` fails on an unlisted file). `test_art_ui.gd` palette/outline/alpha checks apply automatically; run them.
  - [x] 6.3 `tools/gen_audio.gd`: `_unlock_jingle()` (short, bright, ~0.5–0.7 s, three rising bell notes via the existing `_bell()`; quieter than `sfx_purchase`), saved as `assets/audio/sfx/sfx_unlock_jingle.wav`. Add an `AudioCue` `sfx_unlock_jingle` in `data/audio/audio_library.tres` (SFX bus, a volume near the purchase jingle, e.g. −6 dB; throttle not needed — the moment plays once). Add the CREDITS row (`assets/audio/CREDITS.md`, generated, CC0) — `test_audio_credits.gd` requires exactly one row per file — and the id to `test_audio_library.gd`'s expected-cues list.
- [x] **Task 7: Debug overlay Unlock all / Relock all (AC: 8)**
  - [x] 7.1 `scenes/debug/debug_overlay.tscn`: two buttons `%UnlockAllButton` "Unlock all" / `%RelockAllButton` "Relock all" on `%JumpRow2` (or a new `%JumpRow3` if the panel would overflow — `test_fits_above_the_hud_band_with_every_section` must still pass), `focus_mode = FOCUS_NONE` like the jump buttons.
  - [x] 7.2 `debug_overlay.gd`: add both to `_refresh_jumps()` (disabled off the main menu). Pressed → (only if `visible and _on_main_menu()`) `player_data.debug_set_all_unlocked(true/false)` then `navigate.call(Router.Screen.MAIN_MENU, {})` to reload the menu (Router allows MAIN_MENU → MAIN_MENU). Update the class doc.
  - [x] 7.3 `test_debug_overlay.gd`: buttons exist and never take focus; disabled off the menu; on the menu each calls PlayerData (fake or real-with-temp-save) and navigates to MAIN_MENU once; extend `test_jump_buttons_exist_and_never_take_focus` lists.
- [x] **Task 8: Tests (AC: 9, 10)**
  - [x] 8.1 `test_player_data.gd` (fresh SaveService in `TEST_DIR` + a **code-built** `LevelRegistry` injected through the new seam, so tests don't depend on the shipped chain): timer run of `zombie_run` unlocks `horde_rush` and emits `level_unlocked` once, after `run_recorded`; still exactly one save request (`test_record_run_requests_exactly_one_save` pattern); a second timer run emits nothing; `&"caught"`/`&"escaped"` end reasons unlock nothing; a run of a level that unlocks nothing changes nothing; `get_unlock_state` defaults (open level, locked level, unknown id); `mark_unlock_seen` / `mark_level_chosen` set, emit once, save, are no-ops when locked or already set; junk entries read as seen/chosen and are repaired by a mark; the state survives a reload (new SaveService on the same dir); `debug_set_all_unlocked(true/false)`; `reset_all()` relocks; with no injected registry it lazily uses the shipped one.
  - [x] 8.2 New `tests/unit/test_level_unlocks.gd` (the AC-named flow file): `LevelCard.state_for` precedence table (Coming soon > Locked > New > Available, incl. `available=false` + unlocked); the **one-time moment**: menu built on a PlayerData whose `horde_rush` is unlocked/unseen → card plays the moment, `moment_seen` saved true, focus ends on Horde Rush after `finish_unlock_moment()`; a second menu on the same PlayerData plays nothing and shows NEW; choosing the NEW card navigates to RUN with `horde_rush` and saves `chosen`; the next menu shows AVAILABLE; a Coming-soon level with an unseen moment plays nothing and stays unseen; **no-unlock-on-quit**: drive a RunFrame quit (or assert `record_run` is never called on `_quit_to_menu`, reusing the `test_run_frame.gd` quit pattern) and check `level_unlocks` stays empty; **backfill**: `SaveService` loading `save_v1_backfill.json` → menu shows the Horde Rush moment.
  - [x] 8.3 `test_level_card.gd`: LOCKED look (dusk tint, padlock, no plank, parchment sign, no badge); NEW look (badge, no tint/padlock); LOCKED wiggles and never emits; NEW emits once on Enter and click; hint visible only while LOCKED **and** focused, hidden on focus loss and on any other state; hint text; moment end state equals NEW; `finish_unlock_moment()` mid-way snaps to the end state and emits `unlock_moment_finished` once; jingle requested once through the seam; positions stay whole pixels.
  - [x] 8.4 `test_main_menu.gd`: `test_shipped_registry_gives_three_cards_in_order` on a **fresh** save → `[AVAILABLE, LOCKED, COMING_SOON]` (update the 6.7 comment). Initial focus = Zombie Run on a fresh save. Up from the bottom row → first choosable. Input during the moment: Right arrow finishes it and then moves focus right of Horde Rush (to Pitchfork Panic); Enter finishes it and starts Horde Rush once; Esc finishes it and goes nowhere; mouse motion does not finish it. `profile_replaced` after an unlock relocks the card. Hint sign stays inside the margin rect and is not counted as overlapping the notice (update `test_notice_overlaps_no_control` / `test_every_control_is_inside_the_margin` only by **explicitly** excluding/including `%Hint` with a reason — don't weaken them). Text fits and ≥ 16 px with the hint and badge shown.
  - [x] 8.5 `test_plain_words.gd`: add "Finish Zombie Run to open!", "Finish Horde Rush to open!" and "New!" to `APPROVED_COPY` (Main menu group) and collect the hint copy for every menu entry with an `unlocked_by` plus the badge label in the script-copy walk. `test_readability.gd` / `test_grayscale_states.gd`: Locked vs Coming soon differ by shape (padlock vs plank) not hue — add a case like the five-tile one.
  - [x] 8.6 Run the full GUT suite headless (`"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gexit` — same command as earlier stories). All green, no new warnings/errors in output except the ones tests assert. Watch the integration flows (`test_first_purchase_flow.gd`, `test_screen_flow.gd`, `test_run_frame.gd`): a first finished Zombie Run now unlocks Horde Rush, so a flow that ends on the main menu may now start the unlock moment and move focus to Horde Rush once it finishes. Update such expectations on purpose, with a comment pointing to 6.8, and don't hide it by relocking in setup unless the test isn't about the menu.
- [x] **Task 9: Verify in the real game (AC: 5, 6, 7, 10)**
  - [x] 9.1 Desktop debug run (godot MCP `run_project`, or the editor): fresh save (debug overlay F8 ×2) → menu: Horde Rush Locked, hint on focus, Enter wiggles. F3 → "Unlock all" → menu reloads and the moment plays; press an arrow mid-way → it snaps and focus moves. Choose Horde Rush → back to menu → badge gone. F3 → "Relock all" → Locked again.
  - [ ] 9.2 (not done: covered by tests only, see Completion Notes) Real path once: fresh save → play Zombie Run to 0:00 (F6 ends it "as if the clock ran out" = `timer`, allowed) → report card → Welcome Gift → Closet → Esc → menu: the moment plays here, not earlier. Then quit-mid-run path on a fresh save: Pause → Quit to Menu → Horde Rush still Locked.
  - [x] 9.3 Screenshots to `screenshots/6-8/` (locked + hint, moment mid-way, new badge). If `tools/capture_screens_runner.gd` makes this easy, add the three captures there; otherwise manual screenshots are fine.
  - [ ] 9.4 (skipped: optional) Optional web check (debug export, `preview_start {name: "web-debug"}`, **pane visible**): the moment plays smoothly and the jingle is heard after the first click.
- [x] **Task 10: Docs + release hand-off**
  - [x] 10.1 `_bmad-output/implementation-artifacts/deferred-work.md`: strike line ~227 ("`record_run` validates only `null`; unlock rule … join it in Story 6.8") as done in 6.8. Leave the line ~531 note (a debug Horde Rush jump that ends with F6 writes a `timer` record that can unlock Pitchfork Panic) — still true, still harmless while Pitchfork Panic is Coming soon; add "6.8: confirmed, the backfill/record_run counts it" to it.
  - [x] 10.2 Release: Story 6.7 says the next version tag after 6.8 publishes Horde Rush. **Do not push a tag yourself.** In the Completion Notes, tell Smuck the build is ready for the next `v*` tag (last is `v1.0.0`; suggest `v1.1.0`) once code review is done; Smuck pushes it (Pages deploys only from `v*` tags).

### Review Findings

- [x] [Review][Patch] Unlock moment end steals focus unconditionally — `_on_unlock_moment_finished` calls `_moment_cards[0].grab_focus()` even if the player moved focus (Tab, mouse hover) during the ~1.3 s; only grab if focus is unset or still on the initial card [scripts/screens/main_menu.gd:_on_unlock_moment_finished]
- [x] [Review][Patch] Card with `chosen:true` + `moment_seen:false` plays the moment and ends on NEW (badge reappears) — skip the moment or pass the end state into `_end_moment` [scripts/screens/main_menu.gd:_build_cards, scripts/ui/level_card.gd:_end_moment]
- [x] [Review][Patch] `mark_level_chosen` is saved before navigation succeeds; a failed/blocked `_leave` burns the New! badge for a level that never started [scripts/screens/main_menu.gd:_on_card_chosen]
- [x] [Review][Patch] `set_state()` mid-moment does not kill/finish `_moment_tween`, which keeps writing padlock/tint and later forces NEW [scripts/ui/level_card.gd:_set_state]
- [x] [Review][Patch] Hint sign shows during the 0.3 s beat on a just-unlocked focused card, then vanishes abruptly at pop instead of leaving with the padlock (AC6) [scripts/ui/level_card.gd:play_unlock_moment/_on_padlock_popped]
- [x] [Review][Patch] `PlayerData._registry()` can return null (failed load); `record_run` timer branch and `get_unlock_state` then crash before `run_recorded`/`request_save`, losing the run — guard null and/or compute unlocks before mutating [scripts/autoloads/player_data.gd:_registry, record_run]
- [x] [Review][Patch] `migrate_1_to_2` backfill compares against live `GameConstants.END_REASON_TIMER`; freeze the literal "timer" like `V2_UNLOCKED_BY` [scripts/core/save_schema.gd:_finished_levels]
- [x] [Review][Patch] Story Tasks 9.2 and 9.4 are ticked `[x]` but Completion Notes say not done — untick or mark skipped [_bmad-output/implementation-artifacts/6-8-level-unlocks.md]
- [x] [Review][Defer] `LevelRegistry.validate()` is only called from tests, never at runtime [scripts/resources/level_registry.gd:55] — deferred, shipped registry is test-checked
- [x] [Review][Defer] Timing-based `wait_seconds` assertions in moment tests (0.05 s slack) may flake on slow runners; Router-fade pause behavior has no automated test [tests/unit/test_level_card.gd]
- [x] [Review][Defer] `debug_set_all_unlocked(false)` wipes unlocks without confirm; confirm debug overlay is stripped from release exports [scripts/autoloads/player_data.gd, scripts/debug/debug_overlay.gd]

## Dev Notes

### What this story is / isn't

- **Is:** the FR79 lock rule end to end: registry chain, save v2 + backfill, unlock in `record_run`, Locked / New card states, the hint sign, the one-time unlock moment with a jingle, the "New!" badge lifetime, debug unlock/relock tools.
- **Isn't:** Pitchfork Panic (Epic 8; it stays `available = false`, so its card is always Coming soon and its moment never plays); tiers / placement (Epic 7 — its fields go **inside the profile**, never at the top level); profiles UI (Epic 11 — `migrate_1_to_2` already walks every profile so 11 needs nothing); a 4th card (the row is exactly full, deferred in 4.2); any change to Horde Rush tuning, RunFrame's state machine, the report card or the Closet; a gate in RunFrame against starting a locked level (the debug jump starts Horde Rush on purpose; the card is the only kid path).

### Current state of the files you'll touch (read before editing)

- **`scripts/core/save_schema.gd`** — pure static class. `prepare()` = `normalize_numbers` → `migrate` → `fill_defaults`. `migrate(data, steps, target)` already loops `steps[version-1]`, bumps `schema_version`, logs, and never crashes (missing step / non-dict return / future version). `migration_steps()` returns `[]` today; the header says migrate_1_to_2 lands here. `_merge` fills missing keys and replaces wrong-typed values with the default — so a non-Dictionary `level_unlocks` becomes `{}` automatically **after** migration, but migrate_1_to_2 still must not assume types (it runs **before** fill).
- **`scripts/core/game_constants.gd`** — `CURRENT_SCHEMA = 1`, `END_REASON_TIMER = &"timer"`. In the JSON save, `end_reason` and `level_id` are **Strings** (`RunResult.to_record()`); compare with `str()`.
- **`scripts/autoloads/player_data.gd`** — the only writer of profile fields; every mutation emits a typed signal and calls `save_service.request_save()` exactly once; getters read through `save_service.get_active_profile()` live (no caching — F8 reset / Epic 11 switch replace the data). Contract violations log and change nothing (no `assert`). `record_run` already does history (cap 500 via one slice), best WPM, brains inline (to keep one save request), `run_recorded.emit`, one save, info log. Seams: `save_service`, `catalogue`.
- **`scripts/ui/level_card.gd` / `scenes/ui/level_card.tscn`** — `Control` with `_gui_input` (not a Button). States AVAILABLE / COMING_SOON; `setup(entry)` before `add_child`; the lift/bob move `%Frame.position.y`, the wiggle owns `%Frame.position.x`; hover grabs focus on real mouse motion; every child `mouse_filter = IGNORE`. Card 192×124, picture region 4..188 × 4..76, name sign 4..188 × 80..120, `%Tint` is a ColorRect stone at 0.85 alpha.
- **`scripts/screens/main_menu.gd`** — builds cards from `level_registry.menu_entries()`; focus wiring with explicit neighbours (cards row ↔ bottom row, ends stop, Tab wraps); `_leave()` guards one navigation and the Router transition; Esc on the root does nothing; `_show_profile()` re-reads brains + toggles on `profile_replaced`. Seams: `navigate`, `player_data`, `toggle_fullscreen`, `is_fullscreen`, `is_transitioning`, exported `level_registry`.
- **`scripts/debug/debug_overlay.gd`** — debug builds only (Router adds it only when `OS.is_debug_build()`); jump buttons are mouse-only (`FOCUS_NONE`), enabled only on MAIN_MENU via `_refresh_jumps()`, routed through `_jump()` and the `navigate` seam.
- **`scripts/autoloads/router.gd`** — `go()` pauses the tree for the fade and unpauses after the fade-in; it ignores a `go()` during a transition; MAIN_MENU → MAIN_MENU is allowed (it reloads the scene).
- **`scripts/run/run_frame.gd`** — `_record_result()` calls `player_data.record_run(_result)` on entering ENDING; `_quit_to_menu()` only `add_brains()` and never builds a result. F6 (`debug_end_run`) ends with `END_REASON_TIMER`. **No change needed here.**

### Must preserve

- One save request per `record_run` (`test_record_run_requests_exactly_one_save`).
- Fresh-save menu: Zombie Run focused; arrows/Tab/Up behaviour; Esc goes nowhere; Ctrl+Shift+E export; FR27 notice; toggles; hat/pet; whole-pixel bob; wiggle returns exactly to 0.
- `save.json` written by this build is v2. A v2 save opened by an older (v1) build is loaded read-only by that build (existing `_read_only` rule) — nothing to do.
- Unknown save fields survive (fill keeps unknown keys); `migrate_1_to_2` must not drop anything.
- Test isolation: tests never touch the real `user://save.json` (fresh SaveService on a temp dir, PlayerData via seams), never play real audio (seams), and inject a code-built registry where the shipped chain isn't the subject.

### Unlock state rules (one place to look)

| available | unlocked_by | in `level_unlocks` | moment_seen | chosen | Card | Moment |
|---|---|---|---|---|---|---|
| false | any | any | any | any | COMING_SOON | never (and not marked) |
| true | `""` | – | – | – | AVAILABLE | – |
| true | set | no | – | – | LOCKED (+ hint on focus) | – |
| true | set | yes | false | false | starts LOCKED-look → plays → NEW | plays once, marked seen at start |
| true | set | yes | true | false | NEW | – |
| true | set | yes | true | true | AVAILABLE | – |

Save shape (architecture "Schema v2"): `profiles.<id>.level_unlocks = { "horde_rush": { "moment_seen": false, "chosen": false } }`. Key present = unlocked, never removed by gameplay (only the debug "Relock all" and F8 reset clear it). Storage not persistent → the unlock follows the save, like brains (accepted).

### Unlock moment sequence (EXPERIENCE.md Level Unlocks; all motion values `[ASSUMPTION]`, tune by eye)

menu fades in (Router; tree paused, card tween waits) → **0.3 s beat** → padlock wiggles (±2 px, ~0.2 s) → padlock pops up ~6 px and falls ~24 px while fading (~0.35 s; the hint sign, if showing, hides with it) → dusk tint fades out (~0.3 s) → "New!" badge scales 1.4 → 1.0 (~0.15 s) with `sfx_unlock_jingle` → focus to the card. No screen shake (D9). Animation never blocks input: arrow / Enter / Esc / left click → snap to the end state + focus to the new card, then the event is processed normally.

### Hint sign layout (DESIGN.md level-card-locked, D14)

Parchment `Sign` box, ink 16 px Press Start 2P label, hanging on two 1 px ink strings from the card's bottom edge. 16 px per glyph means "Finish Zombie Run to open!" (26 glyphs) needs two lines: ~"Finish Zombie" / "Run to open!" in a ~224 px wide sign (+ padding). Centre it under the card, clamp to x ∈ [16, 624]. Cards are at y 64..188 (focused lift −2/−3 px); a sign at y ≈ 194..246 stays above the bottom row (toggles start at y 288) but overlaps the storage notice (288..624 × 200..280) when shown under the Horde Rush card: it must draw on top (z_index) — it is transient and only appears while the Locked card has focus. Copy source: the `unlocked_by` entry's `display_name` from the registry (EXPERIENCE Voice and Tone: "Finish Zombie Run to open!" / "Finish Horde Rush to open!").

### Architecture compliance

- Only `PlayerData` mutates save fields; only `SaveService` touches files; `SaveSchema` is pure (no file/registry loads → the frozen `V2_UNLOCKED_BY` const, guarded by a test against the registry).
- Data lives in Resources (`unlocked_by` on `LevelEntry`), not literals in scripts — the menu and `record_run` read the registry; only the frozen migration const is a literal, by design.
- Logging: `Log.info(&"run", …)` for unlocks, `Log.warn(&"save", …)` for migration junk, `Log.debug` for the moment. Never log save contents.
- Static typing everywhere, `##` docs on public members, StringName ids in the API, String keys in the save (house rule in PlayerData's header).
- New level later = `unlocked_by` in the registry + (only if old saves need backfilling) a new migration; note this in `level_entry.gd`'s doc.

### Library / framework

Godot **4.7.2**, GUT **9.7.1** (architecture D9, verified 2026-09-27). Nothing new to install. Tweens: `create_tween()` on the card (bound to the node, so it pauses with the tree during the Router fade); `Tween.kill()` + direct property sets to snap. `Control.z_index` is available on all CanvasItems (use it for the hint over the notice). No web-specific behaviour beyond the existing audio unlock (the jingle plays after the title's first input, so it's never blocked).

### File list (expected)

UPDATE: `scripts/resources/level_entry.gd`, `scripts/resources/level_registry.gd`, `data/levels/level_registry.tres`, `scripts/core/game_constants.gd`, `scripts/core/save_schema.gd`, `scripts/autoloads/player_data.gd`, `scripts/ui/level_card.gd`, `scenes/ui/level_card.tscn`, `scripts/screens/main_menu.gd`, `scripts/debug/debug_overlay.gd`, `scenes/debug/debug_overlay.tscn`, `tools/gen_ui_art.gd`, `tools/gen_audio.gd`, `data/audio/audio_library.tres`, `assets/audio/CREDITS.md`, `docs/art-style-sheet.md`, `_bmad-output/implementation-artifacts/deferred-work.md`; tests `test_save_schema.gd`, `test_save_service.gd`, `test_smoke.gd`, `test_player_data.gd`, `test_level_registry.gd`, `test_level_card.gd`, `test_main_menu.gd`, `test_debug_overlay.gd`, `test_plain_words.gd`, `test_grayscale_states.gd`, `test_audio_library.gd` (+ `test_readability.gd` / `test_art_ui.gd` only if they need the new piece listed).
NEW: `assets/sprites/ui/menu/ui_padlock.png` (+ `.import`), `assets/audio/sfx/sfx_unlock_jingle.wav` (+ `.import`), `tests/fixtures/saves/save_v2_fresh.json`, `tests/fixtures/saves/save_v1_backfill.json`, `tests/unit/test_level_unlocks.gd`, `screenshots/6-8/*`.

### Testing standards

GUT 9.7.1 under `tests/unit` / `tests/integration`; `extends GutTest`; a `##` file doc saying what's covered; fresh SaveService on `user://test_<name>/` cleared before/after each test; seams assigned before `add_child_autofree`; no real audio, no real Router navigation (navigate seam), no real save. Assert pushed warnings/errors you trigger (`assert_push_warning` / `assert_push_error`), and never weaken an existing assertion to make it pass — change the input or exclude explicitly with a reason.

### Previous story intelligence (6.7 and earlier)

- 6.7 switched `horde_rush.available = true` and explicitly left the lock to this story; main currently has Horde Rush selectable with no lock and **must not be tagged** until 6.8 lands (6.7 Task 7.4). Hence Task 10.2.
- 6.7/6.3 known defer: a debug "Horde Rush" jump that reaches 0:00 (or F6) writes a real `timer` record → with 6.8 it unlocks Pitchfork Panic in that save (harmless: Coming soon). Smuck's own dev save will also be migrated on first launch (likely unlocking Horde Rush with an unseen moment — expected; use "Relock all" to re-test).
- Web checks need the browser pane **visible** (hidden pane throttles rAF; 1.8/4.5/5.3/6.7).
- 4.2: the card was designed as one component with a state enum precisely so 6.8 only adds states; the row is 608 px exactly full (no 4th card).
- 5.0/5.2: every new sprite must be listed in the style sheet table, palette-only, 1 px ink outline (UI exemptions listed), 16 px text floor, plain-words approved-copy list, grayscale distinctness by shape.
- 5.1: SFX go through `AudioManager.play_sfx` with a cue in `audio_library.tres`, generated by `tools/gen_audio.gd`, credited in `assets/audio/CREDITS.md`; screens use a `play_sfx` seam in tests.
- Code reviews in this epic repeatedly caught: doc headers left stale ("Later: … 6.8"), tests that couldn't fail, and seams bypassed by live autoloads. Update every header that mentions 6.8 (grep `6.8` in `scripts/` and `scenes/`).

### Git intelligence

Last commits: `9866c54 Story 6.7: horde rush tuning and stress check…`, `bccbf75 / c41cafa Story 6.6…`, `44eb3f0 / a1e0867 Story 6.5…`. Pattern: one implementation commit per story, then a "code review patches applied, done" commit. Commit message style: `Story 6.8: level unlocks` (+ Co-Authored-By trailer).

### Project Structure Notes

- No `project-context.md` exists; conventions come from the architecture doc and the code's own headers (see above).
- `level_card` lives in `scenes/ui` + `scripts/ui` (reusable widget; 4.2 variance note still applies).
- Fixtures under `tests/fixtures/saves/`; keep v1 fixtures byte-identical (they're migration inputs now).
- `tools/` is export-excluded; generators are run headless and their outputs committed.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 6.8: Level Unlocks] (ACs); #Story 4.2 (card component, states added later); #Story 6.7 (tag after 6.8); FR79, FR13, FR25, FR26, FR27, FR38, NFR7–NFR11, NFR13
- [Source: _bmad-output/game-architecture.md#State Management] (PlayerData unlock API, `level_unlocked`); #Data Persistence (Schema v2, migrations with fixtures, end reasons); #Static Game Data; project tree (`level_registry.tres` … unlocked_by)
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/EXPERIENCE.md] Level Unlocks (rule, precedence, moment, persistence), Component Patterns (level-card), Voice and Tone (hint/New! copy), State Patterns (Main Menu: unlock pending), Game Feel
- [Source: …/DESIGN.md] components `level-card-locked` / `level-card-coming-soon` / `level-card-new`, Colors (dusk, stone-light, pumpkin), "Distinct Locked vs Coming soon" do/don't
- [Source: …/mockups/key-main-menu.html] section B (Locked / moment / New!; its hint-at-rest is superseded by D14)
- [Source: _bmad-output/planning-artifacts/sprint-change-proposal-2026-09-27-b.md] (D12 gating routed into GDD/epics/architecture)
- [Source: docs/art-style-sheet.md] sections 7–8 (UI sprites table, readability/grayscale)
- [Source: _bmad-output/implementation-artifacts/6-7-horde-rush-tuning-and-stress-check.md] (Horde Rush available, no tag until 6.8); 4-2-main-menu.md (card design); deferred-work.md lines ~227, ~531

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5), two sessions on 2026-10-08.

### Debug Log References

- Baseline before the story: 1583/1583 GUT tests green. Final: 1648/1648 green (86 scripts), no new warnings or errors apart from the ones tests assert (the two migrate_1_to_2 junk warnings; the "newer than this build" text now reads 2).
- Full-suite run found that `test_screen_flow.gd` built the main menu on the LIVE PlayerData. Since 6.8 the menu writes unlock state, so that test wrote Smuck's real `user://save.json` (only `level_unlocks` changed: Horde Rush seen + chosen; brains 108 and run history intact; the v2 migration itself is expected on first launch). Fixed: every menu instance in that test now gets a temp-dir PlayerData; later full runs leave the real save's mtime unchanged.
- `assert_eq_deep` takes no message in GUT 9.7.1; messages became comments.

### Completion Notes List

- Registry: `LevelEntry.unlocked_by`; `LevelRegistry.validate()` (unknown / self / debug-only / loops) and `unlocks_of()`. Shipped chain zombie_run -> horde_rush -> pitchfork_panic; no `available` flag changed.
- Save v2: `CURRENT_SCHEMA = 2`, `level_unlocks: {}` in profile defaults, pure `migrate_1_to_2` with the frozen `V2_UNLOCKED_BY` (a test keeps it equal to the registry). Backfills every profile from `timer` records; skips junk; keeps existing entries and unknown fields. v1 fixtures unchanged; new `save_v2_fresh.json` (generated from `defaults()`) and `save_v1_backfill.json`.
- PlayerData: `level_unlocked` / `unlocks_changed` signals, lazy registry seam (never preloaded), unlock in `record_run` (timer only, emitted after `run_recorded`, still one save request), `get_unlock_state`, `mark_unlock_seen`, `mark_level_chosen` (junk entries read as set and are rewritten as a Dictionary by a mark), `debug_set_all_unlocked`.
- LevelCard: `State.LOCKED` / `State.NEW` appended; static `state_for` (Coming soon > Locked > New > Available); dusk tint + padlock; "New!" BadgePumpkin flush with the card's right edge; hint sign on two ink strings, focus-only, clamped into the 16 px margin, `z_index = 1` over the storage notice; unlock moment (beat, padlock wiggle/pop/fall on whole pixels, tint clear, badge thump + `sfx_unlock_jingle` via `play_sfx` seam), `finish_unlock_moment()` snaps, jingle and `unlock_moment_finished` exactly once.
- Main menu: states from PlayerData, hint copy from the `unlocked_by` entry's display name, pending moments start Locked-looking, are marked seen first, then play together; `_input` finishes them on arrow / Enter / Esc / left click without consuming the event; focus to the first new card when the last one ends; a New card is marked chosen before leaving (not while a transition blocks the leave); re-read on `profile_replaced` / `unlocks_changed` (a relock mid-moment finishes it Locked).
- Art + audio: 32x40 `menu/ui_padlock.png` (stone-light / stone / ink, generator map), style-sheet row + `test_art_ui` entry; `sfx_unlock_jingle.wav` (G5 C6 E6 bells, 0.65 s, cue at -6 dB), CREDITS row, expected-cues list. Regenerating rewrote every other sheet and sound byte-identically.
- Debug overlay: "Unlock all" / "Relock all" on `%JumpRow2` (FOCUS_NONE, main menu only), through PlayerData, then reload MAIN_MENU. The panel still fits above the HUD band.
- Tests: new `tests/unit/test_level_unlocks.gd` (precedence table, real RunFrame quit vs finish, one-time moment -> New -> Available across three menus, reload, Coming soon waits, v1 backfill shows the moment) plus additions to the registry, schema, save, smoke, PlayerData, card, menu, overlay, plain-words, grayscale, art and audio tests. Mutation checks: breaking the hint rule, the badge reset, the input finish or the seen/chosen marks makes the new tests fail.
- Task 9 (verify in the real game): a scratch runner drove the ENABLED main menu in a real window on a temp save, with real input through `Input.parse_input_event`: 20/20 checks (Locked + hint on a real arrow, Enter wiggles, moment playing at 0.75 s, a real arrow mid-moment finishes it and moves focus on to Pitchfork Panic, seen saved, New on the next visit, Enter starts Horde Rush and saves chosen, natural end focuses the new card, real save untouched). Screenshots: `screenshots/6-8/01-locked-hint.png`, `02-unlock-moment-midway.png`, `03-new-badge.png`. The 9.2 hands-on path (play Zombie Run to 0:00 -> report card -> gift -> Closet -> menu; pause-quit leaves Horde Rush Locked) is covered by the RunFrame finish/quit tests and the route-agnostic menu `_ready`, not by a manual playthrough: a quick hands-on run is still worth doing. 9.4 (optional web check) not done.
- Smuck's dev save: already v2 with Horde Rush seen + chosen (see Debug Log). Use F3 -> "Relock all" to see the lock and the moment again.
- Release (10.2): no tag pushed. After code review, the build is ready for the next `v*` tag; last is `v1.0.0`, suggested `v1.1.0` (publishes Horde Rush with its lock). Smuck pushes it; Pages deploys only from `v*` tags.

### File List

UPDATE:
- `_bmad-output/implementation-artifacts/deferred-work.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `assets/audio/CREDITS.md`
- `data/audio/audio_library.tres`
- `data/levels/level_registry.tres`
- `docs/art-style-sheet.md`
- `scenes/debug/debug_overlay.tscn`
- `scenes/ui/level_card.tscn`
- `scripts/autoloads/player_data.gd`
- `scripts/core/game_constants.gd`
- `scripts/core/save_schema.gd`
- `scripts/debug/debug_overlay.gd`
- `scripts/levels/horde_rush/horde_rush_level.gd`
- `scripts/resources/level_entry.gd`
- `scripts/resources/level_registry.gd`
- `scripts/screens/main_menu.gd`
- `scripts/ui/level_card.gd`
- `tests/integration/test_screen_flow.gd`
- `tests/unit/test_art_ui.gd`
- `tests/unit/test_audio_library.gd`
- `tests/unit/test_debug_overlay.gd`
- `tests/unit/test_grayscale_states.gd`
- `tests/unit/test_level_card.gd`
- `tests/unit/test_level_registry.gd`
- `tests/unit/test_main_menu.gd`
- `tests/unit/test_plain_words.gd`
- `tests/unit/test_player_data.gd`
- `tests/unit/test_save_schema.gd`
- `tests/unit/test_save_service.gd`
- `tests/unit/test_smoke.gd`
- `tools/gen_audio.gd`
- `tools/gen_ui_art.gd`

NEW:
- `assets/audio/sfx/sfx_unlock_jingle.wav` (+ `.import`)
- `assets/sprites/ui/menu/ui_padlock.png` (+ `.import`)
- `screenshots/6-8/01-locked-hint.png`, `02-unlock-moment-midway.png`, `03-new-badge.png`
- `tests/fixtures/saves/save_v1_backfill.json`
- `tests/fixtures/saves/save_v2_fresh.json`
- `tests/unit/test_level_unlocks.gd` (+ `.uid`)

### Change Log

- 2026-10-08: Story 6.8 implemented: level unlock chain in the registry, save schema v2 with backfilling migration, unlocks in `record_run`, PlayerData unlock API, Locked / New level cards with hint sign and one-time unlock moment + jingle, padlock art, debug Unlock all / Relock all; `test_screen_flow.gd` menu instances moved onto temp saves. 1648/1648 tests green. Status -> review.
