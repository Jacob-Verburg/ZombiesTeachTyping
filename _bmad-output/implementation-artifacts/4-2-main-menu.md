---
baseline_commit: 91b9b3f
---

# Story 4.2: Main Menu

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a kid,
I want a main menu where I can see my zombie and brains, pick a level and toggle sound,
so that I can choose what to do next.

## Acceptance Criteria

1. **Layout follows the mock and the spines (FR26, DESIGN.md Layout "Menu screens" + Components, Main Menu mock section A).** The real menu replaces the placeholder in `scenes/screens/main_menu.tscn`. It keeps the mock's arrangement: logo top-centre, brain counter top-left, the three level cards in a row across the middle, the player's zombie bottom-left with the Crypt Closet button on a wooden signpost beside it, and the Music / Sound / Fullscreen toggles bottom-right. Sizes follow the **real** font, not the mock's narrow stand-in font (see Dev Notes "Layout"). No text overflows its box, every text is ≥ 16 px, and nothing is closer than 16 px to the canvas edge. No separate sketch is needed. Smuck approves a screenshot in this file before the story goes to review (Task 9).
2. **Contents (FR26).** On open the menu shows: the title logo (placeholder sign), the player's zombie (idle), the brain counter with `PlayerData.get_brains()`, 3 level cards (Zombie Run, Horde Rush, Pitchfork Panic, in registry order), a "Crypt Closet" button, and Music, Sound and Fullscreen toggles. Debug-only levels (`test_level`) never get a card.
3. **Level cards are data-driven and one component.** `LevelEntry` gains `available: bool` (and `card_picture: Texture2D`). `level_registry.tres` registers `horde_rush` and `pitchfork_panic` with `available = false` and no scene, and `zombie_run` with `available = true`. A single `LevelCard` scene/script with `enum State { AVAILABLE, COMING_SOON }` draws every card. The menu picks the state from `available` only. Story 6.8 will add `LOCKED` and `NEW` to the same enum without rebuilding the card.
4. **Card behaviour (EXPERIENCE.md level-card).** Enter or click on an *Available* card plays `sfx_ui_click` and calls `Router.go(Router.Screen.RUN, {"level_id": <id>})` exactly once. A *Coming soon* card shows a greyed (stone-tinted) picture with a wood "Coming soon" plank nailed across it. It stays focusable, and Enter or a click only makes it wiggle (no sound, no navigation). The focused card shows a 2 px candy-yellow ring and lifts 2 px.
5. **Navigation (FR25).** Left/Right arrows move between the cards. Down from the cards goes to the bottom row (Closet button, Music, Sound, Fullscreen), Left/Right move along it, and Up goes back to the cards. Focus is always visible and only one control is highlighted: hovering a control with the mouse moves keyboard focus to it. Enter selects. Mouse clicks work on every control. Esc on the main menu does nothing (it is the root screen). On open, focus is on the first *Available* card (Zombie Run).
6. **Crypt Closet button.** Enter or a click goes to `Router.Screen.CRYPT_CLOSET` (still the placeholder until Story 4.4).
7. **Music / Sound toggles (FR46).** Switching one calls `PlayerData.set_setting(&"music_on" | &"sound_on", on)`, mutes or unmutes the matching bus right away, and the toggle shows the new state (icon on, or icon with a diagonal slash when off). The saved settings are **applied to the buses at startup**, before the title screen's first input (today nothing does this, see Dev Notes). After a reload a muted setting is still muted and the menu toggle shows it. The F8 debug reset (`profile_replaced`) re-applies the defaults.
8. **Fullscreen toggle.** Enter or a click calls `WebPlatform.toggle_fullscreen()` synchronously inside that input callback (browser gesture rule). The toggle shows the current state from `WebPlatform.is_fullscreen()` when the menu opens and again whenever the window size changes (the browser's own Esc may have left fullscreen). The state is not saved.
9. **Save export still works.** Ctrl+Shift+E on the real menu still calls `SaveService.offer_export()` with no visible change (`is_export_chord` unchanged).
10. **Storage notice still works (FR27).** When `WebPlatform.is_storage_persistent()` is false, the parchment notice "Progress may not be saved in this browser mode" is shown in a corner. It never takes focus or blocks the mouse, and it does not overlap any control.
11. **Plain words, no timer (NFR9, NFR11).** Every label is plain words (no zombie slang) at ≥ 16 px, and there is no timer or countdown anywhere on the screen.
12. **Debug entries leave the kid's menu (Boundary 7).** The placeholder's debug buttons (Test level, Welcome Gift, Keyboard Test) and its `_is_debug_build()` seam are removed from `main_menu.gd`. The same three jumps are offered from the F3 debug overlay instead (debug builds only), so the test level, the gift placeholder and the keyboard test stay reachable for manual checks.
13. **Tests.** `tests/unit/test_main_menu.gd` is rewritten for the real menu. New `tests/unit/test_level_card.gd`. `test_level_registry.gd`, `test_audio_manager.gd`, `test_debug_overlay.gd` and `tests/integration/test_screen_flow.gd` are updated. All of them pass, along with the full suite.

## Tasks / Subtasks

- [x] **Task 1: Registry data (AC: 2, 3)**
  - [x] 1.1 `scripts/resources/level_entry.gd`: add `@export var available: bool = false` (`##` "False = the card shows Coming soon and cannot be chosen (FR26). Coming soon wins over Locked (FR79)") and `@export var card_picture: Texture2D` (`##` "Card picture; placeholder until Story 5.0's `ui_level_card_<id>.png`. Null = a flat placeholder fill"). Update the header comment (drop "availability ... arrive with Stories 4.2 / 6.8", keep "unlock rules arrive with Story 6.8").
  - [x] 1.2 `scripts/resources/level_registry.gd`: add `func menu_entries(debug_build: bool = OS.is_debug_build()) -> Array[LevelEntry]`. It returns the non-null, non-`debug_only` entries in registry order. `debug_build` is accepted for symmetry, but debug-only levels are **never** returned, even in a debug build (the test level is reached from the debug overlay, AC 12). If you find the parameter pointless, drop it. Don't touch `get_entry` / `get_scene`.
  - [x] 1.3 `data/levels/level_registry.tres`: `zombie_run` → `available = true`, `card_picture` = an `AtlasTexture` sub-resource cropping `assets/sprites/backdrops/sunny_village_green/far.png` (640×192) to the card picture size (see Layout). Add `horde_rush` ("Horde Rush") and `pitchfork_panic` ("Pitchfork Panic"), both `available = false`, `scene` unset, no picture. Keep `test_level` last (`debug_only = true`, `available` may stay false: it is never on the menu). The order is zombie_run, horde_rush, pitchfork_panic, test_level. **RunFrame needs no change:** `get_scene()` already returns null for a scene-less entry, and RunFrame logs and goes back to the menu (NFR16).
- [x] **Task 2: Startup audio settings (AC: 7)**, in `scripts/autoloads/audio_manager.gd`
  - [x] 2.1 Add a `player_data` test seam (`var player_data: Node = null`, typed as the PlayerData script like `debug_overlay.gd` does, defaulting to the `PlayerData` autoload in `_ready()`). AudioManager is autoload #4, so it may use PlayerData (#3) in `_ready()`.
  - [x] 2.2 In `_ready()` call `_apply_saved_settings()`: `set_music_muted(not player_data.get_setting(&"music_on"))` and `set_sfx_muted(not player_data.get_setting(&"sound_on"))`. Connect `player_data.settings_changed` (re-apply the changed key) and `player_data.profile_replaced` (re-apply both). This closes the 2.7 deferral ("buses start unmuted after a reload") and the 1.8 one ("reset_all does not re-apply settings").
  - [x] 2.3 Update the header comment: "Settings (Story 4.2): the Music/Sound buses follow PlayerData's music_on/sound_on, applied at startup and on every settings_changed / profile_replaced. Screens only call PlayerData.set_setting()."
  - [x] 2.4 **Preserve** `RunFrame._on_pause_panel_music_toggled/_sound_toggled`. They still call `AudioManager.set_*_muted` directly and then `player_data.set_setting`. With the live PlayerData the second application is a no-op, and `test_run_frame.gd` injects its own PlayerData that AudioManager doesn't hear, so its direct calls must stay.
- [x] **Task 3: Shared pixel-button look (AC: 1, 5)**, in `data/ui_theme.tres`
  - [x] 3.1 Add a theme type variation `PixelButton` (base type `Button`) with placeholder `StyleBoxFlat`s in palette colours, square corners (no `corner_radius`: it anti-aliases, DESIGN Shapes). `normal`: wood `#8A5228`, 1 px ink border. `hover` = the focus fill (hover moves focus anyway). `focus`: `draw_center = false`, 2 px candy-yellow `#FFD23F` border with `expand_margin` 2 on every side, so the ring sits outside the outline. `pressed`: pumpkin `#F07A1C`. `disabled`: disabled-fill `#CFC6B6`. Font colours: chalk `#F4F1E4` normal, ink `#1E1428` hover/focus/pressed, ink-muted `#4E4757` disabled. Font size 16. The pumpkin-light focus fill: a Godot Button draws `focus` **on top of** `normal`/`hover`, so give the focused fill through the `hover` box plus `mouse_entered → grab_focus`, and swap `normal` to the pumpkin-light box on `focus_entered`/`focus_exited` in a tiny `scripts/ui/pixel_button.gd` (`class_name PixelButton extends Button`, sets `theme_type_variation = &"PixelButton"` in `_init`). This is the 2.9 deferral ("a shared pixel-button widget/theme type should absorb this"). `report_card.gd` and the pause panel stay as they are (Story 5.0 migrates them).
  - [x] 3.2 Additive only: `default_font` and `default_font_size = 16` stay, and `test_ui_theme.gd` still passes. Add a test that the variation exists and its font size is ≥ 16 and on the 8 px grid.
- [x] **Task 4: `LevelCard` widget (AC: 3, 4, 5)**: `scenes/ui/level_card.tscn` + `scripts/ui/level_card.gd`
  - [x] 4.1 `class_name LevelCard extends Control`, `focus_mode = FOCUS_ALL`, `enum State { AVAILABLE, COMING_SOON }` with a `##` note: "Story 6.8 adds LOCKED and NEW; COMING_SOON wins over LOCKED".
  - [x] 4.2 `signal chosen(level_id: StringName)`, emitted only by an AVAILABLE card. `func setup(entry: LevelEntry) -> void` is called **before** `add_child` (architecture Entity Patterns). It stores the id, sets the name-sign text from `display_name` (falling back to `String(id).capitalize()`), sets the picture from `card_picture`, and sets the state: `AVAILABLE if entry.available else COMING_SOON`. Add `get_state()`, `get_level_id()` and `is_wiggling()` for tests.
  - [x] 4.3 Nodes (placeholder chrome, square `StyleBoxFlat`s): `Frame` (wood-dark `#5A3218`, 1 px ink border), `Picture` (`TextureRect`, expand, keep-aspect-covered, clipped. With no texture it shows a flat art-sky `#7EC8E3` fill), `Tint` (`ColorRect` stone `#6F6A80` over the picture, visible only when COMING_SOON), `ComingSoonPlank` (wood `#8A5228` panel, 1 px ink border, "Coming soon" label in chalk, rotated about −8°, visible only when COMING_SOON), `NameSign` (parchment `#F6E7C1`, 1 px ink border, ink label, autowrap, centred; greyed to stone-light `#BDB6C4` when COMING_SOON, as in the mock), `FocusRing` (2 px candy-yellow, outside the frame, visible only while focused) and a 2 px ink drop shadow (it grows to 4 px when focused, as in the mock). Every child has `mouse_filter = IGNORE`, so the card itself gets clicks and hover.
  - [x] 4.4 Input: `_gui_input`. `ui_accept` pressed, or a left mouse button press → `_activate()`, then `accept_event()`. `mouse_entered` → `grab_focus()`. `focus_entered`/`focus_exited` → ring on/off and lift `Frame` (with its children) 2 px up/back. Lift the inner frame, not the card's own position: the menu's `HBoxContainer` owns that.
  - [x] 4.5 `_activate()`: AVAILABLE → `chosen.emit(_level_id)`. COMING_SOON → `_wiggle()`: one node-bound tween, ±2 px on `Frame.position.x`, 0.2 s total, a new wiggle kills the old one, and it ends exactly at rest. No sound (EXPERIENCE level-card `[ASSUMPTION]`). Look values (2 px, 0.2 s) are `const`s with a "look value, not a GDD number" comment.
- [x] **Task 5: Toggle widget (AC: 7, 8)**: `scenes/ui/menu_toggle.tscn` + `scripts/ui/menu_toggle.gd`
  - [x] 5.1 `class_name MenuToggle extends VBoxContainer` (or Control): a 32×32 `PixelButton` (`%IconButton`, `toggle_mode = true`) with a placeholder icon drawn in `_draw()` of a small child `Control` (`%Icon`). Music = a note, Sound = a speaker, Fullscreen = four corner brackets. Plain rects are fine, the art is Story 5.0. When on, the icon is zombie-green-bright `#B8F27C`. When off, it is stone-light `#BDB6C4` plus a 2 px stamp-red `#B02A25` diagonal slash: **the slash, not the colour, carries the state** (NFR8). Below it, the `%Caption` label (chalk, 16 px, centred).
  - [x] 5.2 `enum Kind { MUSIC, SOUND, FULLSCREEN }`, `@export var kind: Kind`, `signal flipped(on: bool)`. `func show_state(on: bool)` sets the visible state **without** emitting (`set_pressed_no_signal` + `queue_redraw`). A user flip (Enter/click on the button) emits `flipped(new_state)` once. Hovering the button grabs focus. The toggle is the focus target (the inner button), so the menu wires its neighbours to `%IconButton`.
- [x] **Task 6: The real main menu (AC: 1, 2, 5, 6, 7, 8, 9, 10, 11)**: rebuild `scenes/screens/main_menu.tscn` and `scripts/screens/main_menu.gd`
  - [x] 6.1 Remove `Box` and its buttons (`PlayButton`, `TestLevelButton`, `ClosetButton`, `GiftButton`, `KeyboardTestButton`), `Heading`, `PayloadLabel` and `_is_debug_build()`. Keep `STORAGE_NOTICE_TEXT`, `%StorageNotice` / `%StorageNoticeLabel` (moved to its new place), `_show_storage_notice(persistent)`, `is_export_chord()` and `_unhandled_input` for the chord.
  - [x] 6.2 New nodes (unique names): `%Background` (night `#2B1D3F`), `%Logo` (parchment sign with the "Zombies Teach Typing" label: a placeholder for 5.0's hand-lettered sprite), `%BrainCounter` (instance `scenes/ui/brain_counter.tscn`), `%Cards` (an `HBoxContainer` the cards are added to in code), `%Zombie` (instance `scenes/characters/player_zombie.tscn`, which plays idle by autoplay), `%PetSpot` (an empty `Marker2D` beside the zombie's feet, for Story 4.3's `PetSlot`), `%ClosetButton` (a `PixelButton` "Crypt Closet" with two wood-dark post `ColorRect`s under it: the signpost), `%MusicToggle`, `%SoundToggle`, `%FullscreenToggle` (`MenuToggle`s), and `%StorageNotice`. Sizes and positions: see Dev Notes "Layout".
  - [x] 6.3 Test seams, following `report_card.gd` / `run_frame.gd`: `var navigate: Callable` (defaults to `Router.go` in `_ready` when invalid), `var player_data: PlayerDataScript = null` (defaults to `PlayerData`), `var toggle_fullscreen: Callable` / `var is_fullscreen: Callable` (default to `WebPlatform.toggle_fullscreen` / `WebPlatform.is_fullscreen`), and `@export var level_registry: LevelRegistry` (set to `level_registry.tres` in the scene, like `report_card.tscn`). Tests assign them before `add_child`.
  - [x] 6.4 `_ready()`:
    1. `Router.take_payload()`: always consume, so a stale payload never leaks. The value is unused today.
    2. `AudioManager.play_music(&"mus_menu")`. A no-op when it is already playing or pending (the title requested it), and correct once Story 5.1 gives levels their own music.
    3. Build the cards: for each `level_registry.menu_entries()`, `LEVEL_CARD_SCENE.instantiate()`, `setup(entry)`, connect `chosen` → `_on_card_chosen`, then `%Cards.add_child`. If the registry is null or there are no entries → `Log.error(&"ui", ...)` and show no cards (NFR16: never crash).
    4. Brain counter: `set_count(player_data.get_brains())`. Connect `brains_changed` → `set_count(total)` and `profile_replaced` → re-read everything (brains and toggles), so F5/F8 on the menu update live.
    5. Toggles: `show_state(player_data.get_setting(&"music_on"))`, the same for `sound_on`, and `show_state(is_fullscreen.call())`. Connect their `flipped` signals. Connect `get_tree().root.size_changed` → `_sync_fullscreen()` (a browser Esc out of fullscreen shows up here).
    6. Focus wiring (6.5), then focus the first AVAILABLE card. If there is none, focus `%ClosetButton`.
    7. Storage notice: unchanged (`_show_storage_notice(WebPlatform.is_storage_persistent())`).
  - [x] 6.5 Focus neighbours, set in code after the cards exist (they are dynamic). In the card row, left/right go to the previous/next card (the ends stop, no wrap) and down from **any** card goes to `%ClosetButton`. In the bottom row, `ClosetButton ↔ Music ↔ Sound ↔ Fullscreen` left/right (ends stop), and up from any bottom control goes to the **first AVAILABLE card**. Use `focus_neighbor_*` with `get_path_to()`, and set `focus_next`/`focus_previous` the same way so Tab is sane. Set the storage notice, logo, brain counter and zombie to `FOCUS_NONE` + `MOUSE_FILTER_IGNORE`.
  - [x] 6.6 Handlers. `_on_card_chosen(id)`: a `_leaving` guard (like `report_card.gd`), `AudioManager.play_sfx(&"sfx_ui_click")`, then `navigate.call(Router.Screen.RUN, {"level_id": id})`. `%ClosetButton.pressed`: the same guard and click, then `navigate.call(Router.Screen.CRYPT_CLOSET, {})`. Music `flipped(on)` → `player_data.set_setting(&"music_on", on)` (AudioManager applies it through `settings_changed`). Sound: the same. Fullscreen `flipped(_on)` → `toggle_fullscreen.call()` **in the same callback**, then `_sync_fullscreen()`. On web the mode change can land a frame later; the `size_changed` sync then corrects the icon. Toggles play `sfx_ui_click` too. Order it so turning Sound **on** clicks audibly, i.e. play after `set_setting`.
  - [x] 6.7 `_unhandled_input`: keep the export chord exactly. Also swallow `ui_cancel` (Esc does nothing on the root menu: `set_input_as_handled()`, no navigation).
  - [x] 6.8 Rewrite the header comment: what the screen shows, the seams, that the storage notice and the Ctrl+Shift+E export are kept (Stories 1.7, 1.8), that hat/pet display arrives in Story 4.3 (`%PetSpot`, the zombie's `%HatSlot`), and that Locked/New card states arrive in Story 6.8.
- [x] **Task 7: Debug jumps move to the overlay (AC: 12)**: `scripts/debug/debug_overlay.gd` + `scenes/debug/debug_overlay.tscn`
  - [x] 7.1 Add a "Jump" row to the overlay panel with three buttons, "Test level", "Welcome gift" and "Keyboard test", with `focus_mode = FOCUS_NONE` (they must never steal the menu's keyboard focus). They are mouse-only and visible only while the overlay is open. Each calls a `navigate` seam (defaults to `Router.go`): RUN `{"level_id": &"test_level"}`, WELCOME_GIFT, KEYBOARD_TEST. They work only while `Router.current_screen == Router.Screen.MAIN_MENU` (seam: a `current_screen` Callable), and are otherwise disabled. Jumping out of a run would skip RunFrame's quit path.
  - [x] 7.2 Extend `HELP_TEXT` only if it still fits. Update the header comment. `test_debug_overlay.gd`: the buttons exist, are not focusable, navigate with the right payloads when on the main menu, and do nothing elsewhere.
- [x] **Task 8: Tests (AC: 13)**
  - [x] 8.1 `tests/unit/test_level_card.gd` (new): `setup` with an available entry gives AVAILABLE, the name text, the plank hidden; an unavailable entry gives COMING_SOON with the tint and plank visible; an empty `display_name` falls back to the capitalized id. `ui_accept` and a left click on AVAILABLE emit `chosen(id)` once. On COMING_SOON they emit nothing and start a wiggle that ends at rest (`await` the tween). Focus shows the ring and lifts the frame 2 px; losing focus undoes it. Every child is `MOUSE_FILTER_IGNORE`. The card's `focus_mode` is `FOCUS_ALL`. Build synthetic `InputEventAction`/`InputEventMouseButton` events and call `_gui_input` directly.
  - [x] 8.2 `tests/unit/test_main_menu.gd` (rewrite). Instance with seams (a recorder `navigate`, a fresh `PlayerData` on a temp-dir `SaveService` as in `test_player_data.gd`, fake fullscreen callables, a code-built `LevelRegistry`) and `PROCESS_MODE_DISABLED` like today. Cover:
    - the shipped registry gives 3 cards in order with states AVAILABLE, COMING_SOON, COMING_SOON, and no `test_level` card;
    - initial focus is on the Zombie Run card;
    - choosing the available card records `[RUN, {"level_id": &"zombie_run"}]` once (a second choice is ignored: the `_leaving` guard); choosing a coming-soon card records nothing;
    - Closet records `[CRYPT_CLOSET, {}]`;
    - the focus neighbours: card → right card, card down → Closet, Closet → Music → Sound → Fullscreen, bottom up → the first available card, and the row ends have no wrap;
    - the brain counter shows the injected wallet and updates on `add_brains` and on `reset_all`;
    - the Music/Sound toggles show the saved setting, and flipping writes `set_setting` (the injected PlayerData reads it back);
    - Fullscreen: flipping calls the fake toggle exactly once, and the icon state follows the fake `is_fullscreen` on `_sync_fullscreen()`;
    - the storage notice: keep the existing 3 tests, adapted (the "keeps focus" assert now targets the Zombie Run card) and add "the notice rect does not intersect any control's rect";
    - keep `test_export_chord_is_ctrl_shift_e_only` unchanged;
    - Esc is swallowed and records no navigation;
    - **text fit**: for every visible `Label`/`Button` in the menu (cards included), `get_theme_font(...).get_string_size(text, ..., font_size).x <= the control's width` (or the label wraps inside its box), and every font size is ≥ 16;
    - every control lies inside the 16 px margin rect `Rect2(16, 16, 608, 328)`. The cards' focus ring and lift may reach the margin but never beyond the canvas.
  - [x] 8.3 `tests/unit/test_level_registry.gd`: `menu_entries()` skips debug-only and null entries and keeps the order. The shipped registry has `zombie_run` (available, picture set), `horde_rush` and `pitchfork_panic` (not available, no scene, display names exact), and `get_scene(&"horde_rush")` is null. Keep the existing tests; `test_shipped_registry` iterates entries and must tolerate scene-less ones (it only instantiates `test_level`).
  - [x] 8.4 `tests/unit/test_audio_manager.gd`: on a fresh AudioManager with an injected PlayerData (temp `SaveService`): saved `music_on = false` → the Music bus is muted after `_ready`; `set_setting(&"sound_on", false)` → the SFX bus is muted; `reset_all()` → both unmuted. **Unmute both buses in `after_each`.** The buses are global `AudioServer` state, and a leaked mute would silence other tests' assumptions.
  - [x] 8.5 `tests/integration/test_screen_flow.gd`: `FLOW_BUTTONS["MAIN_MENU"]` becomes `["%ClosetButton"]`; `test_empty_payload_shows_nothing` drops the main menu (it has no payload label now) or is changed to assert that the menu consumes the payload (`Router.take_payload() == {}` after instancing). `test_every_screen_instantiates` must still pass. The real menu calls `Router`/`AudioManager` only through seams or harmless calls.
  - [x] 8.6 Run `--import` (new `class_name`s: `LevelCard`, `MenuToggle`, `PixelButton`), then the full suite. Record the baseline and final counts.
- [x] **Task 9: Manual check and approval (AC: 1, 7, 8)**
  - [x] 9.1 Desktop run (`preview` or the editor): walk Title → Menu → arrows/Enter/mouse over every control → Zombie Run → report card → Menu. Esc on the menu does nothing. Coming soon cards wiggle.
  - [x] 9.2 Mute Music, quit, relaunch: the title and menu are silent and the toggle shows off. Unmute and check again for Sound.
  - [x] 9.3 Web debug build in Chrome/Edge: Fullscreen on and off by click **and** by Enter. Leave fullscreen with the browser's Esc and check the icon follows. Also check Ctrl+Shift+E downloads the save. In a private window, check the storage notice shows, sits clear of the toggles and reads in plain words.
  - [x] 9.4 Save a 640×360 screenshot to `_bmad-output/implementation-artifacts/screenshots/4-2-main-menu.png`, put it in front of Smuck, and record "Approved by Smuck on <date>" (or the requested changes) in the Completion Notes. Don't move to review without it (AC 1).
- [x] **Task 10: Wrap-up**
  - [x] 10.1 LF line endings on every touched text file. Update `deferred-work.md`: strike the 2.7 "restoring Music/Sound on launch", the 1.8 "reset_all does not re-apply settings", the 1.5 "Keyboard Test button ships in release" and the 2.4 "main menu `_is_debug_build()` seam" items with "Done in 4.2", and the 3.1 "no direct test of menu routing to zombie_run" item.
  - [x] 10.2 Fill in the File List, the Debug Log (counts, mutation pass) and the Change Log.


### Review Findings

- [x] [Review][Patch] Only grab focus on real mouse movement (not on `mouse_entered` from a stationary cursor), so hover never leaves two controls highlighted or steals initial focus (decided: option c) [scripts/ui/pixel_button.gd, scripts/ui/level_card.gd]
- [x] [Review][Dismiss] Task 9.1-9.3 manual checks were only blanket-approved — accepted by Smuck as is
- [x] [Review][Patch] Commit the `project.godot` stretch change with this story and add it to the File List (decided by Smuck) [project.godot, 4-2-main-menu.md File List]
- [x] [Review][Patch] `_leaving` is never reset, so the menu goes dead if `Router.go` ignores the call or the target scene fails to load [scripts/screens/main_menu.gd:_leave]
- [x] [Review][Patch] An `available = true` entry with no scene or empty id gets a live card that bounces the player back from RunFrame; treat it as COMING_SOON and log an error [scripts/screens/main_menu.gd:_build_cards, scripts/ui/level_card.gd:setup]
- [x] [Review][Defer] Fourth non-debug level overflows the `Cards` row (608 px exactly full, no wrap) [scenes/screens/main_menu.tscn] — deferred, only 3 cards in scope
- [x] [Review][Defer] Long single word in a level name overflows the sign (WORD autowrap) [scenes/ui/level_card.tscn] — deferred, shipped names fit
- [x] [Review][Defer] Up from the bottom row is dead when no card is Available [scripts/screens/main_menu.gd:_wire_focus] — deferred, not reachable with the shipped registry
- [x] [Review][Defer] `PixelButton` keeps the focused `normal` override if disabled/hidden while focused; shared by Story 5.0 [scripts/ui/pixel_button.gd:_on_focus_changed] — deferred, no current caller
- [x] [Review][Defer] Debug jump buttons have no re-entry guard, and are disabled when the menu is run directly with F6 [scripts/debug/debug_overlay.gd:_jump] — deferred, debug builds only
- [x] [Review][Defer] Weak tests: slash test asserts only constants, Esc test does not assert `set_input_as_handled`, wall-clock `wait_seconds` wiggle tests [tests/unit/test_menu_toggle.gd, test_main_menu.gd, test_level_card.gd] — deferred, test hardening

## Dev Notes

### What this story is (and isn't)

- **Is:** the real main menu screen with placeholder chrome in palette colours, a reusable `LevelCard` with a state enum, a reusable `MenuToggle`, a shared `PixelButton` theme variation, `available`/`card_picture` on `LevelEntry` plus the two Coming soon registry entries, saved audio settings applied at startup, and the debug jumps moved to the overlay.
- **Isn't:** the hat/pet on the menu zombie (Story 4.3 adds `HatSlot`/`PetSlot`; leave `%PetSpot` empty and don't touch `player_zombie.gd`), the real Closet (4.4), the Welcome Gift flow (4.5), Locked/New card states, the hint sign and the unlock moment (6.8), final art: logo sprite, card art, toggle icons, 9-slice buttons (5.0), button squish/bounce, the card bob and menu music crossfades (5.0/5.1), and migrating the report card or pause panel to `PixelButton` (5.0).

### Layout: the mock's arrangement, the real font's sizes

The mock used a narrow system monospace as a stand-in (its own header says so). The shipped font is **Press Start 2P: 8 px native, so at 16 px every glyph is 16 px wide.** At the mock's sizes the real text would overflow: "Crypt Closet" = 192 px vs a 132 px button, "Fullscreen" = 160 px vs a 100 px label, "Pitchfork Panic" = 240 px vs a 142 px sign, and the 46-character storage notice = 736 px in one line. So keep the **arrangement** and resize. Starting values (logical px, all on the 4 px grid, all checked against 16 px glyphs):

| Element | Rect (x, y, w, h) | Notes |
|---|---|---|
| Brain counter | 16, 16, 80, 28 | existing `brain_counter.tscn` size |
| Logo sign | 144, 16, 352, 40 | "Zombies Teach Typing" 20 × 16 = 320 px at 16 px (placeholder; 5.0's sprite replaces it). Not 24 px: 480 px would collide with the brain counter |
| Card row (`HBoxContainer`, separation 16) | 16, 64, 608, 124 | 3 cards × 192 + 2 × 16 = 608 |
| Each card | 192 × 124 | frame 4 + picture 184 × 72 + 4 + name sign 184 × 40 + 4 (2 lines of 16 px, so "Pitchfork / Panic" wraps; one-line names centre vertically) |
| Coming soon plank | ~176 × 28, centred on the picture, rotated ≈ −8° | "Coming soon" = 176 px; the plank ends may overhang the picture onto the frame (it's nailed on) |
| Zombie (feet origin) | (48, 284) | 32 × 32 at 1× (D16: one sprite scale); `%PetSpot` at (84, 284) |
| Crypt Closet signpost button | 16, 296, 208, 32 | 192 px text + 8 px padding each side; two 4 × 16 posts under it down to y 344 |
| Storage notice | 288, 200, 336, 80 | autowrap, 21 chars per line → 3 lines; bottom-right corner above the toggles; never overlaps them |
| Toggle columns (button 32 × 32 at y 288, caption 16 px at y 324) | Music caption 280–360, Sound 368–448, Fullscreen 464–624 | buttons centred above their captions: x 304, 392, 528 |

These numbers are a starting point; tune them by eye, but the text-fit and margin tests (8.2) are the guard. A focused card's ring (2 px) plus lift (2 px) reaches y 60: that's fine. If anything won't fit, **enlarge the box or wrap. Never shrink text below 16 px** (DESIGN Do/Don't).

### Existing code: current state, what changes, what must be preserved

- `scripts/screens/main_menu.gd` / `scenes/screens/main_menu.tscn` (REPLACE). Today it's a VBox of placeholder buttons, a payload label, a debug-gated Test level button, the storage notice (`%StorageNotice`, `MOUSE_FILTER_IGNORE`, parchment `StyleBoxFlat`) and the Ctrl+Shift+E chord. **Preserve:** `STORAGE_NOTICE_TEXT`, `_show_storage_notice()`, `is_export_chord()` (static, its test is unchanged), and the chord in `_unhandled_input` calling `SaveService.offer_export()`. The scene's uid (`uid://c0j61hcvdcyx0` on the script ext_resource) must keep working: edit in place, don't delete and recreate the `.gd`.
- `scripts/autoloads/audio_manager.gd` (UPDATE, Task 2). Today `set_music_muted`/`set_sfx_muted` exist, but **nothing reads the saved settings at startup**: the 2.7 deferral says so explicitly. Preserve every public method, the throttle, voice gap, ambience, the unlock gate and the `library`/`now_msec`/`ambience_rng` seams.
- `scripts/resources/level_entry.gd`, `level_registry.gd`, `data/levels/level_registry.tres` (UPDATE). RunFrame and the report card read the registry: `get_scene` and `get_entry` must keep their behaviour. The report card heading for `horde_rush` later comes from `display_name`, so set it exactly.
- `scripts/debug/debug_overlay.gd` (UPDATE, Task 7). Preserve the F-keys, `_input` handling and every seam. The new buttons are `FOCUS_NONE`.
- `tests/integration/test_screen_flow.gd` (UPDATE). It references the old menu buttons and `%PayloadLabel`.
- `scripts/ui/brain_counter.gd` (reuse as is). `set_count(n)` already exists; it never takes focus or the mouse.
- `scenes/characters/player_zombie.tscn` (reuse as is). It autoplays `idle`, its origin is at the feet centre, and `%HatSlot` is empty until 4.3. It's a `Node2D` inside a `Control` screen: position it directly.
- `scripts/screens/title.gd`: no change. It already requests `mus_menu` and unlocks on the first input. With Task 2 the buses are muted correctly **before** that unlock, so a muted kid never hears the menu loop start.
- Report card → Menu and Pause → Quit to Menu pass `{}`. The menu ignores the payload (it just consumes it).

### Key design decisions (follow these, Smuck can overrule)

- **Settings live in AudioManager's listener, not in screens.** Screens change state only through `PlayerData` (Boundary 4); audio rules live only in `AudioManager`. So the menu toggles call only `set_setting`, and AudioManager follows the setting. That also fixes the startup restore and the F8 reset in one place.
- **Initial focus is always the first Available card.** EXPERIENCE says "last played card" on return `[ASSUMPTION]` (Open Question 8). In the MVP only Zombie Run is choosable, so they're identical. Epic 6 can add a `focus_level_id` payload.
- **Hover moves focus** (EXPERIENCE pixel-button `[ASSUMPTION]`, Open Question 5): one highlighted control at a time.
- **Esc on the menu does nothing.** It's the root (EXPERIENCE "back one level"; there is no level above). Never go back to the title: it would re-request the audio unlock path.
- **Coming soon: wiggle, no sound** (EXPERIENCE level-card `[ASSUMPTION]`).
- **Debug jumps in the overlay**, not on the kid's menu: it removes the Boundary 7 exception the 2.4 story flagged and the release-build Keyboard Test button the 1.5 review flagged. Mouse-only, `FOCUS_NONE`, main menu only.
- **`PixelButton` is a theme variation plus a 10-line script**, used here by the Closet button and the toggles. Don't restyle the default `Button` type: that would silently change the report card and pause panel, which Story 5.0 owns.
- **The card is a `Control` with `_gui_input`, not a `Button`.** Its look (picture, plank, sign, ring) and the wiggle-instead-of-press for Coming soon don't map onto Button states, and 6.8 adds two more states.

### Godot 4.7 notes

- **Focus visibility:** since Godot 4.5, focus obtained through a mouse click can be **hidden** (the "hide Control focus when given via mouse input" change; see the `gui/common/always_show_focus_state` project setting and `grab_focus(hide_focus := false)`). Our cards draw their own ring on `focus_entered`, which is unaffected. For `PixelButton`'s theme `focus` box, check by eye that the ring shows after hover → `grab_focus()`. If it doesn't, either call `grab_focus()` explicitly (it shows by default) or draw the ring the same way as the card. Don't flip the project setting without saying so in the Completion Notes (`test_project_settings.gd` may pin settings).
- `Control.rotation` works for the plank label (set `pivot_offset` to its centre).
- `HBoxContainer` positions its children, so lift the card's inner `Frame`, never the card node.
- `get_tree().root.size_changed` fires when the window/canvas size changes, which includes a fullscreen exit.
- `StyleBoxFlat` with no corner radius and `anti_aliasing` irrelevant = crisp pixel edges. Never set `corner_radius_*` (DESIGN Shapes).
- Button `pressed` is emitted from Godot's input dispatch, which counts as the input callback for the browser fullscreen rule. The Keyboard Test screen's Fullscreen button (Story 1.5) already proved this path in Chrome/Edge.

### Testing notes

- Suite: `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`. Run `"/c/Program Files/Godot/Godot.exe" --headless --path . --import` first (new `class_name`s).
- Baseline after 4.1: **904** tests, all passing, with the 3 expected `SCRIPT ERROR` lines (`villager.gd`). Confirm it yourself before changing anything.
- Don't call the live `Router.go` from tests (it swaps GUT's scene): use the `navigate` recorder. Don't toggle the real window: use the fullscreen seams. Don't write the developer's real save: inject a temp-dir `SaveService` + `PlayerData` (pattern in `test_player_data.gd` / `test_run_frame.gd`).
- `PROCESS_MODE_DISABLED` instances still run `_ready()` but get no input. Call `_gui_input`/handlers directly with synthetic events.
- `assert_push_error` matches `Log.error` text; keep the menu's error strings stable (`"no level registry"`, `"no menu levels"`).
- Mutation pass (the habit since 2.x): drop the `_leaving` guard, let a COMING_SOON card emit `chosen`, wire "down" to a wrong node, forget `profile_replaced`, call `set_setting` with the inverted value, skip `_apply_saved_settings` in `_ready`, and include debug-only entries in `menu_entries`. Each should be caught. Report honestly any that survive.

### Previous story intelligence

- 4.1: `PlayerData` now has `brains_changed(total, delta)` with a **negative delta on purchase** (the menu uses only `total`), plus `profile_replaced`, `equipment_changed`, `get_flag`. Seams are assigned before `add_child`. Error strings are kept distinctive for `assert_push_error`.
- 2.9: `report_card.gd` is the model for a screen with a `navigate` seam, an `@export level_registry`, a `_leaving` guard and the pixel-button focus swap (`normal` ↔ pumpkin-light on focus). Copy the shape and generalize it into `PixelButton`.
- 2.7: the pause panel's toggles are text buttons ("Music: on"), and RunFrame applies both the bus and the setting. Leave both alone (see Task 2.4).
- 1.7/1.8: the storage notice and Ctrl+Shift+E must survive the rebuild (deferred-work line ~69), and both have tests already.
- Traps from earlier stories: keep files LF (`.gitattributes eol=lf`); write `×`/`–` as UTF-8 (a cp1252 Python write once mangled them); prefer scratchpad scripts over heredocs with apostrophes; `assert()` shows up as `SCRIPT ERROR` in headless GUT, so use `Log` + safe returns.

### Git intelligence

- One commit per story. The tree was clean at `91b9b3f Story 4.1: cosmetic catalogue and brain wallet rules` when this story was created. Suggested message: `Story 4.2: main menu`.
- Recent stories ship code and tests together and record baseline/final counts plus a mutation pass in the Dev Agent Record.

### Project Structure Notes

- New: `scenes/ui/level_card.tscn`, `scripts/ui/level_card.gd`, `scenes/ui/menu_toggle.tscn`, `scripts/ui/menu_toggle.gd`, `scripts/ui/pixel_button.gd`, `tests/unit/test_level_card.gd`. Updated: `scenes/screens/main_menu.tscn`, `scripts/screens/main_menu.gd`, `scripts/autoloads/audio_manager.gd`, `scripts/resources/level_entry.gd`, `scripts/resources/level_registry.gd`, `data/levels/level_registry.tres`, `data/ui_theme.tres`, `scripts/debug/debug_overlay.gd`, `scenes/debug/debug_overlay.tscn`, and the tests listed in Task 8.
- `scenes/ui/` + `scripts/ui/` is the architecture's "reusable widgets" home (`brain_counter`, `pixel_button`). `level_card` and `menu_toggle` aren't named in the architecture tree, but they are reusable widgets (6.8 and the 5.0 pause panel reuse them), so they belong there. The architecture names `pixel_button.tscn`; a script-only `PixelButton` class is enough here, so note the variance.
- Card art later goes in `assets/sprites/ui/menu/` (5.0). Don't create placeholder PNGs: the `AtlasTexture` crop of the existing backdrop is the placeholder.

### Project Context Rules

- There is no `project-context.md`. Rules from the architecture and earlier stories: typed GDScript everywhere (`untyped_declaration = Error`). `%UniqueName` node refs, no `/root/` paths or `get_parent()` chains. Typed past-tense signals connected in code, no event bus. Screens change state only via `PlayerData` and navigate only via `Router` (Boundary 4). Browser APIs only in `WebPlatform` (Boundary 3). Debug code only in `scenes/debug/`/`scripts/debug/` (Boundary 7). Palette colours only (DESIGN Colors). 16 px text floor. Plain words. No timers outside runs. NFR16: a missing registry/texture logs and degrades and never crashes. Use `Log` tags `&"ui"` (menu) and `&"audio"` (settings application).

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 4.2: Main Menu]; FR24, FR25, FR26, FR27, FR46, FR79 (precedence only); NFR7, NFR8, NFR9, NFR11, NFR13, NFR16
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/DESIGN.md] Colors, Typography, Layout & Spacing ("Menu screens"), Elevation & Depth, Shapes, Components (pixel button, level card, toggle, brain counter, storage notice), Do's and Don'ts
- [Source: …/EXPERIENCE.md] Information Architecture (main menu hierarchy), Voice and Tone (menu copy), Component Patterns (pixel-button, level-card, toggle, storage-notice, brain-counter), State Patterns (Main Menu rows), Input Schemes, Game Feel (button/card focus), Level Unlocks (precedence), Open Questions 5 and 8
- [Source: …/mockups/key-main-menu.html] section A (MVP, canonical arrangement; its font is a stand-in)
- [Source: _bmad-output/game-architecture.md] Audio Architecture, Web Platform (fullscreen gesture rule), Architectural Boundaries 3/4/7, Communication Patterns (seams, `setup()` before `add_child`), Directory Structure (`scenes/ui/`, `scripts/ui/`, `level_registry.tres` "card art + available flag")
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] the 1.5, 1.7, 1.8, 2.4, 2.7, 2.9 and 3.1 items named in Task 10
- [Source: scripts/screens/main_menu.gd, report_card.gd, title.gd], [Source: scripts/autoloads/audio_manager.gd, player_data.gd, web_platform.gd, router.gd], [Source: scripts/run/run_frame.gd#_on_pause_panel_music_toggled], [Source: scripts/resources/level_entry.gd, level_registry.gd], [Source: data/ui_theme.tres], [Source: tests/unit/test_main_menu.gd, tests/integration/test_screen_flow.gd]
- Godot focus-visibility change: [Godot docs: GUI navigation](https://docs.godotengine.org/it/4.5/_sources/tutorials/ui/gui_navigation.rst.txt), [engine commit "Hide Control focus when given via mouse input"](https://remotebranch.eu/Stowage/godot/commit/be421bcdd4034fe99e17cd8298bdcad7bef21f24)

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5), 2026-10-05

### Debug Log References

- Baseline before any change: **909** tests, all passing, 3 expected `SCRIPT ERROR` lines (`villager.gd`). The story said 904; 909 is the measured number.
- Final: **976** tests, all passing (+67), the same 3 expected `SCRIPT ERROR` lines. Two clean full runs after the last change.
- One full run failed `test_audio_manager.gd::test_sfx_pool_exhaustion_never_steals_the_voice_player` (calls 4/5). It passed 6/6 in isolation and in the next 2 full runs. It's a pre-existing Dummy-driver timing race (the 2.5 deferral's root cause), unrelated to the bus mutes. Logged in deferred-work.md.
- Mutation pass (11 mutations, each run against its test file and reverted): drop the `_leaving` guard, let COMING_SOON emit `chosen`, wire "down" to Music instead of Closet, forget `profile_replaced` on the menu, invert the Music `set_setting` value, skip `_apply_saved_settings()` in AudioManager `_ready`, include debug-only entries in `menu_entries`, make Sound write `music_on`, drop the `size_changed` fullscreen sync, let the jump buttons work off the menu, make Esc navigate. **All 11 caught.**
- Screenshots were rendered with a throwaway SceneTree script (scratchpad, not committed) that loads the real menu in a window and saves the 640x360 viewport. The first render showed two problems: the Zombie Run crop was pure sky (far.png is transparent above the hills), and the Music/Sound captions ran together. Fixed with crop Rect2(448, 120, 184, 72) (hills and windmill over the card's sky fill) and toggle columns at x 240 / 352 / 464.

### Implementation Plan

- Registry: `available` + `card_picture` on `LevelEntry`; `LevelRegistry.menu_entries()` with **no** `debug_build` parameter (the story allowed dropping it: debug-only entries are never returned).
- Settings: AudioManager gets a `player_data` seam and is the only place a setting becomes a bus mute (`_ready`, `settings_changed`, `profile_replaced`). The menu toggles only call `set_setting`. RunFrame's pause-panel calls are untouched (Task 2.4).
- `PixelButton`: theme variation in `ui_theme.tres` (normal / hover / pressed / hover_pressed / disabled / focus ring / `normal_focused`) + `scripts/ui/pixel_button.gd`. It swaps `normal` to the theme's `normal_focused` box on focus and grabs focus on hover. Additive: `default_font` / `default_font_size` are unchanged.
- `LevelCard`: a `Control` with `_gui_input`, sign styles exported on the scene, and lift/wiggle on the inner `%Frame`. The drop shadow stays put while the frame lifts, so the visible shadow grows from 2 to 4 px.
- `MenuToggle`: VBox with a 32x32 `PixelButton` plus caption. The icon is drawn through `%Icon.draw`. **Variance:** the button is not in `toggle_mode` (a toggled Button draws `pressed` the whole time, which hides the focused fill); the script keeps the state, `show_state()` never emits, and a user press emits `flipped` once.
- Menu: built from the registry in code. Focus neighbours and `focus_next`/`focus_previous` are set with `get_path_to()`; row ends point at themselves. One `_leave()` with the `_leaving` guard plays the click and navigates.
- Debug overlay: a mouse-only `JumpRow` (FOCUS_NONE) whose buttons go through `navigate` / `current_screen` seams, work only on MAIN_MENU and are disabled elsewhere (refreshed with the panel). HELP_TEXT is unchanged (the buttons label themselves).

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created.
- Tasks 1-8 and 10 are implemented and tested. ACs 2-13 are covered by automated tests. AC 1 (layout) is covered by the margin and text-fit tests plus the screenshot.
- **Approved by Smuck on 2026-10-05** (screenshot `_bmad-output/implementation-artifacts/screenshots/4-2-main-menu.png`, Task 9.4). Smuck gave a blanket "i approve" after being asked for the manual checks 9.1-9.3 (desktop walk, mute-and-relaunch, web fullscreen/export/private-window). The individual results of those checks were not reported back, so code review or the 5.4 playtest should confirm them if in doubt.
- Layout variance from the Dev Notes table: the toggle columns are at x 240-320 (Music), 352-432 (Sound) and 464-624 (Fullscreen) instead of 280 / 368 / 464, so the captions are 32 px apart. Everything else follows the table.
- The `gui/common/always_show_focus_state` project setting was **not** changed. A ring shows after hover → `grab_focus()` on the Closet button and the toggles (checked in the rendered screenshots).
- `project.godot` already had an uncommitted change when this story started (the editor dropped the default `window/stretch/aspect` and `scale_mode` keys and reordered `snap_2d_transforms_to_pixel`). This story didn't touch it; Smuck decided in code review to commit it with this story (now in the File List).
- Architecture variance: the architecture names a `pixel_button.tscn`; the script-only `PixelButton` class plus the theme variation is enough here.

### File List

- `scripts/resources/level_entry.gd` (modified)
- `scripts/resources/level_registry.gd` (modified)
- `data/levels/level_registry.tres` (modified)
- `scripts/autoloads/audio_manager.gd` (modified)
- `data/ui_theme.tres` (modified)
- `scripts/ui/pixel_button.gd` (new) + `.uid`
- `scenes/ui/level_card.tscn` (new)
- `scripts/ui/level_card.gd` (new) + `.uid`
- `scenes/ui/menu_toggle.tscn` (new)
- `scripts/ui/menu_toggle.gd` (new) + `.uid`
- `scenes/screens/main_menu.tscn` (rewritten)
- `scripts/screens/main_menu.gd` (rewritten, same uid)
- `scripts/debug/debug_overlay.gd` (modified)
- `scenes/debug/debug_overlay.tscn` (modified)
- `project.godot` (stretch keys; committed with this story per review)
- `tests/unit/test_main_menu.gd` (rewritten)
- `tests/unit/test_level_card.gd` (new) + `.uid`
- `tests/unit/test_menu_toggle.gd` (new) + `.uid`
- `tests/unit/test_pixel_button.gd` (new) + `.uid`
- `tests/unit/test_level_registry.gd` (modified)
- `tests/unit/test_audio_manager.gd` (modified)
- `tests/unit/test_debug_overlay.gd` (modified)
- `tests/unit/test_ui_theme.gd` (modified)
- `tests/integration/test_screen_flow.gd` (modified)
- `_bmad-output/implementation-artifacts/screenshots/4-2-main-menu.png` (new)
- `_bmad-output/implementation-artifacts/deferred-work.md` (modified)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified)
- `_bmad-output/implementation-artifacts/4-2-main-menu.md` (this file)

### Change Log

- 2026-10-05: Story 4.2 implemented: the real main menu (level cards from the registry, Crypt Closet signpost, Music/Sound/Fullscreen toggles, brain counter, zombie), `LevelCard` / `MenuToggle` / `PixelButton` widgets, `available` + `card_picture` registry fields with Horde Rush and Pitchfork Panic as Coming soon, saved audio settings applied at startup and on reset, debug jumps moved to the F3 overlay. Tests 909 → 976. Approved by Smuck; status → review.
