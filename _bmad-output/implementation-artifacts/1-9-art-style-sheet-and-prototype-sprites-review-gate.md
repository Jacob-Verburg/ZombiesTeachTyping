---
baseline_commit: c21a580b6a7cf6b9104c30c53bd24025f968ddbf
---

# Story 1.9: Art-Style Sheet and Prototype Sprites (Review Gate)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As Smuck (art director),
I want the palette, pixel font, sprite standards and the first zombie and villager sprites approved before other art is made,
so that every later asset looks like one consistent game.

## Acceptance Criteria

1. **Palette file and style sheet.** Given `assets/palette/palette_32.png`, when it is inspected, then it holds at most 32 colors (exactly the 32 in `DESIGN.md`), and a style sheet in `docs/` records the palette, the sprite sizes (characters 32×32, brutes 48×48, tiles 16×16), the 1 px dark outline rule and the animation limits (2–6 frames at 8–12 fps) (NFR13).
2. **Font record.** Given the pixel font chosen in Story 1.3 (Press Start 2P), when the style sheet is written, then it records the font, its sizes (16 px UI, 32 px targets, 24 px paragraph text) and its license.
3. **Prototype sprites.** Given prototype sprites of the player zombie (idle 2f, walk 4f) and one villager (idle/wave 2f), using only palette colors, when they are shown in-game with the project's fractional scaling and nearest filtering, then they are crisp, kid-safe (no gore) and readable against a plain background.
4. **Approval gate.** Smuck records approval (or requested changes) in this story file (`## Art Approval`). No final art is produced until approval is given. Placeholder art (plain shapes in palette colors) stays allowed in any story before its final-art story (3.6, 4.3, 5.0).
5. **Tests.** What a machine can check (palette contents, sprite sizes, palette-only pixels, hard alpha, the outline rule, import settings, style-sheet contents, animation limits) is covered by GUT tests that pass. Looks (cute, readable, kid-safe) are Smuck's call in AC 4.

AC 1–4 are the epic's, verbatim in intent. AC 5 is added: the epic has no test AC, but every rule the style sheet states that can be a test should be one, so later art stories cannot drift.

## Tasks / Subtasks

- [x] **Task 1: Tests first** (AC: 1, 3, 5). Write the tests in Dev Notes → Testing requirements, run GUT, watch them fail (no files yet).
- [x] **Task 2: Palette** (AC: 1). `tools/gen_art_prototypes.gd` (`extends SceneTree`, same pattern as `tools/gen_placeholder_audio.gd`), run headless.
  - [x] 2.1 A `PALETTE` constant (name → hex, the 32 colors from `DESIGN.md` → Colors, in that order) and a writer that saves `assets/palette/palette_32.png`: **32×1 px, one pixel per color, fully opaque, no scaling**. The file is the master palette (architecture: "The 32-color master palette"), so it must be the raw data, not a pretty swatch sheet.
  - [x] 2.2 No 33rd color. The night scrim's 60% alpha (DESIGN.md → Elevation) is a UI runtime blend and is **not** in sprites or the palette file.
