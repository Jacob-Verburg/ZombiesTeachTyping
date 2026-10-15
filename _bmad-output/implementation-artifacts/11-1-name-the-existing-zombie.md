---
baseline_commit: b992bce7ac5b306281910057b4c859cd8d8da4b1
---

# Story 11.1: Name the Existing Zombie

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a kid who already plays,
I want to give my zombie a name when profiles arrive,
so that my brains and hats are clearly mine.

## Acceptance Criteria

1. **The title sends an unnamed zombie to the name screen (FR78, FR23, FR24).** When the title screen advances (any key except Esc, or a click; audio unlock and UI click unchanged), it goes to a new `Router.Screen.NAME_ZOMBIE` if `PlayerData.get_zombie_name()` is empty, and to `MAIN_MENU` exactly as today when the active profile already has a name. This applies to every save whose active profile has an empty `name`: an old MVP/v5 save **and** a brand-new save (both store `"name": ""`). Nothing else in the flow changes: report card, Closet, Progress, pause → Quit to Menu all still go straight to the menu.
2. **A plain-words name screen (FR78, NFR9, DESIGN.md).** `NAME_ZOMBIE` is **appended after `TRENDS`** in `Router.Screen` (no existing value moves) and maps to `res://scenes/screens/name_zombie.tscn` (script `scripts/screens/name_zombie.gd`). It shows the player's own zombie wearing the equipped hat with the equipped pet beside it (same `player_zombie.tscn` + `PetSlot` as the main menu), a parchment sign asking for the name, the name field and one `%DoneButton`. Copy is `[ASSUMPTION — Gate 1]`: heading "Name your zombie!", button "Done" with an "Enter" keycap beside it. The menu music keeps playing (`play_music(&"mus_menu")`). The payload is consumed and ignored.
3. **Name rules: letters and spaces only, 1–12 characters.** Typing a letter `A–Z` / `a–z` adds it (case kept as typed); Space adds one space only between words (never first, never two in a row); Backspace removes the last character; every other key (digits, punctuation, accented letters, Tab, arrows, echo/repeat events, Ctrl/Alt/Meta combos) adds nothing and is never an error (no bonk, no shake, no red). The field stops accepting characters at 12. A name is valid when, after removing a trailing space, it has 1–12 characters and at least one letter. The rules live in one pure helper, `ZombieName` (`scripts/core/zombie_name.gd`), and `PlayerData.set_zombie_name()` re-checks them (it never trusts the screen).
4. **Done.** Enter, or a click on `%DoneButton`, with a valid name: saves it with `PlayerData.set_zombie_name()`, plays the UI click and goes to `MAIN_MENU` exactly once. With an empty / invalid name, Enter and the button do nothing except a soft wiggle of the field (no sound, no text, no error) and the button looks disabled-but-focusable while the name is empty `[ASSUMPTION — Gate 1]`. Esc does nothing (there is nowhere to go back to; the name screen is reached only from the title).
5. **The profile is untouched apart from the name (FR78, ADR-2).** `set_zombie_name()` writes only `profiles.<active>.name` (the cleaned name) and requests one save. Brains, owned/equipped items, flags, tier/placement, settings, bests, run history, level unlocks, used passages, last themes and lifetime are byte-for-byte the same before and after (a GUT test compares the whole profile Dictionary minus `name`). It emits a new typed signal `zombie_name_changed(name: String)` and does nothing (no signal, no save) when the cleaned name equals the stored one.
6. **No migration (ADR-2).** `"name": ""` has been in `SaveSchema.profile_defaults()` since v1, so `GameConstants.CURRENT_SCHEMA` stays **5**, `migration_steps()` is unchanged and no fixture changes. A junk stored name (a number, null, an array) is already replaced by `""` by `SaveSchema._merge`; `get_zombie_name()` additionally returns `""` for any stored String that is not a valid name (a hand-edited `"!!!"` or a 40-character string), so that save also gets the name screen.
7. **The name is never logged (NFR12).** No `Log.*`, `print`, `push_warning` or `push_error` line anywhere carries the name or the typed characters (also not in DEBUG / `verbose_typing`). `set_zombie_name()` logs at most `[INFO][save] zombie named` and, for a rejected name, `[WARN][save] set_zombie_name: invalid name` — no name, no length. A GUT test proves it for PlayerData (see Testing). The debug overlay shows nothing new. The name does appear in `save.json` and the Ctrl+Shift+E save export (that is the parent's own save file, not a log).
8. **Browser keys while naming (ARCH WebPlatform, Story 5.3).** The name screen sets `WebPlatform.capture_keys = true` in `_ready()` and `false` in `_exit_tree()` (the `keyboard_test.gd` / `run_frame.gd` pattern), so Space never scrolls the page, Backspace never navigates and `'` / `/` never open Firefox quick-find while a kid types a name. `test_screen_flow.gd`'s `capture_keys` guard (before_each / after_all) stays green.
9. **Layout and readability (NFR7, DESIGN.md, Gate 1).** 640×360, everything inside the 16 px margin, nothing overlaps, no clipped text. The typed name is ≥ 24 px (Press Start 2P: 24 px per glyph → 12 characters = 288 px; the field is wide enough for 12 `W`s plus the caret). A caret shows where the next letter goes (blinking is allowed but ≤ 3 flashes per second; a steady underline is fine). Focus is candy yellow only (DESIGN.md). No `StyleBoxFlat`, no `draw_*` calls; the field reuses an existing theme box (e.g. `Sign` / parchment or `Chalkboard`) through a theme type variation. `%DoneButton` ≥ 32 px tall and is the only focusable Control. The new scene is walked by `test_no_placeholder_chrome.gd`, `test_plain_words.gd`, `test_readability.gd` and `test_screen_flow.gd`.
10. **Approval gates.** Gate 1: a layout sketch of the name screen (empty and filled states) plus the copy list, approved by Smuck **before** wiring visuals. Gate 2: in-game screenshots (empty, a filled 12-character name, the zombie with a hat and pet, grayscale of the filled state) approved by Smuck. Record each answer verbatim with the date under `## Art Approval`. No new sound (UI click only), no new sprites: no Audio or Art gate beyond these.
11. **No regressions.** Full GUT suite green and the count only goes up; zero `Parse Error|Compile Error|Failed to load script`; `SCRIPT ERROR` / `WARNING` counts unchanged except deliberate, asserted ones. All existing PNG/WAV byte-identical. The real `user://save.json` sha256 is identical before and after every suite run and manual check (temp `user://` dirs only).

## Tasks / Subtasks

- [x] **Task 1: Baseline** (AC: 11)
  - [x] 1.1 `Godot.exe --headless --path . --import`, then the full suite: `Godot.exe --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` (log to a scratch file). Record tests/passing, `SCRIPT ERROR` count, `WARNING` count and zero `Parse Error|Compile Error|Failed to load script`. Expected from 10.5's wrap-up: 2239 / 2239, 3 / 178 (re-measure: 10.5's review may have added tests).
  - [x] 1.2 Record the real save's sha256 (`%APPDATA%/Godot/app_userdata/ZombiesTeachTyping/save.json`).

