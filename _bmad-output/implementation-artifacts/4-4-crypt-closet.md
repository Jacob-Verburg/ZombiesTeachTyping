---
baseline_commit: 716392cefb1fc27a0777d176d608e140ae866409
---

# Story 4.4: Crypt Closet

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a kid,
I want a closet where I can see every hat and pet, buy the ones I can afford and wear them,
so that my brains turn into something fun.

## Acceptance Criteria

1. **Layout sketch gate (HUMAN GATE).** A layout sketch of the Closet at 640×360 is written to `_bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/sketches/crypt-closet-4-4.md`. It follows `DESIGN.md` (closet-item-tile states and colours, brain counter pill, panel materials, confirm prompt) and `EXPERIENCE.md` (grid navigation, confirm prompt with default focus on Yes, first-visit tutorial). It shows the two 3×3 grids with prices, every tile state, the preview zombie, the brain counter, the confirm prompt, and the tutorial arrow's positions (the arrow itself is built in Story 4.5). It has an element table (x, y, w, h, font size) and lists every deviation the font forces. Every text is 16 px or more. **Smuck approves it in this story file (`### Review Findings

- [x] [Review][Patch] Double-tap Enter buys the item: ignore Yes/No input for ~300 ms after the ConfirmPrompt opens (decided by Smuck, option b). [scripts/ui/confirm_prompt.gd open()]
- [x] [Review][Patch] `_leave()` awaits across the Router freeing the Closet, which logs "Resumed function after await, but class instance is gone" on every successful exit; `is_inside_tree()` is never reached. Confirm in the editor output, then drop the await or release `_leaving` another way. [scripts/screens/crypt_closet.gd:314-326]
- [x] [Review][Patch] Open ConfirmPrompt goes stale when PlayerData changes (profile_replaced, debug F5/F8, brains change): Yes then silently does nothing. Cancel the prompt in those handlers and give non-OK results feedback. [scripts/screens/crypt_closet.gd:_on_confirm_answered]
- [x] [Review][Patch] Focus lost if the pending item's tile is not found after the prompt closes; fall back to `%MenuButton.grab_focus()`. [scripts/screens/crypt_closet.gd:_on_confirm_answered]
- [x] [Review][Patch] Rejected `equip()`/`unequip()` still plays `sfx_ui_click`; check the result. [scripts/screens/crypt_closet.gd:658-663]
- [x] [Review][Patch] Dead `_need` parameter in `ClosetItemTile.show_state` and its callers; `_box` always gets `border = true`. [scripts/ui/closet_item_tile.gd]
- [x] [Review][Patch] `test_every_control_is_inside_the_margin` skips `Shadow` by name, and the shadow reaches x=626 (past the 16 px margin). Fix the shadow or state the exemption. [tests/unit/test_closet_item_tile.gd, scenes/ui/closet_item_tile.tscn]
- [x] [Review][Patch] `test_esc_is_not_handled_here` passes if either half of the `and` is false; make it assert the real behaviour. [tests/unit/test_confirm_prompt.gd]
- [x] [Review][Defer] Task 7.1 only partly done: the hat on the report card was not reached in the live walk, and it ran in a web export, not desktop — deferred, covered by 4.3
- [x] [Review][Defer] Wiggle tween freezes under a tree pause, leaving `Frame.position.x` off rest — deferred, unlikely path
- [x] [Review][Defer] Hand-written UID for `sfx_purchase` in `audio_library.tres` could drift from the `.wav.import` UID — deferred, Godot falls back to the path
- [x] [Review][Defer] Placeholder jingle waveform starts at -1 (masked by the attack envelope) — deferred, placeholder audio