- [x] **Task 3: Prototype sprites** (AC: 3). In the same tool, draw each frame from an ASCII pixel map (one string per row, one character per pixel, a legend from character to palette **name**) and write the sheets. Frames sit side by side in one horizontal strip, each 32×32.
  - [x] 3.1 `assets/sprites/characters/zombie/zombie_idle.png` (64×32, 2 frames) and `zombie_walk.png` (128×32, 4 frames). The player zombie: zombie-green skin, big goofy friendly face, cute, no gore (Dev Notes → Art direction).
  - [x] 3.2 `assets/sprites/characters/villager/villager_wave.png` (64×32, 2 frames; this is the idle/wave animation, named `wave` per the architecture's animation names).
  - [x] 3.3 Every sprite obeys the rules in Dev Notes → Sprite rules (outline, hard alpha, palette only, transparent margin).
  - [x] 3.4 Run `--import` so Godot writes the `.png.import` files; check each has `compress/mode=0` (Lossless) and `mipmaps/generate=false`; commit the `.import` files like the audio ones. Fix the import settings in the `.import` file only if the defaults differ.
  - [x] 3.5 The tool exits non-zero on any write failure (as `gen_placeholder_audio.gd` does).
- [x] **Task 4: Art review scene** (AC: 3, 4). `scenes/debug/art_review.tscn` + `scripts/debug/art_review.gd` (Boundary 7: debug folder, never routed to, never instanced by the Router).
  - [x] 4.1 Builds one `SpriteFrames` per animation from the sheets with a pure `static func build_frames(sheet: Texture2D, frame_count: int, fps: float) -> SpriteFrames` (slices with `AtlasTexture`, 32×32 frames, loop on); animation names `idle`/`walk` (zombie) and `wave` (villager). fps within 8–12 (Dev Notes → Art direction picks the defaults).
  - [x] 4.2 Layout at 640×360, in this order, nothing overlapping: a palette strip (all 32 swatches, big enough to see, labelled by index only); each animation playing at 1× and at 3× (integer scale, nearest); a **type specimen** in the project font: `lI1O0` and a sample line at 16, 24 and 32 px (the font is part of the gate); a small footer with the current window scale (`get_window().size` / viewport 640×360) and background name.
  - [x] 4.3 `B` cycles the plain background through palette colors only (`night`, `parchment`, `art-sky`, `chalkboard`, `art-grass`); `Esc` quits. Handle keys in `_unhandled_input`. Text uses the shared theme (no new font, no new colors that are not in the palette).
  - [x] 4.4 It is run on its own (never reachable from the game): `"/c/Program Files/Godot/Godot.exe" --path . res://scenes/debug/art_review.tscn` (or Godot MCP `run_project` with that scene). Say so in the script's `##` header. Do **not** add a Router screen, a menu button, a Router/overlay hook or an autoload (Boundary 7; the autoload list is fixed at five).
- [x] **Task 5: Style sheet** (AC: 1, 2). `docs/art-style-sheet.md` (the folder is new: `docs/` holds nothing yet, and it is excluded from exports). Sections, in this order:
  - [x] 5.1 Purpose and the gate rule (what must be approved before other art is made, with the epics that depend on it).
  - [x] 5.2 **Palette:** a table of the 32 colors (index, name, hex, role in one phrase) copied from `DESIGN.md`; the "≤ 32, 24 UI + 8 art, a 33rd color means dropping one" rule; `palette_32.png` is the master (32×1, index = row order); the night-scrim alpha exception (UI only, never sprites).
  - [x] 5.3 **Sprites:** sizes (characters 32×32, brutes 48×48, tiles 16×16); the 1 px `ink` outline rule written exactly as the test enforces it; hard alpha only (0 or 255); transparent margin ≥ 1 px; animation limits (2–6 frames at 8–12 fps); file naming (`<subject>_<animation>.png`, horizontal strip, frame width = size); import settings (Lossless, no mipmaps, Nearest via the project default filter); fractional scaling and nearest filtering (`640×360`, viewport stretch, keep, fractional) and the one-line consequence (non-whole scales give slightly uneven pixels, accepted).
  - [x] 5.4 **Font:** Press Start 2P v3.000 (CodeMan38, from google/fonts), SIL OFL 1.1, license file `assets/fonts/press_start_2p_OFL.txt`, native grid 8 px, sizes 16 (UI/labels/stats), 24 (headings, paragraph lines), 32 (targets), 64 (countdown); import settings (no antialiasing, no hinting, no subpixel positioning); confusable glyphs `lI1O0` checked in Story 1.3; one line on why not Pixelify Sans (failed the O/0 check, 1.3).
  - [x] 5.5 **Kid-safe art rules** (from NFR10, DESIGN.md Do's and Don'ts): cute-Halloween; no gore, blood, exposed bones or brains, body-part gags, guns; defeat is melting, dust, stars; stamp red only on the stamp and toggle slash.
  - [x] 5.6 **Reuse rules** the sprites must keep working (GDD Reuse): party-hat zombie = villager recolor + hat; Horde Rush copies = player sprite scaled; mob = 2 base sprites recolored; hats anchor to a head point (Story 4.3).
  - [x] 5.7 `## Approval` heading pointing at this story file's `## Art Approval` as the record.
- [x] **Task 6: Verify** (AC: all)
  - [x] 6.1 `"/c/Program Files/Godot/Godot.exe" --headless --path . --import`, then GUT: all tests pass (190 at HEAD + new), exit 0, no `Parse Error` / `Failed to load script` / `SCRIPT ERROR`.
  - [x] 6.2 Boundary greps: `grep -rn "FileAccess\|DirAccess" scripts/` → still only `save_service.gd` (the tool in `tools/` is not under `scripts/`; tests may read files); `grep -rn "art_review\|scripts/debug" scripts/ scenes/` → only the debug folders and the Router's overlay path; no change to `project.godot`, `router.gd`, autoloads.
  - [x] 6.3 Run the review scene on desktop. Capture screenshots into `_bmad-output/implementation-artifacts/screenshots/` (naming: `1-9-art-review-<window size>-<background>.png`): at least the default 1280×720 window (2×) and a **non-whole scale** (resize the window to about 1366×768, 2.13×) on two backgrounds. Look at them yourself first: crisp edges, no smeared pixels, outline visible on every background, the 1× and 3× rows agree. Record what you saw in the Debug Log.
  - [x] 6.4 Confirm the sprites in a web build are not required for this story (the gate is about look; the web uses the same filter setting). If you export Web anyway, note it.
- [x] **Task 7: Hand to Smuck for the gate** (AC: 4)
  - [x] 7.1 Tell Smuck how to run the review scene (the command in 4.4), where the screenshots and `docs/art-style-sheet.md` are, and the three open questions in Dev Notes → Questions for Smuck at the gate.
  - [x] 7.2 Smuck fills in `## Art Approval` below: approved, or changes requested. On changes, revise the sprites/palette/font choice, re-run Tasks 3–6 as needed, and repeat 7.1. Tests that encode a rule Smuck changes (for example fps range, font) are updated with the style sheet in the same change.
  - [x] 7.3 Only after an **approved** record: set the story to `review` in `sprint-status.yaml`, and update `deferred-work.md` (strike or restate the 1.3 font note, add anything new). Until then the story stays `in-progress`.

## Art Approval

*(Smuck fills this in. Nothing downstream that produces final art starts before "Approved".)*

- Decision: ☑ Approved  ☐ Approved with notes  ☐ Changes requested
- Palette (32 colors): ☑
- Pixel font (Press Start 2P, or a replacement named here): ☑
- Player zombie (idle, walk): ☑
- Villager (wave): ☑
- Style sheet `docs/art-style-sheet.md`: ☑
- Notes / requested changes: Keep Press Start 2P. Keep the 8 fps idle (the 8–12 fps rule stands; no slower-idle exception). Recorded from Smuck's approval in chat.
- Date: 2026-10-03

## Dev Notes

### Scope boundaries (what this story is NOT)

- **Only** the palette file, the style sheet, three sprite sheets (zombie idle, zombie walk, villager wave), a standalone review scene and their tests. **No** hop/hug/dance/poof frames, no party-hat zombie, no Professor, no hats, pets, brain block, backdrops, tiles, hands, UI art, level cards, logo or signs. Those come after approval (3.x, 4.x, 5.0).
- **No scenes for the real characters** (`scenes/characters/player_zombie.tscn`, `HatSlot`, `SpriteAnchors`): Story 3.1/4.3 own them. This story only has to prove the look. Do not create `data/anchors/*.tres` now; the style sheet only notes that a hat anchors to a head point.
- **No change to the game's screens, Router, autoloads, `project.godot`, `export_presets.cfg` or CI.** The Keyboard Test screen and main menu stay as they are. The review scene is reached only by running it directly (Boundary 7: debug code lives in `scenes/debug/` and `scripts/debug/`).
- **No new font, no theme change, no `ui_theme.tres` edits.** The font gate here is "show it, record it, let Smuck confirm it". If Smuck wants another font, that is a change request that must keep `test_ui_theme.gd` passing (OFL license file, native size dividing 16/24/32/64, no antialiasing/hinting/subpixel) and is done inside this story.
- Placeholder art elsewhere stays plain shapes. Do not retrofit these sprites into other screens.

### Current state of the project (nothing to preserve, but know it)

- `assets/` holds only `audio/` and `fonts/` (Press Start 2P + OFL text + a README). There is **no** `assets/palette/`, `assets/sprites/` or `docs/` yet; create them. Architecture: `assets/` holds raw imported media only (no `.gd`, no `.tres`). Sprite paths: `assets/sprites/characters/zombie/`, `.../villager/`.
- `project.godot` already has the render settings the gate depends on: viewport 640×360, stretch `viewport`, aspect `keep`, scale mode `fractional`, `default_texture_filter = 0` (Nearest), `snap_2d_transforms_to_pixel = true`, theme `res://data/ui_theme.tres`. Do not touch them. Window override is 1280×720 (2×), so a non-whole scale needs a manual resize.
- `data/ui_theme.tres` has Press Start 2P as the default font at 16 px. `tests/unit/test_ui_theme.gd` guards it. The review scene gets its text from this theme and sets sizes with `theme_override_font_sizes` (8-multiples only).
- `tools/gen_placeholder_audio.gd` is the precedent for a headless generator: `extends SceneTree`, work in `_init()`, collect `Error`s, `quit(0|1)`. Follow it. `tools/*` is excluded from exports.
- `scenes/debug/` holds `debug_overlay.tscn` (Story 1.8) and `scripts/debug/` holds `debug_overlay.gd`, `frame_tracker.gd`. The overlay is instanced by the Router in debug builds; the art review scene is a different thing and is never instanced by anything.
- `.gdignore` for `_bmad-output/` already exists (1.5). The `screenshots/` folder there already exists for story evidence.
- `tests/unit/test_export_presets.gd` already requires `docs/*` and `tools/*` among the exclude filters; no preset change needed.

### Art direction (the design intent the pixels must serve)

Sources: GDD → Art Style; `DESIGN.md` (Overview, Colors, Do's and Don'ts); NFR10, NFR13.

- **Feeling:** a Halloween party thrown by a very polite zombie, on a 1992 family PC. Cute-Halloween, early-90s pixel art, hard pixels, no gradients, no soft glow, no anti-aliasing. Goofy, never babyish (a 13-year-old should find it charming), never scary (a 6-year-old).
- **The zombie (the player):** a big goofy friendly face (large eyes, a wide smile, maybe a missing-tooth gag), zombie-green skin using the three green tones for volume (`zombie-green` base, `zombie-green-bright` highlight, `zombie-green-dark` shade), simple clothes (a tattered shirt is fine; keep tatters as clean stepped edges, no wounds, no exposed bone or brain, no blood). Classic arms-forward lean is fine for walk, but keep it cuddly. A clearly readable **head top** (a flat-ish crown at least about 10 px wide) so a pumpkin hat, party hat and mortarboard can sit on it later; Story 4.3 sets the exact anchor, the design just must leave room.
- **The villager:** a friendly human (art-skin-light with art-skin-dark shading, simple clothes and hair from the UI colors, e.g. wood/pumpkin/stone), a 2-frame wave. They are the one who becomes a party-hat zombie by **recolor** (GDD Reuse), so draw them with few, clearly separated color regions and write the ASCII legends so the skin and clothing can be swapped by changing legend entries (skin → the three greens, clothes unchanged) with the result still palette-only. Do not use colors in the villager that would have no sensible recolor.
- **Outline:** 1 px `ink` (`#1E1428`) around the whole silhouette, not pure black. Interior lines are optional and also `ink` or a darker tone from the sprite's own ramp.
- **Reserved colors:** the eight `art-*` colors exist for exactly this: `art-skin-light`, `art-skin-dark` (villager skin), `art-brain-pink`, `art-brain-shade` (brain props, later), `art-sky`, `art-sky-light`, `art-grass`, `art-moon` (backdrops, later). `stamp-red` is **not** a sprite color (stamp and toggle slash only). Use `chalk` for eye whites and teeth. No color that is not one of the 32.
- **Animation:** idle 2 frames and wave 2 frames at 8 fps (a lively 4 Hz bob; that is the rule's floor), walk 4 frames at 10 fps (a 2.5 Hz stride that suits the 24 px/s amble). All within 8–12 fps. Per-frame duration multipliers in `SpriteFrames` are **not** used to slow things below 8 fps (it would hide a rule break); if Smuck finds the idle too busy, the right fix is a rule change, decided at the gate (open question 2).
- **Scale in context:** at the default 2× window a 32 px sprite is 64 px tall on a 1280×720 screen; the playfield is 256 px of the 360 px height, so characters are about an eighth of the playfield height. Judge them at that size, not zoomed in. The 3× row in the review scene is for detail only.

### Sprite rules (testable, stated once; the style sheet repeats them exactly)

1. Sheet = one horizontal strip, `frames × 32` wide, 32 high. Brutes (48×48) and tiles (16×16) are in the style sheet only; no such sprite exists yet.
2. **Hard alpha:** every pixel has alpha 0 or 255. No semi-transparent pixels (nothing blends in this game except the UI scrim).
3. **Palette only:** every opaque pixel's RGB is one of the 32 palette colors. (Comparing 8-bit RGB exactly; the files are generated from the same hex values.)
4. **Outline rule:** an opaque pixel that is **not** `ink` must have all four orthogonal neighbours (up, down, left, right) opaque, **within the same frame**. A neighbour outside the frame counts as transparent. So the silhouette edge is always an `ink` pixel, and a sprite never touches the frame edge (at least a 1 px transparent margin on every side). Diagonal gaps are fine (stepped corners).
5. **Not empty, not static:** every frame has opaque pixels; in a multi-frame sheet no two frames are identical.
6. Each sprite's frames are the same size and share a ground line (feet on the same row across frames, except for deliberate hops later) so a swap never makes the sprite jump. The test checks the lowest opaque row is the same in every frame of a sheet (idle, walk, wave); a bobbing idle moves the body, not the soles.
7. Import: Lossless compression, no mipmaps; filtering comes from the project's Nearest default (do not set a per-file filter).

### Design decisions already made (don't reopen)

1. **Pixels are authored in code** (the GDD says "code-authored pixel art"): ASCII maps with a name legend in `tools/gen_art_prototypes.gd`, written to PNG. The maps are reviewable in a diff, and a recolor is a legend change. The generated PNGs are committed (the game and tests read PNGs, not the tool).
2. **The palette is the 32 colors in `DESIGN.md`**, approved by Smuck on 2026-09-27 (UX D13). This story does not renegotiate it, it records it and checks the first art against it. Smuck can still request a change at the gate; then `DESIGN.md`, the tool, the test list and the style sheet change together.
3. **Review scene is standalone** (run directly), not a Router screen, overlay panel or menu button: no change to navigation or autoloads, and nothing a kid can reach.
4. **Font stays Press Start 2P unless Smuck changes it at the gate** (Story 1.3 chose it because the rounder Pixelify Sans failed the O/0 check; `DESIGN.md` still asks for "slightly rounded", so it is an explicit question).

### Architecture compliance

- **Boundary 7:** debug/dev code only in `scenes/debug/`, `scripts/debug/`; the review scene is not instanced by the Router and is not an autoload. Tools in `tools/`, not exported.
- **Naming (architecture → Naming):** sprite sheets `<subject>_<animation>.png` (`zombie_walk.png`, `villager_wave.png`); animation names lowercase verbs (`idle`, `walk`, `wave`); snake_case files; scene/script paths mirror each other (`scenes/debug/art_review.tscn` ↔ `scripts/debug/art_review.gd`).
- **Asset rules:** `assets/` has media only; art imports as 2D pixel textures, Nearest, no mipmaps; sprite sheets become `SpriteFrames` (built in the review script now; a real `.tres` per character arrives with the character scenes).
- **Typing/strictness:** static typing everywhere (`untyped_declaration = Error`), including the tool and tests; `Log` for logging in game code (the tool uses `print`/`push_error` like `gen_placeholder_audio.gd`); no hot-path logging.
- **Constants:** frame size (32), fps values, background names/colors are named constants in the script; no GDD balance numbers involved.
- **Kid-facing text:** the review scene is a dev/Smuck screen and never ships to kids; English dev labels are fine. It still ships in release exports (`all_resources`) but is unreachable.

### Library / framework requirements

- Godot 4.7.2 standard, GDScript only. Image creation with `Image.create_empty()`, `set_pixel`, `save_png`; reading with `Image.load_from_file()`. `SpriteFrames` (`add_animation`, `set_animation_speed`, `set_animation_loop`, `add_frame`), `AtlasTexture` (`atlas`, `region`), `AnimatedSprite2D`, `TextureRect`/`ColorRect`/`Label` for the layout. GUT 9.7.1. No new libraries or add-ons; no external art tools.

### File structure requirements

New:
```
tools/gen_art_prototypes.gd (+ .uid)
assets/palette/palette_32.png (+ .import)
assets/sprites/characters/zombie/zombie_idle.png (+ .import)
assets/sprites/characters/zombie/zombie_walk.png (+ .import)
assets/sprites/characters/villager/villager_wave.png (+ .import)
scenes/debug/art_review.tscn
scripts/debug/art_review.gd (+ .uid)
docs/art-style-sheet.md
tests/unit/test_art_palette.gd (+ .uid)
tests/unit/test_art_sprites.gd (+ .uid)
tests/unit/test_art_review.gd (+ .uid)
tests/unit/test_art_style_sheet.gd (+ .uid)
_bmad-output/implementation-artifacts/screenshots/1-9-art-review-*.png
```
Modified: this story file, `sprint-status.yaml`, `deferred-work.md`. New `.uid` and `.import` files are created by `--import`; commit them.

### Testing requirements

GUT 9.7.1 facts (carried from 1.1–1.8):
- An unexpected `push_error` **fails** a test; assert expected ones with `assert_push_error`. Use `wait_process_frames`, never `wait_frames`. Run `--import` after adding files, then grep the GUT output for `Parse Error|Failed to load script|SCRIPT ERROR`.
- Commands: `"/c/Program Files/Godot/Godot.exe" --headless --path . --import`, then `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`.
- Read PNGs with `Image.load_from_file(ProjectSettings.globalize_path(path))` so the tests check the committed bytes and do not depend on import state. Colors compared as `Color.to_html(false)` strings (8-bit exact), never as floats.
- Tests may read the repository files under `res://` (they never ship); no write to `user://` or the live save is needed. Never route through the live autoloads.

`tests/unit/test_art_palette.gd` (own const `EXPECTED_HEX: Array[String]` with the 32 hex values from `DESIGN.md`, lowercase, no `#`):
- file exists; width 32, height 1.
- every pixel opaque; unique colors ≤ 32 (and the set equals `EXPECTED_HEX`, order too: index i is color i).
- `EXPECTED_HEX` has 32 distinct entries (guards a typo in the test itself).

`tests/unit/test_art_sprites.gd` (a const table of sheets: path → frame count: `zombie_idle` 2, `zombie_walk` 4, `villager_wave` 2; palette loaded from `palette_32.png`):
- each sheet exists, is `frames × 32` by `32`, and has 2–6 frames.
- hard alpha; every opaque color is in the palette.
- the outline rule (Dev Notes rule 4), reported with the frame and pixel coordinates in the failure message (`"zombie_walk frame 2 (7,14) rgb 6cc24a open edge"`).
- not empty per frame; no two frames identical within a sheet; same lowest opaque row in every frame of a sheet.
- the `.import` file next to each sheet (and the palette) loads with `ConfigFile`: `params/compress/mode == 0` and `params/mipmaps/generate == false`.
- the zombie sheets contain at least `zombie-green`, `zombie-green-dark` and `ink`; the villager sheet contains `art-skin-light` and `ink` (a cheap check that the right ramps are used).

`tests/unit/test_art_review.gd`:
- `ArtReview.build_frames()` on the real `zombie_walk.png` returns a `SpriteFrames` with one animation, 4 frames, a 32×32 region each, the requested fps, looping.
- the scene instantiates (disabled instance, `add_child_autofree`), builds `idle`/`walk`/`wave` animations whose fps are within 8–12 and frame counts within 2–6, and `B` cycling (call the `_cycle_background()` seam, not a synthetic input event) visits only palette colors and wraps around.
- every background color used equals a palette color (compare with `palette_32.png`).

`tests/unit/test_art_style_sheet.gd`:
- `docs/art-style-sheet.md` exists and contains: all 32 hex values (case-insensitive), `Press Start 2P`, `SIL Open Font License`, `32×32`, `48×48`, `16×16`, `8–12 fps` (or the exact phrase the sheet uses; match the sheet), `2–6 frames`, and an `Approval` heading.

### Previous story intelligence (1.1–1.8)

- **1.8 (just done):** the repo's dev loop and boundary greps are the model for Task 6; desktop runs use the Godot MCP (`run_project`, `get_debug_output`, `stop_project`) plus a scratch PowerShell helper for window driving and `CopyFromScreen` screenshots (SetForegroundWindow, `keybd_event`, `SetCursorPos`/`mouse_event`, `Process.CloseMainWindow()`). See the 1.6, 1.7 and 1.8 Debug Log References; don't reinvent them. `stop_project` kills the process.
- **1.8 test patterns:** fresh instances with seams set before `add_child_autofree`; private handlers and `_cycle_*` seams called directly instead of synthetic input; instances in tests are `process_mode = DISABLED` when they own input.
- **1.8 deferral to remember:** the debug overlay (8 px text, top-left, starts hidden) is added by the Router in every debug run. Running the review scene directly still loads the autoloads, so F3 will toggle the overlay over it. That is fine: don't bind F3/F5/F8/F9 in the review scene, and take the screenshots with the overlay closed.
- **1.3:** the font. Press Start 2P: wide, arcade; chosen after Pixelify Sans failed the `O`/`0` check. Native 8 px grid: sizes 16/24/32/64. Import settings are pixel-crisp (antialiasing none, hinting none, subpixel disabled). `test_ui_theme.gd` guards all of it.
- **1.2 / 1.5 / 1.7:** Firefox still not installed; browser checks stay Chrome/Edge. This story needs no browser check.
- **Easy mistakes seen before:** a `\d` in a shell heredoc loses its backslash (use raw strings `r"..."` in GDScript tests); GUT's deprecated `wait_frames`; forgetting to run `--import` after adding test or asset files (Godot then cannot find `.uid`/`.import`).

### Git intelligence

- Recent commits: `c21a580` Story 1.8 (debug overlay, save export, 190 tests), `3798a0c` 1.7, `87913aa` 1.6, `803a575` 1.5, `580aba1` 1.4. Tree clean at story creation. Style: `Story 1.N: <summary>` plus a short body and the `Co-Authored-By` trailer. Commit only when Smuck asks.
- Story 1.4 (`580aba1`) added generated assets via a tool plus `--import` (`tools/gen_placeholder_audio.gd` → `.wav` + `.wav.import`); this story repeats that shape for PNGs.

### Latest tech information (checked 2026-10-03)

- Godot 4.7.2-stable, Compatibility renderer, single-threaded web export. 2D textures import as Lossless PNG by default with mipmaps off; `AtlasTexture` regions sample exactly (no filtering bleed) with Nearest filtering. With `snap_2d_transforms_to_pixel = true` and Nearest, an `AnimatedSprite2D` at integer positions stays crisp; at fractional window scales the whole viewport is resampled, which is the accepted "slightly uneven pixels" trade-off recorded in the architecture.
- `Image.load_from_file()` reads a PNG from an absolute path without the import pipeline (usable in tests and the tool). `Image.save_png()` writes 8-bit RGBA losslessly. No new APIs beyond what the project already uses.
- Press Start 2P Version 3.000 (OFL 1.1) is already in the repo; nothing to download. No new licenses are added by this story (the sprites are project-authored).

### Questions for Smuck at the gate

1. **Font:** Press Start 2P is wide and arcade-like; `DESIGN.md` asked for a "chunky, friendly, slightly rounded" face. Keep it, or ask for a replacement? (A replacement must be OFL, keep `lI1O0` distinct and have an 8-multiple-friendly native size.)
2. **Idle speed:** the 8–12 fps rule makes a 2-frame idle bob 4 times a second. Fine, or should the rule allow slower idles (say 4–6 fps for 2-frame idles)? If yes, the style sheet and `test_art_review.gd` change.
3. **Zombie look:** the review scene is the only place to judge it. Anything that reads scary, or too babyish, is a change request. Also: are the eight reserved `art-*` colors enough for the villager (skin, hair, clothes)?

### Risks noted, not solved here

- **Horde Rush brutes** are specified as 48×48, but "Horde Rush copies are the player sprite plus scaling for size classes": a 1.5× nearest-neighbour scale of a 32 px sprite produces uneven pixels. Epic 6 (Story 6.3) must choose between redrawn 48×48 brutes and an integer scale. This story only records the 48×48 size in the style sheet.
- **Fractional scaling** (non-whole window sizes) makes some pixels wider than others; accepted in the architecture. The gate screenshots at about 2.13× exist so Smuck sees the worst realistic case (1366×768 laptop).

### Project Structure Notes

- Matches the architecture tree: `assets/palette/palette_32.png`, `assets/sprites/characters/{zombie,villager}/`, `docs/` for project knowledge, `tools/` for the offline generator. **Variances (small, additive):** `scenes/debug/art_review.tscn` and `scripts/debug/art_review.gd` are not in the architecture tree (they are the review tool the gate needs; Boundary 7 puts them in the debug folders); the sprite sheets are built into `SpriteFrames` in code for now.
- No `project-context.md` exists.

### Project Context Rules

- There is no `project-context.md`. Rules come from the architecture (Asset Management, Naming, Boundaries, Consistency Rules), the UX spines (`DESIGN.md` palette, typography, Do's and Don'ts) and Stories 1.1–1.8: strict static typing, `Log` for game logging, tests first, GUT parse-error grep, standard Godot build only, no change to autoloads or navigation.
- Tools: Godot binary at `/c/Program Files/Godot/Godot.exe` for `--import`, the generator, the review scene and GUT; Godot MCP (`run_project`, `get_debug_output`, `stop_project`) for desktop runs; Smuck's own eyes for the gate.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.9: Art-Style Sheet and Prototype Sprites (Review Gate)]
- [Source: _bmad-output/planning-artifacts/epics.md#Requirements Inventory] (NFR7, NFR10, NFR13; "Additional Requirements" asset/standards bullets)
- [Source: _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md#Art Style] (sizes, outline, animation limits, reuse, risk gate)
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/DESIGN.md#Colors] (the 32 hex values, contrast table), [#Typography], [#Do's and Don'ts]
- [Source: _bmad-output/game-architecture.md#Asset Management, #Cosmetics, #Directory Structure, #Naming Conventions, #Architectural Boundaries]
- [Source: _bmad-output/implementation-artifacts/1-3-screen-router-and-title-screen.md] (font choice, theme test) and `assets/fonts/README.md`
- [Source: _bmad-output/implementation-artifacts/1-8-debug-overlay-and-save-export.md] (test patterns, desktop run and screenshot method, overlay behaviour in debug runs)
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] (1.3 font note; 1.2 letterbox note belongs to Story 5.0, not here)
- [Source: tools/gen_placeholder_audio.gd] (generator pattern)

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Debug Log References

- Red: GUT with the four new test files and no assets → `Preload file ... art_review.tscn does not exist` parse errors (test_art_review) plus 13 failing tests (palette, sprites, style sheet); 191 passing (190 + the `EXPECTED_HEX` self-check).
- Pixel maps were drafted in a scratch Python previewer (same compose + outline check as the tests, rendered at 8× on night/parchment/art-grass), then ported verbatim into the tool. Two look fixes after the first preview: the zombie's diagonal pupils read as angry → square 2×2 pupils (looking right); the villager's double ink row at the shoulders read as a black scarf → shirt shoulders.
- Green: tool exit 0 (4 PNGs written), `--import` wrote the 4 `.png.import` files with the defaults `compress/mode=0`, `mipmaps/generate=false` (no edits needed). GUT 209/209 (190 at HEAD + 19 new), exit 0, no `Parse Error` / `Failed to load script` / `SCRIPT ERROR`. The ERROR lines in the log are the existing tests' expected ones.
- 6.2 boundary greps: `FileAccess`/`DirAccess` under `scripts/` only in `save_service.gd` (the review script reads the palette with `Image.load_from_file`); `art_review` / `scripts/debug` referenced nowhere outside `scenes/debug/` and `scripts/debug/`. No change to `project.godot`, `router.gd`, autoloads, export presets or CI.
- 6.3 desktop: the scene was run directly (`Godot.exe --path . res://scenes/debug/art_review.tscn`) with a scratch PowerShell helper (MoveWindow to set the client size, focus click + `keybd_event` B, `CopyFromScreen` of the client area). First pass had two problems, both fixed and re-shot: the 16 px animation labels overlapped each other ("fpswalk") → 8 px labels; the first B press after launch was lost (window not focused) so file names didn't match → a focus click before keys. Final shots: `1-9-art-review-1280x720-night.png`, `-1280x720-parchment.png`, `-1366x768-art-grass.png`, `-1366x768-night.png`; each footer shows the matching window, scale (2.00× / 2.13×) and background.
- What I saw: edges crisp at 2.00×; at 2.13× a few pixel columns/rows are one screen pixel wider (the accepted fractional-scale trade-off), no smearing. The 1× and 3× rows agree. The ink outline stands out on parchment, art-sky and art-grass; on night/chalkboard the outline is close to the background (ink vs night) and the silhouette reads by its fills instead, as designed (ink is a purple-black, the backdrop is night). 1 px letterbox slivers at 1366×768 (aspect keep). The night/26 swatch disappears on its own background (expected; labels keep the index). The F3 overlay was not opened.
- 6.4 no web export made; not needed for the gate (same filter setting on web).

### Completion Notes List

- `tools/gen_art_prototypes.gd` (`extends SceneTree`, like `gen_placeholder_audio.gd`): `PALETTE` (name → hex, DESIGN.md order) → `palette_32.png` 32×1; sprites from ASCII maps (`.` = transparent) with a legend char → palette **name**. A frame is a list of parts `[map, first row]` painted in order (legs, then body), so the bob/stride frames reuse one upper-body map. Bad width, unknown char or a part that doesn't fit → `push_error` + exit 1; any save failure → exit 1.
- Zombie: three greens (bright crown highlight, dark left/bottom shade), chalk eye whites and teeth with one missing tooth, bat-purple shirt (dusk shade, stepped tattered hem), wood trousers (b near / B far leg), green bare feet, one arm forward with dangling fingers. Flat ink crown 12 px wide for hats. Idle = body bobs 1 px, soles fixed; walk = contact/passing/contact/passing with near/far leg shading swapped, body down on contacts.
- Villager: skin only `s`/`S` (art-skin-light/dark), wood-dark hair, pumpkin shirt, stone trousers, wood-dark shoes; the right arm waves (straight, then tilted). Recolor to a party-hat zombie = `s → zombie-green`, `S → zombie-green-dark` in the legend (noted in the tool).
- Every sheet: ground row 30, 1 px transparent margin, outline rule satisfied (checked by the previewer and by GUT).
- `ArtReview` (`class_name`, `scripts/debug/art_review.gd`): `static build_frames(sheet, frame_count, fps, anim_name = &"default")`. The optional 4th argument renames the default animation so the scene can use `idle`/`walk`/`wave`; with three arguments it matches the story's signature. Seams for tests: `get_animations()`, `swatch_colors()`, `background_name()`, `background_color()`, `_cycle_background()`. Text color follows the background (chalk on night/chalkboard, ink on light ones), palette only. Footer refreshes on `size_changed`.
- `docs/art-style-sheet.md`: sections 1–6 + `## Approval` as specified; the outline rule is the test's wording.
- Tests: `test_art_palette` (3), `test_art_sprites` (7, failure messages name sheet/frame/pixel/rgb), `test_art_review` (5, also asserts frame duration 1.0 so no multiplier hides a sub-8 fps animation), `test_art_style_sheet` (4).
- **Gate passed (Task 7):** Smuck approved on 2026-10-03 in chat: keep Press Start 2P, keep the 8 fps idle. Recorded in `## Art Approval`; no rule or test changed. `deferred-work.md`: 1.3 font note struck as settled; new 1.9 section (outline on dark backgrounds, brute scaling, `fix_alpha_border`, review scene in release exports).

### File List

New:
- tools/gen_art_prototypes.gd (+ .uid)
- assets/palette/palette_32.png (+ .import)
- assets/sprites/characters/zombie/zombie_idle.png (+ .import)
- assets/sprites/characters/zombie/zombie_walk.png (+ .import)
- assets/sprites/characters/villager/villager_wave.png (+ .import)
- scenes/debug/art_review.tscn
- scripts/debug/art_review.gd (+ .uid)
- docs/art-style-sheet.md
- tests/unit/test_art_palette.gd (+ .uid)
- tests/unit/test_art_sprites.gd (+ .uid)
- tests/unit/test_art_review.gd (+ .uid)
- tests/unit/test_art_style_sheet.gd (+ .uid)
- _bmad-output/implementation-artifacts/screenshots/1-9-art-review-1280x720-night.png
- _bmad-output/implementation-artifacts/screenshots/1-9-art-review-1280x720-parchment.png
- _bmad-output/implementation-artifacts/screenshots/1-9-art-review-1366x768-art-grass.png
- _bmad-output/implementation-artifacts/screenshots/1-9-art-review-1366x768-night.png

Modified:
- _bmad-output/implementation-artifacts/1-9-art-style-sheet-and-prototype-sprites-review-gate.md
- _bmad-output/implementation-artifacts/sprint-status.yaml
- _bmad-output/implementation-artifacts/deferred-work.md

### Change Log

- 2026-10-03: Story 1.9 created (ready-for-dev).
- 2026-10-03: Tasks 1–6 done: palette file, prototype zombie (idle, walk) and villager (wave) sprites, art review scene, style sheet, 19 new GUT tests (209/209), gate screenshots. Handed to Smuck for the art approval (Task 7); status stays in-progress.
- 2026-10-03: Art gate approved by Smuck (Press Start 2P and 8 fps idle kept). Task 7 done, deferred-work updated, status → review.

### Review Findings

Code review 2026-10-03 (Blind Hunter, Edge Case Hunter, Acceptance Auditor). GUT re-run by the reviewer: 209/209 passing.

- [x] [Review][Decision] RESOLVED 2026-10-03: Smuck confirmed the approval is genuine and the art needs no changes (Q3 answered: fine as is). Art approval was recorded by the dev agent, not by Smuck — `## Art Approval` says "Recorded from Smuck's approval in chat" with every box ticked, while AC 4 says Smuck records it. Open Question 3 (zombie look "too babyish or scary?", are the 8 `art-*` colors enough for the villager?) is also unanswered in the notes. Confirm the approval is genuine and answer Q3, or untick and let Smuck fill it in.
- [x] [Review][Patch] `art_review.gd` crashes when the palette PNG is not on disk (exports ship only the imported `.ctex`): `Image.load_from_file(globalize_path(...))` returns null, then `image.get_width()` aborts `_ready` [scripts/debug/art_review.gd:373]. Load via `load(PALETTE_PATH) as Texture2D` + `get_image()`, or guard null.
- [x] [Review][Patch] No null guard on `load(spec["path"]) as Texture2D`; a missing import gives blank sprites silently, and `test_scene_builds_animations_within_limits` would still pass [scripts/debug/art_review.gd:390]. Guard it and assert non-null textures in the test.
- [x] [Review][Patch] Style sheet marks the animation limits and the "transparent margin ≥ 1 px" rule as "(*tested*)", but the frame check runs against the test's own SHEETS table, the fps check against the review scene's constants, and the margin is only implied by the outline rule. Reword the sheet to say what is actually enforced [docs/art-style-sheet.md §3].
- [x] [Review][Patch] `assert_lte(unique.size(), 32)` can never fail (all 32 pixels are already pinned one by one) [tests/unit/test_art_palette.gd:~48]. Remove or replace with a distinctness check.
- [x] [Review][Defer] Esc calls `get_tree().quit()`, which does nothing useful in a web build [scripts/debug/art_review.gd:338] — deferred, scene is unrouted and dev-only.
- [x] [Review][Defer] Style-sheet test only checks that each hex string appears somewhere in the doc, so a wrong name or index in a palette row still passes [tests/unit/test_art_style_sheet.gd:~30] — deferred, `palette_32.png` is the master data.
- [x] [Review][Defer] The 32 hex values are copied into the generator and two tests, and no test reads DESIGN.md [tests/unit/test_art_palette.gd] — deferred, acts as an independent oracle; revisit if DESIGN.md palette changes.
- [x] [Review][Defer] `fix_alpha_border` and Nearest filtering are not asserted in the `.import` checks [tests/unit/test_art_sprites.gd] — deferred, already recorded in deferred-work (dev of story-1-9).

Dismissed as noise: 26 (including two Blind Hunter "high" outline-rule claims that the passing test run disproves).
