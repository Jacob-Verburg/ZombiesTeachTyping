---
baseline_commit: 3a39fa38fb303c38224039b33a52ee6ea0f17b5e
---

# Story 5.0: MVP UI Art Pass

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a kid,
I want every screen to look as good as the zombie does,
so that the whole game feels finished, not just the level.

## Acceptance Criteria

1. **The MVP UI asset list is final art (GDD Asset Requirements "UI", epics AC 1).** Every item below exists as a committed, tool-generated PNG under `assets/sprites/ui/`, is wired into its scene, and replaces the placeholder (`StyleBoxFlat` box, `ColorRect` shape, code `_draw()` shape or font-only text) it stands in for today:
   - title logo (title screen, main menu, web loading page, engine boot splash);
   - 3 level cards: a picture per level (`ui_level_card_<id>.png`), the card frame, the name sign, the greyed sign, and the hand-lettered "Coming soon" plank on the 2 unavailable cards;
   - HUD band frame, target sign, stats chalkboard, pet cushion, Caps Lock hint sign, pause button and its icon;
   - zombie hands: 2 hands, 10 finger-glow states with the pulsing outline, f/j bumps;
   - chalkboard report card (frame, board, chalk tray), the "New best!" stamp (hand-lettered, pre-rotated −8°), key-hint keycaps, the smiling moon;
   - Crypt Closet: tile frames for every state, the tags, the locked "?" silhouette, all 5 tile states, the hand-lettered "Crypt Closet" sign, the mirror, the confirm prompt's wood panel and parchment sign;
   - buttons (normal / focus / pressed / disabled) and the focus ring;
   - the brain icon (counter pill and Welcome Gift);
   - the Welcome Gift card (wood panel, pumpkin ribbon and bow);
   - the pause panel (stone panel, title sign, pixel buttons, icon toggles) and the countdown numerals;
   - the Music / Sound / Fullscreen toggle icons (on, and off with the stamp-red slash);
   - the tutorial arrow (hand-drawn, down and right);
   - the web loading page and the boot splash (AC 2, AC 3).
2. **Web loading page (DESIGN boot-splash, UX D11).** On a slow connection the loading page matches the title screen: a night `#2B1D3F` page, the title logo, a chunky pumpkin `#F07A1C` progress bar on a dusk `#4A3366` track, no text beyond the logo, no Godot logo. It is done with the Web preset's `html/head_include` CSS restyling the default shell's `#status`, `#status-splash`, `#status-progress` and `#status-notice` (plus `body`). A `html/custom_html_shell` is used only if head-include can't reach the look, and the reason is written in this file.
3. **Engine boot splash.** `application/boot_splash/bg_color = #2B1D3F`, `application/boot_splash/image` = the title logo PNG, `use_filter = false` (Nearest), `stretch_mode = 0` (Disabled, "no stretch"), `show_image = true`. Loading page → boot splash → title has **no white or grey flash** on Chrome, Edge and Firefox (the defaults today are grey: bg `(0.14, 0.14, 0.14)`, clear colour `(0.3, 0.3, 0.3)`). The Windows export uses the same settings.
4. **Every asset follows the style sheet (NFR13).** Palette only (the 32 colours), hard alpha, 1 px ink outline (with the exemptions listed in Dev Notes), the pixel font for dynamic text, Lossless import with no mipmaps, stepped corners from 9-slice `StyleBoxTexture`s (never a `StyleBoxFlat` radius). It matches `DESIGN.md` (tokens, typography, component states), the three key-screen mocks, and the approved layout sketches (`hud-band-2-5.md`, `crypt-closet-4-4.md`) and layout tables (2.9 report card, 4.2 main menu, 4.5 Welcome Gift). Screens without a mock or sketch (title, boot splash, pause panel + countdown, Welcome Gift) follow the spines. A new `tests/unit/test_art_ui.gd` enforces the mechanical rules for every UI PNG, and `docs/art-style-sheet.md` gets a UI section.
5. **Grayscale (NFR8).** In grayscale screenshots of the zombie hands and HUD, the active finger is still clear without colour (brightness plus the outline shape). A test backs it with the luminance of the lit finger vs. the resting finger and the outline pixels.
6. **Nothing about the game changes.** Every approved layout rect, `%UniqueName`, signal, public method and test seam stays (the getters `ZombieHands.get_lit_fingers / is_lit / get_outline_width / get_finger_fill / has_bump`, `TutorialArrow.point_at` positions and size 24 × 20, `ClosetItemTile.state_for / info_lines`, `LevelCard` states, `BrainCounter.set_count`, `PausePanel` signals, report card guard and reveal, Router payloads). Text stays ≥ 16 px and inside the 16 px margin. The full GUT suite passes; tests change only where they asserted the placeholder look (listed in Task 9).
7. **One shared look.** Button, panel, sign, chalkboard and keycap boxes live once in `data/ui_theme.tres` as theme type variations (9-slice `StyleBoxTexture`s); scenes use `theme_type_variation`, not per-scene `StyleBoxFlat` sub-resources. The report card and pause panel buttons become `PixelButton`s (closes the 2.9 / 4.2 deferral). A pressed pixel button drops 2 px onto its shadow (squish).
8. **End-to-end approval.** With the new art in game, the MVP flow is walked end to end (loading page → boot splash → title → menu → Zombie Run → pause → countdown → report card → Welcome Gift → Closet with the tutorial → buy → wear → menu) and no screen still shows placeholder art. Smuck approves the sprite sheet (Gate 1) and the in-game screens (Gate 2); both answers are recorded verbatim with the date in `### Review Findings

- [x] [Review][Defer] In-run Zombie Run scenes still use StyleBoxFlat; narrow the Task 10.5 claim to menus/screens/HUD [scenes/levels/zombie_run/*.tscn] — deferred to 5.2 (Smuck chose to defer)
- [x] [Review][Defer] Coming-soon card `Tint` stays an 85 % alpha overlay [scenes/ui/level_card.tscn] — accepted for MVP (Smuck chose to accept)
- [x] [Review][Dismiss] AC 3 throttled-network observation — accepted: Smuck confirmed Edge/Firefox/Windows flash check
- [x] [Review][Patch] PixelButton keeps the plain plank (no focused fill) when re-enabled while still focused — no hook for `disabled` going false [scripts/ui/pixel_button.gd:_notification/_refresh_fill ~36-59]. Make the redraw hook two-way (compare `has_focus() and not disabled` with override state) and add a test.
- [x] [Review][Patch] Focus bounce writes a stale `_rest_y` if the owner repositions mid-bounce, and offsets `position` by 1 px for 0.1 s (affects `TutorialArrow.point_at` reads) [scripts/ui/pixel_button.gd:_bounce ~62-70]. Use relative tweens / rest-rect for `point_at`.
- [x] [Review][Patch] No test that the bounce runs under a paused tree (PausePanel, PROCESS_MODE_WHEN_PAUSED) — spec Dev Notes asked for it [tests/unit/test_pixel_button.gd]
- [x] [Review][Patch] `test_focus_bounce_ends_exactly_at_rest` relies on fixed `wait_seconds`; poll `is_bouncing()` with `wait_until` instead [tests/unit/test_pixel_button.gd]
- [x] [Review][Patch] `test_glow_ring_is_two_px_strong_one_px_weak` doesn't assert ring width 2 vs 1, and checks only the tip for the thumb (Task 9.2) [tests/unit/test_art_ui.gd]
- [x] [Review][Patch] Welcome Gift `Bow` rect is 48x16 but the art is 48x20 (draws 4 px outside the rect) [scenes/screens/welcome_gift.tscn Bow]
- [x] [Review][Patch] Web loading bar is invisible in the indeterminate state (`#status-progress:indeterminate` set to the track colour) [export_presets.cfg html/head_include]
- [x] [Review][Patch] Story record out of date: "UI sheet list" sizes (logo 292x114, stone panel 32x32, chalkboard margin 8, etc.), Gate 2 screenshot count, `InkStrip` start-prompt change not noted [5-0-mvp-ui-art-pass.md Dev Notes / Art Approval]
- [x] [Review][Patch] Verify `StorageNotice` (PanelContainer with `Sign` variation whose base_type is Panel) renders its panel in game; add a test [scenes/screens]
- [x] [Review][Defer] Pause/toggle icons don't follow the pressed plank's 2 px squish — deferred, already recorded in deferred-work (5.0)
- [x] [Review][Defer] Letterbox bars still black on web/desktop (AC 3 partly) — deferred, already recorded
- [x] [Review][Defer] Hand textures loaded by runtime path; a Web resource filter would drop them, only the first missing file is warned [scripts/run/zombie_hands.gd:_load] — deferred
- [x] [Review][Defer] `ui_art_review` scene/script lack null guards and ship in exports [scripts/debug/ui_art_review.gd] — deferred, dev-only
- [x] [Review][Defer] Brittle exact-pixel/count tests and editor-only `Image.load_from_file` [tests/unit/test_art_ui.gd, test_report_card.gd, test_main_menu.gd] — deferred
- [x] [Review][Defer] The HUD grayscale check is a screenshot only, with no test (AC 5) — deferred

## Art Approval`.

## Tasks / Subtasks