- [x] **Task 2: Pure name rules** (AC: 3, 6) — do first.
  - [x] 2.1 `scripts/core/game_constants.gd`: `ZOMBIE_NAME_MAX_LENGTH: int = 12` with a `## FR78 / Story 11.1:` comment (a content rule from the epics, not a balancing number, so `GameConstants` rather than a Resource).
  - [x] 2.2 New `scripts/core/zombie_name.gd`, `class_name ZombieName` (pure, static, no autoloads/nodes — Boundary 1), class doc naming FR78 and the rules. Typed static funcs:
    - `is_letter(c: String) -> bool` — exactly one ASCII `A–Z`/`a–z` character (use `unicode_at(0)` ranges, **not** `String.is_valid_identifier()` or a locale-aware check: Press Start 2P only has ASCII glyphs, so `é` must be rejected).
    - `append(current: String, c: String) -> String` — returns `current` unchanged when `c` is not a letter or a single space, when the result would exceed `GameConstants.ZOMBIE_NAME_MAX_LENGTH`, when `c` is a space and `current` is empty or already ends in a space; otherwise `current + c`.
    - `backspace(current: String) -> String` — drops the last character (empty stays empty).
    - `clean(raw: String) -> String` — keeps only letters and spaces, collapses space runs to one, strips leading/trailing spaces, then truncates to the max length and strips a trailing space again. Used by `PlayerData` on anything it is given.
    - `is_valid(name: String) -> bool` — `name == clean(name)`, length 1..max, at least one letter.
  - [x] 2.3 New `tests/unit/test_zombie_name.gd`: letters both cases accepted; digits, punctuation, `é`, `ß`, emoji, empty string, two-character strings rejected by `is_letter`; `append` rules (leading space, double space, the 13th character, non-letters); `backspace` on empty and on one character; `clean` on `"  sam   the  zombie "` → `"sam the zombie"` then truncated to 12 (`"sam the zomb"`) and a truncation that ends in a space (`"abcdefghijk lmno"` → `"abcdefghijk"`); `is_valid` on `""`, `" "`, `"Sam"`, `"Sam "`, 12 and 13 letters, `"S4m"`.

