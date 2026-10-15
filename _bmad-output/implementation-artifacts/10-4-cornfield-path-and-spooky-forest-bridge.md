---
baseline_commit: e5ec1d6c0fd7b19f96b1fe85e4c3324fd129cc82
---

# Story 10.4: Cornfield Path and Spooky Forest Bridge

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a kid,
I want new chase settings in Pitchfork Panic,
so that each escape feels like a new adventure.

## Acceptance Criteria

1. **Two new Pitchfork Panic themes ship (FR74, FR76).** `data/levels/level_registry.tres` gives `pitchfork_panic` three themes, in this order: `moonlit_village` (unchanged, stays first: it is the level scene's built-in look), `cornfield_path`, `spooky_forest_bridge`. Each new theme is a `LevelTheme` with only `id` and `backdrop` set (`defender` null, `music_id` empty, so every setting keeps `mus_pitchfork_panic`). The ids are permanent once shipped (they go into players' saves). Zombie Run and Horde Rush themes are untouched. With three themes, 10.1's `ThemePicker` picks one per run, never the previous one; no picker, RunFrame or save change is needed.
2. **Each setting is a full parallax backdrop.** `scenes/levels/pitchfork_panic/themes/cornfield_path.tscn` and `spooky_forest_bridge.tscn` have the `moonlit_village.tscn` node layout: root `Backdrop` (Node2D, the new `ChaseBackdrop` script, AC 6), `Sky` (ColorRect 640×192, palette colour, `mouse_filter = 2`), `Clouds/A,B`, `Far/A,B`, `Near/A,B`, `Ground/A,B` (Ground at y 192, copy B at x 640, `centered = false`), plus optional static children outside the four layers (a `Sun` or `Moon` Sprite2D, like Moonlit's `Moon`). Textures in `assets/sprites/backdrops/cornfield_path/` and `assets/sprites/backdrops/spooky_forest_bridge/`: `clouds.png`, `far.png`, `near.png` (640×192 each), `ground_tiles.png` (4 tiles × 16×16 = 64×16) and `ground_strip.png` (640×64, built from the tiles, row 0 = the walking path). All 640 px layers and the strip wrap with no seam for a full 5:00 run.
3. **Each setting has its own place for the Escaped! dive (FR73, FR74).** A new 48×48, 3-frame cover sheet per setting with the escape bush's exact contract (frame 0 still, frames 1-2 rustled with bits popping off; stands on row 46; origin bottom-centre, sprite at (−24, −47); tween-stepped): `assets/sprites/props/escape_haystack.png` (Cornfield Path) and `assets/sprites/props/escape_hollow_log.png` (Spooky Forest Bridge) — Gate 1 may swap either for a hedge or gate, keeping the contract. The Moonlit Village keeps `escape_bush.png` (byte-identical). The escape outro's timings, positions, hop, vanish and label are unchanged; only the picture differs.
4. **The cover travels with the backdrop scene; one shared node renamed.** New `class_name ChaseBackdrop extends ParallaxBackdrop` (`scripts/levels/pitchfork_panic/chase_backdrop.gd`) adds one export, `escape_cover_sheet: Texture2D`, and no behaviour (no `_ready` override). `moonlit_village.tscn` switches to it with `escape_cover_sheet = escape_bush.png`; the two new scenes point at their own covers. `EscapeBush` becomes `EscapeCover` (`scripts/levels/pitchfork_panic/escape_cover.gd`, `git mv` with its `.uid`; node `%EscapeBush` → `%EscapeCover` in `pitchfork_panic_level.tscn`) and gains `use_sheet(sheet: Texture2D) -> bool` and `get_sheet() -> Texture2D`; its built-in default stays `escape_bush.png`. `PitchforkPanicLevel._ready` hands the backdrop's sheet to `%EscapeCover`: a `ChaseBackdrop` with a null sheet warns once (NFR16) and keeps the built-in bush; a plain `ParallaxBackdrop` (10.1's `test_backdrop.tscn` fixture) keeps it silently; a sheet of the wrong size warns once and keeps the bush. `ParallaxBackdrop` and `LevelTheme` get **no** new property (`LevelTheme`'s property-list test passes unchanged).
5. **The mob is reused, unchanged (FR70, FR74).** No new mob, mob recolour, dust cloud, dizzy stars or dazed art; `chase_mob.tscn`, `chase_mob.gd` and every `characters/mob/` PNG untouched. The mob, the pickups and the zombie must stay readable on both settings (AC 7, checklist).
6. **Rules never change with the setting (FR76).** No change to `data/levels/pitchfork_panic.tres`, `ChaseModel`, `PickupTrail`, `BrainPickup`, `ParagraphSource`, the camera (`zombie_screen_x_frac`), `GROUND_Y`, `ESCAPE_*` layout values (renamed only), RunFrame, the HUD or the save. *Tested:* one RunFrame start per theme (payload `"theme"` forced, same seed, the same scripted correct keys and fixed `_process` steps) gives the identical passage text, `LevelConfig`, `zombie_steps`, `mob_steps`, brains from pickups and end reason; zero warnings and errors; `%Backdrop` is that theme's scene and `%EscapeCover.get_sheet()` is that theme's cover.
7. **Text and mob distance stay readable (FR74, NFR8, NFR13).** *Tested* for both new settings (the **chase readability band**, Dev Notes): `near.png` rows 160-191 fully opaque and free of `ink`, `night`, `zombie-green`, `zombie-green-bright`, `bat-purple`, `art-brain-pink`, `art-brain-shade`; the ground strip's top 4 rows free of the same plus `wood` and `wood-dark` (the zombie's trousers and shoes); no file uses `candy-yellow` (the "Escaped!"/"Got you!" label colour and focus), `stamp-red` or `art-moon` (except a `Moon` that reuses Moonlit's `moon.png`). The **chase setting readability checklist** passes at 1× per setting, recorded pass/fail: the paragraph band, the end labels, the mob at gap 20 and gap 5, the pickups and the zombie all read.
8. **Goofy, not scary (NFR10, NFR13).** Code-authored by a new tool (never a hand-edited PNG; fixed positions, no RNG: a rerun writes the same bytes); palette only, hard alpha; Lossless, no mipmaps; covers have the ink outline, backdrops are outline-exempt. Cute-Halloween dressing on each (a pumpkin and `bat-purple`, *tested*); nothing scary: no skulls, bones, gore, glowing or slit eyes, grabbing branches, cobwebs with spiders the size of a head, horror lighting; a scarecrow or owl smiles; the forest is "spooky" the way a kids' cartoon is. No letters, numbers or text-like marks anywhere (signposts blank or a picture).
9. **A setting is easy to see on demand (debug only).** `THEME_JUMP_LEVELS` gains `pitchfork_panic`, so the F3 overlay shows one jump button per Pitchfork Panic theme (payload `{"level_id": &"pitchfork_panic", "theme": <id>}`) with the existing builder; never visible in a release build. The debug art review lists both new cover sheets.
10. **Approval gates.** Gate 1 (both settings' layers composed at 1× and 3× plus grayscale, and both cover sheets, before wiring) and Gate 2 (in game on the real RunFrame, including both outros) are approved by Smuck; each answer verbatim with the date in `## Art Approval`. The checklists are filled in pass/fail per setting. No new sound: no Audio gate (if Smuck asks for a per-setting escape sound, stop and raise it; it is out of scope).
11. **No regressions.** Full GUT suite green; the count only goes up; zero `Parse Error|Compile Error|Failed to load script`; `SCRIPT ERROR` / `WARNING` counts unchanged except deliberate, asserted ones. All existing PNGs and WAVs byte-identical (`git status` shows no modified `.png` or `.wav`). The real `user://save.json` is untouched by the test run, the tool runs and the captures (sha256 before/after).

## Tasks / Subtasks

- [x] **Task 1: Baseline** (AC: 11)
  - [x] 1.1 `git status` clean. `"/c/Program Files/Godot/Godot.exe" --headless --path . --import`, then `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`. Record the count (10.3 ended at 2144 before its review patches; the recount is authoritative), `SCRIPT ERROR` (3) and `WARNING` (172 at 10.3) line counts; grep the log for `Parse Error|Compile Error|Failed to load script`.
  - [x] 1.2 sha256 of the real save (`%APPDATA%/Godot/app_userdata/<project>/save.json`).

- [x] **Task 2: Rename `EscapeBush` → `EscapeCover`, no behaviour change** (AC: 4) — do first, run the suite before any art
  - [x] 2.1 `git mv scripts/levels/pitchfork_panic/escape_bush.gd scripts/levels/pitchfork_panic/escape_cover.gd` (+ `.gd.uid`); `class_name EscapeCover`. Doc: the cover the zombie dives into when it escapes (a bush, a haystack, a hollow log...), one per setting (Story 10.4); keep the sheet contract text. Keep every constant and line of behaviour; `SHEET_PATH` → `DEFAULT_SHEET_PATH` (still `escape_bush.png`). Warning owner text `"escape bush"` → `"escape cover"` (update any test asserting it).
  - [x] 2.2 `pitchfork_panic_level.tscn`: the script path and the node name `EscapeBush` → `EscapeCover` (still `unique_name_in_owner`, same place under `%World`, still `visible = false`). Keep ext id `11_bush` or rename it; keep `load_steps` right.
  - [x] 2.3 `pitchfork_panic_level.gd`: `_bush: EscapeBush = %EscapeBush` → `_cover: EscapeCover = %EscapeCover`; `ESCAPE_BUSH_AHEAD_PX` → `ESCAPE_COVER_AHEAD_PX` (same 48.0); `_vanish_into_bush` → `_vanish_into_cover`; the outro-node null check; the class doc ("hops into a bush" → "into the setting's cover"). `sheet_frames.gd` doc. Tests: `test_pitchfork_panic_level.gd` (`%EscapeBush`, `EscapeBush.new()`, `test_escape_bush_rustles_...` → keep or rename), `test_level_themes.gd` l.136. `docs/art-style-sheet.md` mentions. Grep the repo (excluding `_bmad-output/` and `.godot/`) for `EscapeBush|escape_bush\.gd|ESCAPE_BUSH_AHEAD|_vanish_into_bush|_bush\b` → zero hits (the PNG name `escape_bush.png`, the art-review entry `escape_bush` and `ESCAPE_BUSH_PATH` in `test_art_sprites.gd` stay: they name the Moonlit picture).
  - [x] 2.4 `--import` (class cache), full suite: same count, all green. If anything fails, the rename is wrong, not the test.

- [x] **Task 3: The cover travels with the backdrop** (AC: 4)
  - [x] 3.1 `sheet_frames.gd`: add `static func from_texture(sheet: Texture2D, frame_count, frame_px, fps, anim, loop, owner_name) -> SpriteFrames` (the size check + atlas frames); `build()` loads then delegates. Behaviour and warnings of `build()` unchanged (`DustCloud`, `DizzyStars` keep calling `build`).
  - [x] 3.2 `escape_cover.gd`: `use_sheet(sheet: Texture2D) -> bool`: null → false, nothing changes; otherwise build frames with `from_texture`; on success replace the sprite's frames, set `ANIM`, frame 0, remember the sheet, return true; on failure (wrong size: `from_texture` warns once) keep the current frames, return false. Kills a running rustle tween first. `get_sheet()` returns the sheet in use (the default bush texture after `_ready`, null if even that failed to load). No `_process`, no RNG.
  - [x] 3.3 New `scripts/levels/pitchfork_panic/chase_backdrop.gd`: `class_name ChaseBackdrop extends ParallaxBackdrop`, class doc (a Pitchfork Panic setting's backdrop; the one thing it adds is its escape cover; why it lives here and not on `LevelTheme`), `@export var escape_cover_sheet: Texture2D` with a doc line. No other code. `--import` so its `.uid` is written; commit it.
  - [x] 3.4 `moonlit_village.tscn`: script ext_resource → `chase_backdrop.gd`; `escape_cover_sheet = ExtResource(...)` pointing at `res://assets/sprites/props/escape_bush.png`; fix `load_steps`. Nothing else in the scene changes.
  - [x] 3.5 `pitchfork_panic_level.gd` `_ready` (after the `_cfg` check is fine, but the cover must be set even when the config is missing — put it before the early return): `_apply_escape_cover()`. `_backdrop as ChaseBackdrop`: null (plain `ParallaxBackdrop` or no backdrop) → keep the built-in bush silently; a `ChaseBackdrop` with `escape_cover_sheet == null` → `Log.warn(&"level", "...backdrop has no escape cover sheet, using the bush")` once; otherwise `_cover.use_sheet(...)` (its own warning on a bad size). Keep `_accepts_backdrop` as `node is ParallaxBackdrop` (a plain one still fits). Class doc: one line on the per-setting cover.
  - [x] 3.6 Tests (`test_pitchfork_panic_level.gd`). Add a fixture `tests/fixtures/levels/test_chase_backdrop.tscn` (copy `test_backdrop.tscn`, script `chase_backdrop.gd`, `escape_cover_sheet` = `dust_cloud.png`, wide enough for 3 × 48); for the null-sheet case set `escape_cover_sheet = null` on an instance before `add_child` (or a second fixture). Cases: the built-in level (Moonlit) has `%EscapeCover.get_sheet().resource_path == ".../escape_bush.png"` and zero warnings; a level whose backdrop is swapped (`apply_theme`) to a `ChaseBackdrop` with a fixture sheet (e.g. `dust_cloud.png`'s 4×48 sheet is wide enough — or any committed 144×48+ sheet) uses it after `add_child`, and the escape outro shows that sheet; a `ChaseBackdrop` with a null sheet warns once (`assert_push_warning`) and keeps the bush; the plain `test_backdrop.tscn` swap keeps the bush with zero warnings (existing `test_pitchfork_backdrop_swaps_too` covers the count; assert the sheet too); `EscapeCover.use_sheet` with a too-small texture (e.g. `dizzy_star.png`) warns once, returns false, keeps frame count 3. Every existing test passes unchanged apart from the rename.

- [x] **Task 4: Art tool** (AC: 2, 3, 7, 8) — new `tools/gen_chase_themes_art.gd`
  - [x] 4.1 `extends SceneTree`, header doc like `gen_pitchfork_panic_art.gd`'s (what it writes, the run line, the rules, the chase readability band). `const Proto := preload("res://tools/gen_art_prototypes.gd")` (palette); `const Chase := preload("res://tools/gen_pitchfork_panic_art.gd")` for **consts** only (`PERIOD`, `LAYER_H`, `GROUND_ROWS`, `TILE`, `BAND_TOP`, `EFFECT_FRAME`, `BUSH_LEGEND` if useful). Copy the helpers (`_color`, `_sheet_image`, `_tiles_image`, `_ground_strip` (with a per-theme `PATH_TILES` and map), `_layer`, `_put`, `_rect`, `_box`, `_blob`, `_roof`, `_save`): **never edit `gen_pitchfork_panic_art.gd`** (its PNGs must stay byte-identical; 8.6/10.2/10.3 precedent).
  - [x] 4.2 `_init`: write all 12 PNGs (2 covers, 2 × 5 backdrop files; see "Expected new asset files"); non-zero exit on any bad map, legend, path, a strip cell that is not a tile, a non-path tile in row 0, or a reserved colour in any legend or shape (`candy-yellow`, `stamp-red`, `art-moon`). Every backdrop x wraps with `posmod(x, PERIOD)`; something crosses the seam on purpose in every layer.
  - [x] 4.3 Draw both settings and both covers (compositions and colour rules in Dev Notes). Run: `"/c/Program Files/Godot/Godot.exe" --headless --path . -s tools/gen_chase_themes_art.gd`, then `--import`. Rerun once: `git status` shows no change. Commit PNGs with their `.import` (Lossless `compress/mode=0`, no mipmaps, no per-file filter).

- [x] **Task 5: Art tests** (AC: 2, 3, 7, 8)
  - [x] 5.1 `tests/unit/test_art_backdrop.gd`: a "Pitchfork Panic settings (Story 10.4)" section: `PP_THEMES` (dir → path tile indices). Reuse the shared helpers (`_alpha_palette_problems`, `_seam_mismatch_rows`, `_assert_pixel_crisp_import`, `_colors`); where the Moonlit tests hard-code `_load_moon`, add dir-taking helpers rather than copy-pasting (every existing Sunny, Farmhouse, Moonlit, ZR-themes and HR-pairs test passes unchanged). Per dir: sizes; hard alpha + palette; no `candy-yellow`/`stamp-red`/`art-moon`; seams match and a feature crosses (three layers + strip); tiles seamless (left = right col for all four; non-path ground tiles also top = bottom only if you author them that way — match what the Moonlit test asserts); strip built from the tiles (row 0 only path tiles, every tile used); the **chase readability band** (near rows 160-191 opaque + `CHASE_BAND_FORBIDDEN` = `NIGHT_BAND_FORBIDDEN`; strip top 4 rows free of the same plus `wood` `8a5228` and `wood-dark` `5a3218`); Halloween dressing (`pumpkin` and `bat-purple` in near or far); import settings. Header doc: a Story 10.4 paragraph.
  - [x] 5.2 `tests/unit/test_art_sprites.gd`: the two covers in `EFFECT_SHEETS` (3 frames each, so `_size()` returns 48 and the generic outline/alpha/palette/import checks and the sums in `test_right_color_ramps_used` cover them) and in `PITCHFORK_PANIC_SHEETS`; per-cover colour checks in the existing per-path branch (haystack: `parchment-shade` + `wood-light`; hollow log: `wood` + `wood-dark`, moss `art-grass`); `test_effects_stand_on_row_46` covers them; new `test_escape_covers_hide_the_zombie`: frame 0 opaque bounding box ≥ 28 px wide and ≥ 30 px tall for every cover (include `escape_bush.png` if it passes; if not, new covers only and note why).
  - [x] 5.3 Run the two files (`-gdir=res://tests/unit -gselect=test_art_`). Fix the art in the tool, never the rule (a gate may relax a rule: record why).

- [x] **Task 6: Gate 1 — layer and cover review** (AC: 10) — before wiring
  - [x] 6.1 Scratch compositions (scripts in `tools/_scratch_10_4/`, deleted after use): per setting, sky + static child + 4 layers at scroll offsets 0 and 320 and at the run's start (camera x = `-384`: the zombie at screen x 384 at world x 0), with on the ground line (y 192): the zombie (with the Pumpkin hat), the 4-member mob at gap 20 (front at screen x 64) and gap 5 (x 304), two brain pickups, the cover at frame 0 and frame 2 at zombie x + 48, the dust cloud and the dazed zombie with stars; the "Escaped!" label at y 100 as the level draws it. A 3× crop and a grayscale copy (`"/c/Program Files/Godot/Godot.exe" --headless --path . -s tools/capture_screens.gd -- --convert <png>`). Both cover sheets as strips at 3×. Save to `_bmad-output/implementation-artifacts/screenshots/10-4/gate1-<theme>-*.png`.
  - [x] 6.2 Show Smuck; record the verbatim answer with the date in `## Art Approval`. Don't wire anything before Gate 1 passes; redraw in the tool, regenerate, re-show.

- [x] **Task 7: Scenes and registry** (AC: 1, 2, 4)
  - [x] 7.1 `scenes/levels/pitchfork_panic/themes/cornfield_path.tscn`, `spooky_forest_bridge.tscn`: copy `moonlit_village.tscn` (after Task 3.4), swap the textures, the `Sky` colour, the `escape_cover_sheet` and the static child (drop `Moon`, add a `Sun`, or reuse Moonlit's `moon.png` as `Moon` — whatever Gate 1 approved). Keep `format=3`, correct `load_steps`, unique ext ids; let `--import` write uids; commit what it writes.
  - [x] 7.2 `data/levels/level_registry.tres`: two `PackedScene` ext_resources (next free ids **in the file as it is**: 23, 24 today), two `LevelTheme` sub-resources (`Resource_theme_cornfield_path`, `Resource_theme_spooky_forest_bridge`: `script`, `id`, `backdrop`), `pitchfork_panic`'s `themes = Array[ExtResource("12_theme")]([SubResource("Resource_theme_moonlit_village"), SubResource("Resource_theme_cornfield_path"), SubResource("Resource_theme_spooky_forest_bridge")])`, `load_steps` 35 → 39. Moonlit stays first.
  - [x] 7.3 Do **not** touch `pitchfork_panic.tres`, `chase_mob.tscn`, `brain_pickup.tscn`, or any other entry. `pitchfork_panic_level.tscn` changes only by the Task 2.2 rename (its built-in `%Backdrop` stays the Moonlit instance, so `themes[0]` is the no-op).

- [x] **Task 8: Tests for the shipped settings** (AC: 1, 6)
  - [x] 8.1 `tests/unit/test_level_registry.gd::test_shipped_registry_themes`: Pitchfork Panic ships `moonlit_village`, `cornfield_path`, `spooky_forest_bridge` in order, each with a backdrop (paths asserted), no defender, empty `music_id`; every Pitchfork backdrop instantiates to a `ChaseBackdrop` with a non-null `escape_cover_sheet` (or assert that in 8.4); the other levels as they are; `validate() == ""`.
  - [x] 8.2 `tests/integration/test_run_frame.gd::test_shipped_levels_start_in_their_theme`: `pitchfork_panic`'s theme is now drawn among three; extend its expected list (the membership assert already handles it; the exact assert stays only for single-theme levels — after this story none remain).
  - [x] 8.3 New RunFrame cases (same file; injected temp `PlayerData`, never the autoload): (a) **AC 6**: seed 42, `"theme"` forced to each of the three ids; type the same N correct keys through the frame's session, step `_process` a fixed number of times with a fixed delta → identical passage/targets, `get_level_config()`, `get_model().zombie_steps` / `mob_steps`, `get_brains_earned()`; `%Backdrop.scene_file_path` and `%EscapeCover.get_sheet()` are that theme's; zero warnings/errors. Mirror `test_horde_rush_rules_do_not_change_with_the_pair` (l.~2444) and its scripted-run helper. (b) Rotation: five consecutive Pitchfork Panic starts on one temp PlayerData with different seeds → no two consecutive ids equal. (c) Seeds 1..60 with last = `&""` → all three appear.
  - [x] 8.4 `tests/unit/test_level_themes.gd`: new case — the Pitchfork Panic scene with `cornfield_path` and with `spooky_forest_bridge` applied: `%Backdrop` swapped (scene path, index, name, unique name), is a `ChaseBackdrop` the level holds (`_backdrop`), `_set_zombie_x(1000)` moves its ground layer, after `add_child` `%EscapeCover.get_sheet()` is the theme's cover; zero warnings (all textures present). `test_pitchfork_backdrop_swaps_too` asserts `%EscapeCover` now. `test_each_shipped_theme_is_a_no_op` keeps using `themes[0]` and passes unchanged.
  - [x] 8.5 `tests/unit/test_no_placeholder_chrome.gd`: add the two new theme scenes to its explicit list next to `moonlit_village.tscn` (l.~24) if it keeps one; each has exactly one `ColorRect` (the `Sky`).

- [x] **Task 9: Debug jumps and art review** (AC: 9)
  - [x] 9.1 `scripts/debug/debug_overlay.gd`: `THEME_JUMP_LEVELS` gains `&"pitchfork_panic"` (9 theme buttons in all). Check they fit the panel (the row may need to wrap: an `HFlowContainer` or a second row; debug text, 8 px is fine). `tests/unit/test_debug_overlay.gd`: the three Pitchfork buttons with the right payloads (extend the existing theme-jump test; never navigate the live Router).
  - [x] 9.2 `scripts/debug/art_review.gd`: add `escape_haystack` and `escape_hollow_log` (48 px, `BUSH_FPS`); update `tests/unit/test_art_review.gd`'s expected list and page assertions.

- [x] **Task 10: Gate 2, checklists, smoke** (AC: 7, 10, 11)
  - [x] 10.1 In-game captures on the real `RunFrame` per new setting (scratch capture scene under `tools/_scratch_10_4/`, forced theme, fixed seed, temp `SaveService` dir — **never the real save**, sha256 before/after): `gate2-<theme>-start.png`, `-mob-close.png` (the mob on screen at gap ~10, a pickup ahead), `-escape-dive.png` (zombie mid-hop into the cover), `-escape-label.png` ("Escaped!"), `-caught-dazed.png` (dust cloud gone, dazed + stars + "Got you!"), plus a 3× crop of the mob and a grayscale of `-mob-close`. Include the HUD paragraph band in at least one capture. Save to `screenshots/10-4/`.
  - [x] 10.2 Fill in the **chase setting readability checklist** per setting (Dev Notes) in Debug Log References.
  - [x] 10.3 Show Smuck; record the verbatim Gate 2 answer with the date in `## Art Approval`. Tell Smuck how to reach each setting: F3 → the theme jump buttons (from the menu card the setting is random, never the previous one).
  - [x] 10.4 Scroll/perf smoke (web debug build via the `web-debug` launch config, its `user://` is browser storage): a full Pitchfork Panic run per new setting to the Escaped! ending (F6 is fine for the second half once the scroll has been seen); no seam, gap or flicker; the ground in step with the zombie; worst in-run frame under 33 ms (NFR1, F3 overlay); console clean.

- [x] **Task 11: Wrap-up** (AC: 11)
  - [x] 11.1 Full suite as in Task 1; record count, `SCRIPT ERROR` / `WARNING` deltas (explain each), zero parse/compile errors; real save sha256 unchanged; `git status` shows no modified existing `.png` or `.wav`.
  - [x] 11.2 Mutation pass (each must turn a test red): `ink` at y 170 in a new `near.png`; `wood` in the cornfield strip's row 0; a transparent pixel at y 180 in a new `near.png`; a strip cell that is not a tile; a layer clipped at the seam; `candy-yellow` in the haystack; a haystack frame standing on row 45; drop `spooky_forest_bridge` from the registry; `escape_cover_sheet` emptied in `cornfield_path.tscn` (the warning test and the forced-theme test); the forced-theme RunFrame test with one theme's `pitchfork_panic.tres` duplicated and `step_px` changed. (Edit, run, restore; PNG mutations via the tool, then regenerate byte-identical.)
  - [x] 11.3 `docs/art-style-sheet.md`: section 1 (Epic 10 Pitchfork Panic settings done in 10.4), the animation table rows (the two covers), section 3 (a Cornfield Path + Spooky Forest Bridge paragraph: folders, tiles, the chase readability band, the covers, *tested*), "How sprites are made" (the new tool), the `EscapeCover`/`ChaseBackdrop` names.
  - [x] 11.4 `deferred-work.md`: under the 10-1 dev section append "Resolved in 10.4: per-setting escape cover (on `ChaseBackdrop`, not `LevelTheme`)"; under the 8.6 "One bush for every setting" line append "Resolved in 10.4" (never delete history). New "Deferred from: dev of story 10-4" (at least: dust cloud, dizzy stars and `sfx_escape` stay setting-independent; the Pitchfork Panic level card still shows the Moonlit Village; per-setting music not used; the mob keeps its nightcaps and pyjamas in every setting; the registry now eagerly loads three Pitchfork backdrops; the overlay's theme rows are still keyed by `THEME_JUMP_LEVELS`; `mob_hint.png` still unused; anything accepted at a gate).
  - [x] 11.5 Dev Agent Record, File List, Change Log; `sprint-status.yaml` → `review`.

## Dev Notes

### What this story is (and isn't)

- **Is:** two new Pitchfork Panic settings (art tool, 12 PNGs, 2 theme scenes, 2 registry entries), a per-setting escape cover carried by the backdrop scene (`ChaseBackdrop` + `EscapeCover.use_sheet`), the `EscapeBush` → `EscapeCover` rename, art/level/RunFrame tests, debug jumps, two gates.
- **Isn't:** any theme plumbing change (10.1: `LevelTheme`, `ThemePicker`, `last_themes`, `_swap_slot` work as is), new mob art, per-setting dust cloud/stars/sounds, new music, the level card, tuning, trends (10.5). If you find yourself editing `run_frame.gd`, `level_base.gd`, `theme_picker.gd`, `level_theme.gd` (doc line only is fine), `parallax_backdrop.gd` (doc line only is fine), `save_schema.gd`, `player_data.gd`, `pitchfork_panic.tres`, `chase_model.gd`, `chase_mob.*`, `pickup_trail.gd`, `brain_pickup.*`, `dust_cloud.gd`, `dizzy_stars.gd`, `player_zombie.*` or `gen_pitchfork_panic_art.gd`, stop: out of scope.

### Design decisions made for this story (follow them; record any change and why)

- **The cover lives on the backdrop scene, not on `LevelTheme`** (10.3 precedent: the projectile pair lives on the defender scene). 10.1's deferral said "per-theme dive props are left to 10.4". A `ChaseBackdrop` keeps each setting whole in one scene (a cornfield can never be registered with the forest's log), keeps `LevelTheme` level-agnostic (its pinned 4-property list stays true), needs no registry validation, and keeps the 10.1 fallback (the plain-`ParallaxBackdrop` fixture still swaps in silently and the bush shows).
- **A subclass, not an export on `ParallaxBackdrop`.** `ParallaxBackdrop` drives Zombie Run too; an escape export there would be dead weight on four Zombie Run scenes. `ChaseBackdrop` adds only the export; it must not override `_ready`/`scroll_to` (the parent's missing-texture warning and rounding stay exactly as tested).
- **Only the cover picture changes per setting.** The 48×48, 3-frame, row-46 contract and the tween-stepped rustle are unchanged, so `EscapeCover` just swaps its `SpriteFrames`; the outro code and its tests stay as they are. Dust cloud and dizzy stars are setting-neutral already (a scuffle and stars) — deferred.
- **Rename `EscapeBush` → `EscapeCover`** now (10.3 lesson: its review had to rename leftover tomato names after the fact). The PNG `escape_bush.png` keeps its name: it *is* the Moonlit bush.
- **Theme ids `cornfield_path` and `spooky_forest_bridge`** (the epic's names). Folders `backdrops/cornfield_path/`, `backdrops/spooky_forest_bridge/`.
- **Torch-friendly light.** The mob carries torches, so neither setting is a bright noon: Cornfield Path at sunset (`dusk` sky, a low `pumpkin-light` sunset glow), Spooky Forest Bridge at night under the trees (`night` sky). Both must differ from the Moonlit Village at a glance (warm golden corn vs blue-grey cobbles; dark green woods and a plank bridge vs a street).
- **The whole path is the setting's path.** The ground strip wraps every 640 px, so the Forest's path is a continuous plank boardwalk/bridge over a creek (row 0 planks, rows 1-3 creek water, reeds, stones under it), the Cornfield's a dirt farm track between corn (row 0 dirt, rows 1-3 corn roots, straw, dirt). Planks are `wood-light`/`parchment-shade`, never `wood`/`wood-dark` in the top 4 rows (the zombie's trousers and shoes would sink in; 6.6 "soil is not wood" lesson, *tested*).
- **New tool, old tool untouched** (8.6/10.2/10.3 precedent): `gen_pitchfork_panic_art.gd`'s PNGs must stay byte-identical; reading its consts by `preload` is fine.

### Layout facts (`pitchfork_panic_level.gd`; unchanged)

- `GROUND_Y` 192; the ground strip is y 192-255; the HUD band (paragraph text) starts at y 256, below every backdrop pixel.
- Camera: the zombie at `zombie_screen_x_frac` 0.6 × 640 = **x 384**; `step_px` 16; the mob's front at screen x = 384 − gap × 16; the mob shows while gap < `mob_visible_gap_steps` (25: front just off screen at x −16) and its back member trails 42 px behind.
- Escape: the cover at the zombie's x + 48 (`ESCAPE_COVER_AHEAD_PX`) on `GROUND_Y`, i.e. screen x 432, sprite x 408-455, y 145-192; the zombie hops 10 px and vanishes on arrival; "Escaped!" (candy-yellow, ink outline, 32 px) at y 100-140, centred at x 320. "Got you!" at y 100 centred on the zombie.
- Draw order under `%World`: `Pickups`, `Mob`, `Zombie`, `EscapeCover`, `DustCloud`, `DizzyStars`, then pops. The pause button is top-right (x ≥ 600, y ≤ 40): keep a sun/moon and bright stars out of that corner.
- At the run start the camera x is −384 (`_set_zombie_x(0)`), so near-layer offset = posmod(−192, 640) = 448: near x 448-639 then 0-447 show on screen; the zombie at screen x 384 has near x ≈ 192 behind it (8.6 lesson: nothing round with its bottom just above the zombie's crown, y ~160, reads as a hat there).

### Colour rules (most *tested*)

| Rule | Where | Why |
|---|---|---|
| no `candy-yellow`, `stamp-red`; `art-moon` only in a reused `moon.png` | every new file | end-label/focus colour, stamp (D16, never blood), moon reserved |
| **chase readability band**: fully opaque, none of `ink`, `night`, `zombie-green`, `zombie-green-bright`, `bat-purple`, `art-brain-pink`, `art-brain-shade` | `near.png` rows 160-191 | the zombie's outline, skin and shirt, the mob's ink and the brain pickups stand out (8.6 night band, same list) |
| the same set plus `wood`, `wood-dark` | ground strip rows 0-3 | the path under the feet; the zombie's trousers/shoes |
| `pumpkin` and `bat-purple` somewhere in near or far | each setting | cute-Halloween dressing (D6) |
| palette only, alpha 0 or 255; ink outline on covers | every file | NFR13 |

- **Mob distance readability** (checklist, not a test): the mob's clothes are `art-sky-light`/`art-sky` (base A), `parchment`/`parchment-shade` (A alt), `wood-light`/`wood` and `disabled-fill`/`ink-faded` (B, B alt), skin `art-skin-light`/`art-skin-dark`, flames `pumpkin`/`pumpkin-light`/`parchment`. In the near band avoid large flat areas of exactly those (especially behind x 64-304, where the mob runs at gap 20 → 5): e.g. corn in `parchment-shade` with `wood-light` stalks is fine only if the mob still separates by its ink outline in the grayscale; prefer `zombie-green-dark`/`art-grass`/`stone`/`dusk`/`ink-muted` for the band's big masses.
- **Pickups** are `art-brain-pink`/`art-brain-shade` with ink: banned in the band and the path, so they always pop.

### Suggested compositions (Gate 1 decides; keep the Moonlit shape style: rects, roofs, blobs, discs)

**Cornfield Path** (`cornfield_path`, sunset):
- `Sky` `dusk` `#4A3366`. Static `Sun` child (optional): a half-set `pumpkin-light` disc with a `pumpkin` rim low on the horizon, left of x 560 (not the pause corner), no face needed (a smile is fine; keep it different from the moon).
- `clouds.png`: long thin sunset clouds in `pumpkin`/`pumpkin-light`/`bat-purple` streaks, a few `chalk` first stars high up (above y 60), one cloud across the seam.
- `far.png`: rolling hills in `ink-muted`/`dusk` silhouette with a red-free barn and silo, a windmill-free horizon (Moonlit has one), rows of tiny `pumpkin` dots (a distant pumpkin patch), a friendly bat or two (`bat-purple`).
- `near.png`: a wall of tall corn (`zombie-green-dark` leaves, `art-grass` highlights, `parchment-shade` cobs with `wood-light` husks above y 160 only) over an opaque band of corn stalks and dirt for rows 160-191 (`zombie-green-dark`, `art-grass`, `stone`, `wood-light` — check the forbidden list), a smiling scarecrow (button eyes, a patched `bat-purple` shirt, a hat — not a crow-eaten creepy one), a few pumpkins by the stalks, a wooden fence or a hay cart.
- `ground_tiles.png`: tile 0 packed dirt (`parchment-shade` with `ink-faded` specks), tile 1 dirt with a straw wisp (`wood-light`), tile 2 dirt with a pebble (`stone-light`), tile 3 corn roots/stubble (`zombie-green-dark`, `art-grass`) for rows 1-3 only; path tiles = 0, 1, 2 (row 0); all four used.
- `escape_haystack.png` (48×48, 3 f, row 46): a round haystack (`parchment-shade` body, `wood-light` straw lines, `ink` outline, a small `pumpkin` on its side or a pitchfork-free top), frames 1-2: the stack bulges/leans 1-2 px and straw wisps pop off the top. Wide enough to hide the 32 px zombie (≥ 28 × 30 opaque).

**Spooky Forest Bridge** (`spooky_forest_bridge`, night in the woods — goofy-spooky):
- `Sky` `night` `#2B1D3F`. Static `Moon` optional (reuse `res://assets/sprites/backdrops/moonlit_village/moon.png`, the only allowed `art-moon`; place it away from x ≥ 560, y ≤ 48) — or no moon and fireflies instead.
- `clouds.png`: a few `dusk` clouds, `chalk` stars, `pumpkin-light` fireflies (1-2 px; not candy-yellow, not art-moon) in the upper sky only.
- `far.png`: layered rounded tree tops (`zombie-green-dark`/`dusk`/`ink-muted`), a friendly owl on a branch (big round `parchment` eyes with `ink` pupils, a smile — no glowing or slit eyes), a bat.
- `near.png`: big friendly trees with smooth trunks (`wood`/`wood-dark` above row 160 is fine; in rows 160-191 use `stone`, `zombie-green-dark`, `art-grass`, `ink-muted`, `wood-light`), toadstools (`pumpkin` caps with `chalk` dots), a jack-o'-lantern on a stump, ferns, the bridge's handrail posts and rope (`wood-light`, `parchment-shade`) along the band. No cobwebs, no grabbing branches, no skulls.
- `ground_tiles.png`: tile 0 bridge plank (`wood-light` with `parchment-shade` grain, a `stone-light` nail), tile 1 plank with a knot (`ink-faded` ring is fine — check the band list; `ink` is not allowed in rows 0-3), tile 2 creek water (`art-sky`/`dusk` ripples with `art-sky-light` glints), tile 3 reeds/stones (`zombie-green-dark`, `stone`); path tiles = 0, 1 (row 0); rows 1-3 the creek under the bridge (never a plank).
- `escape_hollow_log.png` (48×48, 3 f, row 46): a fat hollow log lying on the path end-on or side-on with a dark (`dusk`, not `ink` fill) opening the zombie dives into, `wood`/`wood-dark` bark, `art-grass` moss, a `pumpkin` toadstool on top; frames 1-2: the log rocks 1 px and a couple of leaves/moss bits pop off. Must read as a log, not a mouth or a face. (Gate 1 may prefer a fern hedge: same contract.)

### Chase setting readability checklist (per setting, 1×, pass/fail each; from 8.6, extended)

1. The zombie reads by silhouette over the near band and the path at every scroll offset, with and without the Pumpkin hat.
2. The mob reads as four goofy villagers (not monsters) at gap 20 (just in) and gap 5 (close): the distance between the mob's front and the zombie is easy to judge at a glance.
3. Torches read as torches, nothing glows, the sunset/fireflies never look like fire or danger.
4. Brain pickups read on the path.
5. The cover reads as a haystack / hollow log (not a monster, mouth or face); the dive into it reads.
6. Dust cloud and dazed beat still read on this setting; "Got you!" and "Escaped!" read over the far layer and sky.
7. Nothing in the backdrop looks like a target, a letter, a number or UI; the HUD paragraph band is unaffected.
8. The pause button reads over the sky/top-right.
9. Grayscale (NFR8): zombie, mob, pickups and the cover separate from the backdrop by value or outline.
10. Tone (NFR10): goofy-spooky; a 6-year-old would not be scared, a 13-year-old would not cringe.
11. It feels like a different place from the Moonlit Village (and from the other new setting) at a glance.

### Existing code: current state, what changes, what must be preserved

- `scripts/levels/pitchfork_panic/escape_bush.gd` → `escape_cover.gd` (RENAME + `use_sheet`/`get_sheet`). Today: `_ready` builds the sprite in code (`SheetFrames.build(SHEET_PATH, 3, 48, 8.0, &"rustle", false, "escape bush")`, sprite at (−24, −47), `centered = false`); `rustle(duration_s)` kills/restarts a node-bound tween stepping frames 1,2,1,2 then `_settle` to 0; `get_tween`, `get_frame`. Preserve all of it; tests create it with `new()`.
- `scripts/levels/pitchfork_panic/sheet_frames.gd` (UPDATE): `build(path, ...)` loads and slices; add `from_texture`, `build` delegates; warnings unchanged.
- `scripts/levels/pitchfork_panic/pitchfork_panic_level.gd` (UPDATE): `@onready var _bush: EscapeBush = %EscapeBush` (l.139), `ESCAPE_BUSH_AHEAD_PX` (l.~99), `_play_escape` / `_vanish_into_bush` (l.~305-325), the outro-node null check in `on_run_ending`, `_ready` (l.~148). Preserve: one step per key in the key's call, logic before visuals, the catch-before-timer priority, both outros' timings and order, the run RNG drawing exactly twice, sounds inside `on_run_ending`'s guarded call, `_accepts_backdrop` (`node is ParallaxBackdrop`).
- `scripts/levels/zombie_run/parallax_backdrop.gd` (NO CHANGE; a doc line naming the chase settings is OK): `_ready` warns on a missing layer texture with the owner's name; `scroll_to` rounding. `ChaseBackdrop` inherits both.
- `scenes/levels/pitchfork_panic/themes/moonlit_village.tscn` (UPDATE: script → `chase_backdrop.gd`, + `escape_cover_sheet`). Every node, texture and the Sky colour unchanged.
- `scripts/run/level_base.gd` (NO CHANGE): `_swap_slot` is a no-op when the slot already is that scene, copies `position`, checks `accepts`, keeps parent/index/owner/unique name; `@onready` vars resolve at `_ready`, which runs after `apply_theme` (RunFrame applies the theme before `add_child`), so `_backdrop` is the swapped-in scene when `_apply_escape_cover` runs.
- `data/levels/level_registry.tres` (UPDATE): today `load_steps=35`, ext ids to `22_lifeguard`, theme script `12_theme`, Moonlit `16_moonlit_village`, `Resource_theme_moonlit_village`.
- `scripts/debug/debug_overlay.gd` (UPDATE): `THEME_JUMP_LEVELS` (l.64), `_build_theme_jumps()` (l.~374). 10.3 review deferred "hard-coded list; revisit when a third themed level lands": this is it — adding the id is the agreed fix; button names `JumpTheme_<id>` stay unique (all theme ids are distinct across levels).
- **Must not change:** `pitchfork_panic.tres`, `chase_mob.*`, `brain_pickup.*`, every existing PNG/WAV/OGG, `tools/gen_pitchfork_panic_art.gd`, `tools/pitchfork_panic_sim.gd`, `scripts/run/*`, `scripts/core/*`, `scripts/autoloads/*`, `player_zombie.*`, Zombie Run and Horde Rush scenes.

### Known test fallout (so you are not surprised)

| Test | Why | Fix |
|---|---|---|
| `test_pitchfork_panic_level.gd`, `test_level_themes.gd` | `EscapeBush`/`%EscapeBush` rename | Task 2 (names only) |
| `test_level_registry.gd::test_shipped_registry_themes` | Pitchfork ships one theme | Task 8.1 |
| `test_run_frame.gd::test_shipped_levels_start_in_their_theme` | expects `[moonlit_village]` | Task 8.2 |
| `test_art_review.gd` | exact sheet list and pages | Task 9.2 |
| `test_debug_overlay.gd` | theme-jump button count/payloads | Task 9.1 |
| `test_art_sprites.gd` | `EFFECT_SHEETS` sums | Task 5.2 |
| `test_parallax_backdrop.gd`, `test_level_theme.gd` (property list) | — | must pass unchanged |

### Testing notes

- Commands in Task 1. Run `--import` after the rename (class cache: stale caches give "Could not find type" parse errors), after adding `chase_backdrop.gd`, after the tool writes PNGs and after adding scenes.
- Never write the real save: temp-dir `SaveService` + injected `PlayerData` (`test_run_frame.gd::_make(payload, null, data)`, `_fake_player_data()`). Running a `-s` tool loads the autoloads, which *read* the real save; check its sha256 after every tool and capture run (10.3 log).
- Pitchfork level tests: the `play_sfx` recorder seam (assigned before `add_child`), `custom_step` on `get_outro_tween()` / `EscapeCover.get_tween()`.
- GUT 9.7.1: `assert_push_warning` / `assert_push_warning_count` / `assert_push_error_count` for deliberate logs; GUT silently skips a script that fails to parse and still exits 0 — always grep the log for `Parse Error|Compile Error|Failed to load script` (8.7 found 49 Pitchfork tests silently skipped this way).
- Image tests read committed PNG bytes with `Image.load_from_file(ProjectSettings.globalize_path(path))`, not `load()`.
- Sort `String`s, never `StringName`s. Type every `for` variable (`untyped_declaration = Error` in tests too).
- Flaky `test_audio_manager` pool test: rerun once before investigating.

### Previous story intelligence

- **10.3 (done):** the same "slot scene carries its extras" pattern (`HordeDefenderSprite` exports, resolved once in the level's `_ready`, silent fallback for a plain fixture node, one warning per empty export on a real one); class renames first, proven by an unchanged suite; a new art tool reading the old tool's consts by `preload`; forced-theme RunFrame test keyed on scene paths (its first mutation attempt keyed on the node name and never fired: a swapped slot keeps the name — key on `scene_file_path`); review patched leftover old names (rename everything now). Gates answered "i approve" / "approved". Baseline it ended at: 2144 tests, `SCRIPT ERROR` 3, `WARNING` 172. `_bmad-output/` has a `.gdignore`: screenshots get no `.import`.
- **10.2 (done):** parallax-theme art tool pattern, seam/tile/strip tests made dir-taking helpers, the overlay theme-jump builder, rotation and "all appear over seeds 1..60" tests. Snow was not chalk (band rules drive colour choices — expect the same with corn and planks).
- **8.6 (Moonlit Village):** the night readability band (reused here as the chase band), the 48×48 effect frame on row 46, the bush contract, the mob = 2 bases + clothes recolours, the static `Moon` child outside the layers, "frames, not transforms" (no scaling/rotating pixel art: the log rocks by frames, not by `rotation`), Gate 1 accepted the busy grout and a subtle rustle. **8.7:** the mob walks in whole from the left edge at gap 25 (the hint was removed; `mob_hint.png` unused).
- **Traps:** files LF (`.gitattributes eol=lf`; working copies may be CRLF via `core.autocrlf`; normalise before scripted matching). Hand-edited `.tscn`/`.tres`: `format=3`, correct `load_steps`, unique ids. Godot rewrites uids on import — commit what it writes.

### Git intelligence

- Recent: `e5ec1d6 Story 10.3: code review patches applied, done`, `1e45d78 Story 10.3: Castle + Knight and Beach Hut + Lifeguard`, `bb5f9f8 Story 10.2 ...`, `2aafc7b Story 10.1 ...`. One commit per story with code, art, data, tests, screenshots, the story file, `deferred-work.md` and `sprint-status.yaml` together.
- Expected shape: new `tools/gen_chase_themes_art.gd` (+ `.uid`); 12 PNGs + `.import`; `chase_backdrop.gd` (+ `.uid`); 2 theme scenes; 1 renamed script (+ `.uid`); `pitchfork_panic_level.gd`/`.tscn`, `sheet_frames.gd`, `moonlit_village.tscn`, `level_registry.tres`, `debug_overlay.gd`, `art_review.gd`; ~9 test files; style sheet; screenshots. Suggested message: `Story 10.4: Cornfield Path and Spooky Forest Bridge`.

### Expected new asset files

- `assets/sprites/backdrops/cornfield_path/clouds.png`, `far.png`, `near.png` (640×192), `ground_tiles.png` (64×16), `ground_strip.png` (640×64)
- `assets/sprites/backdrops/spooky_forest_bridge/` the same five
- `assets/sprites/props/escape_haystack.png`, `escape_hollow_log.png` (144×48: 3 frames of 48×48)
- = **12 PNGs** (no new WAV/OGG; no new `moon.png` — a Forest moon reuses Moonlit's)

### Latest tech notes (Godot 4.7.2, GUT 9.7.1)

- No new libraries or engine APIs; nothing to research. Godot 4.7.2, Compatibility renderer, GDScript only, static typing.
- A `class_name` subclass of a script class (`ChaseBackdrop extends ParallaxBackdrop`) inherits `_ready` unless overridden; `node is ParallaxBackdrop` is true for it. After adding/renaming a `class_name`, run `--import` to rebuild `.godot/global_script_class_cache.cfg`.
- `@export var escape_cover_sheet: Texture2D` serialises in the `.tscn` as `escape_cover_sheet = ExtResource("...")` on the root node, under its `script =` line.
- `git mv` of a script with its `.gd.uid` keeps the uid; `ext_resource` lines by path must be updated.
- `Image.save_png` writes deterministic bytes, so a rerun of the tool shows no diff.

### Project Structure Notes

- Art tool in `tools/`; covers in `assets/sprites/props/` (next to `escape_bush.png`); backdrops in `assets/sprites/backdrops/<theme_id>/`; `chase_backdrop.gd` and `escape_cover.gd` in `scripts/levels/pitchfork_panic/`; theme scenes in `scenes/levels/pitchfork_panic/themes/<theme_id>.tscn`; scratch in `tools/_scratch_10_4/` (deleted); screenshots in `_bmad-output/implementation-artifacts/screenshots/10-4/`.

### Project Context Rules

- There is no `project-context.md`. Rules from the architecture and earlier stories:
  - Levels never read input, the clock or PlayerData; RunFrame calls down (`apply_theme`), levels signal up.
  - One RNG per run (Pitchfork: exactly two draws); the theme has its own seed-derived RNG; art tools use no unseeded RNG.
  - Static data via `@export` Resources; theme ids permanent once shipped (`cornfield_path`, `spooky_forest_bridge` join the saved ids).
  - NFR16: a missing texture, scene or export never stops a run (warn + built-in fallback).
  - NFR10: goofy, never scary; no gore; pitchforks upright; NFR9/NFR10: no text in art; theme ids are debug-only text.
  - Debug code only in `scenes/debug/` / `scripts/debug/`; release-hidden.
  - Visible changes wait for Smuck's approval (Gate 1 before wiring, Gate 2 in game), recorded verbatim with dates.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 10.4: Cornfield Path and Spooky Forest Bridge]; Epic 10 overview; FR70, FR73, FR74, FR76; NFR1, NFR8, NFR10, NFR13, NFR16
- [Source: _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md] (Pitchfork Panic settings, mob reuse)
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/DESIGN.md] (D6 Halloween dressing, D16 stamp red reserved, no grit/gore/horror lighting)
- [Source: docs/art-style-sheet.md] sections 1-3 (animation table `escape_bush` row l.167, Moonlit paragraph, how sprites are made)
- [Source: tools/gen_pitchfork_panic_art.gd] (header l.1-27, BUSH_LEGEND/BUSH_* maps l.340-640, backdrop consts l.762-913, helpers l.977-1275), [tools/gen_art_prototypes.gd PALETTE], [tools/capture_screens.gd --convert]
- [Source: scripts/levels/pitchfork_panic/pitchfork_panic_level.gd], [escape_bush.gd], [sheet_frames.gd], [scripts/levels/zombie_run/parallax_backdrop.gd], [scripts/run/level_base.gd l.63-100], [scripts/resources/level_theme.gd], [data/levels/level_registry.tres], [scenes/levels/pitchfork_panic/*.tscn], [scripts/debug/debug_overlay.gd l.64, 374], [scripts/debug/art_review.gd l.82]
- [Source: tests/unit/test_art_backdrop.gd l.384-586 (Moonlit section, shared helpers)], [test_art_sprites.gd l.30-45, 129, 495-510, 876-910], [test_level_themes.gd l.105-140], [test_pitchfork_panic_level.gd l.570-700], [test_level_registry.gd ~l.255-270], [tests/integration/test_run_frame.gd l.2311-2470], [test_no_placeholder_chrome.gd l.12-31], [test_art_review.gd l.53, 137, 154]
- [Source: _bmad-output/implementation-artifacts/10-3-castle-knight-and-beach-hut-lifeguard.md], [10-2-pumpkin-patch-farm-and-snowy-town.md], [8-6-moonlit-village-mob-and-chase-music.md] (night band, checklist, gates), [deferred-work.md] (l.728 one bush; l.831 10-1 deferral; l.772 mob hint)

## Art Approval

<!-- Gate 1 (Task 6.2) and Gate 2 (Task 10.3): Smuck's verbatim answers, with dates. -->

- **Gate 1** (2026-10-14; both settings' layers at 1x, 3x and grayscale, run start and scroll offsets 0 / 320, mob at gap 20 and gap 5, both covers' frames 0-2 at 3x; `screenshots/10-4/gate1-*.png`): "approved". Approved as shown: no static `Sun` or `Moon` child in either setting (the Cornfield's sunset is the clouds layer's bands; the Forest has fireflies and stars, and its canopies would hide a moon), haystack and hollow log as drawn.
- **Gate 2** (2026-10-14; in game on the real RunFrame, both settings: start, mob close, escape dive, "Escaped!", caught and dazed; `screenshots/10-4/gate2-*.png`): "approved". Smuck was told how to reach each setting: F3, then the `cornfield_path` / `spooky_forest_bridge` theme jump buttons (from the menu card the setting is random, never the previous one).

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Debug Log References

- Baseline (Task 1): 2144 tests / 2144 passing, `SCRIPT ERROR` 3, `WARNING` 172, zero `Parse Error|Compile Error|Failed to load script`. Real save sha256 `2859cbaa61d4fc9a7a4b7b7e8019794def38313e28a8ba71d8b6a0cd347d647a`.
- After the rename (Task 2): 2144 / 2144, 3 / 172, zero parse errors (names only, as required).
- After the cover plumbing (Task 3): 2150 / 2150, `SCRIPT ERROR` 3, `WARNING` 174 (+2: the deliberate, asserted "no escape cover sheet" and "smaller than 3 frames of 48 px" warnings).
- Art tool (Task 4): `tools/gen_chase_themes_art.gd` exits 0 and writes 12 PNGs; a rerun is byte-identical (sha256 of all 12 unchanged). Real save sha256 unchanged after every tool run.
- Art tests (Task 5): `-gselect=test_art_` 125 / 125. `escape_bush.png` passes the new hide-the-zombie size check too, so it is included.
- After the scenes, registry and tests (Tasks 7-8): 2165 / 2165, `SCRIPT ERROR` 3, `WARNING` 174, zero parse errors. After Task 9: 2165 / 2165, same counts.
- Gate 2 captures (Task 10.1): scratch windowed runner `tools/_scratch_10_4/capture_gate2*.gd` on the real `RunFrame`, forced setting, seed 42, temp `user://capture_10_4/` save dir; `screenshots/10-4/gate2-<theme>-{start,mob-close,escape-dive,escape-label,caught-dazed}.png` (+ `-gray`) and `-mob-3x.png`. The HUD paragraph band shows in every capture. Real save sha256 unchanged.
- **Chase setting readability checklist** (Task 10.2), at 1x, from the Gate 1 compositions and the Gate 2 captures:

  | # | Cornfield Path | Spooky Forest Bridge |
  |---|---|---|
  | 1 | pass: the ink outline and green skin stand out over the dark-green corn band and the tan track, with and without the Pumpkin hat | pass: same over the fern band and the planks |
  | 2 | pass: four villagers in nightcaps at gap 20 and gap 5; the gap reads against the fence posts | pass: same; the handrail posts give the distance |
  | 3 | pass: torches read as torches; the sunset is flat bands behind the hills, no glow | pass: fireflies are 1 px dots high in the sky; the jack-o'-lantern is a plain pumpkin |
  | 4 | pass: pink brains on the tan track | pass: pink brains on the planks |
  | 5 | pass: a haystack with a pumpkin; the dive reads | pass: a log with a round hollow end, no face; the dive reads |
  | 6 | pass: dust cloud and dazed beat read; "Got you!"/"Escaped!" read over the hills and sunset (ink outline) | pass: same, over the trees and far woods |
  | 7 | pass: no letters, numbers or targets; HUD band unaffected | pass |
  | 8 | pass: pause button over the dusk sky | pass: pause button reads over a canopy when one scrolls under it (brown with ink outline on green) |
  | 9 | pass: zombie, mob, pickups and haystack separate by value or outline (`gate1-cornfield_path-1x-gray`, `gate2-cornfield_path-mob-close-gray`) | pass (`gate1-spooky_forest_bridge-1x-gray`, `gate2-spooky_forest_bridge-mob-close-gray`) |
  | 10 | pass: a smiling scarecrow, pumpkins, a sunset farm | pass: friendly trees, a smiling owl, toadstools; nothing scary |
  | 11 | pass: warm golden-orange farm vs the blue-grey Moonlit street | pass: green woods, a plank bridge over a creek |
- **Scroll/perf smoke (Task 10.4):** a web debug export (`--export-debug "Web" build/web/index.html`) served by the `web-debug` launch config in the browser pane (browser storage, never the real save). F3 then `cornfield_path`, then `spooky_forest_bridge` (the nine theme buttons wrap onto three rows of the overlay's `HFlowContainer`). Keys were typed through synthetic browser key events, because the pane's key injection drops capitals. About 45 keys (Cornfield) and 53 keys (Forest) were typed, with pickups collected and the scroll watched (no seam, gap or flicker; the ground in step with the zombie). F6 then ended each run on the Escaped! ending, after about 35 s and 20 s of run time, not a full 5:00. The overlay's "Run" worst frame was 17.2 ms (Cornfield) and 16.8 ms (Forest), under 33 ms (NFR1), at 60 FPS. No console errors in the buffered log (older lines were dropped before reading). Each run's report card showed Pitchfork Panic with the escape bonus.
- **Wrap-up (Task 11.1):** 2165 / 2165 (baseline 2144, +21), `SCRIPT ERROR` 3 (unchanged), `WARNING` 174 (+2: the deliberate, asserted "no escape cover sheet" and "smaller than 3 frames of 48 px" warnings in `test_pitchfork_panic_level.gd`), zero `Parse Error|Compile Error|Failed to load script`. Real save sha256 `2859cbaa...647a` unchanged (checked after every tool run, both capture runs and every suite run). `git status`: no modified existing `.png` or `.wav`.
- **Mutation pass (Task 11.2):** a scratch harness (deleted) applied each mutation, ran the named test files, restored, regenerated the PNGs and checked them byte-identical. Each turned a test red: `ink` at y 170 in the cornfield `near.png`, `wood` in the cornfield strip's row 0 and a transparent pixel at y 180 -> `test_pp_themes_chase_readability_band`; a strip cell that is not a tile -> `test_pp_themes_strip_is_built_from_the_tiles`; a layer clipped at the seam -> `test_pp_themes_seam_rows_match_and_features_cross`; `candy-yellow` in the haystack -> `test_pitchfork_panic_sheets_never_use_stamp_red_or_candy_yellow`; a haystack frame on row 45 -> `test_effects_stand_on_row_46` and `test_frames_not_empty_distinct_and_grounded`; `spooky_forest_bridge` dropped from the registry -> `test_shipped_registry_themes`, `test_pitchfork_panic_rules_do_not_change_with_the_setting`, `test_every_pitchfork_panic_setting_can_be_drawn`; `escape_cover_sheet` emptied in `cornfield_path.tscn` -> the forced-setting test, `test_new_pitchfork_settings_really_swap`, `test_shipped_registry_themes` and the rotation tests (an unexpected warning); one setting's chase config with `step_px` changed -> the forced-setting test. **The first `step_px` run was not caught**: `step_px` only scales pixels, so steps, brains and the ending were identical. The scripted chase now also records the mob's world x (`mob_steps * step_px`), and the rerun is red. An extra variant (a faster mob for one setting) is red too.

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created
- `EscapeBush` renamed `EscapeCover` (`git mv` with its uid; node `%EscapeCover`; `ESCAPE_COVER_AHEAD_PX`, `_vanish_into_cover`, `DEFAULT_SHEET_PATH`), proven by an unchanged suite before any other change. `EscapeCover` gains `use_sheet()` / `get_sheet()`; `SheetFrames` gains `from_texture()` (`build()` delegates, its warnings unchanged).
- New `ChaseBackdrop extends ParallaxBackdrop` with one export, `escape_cover_sheet`, and no behaviour. The Moonlit Village scene now uses it with the bush. `PitchforkPanicLevel._apply_escape_cover()` runs first in `_ready` (before the config check): a plain `ParallaxBackdrop` keeps the bush silently, a `ChaseBackdrop` with no sheet warns once and keeps it, and a wrong-size sheet warns once in `use_sheet()`. `LevelTheme` and `ParallaxBackdrop` are unchanged.
- New `tools/gen_chase_themes_art.gd` writes 12 PNGs (two settings x five files, two covers): deterministic, palette-only, hard alpha. It checks seams, the chase readability band, the path rows, the Halloween dressing and reserved colours, and exits non-zero on any failure. The covers are painted as fills and grown an ink outline. `gen_pitchfork_panic_art.gd` is untouched (its consts are read by `preload`).
- Two theme scenes (`cornfield_path.tscn`, `spooky_forest_bridge.tscn`, no static moon, as approved at Gate 1) and two registry entries (Moonlit first). Debug: `THEME_JUMP_LEVELS` gains `pitchfork_panic` (nine buttons wrap in the existing `HFlowContainer`); the art review lists both covers.
- Tests: the cover plumbing (6 cases), the Pitchfork settings' art rules (9), the cover sprite rules (EFFECT_SHEETS, colours, a new hide-the-zombie size test that the Moonlit bush also passes), the registry, a forced-setting RunFrame test (same passage, chase steps, mob world x, brains and caught ending; that setting's backdrop and cover), rotation and all-drawn, the real swap of both settings, the placeholder-chrome check, the overlay buttons and the art review pages.
- Gates: Gate 1 and Gate 2 answered "approved" (verbatim, dated in `## Art Approval`). No sound added, so no Audio gate.
- Not done exactly as written: the perf smoke used F6 after about 35 s / 20 s of typed run, not a full 5:00 per setting (recorded above and in `deferred-work.md`).

### File List

New:
- `scripts/levels/pitchfork_panic/chase_backdrop.gd` (+ `.uid`)
- `tools/gen_chase_themes_art.gd` (+ `.uid`)
- `assets/sprites/backdrops/cornfield_path/{clouds,far,near,ground_tiles,ground_strip}.png` (+ `.import`)
- `assets/sprites/backdrops/spooky_forest_bridge/{clouds,far,near,ground_tiles,ground_strip}.png` (+ `.import`)
- `assets/sprites/props/escape_haystack.png`, `escape_hollow_log.png` (+ `.import`)
- `scenes/levels/pitchfork_panic/themes/cornfield_path.tscn`, `spooky_forest_bridge.tscn`
- `tests/fixtures/levels/test_chase_backdrop.tscn`
- `_bmad-output/implementation-artifacts/screenshots/10-4/` (Gate 1 and Gate 2 captures)

Renamed:
- `scripts/levels/pitchfork_panic/escape_bush.gd` (+ `.uid`) -> `scripts/levels/pitchfork_panic/escape_cover.gd` (+ `.uid`)

Modified:
- `scripts/levels/pitchfork_panic/pitchfork_panic_level.gd`, `scripts/levels/pitchfork_panic/sheet_frames.gd`
- `scenes/levels/pitchfork_panic/pitchfork_panic_level.tscn`, `scenes/levels/pitchfork_panic/themes/moonlit_village.tscn`
- `data/levels/level_registry.tres`
- `scripts/debug/debug_overlay.gd`, `scripts/debug/art_review.gd`
- `tests/unit/test_pitchfork_panic_level.gd`, `test_level_themes.gd`, `test_art_backdrop.gd`, `test_art_sprites.gd`, `test_level_registry.gd`, `test_no_placeholder_chrome.gd`, `test_debug_overlay.gd`, `test_art_review.gd`; `tests/integration/test_run_frame.gd`
- `docs/art-style-sheet.md`
- `_bmad-output/implementation-artifacts/deferred-work.md`, `_bmad-output/implementation-artifacts/sprint-status.yaml`, this story file

### Change Log

- 2026-10-14: Story 10.4 implemented. Two new Pitchfork Panic settings (Cornfield Path, Spooky Forest Bridge) with per-setting escape covers (haystack, hollow log) carried by a new `ChaseBackdrop`; `EscapeBush` renamed `EscapeCover`. New art tool and 12 PNGs, two theme scenes, two registry entries, debug theme jumps and art-review entries, art/level/RunFrame tests (2144 -> 2165), style sheet and deferred-work updated. Gates 1 and 2 approved. Status -> review.

### Review Findings

Code review 2026-10-14 (Blind Hunter partial: read ~1560 of 2541 diff lines; Edge Case Hunter; Acceptance Auditor). Generator tool `tools/gen_chase_themes_art.gd` only grep-checked by the Auditor.

- [x] [Review][Defer] Perf smoke was ~35 s / ~20 s per setting, not a full 5:00 run (AC 2, NFR1) — deferred, reason: user accepts the disclosed deviation; full run deferred
- [x] [Review][Defer] `SheetFrames.from_texture` only rejects too-small sheets (oversized accepted) — deferred, reason: keep as a documented minimum (doc comment added as a patch below)
- [x] [Review][Patch] Document in `SheetFrames.from_texture` that the size check is a minimum, not exact [scripts/levels/pitchfork_panic/sheet_frames.gd:~21]
- [x] [Review][Patch] `EscapeCover._ready` loads the default sheet twice and `_sheet` can be null while a sprite shows; set `_sheet` from the texture `SheetFrames` used [scripts/levels/pitchfork_panic/escape_cover.gd:36]
- [x] [Review][Patch] `test_pitchfork_panic_rules_do_not_change_with_the_setting` asserts `assert_eq` on a shared cached `LevelConfig` Resource, which is trivially true (AC 6) [tests/integration/test_run_frame.gd]
- [x] [Review][Patch] `_scripted_chase_run` indexes `get_current_target()[get_cursor()]` with no bounds check; break when the cursor passes the passage end [tests/integration/test_run_frame.gd:~777]
- [x] [Review][Patch] No level-level test that a `ChaseBackdrop` with a too-small cover sheet warns once and keeps the bush through `_apply_escape_cover` (AC 4, Task 3.6) [tests/unit/test_pitchfork_panic_level.gd]
- [x] [Review][Patch] `test_a_chase_backdrop_brings_its_own_cover` asserts only `visible` and `get_sheet()` after stepping the outro, both true beforehand; assert the outro frame/atlas (Task 3.6) [tests/unit/test_pitchfork_panic_level.gd]
- [x] [Review][Patch] No guard that the forest ground rows 1-3 never contain a plank tile (Dev Notes ground rule) [tests/unit/test_art_backdrop.gd]
- [x] [Review][Patch] Stale "bush"/"static Moon"/"Moonlit Village ... ParallaxBackdrop" wording in test vars/messages and the `PitchforkPanicLevel` doc comment [tests/unit/test_pitchfork_panic_level.gd:582-589,685; scripts/levels/pitchfork_panic/pitchfork_panic_level.gd:50-55]
- [x] [Review][Defer] `ChaseBackdrop` in `pitchfork_panic/` extends `ParallaxBackdrop` from `zombie_run/` (cross-level script coupling) — deferred, design choice
- [x] [Review][Defer] Layer structure copy-pasted across three theme scenes (could use scene inheritance) — deferred, matches Moonlit shape
- [x] [Review][Defer] New theme scenes' texture `ext_resource` lines have no `uid=` (resolve by path; Godot rewrites on next editor save) — deferred
- [x] [Review][Defer] Cover is applied once in `_ready`; a later `apply_theme()` would not update it — deferred, no such caller today