- [x] **Task 1: UI art tool (AC: 1, 4)** — new `tools/gen_ui_art.gd`
  - [x] 1.1 `extends SceneTree`, run headless like `tools/gen_cosmetics_art.gd`, then `--import`. Reuse `const Proto := preload("res://tools/gen_art_prototypes.gd")` for `Proto.PALETTE` and the PNG-writing helpers' approach (copy the small helpers if a static call isn't possible, as 3.6 / 4.3 did). ASCII maps, one character per pixel, `.` transparent, a legend maps a character to a palette **name**; non-zero exit on any bad map. **Never hand-edit a PNG.**
  - [x] 1.2 Shape helpers for the large pieces (the backdrop precedent in `gen_zombie_run_art.gd`): filled rect, stepped-corner rect (`rounded.sm` = 1 px notch, `md` = 2-step, `lg` = 3–4 step), 1 px ink outline around a mask, horizontal plank grain lines, so a 9-slice source or a 184 × 72 card picture isn't a giant hand-typed map. Fixed positions only, no randomness.
  - [x] 1.3 A small **hand-lettered alphabet** as glyph maps (only the letters needed: "Zombies Teach Typing", "Coming soon", "New best!", "Crypt Closet") in two sizes (logo-size and sign-size), plus a `compose_word()` helper with tuned (tight) spacing. This is DESIGN's "hand-lettered signs are sprites"; it is not a second font and is never used for dynamic text.
  - [x] 1.4 Output folders (architecture Directory Structure, plus `common/` for the shared chrome): `assets/sprites/ui/common/`, `ui/hud/`, `ui/hands/`, `ui/menu/`, `ui/closet/`, `ui/report_card/`. File names `ui_<element>[_<state>].png` (architecture naming). The full list and sizes are in Dev Notes "UI sheet list"; sizes marked "look value" may change at Gate 1, and the table in `docs/art-style-sheet.md` follows.