- [x] **Task 3: PlayerData name API** (AC: 5, 6, 7)
  - [x] 3.1 `scripts/autoloads/player_data.gd`: new signal `zombie_name_changed(name: String)` (doc: "the active profile's zombie name was set; never logged"). **Do not name anything `get_name` / `set_name`: PlayerData extends `Node`, and `Node.get_name()` / `Node.set_name()` already exist (the node's own name).** Add:
    - `get_zombie_name() -> String` — the stored `name` when it is a String and `ZombieName.is_valid()`; `""` for anything else (junk reads as "not named yet", NFR16).
    - `set_zombie_name(raw: String) -> bool` — `ZombieName.clean(raw)`; invalid → `Log.warn(&"save", "set_zombie_name: invalid name")`, change nothing, return false; equal to the stored name → return true, no signal, no save; else write `_profile()["name"]`, emit `zombie_name_changed`, `save_service.request_save()`, `Log.info(&"save", "zombie named")`, return true.
    - Extend the class doc with a `## Zombie name (Story 11.1, FR78): ...` paragraph (stored cleaned, read through ZombieName.is_valid, never logged, Epic 11 profile switch will re-read it through profile_replaced).
  - [x] 3.2 `reset_all()` needs nothing (defaults have `"name": ""`; listeners re-read on `profile_replaced`).
  - [x] 3.3 `tests/unit/test_player_data.gd` (temp-dir SaveService, never the real save): a fresh profile reads `""`; set → get returns the cleaned name and exactly one save request; the whole profile minus `name` is identical before/after (deep `duplicate(true)` compare); same name twice → one signal, one save; invalid (`""`, `"123"`, `"   "`) → false, nothing written, `assert_push_warning` matched on `"set_zombie_name: invalid name"`; junk stored values (`5`, `"!!!"`, a 40-char String) read as `""`; the name survives a reload through a second temp `SaveService`; **NFR12 check (two parts):** (a) set an invalid `"Zorbleflux9"` and assert the one pushed warning is exactly the fixed text (`assert_push_warning("set_zombie_name: invalid name")`) and contains no `"Zorbleflux"`; (b) `print` lines can't be captured by GUT, so keep every name-related `Log.info`/`Log.debug` message a **fixed literal** and add a source guard test that reads `scripts/autoloads/player_data.gd`, `scripts/screens/name_zombie.gd` and `scripts/core/zombie_name.gd` as text and fails if any `Log.` / `print` / `push_` call line contains `%` formatting together with a name variable (`name`, `raw`, `text`, `cleaned`) — keep the regex simple and document it in the test.

- [x] **Task 4: Gate 1 — layout sketch and copy** (AC: 2, 9, 10) — **stop for Smuck's approval before Task 5 visuals.**
  - [x] 4.1 Sketch `_bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/sketches/name-zombie-11-1.md` in the style of `trends-10-5.md` / `crypt-closet-4-4.md`: both states (empty with caret; a filled 12-character name with Done ready), coordinates on the 4 px grid, the theme variations used, focus. Proposed starting layout below (Dev Notes).
  - [x] 4.2 Copy list (all `[ASSUMPTION]` until approved): "Name your zombie!", "Done", "Enter". Ask Smuck the open questions listed under Dev Notes → Questions for Gate 1 in the same message. Record the verbatim answer + date under `## Art Approval`.

- [x] **Task 5: Name screen** (AC: 2–4, 8, 9)
  - [x] 5.1 `scripts/autoloads/router.gd`: append `NAME_ZOMBIE` to `enum Screen` (after `TRENDS`) and its path to `SCREEN_PATHS`. Nothing else in the Router changes. Update `tests/unit/test_router.gd` enum-order assertion (message `"Story 11.1 appended NAME_ZOMBIE; nothing moved"`).
  - [x] 5.2 `scenes/screens/name_zombie.tscn` + `scripts/screens/name_zombie.gd` (mirrored paths, `extends Control`). Seams like `welcome_gift.gd` / `trends.gd`, assigned before `add_child`, defaulted in `_ready()`: `navigate` (→ `Router.go`), `player_data` (→ `PlayerData`), `play_sfx`, `play_music`. Nodes (PascalCase, `%Unique` where scripted): `Background` (night), `%Zombie` (`player_zombie.tscn`), `%PetSlot` (`pet_slot.tscn`), `%Sign` + `%Heading`, `%NameField` (a `Panel`/`PanelContainer` with a theme variation) holding `%NameLabel` (24 px) and `%Caret`, `%DoneButton` (`Button`, `PixelButton` script + `PixelButton` variation), `%EnterKeycap` (`Keycap` variation, like the report card).
  - [x] 5.3 Typing: handle `InputEventKey` in `_unhandled_input` (Godot `ui_*` actions still drive the button): ignore releases, echo, and events with Ctrl/Alt/Meta held; `KEY_BACKSPACE` → `ZombieName.backspace`; `KEY_ENTER` / `KEY_KP_ENTER` → Done; otherwise `char(event.unicode)` → `ZombieName.append`. Mark handled only what you used. Do **not** use `TypingInput` (it is the run's judgment pipeline, emits errors/caps hints) and do **not** use a `LineEdit` (see Dev Notes — Why not LineEdit). Read keys by `unicode`, never `keycode`, so non-US layouts type the letter they show (NFR6).
  - [x] 5.4 Space vs the focused button: Godot's `ui_accept` includes **Space** by default, so a focused `%DoneButton` would treat Space as a press. Make sure Space in the name screen only ever adds a space: handle it in `_input` before the GUI (mark handled) **or** set `%DoneButton`'s shortcut/`action_mode` so only Enter/click press it — pick one and test it (`Space with Done focused adds a space and never navigates`).
  - [x] 5.5 Done: valid → `player_data.set_zombie_name(text)`, `play_sfx(&"sfx_ui_click")`, `navigate(MAIN_MENU, {})` once (`_leaving` guard, released if `Router.is_transitioning()` ends without freeing the screen — the main menu's `_leave()` pattern); invalid → field wiggle tween (≤ 0.2 s, position only, no sound). `%DoneButton` shows its disabled look while the name is empty but stays focusable (`focus_mode = FOCUS_ALL`; do not set `disabled = true`, which drops focus and makes Enter dead).
  - [x] 5.6 Esc (`ui_cancel`): mark handled, do nothing. `_ready()`: `Router.take_payload()`, `play_music.call(&"mus_menu")`, `WebPlatform.capture_keys = true`, `%DoneButton.grab_focus()`, show the current `get_zombie_name()` (normally `""`). `_exit_tree()`: `WebPlatform.capture_keys = false`, disconnect any autoload signal you connected.
  - [x] 5.7 Hat/pet: `HatSlot`/`PetSlot` already follow `PlayerData.equipment_changed`; copy how `main_menu.tscn` places `Zombie` + `PetSlot` (and its `pet_slot` sizing). Nothing new to code for cosmetics.

- [x] **Task 6: Title routing** (AC: 1)
  - [x] 6.1 `scripts/screens/title.gd`: add a `player_data` seam (default `PlayerData` in `_ready()`) and `func next_screen() -> Router.Screen` returning `NAME_ZOMBIE` when `player_data.get_zombie_name().is_empty()`, else `MAIN_MENU`; `_unhandled_input` calls `Router.go(next_screen())`. Keep `AudioManager.unlock()` and the click **inside** the input callback (browser gesture rule) and the `_advanced` once-guard. Update the class doc.
  - [x] 6.2 `tests/unit/test_title.gd`: `next_screen()` with a temp `PlayerData` whose name is empty → `NAME_ZOMBIE`; named → `MAIN_MENU`; junk name → `NAME_ZOMBIE`. Existing title tests unchanged.

- [x] **Task 7: Screen tests and cross-screen walks** (AC: 2–4, 8, 9, 11)
  - [x] 7.1 New `tests/unit/test_name_zombie.gd` (temp PlayerData + recorders, `process_mode` handling like `test_trends.gd`; push a no-op `InputEventAction` in `after_each` — the `_reset_input_handled` pattern, 10.5 found that calling `_unhandled_input()` by hand leaves GUT's viewport input marked handled): typing `S`,`a`,`m` shows `Sam`; leading space / double space / 13th letter / `7` / `!` / `é` / echo / Ctrl+A ignored; Backspace; Enter with empty → no navigation, no save, wiggle started; Enter with `Sam` → name saved, click played, exactly one `[MAIN_MENU, {}]`; a second Enter / click after that → nothing; Esc → nothing; Space with Done focused → adds a space; payload consumed; `capture_keys` true while open and false after free; `%DoneButton` is the only focusable control and starts focused; 24 px name font.
  - [x] 7.2 `tests/integration/test_screen_flow.gd`: `_instance()` gives `NAME_ZOMBIE` a temp `PlayerData`, a navigate recorder and no-op `play_sfx` (10.1 real-save incident: any screen that can write gets a temp PlayerData); add `"NAME_ZOMBIE": ["%DoneButton"]` to `FLOW_BUTTONS`; add `test_name_zombie_consumes_the_payload`. `test_every_screen_instantiates` walks the new value automatically.
  - [x] 7.3 `tests/unit/test_plain_words.gd`: add the approved copy to `APPROVED_COPY` on purpose; add the new scene to its scene list / preloads if the walk needs it (see how `TrendsScene` was added). The kid's typed name is user content: make sure the walk reads the scene with an empty `%NameLabel` (no test name leaks into the copy check).
  - [x] 7.4 `tests/unit/test_readability.gd` lists its scenes as explicit preloads (`TitleScene`, `MenuScene`, … `TrendsScene` at the top): add a `NameZombieScene` preload and walk it (filled with a 12-character `WWWWWWWWWWWW` name so the clipping/16 px checks see the widest case; add a test that the name label is ≥ 24 px). Confirm `test_no_placeholder_chrome.gd` picks the new scene and script up (it scans folders; no change expected).
  - [x] 7.5 `grep -rn "Screen.MAIN_MENU" tests` for any test that drives the **title** and expects the menu (currently only `test_title.gd`/`test_router.gd`/`test_readability.gd` mention the title); update only what AC 1 changes.

- [x] **Task 8: Docs** (AC: 1, 2)
  - [x] 8.1 `EXPERIENCE.md`: Information Architecture row for "Name your zombie" (reached from Title when the active zombie has no name; leaves to Main Menu), the flow line `Title → (Name your zombie, unnamed zombie only) → Main Menu → …`, Voice and Tone rows for the approved copy, a Component Patterns row `name-entry` (letters/space/Backspace/Enter rules, ignored keys are silent, wiggle on empty Done), State Patterns rows (empty / filled). DESIGN.md: a short "Name field" component entry (theme variation, 24 px text, caret).
  - [x] 8.2 `_bmad-output/game-architecture.md` Screen Flow: add `NAME_ZOMBIE` to the enum listing and the flow; System Location Mapping gets `scripts/core/zombie_name.gd`.

- [x] **Task 9: Gate 2 — in-game check** (AC: 10, 11)
  - [x] 9.1 Captures via a scratch windowed runner on a temp `user://` dir (deleted after) into `_bmad-output/implementation-artifacts/screenshots/11-1/`: `name-empty.png`, `name-filled.png` (12 characters), `name-with-hat-pet.png`, `name-filled-gray.png`. Show Smuck; record the verbatim answer + date.
  - [x] 9.2 Web smoke with the `web-debug` launch config (browser storage only — never the desktop save): the browser's existing save has `"name": ""` → title → name screen → type a name (single key presses; the pane's `type` action is unreliable and drops capitals) → Enter → menu with the same brains/hat/pet as before; reload → title → straight to the menu. Check Space did not scroll, Backspace did not navigate, and the console has no errors and no line containing the name.

- [x] **Task 10: Wrap-up** (AC: 11)
  - [x] 10.1 Full suite + counts vs baseline; real save sha256 unchanged.
  - [x] 10.2 Mutation pass (scratch harness, restore after): title always goes to MAIN_MENU; `append` allows a leading space; `clean` skips truncation; `set_zombie_name` skips `clean`; `get_zombie_name` skips `is_valid`; Done navigates with an empty name; `capture_keys` not reset in `_exit_tree`; `set_zombie_name` logs the name. Each must turn a test red.
  - [x] 10.3 Anything deferred → `deferred-work.md`. Status → review.

## Dev Notes

### What this story is (and isn't)

- **Is:** one pure `ZombieName` helper, two `PlayerData` methods + one signal, one new screen + Router id, the title's next-screen choice, docs, tests, two approval gates.
- **Isn't:** the "Who's playing?" picker, creating new profiles, switching `active_profile` (Story 11.2); per-profile separation tests (11.3); showing the name on the menu or report card (11.4); renaming later from the menu (11.4 adds "a way to switch zombies"; a rename button is not in any AC — do not add one); a bad-word filter (not in FR78; see Questions); any save schema change.

### Design decisions made for this story (follow them; record any change and why)

1. **Fresh saves are asked too.** AC 1 of the epic says "a save whose active profile has an empty name". A new save also has `"name": ""`, so a first-time kid names the zombie right after the title, before the first run. That is the same moment 11.2's "New zombie" will ask for a name, so the screen is reused there. (If Smuck wants first-timers to skip it, that is a one-line change in `title.gd::next_screen()` — ask at Gate 1.)
2. **No migration.** ADR-2 made the save profile-shaped with `"name": ""` from v1 precisely so Epic 11 needs no migration. Do not bump `CURRENT_SCHEMA`, do not add `migrate_5_to_6`, do not touch fixtures.
3. **`get_zombie_name` / `set_zombie_name`, not `get_name` / `set_name`.** `Node.get_name()` returns the node's name ("PlayerData"); shadowing it is a parse error / silent breakage. Also avoid a property named `name`.
4. **ASCII letters only.** "Letters and spaces" + the pixel font: Press Start 2P has only ASCII glyphs, so `é`, `ñ`, Cyrillic etc. would render as boxes. Rejecting them is silent (like any other ignored key).
5. **Case kept as typed.** No auto-capitalisation (a kid who types `sam` sees `sam`). Ask at Gate 1 if a capital first letter is wanted.
6. **Trailing space is allowed while typing, dropped on save** (`clean`), so a kid can type "Sam " then "Z".
7. **Custom field, not `LineEdit`** (see below). **Keys by `unicode`**, like the typing pipeline (NFR6: matching is by character).
8. **Router enum appended** (10.5 precedent): ints are passed around (`test_debug_overlay.gd` and others).
9. **The name screen never writes anything but the name**, and only on Done. Leaving the tab mid-typing loses the typed text (nothing is saved until Done) — fine: the screen reappears next launch.

### Why not `LineEdit`

- The theme has **no `LineEdit` styles** (`data/ui_theme.tres` has none); styling one needs new StyleBoxes (and DESIGN.md forbids `StyleBoxFlat`).
- `LineEdit` brings mouse selection, drag, double-click select-all, a right-click context menu (DESIGN/EXPERIENCE ban right-click), Ctrl+V paste of any text, and on web a hidden HTML `<input>` for IME/virtual keyboard — all behaviour we'd have to switch off or filter after the fact (`text_changed` re-filtering moves the caret).
- A `Label` + caret driven by `_unhandled_input` is ~40 lines, uses the existing pixel font and theme boxes, and the rules live in the tested `ZombieName` helper.

### Proposed layout (starting point for the Gate 1 sketch; 640×360, 4 px grid, 16 px margin; Press Start 2P: 16 px per glyph at 16 px, 24 px at 24 px)

- Background: night (`#2B1D3F`), like the welcome gift.
- `%Sign` (parchment `Sign` variation) top centre, x 136–504, y 24–64, `%Heading` "Name your zombie!" 24 px (17 glyphs × 24 = 408 px is too wide for 368 → use 16 px: 272 px, or widen the sign to x 104–536 at 24 px = 408 + 16 padding; decide in the sketch).
- `%Zombie` (32×32 sprite, scaled like the menu's) + `%PetSlot` centred at y ~ 112–176 so the hat and pet read clearly.
- `%NameField` x 160–480 (320 px: 12 × 24 = 288 + caret + padding), y 200–244, theme variation from the existing set (`Chalkboard` reads as "write here"; `Sign` is parchment). `%NameLabel` 24 px, left-aligned with 12 px padding; `%Caret` a 24×4 chalk/ink underline after the last glyph (or a 4×24 bar), steady or blinking ≤ 3 Hz.
- `%DoneButton` x 248–392, y 272–304 (`PixelButton`, 32 px tall) with `%EnterKeycap` right of it (report-card keycap composition).
- Nothing in the top-right (no Progress/brain counter here: this screen is about the name only). Check the welcome gift / trends scenes for exact theme variation names before using them (`WoodPanel`, `Sign`, `Chalkboard`, `Keycap`, `PixelButton`, `Ribbon`).

### Questions for Gate 1 (ask Smuck together with the sketch; record answers)

1. Copy: "Name your zombie!" / "Done" OK? (Alternatives: "What is your zombie's name?", "OK".)
2. Should a brand-new save also see the name screen right after the title (decision 1), or only saves that already have runs?
3. Capitalise the first letter automatically, or keep exactly what the kid types?
4. Any rude-word check? FR78 says only "plain-word, length-limited"; the default here is none (a parent-supervised family game, no network). If wanted, it becomes a small static list in `ZombieName` + a test.

### Existing code: current state, what changes, what must be preserved

- **`scripts/screens/title.gd`** (36 lines): any key except Esc / any non-wheel click → `_advanced` guard → `AudioManager.unlock()` + click → `Router.go(MAIN_MENU)`. Change only the target (`next_screen()`) and add the `player_data` seam. Preserve: unlock inside the input callback, Esc and wheel ignored, once-guard, `mus_menu` pending in `_ready()`, all `test_title.gd` cases. The title test instances are `PROCESS_MODE_DISABLED` so `Router.go` is never reached — keep it that way; test `next_screen()` directly.
- **`scripts/autoloads/router.gd`**: enum + `SCREEN_PATHS` only. Fade, payload, fallback, debug overlay untouched.
- **`scripts/autoloads/player_data.gd`** (619 lines): getters read `save_service.get_active_profile()` every call (no caching — Epic 11 swaps profiles; keep it). Add the two methods + signal near the settings/flags API. Preserve every existing method and the one-save-request-per-mutation rule. `_reconcile_tier()` and `reset_all()` untouched.
- **`scripts/core/save_schema.gd`**: **no change.** `profile_defaults()["name"] = ""` already; `_merge` already repairs a non-String `name` to `""` (with a `bad type at profiles/p1/name` warning — the path, never the value, so NFR12 holds).
- **`scripts/screens/main_menu.gd`**: **no change** in this story (11.4 adds the name there). It must keep working when entered from the name screen with an empty payload (it already is entered with `{}` from the title).
- **`WebPlatform.capture_keys`**: false outside runs today; only `run_frame.gd` and `keyboard_test.gd` set it. The name screen becomes the third setter; it must always reset it on exit.
- **Debug overlay F8 (`reset_all`)** while on the menu empties the name; the kid stays on the menu until the next launch (title → name screen). Acceptable (dev-only); do not add routing to the overlay.

### Known test fallout (so you are not surprised)

| Test | Why | Fix |
|---|---|---|
| `test_router.gd:25` | pins `Screen.keys()` | append `"NAME_ZOMBIE"` (Task 5.1) |
| `test_screen_flow.gd::test_every_screen_instantiates` | walks every `Router.Screen`; the new screen writes (`set_zombie_name`) and sets `capture_keys` | temp PlayerData + recorders (Task 7.2); `_exit_tree` resets `capture_keys` |
| `test_plain_words.gd` | new copy on a walked scene | approve it on purpose (Task 7.3) |
| `test_readability.gd` / `test_no_placeholder_chrome.gd` | new scene walked | layout per AC 9 |
| `test_title.gd` | no change to existing cases | add `next_screen()` cases |
| `test_smoke.gd:12` (`CURRENT_SCHEMA == 5`) | must **not** change | if you touched the schema, undo it |

### Testing notes

- Commands as in Task 1. Run `--import` after adding `class_name ZombieName` (stale class cache → "Could not find type" parse errors).
- GUT silently skips a script that fails to parse and still exits 0 — always grep the log for `Parse Error|Compile Error|Failed to load script`.
- Never the real save: temp-dir `SaveService` + injected `PlayerData` (`test_player_data.gd` helpers, `test_screen_flow.gd::_temp_player_data`). Check the real save's sha256 after every run.
- Synthetic keys: build `InputEventKey` with `pressed`, `echo`, `keycode` **and `unicode`** (e.g. `unicode = "S".unicode_at(0)`, `shift_pressed = true` for capitals) — the screen reads `unicode`. For Ctrl combos set `ctrl_pressed = true`.
- `assert_push_warning` / `assert_push_warning_count` for the deliberate invalid-name warning; the warning count in the final suite rises only by asserted ones.
- Type every variable including `for` loop variables (`untyped_declaration = Error`, tests too). Sort `String`s, not `StringName`s.
- Freed nodes: `queue_free()` frees at frame end — `await get_tree().process_frame` before checking `capture_keys` after free.
- Flaky `test_audio_manager` pool test: rerun once before investigating.

### Previous story intelligence

- **10.5 (done, latest):** Router enum appended (`TRENDS`) with the enum-order test message pattern; screens get `navigate` / `player_data` / `play_sfx` / `play_music` seams; `_leave()`-style once-guard released if the transition ends without freeing the screen; `_reset_input_handled` (`InputEventAction` push in `after_each`) after calling `_unhandled_input()` by hand; new copy approved in `test_plain_words.gd` + EXPERIENCE.md rows; Gate 1 (sketch + copy) and Gate 2 (captures incl. grayscale) recorded verbatim; web smoke via `web-debug`; final 2239 tests, `SCRIPT ERROR` 3, `WARNING` 178. `Godot.exe` in `C:\Program Files\Godot\` is the 4.7.2 build used (the `_console.exe` can't find its main exe there).
- **10.1:** real-save incident — a screen instanced on the live `PlayerData` wrote `save.json`. This screen **writes** (the name): temp PlayerData everywhere it is instanced in tests.
- **5.3 / 1.5:** `WebPlatform.capture_keys` and the JS keydown listener; in menus browser keys are normally left alone — this screen is the deliberate exception (it is a typing screen).
- **2.1:** `TypingInput` filtering (echo, `unicode == 0`, ignored keycodes) — reuse the *idea* (echo / `unicode == 0` / modifiers ignored), not the class.
- **4.5 (welcome gift):** single pre-focused button screen, `_input` swallowing, Esc does nothing — the closest existing screen shape.
- **Traps:** files LF (`.gitattributes eol=lf`); hand-edited `.tscn`: `format=3`, correct `load_steps`, unique ids; Godot rewrites uids on import — commit what it writes.

### Git intelligence

- Recent: `b992bce Story 10.5: code review findings resolved, done`, `fc93e9d Story 10.5: trends and lifetime stats screen`, `e3b4481 Story 10.4: code review patches applied, done`, `0495db9 Story 10.4: ...`, `e5ec1d6 Story 10.3: ...`. One commit per story with code, data, tests, screenshots, story file, `deferred-work.md` and `sprint-status.yaml` together.
- Expected shape: new `scripts/core/zombie_name.gd`, `scripts/screens/name_zombie.gd` (+ `.uid`s), `scenes/screens/name_zombie.tscn`, `tests/unit/test_zombie_name.gd`, `tests/unit/test_name_zombie.gd`; updated `player_data.gd`, `game_constants.gd`, `router.gd`, `title.gd`, `test_player_data.gd`, `test_title.gd`, `test_router.gd`, `test_screen_flow.gd`, `test_plain_words.gd` (maybe `test_readability.gd`); the sketch, EXPERIENCE/DESIGN rows, architecture lines, screenshots. Suggested message: `Story 11.1: name the existing zombie`.

### Latest tech notes (Godot 4.7.2, GUT 9.7.1)

- No new libraries or addons. Versions are pinned by the architecture (Godot 4.7.2 standard, GDScript, Compatibility renderer; GUT 9.7.1).
- `InputEventKey.unicode` is the typed character (0 for non-printables); `char(code)` turns it into a String. `is_echo()` for key repeat. `event.is_command_or_control_pressed()` covers Ctrl/Cmd.
- Default `ui_accept` = Enter, KP Enter **and Space**; a focused `BaseButton` reacts to `ui_accept` → handle Space first (Task 5.4).
- `Button` with `disabled = true` can't hold focus usefully — use a visual disabled look (theme variation or `modulate`) instead.
- Tween a position wiggle with `create_tween()`; kill the previous wiggle before starting a new one so mashing Enter never drifts the field.

### Project Structure Notes

- `scripts/core/zombie_name.gd` (pure helper → core, with its unit test, like `trends_calculator.gd`); `scripts/screens/name_zombie.gd` + `scenes/screens/name_zombie.tscn` (screen, mirrored); sketch in `ux-designs/.../sketches/name-zombie-11-1.md`; screenshots in `_bmad-output/implementation-artifacts/screenshots/11-1/`; scratch in `tools/_scratch_11_1/` (deleted). No variance from the architecture tree.
- Story 11.2 will reuse `NAME_ZOMBIE` for "New zombie" (likely with a payload such as `{"new_profile": true}` and a different next screen). Keep the screen's "what happens on Done" in one method so 11.2 can branch there; do **not** build that branch now.

### Project Context Rules

- There is no `project-context.md`. Rules from the architecture and earlier stories:
  - Only `SaveService` touches files; only `PlayerData` mutates profile state (screens read via getters, navigate via `Router`). Boundary 4.
  - `scripts/core/` is pure (no autoloads, no scene tree); every class in it has `tests/unit/test_*.gd`.
  - Static typing everywhere; `untyped_declaration = Error`. Typed, past-tense signals connected in code; disconnect autoload connections in `_exit_tree`.
  - No GDD number as a literal in a script; UI look values are consts with a "Look value" comment (wiggle duration, caret blink).
  - Never log personal data — the zombie name is the one piece of personal data in the game (ARCH Logging, NFR12).
  - Kid-facing text: words a 6-year-old can read, no slang, no technical text, no ranks (NFR9, NFR10). No timers outside runs (NFR11) — the caret blink is not a timer; no countdown, no "hurry".
  - DESIGN.md: palette colours only, 16 px text floor (24 px for the name), candy yellow = focus only, no `StyleBoxFlat`, no anti-aliased shapes, never colour alone (the empty-Done state is shape/brightness, not just a hue).
  - Errors never reach the kid; junk save values read as safe defaults (NFR16).
  - Visible changes wait for Smuck's approval (Gate 1 before wiring visuals, Gate 2 in game), recorded verbatim with dates.
  - Debug code only in `scenes/debug/` / `scripts/debug/` (nothing needed here).

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 11.1: Name the Existing Zombie]; Epic 11 overview; FR78 (named zombie, plain-word, length-limited; MVP save becomes the first profile), FR23/FR24/FR25 (title, flow, keyboard + mouse), NFR6, NFR7, NFR9, NFR11, NFR12, NFR16
- [Source: _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd-epics-overview.md#Epic 11] ("Create a zombie with a name (plain-word, length-limited)")
- [Source: _bmad-output/game-architecture.md#Data Persistence] (save shape with `"name": ""`), [#Architecture Decision Records] (ADR-2: no data migration for profiles), [#Logging] ("the future zombie name ... isn't logged"), [#Screen Flow], [#Architectural Boundaries], [#Consistency Rules]
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/EXPERIENCE.md] (IA, Voice and Tone, Component Patterns, Input Schemes: browser key capture, Accessibility Floor), [DESIGN.md] (Colors, Typography, Components, Do's and Don'ts)
- [Source: scripts/screens/title.gd], [scripts/autoloads/router.gd], [scripts/autoloads/player_data.gd], [scripts/core/save_schema.gd profile_defaults/_merge], [scripts/core/game_constants.gd], [scripts/autoloads/web_platform.gd capture_keys], [scripts/screens/welcome_gift.gd], [scripts/screens/main_menu.gd + main_menu.tscn (Zombie, PetSlot)], [scripts/screens/keyboard_test.gd capture_keys on/off]
- [Source: tests/unit/test_title.gd], [tests/unit/test_router.gd], [tests/integration/test_screen_flow.gd], [tests/unit/test_player_data.gd], [tests/unit/test_plain_words.gd], [tests/unit/test_readability.gd], [tests/unit/test_no_placeholder_chrome.gd], [tests/unit/test_trends.gd (seams, _reset_input_handled)]
- [Source: _bmad-output/implementation-artifacts/10-5-trends-and-lifetime-stats-screen.md] (new screen + Router append + gates template), [10-1-random-theme-rotation.md] (real-save incident), [deferred-work.md] (Epic 11 notes: profile switch must call `_reconcile_tier()` — 11.2, not here)

## Art Approval

<!-- Gate 1 (layout sketch + copy) and Gate 2 (in-game captures): Smuck's verbatim answers with dates. -->

### Gate 1 — layout sketch + copy (2026-10-15)

Sketch: `_bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/sketches/name-zombie-11-1.md`.

- Layout and copy ("Name your zombie!" / "Done" / "Enter"): **"Approve as drawn"**
- Brand-new saves also see the name screen: **"Yes, ask everyone (Recommended)"**
- Capitalise the first letter: **"Keep what they type (Recommended)"**
- Rude-word check: **"No check (Recommended)"**

### Gate 2 — in-game captures (2026-10-15)

Captures `screenshots/11-1/name-empty.png`, `name-with-hat-pet.png`, `name-filled.png` ("Mister Bones", 12 characters), `name-filled-gray.png`, taken from the real title → name screen flow on an isolated user dir: **"Approve"**

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Debug Log References

- Baseline (Task 1): 2239 / 2239, `SCRIPT ERROR` 3, `WARNING` 178, 0 `Parse Error|Compile Error|Failed to load script`. Real save sha256 `2859cbaa…647a`.
- Final (Task 10): 2291 / 2291 (+52), `SCRIPT ERROR` 3, `WARNING` 183 (+5: exactly the asserted `[WARN][save] set_zombie_name: invalid name` lines), 0 parse errors. Real save sha256 unchanged after every suite run, the capture runs and the web smoke.
- First parse error during dev: the source-guard regexes were written through a shell heredoc that collapsed the escapes; switched to GDScript raw strings (`r"..."`).
- Gate 2 capture: `-s` scene-tree scripts don't load the main scene, so the runner loads `title.tscn` itself and presses Enter; the title then routes to `NAME_ZOMBIE` by itself (no direct `Router.go`).

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created
- `ZombieName` (`scripts/core/zombie_name.gd`): pure static rules: `is_letter` (ASCII only), `append`, `backspace`, `clean`, `is_valid`; `GameConstants.ZOMBIE_NAME_MAX_LENGTH = 12`. 13 unit tests.
- `PlayerData`: `get_zombie_name()` (junk / invalid reads as ""), `set_zombie_name(raw) -> bool` (cleans, refuses invalid with a fixed warning, no-op when unchanged, else writes only `name`, emits `zombie_name_changed`, one save request, logs the fixed text `zombie named`). No schema change (`CURRENT_SCHEMA` stays 5). 11 tests, including a whole-profile-minus-name compare on the full fixture, reload, reset, and NFR12 in two parts.
- **NFR12 test deviation:** the story's example `"Zorbleflux9"` cleans to the valid `"Zorbleflux"`, so it can't be the invalid case. The test saves it (asserting zero warnings), then uses `"#9#9#"` as the invalid input and checks that no tracked warning or error contains either string. Part (b) is a source guard over `player_data.gd`, `name_zombie.gd` and `zombie_name.gd`.
- `Router.Screen.NAME_ZOMBIE` appended after `TRENDS`; `scenes/screens/name_zombie.tscn` + `scripts/screens/name_zombie.gd` as sketched (Sign heading, zombie + pet at 2×, Chalkboard field with a 24 px name and a steady chalk underline caret hidden at 12 characters, `%DoneButton` + Enter keycap). Space is taken in `_input` (Task 5.4 option 1) so it never presses the focused button. Done's "off" look reuses the theme's `disabled` plank and text colour through overrides, keeping focus and the ring. `_finish()` holds "what Done does" for 11.2. 24 tests, including real viewport events for Space, Enter and letters.
- Title: `player_data` seam + `next_screen()`; unlock and click stay in the input callback. 3 new tests.
- Cross-screen: `test_screen_flow` (temp PlayerData + recorders, `FLOW_BUTTONS`, payload test), `test_plain_words` (approved "Name your zombie!", "Done"; walks the live screen with an empty name), `test_readability` (walks the screen filled with 12 W; new ≥ 24 px name + fit test), `test_router` enum order. `test_no_placeholder_chrome` picked up the new files with no change.
- Docs: EXPERIENCE.md (IA row, flow, Voice and Tone, `name-entry` component, two state rows, title-prompt note), DESIGN.md "Name field", game-architecture.md (full Screen enum, NAME_ZOMBIE flow note, `zombie_name.gd` location row).
- Gates: Gate 1 and Gate 2 approved and recorded verbatim above. Captures came from the real title flow on an isolated user dir: a temporary `override.cfg` with `custom_user_dir_name`, deleted afterwards along with the scratch runner and the temp dir.
- Web smoke (`web-debug`, fresh debug export, browser storage only): title → name screen → typed (single key presses) → Enter → menu with the same 110 brains; reload → title → straight to the menu. `scrollY` stayed 0 after Space, Backspace didn't navigate (`history.length` 1, same URL), `7` ignored, no console errors, no console line containing the name (only `[INFO][save] zombie named`). The pane's synthetic keys drop Shift, so capitals were lowercase there; capitals were checked on desktop instead.
- Mutation pass (scratch harness, each file restored after): title always MAIN_MENU, `append` allows a leading space, `clean` skips truncation, `set_zombie_name` skips `clean`, `get_zombie_name` skips `is_valid`, Done navigates with an empty name, `capture_keys` not reset, `set_zombie_name` logs the name, and (extra) Space not taken before the GUI. Every one turned at least one test red.
- Deferred notes added to `deferred-work.md` (Done off-look relies on focus, pane drops capitals, no rename, source-guard regex limits).

### File List

- `scripts/core/zombie_name.gd` (new) + `.uid`
- `scripts/core/game_constants.gd` (modified)
- `scripts/autoloads/player_data.gd` (modified)
- `scripts/autoloads/router.gd` (modified)
- `scripts/screens/title.gd` (modified)
- `scripts/screens/name_zombie.gd` (new) + `.uid`
- `scenes/screens/name_zombie.tscn` (new)
- `tests/unit/test_zombie_name.gd` (new) + `.uid`
- `tests/unit/test_name_zombie.gd` (new) + `.uid`
- `tests/unit/test_player_data.gd` (modified)
- `tests/unit/test_title.gd` (modified)
- `tests/unit/test_router.gd` (modified)
- `tests/unit/test_plain_words.gd` (modified)
- `tests/unit/test_readability.gd` (modified)
- `tests/integration/test_screen_flow.gd` (modified)
- `_bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/sketches/name-zombie-11-1.md` (new)
- `_bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/EXPERIENCE.md` (modified)
- `_bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/DESIGN.md` (modified)
- `_bmad-output/game-architecture.md` (modified)
- `_bmad-output/implementation-artifacts/screenshots/11-1/name-empty.png`, `name-with-hat-pet.png`, `name-filled.png`, `name-filled-gray.png` (new)
- `_bmad-output/implementation-artifacts/deferred-work.md` (modified)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified)
- `_bmad-output/implementation-artifacts/11-1-name-the-existing-zombie.md` (this story)

## Change Log

- 2026-10-15: Story 11.1 implemented: ZombieName rules, PlayerData zombie name API + signal, NAME_ZOMBIE screen, title routing for unnamed zombies, docs, tests (+52, 2291 total). Gates 1 and 2 approved. Status → review.