## Sketch Approval`) before the screen is built.** If Smuck changes it, the approved sketch wins over this story's numbers.
2. **Contents (FR39).** The Crypt Closet (reached from the menu's Closet button) replaces the placeholder in `scenes/screens/crypt_closet.tscn`. On open it shows the 3×3 hat grid and the 3×3 pet grid built from `Catalogue.items_for_slot()` in grid order, with prices by row (100 / 200 / 300), the brain counter showing `PlayerData.get_brains()`, a preview zombie, and a way back to the menu for mouse users (a "Menu" button).
3. **Preview zombie (FR39).** The preview is the real `player_zombie.tscn` (idle, 1×, one sprite scale) with a `PetSlot` beside it. Both of its slots use `follow_equipped = false` and `show_item()` (the Story 4.3 preview hook). By default it wears what is equipped. Focusing (or hovering) an **available** tile shows that item on the preview in its slot, and the other slot keeps showing the equipped item. Focusing a Locked tile shows the equipped items (locked items have no art, and a slot must never warn because of the Closet). It updates at once after a buy, a wear or a take-off.
4. **Exactly one state per tile (FR40, FR42).** A `ClosetItemTile` shows exactly one of: **Locked** (`is_available = false`: stone fill, an ink-muted "?" silhouette, "Coming soon"), **Can't afford** (disabled fill, item art, "Need N more" with N = price − brains), **Buy**, **Wear** (owned) or **Wearing** (equipped: the bright tag **with a check mark**, so the shape carries the state, not only the colour). The state comes from one pure function of (item, brains, owned, equipped id), with Locked winning over everything. The words go where the approved sketch puts them (see Dev Notes "The font problem"). In the MVP catalogue only the Pumpkin hat and the Cute ghost can be anything but Locked.
5. **Buy with a confirm prompt (FR41).** Enter or a click on a **Buy** tile opens a modal confirm prompt over the night scrim: a wood panel, a parchment sign asking "Buy the Pumpkin hat for 100 brains?" (the item's `display_name` and price) at 24 px, and Yes / No buttons. Focus starts on **Yes** and is trapped between Yes and No. **Yes** calls `PlayerData.buy_item(item)`. On `OK` it plays `sfx_purchase` (a new placeholder purchase jingle), the brain counter shows the new total, the tile becomes **Wear**, and the save is requested in the same call (`buy_item` does it; the file is written at the end of that frame). **No**, Esc or a click on No closes the prompt and changes nothing. While it is open, the grids and the Menu button can't be reached by keyboard or mouse.
6. **Wear and take off (FR41, FR43).** Enter or a click on a **Wear** tile calls `PlayerData.equip(id)`: it becomes **Wearing**, the tile that was Wearing in the same slot goes back to **Wear**, the preview shows it, and the save is requested. Enter or a click on a **Wearing** tile calls `PlayerData.unequip(slot)` and it goes back to **Wear**. **Can't afford** and **Locked** tiles only wiggle (no sound, no prompt, no change).
7. **Keyboard and mouse (FR25).** Arrow keys move within and between the two grids (hats left, pets right: Right from a hat grid's right column goes to the pet grid's left column on the same row, and back). Up from a top-row tile goes to the Menu button, and the outer edges stop (no wrap). Hovering a control with real mouse motion moves keyboard focus to it, so only one control is highlighted. The focused tile shows a 2 px candy-yellow ring. On open, focus is on the first hat tile. **Esc** goes back to the main menu (`Router.go(MAIN_MENU)`, once, with the `_leaving` guard), except while the confirm prompt is open, where Esc = No.
8. **Live updates.** The Closet listens to `PlayerData.brains_changed`, `inventory_changed`, `equipment_changed` and `profile_replaced` and refreshes the counter, every tile and the preview in the same call (an F5/F8 debug change while the Closet is open shows at once). It disconnects them in `_exit_tree()`.
9. **Tile art.** `hat_pumpkin.tres` and `pet_cute_ghost.tres` get an `icon` (no new PNGs: the hat's 32×32 overlay, and a 32×32 `AtlasTexture` of the ghost's first idle frame). An available item with no `icon` logs one `Log.warn(&"ui", ...)` and shows an empty art box. It never errors or crashes (NFR16).
10. **Plain words, 16 px, no timers (NFR9, NFR11).** Every label is plain words a 6-year-old can read, at 16 px or more (the question at 24 px). Nothing overflows its box, everything is inside the 16 px margin, and there is no timer anywhere on the screen.
11. **Tests.** New `tests/unit/test_closet_item_tile.gd` and `tests/unit/test_crypt_closet.gd`. Updated: `tests/integration/test_screen_flow.gd`, `test_catalogue.gd` (MVP icons), `test_audio_library.gd` (the new cue, if it pins the list). The full suite passes. A manual walk-through screenshot set is shown to Smuck and recorded.

## Tasks / Subtasks

- [x] **Task 1: Layout sketch and approval gate (AC: 1, 10) — HUMAN GATE. Do this first. Build nothing in Tasks 4–6 before the approval.**
  - [x] 1.1 Measure in Godot before sketching (the 2.5 habit): Press Start 2P's advance at 16 and 24 px (expected: equal to the font size, spaces included), and whether it has `?`, `✓` (U+2713) and `–`. If `✓` is missing, the check mark is drawn (`_draw()` polyline or a tiny sprite), not typed.
  - [x] 1.2 Write `sketches/crypt-closet-4-4.md` in the same format as `sketches/hud-band-2-5.md`: a status line, ASCII frames, an element table (x, y, w, h, font size), and a numbered "Deviations" list. **Frames:** (A) the Closet at rest, fresh save + welcome gift (Pumpkin hat and Cute ghost **Buy**, 16 Locked); (B) after the Pumpkin hat is worn (hat **Wearing**, ghost **Can't afford** "Need 100 more", preview wearing the hat); (C) the confirm prompt open over the scrim; (D) the tutorial arrow positions for Story 4.5 (first affordable tile, then Yes, then the tile again as Wear). Start from Dev Notes "Recommended sketch"; it already fits the font.
  - [x] 1.3 **Stop and ask Smuck to approve** (or change) the sketch, showing it in chat. Record the answer verbatim, with the date, in `## Sketch Approval` below and in the sketch's status line. If Smuck changes sizes, words or the tile design, follow the approved sketch and note it in the Completion Notes.
- [x] **Task 2: Data and the purchase jingle (AC: 5, 9)**
  - [x] 2.1 `data/cosmetics/hat_pumpkin.tres`: `icon = ExtResource(<the overlay png>)` (the same `hat_pumpkin.png` ext_resource already there). `data/cosmetics/pet_cute_ghost.tres`: `icon` = a new `AtlasTexture` sub-resource with `atlas` = `pet_cute_ghost_idle.png` and `region = Rect2(0, 0, 32, 32)`. Fix `load_steps`. LF. Keep the ids. Epic 9 items keep no icon (they're Locked and show "?").
  - [x] 2.2 `tools/gen_placeholder_audio.gd`: add `PURCHASE_PATH = "res://assets/audio/sfx/sfx_purchase.wav"` and `_purchase_samples()`: a short happy rising jingle (e.g. C5–E5–G5 at ~0.08 s each, then C6 held ~0.25 s with a fade, peak ≈ 0.4, square or triangle like the click), deterministic (no unseeded noise). Run it headless, then `--import`. **Check `git status`: every existing `.wav` must be byte-identical** (the tool is deterministic; if anything else changed, revert it and only keep the new file). Add the `CREDITS.md` row.
  - [x] 2.3 `data/audio/audio_library.tres`: add an `AudioCue` sub-resource `id = &"sfx_purchase"`, `volume_db = -6.0`, no throttle, and append it to `cues`. Update `test_audio_library.gd` if it pins the cue list.
- [x] **Task 3: `ClosetItemTile` widget (AC: 4, 6, 7, 9)**: `scenes/ui/closet_item_tile.tscn` + `scripts/ui/closet_item_tile.gd` (architecture paths)
  - [x] 3.1 `class_name ClosetItemTile extends Control`, `focus_mode = FOCUS_ALL`. `enum State { LOCKED, CANT_AFFORD, BUY, WEAR, WEARING }`. Header `##` comment in the `level_card.gd` style: what it shows per state, that the closet owns the actions, placeholder chrome until Story 5.0.
  - [x] 3.2 Pure rule, unit-tested on its own: `static func state_for(item: CosmeticItem, brains: int, owned: bool, equipped_id: StringName) -> State`. Order: null item or `not item.is_available` → LOCKED; `owned and equipped_id == item.id` → WEARING; `owned` → WEAR; `brains >= item.price` → BUY; else CANT_AFFORD. Plus `static func need_more(item, brains) -> int` = `maxi(item.price - brains, 0)`.
  - [x] 3.3 API: `func setup(item: CosmeticItem) -> void` (call before `add_child`; stores the item, sets the art from `item.icon`, the price text from `item.price`), `func show_state(state: State, need: int) -> void` (sets the look; never emits), `get_item()`, `get_item_id()`, `get_state()`, `is_wiggling()`. `signal activated(item_id: StringName)`, emitted **only** for BUY, WEAR and WEARING. LOCKED and CANT_AFFORD call `_wiggle()` instead.
  - [x] 3.4 Nodes (placeholder chrome, square `StyleBoxFlat`s in palette colours, no `corner_radius`; DESIGN Shapes): `%Frame` (the box the wiggle moves; fill per state, 1 px ink border), `%Art` (`TextureRect`, 32×32, nearest, the item icon), `%Question` (a `Label` "?" at 32 px in ink-muted, LOCKED only), `%Tag` (a `PanelContainer`/`Panel` strip with `%TagLabel`: price on LOCKED (chalk), CANT_AFFORD (ink-muted, no tag fill) and BUY (pumpkin tag, ink); "Wear" on a zombie-green tag; WEARING: zombie-green-bright tag with a zombie-green-dark check mark), `%FocusRing` (2 px candy-yellow, outside the frame, focused only) and a 2 px ink drop shadow. Exact sizes, and whether a state shows a word or only its price, follow the **approved sketch**. Every child is `MOUSE_FILTER_IGNORE`, so the tile gets the clicks.
  - [x] 3.5 Input, copied from `level_card.gd`: `_gui_input` — real `InputEventMouseMotion` grabs focus when not focused; a left-button press or `ui_accept` → `_activate()` then `accept_event()`. `focus_entered`/`focus_exited` show/hide the ring (guard with `get_node_or_null`, the tile may be mid-free). `_wiggle()`: the same ±2 px / 0.2 s tween on `%Frame.position.x` as `LevelCard` (look values as `const`s with the "look value, not a GDD number" comment), ending exactly at rest, a new one replaces a running one.
  - [x] 3.6 Missing art: an available item with a null `icon` → `Log.warn(&"ui", "closet tile: %s has no icon" % id)` once per tile, empty `%Art`. Never `push_error`, never assert.
- [x] **Task 4: Confirm prompt (AC: 5, 7)** — a child scene of the Closet: `scenes/ui/confirm_prompt.tscn` + `scripts/ui/confirm_prompt.gd` (`class_name ConfirmPrompt extends Control`). (It is reusable; the pause panel stays as it is.)
  - [x] 4.1 Nodes: `%Scrim` (`ColorRect`, full rect, night `#2B1D3F` at **alpha 0.6**, the one sanctioned alpha blend in the UI; `mouse_filter = STOP` so clicks never reach the grids), `%Panel` (wood `#8A5228`, wood-dark frame, 1 px ink border), `%Sign` (parchment, 1 px ink border) holding `%QuestionLabel` (24 px, ink, centred, autowrap), `%YesButton` and `%NoButton` (`PixelButton`, "Yes" / "No"). Sizes from the approved sketch.
  - [x] 4.2 API: `signal answered(yes: bool)`. `func open(question: String) -> void` (sets the text, shows, `%YesButton.grab_focus()`), `func close() -> void`, `func is_open() -> bool`, `func cancel() -> void` (= No: emits `answered(false)` and closes). Yes/No `pressed` → emit `answered(true|false)` then close. Guard against a double answer (only while open).
  - [x] 4.3 Focus trap: Yes ↔ No with left/right, every other neighbour and `focus_next`/`focus_previous` point inside the pair (set in `_ready`, `get_path_to`). While open, the Closet also sets its tiles and Menu button to `FOCUS_NONE` (and back on close), so nothing behind the scrim can be focused even by a stray `grab_focus` (Dev Notes "Modal focus").
  - [x] 4.4 Hidden by default (`visible = false`). It never handles Esc itself: the Closet routes Esc (Task 5.6), so there is one owner of Esc.
- [x] **Task 5: The real Closet screen (AC: 2, 3, 5, 6, 7, 8, 10)**: rebuild `scenes/screens/crypt_closet.tscn` + `scripts/screens/crypt_closet.gd`
  - [x] 5.1 Remove `Box`, `Heading`, `PayloadLabel` and `BackButton`. Keep the root name `CryptCloset` and the script path (the Router's `SCREEN_PATHS` points at the scene). New nodes, positioned by the **approved sketch**: `%Background` (night), `%BrainCounter` (instance `scenes/ui/brain_counter.tscn`), `%Title` (parchment sign, "Crypt Closet" label; placeholder for 5.0's hand-lettered sprite), `%MenuButton` (`PixelButton` "Menu"), `%HatsHeading` / `%PetsHeading` (16 px chalk labels "Hats" / "Pets"), `%HatGrid` / `%PetGrid` (`GridContainer`, `columns = Catalogue.GRID_COLUMNS`, separations from the sketch), `%Mirror` (the preview backing panel), `%PreviewZombie` (instance of `player_zombie.tscn`), `%PreviewPet` (instance of `pet_slot.tscn`), `%InfoSign` + `%InfoLabel` (the focused tile's words, if the sketch keeps the info sign), `%ConfirmPrompt` (instance of Task 4, **last child**, so it draws on top). Every non-interactive node: `FOCUS_NONE` + `MOUSE_FILTER_IGNORE`.
  - [x] 5.2 Seams (tests assign before `add_child`, same pattern as `main_menu.gd`): `@export var catalogue: Catalogue` (set to `data/cosmetics/catalogue.tres` in the scene; architecture Data Patterns example is exactly this), `var navigate: Callable` (→ `Router.go`), `var is_transitioning: Callable` (→ `Router.is_transitioning`), `var player_data: PlayerDataScript = null` (→ `PlayerData`), `var play_sfx: Callable` (→ `AudioManager.play_sfx`), so tests can assert the jingle. Use `const PlayerDataScript: GDScript = preload("res://scripts/autoloads/player_data.gd")`.
  - [x] 5.3 Preview slots: set `follow_equipped = false` **in `crypt_closet.tscn`**, not in code. Children run `_ready()` before the Closet does, so a code assignment would come too late (see Dev Notes "Preview slots and `_ready` order"). That's an editable-child override on `PreviewZombie/Body/HatSlot` plus the property on the `PreviewPet` instance. Then they never connect to the live `PlayerData`, and the Closet drives them only with `show_item()`.
  - [x] 5.4 `_ready()`: default the seams; `Router.take_payload()` (consume; Story 4.5 will read a tutorial flag from it); null/invalid catalogue → `Log.error(&"ui", ...)`, build no tiles, focus `%MenuButton` (NFR16); build the tiles (`items_for_slot(HAT)` into `%HatGrid`, `items_for_slot(PET)` into `%PetGrid`, `setup(item)` then `add_child`, connect `activated` → `_on_tile_activated`, `focus_entered` → `_on_tile_focused.bind(tile)`); connect the four `PlayerData` signals; `_refresh()`; wire focus (5.5); `%MenuButton.pressed` → `_leave()`; `%ConfirmPrompt.answered` → `_on_confirm_answered`; focus hat tile 0 (or `%MenuButton` if there are no tiles).
  - [x] 5.5 Focus wiring in code after the tiles exist (`focus_neighbor_*` via `get_path_to`, like `main_menu.gd::_wire_row`). Hat grid index `i` = row `i / 3`, col `i % 3`. Inside a grid: left/right/up/down by row and column. Hat col 2 → Right → pet col 0, same row. Pet col 0 → Left → hat col 2, same row. Hat col 0 Left, pet col 2 Right and row-2 Down stop (point at themselves). Row-0 Up → `%MenuButton`. `%MenuButton` Down → the tile under it in the sketch (recommended: pet tile index 2); its other sides stop. Tab order: hats 0–8, pets 0–8, Menu, wrapping.
  - [x] 5.6 `_unhandled_input`: `ui_cancel` pressed → `set_input_as_handled()`; then if `%ConfirmPrompt.is_open()` → `%ConfirmPrompt.cancel()`, else `_leave()`. Nothing else is handled here (Enter on a tile goes through the tile's `_gui_input`; Enter on a button through the Button).
  - [x] 5.7 `_refresh()`: brains = `player_data.get_brains()`; `%BrainCounter.set_count(brains)`; for every tile `show_state(ClosetItemTile.state_for(item, brains, player_data.owns(id), player_data.get_equipped(item.slot_key())), ClosetItemTile.need_more(item, brains))`; then `_show_preview()` and the info sign for the focused tile. Called on open and from every `PlayerData` signal handler (one refresh per signal is fine; `buy_item` emits two signals, so refresh twice is cheap).
  - [x] 5.8 `_on_tile_activated(item_id)`: re-read the state (never trust a stale tile). BUY → remember the item, `%ConfirmPrompt.open("Buy the %s for %d brains?" % [display_name, price])`, disable the background focus (Task 4.3). WEAR → `player_data.equip(item_id)` + `play_sfx.call(&"sfx_ui_click")`. WEARING → `player_data.unequip(item.slot_key())` + click. The refresh comes from the signals.
  - [x] 5.9 `_on_confirm_answered(yes)`: restore background focus, put focus back on the item's tile. If yes: `match player_data.buy_item(item)`: `OK` → `play_sfx.call(&"sfx_purchase")` (and `Log.info` is already in `buy_item`); `NOT_ENOUGH_BRAINS` / `ALREADY_OWNED` / `UNAVAILABLE` → `Log.warn(&"economy", "closet: unexpected buy result %s for %s" % ...)` and `_refresh()` (the architecture example). No → nothing.
  - [x] 5.10 `_show_preview()`: hat shown = the focused tile's item if it is an available hat, else `catalogue.get_item(player_data.get_equipped(&"hat"))` (null = empty). Pet the same. Call `%PreviewZombie.get_node("%HatSlot").show_item(hat)` and `%PreviewPet.show_item(pet)`. Never pass a Locked item (they have no overlay/frames and the slots would warn).
  - [x] 5.11 `_leave()`: the `main_menu.gd` pattern exactly (`_leaving` guard, `is_transitioning` check, click SFX, `navigate.call(Router.Screen.MAIN_MENU, {})`, release the guard if the transition ends with this screen still alive). `_exit_tree()`: disconnect the four `PlayerData` signals if connected.
  - [x] 5.12 Public helpers for tests and Story 4.5's tutorial arrow: `get_tiles() -> Array[ClosetItemTile]`, `get_tile(item_id) -> ClosetItemTile`, `get_confirm_prompt() -> ConfirmPrompt`. Rewrite the header comment (what it shows, the seams, Esc/prompt rules, that the tutorial arrow is Story 4.5 and the final art/juice is 5.0/5.1).
- [x] **Task 6: Tests (AC: 11)**
  - [x] 6.1 `tests/unit/test_closet_item_tile.gd` (new): `state_for` truth table — unavailable (even if owned and equipped) → LOCKED; owned + equipped → WEARING; owned not equipped → WEAR; brains == price → BUY (boundary); price − 1 → CANT_AFFORD; null item → LOCKED. `need_more` (40 short → 40; never negative). `setup` + each `show_state`: exactly one state look visible (the "?" only on LOCKED, the check only on WEARING, the tag colour per state, the price/word text per the sketch). `ui_accept` and a left click on BUY/WEAR/WEARING emit `activated(id)` once; on LOCKED/CANT_AFFORD they emit nothing and start a wiggle that ends at rest. Focus shows the ring; mouse motion grabs focus; every child ignores the mouse; `focus_mode == FOCUS_ALL`. A null icon on an available item warns once (`assert_push_warning`) and doesn't error. Disabled instances + direct `_gui_input` calls, like `test_level_card.gd`.
  - [x] 6.2 `tests/unit/test_crypt_closet.gd` (new). Fresh `PlayerData` on a temp-dir `SaveService` (copy `test_main_menu.gd::_make_player_data`), recorder seams for `navigate`, `is_transitioning` and `play_sfx`, `PROCESS_MODE_DISABLED`, shipped catalogue unless a test injects one. Cover:
    - 9 hat tiles and 9 pet tiles in catalogue order; prices by row 100/200/300; on a fresh save with 0 brains: Pumpkin hat and Cute ghost CANT_AFFORD (need 100), the 16 others LOCKED; the counter shows 0;
    - with 100 brains: both BUY; activating the hat opens the prompt with "Buy the Pumpkin hat for 100 brains?", Yes focused, tiles and Menu not focusable while open;
    - Yes → brains 0, owns `hat_pumpkin`, tile WEAR, ghost CANT_AFFORD "need 100", `play_sfx` got `&"sfx_purchase"` once, the counter shows 0, prompt closed, focus back on the tile, and the save was requested (use the counting `SaveService` from `test_player_data.gd`);
    - No, `cancel()` and Esc-while-open change nothing (brains, owned, no jingle) and do **not** navigate;
    - WEAR → WEARING + `get_equipped(&"hat") == &"hat_pumpkin"` + preview hat slot shows it; WEARING → WEAR + empty; equipping a second owned hat (inject a code-built catalogue with two available hats) flips the first back to WEAR;
    - LOCKED and CANT_AFFORD activation: no prompt, no change, the tile wiggles;
    - preview: focusing an available hat tile shows it on the preview while the pet shows the equipped pet; focusing a LOCKED tile shows the equipped items and logs **no** warning;
    - live updates: `add_brains(100)` with the Closet open flips CANT_AFFORD → BUY and updates the counter; `reset_all()` re-reads everything;
    - focus neighbours: inside a grid, hat col 2 ↔ pet col 0 per row, row-0 Up → Menu, Menu Down → the sketch's tile, the outer edges stop; initial focus on hat tile 0;
    - Esc (prompt closed) records `[MAIN_MENU, {}]` once (the guard holds a second Esc); the Menu button records the same;
    - the preview slots have `follow_equipped == false`, and equipping through `PlayerData` without the Closet's refresh doesn't move them (they don't listen);
    - `_exit_tree` disconnects (free the Closet, then `add_brains`: no error, and `brains_changed.get_connections()` no longer has it);
    - **text fit and margins** (copy `test_main_menu.gd`'s helpers): every visible `Label`/`Button` text fits its box or wraps inside it, every font size ≥ 16, every control inside `Rect2(16, 16, 608, 328)` (the full-rect scrim and background excepted), the prompt's question fits at 24 px for every **shipped** item name, and the rects match the approved sketch's table (one assert per element);
    - a null catalogue logs an error, builds no tiles and focuses Menu.
  - [x] 6.3 `tests/integration/test_screen_flow.gd`: `FLOW_BUTTONS["CRYPT_CLOSET"]` becomes `["%MenuButton"]`. `test_every_screen_instantiates` must still pass. **Careful:** it instances the Closet with the live autoloads, so the Closet must not write anything on open (it doesn't: only reads). Add `test_closet_consumes_the_payload` like the main menu's.
  - [x] 6.4 `test_catalogue.gd`: the Story 4.3 test that asserts every icon is null (line ~255, "icon is Story 4.4") becomes: the two MVP items have an icon (32×32), the 16 unavailable ones still have none. Keep line ~106 (neutral defaults on `CosmeticItem.new()`).
  - [x] 6.5 Run `"/c/Program Files/Godot/Godot.exe" --headless --path . --import` first (new `class_name`s: `ClosetItemTile`, `ConfirmPrompt`; the new `.wav`), then the full suite. Record the baseline (measure it at the story's start; it was 1050 after 4.3's dev run, and its review patches may have added a few) and the final counts.
  - [x] 6.6 Mutation pass (the habit since 2.x), each must be caught: LOCKED not winning over owned; `>=` → `>` in BUY; WEARING without the `equipped_id` check; Yes not calling `buy_item`; jingle on No; Esc navigating while the prompt is open; prompt not disabling background focus; preview showing a Locked item; forgetting the `inventory_changed` (or `brains_changed`) connection; skipping the `_exit_tree` disconnect; Right from hat col 2 not crossing to the pets. Report honestly any that survive.
- [x] **Task 7: Manual checks and approval (AC: 1, 5, 6, 7, 10)**
  - [x] 7.1 Desktop run. Back up the real save first (as 4.3 did), or use the F8 reset and restore after. With the debug overlay's F5 (+brains), walk: Menu → Closet (focus on the Pumpkin hat) → arrows through both grids and onto Menu → Can't afford / Locked wiggle → F5 to 100 → Buy → prompt (Yes focused, arrows stay inside, clicks on the scrim do nothing) → No → Buy → Yes (jingle, counter 0, tile Wear) → Wear (preview hat, tile Wearing, check mark) → Enter again (take off) → Wear again → Esc → menu zombie wears the hat. Then play one Zombie Run and confirm the hat in play, on the report card and on the menu. Mouse-only pass too.
  - [x] 7.2 Screenshots to `_bmad-output/implementation-artifacts/screenshots/`: `4-4-closet-fresh.png` (frame A), `4-4-closet-confirm.png` (C), `4-4-closet-wearing.png` (B). Put them in front of Smuck next to the approved sketch, and record "Approved by Smuck on <date>" (or the changes) in `## Sketch Approval`. Don't move to review without it.
  - [x] 7.3 Restore the real save if it was backed up, and say so in the Debug Log (what changed in it, if anything).
- [x] **Task 8: Wrap-up**
  - [x] 8.1 LF line endings on every touched text file (`.gitattributes eol=lf`).
  - [x] 8.2 `deferred-work.md`: strike, with "Done in 4.4: …", the 1.3 item's "Esc on Crypt Closet" part (now tested), and add a note to the 4.3 item about the fit check's `E` key ("the Closet now buys and wears for real; the debug key stays for art checks"). Add "Deferred from: dev of story 4-4" with at least: final tile/prompt/panel art and the counter tick-down + squish (5.0/5.1), the tutorial arrow (4.5), the Closet music (5.1), any sketch deviation Smuck approved, and a reminder for Story 5.2's grayscale review of the five tile states.
  - [x] 8.3 Fill in the File List, Debug Log (counts, mutation pass, measured font facts) and Change Log. Suggested commit: `Story 4.4: crypt closet`.

## Sketch Approval

<!-- Task 1.3: Smuck's verbatim approval (or requested changes) of sketches/crypt-closet-4-4.md, with the date. Task 7.2: the screenshots' approval. -->

- **Sketch (Task 1.3), 2026-10-06:** Smuck: "Approve as drawn". The sketch's six deviations (words on the info sign, price on the Buy tag, drawn check mark, 68 px tiles, no name on Locked, focus ring on the tile's edge) are approved.
- **Screenshots (Task 7.2), 2026-10-06:** `4-4-closet-fresh.png` (frame A), `4-4-closet-confirm.png` (C) and `4-4-closet-wearing.png` (B) shown next to the approved sketch. Smuck: "Approve". Approved by Smuck on 2026-10-06.

## Dev Notes

### What this story is (and isn't)

- **Is:** the real Crypt Closet screen with placeholder chrome in palette colours; a reusable `ClosetItemTile` with a state enum and a pure state rule; a reusable `ConfirmPrompt` (modal over the night scrim); the preview zombie driven by the Story 4.3 `show_item()` hook; tile icons for the two MVP items; a placeholder purchase jingle; the approved layout sketch.
- **Isn't:** the tutorial arrow and the `tutorial_seen` flag (Story 4.5; this story only plans the arrow's positions in the sketch and exposes `get_tile()` / `get_confirm_prompt()`), the Welcome Gift card (4.5), any change to `PlayerData` or the save (every method needed exists since 4.1), final art (9-slice panels, tile art, hand-lettered "Crypt Closet" sign) and button squish / counter tick-down (5.0 / 5.1), Closet music (5.1), the 16 other items' art (Epic 9), selling back (never, FR41), a "Play with it!" button after Wear (post-MVP idea, Story 4.5 design note).

### The font problem (read before sketching)

The shipped font is Press Start 2P: at 16 px **every character is 16 px wide** (measured in 2.5: advance = font size, spaces included). DESIGN.md's tile is a 48 px square with words written under it, drawn before the font was chosen (D11, `[ASSUMPTION]`). The tile words don't fit any tile that leaves room for two 3×3 grids across 608 px:

| Text | Chars | Width at 16 px |
|---|---|---|
| "Coming soon" | 11 | 176 |
| "Need 100 more" (worst case: 300 price, 0 brains is "Need 300 more") | 13 | 208 |
| "Wearing" | 7 | 112 |
| "Wear" / "Buy" / "100" | 4 / 3 / 3 | 64 / 48 / 48 |

Two grids of 3 tiles plus the preview between them leave about 64–72 px per tile. So the sketch has to choose, and that's why AC 1 is a gate. The recommendation below keeps **at most 4 characters on a tile** and moves the long words to one info sign for the focused tile. That changes FR40's "label on the tile" into "label for the focused tile", which **only Smuck can approve** (listed as a deviation in the sketch).

### Recommended sketch (start here; Smuck decides)

Canvas 640×360, 16 px margin, 4 px grid. Hats left, pets right, the preview between them, so the zombie trying things on is the centre of the screen.

```
x: 16           228   236              404  412           624
y=16 ┌(B) 100 ┐        ┌── Crypt Closet ──┐          [ Menu ] ┐  brain counter / title sign 24 px / Menu button
y=56      Hats                                    Pets            16 px chalk headings, centred over each grid
y=76 ┌────┐┌────┐┌────┐  ┌──────────────┐  ┌────┐┌────┐┌────┐
     │ 🎃 ││ ?  ││ ?  │  │    mirror    │  │ 👻 ││ ?  ││ ?  │  tiles 68×68, 4 px gaps
     │100 ││100 ││100 │  │              │  │100 ││100 ││100 │
     └────┘└────┘└────┘  │   zombie +   │  └────┘└────┘└────┘
     ┌────┐┌────┐┌────┐  │     pet      │  ┌────┐┌────┐┌────┐
     │ ?  ││ ?  ││ ?  │  └──────────────┘  │ ?  ││ ?  ││ ?  │
     │200 ││200 ││200 │                    │200 ││200 ││200 │
     └────┘└────┘└────┘                    └────┘└────┘└────┘
     ┌────┐┌────┐┌────┐                    ┌────┐┌────┐┌────┐
     │ ?  ││ ?  ││ ?  │                    │ ?  ││ ?  ││ ?  │
     │300 ││300 ││300 │                    │300 ││300 ││300 │
y=288└────┘└────┘└────┘                    └────┘└────┘└────┘
y=296┌─────────────────────── info sign (parchment) ────────────────────────┐
     │ Pumpkin hat                                                         │  line 1: name (Locked: "Coming soon")
     │ Buy                                                                 │  line 2: the state word(s)
y=344└─────────────────────────────────────────────────────────────────────┘
```

| Element | x | y | w | h | Font | Notes |
|---|---|---|---|---|---|---|
| Brain counter | 16 | 16 | 80 | 28 | 16 | existing `brain_counter.tscn` (same place as the menu) |
| Title sign "Crypt Closet" | 168 | 16 | 304 | 32 | 24 | 12 × 24 = 288 + 8 px pad each side |
| Menu button | 544 | 16 | 80 | 32 | 16 | "Menu" 64 px + 8 px pad; `PixelButton` |
| "Hats" / "Pets" headings | centred over each grid | 56 | 64 | 16 | 16 | chalk on night |
| Hat grid | 16 | 76 | 212 | 212 | – | 3 × 68 + 2 × 4 |
| Pet grid | 412 | 76 | 212 | 212 | – | |
| Tile | – | – | 68 | 68 | 16 | art 32×32 at (18, 6); tag strip (2, 46, 64, 20); 4 chars max |
| Mirror (preview backing, parchment-shade or wood frame) | 244 | 76 | 152 | 120 | – | the zombie stands on its bottom edge |
| Preview zombie (feet origin) | 302 | 188 | 32 | 32 | – | 1×, feet near the mirror's bottom edge (y 196); with the hat the top is about y 146 |
| Preview pet (feet origin) | 338 | 188 | 32 | 32 | – | 36 px right of the zombie, like the menu (48 → 84); the pair is centred on x 320 |
| Info sign (parchment, ink, autowrap) | 16 | 296 | 608 | 48 | 16 | 2 lines × 20 px pitch + 4 px pad; 37 chars per line |
| Confirm: scrim | 0 | 0 | 640 | 360 | – | night at 60% alpha |
| Confirm: wood panel | 56 | 96 | 528 | 168 | – | |
| Confirm: parchment sign + question | 64 | 104 | 512 | 100 | 24 | 20 chars per line: "Buy the Pumpkin hat" / "for 100 brains?"; 3 lines fit (Epic 9 names) |
| Confirm: Yes / No | 208 / 336 | 216 | 96 | 32 | 16 | side by side, Yes focused |
| Tutorial arrow (4.5) | above the target tile, centred, bottom 4 px above it | – | 24 | 20 | – | row 1 tiles' arrow sits in the headings row, clear of the centred heading; on the prompt: left of Yes, pointing right, x 176–200 |

Tile states in this recommendation (each distinct by **shape**, so Story 5.2's grayscale check passes):

| State | Fill | Art area | Tag strip | Info sign line 2 |
|---|---|---|---|---|
| Locked | stone | "?" 32 px, ink-muted | price, chalk, no tag box | (line 1 is "Coming soon", no name: a locked item stays a mystery) |
| Can't afford | disabled-fill | item icon | price, ink-muted, no tag box | "Need N more" |
| Buy | parchment | item icon | **pumpkin tag box** with the price, ink | "Buy" |
| Wear | parchment | item icon | zombie-green tag box "Wear", ink | "Wear" |
| Wearing | parchment | item icon | zombie-green-bright tag box with a zombie-green-dark **check mark**, no word | "Wearing" |

Showing the price on every not-owned tile (Locked included) is what gives FR39's "prices by row". Deviations to list in the sketch for Smuck: (1) the long words ("Coming soon", "Need N more", "Wearing") live on the info sign for the focused tile, not on every tile; (2) Buy tiles show the price on the pumpkin tag instead of the word "Buy"; (3) Wearing is a check mark on the tile, with the word on the sign; (4) tiles are 68 px, not 48 px; (5) locked items show no name. Smuck may prefer something else. Follow the approved sketch.

### Preview slots and `_ready` order

- Godot readies children before the parent, so the preview `HatSlot`/`PetSlot` run `_ready()` before `crypt_closet.gd` can touch them. If `follow_equipped` were still `true` there, they would connect to the **live** `PlayerData` autoload and show the developer's real equipped items in tests. So set `follow_equipped = false` **in `crypt_closet.tscn`** (an editable-children override on `PreviewZombie/Body/HatSlot`, plus the property on the `PreviewPet` instance). Check it in the `.tscn` text. The test asserts it.
- `show_item(null)` empties a slot; a non-hat item on a `HatSlot` shows nothing. `HatSlot.show_item()` warns once for an available hat without `overlay` (never the case for shipped items). Never call it with a Locked item.
- The preview zombie plays `idle` by autoplay. Nothing drives hops or dances here.

### Modal focus

- `ConfirmPrompt`'s scrim stops the mouse, but keyboard focus can still be grabbed by code, and Godot's focus search ignores `visible` of siblings drawn underneath. So while the prompt is open, set every tile and `%MenuButton` to `FOCUS_NONE` (remember and restore their `FOCUS_ALL` on close), and make Yes/No's neighbours point only at each other. Tiles' `_gui_input` never runs while the scrim covers them (`MOUSE_FILTER_STOP`).
- After the answer, give focus back to the tile that opened the prompt (so the tutorial's "Wear" step in 4.5 is one Enter away).
- One owner of Esc: the Closet's `_unhandled_input`. Godot sends `_unhandled_input` to nodes in reverse tree order, so a handler on the prompt would run before the Closet's. Keeping it in one place avoids "Esc closed the prompt **and** left the Closet".

### Existing code: current state, what changes, what must be preserved

- `scenes/screens/crypt_closet.tscn` / `scripts/screens/crypt_closet.gd` (REPLACE). Today: a placeholder (heading, payload label, `%BackButton`, Esc → menu). Keep the file paths and the root node name. `test_screen_flow.gd` instances it with the live autoloads.
- `scripts/autoloads/player_data.gd` (READ ONLY). `buy_item(item) -> PurchaseResult` checks the catalogue's own record, deducts, appends to owned, emits `brains_changed(total, -price)` **then** `inventory_changed(id)`, requests one save and logs INFO. `equip(id) -> bool` (owned + available only; same id = no signal), `unequip(slot)` (emits `equipment_changed(slot, &"")` only when something was visible), `owns(id)`, `get_equipped(slot)` (filters junk/not owned/unavailable), `get_brains()`. **Don't add methods.** The save is written by `SaveService` at the end of the frame of the request ("immediately" for FR41; the architecture's save points).
- `scripts/ui/level_card.gd` (READ, copy its patterns): state enum + `setup()` before `add_child`, `_gui_input` (real mouse motion grabs focus, `ui_accept` or left click → `_activate()` + `accept_event()`), ring + inner-frame wiggle, the `get_node_or_null` guard in `_show_focus`. Don't change it.
- `scripts/ui/pixel_button.gd` + the `PixelButton` theme variation in `data/ui_theme.tres` (REUSE for Menu, Yes, No). It already moves focus on real mouse motion and shows the pumpkin-light focused fill.
- `scenes/ui/brain_counter.tscn` / `brain_counter.gd` (REUSE). `set_count(n)`; never focusable; placeholder chrome.
- `scenes/characters/player_zombie.tscn` (REUSE as the preview; no change). `Body` at (-16, -31), `%HatSlot` under `Body` with `anchors` and `sprite` set.
- `scenes/cosmetics/pet_slot.tscn`, `hat_slot.tscn` (REUSE; no change). `follow_equipped`, `show_item`, `get_item_id`, `is_showing`, `player_data` seam.
- `scripts/screens/main_menu.gd` (READ, no change). The Closet button already routes to `CRYPT_CLOSET` with `{}`; the `_leave()` guard, seams and focus-wiring helpers are the model. When the Closet returns, the menu's slots re-read on their own.
- `data/cosmetics/catalogue.tres` (READ). 18 items, each slot's items in grid order, validated by `PlayerData._ready()`. `Catalogue.GRID_COLUMNS = 3`, `GRID_SIZE = 9`.
- `tools/gen_placeholder_audio.gd` (UPDATE, additive). Deterministic generator; re-running must not change the existing WAVs.
- `scripts/debug/hat_fit_check.gd` (no change). Its `E` key stays for art checks.

### Key design decisions (follow these; Smuck can overrule)

- **One pure state rule** (`ClosetItemTile.state_for`), so FR40's "exactly one state" is a unit test, not a UI accident. Locked wins over owned: an item made unavailable after purchase (a hand-edited save, a pulled item) shows Locked and can't be worn, which matches `get_equipped()` and `equip()`.
- **Tiles don't touch `PlayerData`.** The tile shows what the Closet tells it and emits `activated`; the Closet (a screen) is the only one that calls `buy_item` / `equip` / `unequip` (Boundary 4: screens change state only through `PlayerData` methods).
- **Refresh from signals, not after calls.** After Yes/Wear/Take off, the tiles and the counter update because `PlayerData` emitted, so an F5/F8 debug change or a future second screen stays in sync for free (AC 8).
- **The catalogue is an `@export` on the screen** (architecture Data Patterns example), not `PlayerData.catalogue` (a test seam).
- **No sound on the wiggle** (same as the Coming soon card, EXPERIENCE `[ASSUMPTION]`). Click on Wear/Take off/Menu; the jingle only on a successful buy.
- **Hover moves focus only on real mouse motion** (the 4.2 review fix), so a cursor resting where the Closet appears never steals the initial focus.
- **Default focus on Yes** (EXPERIENCE confirm-prompt `[ASSUMPTION]`, Open Question 6: fast tutorial vs mash safety). Kept as specified; the 1.0 s report-card mash guard doesn't apply here because the prompt only opens from a deliberate Enter on a Buy tile.

### Godot 4.7 notes

- `GridContainer` lays out children in order with `columns`; `theme_override_constants/h_separation` and `v_separation` set the 4 px gaps. Focus neighbours are not automatic across two containers, hence Task 5.5.
- `focus_neighbor_*` are `NodePath`s relative to the control: use `control.get_path_to(target)`. A neighbour pointing at itself stops focus at an edge (the `main_menu.gd` trick).
- Overriding a property on a node inside an instanced scene in a `.tscn`: the parent scene stores it as a node entry with `parent="PreviewZombie/Body"` and only the changed property (Godot writes this when "Editable Children" is on). Writing it by hand is fine; confirm with a test.
- `ColorRect.color` with alpha 0.6 is the scrim. `mouse_filter = MOUSE_FILTER_STOP` makes it eat clicks.
- `AtlasTexture` sub-resource in a `.tres`: `[sub_resource type="AtlasTexture" id="..."]` with `atlas = ExtResource(...)` and `region = Rect2(0, 0, 32, 32)`; same shape as the `SpriteFrames` atlases already in `pet_cute_ghost.tres`.
- `TextureRect` for 32×32 art: `expand_mode = EXPAND_IGNORE_SIZE`, `stretch_mode = STRETCH_KEEP_CENTERED`, texture filter nearest (inherited from the project default).

### Testing notes

- Suite: `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`, after `--import`.
- Never write the real save: inject a temp-dir `SaveService` + `PlayerData`. The Closet's preview slots don't listen (follow_equipped false), so nothing else defaults to the live autoload except `AudioManager` (use the `play_sfx` seam) and `Router` (use `navigate` / `is_transitioning`).
- GUT 9.7.1: `assert_push_warning` / `assert_push_error` match on a substring; `assert_push_warning_count` also counts warnings already matched (the 4.3 lesson). Keep warn strings distinctive ("closet tile: %s has no icon").
- One flaky `test_audio_manager` pool test exists (deferred-work 4.2). If it fails once, rerun before investigating.
- `assert()` shows as `SCRIPT ERROR` in headless GUT; use `Log` + safe returns.

### Previous story intelligence

- **4.3:** `HatSlot`/`PetSlot` have `follow_equipped` + `show_item()` built for this preview. Slots warn once per cause; a slot fed a Locked item would warn. Professor/zombie slots are connected in `_ready()` only. The art pipeline is `tools/` generators, never hand-edited PNGs (this story needs no new PNGs). The fit check's `E` key wrote the real save during 4.3's checks (backed up and restored); do the same backup for Task 7. 980 → 1050 tests; 14/14 mutations caught.
- **4.2:** the font-forced resize lesson (the mock's widths overflowed with the real font); text-fit and 16 px margin tests in `test_main_menu.gd`; `_leaving` guard released if the transition ends with the screen alive (review patch); hover = real mouse motion only (review patch); `PixelButton` exists; level-card wiggle constants.
- **4.1:** `PurchaseResult`, `buy_item`, `equip`/`unequip`, `get_equipped` filtering, distinctive error strings for `assert_push_error`, the counting `SaveService` test double in `test_player_data.gd`.
- **2.5:** the sketch-gate format (`sketches/hud-band-2-5.md`): status line, ASCII frames, element table, numbered deviations, then the verbatim approval in the story's Debug Log. Follow it.
- **Traps from earlier stories:** LF line endings (a CRLF `player_zombie.gd` turned up in 4.3), UTF-8 for `×`/`–`, prefer scratchpad scripts over heredocs with apostrophes, `untyped_declaration = Error` applies to tools and tests (type every `for` variable).

### Git intelligence

- One commit per story; code, data, tests, screenshots, the sketch and the story file ship together. Tree clean at `716392c Story 4.3: done (live confirmation recorded)`.
- Recent stories record baseline/final test counts and a mutation pass in the Dev Agent Record, and close or add `deferred-work.md` items.

### Project Structure Notes

- New: `scenes/ui/closet_item_tile.tscn`, `scripts/ui/closet_item_tile.gd`, `scenes/ui/confirm_prompt.tscn`, `scripts/ui/confirm_prompt.gd`, `assets/audio/sfx/sfx_purchase.wav` (+ `.import`), `tests/unit/test_closet_item_tile.gd`, `tests/unit/test_crypt_closet.gd`, the sketch `ux-designs/.../sketches/crypt-closet-4-4.md`, screenshots `4-4-*.png`. The architecture's Directory Structure names `scenes/ui/closet_item_tile.tscn` and `scripts/ui/closet_item_tile.gd`; the confirm prompt isn't named there, and `scenes/ui/` is the home for reusable widgets.
- Replaced: `scenes/screens/crypt_closet.tscn`, `scripts/screens/crypt_closet.gd`.
- Updated: `data/cosmetics/hat_pumpkin.tres`, `pet_cute_ghost.tres` (icons), `data/audio/audio_library.tres`, `tools/gen_placeholder_audio.gd`, `assets/audio/CREDITS.md`, `tests/integration/test_screen_flow.gd`, `tests/unit/test_catalogue.gd`, possibly `test_audio_library.gd`, `deferred-work.md`, `sprint-status.yaml`.
- Variance: tile size and where the state words live differ from DESIGN.md's `[ASSUMPTION]` 48 px tile because of the font. That goes in the approved sketch (which the spines say must conform, so the deviations are listed for Smuck explicitly). Don't edit DESIGN.md (a planning artifact); the sketch is the override, as in 2.5.

### Project Context Rules

- There is no `project-context.md`. Binding rules come from `_bmad-output/game-architecture.md` and the UX spines (spines > mocks > sketches, but an approved sketch fixes `[ASSUMPTION]` sizes):
  - Typed GDScript everywhere (`untyped_declaration = Error`); `:=` only when the type is obvious.
  - `%UniqueName` node refs; no `/root/` paths, no `get_parent()` chains.
  - Typed, past-tense signals connected in code; autoload connections disconnected in `_exit_tree`. No event bus (ADR-5).
  - Boundary 4: screens change state only through `PlayerData` methods and navigate only through `Router`. Boundary 3: only `AudioManager` plays audio, only `SaveService` touches files. Boundary 5: `.tres` instances in `data/`, class definitions in `scripts/resources/`.
  - Game numbers (prices, welcome bonus) come from `CosmeticItem`/`EconomyConfig`, never literals. Look values (wiggle px/s) are `const`s marked "look value, not a GDD number".
  - Palette colours only; the night scrim at 60% is the one alpha exception. Square `StyleBoxFlat`s (no `corner_radius`) until 5.0's 9-slices. One sprite scale (the preview zombie is 1×).
  - Log tags: `&"ui"` for the screen and tiles, `&"economy"` for purchase oddities. INFO for purchases is already logged by `PlayerData`.
  - NFR16: a missing icon or cosmetic logs a warning and never crashes. NFR9/NFR11: plain words, no timers.
- Tools: Godot binary `/c/Program Files/Godot/Godot.exe`; GUT 9.7.1; the Godot MCP server and the built-in browser pane are available for manual checks (a `web-debug` entry exists in `.claude/launch.json` since 2.4).

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 4.4: Crypt Closet]; FR24, FR25, FR39–FR43, FR45 (arrow path, built in 4.5); NFR8, NFR9, NFR11, NFR16
- [Source: _bmad-output/planning-artifacts/epics.md#Story 4.5] (what the tutorial needs from this screen; the "Closet → Esc → Menu" design note)
- [Source: _bmad-output/game-architecture.md] Screen Flow (`Router.Screen.CRYPT_CLOSET`, payloads), Data Persistence ("writes at … purchase or equip"), Static Game Data, Cosmetics, Data Patterns (the `crypt_closet.gd` buy example), Logging, Directory Structure (`scenes/ui/closet_item_tile.tscn`, `scripts/screens/crypt_closet.gd`), Architectural Boundaries 3/4/5/7, Consistency Rules
- [Source: …/ux-designs/…/DESIGN.md] Colors (stone, parchment, disabled-fill, pumpkin, candy-yellow, zombie greens), Typography (16 px floor, heading 24 px), Layout ("Closet by Story 4.4" sketch), Elevation (the night scrim, one modal), Shapes (`rounded.md` tiles), Components: closet-item-tile and its five states, confirm-prompt, tutorial-arrow, brain-counter, pixel-button
- [Source: …/ux-designs/…/EXPERIENCE.md] Screen inventory (Crypt Closet row), Voice and Tone (tile copy, "Buy the Pumpkin hat for 100 brains?" / "Yes" / "No"), Component Patterns (closet-item-tile, confirm-prompt, tutorial-arrow, brain-counter), State Patterns (Closet rows), Input (Esc/Enter/arrows), Game Feel (Purchase), Accessibility (keyboard-complete, never colour alone), Flow 2 (first purchase), Open Question 6
- [Source: …/ux-designs/…/sketches/hud-band-2-5.md] the sketch format and the measured font facts
- [Source: _bmad-output/planning-artifacts/gdds/…/gdd.md] M4/M5 (l.146–155), Economy prices (l.274), catalogue (l.278–286), Screens (l.356), SFX "purchase jingle" (l.377), save points (l.391)
- [Source: _bmad-output/implementation-artifacts/4-1-cosmetic-catalogue-and-brain-wallet-rules.md, 4-2-main-menu.md, 4-3-hat-and-pet-display-everywhere.md, 2-5-shared-hud-with-wrong-key-feedback.md]
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] 1.3 (Esc on Crypt Closet untested), 4.3 (preview uses `follow_equipped = false`; fit check `E`)
- [Source: scripts/autoloads/player_data.gd, router.gd, save_service.gd#request_save, audio_manager.gd], [Source: scripts/resources/cosmetic_item.gd, catalogue.gd], [Source: scripts/ui/level_card.gd, pixel_button.gd, brain_counter.gd], [Source: scripts/screens/main_menu.gd], [Source: scripts/cosmetics/hat_slot.gd, pet_slot.gd], [Source: tests/unit/test_main_menu.gd, test_level_card.gd, test_player_data.gd], [Source: tests/integration/test_screen_flow.gd], [Source: tools/gen_placeholder_audio.gd]

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Debug Log References

- **Font facts (Task 1.1, measured in Godot 4.7, 2026-10-06):** Press Start 2P advance = font size at 16, 24 and 32 px (spaces included; "Need 300 more" = 208 px at 16), line height = font size. Has `?`, `–` (U+2013) and `×`; **no** `✓` (U+2713) or `✔` (U+2714), so the Wearing check is a `Line2D` polyline (3 px, zombie-green-dark).
- **Test counts:** baseline 1050 tests, 1049 passing (the known flaky `test_audio_manager` pool test failed once; deferred-work 4.2). Final: 1132 tests, 1132 passing, 64 scripts, 38452 asserts. +82: `test_closet_item_tile.gd` 28, `test_crypt_closet.gd` 44, `test_confirm_prompt.gd` 8, `test_audio_library.gd` +1, `test_screen_flow.gd` +1 (the icon test in `test_catalogue.gd` was rewritten in place).
- **Mutation pass (Task 6.6), 12/12 caught:** LOCKED not winning over owned; `>=` to `>` in BUY; WEARING without the `equipped_id` check; Yes not calling `buy_item`; jingle on No; Esc navigating while the prompt is open; the prompt not disabling background focus; the preview showing a Locked item; missing `inventory_changed` connection; missing `brains_changed` connection; skipping the `_exit_tree` disconnect; Right from hat col 3 not crossing to the pets. Each run restored the source.
- **Audio:** `tools/gen_placeholder_audio.gd` re-run headless; the 8 existing `.wav` files are byte-identical (`git status` showed only the new `sfx_purchase.wav`, 10804 samples, about 0.49 s).
- **Screenshots (Task 7.2):** rendered from the real `crypt_closet.tscn` by a scratchpad SceneTree script on a temp-dir `SaveService` (`user://closet_shots_tmp/`, removed afterwards), 640×360.
- **Manual walk (Task 7.1):** played in a debug web export (`build/web`, ignored by git) in the built-in browser pane, which keeps its own save in browser storage. Title → Menu → Closet (focus on the Pumpkin hat, "Need 100 more") → arrows across both grids, onto Menu and down to pet tile 3 → Locked / Can't afford wiggle → F3 + F5 (+brains): both tiles flipped to Buy and the counter to 100 at once → Buy → prompt (Yes focused; Up/Down/Left stay inside; a click on the scrim did nothing) → No (nothing changed) → Buy → Yes (counter 0, tile Wear, ghost "Need 100 more") → Wear (check mark, preview hat, "Wearing") → Enter (take off) → Wear → Esc → menu zombie wears the hat. Mouse-only pass: Closet button, click to take off, click to wear, Menu button, all fine. A Zombie Run started with the hat on the zombie. Not reached in the pane: the report card (the run timer did not advance in the browser pane, likely tab throttling; the hat on the report card is covered by the Story 4.3 checks). Observation: the first one or two hover moves after any screen change do not move focus (the main menu does the same; logged in deferred-work).
- **Real save (Task 7.3):** not backed up because it was never touched: the walk used the browser storage and the screenshots a temp dir. `save.json` still has its 2026-10-05 19:58 timestamp.

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created.
- Task 1: the layout sketch `sketches/crypt-closet-4-4.md` (frames A–D, element table, six deviations) was approved by Smuck as drawn on 2026-10-06. The build follows it exactly; `test_rects_match_the_sketch` pins every rect.
- Task 2: `hat_pumpkin.tres` uses its overlay as the icon; `pet_cute_ghost.tres` gets an `AtlasTexture` of idle frame 0. New placeholder `sfx_purchase` (C5–E5–G5 at 0.08 s, C6 held 0.25 s with a fade, triangle, peak 0.4) in the generator, the library (−6 dB, no throttle) and `CREDITS.md`.
- Task 3: `ClosetItemTile` with the pure `state_for()` / `need_more()` rules plus a pure `info_lines()` for the info sign (the approved sketch moved the long words there). The tile never touches `PlayerData`; it emits `activated` only on Buy / Wear / Wearing and wiggles otherwise. Palette colours are `const`s in the script and the state boxes are built in code (square `StyleBoxFlat`, 1 px ink border). Hover focus also checks `focus_mode`, so a tile switched off by the prompt can never be hovered into focus.
- Task 4: `ConfirmPrompt` (reusable). It closes **before** emitting `answered` (the task text said emit then close), so a double press can never answer twice and a handler sees it closed. Noted in deferred-work.
- Task 5: the real Closet. All four `PlayerData` signals refresh the counter, tiles, info sign and preview; Wear / take off / buy act on the state re-read at that moment. `follow_equipped = false` is set in the `.tscn` (an editable-children override on `PreviewZombie/Body/HatSlot`, plus the `PreviewPet` property). The Closet also rejects an invalid catalogue (`Catalogue.validate()`), not only a null one: it logs an error, builds no tiles and focuses Menu. The info sign is two labels (name / state), blank while Menu is focused.
- Task 6: tests as listed, plus `tests/unit/test_confirm_prompt.gd` for the reusable prompt (not in the story list; it tests only the Task 4 API). 12/12 mutations caught.
- Task 7: screenshots approved by Smuck on 2026-10-06; manual walk in the debug web build (see Debug Log).
- Task 8: LF everywhere; deferred-work updated (1.3 Esc item closed, 4.3 fit-check note, new "dev of story 4-4" section).

### File List

New:
- `_bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/sketches/crypt-closet-4-4.md`
- `_bmad-output/implementation-artifacts/screenshots/4-4-closet-fresh.png`
- `_bmad-output/implementation-artifacts/screenshots/4-4-closet-confirm.png`
- `_bmad-output/implementation-artifacts/screenshots/4-4-closet-wearing.png`
- `assets/audio/sfx/sfx_purchase.wav`
- `assets/audio/sfx/sfx_purchase.wav.import`
- `scenes/ui/closet_item_tile.tscn`
- `scenes/ui/confirm_prompt.tscn`
- `scripts/ui/closet_item_tile.gd`
- `scripts/ui/closet_item_tile.gd.uid`
- `scripts/ui/confirm_prompt.gd`
- `scripts/ui/confirm_prompt.gd.uid`
- `tests/unit/test_closet_item_tile.gd`
- `tests/unit/test_closet_item_tile.gd.uid`
- `tests/unit/test_confirm_prompt.gd`
- `tests/unit/test_confirm_prompt.gd.uid`
- `tests/unit/test_crypt_closet.gd`
- `tests/unit/test_crypt_closet.gd.uid`

Modified:
- `_bmad-output/implementation-artifacts/4-4-crypt-closet.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `_bmad-output/implementation-artifacts/deferred-work.md`
- `assets/audio/CREDITS.md`
- `data/audio/audio_library.tres`
- `data/cosmetics/hat_pumpkin.tres`
- `data/cosmetics/pet_cute_ghost.tres`
- `scenes/screens/crypt_closet.tscn` (replaced)
- `scripts/screens/crypt_closet.gd` (replaced)
- `tests/integration/test_screen_flow.gd`
- `tests/unit/test_audio_library.gd`
- `tests/unit/test_catalogue.gd`
- `tools/gen_placeholder_audio.gd`

### Change Log

- 2026-10-06: Story 4.4 implemented. Layout sketch approved by Smuck; the real Crypt Closet (two 3×3 grids, preview zombie and pet, brain counter, info sign, Menu) with `ClosetItemTile` (five states, pure state rule), the reusable `ConfirmPrompt`, buy / wear / take off through `PlayerData`, live refresh from its signals, tile icons for the two MVP items and a placeholder `sfx_purchase` jingle. Tests 1050 → 1132, all passing; 12/12 mutations caught. Screenshots approved by Smuck. Status → review.
