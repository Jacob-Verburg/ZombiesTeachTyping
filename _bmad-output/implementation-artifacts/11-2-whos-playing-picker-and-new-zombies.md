---
baseline_commit: 544f6e855819c6063bb5f1b32501fa9f7c0f24e9
---

# Story 11.2: "Who's Playing?" Picker and New Zombies

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a kid sharing a computer,
I want to pick my own zombie when the game starts, or make a new one,
so that my sibling's runs never mix with mine.

## Acceptance Criteria

1. **The title goes to the picker (FR78, FR23, FR24).** When the title screen moves on (any key except Esc, or a click; the audio unlock and click stay inside the input callback, as today), `title.gd::next_screen()` returns a new `Router.Screen.WHOS_PLAYING` when **at least one** profile in the save has a valid name (`PlayerData.has_named_zombie()`), and `NAME_ZOMBIE` otherwise (a brand-new save or an unnamed MVP save: Story 11.1's first-time naming is unchanged). So a save with one named zombie also sees the picker (epic AC: "one or more profiles"). Nothing else in the flow changes: report card, Closet, Progress and pause → Quit to Menu still go straight to the menu.
2. **The "Who's playing?" screen (FR78, FR25, NFR9, DESIGN.md).** `WHOS_PLAYING` is **appended after `NAME_ZOMBIE`** in `Router.Screen` (no value moves) and maps to `res://scenes/screens/whos_playing.tscn` (script `scripts/screens/whos_playing.gd`). It shows a heading sign, one **zombie card** per profile (that profile's name in the pixel font, its own zombie wearing **its** equipped hat with **its** equipped pet beside it) and a **"New zombie"** card/button. Cards are in a stable order (see AC 5, `get_profile_ids()`). A profile with no valid name (only possible in a hand-edited save) shows `GameConstants.ZOMBIE_NAME_DEFAULT` ("Zombie") on its card. Copy is `[ASSUMPTION — Gate 1]`: heading "Who's playing?", button "New zombie". Menu music keeps playing (`play_music(&"mus_menu")`). The payload is consumed and ignored.
3. **Keyboard and mouse (FR25).** Arrow keys move one visible candy-yellow focus between the cards and "New zombie" (ends stop, no wrap; Tab/Shift+Tab walk the same order); Enter or a left click picks the focused/clicked card; hover moves focus (the `PixelButton` / `LevelCard` pattern), so only one control is highlighted. On open, focus is on the **active** profile's card (the zombie that played last). Esc does nothing (the title is not a place to go back to; same as the main menu). Every control is ≥ 32 px tall.
4. **Picking a zombie.** Enter/click on a zombie card: `player_data.switch_profile(id)`, the UI click, then exactly one navigation: `MAIN_MENU, {}` when that profile has a valid name, else `NAME_ZOMBIE, {}` (the unnamed zombie gets named first — 11.1's mode). Once-guard `_leaving` (released if the Router never starts a transition, the `name_zombie.gd::_finish` pattern).
5. **PlayerData profile API (FR78, ADR-2, Boundary 4).** New public methods on `scripts/autoloads/player_data.gd`, all reading `save_service.get_data()` live (no caching):
   - `get_profile_ids() -> Array[StringName]` — every id in `profiles`, sorted with `naturalnocasecmp_to` on the String (so `p2` < `p10`).
   - `get_active_profile_id() -> StringName`.
   - `get_profile_summary(id: StringName) -> Dictionary` — `{"id": StringName, "name": String, "hat": StringName, "pet": StringName}` for any profile, with the **same validation as the active-profile getters**: name through `ZombieName.is_valid` (junk → `""`), hat/pet only when owned by **that** profile and an available catalogue item of the right slot (else `&""`). Unknown id → `{}` and `Log.error`. Refactor `get_equipped`/`owns`/`get_zombie_name` onto private `profile: Dictionary` helpers so both paths share one rule; their public behaviour and every existing test stay identical.
   - `has_named_zombie() -> bool` — any profile's name is valid.
   - `can_add_zombie() -> bool` — profile count `< GameConstants.MAX_ZOMBIES` (`[ASSUMPTION — Gate 1]`: 4).
   - `switch_profile(id: StringName) -> bool` — unknown id: `Log.error`, nothing changes, false. Already active: true, no signal, no save. Else: sets `active_profile`, calls `_reconcile_tier()` (deferred-work 7-2: "Epic 11's profile switch must call `_reconcile_tier()`"), emits `profile_replaced`, one `request_save()`, `Log.info(&"save", "switched zombie %s" % id)` (the id, **never the name**), true.
   - `create_profile(raw_name: String) -> StringName` — `ZombieName.clean`; refused (returns `&""`, fixed `Log.warn`, nothing changes) when the cleaned name is invalid, when it equals another profile's valid name ignoring case (`nocasecmp_to`), or when `can_add_zombie()` is false. Else adds `SaveSchema.profile_defaults()` with that name under the lowest unused id `p<N>` (N ≥ 1), makes it active, runs `_reconcile_tier()`, emits `profile_replaced` **and** `zombie_name_changed`, one save request, `Log.info(&"save", "new zombie %s" % id)`, returns the id. Defaults = 0 brains, no items, nothing worn, all flags false (so the new zombie gets placement, the tutorial arrow and the welcome gift of its own), tier 0, no history, no unlocks, lifetime zeros, music/sound on.
   - Extend the class doc with a `## Profiles (Story 11.2, FR78): ...` paragraph; update the existing "Epic 11's profile switch" sentences to name `switch_profile` / `create_profile`.
6. **New zombie (FR78).** "New zombie" (Enter/click) → UI click → `NAME_ZOMBIE` with payload `{"new_zombie": true}`. In that mode the name screen (one screen, Story 11.1's): starts with an **empty** field (not the active zombie's name); Done with a valid, unused name calls `player_data.create_profile(name)` and, on a non-empty id, goes to `MAIN_MENU, {}` once; Done with an empty, invalid or already-used name, or at the cap, **wiggles** the field (no default name in this mode, no sound, no text); Esc **or** a visible `%BackButton` ("Back", `[ASSUMPTION — Gate 1]`) returns to `WHOS_PLAYING, {}` and creates nothing. Without the payload (title → unnamed zombie, or picker → unnamed card) the screen behaves exactly as 11.1 (no Back button, Esc does nothing, empty Done saves "Zombie"). The branch lives in `_finish()` / `_submit()` (11.1 kept "what Done does" in one place for this).
7. **At the cap.** When `can_add_zombie()` is false the "New zombie" control is not shown and not focusable `[ASSUMPTION — Gate 1]`; `create_profile` refuses as a second line of defence.
8. **Everything refreshes on a switch (epic AC 3).** After `switch_profile` / `create_profile`, every `profile_replaced` listener shows the new zombie: main menu brain counter and Music/Sound toggles (`_show_profile`), level cards (`_refresh_unlocks`), `HatSlot`/`PetSlot` with `follow_equipped`, AudioManager's saved music/sound settings (`_apply_saved_settings`), Closet, Progress. A GUT integration test proves it on a live main menu instance with a temp PlayerData: two profiles with different brains, hat, pet, `music_on` and unlocks → `switch_profile` → counter, toggles, hat/pet ids and card states match the second profile (no new listener code expected — if something stays stale, fix that listener).
9. **No migration, no new save fields (ADR-2).** `GameConstants.CURRENT_SCHEMA` stays **5**; `SaveSchema` is unchanged (`fill_defaults` already merges every profile and repairs a missing `active_profile`); no fixture changes. `test_smoke.gd`'s schema assertion must not move. A save with two profiles round-trips through a second temp `SaveService` with both profiles and `active_profile` intact (GUT).
10. **Names never logged (NFR12).** No log, print or push line carries a name — profile ids (`p2`) may be logged. Extend 11.1's source-guard test to `scripts/screens/whos_playing.gd`, `scripts/ui/zombie_card.gd` and the new PlayerData methods (it already reads `player_data.gd`), and add `summary`, `raw_name`, `chosen` to its identifier list.
11. **Layout and readability (NFR7, DESIGN.md, Gate 1).** 640×360, everything inside the 16 px margin, no overlap, no clipped text with `MAX_ZOMBIES` cards each holding a 12-character `WWWWWWWWWWWW` name plus "New zombie". Names ≥ 16 px (Press Start 2P: 12 × 16 = 192 px). Focus is candy yellow only. No `StyleBoxFlat`, no `draw_*`: theme variations that exist (`Sign`, `PixelButton`, `TileParchment`, `FocusRing`, `WoodPanel`…). Hat and pet shown with `HatSlot`/`PetSlot` set to `follow_equipped = false` + `show_item()` (the Crypt Closet preview pattern), never by following the active profile. The new scene is walked by `test_no_placeholder_chrome.gd`, `test_plain_words.gd`, `test_readability.gd`, `test_screen_flow.gd`.
12. **Approval gates.** Gate 1: layout sketch of the picker (1 zombie; `MAX_ZOMBIES` zombies with 12-character names and hats/pets; focus) **and** of the name screen's new-zombie mode (Back button placement), plus the copy list and the questions in Dev Notes, approved by Smuck **before** wiring visuals. Gate 2: in-game captures (picker with 1 and with 4 zombies, one focused card, grayscale; name screen new-zombie mode empty and refused-duplicate wiggle frame) approved by Smuck. Record verbatim + date under `## Art Approval`. No new sound, no new sprites.
13. **No regressions.** Full GUT suite green and the count only goes up; zero `Parse Error|Compile Error|Failed to load script`; `SCRIPT ERROR` / `WARNING` counts unchanged except deliberate, asserted ones. All existing PNG/WAV byte-identical. The real `user://save.json` sha256 identical before and after every suite run and manual check (temp `user://` dirs only).

## Tasks / Subtasks

- [x] **Task 1: Baseline** (AC: 13)
  - [x] 1.1 `"C:\Program Files\Godot\Godot.exe" --headless --path . --import`, then `... --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` into a scratch log. Record tests/passing, `SCRIPT ERROR`, `WARNING`, and zero `Parse Error|Compile Error|Failed to load script`. Expected after 11.1 + review: ~2291+ / all passing, `SCRIPT ERROR` 3, `WARNING` ~183 — re-measure.
  - [x] 1.2 Record the real save's sha256 (`%APPDATA%/Godot/app_userdata/ZombiesTeachTyping/save.json`).

- [x] **Task 2: PlayerData profile API** (AC: 5, 9, 10) — do first, test-first.
  - [x] 2.1 `scripts/core/game_constants.gd`: `MAX_ZOMBIES: int = 4` with a `## FR78 / Story 11.2:` comment (a content/layout rule, like `ZOMBIE_NAME_MAX_LENGTH`) and `NEW_ZOMBIE_ID_FORMAT: String = "p%d"` (or reuse `SaveSchema.DEFAULT_PROFILE_ID`'s pattern — one place only).
  - [x] 2.2 Refactor: `_profile()` stays the active-profile accessor; add `_profiles() -> Dictionary` (`save_service.get_data()["profiles"]`) and per-profile helpers (`_owned_in(profile)`, `_stored_name(profile)`, `_equipped_id_in(profile, slot)`), then make `owns`, `get_owned_items`, `get_equipped`, `get_zombie_name` call them with `_profile()`. **No public behaviour change** — run the existing `test_player_data.gd` after the refactor before adding anything.
  - [x] 2.3 Add the AC 5 methods. Write `active_profile` through `save_service.get_data()["active_profile"] = String(id)` (SaveService hands its live Dictionary to PlayerData only; `get_active_profile()` re-reads `active_profile` every call, so nothing else in SaveService changes). Ids are Strings in the save, StringNames in the API.
  - [x] 2.4 `tests/unit/test_player_data.gd` (temp-dir SaveService only): ids sorted naturally (`p1, p2, p10`); summary of the active and of an inactive profile (hat/pet owned by **that** profile; a hat id the profile doesn't own reads `&""`; junk name reads `""`; unknown id → `{}` + `assert_push_error`); `has_named_zombie` on fresh / named / junk-name saves; `switch_profile` unknown → false, nothing changes; same id → true, no signal, no save; other id → `profile_replaced` once, one save request, `get_brains()`/`get_equipped()`/`get_setting()`/`get_tier()` now read the other profile, and the **old profile Dictionary is deep-equal before/after**; switching to an MVP-shaped profile with runs and tier 0 places it (`_reconcile_tier`, `placement_done` true); `create_profile` → id `p2` on a one-profile save, the lowest gap reused (`p1`,`p3` → `p2`), whole new profile equals `profile_defaults()` plus the name, active, signals (`profile_replaced`, `zombie_name_changed`) and one save; refused cases (invalid, `"sam"` when `"Sam"` exists, at `MAX_ZOMBIES`) → `&""`, nothing written, fixed warning asserted; two-profile reload through a second temp SaveService keeps both and `active_profile`.

- [x] **Task 3: Gate 1 — sketch and copy** (AC: 2, 3, 6, 7, 11, 12) — **stop for Smuck's approval before Task 4/5 visuals.**
  - [x] 3.1 `_bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/sketches/whos-playing-11-2.md` in the style of `name-zombie-11-1.md`: picker with 1 zombie, with `MAX_ZOMBIES` zombies (12-character names, hats, pets), focus on a card, cap state (no "New zombie"); the name screen's new-zombie mode with `%BackButton`. Coordinates on the 4 px grid, theme variations used, focus map. Proposed starting layout in Dev Notes.
  - [x] 3.2 Copy list (all `[ASSUMPTION]`): "Who's playing?", "New zombie", "Back". Ask the Dev Notes → Questions for Gate 1 in the same message. Record the verbatim answers + date under `## Art Approval`.

- [x] **Task 4: Zombie card** (AC: 2, 3, 11)
  - [x] 4.1 New `scenes/ui/zombie_card.tscn` + `scripts/ui/zombie_card.gd` (`class_name ZombieCard`, mirrored paths; closest models: `closet_item_tile.gd` and `level_card.gd`). `setup(summary: Dictionary, catalogue: Catalogue)` before `add_child`; shows the name label (16 px, `ZOMBIE_NAME_DEFAULT` for `""`), a `player_zombie.tscn` instance whose `%HatSlot` has `follow_equipped = false` and a `pet_slot.tscn` with `follow_equipped = false`, both fed with `show_item(catalogue.get_item(id))` (null for `&""`). It never touches PlayerData: Enter/click emits `picked(id: StringName)`. Focusable (`FOCUS_ALL`), hover grabs focus, candy-yellow `FocusRing` when focused, every child `mouse_filter = IGNORE`.
  - [x] 4.2 `tests/unit/test_zombie_card.gd`: setup shows name, hat id, pet id (code-built catalogue); empty name shows "Zombie"; Enter and left click emit `picked` once with the id; the card never reads `PlayerData` (assign a sentinel / check no autoload connection); focus ring visible only when focused.

- [x] **Task 5: "Who's playing?" screen** (AC: 2–4, 6, 7, 11)
  - [x] 5.1 `scripts/autoloads/router.gd`: append `WHOS_PLAYING` after `NAME_ZOMBIE` + its `SCREEN_PATHS` entry; class doc/arch note. `tests/unit/test_router.gd` enum-order assertion with message `"Story 11.2 appended WHOS_PLAYING; nothing moved"`.
  - [x] 5.2 `scenes/screens/whos_playing.tscn` + `scripts/screens/whos_playing.gd` (`extends Control`). Seams assigned before `add_child`, defaulted in `_ready()`: `navigate`, `player_data`, `play_sfx`, `play_music`, `is_transitioning`, exported `catalogue` (default the shipped `catalogue.tres`). Nodes: `Background` (night), `%Sign` + `%Heading`, `%Cards` (container for `ZombieCard`s, built in `_ready()` from `get_profile_ids()` + `get_profile_summary()`), `%NewZombieButton` (`PixelButton`), hidden when `not can_add_zombie()`.
  - [x] 5.3 Focus wiring in code after building (the `main_menu.gd::_wire_row` pattern: explicit `focus_neighbor_*`, ends stop, `focus_next/previous` for Tab), initial focus on the active profile's card (fallback: first card).
  - [x] 5.4 Pick → `player_data.switch_profile(id)` → `play_sfx(&"sfx_ui_click")` → `navigate(MAIN_MENU or NAME_ZOMBIE, {})` (AC 4); New zombie → click → `navigate(NAME_ZOMBIE, {"new_zombie": true})`. `_leaving` once-guard + release if `is_transitioning` is false right after `navigate` (11.1 review fix). Esc (`ui_cancel`) handled and ignored. Re-build the cards on `profile_replaced` (F8 reset while open) and disconnect in `_exit_tree`.
  - [x] 5.5 Don't set `WebPlatform.capture_keys` here (no typing on this screen; menus leave browser keys alone, Story 5.3).

- [x] **Task 6: Name screen new-zombie mode** (AC: 6)
  - [x] 6.1 `scripts/screens/name_zombie.gd`: read the payload (`Router.take_payload()` already called — keep its result); `_new_zombie: bool = payload.get("new_zombie", false) == true` (anything else = 11.1 mode). In new mode: `_set_text("")`, don't re-read the active name on `profile_replaced`, show `%BackButton`, Esc → `_back()`.
  - [x] 6.2 `_submit()`: new mode → `cleaned` valid → `_finish(cleaned)`; otherwise `_wiggle()` (no `ZOMBIE_NAME_DEFAULT`). `_finish()`: new mode → `player_data.create_profile(chosen)`; `&""` → wiggle and return; else click + `MAIN_MENU`. 11.1 mode unchanged (`set_zombie_name`).
  - [x] 6.3 `scenes/screens/name_zombie.tscn`: add `%BackButton` (`PixelButton`, hidden by default) where Gate 1 puts it; wire focus between Back and Done only when visible (11.1 pins every Done neighbour to itself — update both when Back shows). Space must still never press either button (11.1's `_input` Space swallow covers every focused button — keep it).
  - [x] 6.4 `_back()`: once-guard, click, `navigate(WHOS_PLAYING, {})`, nothing created.
  - [x] 6.5 `tests/unit/test_name_zombie.gd`: new mode starts empty even when the active zombie has a name; valid → `create_profile` called (temp PlayerData now has 2 profiles, the new one active), click, one `[MAIN_MENU, {}]`; empty / `"sam"` duplicate / at cap → wiggle, no navigation, profile count unchanged; Esc and `%BackButton` → one `[WHOS_PLAYING, {}]`, nothing created; Back hidden and Esc dead in 11.1 mode; junk payload (`{"new_zombie": "yes"}`) → 11.1 mode. All existing 11.1 tests unchanged and green.

- [x] **Task 7: Title routing** (AC: 1)
  - [x] 7.1 `scripts/screens/title.gd::next_screen()`: `WHOS_PLAYING` when `player_data.has_named_zombie()`, else `NAME_ZOMBIE`. Class doc updated. Unlock/click/once-guard untouched.
  - [x] 7.2 `tests/unit/test_title.gd`: the 11.1 case "named → MAIN_MENU" (`:135`) becomes "named → WHOS_PLAYING" (update its message to say Story 11.2 changed it); add: two profiles, only the inactive one named → `WHOS_PLAYING`; all unnamed → `NAME_ZOMBIE`.

- [x] **Task 8: Refresh-on-switch integration + cross-screen walks** (AC: 8, 11, 13)
  - [x] 8.1 New `tests/integration/test_profile_switch.gd` (or extend `test_screen_flow.gd`): AC 8's two-profile main-menu check, plus AudioManager re-applies `music_on` from the new profile (use the AudioManager seam that `test_audio_manager.gd` uses for `player_data`; never the live autoload's save).
  - [x] 8.2 `tests/integration/test_screen_flow.gd`: `_instance()` gives `WHOS_PLAYING` a temp PlayerData (it **writes** via `switch_profile` — 10.1 real-save incident), navigate recorder, no-op `play_sfx`/`play_music`; `FLOW_BUTTONS["WHOS_PLAYING"] = ["%NewZombieButton"]`; `test_whos_playing_consumes_the_payload`; a flow test title-named → picker → pick → `MAIN_MENU`.
  - [x] 8.3 `tests/unit/test_plain_words.gd`: approve "Who's playing?", "New zombie", "Back" on purpose; walk the picker with names emptied/defaulted so test names never reach the copy check (kids' names are user content). The default card label "Zombie" **is** copy shown by the game and is not in `APPROVED_COPY` yet (11.1 only approved "Name your zombie!" and "Done") — add it on purpose.
  - [x] 8.4 `tests/unit/test_readability.gd`: `WhosPlayingScene` preload; walk with `MAX_ZOMBIES` profiles named `WWWWWWWWWWWW` with hats and pets (fit / 16 px / no overlap / inside margin); name screen walk in new-zombie mode (Back visible). Confirm `test_no_placeholder_chrome.gd` picks up the new scene/scripts without change.
  - [x] 8.5 `tests/unit/test_player_data.gd` NFR12 source guard: add the new files and identifiers (AC 10).
  - [x] 8.6 `grep -rn "Screen.MAIN_MENU\|NAME_ZOMBIE" tests` for anything that drives the title or the name screen and assumed 11.1's routing; update only what AC 1/6 changes.

- [x] **Task 9: Docs** (AC: 1, 2, 6)
  - [x] 9.1 `EXPERIENCE.md`: IA row "Who's playing?" (from Title when any zombie is named; leaves to Main Menu, Name your zombie); flow line `Title → (Name your zombie, first zombie only) | Who's playing? → (Name your zombie, new zombie) → Main Menu → …`; Voice and Tone rows; Component Patterns row `zombie-card`; State Patterns (1 zombie, full/cap, new-zombie mode with Back). DESIGN.md: "Zombie card" component entry.
  - [x] 9.2 `_bmad-output/game-architecture.md`: Screen Flow enum + `WHOS_PLAYING` note + `NAME_ZOMBIE` payload `{"new_zombie": true}`; State Management line lists `switch_profile()` / `create_profile()` among PlayerData's mutations; Data Persistence: profile ids `p<N>`, `MAX_ZOMBIES`, no schema change.

- [x] **Task 10: Gate 2 — in-game check** (AC: 12, 13)
  - [x] 10.1 Captures via a scratch windowed runner on an isolated user dir (11.1's way: temporary `override.cfg` with `custom_user_dir_name`, deleted after along with the runner and the dir) into `_bmad-output/implementation-artifacts/screenshots/11-2/`: `picker-one.png`, `picker-full.png` (4 zombies, 12-char names, hats/pets), `picker-full-gray.png`, `new-zombie-empty.png`, `new-zombie-duplicate.png`. Show Smuck; record verbatim + date.
  - [x] 10.2 Web smoke (`web-debug` launch config, browser storage only): existing named save → title → picker (1 zombie) → New zombie → type a name (single key presses) → Enter → menu shows 0 brains, no hat, only Zombie Run open → reload → title → picker shows 2 zombies, focus on the new one → pick the first → menu shows its brains/hat/pet/settings. Console: no errors, no line containing either name.

- [x] **Task 11: Wrap-up** (AC: 13)
  - [x] 11.1 Full suite + counts vs baseline; real save sha256 unchanged.
  - [x] 11.2 Mutation pass (scratch harness, restore after): `switch_profile` skips `_reconcile_tier`; `switch_profile` doesn't emit `profile_replaced`; `create_profile` allows a duplicate name; `create_profile` ignores the cap; `get_profile_summary` shows a hat the profile doesn't own; title always `NAME_ZOMBIE`; new-zombie Done saves "Zombie" on empty; Back creates a profile; picker focuses the first card instead of the active one. Each must turn a test red.
  - [x] 11.3 Anything deferred → `deferred-work.md`. Status → review.

### Review Findings

Code review 2026-10-15 of commit cd9415b, scripts and scenes only (tests not yet reviewed). Layers: Blind Hunter, Edge Case Hunter, Acceptance Auditor (no AC violations found).

- [x] [Review][Patch] Picking an unnamed zombie strands the player on the 11.1 name screen — resolved: allow Back/Esc to return to the picker in 11.1 mode when more than one profile exists [scripts/screens/name_zombie.gd, scripts/screens/whos_playing.gd `_pick`]
- [x] [Review][Dismiss] Duplicate display names via the default "Zombie" — decided: accept as is
- [x] [Review][Patch] More than MAX_ZOMBIES profiles (hand-edited save) overflow the screen with off-screen focusable cards — cap the displayed list, active first [scripts/screens/whos_playing.gd `_build`]
- [x] [Review][Patch] Picker rebuild skipped while `_leaving` leaves stale cards if navigation never starts — set a `_dirty` flag in `_on_profile_replaced` and rebuild in `_release_when_settled` [scripts/screens/whos_playing.gd]
- [x] [Review][Patch] `_build` stacks cards using `card.size.y` before layout is applied — use the 52 px constant or `get_combined_minimum_size().y` [scripts/screens/whos_playing.gd `_build`]
- [x] [Review][Patch] Skip ids whose `get_profile_summary` is empty so a dead card never emits `&""` [scripts/screens/whos_playing.gd `_build`, scripts/ui/zombie_card.gd]
- [x] [Review][Patch] After a successful `create_profile` with no transition started, the screen stays in new-zombie mode and Done then wiggles ("name already used") — leave the mode or navigate on success [scripts/screens/name_zombie.gd `_finish`]

## Dev Notes

### What this story is (and isn't)

- **Is:** PlayerData profile list/summary/switch/create API, one new screen (`WHOS_PLAYING`) + one reusable `ZombieCard`, the name screen's new-zombie mode, title routing, refresh-on-switch proof, docs, tests, two gates.
- **Isn't:** the exhaustive "no data crosses between profiles" GUT sweep over every field (Story 11.3 — but don't build anything that would break it: every write already goes through `_profile()`); showing the name on the menu/report card and a "switch zombies" button on the menu (Story 11.4); renaming or **deleting** a zombie (no AC — do not add); any save schema change.

### Design decisions made for this story (follow them; record any change and why)

1. **Picker only once a zombie has a name.** The epic says the picker shows for "one or more profiles", but 11.1 (approved: "ask everyone") sends an unnamed first zombie to the name screen. A picker holding one nameless "Zombie" card would be a pointless extra step for a brand-new kid. So: fresh/unnamed save → name screen (11.1) → menu; every later launch → picker. Gate 1 question 2.
2. **Create on Done, not on "New zombie".** The profile is created only when a valid name is confirmed, so Back/Esc/closing the tab never leaves an empty profile behind.
3. **Unique names, ignoring case.** Cards are the only way to tell zombies apart, and a new zombie has no hat yet. `create_profile` refuses a duplicate; the screen wiggles (no text — the kid sees their sibling's card on the picker). 11.1's `set_zombie_name` (first zombie only) is not changed.
4. **No default name in new-zombie mode.** 11.1's review added "empty Done saves `Zombie`" so nobody gets stuck; in new-zombie mode a visible **Back** button (and Esc) is the way out, so the default (which would also create duplicate "Zombie"s) is not used.
5. **Cap = 4** (`MAX_ZOMBIES`), assumption for layout at 640×360 with 16 px names. At the cap "New zombie" is hidden. Gate 1 question 3.
6. **Ids `p<N>`, lowest unused.** Matches `SaveSchema.DEFAULT_PROFILE_ID = "p1"`. Never shown, may be logged (not personal data). Never derived from the name (would leak it into the save keys and logs).
7. **Order:** natural sort of ids = creation order in practice; stable across launches regardless of JSON key order.
8. **Focus starts on the active (last-played) zombie.** The common case — the same kid again — is one Enter.
9. **Switching is a profile replacement.** `switch_profile` / `create_profile` emit `profile_replaced` (the signal 1.8 added and documented for "Epic 11's profile switch"); there is no new "switched" signal. All existing listeners already re-read on it.
10. **F8 debug reset** (`reset_all` → `SaveService.reset_to_defaults()`) replaces the **whole save** with one unnamed `p1` — every zombie is wiped. Dev-only; leave it, note it in deferred-work, don't add per-profile reset.

### Proposed layout (starting point for the Gate 1 sketch; 640×360, 4 px grid, 16 px margin; Press Start 2P: glyph width = font size)

- Background night `#2B1D3F` (menu, gift, name screen). `%Sign` top centre "Who's playing?" at 24 px (14 × 24 = 336 + 16 padding = 352 px → x 144–496, y 16–56).
- Cards as a **vertical list** (a row of 4 can't fit 12 × 16 = 192 px names): each card ≈ x 112–528 (416 × 52), zombie at 1× (32 px + hat above) and pet at the left, name 16 px right of them (192 px), 4 px gaps → 4 cards y 68–288. "New zombie" `PixelButton` under them (10 glyphs = 160 + 32 padding = 192 px wide, 32 tall) ≈ y 300–332. With fewer zombies the list stays top-aligned (or centred — sketch it).
- Alternative for the sketch if the cards look thin: 2 × 2 grid of 296 × 112 cards with the zombie at 2× and the name under it (192 px fits 296). Pick one in the sketch; both fit.
- Name screen new-zombie mode: `%BackButton` "Back" (4 glyphs → 96 × 32 plank) left of Done, e.g. x 144–240, y 272–304, with Done/Enter keycap unchanged (x 256–440). Back↔Done Left/Right focus.

### Questions for Gate 1 (ask together with the sketch; record answers)

1. Copy: "Who's playing?" / "New zombie" / "Back" OK?
2. A brand-new or unnamed save names its zombie first and sees the picker from the next launch on (decision 1) — or always show the picker, even before the first name?
3. Up to 4 zombies (decision 5) — enough? And at the cap: hide "New zombie" (default) or show it greyed out?
4. Refuse a name another zombie already has (decision 3)?

### Existing code: current state, what changes, what must be preserved

- **`scripts/autoloads/player_data.gd`** (~650 lines): every getter reads `save_service.get_active_profile()` per call (no caching — this is what makes a switch work; keep it). `reset_all()` = `reset_to_defaults()` + `_reconcile_tier()` + `profile_replaced` — copy that order for switch/create. `_reconcile_tier()` reads `_profile()` (the active one), so set `active_profile` **before** calling it. `get_zombie_name`/`set_zombie_name` (11.1) stay; `set_zombie_name` logs fixed text only. Preserve one-save-request-per-mutation, typed signals, no `assert()`.
- **`scripts/autoloads/save_service.gd`**: `get_data()` / `get_active_profile()` hand out live Dictionaries to PlayerData only; `get_active_profile()` indexes `_data["profiles"][_data["active_profile"]]` every call. **No change needed.** A read-only (newer-schema) save still refuses writes (`ERR_LOCKED`); a switch then lives in memory only — same as every other setter (11.1 deferred note); don't special-case.
- **`scripts/core/save_schema.gd`**: **no change.** `fill_defaults` merges every profile with `profile_defaults()` and falls back to `p1` (or the first sorted id) when `active_profile` is missing.
- **`scripts/screens/title.gd`**: change only `next_screen()` and its doc.
- **`scripts/screens/name_zombie.gd`** (11.1 + review): `_ready()` calls `Router.take_payload()` and discards it — keep the call, use its result. `_submit()` currently saves `ZOMBIE_NAME_DEFAULT` for an invalid name → keep for 11.1 mode only. `_finish(chosen)` is the branch point. `_on_profile_replaced` re-reads the active name → skip in new mode (a `create_profile` emits `profile_replaced` right before we leave; re-reading would flash the new name — harmless but keep the field as typed). `%DoneButton` focus neighbours are all `.` in the `.tscn` — must change when Back is shown. `_input` swallows every Space so no focused button is pressed by Space — keep.
- **`scripts/screens/main_menu.gd`**: **no change expected.** `_show_profile()` (brains, Music/Sound) and `_refresh_unlocks()` are connected to `profile_replaced`; `%Zombie`'s `HatSlot` and `%PetSlot` follow PlayerData. AC 8's test proves it.
- **`scripts/autoloads/audio_manager.gd`**: re-applies settings on `profile_replaced` (line ~115). No change expected.
- **`HatSlot` / `PetSlot`**: `follow_equipped = false` + `show_item(item)` (before or after `add_child` both work) — the Crypt Closet preview does exactly this (`crypt_closet.tscn` sets `follow_equipped = false` on `PreviewZombie/Body/HatSlot` and `PreviewPet`; `crypt_closet.gd:267`). In a card built from code, set `follow_equipped` **before** `add_child` (it's read in `_ready`). For the scene-instanced zombie, the hat slot is `player_zombie.tscn`'s `Body/HatSlot` (`%HatSlot`) — use an editable-children override like the Closet or set it in `setup()` before the card enters the tree.
- **`WebPlatform.capture_keys`**: the picker doesn't type → don't touch it. The name screen still sets/resets it.
- **Welcome gift / tutorial / placement / unlocks**: all per-profile flags already → a new zombie gets its own first-run gift, tutorial arrow, placement run and only Zombie Run open. Nothing to code; the web smoke checks the menu.

### Known test fallout (so you are not surprised)

| Test | Why | Fix |
|---|---|---|
| `test_router.gd` | pins `Screen.keys()` | append `"WHOS_PLAYING"` (Task 5.1) |
| `test_title.gd:135` | named → `MAIN_MENU` (11.1) | now `WHOS_PLAYING` (Task 7.2) |
| `test_screen_flow.gd::test_every_screen_instantiates` | walks every screen; picker writes | temp PlayerData + recorders (Task 8.2) |
| `test_name_zombie.gd` | payload now read | existing cases pass `{}`; add new-mode cases |
| `test_plain_words.gd` / `test_readability.gd` / `test_no_placeholder_chrome.gd` | new scene + copy | Tasks 8.3 / 8.4 |
| `test_player_data.gd` | refactor of owns/get_equipped/get_zombie_name | must stay green unchanged (Task 2.2) |
| `test_smoke.gd` (`CURRENT_SCHEMA == 5`) | must **not** change | undo any schema touch |

### Testing notes

- Commands in Task 1. Run `--import` after adding `class_name ZombieCard` (stale class cache → "Could not find type").
- GUT skips a script that fails to parse and still exits 0 — grep the log for `Parse Error|Compile Error|Failed to load script`.
- Never the real save: temp-dir `SaveService` + injected `PlayerData` (`test_player_data.gd::_make*`, `test_screen_flow.gd::_temp_player_data`). Build multi-profile saves by writing `save_service.get_data()["profiles"]["p2"] = SaveSchema.profile_defaults()` (+ fields) in the test, or a JSON fixture under `tests/fixtures/saves/` (`save_two_zombies.json`) loaded through `_put_fixture`.
- `assert_push_warning` / `assert_push_error` for every deliberate refusal; final `WARNING` count rises only by asserted ones.
- After calling `_unhandled_input()` by hand, push a no-op `InputEventAction` in `after_each` (`_reset_input_handled`, 10.5/11.1) or GUT's viewport stays "handled".
- Synthetic keys: `InputEventKey` with `pressed`, `echo`, `keycode` **and** `unicode`; arrows via `InputEventAction` `ui_left`/`ui_right`/`ui_up`/`ui_down` or real keycodes through `Input.parse_input_event` + a frame.
- Type every variable incl. loop vars (`untyped_declaration = Error`). Sort `String`s, not `StringName`s (`naturalnocasecmp_to` on Strings).
- `queue_free()` frees at frame end — `await get_tree().process_frame` before checking disconnects.
- Flaky `test_audio_manager` pool test: rerun once before investigating.

### Previous story intelligence (11.1, done 2026-10-15)

- Name rules in `ZombieName` (`is_letter`, `append`, `backspace`, `clean`, `is_valid`); `GameConstants.ZOMBIE_NAME_MAX_LENGTH = 12`, `ZOMBIE_NAME_DEFAULT = "Zombie"`.
- Review fixes to keep: `_leaving` released when the Router never starts; `char()` guarded against surrogates / > 0x10FFFF; a space can't take the 12th slot; screen re-reads the name on `profile_replaced`; empty Done → "Zombie" (11.1 mode only, now).
- Done's "off" look = theme overrides that assume Done keeps focus (deferred note). **With a Back button focus can leave Done** → the off look then shows a lit plank with grey text. Fix it now: apply the off look to `normal` too (or re-apply on `focus_exited`/`focus_entered`), and add a test with focus on Back and an empty name.
- NFR12 test deviation: `"Zorbleflux9"` cleans to a valid name; use a truly invalid string (`"#9#9#"`) for refusal tests.
- Gate 2 captures: `-s` scripts don't load the main scene; the runner loaded `title.tscn` and pressed Enter. For 11.2, seed the isolated user dir's `save.json` with 4 named profiles first.
- The browser pane's synthetic keys drop Shift (capitals lowercase there); check capitals on desktop.
- Final 11.1 counts: 2291 / 2291, `SCRIPT ERROR` 3, `WARNING` 183 (plus the review's added tests — re-measure).
- Earlier: **10.1** real-save incident (any screen that can write gets a temp PlayerData in tests); **10.5** Router append + `_reset_input_handled`; **7.2** deferred: profile switch must call `_reconcile_tier()`; **4.4** Closet preview (`follow_equipped = false`); **4.2** focus wiring `_wire_row`; **1.8** `profile_replaced` exists for exactly this.

### Git intelligence

- Recent: `544f6e8 Story 11.1: code review findings resolved, done`, `647aee3 Story 11.1: name the existing zombie`, `b992bce Story 10.5: code review findings resolved, done`, `fc93e9d Story 10.5: trends and lifetime stats screen`. One commit per story with code, tests, scenes, screenshots, docs, story file, `deferred-work.md`, `sprint-status.yaml`.
- Expected shape: new `scripts/screens/whos_playing.gd`, `scenes/screens/whos_playing.tscn`, `scripts/ui/zombie_card.gd`, `scenes/ui/zombie_card.tscn` (+ `.uid`s), `tests/unit/test_whos_playing.gd`, `tests/unit/test_zombie_card.gd`, `tests/integration/test_profile_switch.gd`, maybe `tests/fixtures/saves/save_two_zombies.json`; updated `player_data.gd`, `game_constants.gd`, `router.gd`, `title.gd`, `name_zombie.gd`/`.tscn`, `test_player_data.gd`, `test_title.gd`, `test_router.gd`, `test_name_zombie.gd`, `test_screen_flow.gd`, `test_plain_words.gd`, `test_readability.gd`; sketch, EXPERIENCE/DESIGN rows, architecture lines, screenshots. Message: `Story 11.2: who's playing picker and new zombies`.

### Latest tech notes (Godot 4.7.2, GUT 9.7.1)

- No new libraries/addons; versions pinned by the architecture (Godot 4.7.2 standard, GDScript, Compatibility renderer; GUT 9.7.1). No web research needed beyond what 11.1 recorded.
- `String.naturalnocasecmp_to()` for `p2` < `p10`; `String.nocasecmp_to()` for duplicate names (ASCII-only names, so no locale issues).
- `Dictionary` keeps insertion order, and Godot's `JSON` round-trip keeps it too, but don't rely on it — sort.
- Default `ui_accept` = Enter, KP Enter **and Space**; the picker has no typing, so Space pressing a focused card is fine there (it's the normal button behaviour in menus). In the name screen Space stays swallowed.
- `Control.focus_neighbor_*` / `focus_next` / `focus_previous` take NodePaths relative to the control: use `control.get_path_to(other)` after both are in the tree.

### Project Structure Notes

- Screen: `scripts/screens/whos_playing.gd` + `scenes/screens/whos_playing.tscn`. Reusable UI piece: `scripts/ui/zombie_card.gd` + `scenes/ui/zombie_card.tscn` (like `level_card`, `closet_item_tile`). No pure core helper needed (rules sit in PlayerData, the one profile owner; `ZombieName` already holds name rules). Sketch `ux-designs/.../sketches/whos-playing-11-2.md`; screenshots `implementation-artifacts/screenshots/11-2/`; scratch `tools/_scratch_11_2/` (deleted). No variance from the architecture tree.
- 11.4 will add a "switch zombies" path from the menu → it will navigate to `WHOS_PLAYING`; keep the picker working when entered from anywhere with `{}`.

### Project Context Rules

- There is no `project-context.md`. Rules from the architecture and earlier stories:
  - Only `SaveService` touches files; only `PlayerData` mutates profile/save state (screens read via getters, navigate via `Router`). Boundary 4. `active_profile` is written by PlayerData through `get_data()` only.
  - `scripts/core/` is pure; every class there has a unit test.
  - Static typing everywhere; typed, past-tense signals connected in code; disconnect autoload signals in `_exit_tree`.
  - No GDD number as a literal; UI look values are consts with a "Look value" comment.
  - Never log personal data — zombie names (NFR12). Ids are fine.
  - Kid-facing text: words a 6-year-old can read, no ranks or comparisons between zombies (the picker shows no brains/WPM/tier on cards — NFR10, FR60 tier hidden), no timers (NFR11).
  - DESIGN.md: palette only, 16 px text floor, candy yellow = focus only, no `StyleBoxFlat`, never colour alone.
  - Errors never reach the kid; junk save values read as safe defaults (NFR16).
  - Visible changes wait for Smuck's approval (Gate 1 before visuals, Gate 2 in game), recorded verbatim with dates.
  - Files LF (`.gitattributes eol=lf`); hand-edited `.tscn`: `format=3`, correct `load_steps`, unique ids; commit the uids Godot writes.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 11.2: "Who's Playing?" Picker and New Zombies]; Epic 11 overview; FR78, FR23–FR25, NFR7, NFR9–NFR12, NFR16
- [Source: _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd-epics-overview.md#Epic 11] ("A 'Who's playing?' picker at launch", per-zombie brains, cosmetics, history and tier)
- [Source: _bmad-output/game-architecture.md#State Management], [#Screen Flow], [#Data Persistence], [#Architecture Decision Records] (ADR-2), [#Cosmetics], [#Logging]
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/EXPERIENCE.md], [DESIGN.md], [sketches/name-zombie-11-1.md], [sketches/crypt-closet-4-4.md]
- [Source: scripts/autoloads/player_data.gd], [scripts/autoloads/save_service.gd get_data/get_active_profile], [scripts/core/save_schema.gd profile_defaults/fill_defaults], [scripts/screens/title.gd], [scripts/screens/name_zombie.gd + scenes/screens/name_zombie.tscn], [scripts/screens/main_menu.gd _show_profile/_refresh_unlocks/_wire_row], [scripts/cosmetics/hat_slot.gd], [scripts/cosmetics/pet_slot.gd], [scripts/screens/crypt_closet.gd:267 + crypt_closet.tscn preview], [scripts/ui/closet_item_tile.gd], [scripts/ui/level_card.gd], [scripts/autoloads/audio_manager.gd _apply_saved_settings], [scripts/autoloads/router.gd]
- [Source: tests/unit/test_player_data.gd], [tests/unit/test_title.gd], [tests/unit/test_router.gd], [tests/unit/test_name_zombie.gd], [tests/integration/test_screen_flow.gd], [tests/unit/test_plain_words.gd], [tests/unit/test_readability.gd], [tests/unit/test_trends.gd (_reset_input_handled)]
- [Source: _bmad-output/implementation-artifacts/11-1-name-the-existing-zombie.md] (screen + gates template, review fixes), [deferred-work.md] (7-2: switch must call `_reconcile_tier()`; 11-1: Done off-look relies on focus, no rename, read-only save)

## Art Approval

<!-- Gate 1 (layout sketch + copy + questions) and Gate 2 (in-game captures): Smuck's verbatim answers with dates. -->

**Gate 1, 2026-10-15** (sketch `whos-playing-11-2.md`, asked as four multiple-choice questions; Smuck's selections verbatim):

1. Layout + copy ("Who's playing?", "New zombie", "Back", unnamed card shows "Zombie"): **"Approve as drawn (Recommended)"** (vertical list of 352×52 cards, not the 2×2 grid).
2. First launch: **"Name first, picker later (Recommended)"** (decision 1 kept).
3. Zombie cap: **"4, hide at cap (Recommended)"** (decision 5 kept).
4. Names + look: **"Refuse dupes, plain zombie (Recommended)"** (decision 3 kept; added: in new-zombie mode the name screen shows a bare zombie, no hat and no pet, instead of the last player's).

**Gate 2, 2026-10-15** (captures `screenshots/11-2/picker-one.png`, `picker-full.png` (4 zombies, 12-character names, hats and pets, focus on card 2), `picker-full-gray.png`, `new-zombie-empty.png`, `new-zombie-duplicate.png` (mid-wiggle after "sam" when "Sam" exists), taken from the real title → picker → name screen flow on an isolated user dir; asked with the note that in grayscale the focus ring reads as a lighter double edge, like the Closet tiles): **"Approve"**

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Debug Log References

- Baseline (HEAD 544f6e8, 2026-10-15): 2295 tests / 2294 passing, 1 failing (`test_name_zombie.gd::test_real_letters_type`: "Resumed function '_finish()' after await, but class instance is gone", name_zombie.gd:157), `SCRIPT ERROR` 3, `WARNING` 183, zero `Parse Error|Compile Error|Failed to load script`. The failure is pre-existing and deterministic (also alone in that script): an earlier test leaves `_finish()` awaiting `process_frame` while its recorder keeps `is_transitioning` true; the screen is autofreed and the resume errors inside the next test that awaits frames. Fix planned in Task 6 (release `_leaving` from a `process_frame` connection to a method, which Godot drops when the screen is freed, instead of an `await` loop).
- Real save sha256 before: `2859cbaa61d4fc9a7a4b7b7e8019794def38313e28a8ba71d8b6a0cd347d647a`.

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created
- Task 2: `GameConstants.MAX_ZOMBIES = 4` and `NEW_ZOMBIE_ID_FORMAT = "p%d"` (a test pins `% 1 == SaveSchema.DEFAULT_PROFILE_ID`, so the pattern lives in one place). PlayerData refactored onto `_profiles()`, `_owned_in`, `_owns_in`, `_equipped_id_in`, `_stored_name` (owns / get_owned_items / get_equipped / get_zombie_name now delegate with `_profile()`); full suite unchanged after the refactor (2294/2295, same pre-existing failure). Added `get_profile_ids`, `get_active_profile_id`, `get_profile_summary`, `has_named_zombie`, `can_add_zombie`, `switch_profile`, `create_profile`; class doc updated. 17 new tests in `test_player_data.gd` (127/127 green). Small hardening in the refactor: a non-Array `owned_items` / non-Dictionary `equipped` now reads as empty instead of erroring (fill_defaults already prevents both).
- Task 3: sketch `whos-playing-11-2.md` (frames: 1 zombie, 4 zombies, cap, name screen new-zombie mode). Gate 1 approved 2026-10-15 (see Art Approval); one addition from it: the name screen shows a plain zombie (no hat, no pet) in new-zombie mode.
- Task 4: `ZombieCard` (`scenes/ui/zombie_card.tscn` + `scripts/ui/zombie_card.gd`): 352 × 52 `TileParchment` + `ShadowMd` tile, `player_zombie.tscn` (editable child `HatSlot.follow_equipped = false`) and `pet_slot.tscn` (`follow_equipped = false`) fed by `show_item()`, 16 px ink name (default "Zombie"), `FocusRing`, hover grabs focus, Enter/Space/left click → `picked(id)`. The hat slot is unique inside `player_zombie.tscn`, so it is reached through `%Zombie`. 11 tests.
- Task 5: `Router.Screen.WHOS_PLAYING` appended + path; `whos_playing.tscn/.gd` with the seams, cards placed by code (top-aligned, 4 px gaps, New zombie 12 px under the last card, hidden + `FOCUS_NONE` at the cap), one focus list (arrows + Tab, ends stop), focus on the active card, pick → `switch_profile` → click → `MAIN_MENU` / `NAME_ZOMBIE`, New zombie → `NAME_ZOMBIE {"new_zombie": true}`, Esc taken and ignored, rebuild on `profile_replaced` (skipped while leaving, so the switch doesn't rebuild the card being clicked), disconnect in `_exit_tree`. `_leaving` is released through a `process_frame` connection to a method instead of an `await` loop. 19 tests.
- Task 6: name screen new-zombie mode (payload read; only a real `true` counts): empty field, plain zombie, `%BackButton` (x 144–240, y 272–304, hidden and unfocusable otherwise) paired with Done, Esc/Back → `WHOS_PLAYING`, Done → `create_profile`, refusal/empty → wiggle, `_on_profile_replaced` skipped in that mode, `profile_replaced` now disconnected in `_exit_tree`. Done's off look while Back has focus: new `PixelButton.resting_box` (a `normal` box used while unfocused; the DRAW self-check now compares against it) — `_set_done_ready` sets it, replacing the old manual `normal` refresh. **Pre-existing failure fixed:** `_finish()`'s `await` loop resumed on a freed screen (`test_real_letters_type` failed in the baseline); `_go()` now connects `process_frame` to `_release_when_settled`, which Godot drops when the screen is freed. 12 new name-screen tests + 1 PixelButton test.
- Task 7: `title.gd::next_screen()` → `WHOS_PLAYING` when `has_named_zombie()`, else `NAME_ZOMBIE`; 11.1's "named → MAIN_MENU" test now expects `WHOS_PLAYING` (message says Story 11.2 changed it) + 2 new cases.
- Task 8: `tests/integration/test_profile_switch.gd` proves AC 8 on a live main menu + AudioManager (brain counter, Music/Sound toggles, hat, pet, Horde Rush card state, music bus mute) for `switch_profile` both ways and `create_profile` — no listener code needed changing. `test_screen_flow.gd`: temp PlayerData + recorders for `WHOS_PLAYING`, `FLOW_BUTTONS`, payload test, title-named → picker → pick → `MAIN_MENU` flow. `test_plain_words.gd`: approved "Who's playing?", "New zombie", "Back", "Zombie"; walks the new-zombie name screen and the picker with an unnamed temp zombie. `test_readability.gd`: picker walked full (MAX_ZOMBIES, 12 W names, hats, pets) and in new-zombie mode; `ZombieCard` counted as a clickable; fit/margin/overlap tests for both. `test_no_placeholder_chrome.gd` already walks `scenes/screens/`, `scenes/ui/` and `scripts/ui/` (no change). NFR12 guard extended to `whos_playing.gd`, `zombie_card.gd` and `summary` / `raw_name` / `shown` / `get_shown_name` / `get_profile_summary(`. The 8.6 grep found nothing else that assumed 11.1's title routing.
- Task 9: EXPERIENCE.md (IA rows, flow line, Voice and Tone, `zombie-card` + `name-entry` new-zombie mode, State Patterns), DESIGN.md "Zombie card", game-architecture.md (enum, `WHOS_PLAYING`, `NAME_ZOMBIE` payload, PlayerData mutations, profile persistence).
- Task 10: Gate 2 captures from the real title flow on an isolated user dir (temporary `override.cfg` + `tools/_scratch_11_2/`, both deleted with the dir); approved 2026-10-15. Web smoke (fresh `web-debug` export, browser storage only): existing "zed bo" save → title → picker (1 card) → New zombie → typed "al kid" (single key presses) → Enter → menu with 0 brains, no hat, only Zombie Run open → reload → picker with 2 cards, focus on "al kid" → Up + Enter → menu with 110 brains and Horde Rush open (the first zombie's). Console: no errors, only ids (`new zombie p2`, `switched zombie p1`), no names. Keys typed during the fade-in were dropped (input is ignored during transitions).
- Task 11: final 2363 / 2363 (+68 vs 2295; the baseline's one failure fixed), `SCRIPT ERROR` 3 (unchanged), `WARNING` 190 (+7: exactly the asserted `create_profile` refusals: 2 invalid name, 3 name already used, 2 no room), 0 parse/compile/load errors. Real save sha256 `2859cbaa…d647a` unchanged after every suite run, the capture runs and the web smoke. No PNG/WAV changed outside the new screenshots. Mutation pass (scratch harness, files restored): switch skips `_reconcile_tier`, switch without `profile_replaced`, create allows a duplicate, create ignores the cap, summary shows an unowned hat, title always `NAME_ZOMBIE`, new-zombie empty Done saves the default, Back creates a profile, picker focuses the first card, a name variable in a log call — all 10 turned a test red. Deferred notes in `deferred-work.md`.

### File List

- `scripts/core/game_constants.gd` (modified)
- `scripts/autoloads/player_data.gd` (modified)
- `tests/unit/test_player_data.gd` (modified)
- `_bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/sketches/whos-playing-11-2.md` (new)
- `scripts/ui/zombie_card.gd` (+ `.uid`) (new)
- `scenes/ui/zombie_card.tscn` (new)
- `scripts/screens/whos_playing.gd` (+ `.uid`) (new)
- `scenes/screens/whos_playing.tscn` (new)
- `scripts/autoloads/router.gd` (modified)
- `scripts/screens/title.gd` (modified)
- `scripts/screens/name_zombie.gd` (modified)
- `scenes/screens/name_zombie.tscn` (modified)
- `scripts/ui/pixel_button.gd` (modified)
- `tests/unit/test_zombie_card.gd` (+ `.uid`) (new)
- `tests/unit/test_whos_playing.gd` (+ `.uid`) (new)
- `tests/integration/test_profile_switch.gd` (+ `.uid`) (new)
- `tests/unit/test_router.gd` (modified)
- `tests/unit/test_title.gd` (modified)
- `tests/unit/test_name_zombie.gd` (modified)
- `tests/unit/test_pixel_button.gd` (modified)
- `tests/unit/test_plain_words.gd` (modified)
- `tests/unit/test_readability.gd` (modified)
- `tests/integration/test_screen_flow.gd` (modified)
- `_bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/EXPERIENCE.md` (modified)
- `_bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/DESIGN.md` (modified)
- `_bmad-output/game-architecture.md` (modified)
- `_bmad-output/implementation-artifacts/deferred-work.md` (modified)
- `_bmad-output/implementation-artifacts/screenshots/11-2/picker-one.png`, `picker-full.png`, `picker-full-gray.png`, `new-zombie-empty.png`, `new-zombie-duplicate.png` (new)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified)
- `_bmad-output/implementation-artifacts/11-2-whos-playing-picker-and-new-zombies.md` (modified)

## Change Log

- 2026-10-15: Story 11.2 implemented. PlayerData profile API (list, summary, switch, create; MAX_ZOMBIES = 4, ids `p<N>`), `ZombieCard`, the "Who's playing?" screen (`WHOS_PLAYING`), the name screen's new-zombie mode with Back, title routing to the picker once a zombie is named, `PixelButton.resting_box` for Done's off look, the 11.1 `_finish()` await fix, refresh-on-switch integration test, docs, Gate 1 + Gate 2 approved. 2363 / 2363 tests. Status → review.