- [x] **Task 2: Draw the sheets (AC: 1, 4, 5)** — everything in Dev Notes "UI sheet list", in this order so Gate 1 can start early:
  - [x] 2.1 Shared chrome 9-slices: wood panel, stone panel, parchment sign, grey sign, button × 4 states (2 px ink drop shadow baked into normal / focus, not into pressed / disabled), stepped focus ring, keycap, chalkboard (wood frame + board), brain-counter pill, candy sign (Caps Lock hint).
  - [x] 2.2 Icons: brain icon 16 px and 32 px (two drawings, not a scale), toggle icons (music note, speaker, four corner arrows; 2 frames each: on in `zombie-green-bright`, off in `stone-light` with a `stamp-red` diagonal slash), pause icon (two chalk bars), tutorial arrow down and right (24 × 20 each, candy-yellow, ink outline, hand-drawn chunky shape), "?" silhouette, Wearing check mark.
  - [x] 2.3 Logo (large for title + boot splash, small for the menu), "Coming soon" plank (pre-rotated, stepped diagonal), "New best!" stamp (pre-rotated −8°, stamp-red with chalk lettering), "Crypt Closet" sign.
  - [x] 2.4 Level card pictures (184 × 72): Zombie Run (a Sunny Village Green scene with the zombie and a villager, reusing the 3.6 backdrop colours and character maps), Horde Rush (farmhouse, lanes, a couple of zombie silhouettes), Pitchfork Panic (moonlit village, the path, a pitchfork mob far behind). Cute-Halloween, no weapons drawn as weapons (a pitchfork is a farm tool held up, no points aimed at anyone), no candy-yellow, no stamp-red.
  - [x] 2.5 HUD band frame, target sign (parchment, `rounded.sm`), pet cushion, stats chalkboard (same family as the report card board).
  - [x] 2.6 Zombie hands: `ui_hand_left.png`, `ui_hand_right.png` (the tool mirrors the left map), and the 10 glow sheets `ui_finger_glow_<l|r>_<pinky|ring|middle|index|thumb>.png`, each **2 frames** (strong 2 px candy-yellow outline, weak 1 px) **the same size as the hand image**, transparent except the lit finger (bright fill + outline, plus the bump on the index fingers), so a glow overlay sits at the hand's own position with no offsets. Hands fit the 312 × 48 area mirrored about x 156 (Dev Notes "Hands").
  - [x] 2.7 Report card extras: chalk tray with two chalk stubs, smiling moon (art-moon, cute face), a bat (bat-purple) to replace the `BatWings` / `BatBody` rects.
  - [x] 2.8 Welcome Gift: vertical pumpkin ribbon 9-slice, bow.
  - [x] 2.9 Closet: tile frame 9-slices for parchment / stone / disabled fills, tag 9-slices for pumpkin / zombie-green / zombie-green-bright, mirror frame.
  - [x] 2.10 Countdown numerals 3, 2, 1 at 64 px: **decision for the dev, then Gate 1**: either the font (`Press Start 2P` 64 px, candy-yellow) with a 1 px ink outline drawn by four 1 px-offset ink labels plus the existing 2 px shadow label, or 3 sprites `ui_countdown_<n>.png`. Pick the font route first (no new art); if Godot's `outline_size` gives hard palette-only pixels with `antialiasing = none`, use that instead of four labels. Confirm with a screenshot pixel check (no off-palette pixels).
  - [x] 2.11 Run the tool, `--import`, commit PNG + `.import` (Lossless `compress/mode=0`, no mipmaps; Nearest is the project default, don't set a per-file filter).
- [x] **Task 3: Gate 1 — the sheet review (AC: 4, 8)**
  - [x] 3.1 Add the UI sheets to the art review: extend `scenes/debug/art_review.tscn` / `scripts/debug/art_review.gd` (read both and `tests/unit/test_art_review.gd` first; follow their pattern) or add `scenes/debug/ui_art_review.tscn` (note: `scenes/debug/` is **not** export-excluded; like the existing art review it ships but is only reachable from debug builds, so follow how `art_review.tscn` is reached today). Show every UI sheet at 1× and 3×, the 9-slices stretched to two real sizes each, the hands with each finger lit (both frames), and a grayscale copy of the hands (`Image` → luminance, palette-free is fine for a debug view only).
  - [x] 3.2 Screenshots to `_bmad-output/implementation-artifacts/screenshots/5-0/` (`gate1-*.png`). Show Smuck with the sheet list. Record the answer verbatim with the date in `## Art Approval`. **Don't wire the scenes before Gate 1 passes**; redraw what Smuck asks for and re-show.
- [x] **Task 4: Shared theme and PixelButton (AC: 4, 6, 7)** — `data/ui_theme.tres`, `scripts/ui/pixel_button.gd`
  - [x] 4.1 Replace the 5 `StyleBoxFlat`s of `PixelButton` with `StyleBoxTexture`s (`texture_margin_*` = the sheet's corner size; `axis_stretch_*` = `STRETCH` for flat fills, `TILE` where the plank grain must not smear; `content_margin_*` so the label sits where it does today: 8 / 4 / 8 / 4 plus the 2 px shadow at the bottom). `focus` = the stepped ring with `expand_margin_* = 2` (outside the outline, as today). Keep `normal_focused` (the focused fill swap) and the font colours.
  - [x] 4.2 Add theme type variations for the shared boxes (base type `Panel` or `PanelContainer` as each user needs): `WoodPanel`, `StonePanel`, `Sign`, `SignGrey`, `Chalkboard`, `Keycap`, `CandySign`, `BrainPill`. Scenes set `theme_type_variation` and drop their `StyleBoxFlat` sub-resources.
  - [x] 4.3 `PixelButton`: the **squish** = the `pressed` / `hover_pressed` art drops 2 px onto where the shadow was (art does it; no tween, input is committed on the frame it arrives). The **focus bounce** (EXPERIENCE Game Feel, 1 px up and back, ~0.1 s, look values): only when the button's parent is **not** a `Container` (a container would reset `position`); a tween on `position:y` that always ends exactly at rest; never runs on a hidden or disabled button. Fix the 4.2 deferral: the focused `normal` override is removed when the button is disabled or hidden while focused (`visibility_changed`, and a `disabled` check in `_on_focus_changed`). Update the header (drop "Placeholder chrome; Story 5.0 brings …").
  - [x] 4.4 Report card: `%PlayAgainButton` and `%MenuButton` become `PixelButton` (script + `theme_type_variation`). Remove `report_card.gd`'s own focus swap (`button_normal` / `button_focused` exports, `_on_button_focus_changed`) and the scene's button `StyleBoxFlat`s; the visible result (pumpkin-light fill + candy ring when focused, chalk label at rest) must not change. Keep the guard, `_leave()`, the reveal and the focus on Play Again.
  - [x] 4.5 `tests/unit/test_ui_theme.gd`: replace `test_pixel_button_boxes_are_square` with: every `PixelButton` box is a `StyleBoxTexture` whose texture is under `res://assets/sprites/ui/`, margins > 0; the focus ring still sits outside the outline (expand 2). Keep the font tests. `tests/unit/test_pixel_button.gd`: add disabled-while-focused and hidden-while-focused drop the override; the bounce ends at rest and is skipped inside a container.
- [x] **Task 5: Title, loading page and boot splash (AC: 1, 2, 3)**
  - [x] 5.1 `scenes/screens/title.tscn`: `%Logo` becomes a `TextureRect` with `ui_logo.png` (centred, 1×, `mouse_filter` ignore); keep `%Prompt` ("Click or press any key", chalk, 16 px) and the night `Background`. `test_title.gd::test_placeholder_logo_is_shown` becomes "the logo is the ui_logo texture" (and the `mouse_filter` test still passes). `title.gd` is unchanged.
  - [x] 5.2 `project.godot`: `application/boot_splash/bg_color = Color(0.16862746, 0.11372549, 0.24705882, 1)` (#2B1D3F), `application/boot_splash/image = "res://assets/sprites/ui/menu/ui_logo.png"`, `application/boot_splash/use_filter = false`, `application/boot_splash/stretch_mode = 0`, `application/boot_splash/show_image = true`; and `rendering/environment/defaults/default_clear_color` = night (kills a grey frame between splash and the first screen). `tests/unit/test_project_settings.gd`: assert all of them.
  - [x] 5.3 `export_presets.cfg` Web `html/head_include`: a `<style>` block (Dev Notes "Loading page CSS"). It overrides by coming after the shell's own `<style>`. No `<script>`, no external fonts or files, no text. `tests/unit/test_export_presets.gd`: the head include contains the night, pumpkin and dusk hexes, `#status-progress`, `image-rendering: pixelated`, and `html/custom_html_shell` is empty (unless 5.5 says otherwise).
  - [x] 5.4 Night letterbox (closes the 1.2 deferral): with `default_clear_color` = night, check whether the web and desktop letterbox bars turn night. Also set `body { background: #2B1D3F }` in the head include. If the engine still draws black bars, record it in the Debug Log and leave the 1.2 item open (it is not an AC).
  - [x] 5.5 Web check (Task 10): throttle the network in the browser pane or Chrome DevTools ("Slow 4G") to see the loading page fill; then boot splash; then title. Watch for a white, black or grey frame between them on Chrome, Edge and Firefox. If the head include can't produce the look (for example a browser ignores the `<progress>` pseudo-elements), switch to `html/custom_html_shell` (copy the 4.7.2 `godot.html` from `%APPDATA%/Godot/export_templates/4.7.2.stable/web_nothreads_release.zip`, keep every `$GODOT_*` placeholder and the JS untouched) and write why here.
- [x] **Task 6: Main menu and level cards (AC: 1, 6)**
  - [x] 6.1 `main_menu.tscn`: `%Logo` becomes the small logo `TextureRect` inside the approved 144, 16, 352, 40 slot (remove `LogoLabel` and `StyleBoxFlat_logo`; keep the node name `Logo` if a test reads it: check `test_main_menu.gd`). `PostLeft` / `PostRight` become the wood signpost art; `%ClosetButton` stays a `PixelButton` with its label (dynamic text uses the font). Storage notice: parchment `Sign` variation plus a pixel thumbtack (no red, no danger icon).
  - [x] 6.2 `level_card.tscn`: `Frame` = card-frame 9-slice (`rounded.lg`), `Shadow` stays the 2 px ink drop (or is baked into the frame; either way the lift still grows it), `Picture` keeps `%Picture` (TextureRect), `ComingSoonPlank` = the hand-lettered plank `TextureRect` (remove `PlankLabel`), `NameSign` = `Sign` / `SignGrey` variation (drop the `sign_style` / `sign_coming_soon_style` exports or point them at theme boxes; keep the same swap), `FocusRing` = the stepped ring. Level names stay font text on the sign (Dev Notes "Decisions" #2).
  - [x] 6.3 `data/levels/level_registry.tres`: `card_picture` for all three playable-or-coming entries = `ui_level_card_<id>.png` (Zombie Run replaces the `far.png` atlas region). `level_entry.gd` doc: drop "placeholder until Story 5.0". `PictureFill` (the flat fill for a null picture) stays as the NFR16 fallback.
  - [x] 6.4 Focus bob (EXPERIENCE "Lifts 2 px with a gentle bob while focused"; `level_card.gd` header names 5.0): while focused, `%Frame.position.y` alternates between `-LIFT_PX` and `-LIFT_PX - 1` (look values: 1 px, ~0.5 s period, driven in `_process` like the arrow bob, whole pixels); on unfocus it returns to exactly `0`, and a test can read the rest value. Never touches `position.x` (the wiggle owns x). Update the header.
  - [x] 6.5 `menu_toggle.gd` / `.tscn`: `%Icon` becomes a `TextureRect` showing frame 0 (on) or 1 (off) of the kind's icon sheet (an `AtlasTexture` per frame, or two textures); remove `_draw_icon`, the colour consts and `SLASH_PX`. Keep `Kind`, `CAPTIONS`, `flipped`, `show_state`, `is_on`, `get_focus_target`, not `toggle_mode` (the 4.2 decision still holds). `test_menu_toggle.gd::test_the_slash_carries_the_off_state` (deferred: "asserts constants only") becomes a real check: the off frame contains stamp-red pixels on a diagonal and the on frame none.
- [x] **Task 7: Run screen (AC: 1, 5, 6)**
  - [x] 7.1 `hud.tscn`: `Band` = HUD band 9-slice (wood-dark fill, wood frame, 1 px ink top edge), `TargetSign` = `Sign`, `Stats` = `Chalkboard`, `PetCushion` = cushion art, `CapsHint` = `CandySign`, `StartPrompt` keeps its ink strip (a flat ink box is the design, not a placeholder; make it a 9-slice only if Gate 2 asks), `PauseButton` = round 24 × 24 button art (normal / hover / pressed) with the pause icon replacing `BarLeft` / `BarRight` (keep the button not keyboard-focusable during a run, as today). Every rect in the 2.5 sketch table stays. `hud.gd` header: drop "Placeholder chrome until Story 5.0".
  - [x] 7.2 `zombie_hands.gd`: replace the rect drawing with textures: in `_draw()`, draw `ui_hand_left` / `ui_hand_right` at their fixed positions, then for each lit `(hand, finger)` draw frame 0 (strong) or 1 (weak) of its glow sheet at the same position (frame = `0 if _outline_width == OUTLINE_STRONG else 1`). Keep `PULSE_HZ`, `OUTLINE_STRONG` / `OUTLINE_WEAK`, `show_char`, every getter and their meaning (`get_finger_fill` still returns the palette fill the sprite uses for that finger; `has_bump` unchanged). The `LEFT_FINGERS` / `LEFT_PALM` rects either go (if no test needs them) or are kept as documentation of where each finger is in the sprite: read `test_zombie_hands.gd` first. Preload the textures (no per-frame loads). Missing texture: `Log.warn` once, draw nothing, never crash (NFR16).
  - [x] 7.3 `pause_panel.tscn` / `pause_panel.gd`: `Panel` = `StonePanel`, `TitleSign` = `Sign` with "Paused" (font, heading 24 px), `ResumeButton` / `QuitButton` = `PixelButton`, `MusicToggle` / `SoundToggle` = `MenuToggle` instances (kinds MUSIC / SOUND, icon + caption, like the menu). Keep the node names and the four signals. `open(music_on, sound_on)` calls `show_state()` on each toggle (no signal), focuses Resume; a toggle's `flipped(on)` re-emits `music_toggled(on)` / `sound_toggled(on)` while visible. Wire focus neighbours (Up/Down between Resume, Quit and the toggle row; Left/Right between the toggles) using `get_focus_target()`. Remove `_update_toggle_texts`. Update `test_pause_panel.gd` (it reads `.text` "Music: on" and `.button_pressed` today) and `tests/integration/test_run_frame.gd` where it drives `%MusicToggle` / `%SoundToggle` (grep them): drive `get_focus_target().pressed` or `flipped`, assert `is_on()`. `run_frame.gd` needs no change (same signals).
  - [x] 7.4 `countdown.tscn` / `countdown.gd`: the Task 2.10 choice; numbers, timing and `finished` unchanged; header drops "Placeholder look until Story 5.0".
- [x] **Task 8: Report card, Welcome Gift, Closet, arrow, brain counter (AC: 1, 6)**
  - [x] 8.1 `report_card.tscn`: `Board` + `BevelTop` / `BevelLeft` + `Surface` → the chalkboard 9-slice (frame 416 × 276 at (16, 12), board surface rect unchanged so every row, heading and value keeps its place); `Tray` + `ChalkStub0/1` → the tray sprite; `Stamp` (Panel + `Inner` + `Text`) → a `TextureRect` of the pre-rotated stamp (keep the node name `%Stamp`, its show/hide timing and the "must not overlap the heading or any row" rule: `test_stamp_clear_of_heading_and_rows` keeps passing; `test_report_card.gd:128` reads `%Stamp/Text`: change it to assert the stamp texture); `MoonWide` / `MoonTall` → the moon sprite; `BatWings` / `BatBody` → the bat sprite; `EnterHint` / `EscHint` → `Keycap` variation, same text and rects. The wall, window, floor `ColorRect`s are the approved 2.9 composition in palette colours: keep them. Header: drop "Placeholder chrome until Story 5.0".
  - [x] 8.2 `welcome_gift.tscn`: `Panel` + `Wood` → `WoodPanel`, `Ribbon` → ribbon 9-slice, `Bow` → bow sprite, `Sign` → `Sign`, `BrainIcon` + `Shade` → a `TextureRect` of the 32 px brain icon. Every rect in the 4.5 layout table stays; the gift logic is untouched. Header updated.
  - [x] 8.3 `brain_counter.tscn`: the pill = `BrainPill` (`rounded.full`, wood-dark, ink), `Icon` + `Shade` → a `TextureRect` of the 16 px brain icon (keep the node name `Icon` if a test reads it). `set_count` unchanged. Header: the count-up tick and pop move to Story 5.1 (Dev Notes "Out of scope").
  - [x] 8.4 `closet_item_tile.gd` / `.tscn`: `_box(fill)` (a `StyleBoxFlat`) becomes a lookup of the tile frame / tag `StyleBoxTexture` for that state (preloaded or from the theme); `%Question` (font "?") → the "?" silhouette `TextureRect`; `%Check` (`Line2D`) → the check sprite; `FocusRing` → the stepped ring. `state_for`, `info_lines`, the wiggle, the info words and the 68 px tile size (approved deviation) stay. The palette `const`s that only fed `_box` go. Header updated.
  - [x] 8.5 `confirm_prompt.tscn`: `Panel` + `Wood` → `WoodPanel`, `Sign` → `Sign`, Yes / No already `PixelButton`. Scrim unchanged (night 60 %, the one alpha). `crypt_closet.tscn`: `Title` / `TitleLabel` → the hand-lettered "Crypt Closet" sign `TextureRect` (keep the node `Title`), `Mirror` + `Glass` → the mirror frame art, `InfoSign` → `Sign`. Header: drop "Later: final art and juice (5.0 / 5.1)" → "Later: juice and Closet music (5.1)".
  - [x] 8.6 Tile icons (4.4 deferral "the pumpkin sits low and small"): set `hat_pumpkin.tres` `icon` to an `AtlasTexture` of `hat_pumpkin.png` cropped to its opaque bounding box, so the tile centres it. No new PNG. The pet keeps its first idle frame. Check `test_catalogue.gd` / `test_closet_item_tile.gd` for icon assertions first.
  - [x] 8.7 `tutorial_arrow.gd`: draw the arrow textures (down / right) instead of the polygon; keep `ARROW_SIZE` 24 × 20, `point_at` positions, the bob via `draw_set_transform`, `MOUSE_FILTER_IGNORE`, `FOCUS_NONE`. Header updated.
- [x] **Task 9: Tests (AC: 4, 5, 6)**
  - [x] 9.1 New `tests/unit/test_art_ui.gd` (reads PNG bytes like `test_art_sprites.gd`; copy its helpers): a `UI_SHEETS` table `path → {size, frames}` that matches Dev Notes "UI sheet list" exactly, and for **every** `.png` under `res://assets/sprites/ui/` (walk the folders, so an unlisted file fails): listed in the table; hard alpha; palette only; Lossless, no mipmaps; the ink outline rule except the listed exemptions; `stamp-red` only in the stamp and the toggle off frames; `candy-yellow` only in the focus ring, the glow sheets, the tutorial arrows and the candy sign; no `candy-yellow` / `stamp-red` in the level card pictures; glow sheets are the same size as their hand; every 9-slice is at least `2 × margin + 1` in each axis and its `StyleBoxTexture` margins in `ui_theme.tres` match the table.
  - [x] 9.2 Grayscale guard (AC 5) in `test_art_ui.gd`: for each glow sheet, the lit finger's fill luminance (Rec. 709) is at least 0.15 above `zombie-green`'s, and the outline pixels (candy-yellow) form a ring around the finger in both frames (strong frame ring width 2, weak 1). Record the numbers in the Debug Log.
  - [x] 9.3 New `tests/unit/test_no_placeholder_chrome.gd`: no `StyleBoxFlat` and no `corner_radius` in any `.tscn` under `scenes/ui/`, `scenes/screens/` (except `keyboard_test.tscn`, a debug screen), `scenes/run/`, and in `data/ui_theme.tres`; no `draw_rect` / `draw_colored_polygon` / `draw_line` in `scripts/ui/*.gd` and `scripts/run/zombie_hands.gd`. (The report card's palette `ColorRect` backdrop is allowed; `ColorRect` backgrounds and the scrim are allowed.)
  - [x] 9.4 Update the placeholder-look tests, nothing else: `test_ui_theme.gd` (4.5), `test_pixel_button.gd` (4.5), `test_title.gd` (logo), `test_menu_toggle.gd` (icons), `test_pause_panel.gd` + `test_run_frame.gd` (toggles, 7.3), `test_report_card.gd` (stamp text, button styling, focus fill), `test_zombie_hands.gd` (drawing, keep every behaviour test), `test_closet_item_tile.gd` (box colours → state art), `test_level_card.gd` (sign style, plank), `test_tutorial_arrow.gd` (still 24 × 20, positions), `test_brain_counter.gd`, `test_welcome_gift.gd` / `test_main_menu.gd` / `test_crypt_closet.gd` (only node-type changes; every rect test stays), `test_project_settings.gd`, `test_export_presets.gd`, `test_level_registry.gd` ("Zombie Run has a placeholder card picture" → each entry's picture is its `ui_level_card_<id>.png`). Keep every behaviour assertion; if one must change, say why in the Debug Log.
  - [x] 9.5 **The real save trap** (4.5 incident): no test may write the real `save.json`. Any new screen instancing uses the existing temp-dir `PlayerData` seams (`test_crypt_closet.gd::_make_player_data`). Before and after each full run, `save.json` must equal its pre-run copy.
  - [x] 9.6 Full suite: `"/c/Program Files/Godot/Godot.exe" --headless --path . --import`, then `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`. **Confirm the baseline yourself at `3a39fa3`** (4.5 ended at 1187 plus its review patches) and report real counts.
  - [x] 9.7 Mutation pass (break, see a test fail, restore; report survivors honestly): an off-palette pixel in a UI PNG; a soft-alpha pixel; an unlisted PNG in `assets/sprites/ui/`; candy-yellow in a level card picture; a `StyleBoxFlat` back in `hud.tscn`; the boot splash bg back to grey; `use_filter = true`; the head include without the pumpkin bar; a glow sheet the wrong size; the lit finger drawn with the resting green; the toggle off frame without the slash; `PixelButton` keeping the override when disabled.
- [x] **Task 10: Gate 2 — in-game walk and approval (AC: 2, 3, 5, 8)**
  - [x] 10.1 Web debug export (`"/c/Program Files/Godot/Godot.exe" --headless --path . --export-debug "Web" build/web/index.html`), `web-debug` preview (port 8060, `.claude/launch.json`), the browser pane **on screen** (a hidden pane throttles to ~1 fps, 4.4 / 4.5). Fresh save via F3 → F8. Walk: loading page (throttled network) → boot splash → title → menu (Zombie Run card focused with its bob, the two Coming soon cards, toggles, Closet signpost, storage notice if shown) → Zombie Run: start prompt, a wrong key, the hands on several letters including a capital and the thumbs if reachable, the Caps Lock hint (3 capitals) → Esc: pause panel, flip Music and Sound, Resume → countdown → F6 → report card (stamp: play a second run for "New best!" or use the debug path) → Welcome Gift → Closet with the tutorial arrow → buy → Yes → wear → Esc → menu shows the hat. Then the release build check: `--export-release`, load once, the loading page and splash look the same.
  - [x] 10.2 Chrome, Edge and Firefox: the loading page → splash → title shows no white / grey / black flash (AC 3). The browser pane is Chromium; open the same `http://localhost:8060` in real Edge and Firefox for this check, or ask Smuck to, and record who checked which browser.
  - [x] 10.3 Screenshots to `screenshots/5-0/` (`gate2-<screen>.png`, every screen in the walk, plus a grayscale copy of the run HUD with a lit finger: make it with a small scratchpad script or ImageMagick-free Godot `Image` conversion, not by eye). Show Smuck. Record the verbatim answer with the date in `## Art Approval`. **Don't move to review without it.**
  - [x] 10.4 Windows: `--export-debug "Windows Desktop"`, run once: the boot splash is night with the logo, no grey flash, the title follows.
  - [x] 10.5 Checklist (pass / fail each, in the Debug Log): every AC 1 item seen in game; no `StyleBoxFlat` look left anywhere a kid can reach; text ≥ 16 px, nothing clipped, nothing outside the 16 px margin; focus visible on every focusable control (cards, buttons, toggles, tiles); pressed squish visible; Coming soon (grey + plank) vs. Available clearly different; the five tile states distinct in grayscale (feeds 5.2); the active target arrow and HUD letter during the end dance (3.5 deferral: decide "leave" or "hide", record); the console is clean (no missing-texture warnings).
- [x] **Task 11: Docs and wrap-up**
  - [x] 11.1 `docs/art-style-sheet.md`: a new "UI art (Story 5.0)" section: the UI sheet table (path, size, frames, 9-slice margins), 9-slice rules (corners stepped in the texture, margins = corner size, `STRETCH` vs `TILE`), the exemptions from the outline rule, where candy-yellow and stamp-red may appear, the hand-lettered alphabet rule, the countdown choice; section 1's "waits for approval" list marks Story 5.0 done. Keep test-quoted wording in step with the tests.
  - [x] 11.2 `deferred-work.md`: strike with `~~…~~ Done in 5.0: …` every item this story closes (Dev Notes "Deferred items closed"), and add "Deferred from: dev of story 5-0" with what is left (at least: the brain counter tick-up and pop, the conga ×N badge pop → 5.1; the first-mouse-move focus quirk if not fixed; Professor Zombie scale (Smuck's call, unchanged); level names on cards in the font (if Smuck keeps that); anything accepted at Gate 2).
  - [x] 11.3 LF line endings on every touched text file (`.gd`, `.tscn`, `.tres`, `.cfg`, `.md`).
  - [x] 11.4 Dev Agent Record, File List, Change Log; Status → `review`; `sprint-status.yaml` → `review`. Suggested commit: `Story 5.0: MVP UI art pass`.

## Art Approval

<!-- Gate 1 (Task 3.2): Smuck's verbatim answer on the UI sprite sheets, with the date. -->

**Gate 1 (sprite sheets), 2026-10-06:** "the art looks good, continue" — Smuck, on the 11 review pages
`screenshots/5-0/gate1-01` … `gate1-11` (all 65 UI sheets). Approved as shown, including the look-value
changes listed in the Debug Log (logo 292 × 114, `ui_ink_md` / `ui_ink_lg`, stone panel 32 × 32,
chalkboard 9s 8 with a 4 px frame, skewed stamp). The level-name question was not answered, so Decision 2
stands: level names stay font text on the parchment sign.

<!-- Gate 2 (Task 10.3): Smuck's verbatim answer on the in-game screens, with the date. -->

**Gate 2 (in-game screens), 2026-10-06:** "approve" — Smuck, on the 15 numbered screenshots `screenshots/5-0/gate2-01` … `gate2-15` (plus unnumbered extras: the run HUD in grayscale, a "New best" report card, a capital-letter HUD)
(loading page, title, menu, run HUD and its grayscale copy, pause panel and toggles, countdown, report card with
the stamp, Welcome Gift, Closet with the tutorial arrow, confirm prompt, Wearing, menu with the hat). The
Edge / Firefox / Windows flash check (Task 10.2 / 10.4) was asked for in the same message.

**Flash check (Task 10.2 / 10.4), 2026-10-06:** "looks good" — Smuck, in reply to the request to watch loading page →
splash → title in Edge and Firefox (`http://localhost:8060`) and the Windows debug build. Chromium (the browser pane)
was checked by the dev agent. Who checked: Chrome/Chromium — dev agent; Edge, Firefox, Windows — Smuck.

## Dev Notes

### What this story is (and isn't)

- **Is:** final pixel art for every MVP UI surface, generated by a new tool from ASCII maps and shapes; 9-slice `StyleBoxTexture`s in the shared theme replacing every placeholder `StyleBoxFlat`; textures replacing the code-drawn hands, toggle icons, pause bars, arrow, "?" and check; the styled web loading page and engine boot splash; migrating the last plain buttons to `PixelButton`; the button squish, the card focus bob; two approval gates.
- **Isn't:** any gameplay, economy, save or Router change; new screens; layout changes (every approved rect stays); audio, the chalk-scratch / chime / stamp thump, the brain counter tick-up and pop, the conga ×N pop (Story 5.1); the readability / plain-words audit (Story 5.2, though nothing here may break the 16 px floor); performance measurement (5.3); removing the debug keyboard-test screen (it is debug-only; leave it); post-MVP Locked / New card states (6.8); Professor Zombie's size (unchanged, Smuck's call); new hats or pets (Epic 9).

### UI sheet list (look values: Gate 1 may change sizes; the test table and the style sheet follow)

> **As built (code review 2026-10-06):** the sizes below are the planning values. Final sizes and margins are in `UI_SHEETS` in `tests/unit/test_art_ui.gd` and `docs/art-style-sheet.md` (e.g. `ui_logo` 292 × 114, `ui_panel_stone` 32 × 32, chalkboard 9s 8, `ui_logo_small` 282 × 36, `ui_bow` 48 × 20; `ui_ink_md` / `ui_ink_lg` were added at Gate 1 and back the `InkStrip` start prompt and `ShadowMd`).

All under `assets/sprites/ui/`. "9s m" = 9-slice with corner margin m px. Outline = the 1 px ink rule applies.

| File | Size | Frames | Use | Notes |
|---|---|---|---|---|
| `common/ui_button.png`, `_focus`, `_pressed`, `_disabled` | 16 × 18 | 1 each | PixelButton | 9s 4 (top) / 6 (bottom, incl. the 2 px shadow); `md` corners; wood + wood-light bevel / pumpkin-light / pumpkin (shifted down 2, no shadow) / disabled-fill (no shadow) |
| `common/ui_focus_ring.png` | 12 × 12 | 1 | every focus ring | 2 px candy-yellow, stepped corners, transparent centre; **outline-exempt** (the ring is its own edge) |
| `common/ui_panel_wood.png` | 24 × 24 | 1 | WoodPanel | 9s 8, `lg` corners, wood planks, wood-dark frame, wood-light bevel; corner nail allowed |
| `common/ui_panel_stone.png` | 24 × 24 | 1 | StonePanel | 9s 8, stone blocks, stone-light highlight |
| `common/ui_sign.png`, `ui_sign_grey.png` | 12 × 12 | 1 each | Sign, SignGrey | 9s 4, `sm` corners, parchment + parchment-shade / stone-light |
| `common/ui_keycap.png` | 12 × 12 | 1 | Keycap | 9s 4, parchment with a 1 px darker bottom lip |
| `common/ui_candy_sign.png` | 12 × 12 | 1 | CandySign (Caps Lock hint) | 9s 4, candy-yellow |
| `common/ui_brain_pill.png` | 28 × 28 | 1 | BrainPill | 9s 12 (`full` rounding), wood-dark |
| `common/ui_brain_icon.png` | 16 × 16 | 1 | counter | art-brain-pink + shade, cute, no anatomy |
| `common/ui_brain_icon_big.png` | 32 × 32 | 1 | Welcome Gift | a separate drawing, not a scale |
| `common/ui_icon_music.png`, `_sound.png`, `_fullscreen.png` | 20 × 20 | 2 (on, off) | MenuToggle | off frame: stone-light icon + stamp-red diagonal slash |
| `common/ui_icon_pause.png` | 12 × 12 | 1 | pause button | two chalk bars, ink outline |
| `common/ui_pause_button.png`, `_hover.png`, `_pressed.png` | 24 × 24 | 1 each | HUD pause | round (`full`), wood |
| `common/ui_arrow_down.png`, `ui_arrow_right.png` | 24 × 20 | 1 each | TutorialArrow | candy-yellow, ink outline |
| `common/ui_check.png` | 12 × 10 | 1 | Wearing tag | zombie-green-dark check, ink outline |
| `menu/ui_logo.png` | ≈ 384 × 96 | 1 | title, boot splash, loading page | hand-lettered "Zombies Teach Typing", two lines; cute-Halloween (a pumpkin, a bat); ink outline |
| `menu/ui_logo_small.png` | ≤ 352 × 40 | 1 | main menu | the same lettering, one line, own drawing |
| `menu/ui_level_card_zombie_run.png`, `_horde_rush.png`, `_pitchfork_panic.png` | 184 × 72 | 1 each | card pictures | scenes, **outline-exempt** like backdrops; no candy-yellow / stamp-red |
| `menu/ui_card_frame.png` | 24 × 24 | 1 | LevelCard frame | 9s 8, wood-dark, `lg` |
| `menu/ui_coming_soon.png` | ≈ 192 × 40 | 1 | plank | wood plank pre-rotated (stepped), hand-lettered "Coming soon" in chalk, two nail heads |
| `menu/ui_signpost.png` | ≈ 16 × 48 | 1 | Closet signpost posts | wood-dark |
| `menu/ui_thumbtack.png` | 8 × 8 | 1 | storage notice | pumpkin pin (never red) |
| `hud/ui_hud_band.png` | 24 × 24 | 1 | HUD band | 9s 8, wood-dark fill, wood frame, 1 px ink top edge |
| `hud/ui_cushion.png` | 48 × 48 | 1 | pet cushion | parchment + shade |
| `hands/ui_hand_left.png`, `ui_hand_right.png` | ≈ 64 × 48 | 1 each | finger guide | palms down, zombie-green, f/j bumps (zombie-green-dark) on the index fingertips |
| `hands/ui_finger_glow_<l\|r>_<pinky\|ring\|middle\|index\|thumb>.png` | = hand size | 2 (strong, weak) | lit finger | bright fill + candy-yellow outline 2 px / 1 px; index sheets keep the bump; **outline-exempt** (the candy outline is the edge) |
| `report_card/ui_chalkboard.png` | 32 × 32 | 1 | Chalkboard (report card and HUD stats) | 9s 12, wood frame, chalkboard surface, ink |
| `report_card/ui_chalk_tray.png` | ≈ 408 × 12 | 1 | tray + two stubs | |
| `report_card/ui_new_best.png` | ≈ 168 × 56 | 1 | stamp | pre-rotated −8°, stamp-red, chalk lettering, stepped edges |
| `report_card/ui_moon.png` | ≈ 28 × 26 | 1 | window moon | art-moon, smiling, ink outline |
| `report_card/ui_bat.png` | ≈ 16 × 8 | 1 | window bat | bat-purple, cute |
| `closet/ui_tile_parchment.png`, `_stone.png`, `_disabled.png` | 16 × 16 | 1 each | tile frames | 9s 4, `md` |
| `closet/ui_tag_pumpkin.png`, `_green.png`, `_bright.png` | 12 × 12 | 1 each | tile tags | 9s 4 |
| `closet/ui_locked.png` | 32 × 32 | 1 | "?" silhouette | ink-muted shape on transparent |
| `closet/ui_closet_sign.png` | ≈ 224 × 32 | 1 | "Crypt Closet" | hand-lettered on parchment |
| `closet/ui_mirror.png` | 24 × 24 | 1 | mirror frame | 9s 8, wood frame, night glass (or keep `Glass` ColorRect inside) |
| `closet/ui_ribbon.png`, `ui_bow.png` | 24 × 12 / 48 × 20 | 1 each | Welcome Gift | ribbon tiles vertically; pumpkin, ink |

### Loading page CSS (head include, verified against the 4.7.2 shell)

The default 4.7.2 shell (`godot.html` in `web_nothreads_release.zip`) already: paints `#status` with `$GODOT_SPLASH_COLOR` (= `application/boot_splash/bg_color`), shows `<img id="status-splash" src="$GODOT_SPLASH">` (= `application/boot_splash/image`, exported as `index.png`), adds `use-filter--false` → `image-rendering: pixelated` and `fullsize--…` / `show-image--…` classes, and shows a bare `<progress id="status-progress">` at `bottom: 10%; width: 50%`. `body` is black. `$GODOT_HEAD_INCLUDE` comes **after** the shell's `<style>`, so equal-specificity rules in it win. So the include only needs:

```html
<style>
:root { --zts-unit: min(calc(100vw / 640), calc(100vh / 360)); } /* one game pixel, as the viewport stretch computes it */
body, #status { background-color: #2B1D3F; }
#status-splash { image-rendering: pixelated; width: calc(384 * var(--zts-unit)); max-width: 90%; height: auto; }
#status-progress { appearance: none; -webkit-appearance: none; height: calc(12 * var(--zts-unit)); width: 40%; border: calc(1 * var(--zts-unit)) solid #1E1428; background-color: #4A3366; border-radius: 0; }
#status-progress::-webkit-progress-bar { background-color: #4A3366; }
#status-progress::-webkit-progress-value { background-color: #F07A1C; }
#status-progress::-moz-progress-bar { background-color: #F07A1C; }
#status-progress:indeterminate { background-color: #4A3366; }
#status-notice { background-color: #F6E7C1; color: #1E1428; border: 2px solid #1E1428; border-radius: 0; }
</style>
```

This is a starting point, not a spec (`384` = the logo width; use the real one). Check it in Chrome, Edge and Firefox. Goal: the splash image and the bar sit where and at the size the title's logo will appear (the game scales 640 × 360 by `min(w/640, h/360)` with fractional scaling), so loading → title doesn't jump. Indeterminate (no total yet): Firefox animates stripes on `:indeterminate` `<progress>`; make it a flat dusk track (no motion is fine; EXPERIENCE "bar keeps moving" is met once totals arrive). The notice only shows on a failure (e.g. missing WebGL); it stays plain words from the engine, restyled parchment, never red.

**Engine splash vs. title size.** With `stretch_mode = Disabled` (AC 3, "no stretch"), the engine draws the logo at its native 384 px in window pixels, while the title draws it at the viewport scale (~2.13× on 1366 × 768). That's a size step, not a flash, so AC 3 holds. If it looks bad at Gate 2, the alternative is a 640 × 360 splash image composed like the title with `stretch_mode = Keep` (scales exactly like the game). That changes AC 3's wording: ask Smuck, don't switch silently.

### Hands

- Area 312 × 48 (sketch table: x 64–376, y 308–356). Today's code geometry: left palm (60, 30, 44, 16), fingers 8 px wide at x 62 / 72 / 82 / 92, thumb (103, 32, 15, 8); right = mirror about x 156 (`MIRROR_WIDTH 312`). The sprites may be redrawn bigger (up to the full 48 px height, ~64 px wide each), keeping the gap under the target sign and the same mirroring.
- 10 glow states = 5 fingers × 2 hands (FR16/FR17: a capital lights its finger + the opposite pinky; Space lights both thumbs). Two frames per glow sheet carry the pulse (strong 2 px / weak 1 px), matching `get_outline_width()`; the pulse logic and timing stay in code.
- Brightness + shape (NFR8): `zombie-green-bright` fill vs `zombie-green` rest, plus the candy outline; bumps always visible on both index fingers, lit or not.

### Decisions (follow these; Smuck can overrule at Gate 1 / 2)

1. **Two gates.** Gate 1 on the sheets before wiring (cheap to redraw), Gate 2 on the screens. 3.6 did one review at the end; this story touches every screen, so a late "no" would be expensive.
2. **Level names on the cards stay font text** on the parchment sign. DESIGN marks hand-lettered level names `[ASSUMPTION]`; the hand-lettered sprites in this story are the logo, "Coming soon", "New best!" and "Crypt Closet" (fixed text that kids see on every visit). Ask at Gate 1; if Smuck wants lettered names, add `ui_level_name_<id>.png` and keep `display_name` for the report card heading.
3. **Two logo drawings** (title / boot splash big, menu small): the 4.2 slot is 352 × 40 and DESIGN forbids per-screen scaling.
4. **Glow sheets are full-hand-size overlays**: no per-finger offsets to drift.
5. **Theme variations, not per-scene boxes.** One place to change a sign's look.
6. **The report card's wall / window / floor `ColorRect`s stay** (approved 2.9 composition, palette colours, hard edges). Only the moon and the bat become sprites; the chalkboard, tray, stamp, keycaps and buttons become art.
7. **Countdown: font first** (Task 2.10).
8. **Pause toggles become icon toggles** (DESIGN Toggle; the 2.7 deferral "toggles show their state in words").
9. **Focus bounce only outside containers** (Task 4.3); the card bob is drawn on `%Frame` like the lift.

### Existing code: current state, what changes, what must be preserved

- `data/ui_theme.tres` (UPDATE): font Press Start 2P 16 px; `PixelButton` variation with 5 `StyleBoxFlat`s (normal wood, hover/normal_focused pumpkin-light, pressed pumpkin, disabled, focus ring with expand 2). Becomes `StyleBoxTexture`s + new variations. Preserve the font, the font colours, `normal_focused`.
- `scripts/ui/pixel_button.gd` (UPDATE): hover moves focus on real mouse motion; focus swaps `normal` to `normal_focused`. Preserve both. Add the bounce and the override fix.
- `scripts/ui/level_card.gd` / `scenes/ui/level_card.tscn` (UPDATE): states AVAILABLE / COMING_SOON, `chosen`, the wiggle on `%Frame.position.x`, the lift on `%Frame.position.y`, `sign_style` exports. 192 × 124 card: frame 4 + picture 184 × 72 + 4 + name sign 184 × 40 + 4.
- `scripts/ui/menu_toggle.gd` (UPDATE): code-drawn icons on `%Icon` (a `Control`). Becomes a texture. Not `toggle_mode` (keep).
- `scripts/ui/brain_counter.gd` / `.tscn` (UPDATE scene only): 80 × 28 pill, `Icon` + `Shade` `ColorRect`s, `%CountLabel`.
- `scripts/ui/closet_item_tile.gd` / `.tscn` (UPDATE): `_box()` `StyleBoxFlat` per state, font "?", `Line2D` check. 68 px tile (approved deviation from DESIGN's 48).
- `scripts/ui/confirm_prompt.gd` / `.tscn` (UPDATE scene): wood `Panel` + `Wood` rect, parchment `Sign`, Yes (208, 216, 96 × 32) and No `PixelButton`s, scrim. The arrow's RIGHT position depends on Yes's rect: don't move it.
- `scripts/ui/tutorial_arrow.gd` (UPDATE): polygon → texture. 24 × 20, positions tested.
- `scripts/screens/title.gd` / `.tscn` (UPDATE scene): `%Logo` is a `Label` today.
- `scripts/screens/main_menu.gd` / `.tscn` (UPDATE scene; script only if a node type it touches changes): logo `Panel` + `LogoLabel`, posts `ColorRect`s, `%ClosetButton` (PixelButton), storage notice `PanelContainer` (`StyleBoxFlat_notice`; keep `%StorageNotice`, mouse ignore, hidden when storage is persistent).
- `scripts/run/hud.gd` / `.tscn` (UPDATE scene): 7 `StyleBoxFlat`s; `PauseButton` with `BarLeft` / `BarRight`. `hud.gd` sizes the target sign at runtime (`_layout_target`): the sign's box must stay a 9-slice that stretches to 48 × 40, n × 32 + 16 × 40 and 304 × 48.
- `scripts/run/zombie_hands.gd` (UPDATE): see Task 7.2.
- `scripts/run/pause_panel.gd` / `.tscn` (UPDATE): plain `Button`s, toggles as `toggle_mode` Buttons with "Music: on" text. Runs `PROCESS_MODE_WHEN_PAUSED`: tweens on its children (button bounce) need the right process mode too (a `create_tween()` from a node inherits its pause mode; check the bounce runs while paused).
- `scripts/run/countdown.gd` / `.tscn` (UPDATE look only).
- `scripts/screens/report_card.gd` / `.tscn` (UPDATE): see Task 4.4 / 8.1. The 1.0 s guard is counted in `_process`; `%Stamp` shows last in the reveal; the Professor's slots (4.3). Don't touch them.
- `scripts/screens/welcome_gift.gd` / `.tscn`, `scripts/screens/crypt_closet.gd` / `.tscn` (UPDATE scenes; scripts only for header text): every rect test stays green.
- `data/levels/level_registry.tres`, `scripts/resources/level_entry.gd` (UPDATE), `data/cosmetics/hat_pumpkin.tres` (UPDATE icon), `project.godot`, `export_presets.cfg` (UPDATE).
- `scripts/debug/art_review.gd` / `.tscn` (UPDATE or a sibling `ui_art_review`), `tests/unit/test_art_review.gd`.
- **READ ONLY**: `tools/gen_art_prototypes.gd` (palette, helpers), `tools/gen_zombie_run_art.gd` (shape helpers, backdrop colours, character maps for the Zombie Run card picture), `tools/gen_cosmetics_art.gd`, `tests/unit/test_art_sprites.gd` / `test_art_backdrop.gd` (PNG-reading helpers to copy), `scripts/autoloads/router.gd` (fade colour is already night), `scripts/run/run_frame.gd`.

### Deferred items closed (strike in Task 11.2)

1.2 night letterbox (if 5.4 works); 2.5 "HUD chrome is placeholder"; 2.6 "hands are placeholder code-drawn rects"; 2.7 "pause panel and countdown are placeholder chrome … toggles show their state in words"; 2.9 "final chalkboard, chalk tray, stamp, pixel buttons, key-hint keycaps, smiling moon" and "pixel-button focus look is two parts … migrating the report card and pause panel is still Story 5.0" and "no hover cue on the unfocused button" (if the theme's hover box now differs; else leave); 3.5 "active target arrow and HUD letter during the dance; decide in 5.0" (record the decision); 4.2 "MenuToggle … toggle art can revisit it" (keep the decision, close) and "PixelButton keeps the focused normal override if disabled or hidden"; 4.2 review "`test_the_slash_carries_the_off_state` asserts constants only"; 4.4 "final Closet art …" (art part; the tick-down stays for 5.1) and "MVP tile icons … pumpkin sits low"; 4.5 "final Welcome Gift art … and the hand-drawn tutorial arrow". Leave open (move to 5.1): brain counter count-up tick and pop, the ×N badge pop.

### Godot 4.7 notes (verified locally on 4.7.2 this session)

- Boot splash settings and defaults: `application/boot_splash/bg_color` (default `(0.14, 0.14, 0.14)`), `show_image` (true), `stretch_mode` (enum `Disabled, Keep, Keep Width, Keep Height, Cover, Ignore`, default 1 = Keep), `use_filter` (true), `image` (`*.png`, empty = Godot logo), `minimum_display_time` (0 ms). `rendering/environment/defaults/default_clear_color` default `(0.3, 0.3, 0.3)`. There is **no** `boot_splash/fullsize` in 4.7 (it became `stretch_mode`); the web shell still uses a `fullsize--…` CSS class.
- `StyleBoxTexture`: `texture`, `texture_margin_left/top/right/bottom`, `expand_margin_*`, `content_margin_*`, `axis_stretch_horizontal/vertical` (`AXIS_STRETCH_MODE_STRETCH`, `_TILE`, `_TILE_FIT`), `draw_center`, `region_rect`, `modulate_color` (don't use modulate: palette only). With Nearest and pixel snap a stretched 1-colour middle stays crisp; a patterned middle must `TILE` and the target size should be a multiple of the pattern or use `TILE_FIT` (check by eye: no half-planks smearing).
- Fonts: Press Start 2P, antialiasing none, hinting none (tested). For a Label outline (`outline_size`, `font_outline_color`), check the pixels: a hard outline needs the font's antialiasing off (it is).
- `TextureRect`: `stretch_mode = STRETCH_KEEP` / `KEEP_CENTERED`, `expand_mode = EXPAND_KEEP_SIZE` for 1× sprites; never scale.
- An `AtlasTexture` per frame (the project's SpriteFrames pattern) is how a 2-frame icon or glow sheet is cut; preload once.
- Web: `$GODOT_SPLASH` is exported as `index.png` next to `index.html`; check it's the logo after export.

### Testing notes

- PNG checks read raw bytes like `test_art_sprites.gd` (`Image.load_from_file` on the res path's global path, not `load()`, so import settings don't alter pixels).
- Theme/scene checks: load `ui_theme.tres` and read `get_stylebox(&"normal", &"PixelButton")`; scan `.tscn` files as text for the placeholder guard.
- Temp `PlayerData`, `Router._store_payload`, `answer_delay_ms = 0`, `after_each` input reset for `_unhandled_input` tests: as in 4.4 / 4.5.
- GUT 9.7.1: `assert_push_error` / `assert_push_warning` match substrings.
- The flaky `test_audio_manager` pool test (deferred 4.2): rerun once before investigating.

### Previous story intelligence

- **4.5:** the real-save incident: `test_screen_flow.gd::test_every_screen_instantiates` instances every screen with the live autoloads; any `_ready()` that writes (the gift) must have a seam set first. This story adds no writes, but re-check after touching screens. Screenshots for approval were rendered in a real (non-headless) Godot window by a temporary `tools/_shot_*.gd` with a temp PlayerData and deleted after; the live walk needed the browser pane on screen. A String-vs-bool payload compare was a script error: keep type checks explicit.
- **4.4:** 68 px tiles, info sign for long words, focus ring on the tile's own edge, the prompt's 300 ms answer delay, no `await` in `_leave()`.
- **4.2:** text-fit / margin helpers in `test_main_menu.gd`; toggles not in `toggle_mode`; toggle columns at x 240 / 352 / 464.
- **3.6:** the art-story template: a generator tool reusing `Proto`, generalized art tests that walk every sheet, a style-sheet section, an art review scene, a named manual checklist, mutation pass, screenshots in `screenshots/<story>/`.
- **1.9:** the gate rule: no final art without Smuck's recorded approval; a rule Smuck changes is changed in the style sheet and its test in the same change.
- **Traps:** LF line endings, UTF-8, typed `for` variables (`untyped_declaration = Error`, tests too), scratchpad scripts over heredocs with apostrophes, `assert()` shows as SCRIPT ERROR in headless GUT (use `Log` + safe returns), `class_name` changes need `--import` before the suite.

### Git intelligence

- One commit per story with code, data, tests, screenshots and the story file. Last: `3a39fa3 Story 4.5: welcome gift and guided first purchase (code review patches applied, done)`. Art stories commit the PNGs with their `.import` files; generator tools stay in `tools/` (export-excluded).

### Project Structure Notes

- New: `tools/gen_ui_art.gd`; `assets/sprites/ui/{common,hud,hands,menu,closet,report_card}/*.png` + `.import`; `tests/unit/test_art_ui.gd`, `tests/unit/test_no_placeholder_chrome.gd`; screenshots `screenshots/5-0/`. Possibly `scenes/debug/ui_art_review.tscn` + script.
- Variance: `assets/sprites/ui/common/` is not in the architecture's tree (which lists `hud/`, `hands/`, `menu/`, `closet/`, `report_card/`); shared chrome (buttons, panels, signs, icons) has no feature home, so `common/` is added. Note it in the style sheet.
- Updated: see "Existing code". No new autoload, no new class except possibly a debug review script.

### Project Context Rules

- No `project-context.md`. Binding rules from `_bmad-output/game-architecture.md` and the UX spines:
  - Typed GDScript; `%UniqueName` refs; no `/root/` paths; typed past-tense signals; autoload connections disconnected in `_exit_tree`; no event bus.
  - Boundaries: screens navigate only through Router (seams); only AudioManager plays audio; only SaveService touches files; `.tres` in `data/`, classes in `scripts/resources/`; `JavaScriptBridge` / `OS.has_feature("web")` only in `WebPlatform` (this story needs none: the loading page is pure CSS).
  - Palette colours only (32); the night scrim at 60 % is the one alpha. Stepped corners from 9-slices. Candy-yellow = focus / look here. Stamp-red = stamp + toggle slash only. No gradients, glows, blur. One sprite scale, 1× at 640 × 360.
  - Look values are `const`s commented "look value, not a GDD number". NFR16: a missing texture logs once and never crashes. NFR9 / NFR11: plain words, 16 px floor, no timers.
  - Art: generated by tools from ASCII maps / fixed shapes; never hand-edited; PNG + `.import` committed; Lossless, no mipmaps.
- Tools: Godot `/c/Program Files/Godot/Godot.exe` (4.7.2); GUT 9.7.1; the Godot MCP server (`run_project`, `get_debug_output`); the built-in browser pane (`web-debug` in `.claude/launch.json`, port 8060).

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 5.0: MVP UI Art Pass] (ACs); Epic 5 goal; NFR7, NFR8, NFR9, NFR10, NFR13, NFR16
- [Source: _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md#Asset Requirements] (MVP UI asset list, l.403–415)
- [Source: _bmad-output/game-architecture.md] Project Initialization (boot splash / head include, l.110–117), Directory Structure (`assets/sprites/ui/…`, l.566–620), naming `ui_<element>[_<state>].png` (l.755)
- [Source: …/ux-designs/…/DESIGN.md] colours and contrast (l.336–393), typography and hand-lettered signs (l.395–415), shapes / 9-slice (l.460–468), Components (l.470–524), Do's and Don'ts (l.526–541)
- [Source: …/ux-designs/…/EXPERIENCE.md] Game Feel & Juice (l.173–189), State Patterns boot splash (l.116), Open Question on D11 (l.274)
- [Source: …/ux-designs/…/mockups/key-main-menu.html, key-run-hud.html, key-report-card.html]; [Source: …/sketches/hud-band-2-5.md, crypt-closet-4-4.md]
- [Source: docs/art-style-sheet.md] (rules, palette, outline test wording, generator method, approval)
- [Source: _bmad-output/implementation-artifacts/1-9-…, 3-6-…, 2-9-… (report card layout table), 4-2-… (menu layout table), 4-4-…, 4-5-… (gift layout table, save trap)]
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] items listed in "Deferred items closed"
- [Source: %APPDATA%/Godot/export_templates/4.7.2.stable/web_nothreads_release.zip → godot.html] (the default shell, read this session)
- [Source: scripts/ui/*.gd, scripts/run/hud.gd, zombie_hands.gd, pause_panel.gd, countdown.gd, scripts/screens/*.gd, data/ui_theme.tres, project.godot, export_presets.cfg, tests/unit/test_ui_theme.gd, test_export_presets.gd, test_project_settings.gd, test_art_sprites.gd]

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Debug Log References

- **Baseline (Task 9.6):** the full suite at `3a39fa3` in a scratch worktree: 67 scripts, **1190 tests, 1190 passing**,
  38732 asserts. The real `save.json` hash was unchanged before and after (`8dbc629…`).
- **Tool (Task 1):** `tools/gen_ui_art.gd` reads `Proto.PALETTE` from `gen_art_prototypes.gd` and copies the small helpers
  (as 3.6 / 4.3 did). Shapes are masks painted with a 1 px ink outline (any mask pixel with a 4-neighbour outside the mask is
  ink), so the outline rule holds by construction. The hand-lettered alphabet is a 9-row design grid (cap 7, x-height 5,
  descenders 2) drawn as scale × scale blocks (scale 2 for signs, 3 for the menu logo, 4 / 7 for the big logo), then outlined
  in ink with a 1 px top highlight and a per-letter bounce. The plank is rotated −8° by three shears (Paeth; whole rows and
  columns move, nothing is resampled) and its outline re-closed; the stamp is a stepped −8° column skew instead, which keeps
  the scale-3 chalk letters' uprights straight (the rotated version was ragged).
- **Look-value changes at Gate 1 (approved):** `ui_logo.png` 292 × 114 (two lines, slime drips, a pumpkin and a bat;
  taller than ≈ 96 because of the drips); `ui_logo_small.png` 281 × 35; `ui_panel_stone.png` 32 × 32 (a 16 px running-bond
  middle that tiles); `ui_chalkboard.png` 9s 8 with a 4 px frame (ink, wood-light, wood, ink) so the HUD stats labels at x 4
  sit on the board; `ui_coming_soon.png` 156 × 50; `ui_new_best.png` 144 × 59; `ui_closet_sign.png` 152 × 32;
  `ui_signpost.png` 8 × 16 (one post, used twice); added `common/ui_ink_md.png` (16, 9s 4) and `common/ui_ink_lg.png`
  (24, 9s 8): ink silhouettes with stepped corners for the tile / card drop shadows and the start-prompt strip (a square
  shadow would show past the stepped corners).
- **Hands (Task 2.6):** 64 × 48 each, placed at x 56 and x 192 of the 312 px area (mirror about x 156). Glow sheets are
  128 × 48 (strong, weak); the lit finger is drawn above the palm only, and its ring stops at the palm's top row.
- **Grayscale guard (Task 9.2):** Rec. 709 luma of the sRGB values: resting zombie-green 0.655, lit zombie-green-bright
  0.867 (gap **0.212** ≥ 0.15), candy-yellow ring 0.819. Strong frames have candy pixels 2 px out, weak frames none.
- **Countdown (Task 2.10):** font route chosen (no new art); the pixel check is done with the in-game screenshot (Task 7.4).
- **Theme (Task 4):** `data/ui_theme.tres` holds 30 `StyleBoxTexture`s over 28 UI sheets as type variations; `Bare`
  (a `StyleBoxEmpty`) is the tag with no box. `PixelButton`: the pressed box's content margins (top 6 / bottom 4 vs
  8 / 4 / 8 / 6) move the label down with the plank; `disabled` has no signal, so the redraw it causes is the hook
  (deferred `_refresh_fill`), and `visibility_changed` covers hiding.
- **Tests changed where they asserted the placeholder look** (behaviour kept): `test_report_card` (stamp is a
  sprite, buttons are PixelButtons, the 16 px walk counts 18 texts, was 19: the stamp label became art);
  `test_main_menu` (the text walk finds 9, was 12: the logo and two plank labels became art); `test_pause_panel`
  and `test_run_frame` (toggles are MenuToggles: `is_on()` instead of the "Music: on" text, new focus graph);
  `test_closet_item_tile` (theme variations instead of `StyleBoxFlat` colours); `test_level_card` (plank
  sprite, `SignGrey`); `test_level_registry` (every card has its picture); `test_menu_toggle` (a real pixel
  check of the slash); `test_title`, `test_ui_theme`, `test_pixel_button`, `test_zombie_hands`,
  `test_tutorial_arrow`, `test_catalogue`, `test_project_settings`, `test_export_presets` (additions).
- **Countdown (Task 2.10 / 7.4):** rendered "3" at 64 px with `outline_size` 1 and 2: both are hard,
  palette-only (only candy-yellow, ink and the background), but size 1 leaves gaps; size 2 (already in the 2.7
  scene) draws a closed 1 px ring. No change to the scene.
- **Report card stamp:** 144 × 59 at (290, 6), clear of the heading and row 0 (global y 67).
- **Menu logo:** padded to 282 × 36 so it centres in the 352 × 40 slot on whole pixels.
- **Mutation pass (Task 9.7), 12 / 12 caught:** off-palette pixel, soft alpha, unlisted PNG, candy-yellow in a card
  picture (`test_art_ui`); `StyleBoxFlat` in `hud.tscn` (`test_no_placeholder_chrome`); grey splash bg,
  `use_filter = true` (`test_project_settings`); head include without the pumpkin bar (`test_export_presets`);
  glow sheet 126 px wide (`test_art_ui` size); lit finger in the resting green (`test_art_ui`, first failure
  reported by the mirror check); toggle off frame without the slash (`test_menu_toggle`); PixelButton keeping the
  override when disabled (`test_pixel_button`). All files restored; the generator rerun is byte-identical (65 PNGs).
- **Full suite:** 70 scripts, **1231 tests, 1231 passing**, 39885 asserts (baseline 1190). The 4 "Villager state can
  only move forward" assertion messages are in the baseline log too. `save.json` unchanged before / after.
- **5.4 letterbox:** with `default_clear_color` and `body` night, the web bars are still **black** (the engine draws
  them); recorded, the 1.2 item stays open.
- **5.5 / 10.1 web walk (browser pane, Chromium, debug build):** loading page checked by reloading the exported
  `index.html` with its scripts stripped (the real CSS, frozen before the engine starts): night page, pixelated
  logo at 1.6 × (= the game's scale at 1024 × 768), pumpkin bar on a dusk track; head include works, no custom shell
  needed. Title → menu → Zombie Run (start prompt, a wrong key counted, hands on f / r / y) → Esc pause, toggles
  flipped by keyboard → Resume → countdown → F6 → report card → Esc → Welcome Gift → Closet with the arrow → Buy →
  Yes → Wear → Wearing → Esc → menu with the hat. No flash between screens in Chromium. Console: no warnings or
  errors (a flood of 4.3 `[DEBUG][cosmetics]` hat-slot lines, debug builds only). The first F8 reset missed its
  5 s confirm window (my timing, not a bug). The stamp and the capital-letter HUD were rendered in a real Godot
  window (`gate2-report-card-new-best.png`, `gate2-run-hud-capital*.png`), read-only. Release web export: same
  `index.png` (292 × 114) and CSS. Windows debug export: starts and quits cleanly (`--quit-after 180`, no errors);
  the visual splash check is Task 10.4 (Smuck: "looks good").
- **10.5 checklist:** every AC 1 item seen in game — pass; no `StyleBoxFlat` look a kid can reach — pass (guard
  test); text ≥ 16 px, nothing clipped, nothing outside the 16 px margin — pass (existing fit / margin tests green,
  screens checked); focus visible on cards, buttons, toggles, tiles — pass; pressed squish — pass (art + content
  margins, tested); Coming soon vs Available clearly different — pass; the five tile states distinct in grayscale —
  pass (stone / disabled / parchment fills plus "?", tag shapes and the check; feeds 5.2); the active target arrow
  and HUD letter during the end dance (3.5 deferral) — decided **leave**; console clean — pass.

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created.
- Story 5.0 implemented: 65 tool-generated UI sheets (`tools/gen_ui_art.gd`), the shared 9-slice theme, every MVP
  screen rewired (title, menu, level cards, toggles, HUD, hands, pause panel, report card, Welcome Gift, Closet,
  tiles, confirm prompt, brain counter, tutorial arrow), the boot splash and the restyled web loading page.
- Gate 1 and Gate 2 approved by Smuck (recorded verbatim in `## Art Approval`).
- New tests: `test_art_ui.gd` (every UI PNG's rules, the grayscale guard, theme margins), `test_no_placeholder_chrome.gd`,
  `test_ui_art_review.gd`; placeholder-look tests updated as listed in the Debug Log.
- Task 10.2 / 10.4: Edge, Firefox and the Windows splash checked by Smuck ("looks good"); Chromium by the dev agent.

### File List

New: `tools/gen_ui_art.gd` (+ `.uid`); `assets/sprites/ui/common/`, `hud/`, `hands/`, `menu/`, `closet/`, `report_card/`
(65 PNGs + `.import`); `scenes/debug/ui_art_review.tscn`; `scripts/debug/ui_art_review.gd` (+ `.uid`);
`tests/unit/test_art_ui.gd`, `tests/unit/test_no_placeholder_chrome.gd`, `tests/unit/test_ui_art_review.gd` (+ `.uid`s);
`_bmad-output/implementation-artifacts/screenshots/5-0/` (gate1-*, gate2-*).

Modified: `data/ui_theme.tres`, `data/levels/level_registry.tres`, `data/cosmetics/hat_pumpkin.tres`, `project.godot`,
`export_presets.cfg`, `docs/art-style-sheet.md`; scenes `scenes/run/hud.tscn`, `scenes/run/pause_panel.tscn`,
`scenes/screens/crypt_closet.tscn`, `scenes/screens/main_menu.tscn`, `scenes/screens/report_card.tscn`,
`scenes/screens/title.tscn`, `scenes/screens/welcome_gift.tscn`, `scenes/ui/brain_counter.tscn`,
`scenes/ui/closet_item_tile.tscn`, `scenes/ui/confirm_prompt.tscn`, `scenes/ui/level_card.tscn`, `scenes/ui/menu_toggle.tscn`;
scripts `scripts/resources/level_entry.gd`, `scripts/run/countdown.gd`, `scripts/run/hud.gd`, `scripts/run/pause_panel.gd`,
`scripts/run/zombie_hands.gd`, `scripts/screens/crypt_closet.gd`, `scripts/screens/report_card.gd`,
`scripts/screens/welcome_gift.gd`, `scripts/ui/brain_counter.gd`, `scripts/ui/closet_item_tile.gd`,
`scripts/ui/confirm_prompt.gd`, `scripts/ui/level_card.gd`, `scripts/ui/menu_toggle.gd`, `scripts/ui/pixel_button.gd`,
`scripts/ui/tutorial_arrow.gd`; tests `tests/integration/test_run_frame.gd`, `tests/unit/test_catalogue.gd`,
`tests/unit/test_closet_item_tile.gd`, `tests/unit/test_export_presets.gd`, `tests/unit/test_level_card.gd`,
`tests/unit/test_level_registry.gd`, `tests/unit/test_main_menu.gd`, `tests/unit/test_menu_toggle.gd`,
`tests/unit/test_pause_panel.gd`, `tests/unit/test_pixel_button.gd`, `tests/unit/test_project_settings.gd`,
`tests/unit/test_report_card.gd`, `tests/unit/test_title.gd`, `tests/unit/test_tutorial_arrow.gd`,
`tests/unit/test_ui_theme.gd`, `tests/unit/test_zombie_hands.gd`; `_bmad-output/implementation-artifacts/deferred-work.md`,
`_bmad-output/implementation-artifacts/sprint-status.yaml`, this story file.

## Change Log

- 2026-10-06: Story 5.0 implemented — MVP UI art pass (UI art tool and 65 sheets, 9-slice theme, every MVP screen
  rewired, boot splash and loading page, PixelButton squish / bounce / disabled fix, card focus bob, icon toggles in
  the pause panel); Gate 1 and Gate 2 approved; Edge / Firefox / Windows flash check confirmed by Smuck. Status → review.
- 2026-10-06: Code review patches applied (PixelButton two-way fill hook and relative pixel bounce with `get_rest_rect()`, bow rect, loading-bar stripes, ring-width / paused-bounce / StorageNotice tests). Status → done.
