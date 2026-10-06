---
baseline_commit: 96c0223880be66ca3009634926f93091057db2e0
---

# Story 4.5: Welcome Gift and Guided First Purchase

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a new player,
I want a gift of brains after my first run and a little help buying my first item,
so that I get a hat right away and understand what brains are for.

## Acceptance Criteria

1. **The gift replaces the first exit from the first report card (FR24, FR44).** When a report card that was opened **with a `RunResult`** moves on (Play Again, Menu, Esc, or Enter with no focus) and `PlayerData.get_flag(&"welcome_bonus_claimed")` is false, it navigates to `Router.Screen.WELCOME_GIFT` with `{}` **instead of** the requested screen. Once the flag is true, the report card goes where it was asked, exactly as today. The redirect goes through the existing `_leave()` (the card's only navigation), so the 1.0 s mash guard and the once-only `_leaving` latch still hold. Quit runs never reach a report card, so a quit never triggers the gift.
2. **The Welcome Gift card (FR44, DESIGN "Welcome Gift card", EXPERIENCE "welcome-gift-card").** `scenes/screens/welcome_gift.tscn` replaces the Story 1.3 placeholder: a wood panel with a pumpkin ribbon and bow, a parchment "Welcome gift!" sign at 24 px, "+N" (N = `EconomyConfig.welcome_bonus`, 100, never a literal) next to a brain icon, and **one** pre-focused `PixelButton`, "Open the Crypt Closet". Placeholder chrome in palette colours (final art is 5.0), laid out per Dev Notes "Welcome Gift layout". Enter or a click on the button goes to `Router.Screen.CRYPT_CLOSET` with `{"tutorial": true}`, once (`_leaving` guard). Esc does nothing.
3. **Grant once, on show (FR44).** In `_ready()`, if `welcome_bonus_claimed` is false, the card calls `player_data.add_brains(economy.welcome_bonus)` and then `player_data.set_flag(&"welcome_bonus_claimed", true)`, in the same frame (one coalesced save). If the flag is already true (only reachable through the debug overlay's jump), it grants nothing, logs `Log.info(&"economy", ...)`, and still shows the card and its button. A null `economy` logs `Log.error(&"economy", ...)`, grants nothing, leaves the flag false, and the button still works (NFR16).
4. **Mash guard on the gift.** For the first `INPUT_GUARD_S` seconds (a look value, 0.5 s, counted in `_process` like the report card so the Router's paused fade-in doesn't use it up), presses on the button (key or mouse) do nothing, so a kid mashing Enter through the report card still sees the gift.
5. **Tutorial starts only from the gift (FR45).** The Closet reads its payload: when it is `{"tutorial": true}` and `player_data.get_flag(&"tutorial_seen")` is false and a **target** exists, the tutorial is active. Target = the first tile, in `get_tiles()` order (hats 0–8, then pets 0–8), whose state is **BUY**, else the first whose state is **WEAR**. On a Welcome Gift save that is the Pumpkin hat (hat tile 0). Opened any other way (menu, a gift payload with `tutorial_seen` true, or nothing affordable) there is no arrow and the flag is not touched. When the tutorial starts, focus goes to the target tile.
6. **The arrow follows the steps (FR45, approved sketch `sketches/crypt-closet-4-4.md` frame D).** A candy-yellow 24 × 20 `TutorialArrow` with a 1 px ink border, bobbing, never focusable, ignoring the mouse (it never blocks input):
   - **Buy step** (prompt closed, target not owned): pointing down, at (target tile centre x − 12, tile top − 24). Hat tile 0 → (38, 52); pet tile 0 → (434, 52).
   - **Confirm step** (the confirm prompt is open, whatever item it asks about): pointing right, left of Yes: (Yes left − 32, Yes centre y − 10) = (176, 222). It draws **above** the scrim.
   - **Wear step** (prompt closed, target owned, not worn): pointing down over the target tile again.
   - If the kid buys a different item than the target, that item becomes the target (the arrow moves to its Wear). No (or Esc, or a stale-prompt cancel) puts the arrow back on the Buy step. If nothing is left to point at (e.g. a debug F8 reset), the arrow hides but the tutorial stays active.
7. **The tutorial ends for good (FR45).** It ends, hides the arrow and calls `player_data.set_flag(&"tutorial_seen", true)` exactly once, when **any** item is equipped (`equipment_changed` with a non-empty id) or when the kid leaves the Closet (Esc or the Menu button, in `_leave()` before `navigate`). It never comes back on a later visit or a later gift payload.
8. **End-to-end (the Epic 4 deliverable).** On a fresh save: one Zombie Run → report card → Play Again or Menu → Welcome Gift (+100) → Open the Crypt Closet → the arrow guides Buy → Yes → Wear on the Pumpkin hat → Esc → menu shows the hat → start another run → the hat is on the zombie in play and on the report card. Covered by a new integration test and a manual walk (Task 7).
9. **Plain words (NFR9, NFR11).** "Welcome gift!", "+100", "Open the Crypt Closet": plain words a 6-year-old can read, at 16 px or more, nothing overflows, everything inside the 16 px margin, no timer. The arrow carries no text.
10. **Tests.** New: `tests/unit/test_welcome_gift.gd`, `tests/unit/test_tutorial_arrow.gd`, `tests/integration/test_first_purchase_flow.gd`. Updated: `test_report_card.gd`, `test_crypt_closet.gd`, `tests/integration/test_screen_flow.gd`. **No test may write the real save** (see Dev Notes "The real save trap"). The full suite passes. The gift card's screenshot is approved by Smuck before review (there is no mock or sketch for it).

## Tasks / Subtasks

- [x] **Task 1: Report card redirect (AC: 1)** — `scripts/screens/report_card.gd`
  - [x] 1.1 Add the seam `const PlayerDataScript: GDScript = preload("res://scripts/autoloads/player_data.gd")` and `var player_data: PlayerDataScript = null`, defaulted to `PlayerData` in `_ready()` (the `main_menu.gd` pattern).
  - [x] 1.2 Remember whether the payload had a `RunResult` (`_has_result`). In `_leave(screen, payload)`, after the guard and latch checks and before `navigate.call`: `if _has_result and not player_data.get_flag(&"welcome_bonus_claimed"): screen = Router.Screen.WELCOME_GIFT; payload = {}`. Read the flag at leave time, not in `_ready()`. Don't set or clear any flag here (the gift owns it).
  - [x] 1.3 Rewrite the header: drop "Reads nothing from PlayerData"; say it reads one flag, and that the first completed run's exit goes to the gift (Story 4.5).
- [x] **Task 2: `TutorialArrow` widget (AC: 6)** — `scenes/ui/tutorial_arrow.tscn` + `scripts/ui/tutorial_arrow.gd`
  - [x] 2.1 `class_name TutorialArrow extends Control`, size 24 × 20, `mouse_filter = MOUSE_FILTER_IGNORE`, `focus_mode = FOCUS_NONE`, hidden by default. `enum Direction { DOWN, RIGHT }`.
  - [x] 2.2 `_draw()`: a filled candy-yellow (`#FFD23F`) triangle with a 1 px ink (`#1E1428`, the same `INK` const value as `closet_item_tile.gd`) closed outline. DOWN: (0,0) (24,0) (12,20). RIGHT: (0,0) (24,10) (0,20). Palette colours as `const`s, like `closet_item_tile.gd`.
  - [x] 2.3 API: `func point_at(target: Rect2, direction: Direction) -> void` (global rect of the target; DOWN → `global_position = (target.get_center().x - 12, target.position.y - 24)`; RIGHT → `(target.position.x - 32, target.get_center().y - 10)`; shows it; `queue_redraw()`), `func get_direction() -> Direction`. Positions are whole pixels (round).
  - [x] 2.4 Bob: a vertical (DOWN) or horizontal (RIGHT) offset drawn in `_draw()` via `draw_set_transform`, updated in `_process` (`const BOB_PX := 2`, `const BOB_PERIOD_S := 0.6`, "look value, not a GDD number"). `position` stays at rest, so tests check it exactly. No tween.
- [x] **Task 3: Closet tutorial (AC: 5, 6, 7)** — `scripts/screens/crypt_closet.gd`, `scenes/screens/crypt_closet.tscn`
  - [x] 3.1 Add `%TutorialArrow` (instance of Task 2) as the **last child** of `CryptCloset`, after `%ConfirmPrompt`, so it draws above the scrim. Update `test_crypt_closet.gd:640` ("the prompt draws on top"): the prompt is drawn above every other child except the arrow.
  - [x] 3.2 Replace the bare `Router.take_payload()` with reading it: `var wants_tutorial: bool = payload.get("tutorial", false) == true`. After the tiles are built and refreshed: `if wants_tutorial and not player_data.get_flag(&"tutorial_seen")`: pick the target (AC 5); if there is one, `_tutorial_active = true`, `_tutorial_target = item id`, focus its tile.
  - [x] 3.3 `_update_tutorial()`: if not active → hide the arrow. Else: prompt open → RIGHT at `%ConfirmPrompt`'s `%YesButton` global rect; else target tile state WEAR → DOWN at the tile; BUY → DOWN at the tile; anything else → hide. Call it at the end of `_refresh()`, after `%ConfirmPrompt.open(...)` in `_on_tile_activated`, and at the end of `_on_confirm_answered` (No doesn't refresh). Also connect `%HatGrid.sort_children` and `%PetGrid.sort_children` to it: tile rects are only valid after the containers sort (Dev Notes "Layout timing").
  - [x] 3.4 `_on_inventory_changed(item_id)`: while active, `_tutorial_target = item_id` (the bought item is what to wear next), then the existing cancel + refresh.
  - [x] 3.5 `_on_equipment_changed(slot, item_id)`: while active and `item_id != &""` → `_end_tutorial()`, then the existing refresh.
  - [x] 3.6 `_end_tutorial()`: if not active, return; `_tutorial_active = false`; hide the arrow; `player_data.set_flag(&"tutorial_seen", true)`. In `_leave()`, call it after the `_leaving` / `is_transitioning` guard and before `navigate.call`. **Not** in `_exit_tree()` (test teardown would write a flag through whatever `player_data` the Closet holds; and a freed Closet must not touch PlayerData).
  - [x] 3.7 Test helpers: `is_tutorial_active() -> bool`, `get_tutorial_arrow() -> TutorialArrow`. Update the header comment (payload `{"tutorial": true}`, the three steps, when it ends; drop "Story 4.5 reads a tutorial flag").
- [x] **Task 4: The real Welcome Gift card (AC: 2, 3, 4, 9)** — rebuild `scenes/screens/welcome_gift.tscn` + `scripts/screens/welcome_gift.gd`
  - [x] 4.1 Keep the root name `WelcomeGift`, the script path and `%OpenClosetButton` (now a `PixelButton`, `theme_type_variation = &"PixelButton"`, `scripts/ui/pixel_button.gd`). Remove `Box`, `Heading`, `PayloadLabel`. Nodes per Dev Notes "Welcome Gift layout": `%Background`, `%Panel`, `%Ribbon`, `%Bow`, `%Sign` + `%Heading`, `%BrainIcon` (same two-`ColorRect` placeholder as `brain_counter.tscn`'s `Icon`/`Shade`), `%AmountLabel`, `%OpenClosetButton`. Every non-interactive node: `FOCUS_NONE` + `MOUSE_FILTER_IGNORE`.
  - [x] 4.2 Seams (tests assign before `add_child`): `@export var economy: EconomyConfig` (set to `data/economy.tres` in the scene), `var navigate: Callable` (→ `Router.go`), `var player_data: PlayerDataScript = null` (→ `PlayerData`), `var play_sfx: Callable` (→ `AudioManager.play_sfx`).
  - [x] 4.3 `_ready()`: default the seams; `Router.take_payload()` (consume); grant per AC 3 (`_grant()`); `%AmountLabel.text = "+%d" % bonus` (the configured bonus, also when already claimed, so the card reads the same); connect the button; `%OpenClosetButton.grab_focus()`.
  - [x] 4.4 Guard (AC 4): `_open_s` in `_process`; `_input` swallows pressed key/mouse events (and echoes) while `_open_s < INPUT_GUARD_S` or after leaving (copy `report_card.gd::_input`). `_unhandled_input`: `ui_accept` with no focus owner → `_open_closet()`; `ui_cancel` → `set_input_as_handled()` and nothing else.
  - [x] 4.5 `_open_closet()`: `_leaving` guard; `play_sfx.call(&"sfx_ui_click")`; `navigate.call(Router.Screen.CRYPT_CLOSET, {"tutorial": true})`.
  - [x] 4.6 Header comment: what it shows, grant-on-show and once-only, the seams, the guard, placeholder chrome until 5.0, a gift sound is Story 5.1.
- [x] **Task 5: Tests (AC: 10)**
  - [x] 5.1 `test_report_card.gd`: `_card()` injects a temp-dir `PlayerData` (copy `test_crypt_closet.gd::_make_player_data`) with `welcome_bonus_claimed = true` by default, so every existing navigation test keeps its meaning on any dev machine. New: flag false + result → Play Again, Menu, Esc and Enter-with-no-focus each record `[WELCOME_GIFT, {}]` once; flag false + **no** result → the requested screen; flag true → the requested screen; the guard still blocks the redirect; the card never sets the flag.
  - [x] 5.2 `tests/unit/test_welcome_gift.gd` (new): fresh save → brains +100 and flag true, one `brains_changed` with delta 100, one save request (the counting `SaveService` from `test_player_data.gd`); flag already true → brains unchanged, no `brains_changed`; null economy → `assert_push_error`, nothing granted, flag still false; `%AmountLabel` is "+100" (from the economy, test with an injected `EconomyConfig` of 7 → "+7"); button focused on open; press before the guard → nothing; after → `[CRYPT_CLOSET, {"tutorial": true}]` and `sfx_ui_click` once; a second press does nothing; Esc does nothing and is handled; payload consumed; text fit, ≥ 16 px, inside `Rect2(16, 16, 608, 328)` and rects equal to the layout table (copy `test_main_menu.gd`'s helpers).
  - [x] 5.3 `tests/unit/test_tutorial_arrow.gd` (new): hidden by default; `point_at` DOWN on `Rect2(16, 76, 68, 68)` → position (38, 52), size (24, 20); RIGHT on `Rect2(208, 216, 96, 32)` → (176, 222); `get_direction`; ignores the mouse, `FOCUS_NONE`; bob doesn't change `position`.
  - [x] 5.4 `test_crypt_closet.gd` (tutorial section): with `Router._store_payload({"tutorial": true})` and 100 brains: active, focus on hat tile 0, arrow DOWN at (38, 52) (await 2 frames for layout); open the prompt → RIGHT at (176, 222) and the arrow is after the prompt in the tree; No → back at (38, 52); Yes (set the prompt's `answer_delay_ms = 0`) → still DOWN at (38, 52), tile WEAR; Wear → arrow hidden, `tutorial_seen` true, `flags_changed` once; the tutorial does not restart on `_refresh()`. Also: no payload → inactive, flag untouched; payload + `tutorial_seen` true → inactive; payload + 0 brains → inactive; a pet-only affordable catalogue → arrow at (434, 52); Esc while active → flag true then `[MAIN_MENU, {}]`; Menu button the same; Esc while **inactive** → flag stays false; buying the ghost while the target is the hat → arrow moves to the ghost tile; F8-style `reset_all()` while active → no crash, arrow follows the new state.
  - [x] 5.5 `tests/integration/test_screen_flow.gd`: `_instance()` must give `WELCOME_GIFT` a temp-dir `PlayerData` (and a recorder `navigate`) **before** `add_child`, or `test_every_screen_instantiates` writes +100 and the flag into the real save. Add `test_welcome_gift_consumes_the_payload`. `FLOW_BUTTONS["WELCOME_GIFT"]` stays `["%OpenClosetButton"]`.
  - [x] 5.6 `tests/integration/test_first_purchase_flow.gd` (new, AC 8): one temp-dir `PlayerData` shared by every screen via seams: report card (result, flag false) → `[WELCOME_GIFT, {}]`; gift → brains = run brains + 100, `[CRYPT_CLOSET, {"tutorial": true}]`; Closet with that payload → arrow on the hat → buy → wear → `get_equipped(&"hat") == &"hat_pumpkin"`, `tutorial_seen` true; Esc → `[MAIN_MENU, {}]`; a `HatSlot`/`PetSlot` with `player_data` set to the same instance shows `hat_pumpkin`; a second report card → the requested screen (no gift); a Closet opened again with `{"tutorial": true}` → no arrow.
  - [x] 5.7 Run `"/c/Program Files/Godot/Godot.exe" --headless --path . --import` (new `class_name TutorialArrow`), then the full suite. Record the baseline at the start (1132 after 4.4's dev run; its review patches may have added some) and the final count.
  - [x] 5.8 Mutation pass, each must be caught: redirect without the `_has_result` check; redirect when the flag is true; gift grants when already claimed; flag set before / without the grant; literal 100 instead of the economy; no guard on the gift; tutorial starting without the payload; tutorial starting with `tutorial_seen` true; arrow not moving to Yes; arrow drawn under the scrim; tutorial not ending on equip; flag not set on Esc; flag set on Esc when the tutorial was inactive; `_end_tutorial` in `_exit_tree`. Report any survivor honestly.
- [x] **Task 6: Debug overlay check** — `scripts/debug/debug_overlay.gd` (READ; change only if needed)
  - [x] 6.1 The overlay's "Jump to Welcome Gift" now grants +100 on a save whose flag is false. That is the intended debug behaviour (it is how a dev tests the gift). Confirm `test_debug_overlay.gd` doesn't instance the real gift screen with the live `PlayerData` (it records `[WELCOME_GIFT, {}]` through a seam; keep it that way). Note it in deferred-work.
- [x] **Task 7: Manual walk and approval (AC: 2, 8, 9)**
  - [x] 7.1 Use a web debug export in the built-in browser pane (its save is in browser storage, so the real `save.json` isn't touched) or back up `save.json` first. Start from a fresh save (F8). Walk: Title → Menu → Zombie Run to the end → report card → Play Again → **Welcome gift** (+100, button focused, mash Enter right away: the first presses do nothing) → Open the Crypt Closet → arrow over the Pumpkin hat → Enter → arrow left of Yes → Enter → jingle, arrow back over the tile (now Wear) → Enter → Wearing, arrow gone → Esc → menu zombie wears the hat → another Zombie Run (the hat on the zombie in play, the pet in the HUD pet slot) → report card (Professor Zombie wears the hat and the pet sits beside him, per 4.3) → Menu: **no** gift. Second pass from a fresh save: gift → Closet → Esc straight away → menu; Closet again from the menu: no arrow. Mouse-only pass of the gift and the guide.
  - [x] 7.2 Screenshots to `_bmad-output/implementation-artifacts/screenshots/`: `4-5-welcome-gift.png`, `4-5-tutorial-buy.png`, `4-5-tutorial-confirm.png`, `4-5-tutorial-wear.png`. Show them to Smuck with the gift layout table. Record the answer verbatim with the date in `## Layout Approval`. **Don't move to review without it.** If Smuck changes the gift layout, follow it and update the rects test.
  - [x] 7.3 If `save.json` was backed up, restore it and say so in the Debug Log.
- [x] **Task 8: Wrap-up**
  - [x] 8.1 LF line endings on every touched text file.
  - [x] 8.2 `deferred-work.md`: strike with "Done in 4.5: …" the 2.9 item "First completed run goes through the Welcome Gift" and the 4.4 item "The tutorial arrow and the `tutorial_seen` flag"; note on the 1.3 Router item that the gift does **not** redirect from `_ready()` (the decision is made on the report card), so it is not affected. Add "Deferred from: dev of story 4-5" with at least: final gift card art (ribbon, bow, brain icon) and the hand-drawn arrow (5.0); a gift sound and the counter tick-up (5.1); a tab closed mid-tutorial leaves `tutorial_seen` false, which is harmless because the tutorial only starts from the gift and the gift never returns; the debug jump grants on an unclaimed save; the "Play with it!" button idea (post-MVP, epics design note).
  - [x] 8.3 Fill in the File List, Debug Log (counts, mutation pass) and Change Log. Suggested commit: `Story 4.5: welcome gift and guided first purchase`.

## Layout Approval

<!-- Task 7.2: Smuck's verbatim approval (or requested changes) of the gift card and tutorial screenshots, with the date. -->

2026-10-06, Smuck: "Approve as drawn" (the four `4-5-*.png` screenshots, including the ribbon running behind "+100").

## Dev Notes

### What this story is (and isn't)

- **Is:** the report card's one-time redirect to the gift; the real Welcome Gift card (placeholder chrome); the grant of `EconomyConfig.welcome_bonus` and the `welcome_bonus_claimed` flag; a reusable `TutorialArrow` widget; the Closet's three-step guide and the `tutorial_seen` flag; an end-to-end integration test that closes Epic 4.
- **Isn't:** any change to `PlayerData`, `SaveSchema` or the save (`add_brains`, `get_flag`, `set_flag` and both flags exist since 1.7 / 4.1; **don't add methods**); a new screen in the Router (`WELCOME_GIFT` is registered since 1.3); final art (5.0), gift/arrow sounds and the counter tick-up (5.1); a "Play with it!" button after Wear (post-MVP design note in epics.md); any change to `ConfirmPrompt`, `ClosetItemTile`, `LevelCard` or the main menu.

### Welcome Gift layout (no mock, no sketch: build this, then Smuck approves the screenshot)

Canvas 640 × 360, 16 px margin, 4 px grid, Press Start 2P (every glyph = font size wide, line height = font size, measured in 2.5 / 4.4). Placeholder chrome: square `StyleBoxFlat`s / `ColorRect`s in palette colours, 1 px ink borders, no `corner_radius`.

```
y=36            ┌─bow─┐                         pumpkin bow (placeholder: a 48x16 pumpkin box)
y=52   ┌────────────┤rib├────────────┐          wood panel, wood-dark frame, 1 px ink
y=68   │   ┌── Welcome gift! ──┐     │          parchment sign, 24 px ink
y=140  │        [brain] +100         │          32 px brain icon + "+100" at 32 px, chalk
y=236  │  [ Open the Crypt Closet ]  │          PixelButton, focused
y=292  └────────────────────────────┘
```

| Element | x | y | w | h | Font | Notes |
|---|---|---|---|---|---|---|
| Background (night) | 0 | 0 | 640 | 360 | – | full rect |
| Panel (wood `#8A5228`, wood-dark frame, 1 px ink) | 120 | 52 | 400 | 240 | – | |
| Ribbon (pumpkin `#F07A1C`, vertical) | 308 | 52 | 24 | 240 | – | behind the sign, the amount and the button (drawn before them) |
| Bow (pumpkin, 1 px ink) | 296 | 36 | 48 | 16 | – | sits on the panel's top edge |
| Sign (parchment, 1 px ink) | 156 | 68 | 328 | 40 | – | |
| "Welcome gift!" | 164 | 76 | 312 | 24 | 24 | 13 × 24 = 312, centred, ink |
| Brain icon (art-brain-pink + shade, as `brain_counter.tscn`) | 236 | 140 | 32 | 32 | – | |
| "+100" | 276 | 140 | 128 | 32 | 32 | 4 × 32 = 128, chalk; the pair (168 px) is centred on x 320 |
| "Open the Crypt Closet" (`PixelButton`) | 144 | 236 | 352 | 32 | 16 | 21 × 16 = 336 + 8 px pad each side |

"+100" at 32 px is a look choice (DESIGN's 32 px size is the target glyph; the stat style is 16 px). It's the moment's number, so it's big; Smuck can shrink it at the screenshot gate. A 3-digit bonus is the worst case the label must fit ("+999" = 128 px).

### Tutorial rules (one place, derived from state)

- The step is **derived from state every time** (`_update_tutorial()`): prompt open → Yes; else the target's tile state (BUY → the tile; WEAR → the tile; otherwise hidden). No step counter to drift out of sync with a debug F5/F8, a stale-prompt cancel, or a kid who wanders off to another tile.
- EXPERIENCE says "first affordable item → Buy → Yes → Wear"; the approved sketch's frame D collapses "first affordable item" and "Buy" into one position (a Buy tile shows its price on the pumpkin tag, and Enter on it *is* Buy). So there are three arrow positions: tile (Buy), Yes, tile (Wear).
- The arrow points at the target, not at the focus: the kid can explore other tiles ("everything else still usable", EXPERIENCE State Patterns), and the arrow waits.
- The tutorial ends on **any** equip, not only the target's (FR45 "the first item is worn"), and on leaving. A tab closed mid-tutorial leaves `tutorial_seen` false; that's harmless, because the tutorial only starts from the gift payload and the gift is never shown again.
- Closet entry points: the gift sends `{"tutorial": true}`; the menu sends `{}`. Never infer the tutorial from flags alone (a player who skipped through Esc must not get the arrow from the menu).

### The real save trap (read before writing tests)

- `test_screen_flow.gd::_instance()` instances every screen with the **live autoloads**, and `_ready()` runs even with `PROCESS_MODE_DISABLED`. The new gift grants in `_ready()`, so without a seam `test_every_screen_instantiates` would add 100 brains and set the flag in the developer's real `save.json`. Give `WELCOME_GIFT` a temp-dir `PlayerData` in `_instance()` before `add_child`.
- `test_report_card.gd` uses the live `PlayerData` today. After Task 1 its navigation tests depend on the live `welcome_bonus_claimed`: on a fresh dev machine Play Again would go to the gift and the old asserts would fail. Inject a temp `PlayerData` with the flag set in `_card()`.
- The Closet's `_end_tutorial()` writes a flag: only via `player_data` (the seam), only from `_leave()` / `equipment_changed`, never `_exit_tree()`.

### Layout timing

Tiles live in `GridContainer`s; their rects are only right after the containers sort (deferred, after `_ready()`; 4.4's rect test awaits 2 frames). So `_update_tutorial()` placed from `_ready()` would read zero rects. Connect both grids' `sort_children` to `_update_tutorial` (and tests `await wait_process_frames(2)` before asserting positions). The confirm prompt's Yes button is absolutely positioned (208, 216, 96 × 32), so its rect is right at once.

### Existing code: current state, what changes, what must be preserved

- `scripts/screens/report_card.gd` (UPDATE). Today: `_leave(screen, payload)` is the only navigation, guarded by `REPORT_CARD_INPUT_GUARD_S` (1.0 s, counted in `_process`) and `_leaving`; Play Again → `RUN {"level_id"}`, Menu/Esc → `MAIN_MENU {}`, Enter with no focus → Play Again. A missing `RunResult` logs a warning and shows zeros. Change: the redirect in `_leave` and the `player_data` seam. Preserve: everything else, including the reveal, stamp, focus styling and Professor Zombie's slots.
- `scripts/screens/welcome_gift.gd` / `scenes/screens/welcome_gift.tscn` (REPLACE). Today: a placeholder (heading, payload label, plain `Button` `%OpenClosetButton` → `Router.go(CRYPT_CLOSET)`). Keep the paths, the root name and `%OpenClosetButton` (`test_screen_flow.gd` FLOW_BUTTONS).
- `scripts/screens/crypt_closet.gd` / `.tscn` (UPDATE). Today (4.4, after review patches): seams `navigate`, `is_transitioning`, `player_data`, `play_sfx`, `@export catalogue`; `Router.take_payload()` discarded; `_refresh()` from the four `PlayerData` signals; `_on_confirm_answered` restores background focus, refocuses the tile, buys, plays `sfx_purchase`; `_cancel_stale_prompt()` on brains/inventory/profile changes; `_leave()` with `_leaving` + `process_frame` release (no await: the 4.4 review fix). `%ConfirmPrompt` is the last child today. `ConfirmPrompt` closes **before** emitting `answered`, so in `_on_confirm_answered` `is_open()` is already false. Its `answer_delay_ms` (300) ignores Yes/No right after open: tests set it to 0. Preserve all of it.
- `scripts/autoloads/player_data.gd` (READ ONLY). `add_brains(amount)` (negative → error, 0 → no-op; emits `brains_changed(total, amount)`, requests a save); `get_flag` / `set_flag` (known flags only; same value → no signal, no save; emits `flags_changed`); `SaveService.request_save()` coalesces with `call_deferred`, so the grant and the flag land in **one** write at the end of the frame.
- `data/economy.tres` (READ). `welcome_bonus = 100`. `EconomyConfig` default is 0 (neutral; test_catalogue asserts it).
- `scripts/ui/pixel_button.gd` + `PixelButton` theme variation (REUSE for the gift button). `scenes/ui/brain_counter.tscn` (READ: copy the `Icon`/`Shade` `ColorRect` look for the gift's brain icon; don't instance the counter, the gift shows "+100", not a total).
- `scripts/debug/debug_overlay.gd` (READ). `%JumpGiftButton` → `_jump(WELCOME_GIFT, {})`.

### Key design decisions (follow these; Smuck can overrule)

- **The gift is decided on the report card, granted on the gift.** The report card reads the flag at leave time; the gift grants and sets it on show (EXPERIENCE "welcome-gift-card": "Grants +100 and sets `welcome_bonus_claimed` on show"). No screen redirects from its own `_ready()`, so the 1.3 Router caveat (a `go()` during a transition is dropped) never bites.
- **Grant then flag, same frame.** `add_brains` then `set_flag`: one coalesced save, so a reload can never see the flag without the brains or the brains twice.
- **Only a report card with a `RunResult` redirects.** Every real report card has one (`run_frame.gd` passes it); a debug jump without one shouldn't spend the once-per-save gift.
- **Esc on the gift does nothing.** It has one button; Esc to the menu would skip the Closet the gift exists to teach.
- **A 0.5 s guard on the gift**, the same idea as the report card's FR21 guard and the prompt's 300 ms (the 4.4 review decision): a kid mashing Enter must see the gift.
- **The arrow is a reusable widget, the steps live in the Closet** (the Closet already owns the prompt, the tiles and Esc).

### Godot 4.7 notes

- No new engine features or libraries; nothing to research beyond what 4.4 used. `Control._draw()` with `draw_colored_polygon()` + `draw_polyline()` (closed: repeat the first point) for the arrow; `draw_set_transform(Vector2(0, offset))` for the bob, so `position` stays exact.
- `Container.sort_children` is emitted after the container lays out its children.
- `get_global_rect()` on the Closet's children equals local coordinates (the Closet is a full-rect root at the origin).

### Testing notes

- Suite: `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`, after `--import`.
- Temp `PlayerData`: `test_crypt_closet.gd::_make_player_data` (CountingSave in `TEST_DIR`). The counting `SaveService` lets the gift test assert exactly one save request per frame's worth of changes.
- Router payloads in tests: `Router._store_payload({...})` before instancing; `after_each` → `Router.take_payload()`.
- GUT 9.7.1: `assert_push_error` / `assert_push_warning` match substrings; keep log strings distinctive ("welcome gift: no economy", "welcome gift already claimed").
- The flaky `test_audio_manager` pool test (deferred-work 4.2): rerun once before investigating.

### Previous story intelligence

- **4.4:** the Closet's seams, payload consumption and helper hooks (`get_tile`, `get_confirm_prompt`) were built for this story; the arrow positions are approved in frame D. Review patches: the prompt's 300 ms answer delay (tests set `answer_delay_ms = 0`), no `await` in `_leave()` (it frees mid-await), stale prompts are cancelled on PlayerData changes, rejected equip plays no click. The live walk ran in a web debug export in the browser pane (its own save in browser storage); the run timer didn't advance there once (tab throttling), so the report card wasn't reached. Plan for that in Task 7 (keep the pane focused, or use a desktop run with a backed-up save). 1050 → 1132 tests, 12/12 mutations caught.
- **4.2 / 4.3:** text-fit and margin helpers in `test_main_menu.gd`; hover moves focus only on real mouse motion; slots default to the live `PlayerData` unless their own seam is set (the integration test must set it on any slot it checks).
- **2.9:** report card guard and single-exit design; its header already names this story as the hook.
- **Traps:** LF line endings, UTF-8, typed `for` variables (`untyped_declaration = Error` covers tests too), prefer scratchpad scripts over heredocs with apostrophes, `assert()` shows as SCRIPT ERROR in headless GUT (use `Log` + safe returns).

### Git intelligence

- One commit per story with code, data, tests, screenshots and the story file. Last: `96c0223 Story 4.4: Crypt Closet (code review patches applied, done)`. The 4.4 story file's AC 1 has the review findings pasted into its middle (a merge slip in the doc only); leave it, it's a done story.

### Project Structure Notes

- New: `scenes/ui/tutorial_arrow.tscn`, `scripts/ui/tutorial_arrow.gd`, `tests/unit/test_welcome_gift.gd`, `tests/unit/test_tutorial_arrow.gd`, `tests/integration/test_first_purchase_flow.gd`, screenshots `4-5-*.png`. `scenes/ui/` / `scripts/ui/` is the home for reusable widgets (architecture Directory Structure).
- Replaced: `scenes/screens/welcome_gift.tscn`, `scripts/screens/welcome_gift.gd`.
- Updated: `scripts/screens/report_card.gd`, `scripts/screens/crypt_closet.gd`, `scenes/screens/crypt_closet.tscn`, `tests/unit/test_report_card.gd`, `tests/unit/test_crypt_closet.gd`, `tests/integration/test_screen_flow.gd`, `deferred-work.md`, `sprint-status.yaml`.
- No data changes: `data/economy.tres` already has `welcome_bonus = 100`.

### Project Context Rules

- No `project-context.md`. Binding rules from `_bmad-output/game-architecture.md` and the UX spines:
  - Typed GDScript everywhere; `:=` only when the type is obvious. `%UniqueName` node refs; no `/root/` paths or `get_parent()` chains.
  - Typed, past-tense signals connected in code; autoload connections disconnected in `_exit_tree`. No event bus (ADR-5).
  - Boundary 4: screens change state only through `PlayerData` methods and navigate only through `Router` (here via the `navigate` seam). Boundary 3: only `AudioManager` plays audio, only `SaveService` touches files. Boundary 5: `.tres` in `data/`, classes in `scripts/resources/`.
  - Game numbers from data (`EconomyConfig.welcome_bonus`), never literals. Look values (guard seconds, bob px/period) are `const`s marked "look value, not a GDD number".
  - Palette colours only; square boxes until 5.0; the night scrim at 60 % is the one alpha exception.
  - Log tags: `&"economy"` for the grant, `&"ui"` for screen/widget problems. NFR16: missing data logs and never crashes. NFR9 / NFR11: plain words, 16 px floor, no timers.
- Tools: Godot `/c/Program Files/Godot/Godot.exe`; GUT 9.7.1; the Godot MCP server and the built-in browser pane (`web-debug` in `.claude/launch.json`) for the manual walk.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 4.5: Welcome Gift and Guided First Purchase] (ACs and the "Closet → Esc → Menu" design note); Epic 4 goal; FR24, FR44, FR45; NFR9, NFR11, NFR16
- [Source: _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md] M5 (l.152–155), Economy welcome bonus (l.273–275), Screens & Flow (l.352), save contents (l.399)
- [Source: _bmad-output/game-architecture.md] Screen Flow (`WELCOME_GIFT`, payloads, l.180–196), save schema flags (l.253), balancing values in `EconomyConfig` (l.461), Directory Structure (l.603–674), boundaries
- [Source: …/ux-designs/…/EXPERIENCE.md] Screen inventory (l.40–44), Voice and Tone (l.64), welcome-gift-card and tutorial-arrow patterns (l.91–96), State Patterns (l.135–137), Flow 2 (l.255–265), Open Question 6
- [Source: …/ux-designs/…/DESIGN.md] tutorial-arrow and welcome-gift-card tokens (l.216–226), pumpkin / candy-yellow roles (l.363–364), typography (l.401–405), Components (l.500–501)
- [Source: …/ux-designs/…/sketches/crypt-closet-4-4.md] Frame D and the element table's arrow row (approved 2026-10-06)
- [Source: _bmad-output/implementation-artifacts/4-4-crypt-closet.md] (Closet seams, prompt, review patches), 2-9 (report card guard), 4-1 (flags), 4-3 (slot seams)
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] 1.3 Router dropped-redirect caveat, 2.9 "first completed run goes through the Welcome Gift", 4.4 "tutorial arrow and `tutorial_seen`"
- [Source: scripts/screens/report_card.gd, crypt_closet.gd, welcome_gift.gd, main_menu.gd], [Source: scripts/ui/confirm_prompt.gd, pixel_button.gd, brain_counter.gd], [Source: scripts/autoloads/player_data.gd, router.gd, save_service.gd#request_save], [Source: scripts/resources/economy_config.gd, data/economy.tres], [Source: tests/integration/test_screen_flow.gd, tests/unit/test_report_card.gd, test_crypt_closet.gd, test_main_menu.gd, test_player_data.gd]

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Debug Log References

- Suite: 1134 passing at the start (4.4 plus its review patches), 1187 / 1187 at the end (+53: 9 report card, 18 welcome gift, 7 tutorial arrow, 17 Closet tutorial, 2 first purchase flow, 1 screen flow, minus none).
- Mutation pass (Task 5.8), against the six touched test files: 15 / 15 caught. Redirect without `_has_result`; redirect when the flag is true; gift grants when already claimed; flag without the grant; flag set before (instead of with) the grant; literal 100; no guard on the gift; tutorial without the payload; tutorial with `tutorial_seen` true; arrow not moving to Yes; arrow under the scrim (scene order swapped); tutorial not ending on equip; flag not set on Esc; flag set on Esc when inactive; `_end_tutorial` in `_exit_tree`. No survivors.
- **Real save incident (fixed):** my first test run after writing the new gift script came before the `test_screen_flow.gd` seam (Task 5.5), so `test_every_screen_instantiates` granted into the real `save.json` (brains 59 -> 159, `welcome_bonus_claimed` false -> true), exactly the trap the Dev Notes describe. The same write left the previous file as `save.bak`; `diff` showed only those two lines. I restored `save.json` from `save.bak` (bad copy kept in the session scratchpad). Every later run (full suite twice, the mutation pass, the screenshot script) left the save byte-identical to `save.bak`.
- A Closet test caught a real bug: `payload.get("tutorial", false) == true` is a script error when the value is a String. The check is now `tutorial is bool and tutorial`.
- "One save" in the gift test is counted as writes (the counting `SaveService` also overrides `save_now`): `add_brains` and `set_flag` make two requests that coalesce into one write at the end of the frame, and a reload sees both.
- Task 7.1 live walk (web debug export, built-in browser pane, fresh save via F3 + F8 twice): Title -> Menu (0 brains, no hat) -> Zombie Run -> typed 5 letters -> F6. The run reached ENDING and the dance, then stalled: the pane was hidden, which throttles the page to about 1 fps (the overlay showed FPS 2, frame 1016 ms). Smuck brought the pane on screen (60 fps) and the walk was finished:
  - Pass 1 (that fresh save): report card (5 keys, 11 brains incl. +10 bonus) -> Play Again -> **Welcome gift** (+100, button focused); Enter mashed twice straight after Play Again did not skip the gift -> Enter -> Closet with 111 brains, arrow over the Pumpkin hat, focus on it, "Buy" -> Enter -> prompt, arrow left of Yes -> Enter -> 11 brains, tile "Wear", arrow back over it -> Enter -> check mark, "Wearing", arrow gone -> Esc -> menu zombie wears the hat -> second Zombie Run: the hat on the zombie in play -> F6 -> report card: Professor Zombie wears the pumpkin hat under the mortarboard -> Esc -> straight to the menu, **no** gift (22 brains). No pet was bought on this pass, so the HUD and report card pet slots stayed empty (the pet display itself is 4.3's).
  - Pass 2 (fresh save via F8, gift via the overlay's "Welcome gift" jump, which grants on an unclaimed save): Esc on the gift did nothing -> Enter -> Closet (arrow shown) -> Esc straight away -> menu with 100 brains, nothing bought -> Crypt Closet from the menu: no arrow.
  - Pass 3, mouse only (fresh save, overlay jump): click "Open the Crypt Closet" -> click the Pumpkin hat -> prompt with the arrow left of Yes -> click Yes -> "Wear" with the arrow over the tile -> click -> "Wearing", arrow gone. Menu by click.
  - The real `save.json` was never used by the walk (the web build keeps its own save in browser storage); it still equals `save.bak` (the pre-session state, see the incident above).
- Task 7.2 screenshots were rendered instead in a real (non-headless) Godot window by a temporary `tools/_shot_4_5.gd` (deleted after use) with a temp-dir PlayerData: the gift, then the Closet opened with `{"tutorial": true}` at 100 brains (Buy), the prompt (Yes) and after Yes (Wear). They show the real scenes and the real tutorial logic, not a mock.

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created.
- Report card: a `player_data` seam and `_has_result`; `_leave()` swaps the target for `[WELCOME_GIFT, {}]` while `welcome_bonus_claimed` is false, reading the flag at leave time and never writing it. Guard and latch unchanged.
- `TutorialArrow` (`scenes/ui/`, `scripts/ui/`): 24 x 20 candy-yellow triangle, 1 px ink outline, `point_at(rect, DOWN|RIGHT)` at whole pixels, bob drawn with `draw_set_transform` so `position` stays exact, ignores the mouse, never focusable, hidden by default.
- Crypt Closet: reads `{"tutorial": true}`; with `tutorial_seen` false and a BUY (else WEAR) tile, the first one is the target and gets focus. `_update_tutorial()` derives the step from state (prompt open -> left of Yes; else the target tile while Buy / Wear; else hidden) and runs after every refresh, prompt open / answer, and both grids' `sort_children`. A bought item becomes the target; any equip or leaving (`_leave()`, before navigate) ends it and sets `tutorial_seen` once. Nothing in `_exit_tree`. The arrow is the last child, above the prompt's scrim.
- Welcome Gift rebuilt per the layout table: night background, wood panel with wood-dark frame, pumpkin ribbon and bow, parchment sign "Welcome gift!" (24 px), 32 px brain icon + "+N" (32 px, chalk, from `EconomyConfig.welcome_bonus`), one focused `PixelButton` "Open the Crypt Closet". Grants and sets the flag on show, once; already claimed logs `economy` info; no economy logs an error and the button still works. 0.5 s guard counted in `_process`; Esc is handled and does nothing; the button goes to `[CRYPT_CLOSET, {"tutorial": true}]` once with `sfx_ui_click`.
- Tests: `test_report_card.gd` now gives every card a temp-dir PlayerData with the flag set (no more dependence on the live save); `test_screen_flow.gd` gives `WELCOME_GIFT` a temp PlayerData and recorders before `add_child`.
- Debug overlay (Task 6): no change needed. Its test records the jump through the seam and never instances the gift. The jump now grants on an unclaimed save; noted in deferred-work.
- Task 7: Smuck approved the screenshots as drawn (2026-10-06); the live walk passed on three passes (keyboard end to end, Esc-skip, mouse only). See the Debug Log.

### File List

- `scripts/screens/report_card.gd` (modified)
- `scripts/screens/crypt_closet.gd` (modified)
- `scenes/screens/crypt_closet.tscn` (modified)
- `scripts/screens/welcome_gift.gd` (replaced)
- `scenes/screens/welcome_gift.tscn` (replaced)
- `scripts/ui/tutorial_arrow.gd` (new) + `.uid`
- `scenes/ui/tutorial_arrow.tscn` (new)
- `tests/unit/test_report_card.gd` (modified)
- `tests/unit/test_crypt_closet.gd` (modified)
- `tests/unit/test_welcome_gift.gd` (new) + `.uid`
- `tests/unit/test_tutorial_arrow.gd` (new) + `.uid`
- `tests/integration/test_screen_flow.gd` (modified)
- `tests/integration/test_first_purchase_flow.gd` (new) + `.uid`
- `_bmad-output/implementation-artifacts/screenshots/4-5-welcome-gift.png`, `4-5-tutorial-buy.png`, `4-5-tutorial-confirm.png`, `4-5-tutorial-wear.png` (new)
- `_bmad-output/implementation-artifacts/deferred-work.md` (modified)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified)
- `_bmad-output/implementation-artifacts/4-5-welcome-gift-and-guided-first-purchase.md` (this file)

### Change Log

- 2026-10-06: Story 4.5 implemented (report card redirect, real Welcome Gift card, TutorialArrow, Closet guided first purchase, tests 1134 -> 1187, 15/15 mutations caught). Screenshots rendered.
- 2026-10-06: Smuck approved the layout as drawn; live walk finished in the browser pane (three passes). Status -> review.

### Review Findings

- [x] [Review][Patch] Leaving the Closet without equipping must not end the tutorial (decided: end only on equip); update `test_skipping_the_closet_with_esc_ends_the_tutorial_for_good` [crypt_closet.gd `_leave`]
- [x] [Review][Patch] Null economy: gift never sets the flag, so every report card exit redirects to a "+0" gift forever [welcome_gift.gd:67, report_card.gd:162]
- [x] [Review][Patch] `_on_inventory_changed` retargets the arrow on any inventory change, not just the kid's confirmed purchase (`_pending` is already known) [crypt_closet.gd:343]
- [x] [Review][Patch] `_leave` ends the tutorial and sets `tutorial_seen` before navigate is known to succeed; a refused navigate leaves the kid in the Closet with no arrow [crypt_closet.gd:365-382]
- [x] [Review][Patch] Arrow recovery: unequip (item_id == &"") or a vanished target tile leaves the arrow hidden with the tutorial still active [crypt_closet.gd:356, 419]
- [x] [Review][Patch] Arrow can use stale rects: repositions only on grid `sort_children`; `%YesButton` rect is read right after `open()` before layout settles [crypt_closet.gd:81, 410]
- [x] [Review][Patch] `get_node("%YesButton")` reaches across a scene boundary; expose an accessor on ConfirmPrompt [crypt_closet.gd:~416]
- [x] [Review][Patch] `AmountLabel` carries a literal `+100` in the scene, against AC 2 "never a literal" [welcome_gift.tscn]
- [x] [Review][Patch] Test gaps: already-claimed `Log.info` not asserted (AC 3); refused navigate in Closet; null-economy redirect loop; unavailable/removed catalogue item at tutorial start [test_welcome_gift.gd, test_crypt_closet.gd, test_report_card.gd] — added all but the already-claimed Log.info assertion (not capturable in GUT)
- [x] [Review][Defer] Integration test checks only PlayerZombie HatSlot/PetSlot wiring, not a real run or report card (AC 8 prose) [test_first_purchase_flow.gd] — deferred, matches Task 5.6 wording
- [x] [Review][Defer] Tests hard-code the 100 bonus and arrow pixel coordinates [tests/] — deferred, brittle but not wrong
