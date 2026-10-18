---
baseline_commit: bbf7411a5b7c5da34847aceca1867dfaa749a90a
---
# Story 11.4: Zombie Name on Menu and Report Card

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a kid,
I want to see my zombie's name on the menu and report card,
so that the game feels like it's really mine.

## Acceptance Criteria

1. **Name on the main menu (FR78, DESIGN.md).** The main menu shows the active zombie's name near `%Zombie` in a new non-interactive `%ZombieName` Label: Press Start 2P (the theme font), **16 px**, `{colors.chalk}` `#F4F1E4` on the night background (13.7:1, DESIGN.md contrast table), placed where Gate 1 approves (starting point in Dev Notes). The text is `player_data.get_zombie_name()`, or `GameConstants.ZOMBIE_NAME_DEFAULT` ("Zombie") when that is `""` (a hand-edited save; same rule as `ZombieCard`). `FOCUS_NONE`, `mouse_filter = IGNORE`.
2. **The menu name stays current.** `%ZombieName` is set in `_show_profile()` (so it re-reads on open and on `profile_replaced`: a switch, an F8 reset) and on `zombie_name_changed`. Connections are made in `_ready()` like the existing ones.
3. **A way to switch zombies from the menu (FR78, FR25).** A new `%SwitchZombieButton` (`PixelButton`, copy `[ASSUMPTION — Gate 1]`: "Switch") next to the zombie and name. Enter / click → `_leave(Router.Screen.WHOS_PLAYING, {"from_menu": true})` (the one `_leave()` path: UI click, `_leaving` once-guard, release when the Router never starts). It is always shown, even with one zombie (the picker is also where "New zombie" lives). ≥ 32 px tall, hover moves focus (PixelButton does it).
4. **Menu focus map.** The existing map stays except for the new button: `%SwitchZombieButton` sits between the cards and the bottom row in the left column. Up from `%ClosetButton` → Switch; Up from Switch → the first choosable card (else `%TrendsButton`); Down from Switch → `%ClosetButton`; Left/Right from Switch stay put. Cards' Down stays `%ClosetButton`; Music/Sound/Fullscreen Up stays the first choosable card; Progress unchanged. Tab order: cards → Switch → Closet → Music → Sound → Fullscreen → Progress → (wrap). Opening focus unchanged (first choosable card, else Closet). `_wire_focus()` stays the single place this is wired (it is re-run by `_refresh_unlocks` and the unlock moments).
5. **Picker entered from the menu.** `whos_playing.gd` reads its payload: `{"from_menu": true}` (only a real `true`) → Esc (`ui_cancel`) goes back to `MAIN_MENU, {}` once (UI click, `_leaving` guard), switching nothing. Any other payload (title → picker) keeps 11.2's "Esc does nothing". Everything else on the picker is unchanged: focus starts on the active zombie's card (so Enter returns to the menu as the same zombie; `switch_profile` to the active id is a no-op: no signal, no save), picking another named zombie → `switch_profile` → `MAIN_MENU`, unnamed → `NAME_ZOMBIE`, "New zombie" → name screen (Back returns to the picker with `{}` — acceptable: Esc there then does nothing, picking returns to the menu). `[ASSUMPTION — Gate 1 question 3]`: no visible Back button on the picker.
6. **Name on the report card (FR78).** The report card shows the active zombie's name near `%Professor` (the kid's zombie in its professor pose, wearing its hat and pet since Story 4.3) in a new non-interactive `%ZombieName` Label: 16 px, colour `{colors.ink}` `#1E1428` on the `parchment-shade` wall (not chalk — the wall is light; confirm ≥ 4.5:1 and add the pair to DESIGN.md's contrast table), placed where Gate 1 approves (starting point in Dev Notes). Same default rule as AC 1. Read once in `_ready()` from `player_data.get_zombie_name()` (the card never outlives a switch). It never blocks input, never takes focus and does not change the reveal, the mash guard, the stamp or the welcome-gift redirect. The report card reads one more thing from PlayerData — update its class doc line "That one flag is all this screen reads from PlayerData".
7. **Layout and readability (NFR7, DESIGN.md).** 640×360, inside the 16 px margin, no overlap and no clipped text with a 12-character `WWWWWWWWWWWW` name (12 × 16 = 192 px) **and** the tallest hat from the shipped catalogue on the zombie/professor **and** a pet, on both screens; on the report card also with the "New best!" stamp and the bonus row shown; on the menu also with the storage notice shown. Names never wrap or shrink (`autowrap_mode = OFF`, `clip_text = false`; the label is sized to fit 192 px). No `StyleBoxFlat`, no `draw_*`; candy yellow only for focus.
8. **Names never logged (NFR12).** No log/print/push line in `main_menu.gd`, `report_card.gd` or `whos_playing.gd` carries the name. Extend the NFR12 source guard in `tests/unit/test_player_data.gd` to read `scripts/screens/main_menu.gd` and `scripts/screens/report_card.gd`.
9. **Plain words.** "Switch" (or the Gate 1 copy) is approved on purpose in `test_plain_words.gd`; the walks of the menu and report card use an unnamed temp zombie so the shown text is the already-approved "Zombie" (kids' names are user content, never part of the copy check).
10. **No migration, no new save fields.** `GameConstants.CURRENT_SCHEMA` stays **5**; `SaveSchema` and fixtures unchanged; no new PlayerData public method (if one is added anyway, it must go into `test_profile_isolation.gd`'s table or allow-list — Story 11.3's guard fails otherwise).
11. **Approval gates.** Gate 1: layout sketch of the menu (name + Switch, short name and 12-W name with the tallest hat and a pet, focus on Switch, storage notice shown) and the report card (name with the tallest hat, pet, stamp), the copy, and the Dev Notes questions — approved by Smuck **before** wiring visuals. Gate 2: in-game captures (menu with a short name, menu with 12 W's + tallest hat + pet + Switch focused, the same in grayscale, report card with 12 W's + tallest hat + pet + New best stamp, picker opened from the menu) approved by Smuck. Record verbatim + date under `## Art Approval`. No new sprites, no new sounds.
12. **No regressions.** Full GUT suite green and the count only goes up; zero `Parse Error|Compile Error|Failed to load script`; `SCRIPT ERROR` / `WARNING` counts unchanged except deliberate, asserted ones. Existing PNG/WAV byte-identical. The real `user://save.json` sha256 identical before and after every suite run and manual check (temp `user://` dirs only).

## Tasks / Subtasks

- [x] **Task 1: Baseline** (AC: 12)
  - [x] 1.1 `"C:\Program Files\Godot\Godot.exe" --headless --path . --import`, then `... --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` into a scratch log. Record tests/passing, `SCRIPT ERROR`, `WARNING`, zero `Parse Error|Compile Error|Failed to load script`. Expected after 11.3 + review: ~2379+ / all passing, `SCRIPT ERROR` 3, `WARNING` 190 — re-measure.
  - [x] 1.2 Record the real save's sha256 (`%APPDATA%/Godot/app_userdata/ZombiesTeachTyping/save.json`).

- [x] **Task 2: Gate 1 — sketch, copy, questions** (AC: 1, 3–7, 11) — **stop for Smuck's approval before Tasks 3–5 visuals.**
  - [x] 2.1 New `_bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/sketches/zombie-name-11-4.md` in the style of `whos-playing-11-2.md` / `name-zombie-11-1.md`: menu frame (short name; 12 W's + tallest hat + pet; Switch focused; storage notice shown) and report card frame (12 W's + tallest hat + pet + stamp + bonus row). Coordinates on the 4 px grid, colours by token, focus map. Measure the tallest hat's rise on both bodies first (see Dev Notes "Hat height").
  - [x] 2.2 Ask the copy + the Dev Notes questions in one message; record the verbatim answers + date under `## Art Approval`.

- [x] **Task 3: Main menu name + Switch** (AC: 1–4)
  - [x] 3.1 `scenes/screens/main_menu.tscn`: `%ZombieName` Label (theme font, 16 px override, chalk colour override, no wrap, `FOCUS_NONE`, `mouse_filter = 2`) and `%SwitchZombieButton` (`Button` + `theme_type_variation = &"PixelButton"` + `pixel_button.gd`, like `%ClosetButton`). Bump `load_steps` only if a new ext_resource is added (none expected).
  - [x] 3.2 `scripts/screens/main_menu.gd`: `_show_profile()` also sets `%ZombieName.text` via a small `_shown_name()` helper (default rule); connect `player_data.zombie_name_changed` to a handler that calls the same helper; `%SwitchZombieButton.pressed` → `_leave(Router.Screen.WHOS_PLAYING, {"from_menu": true})`; extend `_wire_focus()` per AC 4 (Switch is not in `bottom`; wire it explicitly; Tab `order` = cards + [Switch] + bottom + [trends]). Update the class doc (a "Story 11.4:" paragraph: name label, Switch button, focus).
  - [x] 3.3 `tests/unit/test_main_menu.gd`: name shown (temp profile named "Sam"); empty name → "Zombie"; `profile_replaced` after a second profile + `switch_profile` → other name; `set_zombie_name` → label follows; Switch press → `[[WHOS_PLAYING, {"from_menu": true}]]` and the `_leaving` guard (second press/Closet ignored); the new focus neighbours and Tab order (update `test_tab_order_walks_cards_then_bottom_row` and the bottom-row Up loop only where AC 4 changes Closet's Up — say "Story 11.4" in the message); `%ZombieName` in `test_decor_never_takes_focus_or_the_mouse`; Switch Up with no choosable card → `%TrendsButton`.

- [x] **Task 4: Picker Esc from the menu** (AC: 5)
  - [x] 4.1 `scripts/screens/whos_playing.gd`: keep `Router.take_payload()`'s result; `_from_menu: bool = payload.get("from_menu", false) == true`. `_unhandled_input` `ui_cancel`: still taken; when `_from_menu` → `_go(Router.Screen.MAIN_MENU, {})` with the click (reuse `_go`'s once-guard / `_release_when_settled`). Update the class doc ("Esc does nothing" → "...unless opened from the menu").
  - [x] 4.2 `tests/unit/test_whos_playing.gd`: from-menu Esc → click + one `[MAIN_MENU, {}]`, no `switch_profile`, no save request; title payload `{}` → Esc still dead; junk `{"from_menu": "yes"}` → dead; Enter on the (focused) active card from the menu → `MAIN_MENU`, no `profile_replaced`.

- [x] **Task 5: Report card name** (AC: 6)
  - [x] 5.1 `scenes/screens/report_card.tscn`: `%ZombieName` Label (16 px, ink colour override, no wrap, centred over the professor or as Gate 1 says, `FOCUS_NONE`, `mouse_filter = 2`). Keep it **out of** the `_rows` reveal and above nothing interactive.
  - [x] 5.2 `scripts/screens/report_card.gd`: set it in `_ready()` after the seams (`player_data` may be the temp one). Class doc updated (AC 6).
  - [x] 5.3 `tests/unit/test_report_card.gd`: name shown; empty → "Zombie"; the label is visible from the first frame (not part of the reveal) and the mash guard / gift redirect tests stay unchanged.

- [x] **Task 6: Cross-screen tests** (AC: 7–9, 12)
  - [x] 6.1 `tests/unit/test_readability.gd`: in `_menu()` and `_report_card()` (or new `_menu_long_name()` / `_report_card_long_name()` roots) give `_player` the name `WWWWWWWWWWWW`, the tallest hat (owned + equipped) and a pet; storage notice and stamp shown (already done there). Fit / 16 px / overlap / inside margin must pass with `%ZombieName` and `%SwitchZombieButton` counted. Add `%SwitchZombieButton` wherever that file lists the menu's clickables.
  - [x] 6.2 `tests/unit/test_plain_words.gd`: approve "Switch" (or the Gate 1 copy) on purpose; menu and report card walks keep an unnamed temp zombie (shows "Zombie", already approved by 11.2).
  - [x] 6.3 `tests/integration/test_screen_flow.gd`: `FLOW_BUTTONS["MAIN_MENU"]` gains `"%SwitchZombieButton"`; a flow test menu → Switch → picker (`{"from_menu": true}`) → Esc → `MAIN_MENU`, and menu → Switch → pick the other zombie → `MAIN_MENU` with the other name on `%ZombieName` (temp PlayerData through every screen: the picker **writes** via `switch_profile` — 10.1 real-save incident).
  - [x] 6.4 `tests/integration/test_profile_switch.gd`: the live-menu switch test also asserts `%ZombieName` shows the second profile's name (one more line in the existing test, no new listener expected).
  - [x] 6.5 NFR12 guard (AC 8): add `main_menu.gd` and `report_card.gd` to the files the source guard reads; add `_shown_name` to its identifier list if it uses one.
  - [x] 6.6 Confirm `test_no_placeholder_chrome.gd` and `test_profile_isolation.gd` pass with no change.

- [x] **Task 7: Docs** (AC: 1, 3, 5, 6)
  - [x] 7.1 `EXPERIENCE.md`: IA "Who's playing?" row — also from Main Menu ("Switch", Esc returns to the menu then); Main Menu row/flow line gains the name and Switch; Voice and Tone row for "Switch"; Component Patterns: `zombie-card` Esc note; State Patterns: menu with a name / with no name ("Zombie").
  - [x] 7.2 `DESIGN.md`: "Zombie nameplate" entry (16 px, chalk on night on the menu, ink on the wall on the report card, never wraps, 12 letters = 192 px) + the ink-on-parchment-shade contrast row.
  - [x] 7.3 `_bmad-output/game-architecture.md` Screen Flow: `WHOS_PLAYING` payload `{"from_menu": true}` (Esc → `MAIN_MENU`), reachable from `MAIN_MENU`.

- [x] **Task 8: Gate 2 — in-game check** (AC: 11, 12)
  - [x] 8.1 Captures via a scratch windowed runner on an isolated user dir (11.1/11.2's way: temporary `override.cfg` with `custom_user_dir_name`, deleted after along with the runner `tools/_scratch_11_4/` and the dir), seeded `save.json` with two named profiles (one `WWWWWWWWWWWW` with the tallest hat + a pet), into `_bmad-output/implementation-artifacts/screenshots/11-4/`: `menu-short-name.png`, `menu-long-name.png` (Switch focused), `menu-long-name-gray.png`, `report-card-long-name.png` (new best + bonus), `picker-from-menu.png`. Show Smuck; record verbatim + date.
  - [x] 8.2 Web smoke (`web-debug` launch config, browser storage only; the pane already holds "zed bo" and "al kid" from 11.2): title → picker → pick → menu shows that name → Switch → picker (focus on the same zombie) → Esc → menu → Switch → pick the other → menu shows the other name, brains, hat → play Zombie Run → report card shows that name. Console: no errors, no line containing either name.

- [x] **Task 9: Wrap-up** (AC: 12)
  - [x] 9.1 Full suite + counts vs baseline; real save sha256 unchanged; only the new screenshots among PNG changes.
  - [x] 9.2 Mutation pass (scratch edits, restore after; each must turn a test red): menu doesn't re-read the name on `profile_replaced`; menu ignores `zombie_name_changed`; empty name shows "" instead of "Zombie"; Switch navigates with `{}` (no `from_menu`); picker Esc goes to the menu from the title too; Closet's Up still goes to the card; report card reads the name from the first profile instead of the active one; a `Log.info` with the name in `main_menu.gd`.
  - [x] 9.3 Anything deferred → `deferred-work.md`. Status → review. This is the last story of Epic 11: leave `epic-11` as is (Smuck marks it done; retrospective optional).

### Review Findings

- [x] [Review][Patch] Back from the name screen drops `from_menu` — carry `from_menu` through `NAME_ZOMBIE` (picker payload `{"new_zombie":true,"from_menu":true}`) and have its Back return `{"from_menu": true}`; add tests [scripts/screens/name_zombie.gd:225, scripts/screens/whos_playing.gd:194] (decided: option b)
- [x] [Review][Patch] Menu copy walk never asserts the unnamed-zombie rule (Task 6.2) — add `%ZombieName` text == "Zombie" for the main menu instance [tests/unit/test_plain_words.gd:210]
- [x] [Review][Patch] `test_switch_keeps_its_wiring_after_a_rewire` does not assert Switch's Up neighbour after `unlocks_changed` [tests/unit/test_main_menu.gd:395]
- [x] [Review][Defer] Long or odd-glyph name (hand-edited save) is not re-sanitized at the read site and can overflow the label on menu and report card [scripts/screens/main_menu.gd, scripts/screens/report_card.gd] — deferred, only reachable by hand-editing; names are sanitized on write
- [x] [Review][Defer] Empty-name -> "Zombie" fallback exists in `main_menu.gd`, `report_card.gd` and `ZombieCard` — deferred, can drift; share a helper if a fourth appears

## Dev Notes

### What this story is (and isn't)

- **Is:** a name label on the main menu and on the report card, a "Switch" button on the menu that opens the 11.2 picker, Esc-back on the picker when it was opened from the menu, tests, docs, two gates.
- **Isn't:** renaming or deleting a zombie (no AC; deferred since 11.1/11.2 — don't add a rename tap on the name); a name on the run HUD, Closet, Progress or welcome gift (only menu + report card are in the AC); any save/schema change; any PlayerData API change (the getters exist: `get_zombie_name()`, `zombie_name_changed`, `profile_replaced`).

### Design decisions made for this story (follow them; record any change and why)

1. **Plain label, not a sign.** The name sits near the zombie as text in the pixel font (the AC: "displayed near the zombie in the pixel font"). A `Sign` plank around a 192 px name would not fit next to the professor (the board ends at x 432, the margin at x 624 = exactly 192 px).
2. **Default "Zombie" for an empty name** — same as `ZombieCard`; the title already sends an unnamed active zombie to the name screen, so this only shows on a hand-edited save.
3. **Switch is a separate button, not a clickable name.** A 6-year-old needs a visible button with a word; the name stays decoration (no new interaction pattern).
4. **Always shown**, even with one zombie: the picker is also how a second kid makes a zombie, and the AC says "a way to switch zombies from the menu".
5. **Picker from the menu: Esc returns** (payload `{"from_menu": true}`); focus is already on the current zombie, so Enter also returns. No visible Back button (keeps the 11.2-approved picker layout). Gate 1 question 3.
6. **Report card reads the name once.** The report card is built after any switch and has no path to the picker; no listener needed.

### Proposed layout (starting point for the Gate 1 sketch; 640×360, 4 px grid, 16 px margin; Press Start 2P glyph width = font size)

- **Main menu today** (`main_menu.tscn`): `%BrainCounter` 16–96 × 16–44; `%Logo` 144–496 × 16–56; `%TrendsButton` 480–624 × 16–48; `%Cards` 16–624 × 64–188; `%Zombie` (`player_zombie.tscn`, Node2D, body offset (-16,-31), 32 px) at (48, 284) → body x 32–64, y 253–284, hat above; `%PetSlot` at (84, 284); `%ClosetButton` 16–224 × 296–328 with posts at y 328–344; toggles at y 288–340 from x 240; `%StorageNotice` 288–624 × 200–280 (shown only in non-persistent browsers). Free: the left column x 16–272, y 196–~248 above the zombie, and x ~104–272 beside the zombie/pet.
- Proposed: `%ZombieName` x 16–208, y 204–220, left-aligned (above the hat; adjust to the measured hat top). `%SwitchZombieButton` "Switch" (6 glyphs = 96 + 16 padding → 112 × 32) at x 112–224, y 248–280, right of the pet, above the Closet button (16 px gap). Both clear of the storage notice (x ≥ 288) and the toggles (y ≥ 288).
- **Report card today** (`report_card.tscn`): board 16–432 × 12–288 (shadow to 434 × 290); window 448–628 × 14–122 (sill to y 122); `%Stamp` 290–434 × 6–65; `%Professor` (Node2D, `centered = false` body, 32 px) at (430, 270) → body x 430–462, y 270–302 (stands on the floor line at 296), its `%PetSlot` at +(60, 30) → ~x 490; floor y 296+; buttons at y 308–340. Free: x 436–624, y 126–~250.
- Proposed: `%ZombieName` x 432–624 (192 px, exactly 12 W's — right edge on the margin) centred, y 228–244 (above the professor's hat; adjust to the measured hat top), ink colour. If Gate 1 prefers it below the window, keep ≥ 4 px from the sill.

### Hat height (measure, don't guess)

- Hats ride on `HatSlot` with per-pose anchors (`data/anchors/zombie_anchors.tres`, `professor_anchors.tres`). The tallest shipped hat (Epic 9 has 18 items; party hat / witch hat / top hat are candidates) decides how high the name must sit. Measure in a scratch scene or from the Closet/hat tests (`professor_zombie._rise_cache` is a hat-geometry cache by item id; `tests/unit/test_hat_slot.gd` / Story 9.1 fit tests have the rects) and use the worst case in the sketch and in `test_readability.gd`'s overlap walk.

### Questions for Gate 1 (ask together with the sketch; record answers)

1. Copy for the menu button: "Switch" (recommended, 6 letters fits beside the zombie) — or "Change zombie" / "Who's playing?" (wider: would need the button under the name instead)?
2. Name placement: menu above the zombie (left-aligned), report card above the professor (centred) — OK?
3. Picker opened from the menu: Esc goes back to the menu, no Back button (recommended) — or add a visible "Back" button too?
4. Show "Switch" even when there is only one zombie (recommended: it is the way to make a second one) — or hide it until there are two?

### Existing code: current state, what changes, what must be preserved

- **`scripts/screens/main_menu.gd`** (394 lines): `_show_profile()` (brains, Music/Sound) is connected to `profile_replaced` and called once in `_ready()` — the name goes here. `_leave(screen, payload, on_started)` is the only navigation (click, `_leaving` guard, `await` loop release) — use it. `_wire_focus()` builds three rows (Progress / cards / bottom) via `_wire_row` and a Tab ring; it is called from `_ready()`, `_refresh_unlocks()` and `_on_unlock_moment_finished()` — wire Switch inside it so every re-wire keeps it. Preserve: unlock moments (`_input` finishes them on arrows/Enter/Esc/click), fullscreen settle logic, Ctrl+Shift+E export chord, storage notice, Esc does nothing on the menu.
- **`scenes/screens/main_menu.tscn`**: absolute offsets (`layout_mode = 0`), `load_steps=11`; the PixelButton script and theme variation are already ext_resources (`5_pixel_button`). Adding nodes with existing ext_resources doesn't change `load_steps`.
- **`scripts/screens/whos_playing.gd`** (208 lines, 11.2 + review): `Router.take_payload()` at `:61` (result discarded — keep the call, use the result); `_unhandled_input` takes `ui_cancel` at `:86`; `_go(screen, payload)` at `:188` is the once-guarded navigation with `_release_when_settled` (connected to `process_frame`, dropped when freed — 11.2's fix for the await-on-freed bug); `_dirty` rebuild flag; cards capped to `MAX_ZOMBIES`, active first focus. Change only the payload read + Esc branch + class doc.
- **`scripts/screens/report_card.gd`** (195 lines): seams `navigate`, `player_data`, `play_sfx`, `play_music`; `_fill()` sets the stats; `_rows` reveal in `_process`; `_input` mash guard swallows presses for `REPORT_CARD_INPUT_GUARD_S`; `_leave()` redirects the first exit to the Welcome Gift by `welcome_bonus_claimed`. Add the name in `_ready()` only; preserve everything else.
- **`scenes/screens/report_card.tscn`** (682 lines, `load_steps=9`): absolute offsets; Backdrop wall/window/floor are ColorRects + sprites; Professor is a scene instance whose `HatSlot`/`PetSlot` follow the PlayerData autoload by default (tests set them where needed).
- **`PlayerData`**: no change. `get_zombie_name()` returns `""` for missing/junk; `zombie_name_changed(name)` is emitted by `set_zombie_name` and `create_profile`; `profile_replaced` by `switch_profile`, `create_profile`, `reset_all`.
- **`HatSlot` / `PetSlot`** on the menu and report card already follow the active profile (Story 4.3, proven on switch by `test_profile_switch.gd`).

### Known test fallout (so you are not surprised)

| Test | Why | Fix |
|---|---|---|
| `test_main_menu.gd` Tab order (`:254`) | Switch joins the ring | insert Switch after the cards (Task 3.3) |
| `test_main_menu.gd` bottom-row Up loop (`~:244`) | Closet's Up now → Switch | Closet case expects Switch; others unchanged |
| `test_main_menu.gd::test_up_goes_to_the_first_available_card` (`:249`) | asserts Closet's Up | assert it on Music (or on Switch's Up) instead, message "Story 11.4" |
| `test_main_menu.gd` decor test (`:296`) | new decor label | add `%ZombieName` |
| `test_screen_flow.gd` `FLOW_BUTTONS` | new menu button | add `%SwitchZombieButton` (Task 6.3) |
| `test_readability.gd` menu/report walks | new label + button | Task 6.1 |
| `test_plain_words.gd` | new copy | Task 6.2 |
| `test_whos_playing.gd` Esc test | payload now read | existing `{}` case stays dead; add from-menu cases |
| `test_smoke.gd` (`CURRENT_SCHEMA == 5`), `test_profile_isolation.gd` | must **not** change | undo any schema/PlayerData touch |

### Testing notes

- Commands in Task 1. Run `--import` after scene edits if a test can't find a node or class.
- GUT skips a script that fails to parse and still exits 0 — grep the log for `Parse Error|Compile Error|Failed to load script`.
- Never the real save: temp-dir `SaveService` + injected PlayerData for every screen (`test_main_menu.gd::_make_player_data`, `test_report_card.gd::_make_player_data`, `test_screen_flow.gd::_temp_player_data`). Set `HatSlot`/`PetSlot.player_data` too (the menu's `%Zombie/%HatSlot` and `%PetSlot`; the report card's `%Professor/%HatSlot` and `%Professor/%PetSlot`).
- Second profile in a test: `create_profile("Bo")` (makes it active) or `save_service.get_data()["profiles"]["p2"] = SaveSchema.profile_defaults()` + fields.
- After calling `_unhandled_input()` by hand push a no-op `InputEventAction` in `after_each` (`_reset_input_handled`, 10.5/11.1) or GUT's viewport stays "handled".
- The report card's mash guard: tests advance `_open_s` past `REPORT_CARD_INPUT_GUARD_S` (see existing tests) before pressing anything; the name must be visible at `_open_s == 0`.
- Type every variable incl. loop vars (`untyped_declaration = Error`). Disconnect autoload signals in `_exit_tree` if you connect to the **autoload** (the menu connects to `player_data`, which may be the autoload in the game — follow how the menu's existing `player_data` connections are handled).
- Flaky `test_audio_manager` pool test: rerun once before investigating.

### Previous story intelligence (11.3, done 2026-10-18; 11.2, done 2026-10-15)

- 11.3: no data leaks in PlayerData; one stale listener fixed (Crypt Closet tutorial on a switch). `test_profile_isolation.gd` guard fails if a **public PlayerData method** is added without a table row — this story should add none. `test_profile_switch.gd` already drives a live main menu across `switch_profile` (brains, toggles, hat, pet, cards) — extend it with the name (Task 6.4).
- 11.3 deferred: Closet tutorial after F8 reset (dev-only); getters named `get_*` assumed read-only.
- 11.2: picker API and screen; `ZombieCard` default "Zombie"; `_go` + `_release_when_settled` instead of `await` loops (the await-on-freed bug that failed `test_real_letters_type`); readability walk with `MAX_ZOMBIES` × `WWWWWWWWWWWW`; Gate captures via isolated user dir + `override.cfg`; browser pane drops Shift (check capitals on desktop); keys typed during a Router fade are dropped by design.
- 11.2 Project Structure note: "11.4 will add a 'switch zombies' path from the menu → it will navigate to `WHOS_PLAYING`; keep the picker working when entered from anywhere with `{}`" — it does; this story only adds the `from_menu` Esc.
- 11.1: `ZOMBIE_NAME_MAX_LENGTH = 12`, letters and single spaces only, `ZOMBIE_NAME_DEFAULT = "Zombie"`; name never logged (source-guard regex on log lines naming `name`/`raw`/`text`/`cleaned`/`_text`/`summary`/`shown`...).
- Final counts: 11.3 = 2379 / 2379, `SCRIPT ERROR` 3, `WARNING` 190 (plus the review's tests — re-measure).

### Git intelligence

- Recent: `bbf7411 Story 11.3: code review findings resolved, done`, `8b006d0 Story 11.3: fully separate zombies`, `650c644 Story 11.2: code review findings resolved, done`, `cd9415b Story 11.2: who's playing picker and new zombies`, `544f6e8 Story 11.1: code review findings resolved, done`. One commit per story: code, scenes, tests, docs, screenshots, story file, `deferred-work.md`, `sprint-status.yaml`.
- Expected shape: updated `scripts/screens/main_menu.gd`, `scenes/screens/main_menu.tscn`, `scripts/screens/report_card.gd`, `scenes/screens/report_card.tscn`, `scripts/screens/whos_playing.gd`; tests `test_main_menu.gd`, `test_report_card.gd`, `test_whos_playing.gd`, `test_readability.gd`, `test_plain_words.gd`, `test_player_data.gd` (guard), `test_screen_flow.gd`, `test_profile_switch.gd`; new sketch `zombie-name-11-4.md`; EXPERIENCE/DESIGN/architecture lines; `screenshots/11-4/`. Message: `Story 11.4: zombie name on menu and report card`.

### Latest tech notes (Godot 4.7.2, GUT 9.7.1)

- No new libraries/addons; versions pinned by the architecture (Godot 4.7.2 standard, GDScript, Compatibility renderer; GUT 9.7.1). No web research needed.
- `Label.autowrap_mode = TextServer.AUTOWRAP_OFF` (scene value `0`) and `clip_text = false` keep a name on one line; size the label wide enough (192 px at 16 px) rather than relying on overflow.
- `Control.focus_neighbor_*` / `focus_next` / `focus_previous` are NodePaths relative to the control: `control.get_path_to(other)` after both are in the tree (as `_wire_row` does).

### Project Structure Notes

- No new production files: two scenes + three screen scripts change. Sketch in `ux-designs/.../sketches/zombie-name-11-4.md`; screenshots in `implementation-artifacts/screenshots/11-4/`; scratch runner in `tools/_scratch_11_4/` (deleted). No variance from the architecture tree.

### Project Context Rules

- There is no `project-context.md`. Rules from the architecture and earlier stories:
  - Only `SaveService` touches files; only `PlayerData` mutates profile/save state; screens read via getters and navigate via `Router` (Boundary 4).
  - Static typing everywhere; typed, past-tense signals connected in code; disconnect autoload signals in `_exit_tree`.
  - No GDD number as a literal; UI look values are consts with a "Look value" comment (scene offsets are fine).
  - Never log personal data — zombie names (NFR12). Profile ids are fine.
  - Kid-facing text: words a 6-year-old can read; no ranks or comparisons between zombies (NFR10), no tier shown (FR60), no timers (NFR11).
  - DESIGN.md: palette only, 16 px text floor, candy yellow = focus only, no `StyleBoxFlat`, never colour alone.
  - Errors never reach the kid; junk save values read as safe defaults (NFR16).
  - Visible changes wait for Smuck's approval (Gate 1 before visuals, Gate 2 in game), recorded verbatim with dates.
  - Files LF (`.gitattributes eol=lf`); hand-edited `.tscn`: `format=3`, correct `load_steps`, unique ids; commit the uids Godot writes.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 11.4: Zombie Name on Menu and Report Card]; Epic 11 overview; FR78, FR25, NFR7, NFR9–NFR12, NFR16
- [Source: _bmad-output/game-architecture.md#Screen Flow] (`WHOS_PLAYING`, `NAME_ZOMBIE` payloads), [#State Management], [#Logging]
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/EXPERIENCE.md] (IA rows 37–39, flow line 47, `zombie-card` 110), [DESIGN.md] (colors `chalk`, `ink`; contrast table ~375–393; Report card ~446), [mockups/key-main-menu.html], [mockups/key-report-card.html], [sketches/whos-playing-11-2.md], [sketches/name-zombie-11-1.md]
- [Source: scripts/screens/main_menu.gd] (`_show_profile`, `_wire_focus`, `_wire_row`, `_leave`), [scenes/screens/main_menu.tscn], [scripts/screens/report_card.gd], [scenes/screens/report_card.tscn], [scripts/screens/whos_playing.gd], [scripts/ui/zombie_card.gd] (default-name rule), [scripts/autoloads/player_data.gd] (`get_zombie_name`, `zombie_name_changed`, `profile_replaced`), [scenes/characters/player_zombie.tscn], [scenes/characters/professor_zombie.tscn]
- [Source: tests/unit/test_main_menu.gd], [tests/unit/test_report_card.gd], [tests/unit/test_whos_playing.gd], [tests/unit/test_readability.gd], [tests/unit/test_plain_words.gd], [tests/unit/test_player_data.gd] (NFR12 guard), [tests/integration/test_screen_flow.gd], [tests/integration/test_profile_switch.gd], [tests/unit/test_profile_isolation.gd]
- [Source: _bmad-output/implementation-artifacts/11-2-whos-playing-picker-and-new-zombies.md], [11-3-fully-separate-zombies.md], [deferred-work.md] (11-1, 11-2, 11-3 entries)
- Screenshots of today's screens: `_bmad-output/implementation-artifacts/screenshots/10-5/menu-progress-focused.png`, `screenshots/5-0/gate2-report-card-new-best.png`

## Art Approval

<!-- Gate 1 (layout sketch + copy + questions) and Gate 2 (in-game captures): Smuck's verbatim answers with dates. -->

### Gate 1 — 2026-10-18 (sketch `sketches/zombie-name-11-4.md`)

- Q1 copy: "Switch (Recommended)"
- Q2 placement: "Approve as drawn (Recommended)"
- Q3 picker back: "Esc only (Recommended)"
- Q4 one zombie: "Always show (Recommended)"

### Gate 2 — 2026-10-18 (captures in `screenshots/11-4/`: menu-short-name, menu-long-name, menu-long-name-gray, report-card-long-name, picker-from-menu)

- "Approve (Recommended)"

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Debug Log References

- Baseline (2026-10-18, HEAD bbf7411): 121 scripts, 2379 / 2379 passing, 144863 asserts, `SCRIPT ERROR` 3, `WARNING` 190, zero `Parse Error|Compile Error|Failed to load script`.
- Real save sha256 before: `2859cbaa61d4fc9a7a4b7b7e8019794def38313e28a8ba71d8b6a0cd347d647a`.
- After: 121 scripts, 2404 / 2404 passing (+25), 145067 asserts, `SCRIPT ERROR` 3, `WARNING` 190, zero parse/compile errors. Real save sha256 unchanged after every suite run, the capture run and the web smoke.
- Mutation pass (each restored after): menu ignores profile_replaced for the name → 2 red; ignores zombie_name_changed → 1; empty name shows "" → 2; Switch navigates with {} → 2; picker Esc from the title too → 3; Closet Up still to the card → 3; report card reads the first profile → 1; Log.info with the name in main_menu.gd → 1 (NFR12 guard). All 8 caught.
- Gate 2 captures: scratch runner `tools/_scratch_11_4/capture.gd` + temporary `override.cfg` (`ZTT_scratch_11_4` user dir); runner, override and dir deleted after. Log lines carried ids only.
- Web smoke (fresh `web-debug` export; pane storage was empty): title → name "zed" → menu shows "zed" → Switch → picker → Esc → menu → Switch → New zombie "bo" → menu "bo" → Switch (focus on bo) → Up + Enter → menu "zed" → Zombie Run (first key, F3/F6 end) → report card shows "zed". Console: no errors; no line with either name.
- Hat rise measured from the PNGs: witch hat and bunny ears are tallest (17 px above the head point). Menu: tallest hat top y 237. Report card: tallest hat + stacked mortarboard top y 254. Report card wall lines at y 216 and 240 → name placed at y 220–236 between them. Ink on parchment-shade = 9.7:1.

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created
- Main menu: `%ZombieName` (16 px chalk, x 16–208, y 204–220) set by `_shown_name()` in `_show_profile()` (open + `profile_replaced`) and on `zombie_name_changed`; default "Zombie" for an empty name. `%SwitchZombieButton` ("Switch", PixelButton, x 112–224, y 248–280, always shown) → `_leave(WHOS_PLAYING, {"from_menu": true})`. `_wire_focus()` wires Switch (Up → first choosable card else Progress, Down → Closet, Left/Right stay) and Closet's Up → Switch; Tab: cards → Switch → bottom row → Progress.
- Picker: reads the payload; only a real bool `true` for `from_menu` makes Esc play the click and `_go(MAIN_MENU, {})` once (guarded by `_leaving` / `is_transitioning`). Title payload and junk keep Esc dead.
- Report card: `%ZombieName` (16 px ink, x 432–624, y 220–236, between the wall lines, left-aligned over the professor) set once in `_ready()`; outside the reveal, no focus, no mouse; class doc updated. Ink on parchment-shade = 9.7:1 (added to DESIGN.md).
- Tests: test_main_menu (+11, three Story 11.4 updates to Closet's Up / Tab order / decor), test_whos_playing (+5), test_report_card (+6, text count 18 → 19), test_readability (+2: 12 W's + witch hat + wolf-dog on both screens, rect overlap/margin walk), test_plain_words ("Switch" approved; report walk asserts "Zombie"), test_screen_flow (+2 flows, FLOW_BUTTONS), test_profile_switch (name asserts), test_player_data NFR12 guard (+main_menu.gd, report_card.gd, `zombie_name`, `_shown_name(`). No schema / SaveSchema / PlayerData API change; test_profile_isolation and test_no_placeholder_chrome unchanged and green.
- Docs: EXPERIENCE.md (IA, flow, voice, zombie-card Esc, menu states), DESIGN.md (Zombie nameplate + contrast row), game-architecture.md (WHOS_PLAYING `from_menu`). Sketch approved at Gate 1. Deferred notes in deferred-work.md. Epic 11 left as is (Smuck marks it done).

### File List

- scripts/screens/main_menu.gd
- scenes/screens/main_menu.tscn
- scripts/screens/whos_playing.gd
- scripts/screens/report_card.gd
- scenes/screens/report_card.tscn
- tests/unit/test_main_menu.gd
- tests/unit/test_whos_playing.gd
- tests/unit/test_report_card.gd
- tests/unit/test_readability.gd
- tests/unit/test_plain_words.gd
- tests/unit/test_player_data.gd
- tests/integration/test_screen_flow.gd
- tests/integration/test_profile_switch.gd
- _bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/sketches/zombie-name-11-4.md (new)
- _bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/EXPERIENCE.md
- _bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/DESIGN.md
- _bmad-output/game-architecture.md
- _bmad-output/implementation-artifacts/screenshots/11-4/ (new: menu-short-name.png, menu-long-name.png, menu-long-name-gray.png, report-card-long-name.png, picker-from-menu.png)
- _bmad-output/implementation-artifacts/deferred-work.md
- _bmad-output/implementation-artifacts/sprint-status.yaml
- _bmad-output/implementation-artifacts/11-4-zombie-name-on-menu-and-report-card.md

### Change Log

- 2026-10-18: Story 11.4 implemented — zombie name on the main menu and report card, "Switch" button to the picker, Esc back from a picker opened by the menu; tests, docs, Gate 1 and Gate 2 approved. Status → review.
