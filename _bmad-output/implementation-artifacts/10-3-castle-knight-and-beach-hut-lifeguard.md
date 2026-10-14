---
baseline_commit: bb5f9f8c1e94fd2fe4f2f54ce940f2556187874c
---

# Story 10.3: Castle + Knight and Beach Hut + Lifeguard

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a kid,
I want new houses and defenders in Horde Rush,
so that the siege stays surprising.

## Acceptance Criteria

1. **Two new Horde Rush themes ship (FR58, FR76).** `data/levels/level_registry.tres` gives `horde_rush` three themes, in this order: `farmhouse` (unchanged, stays first: it is the level scene's built-in look), `castle`, `beach_hut`. Each new theme is a `LevelTheme` with `id`, `backdrop` and `defender` set and `music_id` empty (every pair keeps `mus_horde_rush`). The ids are permanent once shipped (they go into players' saves). Zombie Run and Pitchfork Panic themes are untouched. With three themes, 10.1's `ThemePicker` picks one per run, never the previous one; no picker, RunFrame or save change is needed.
2. **Each pair has its house and lane backdrop.** `scenes/levels/horde_rush/themes/castle.tscn` and `beach_hut.tscn` have the `farmhouse.tscn` layout: root `Field` (Node2D, no script), `FieldArt` (Sprite2D at (0, 0), `centered = false`) and `House` (Sprite2D at (548, 0), `centered = false`). Textures in `assets/sprites/backdrops/castle/` (`field.png` 640×256, `castle.png` 92×256) and `assets/sprites/backdrops/beach_hut/` (`field.png`, `beach_hut.png`, same sizes). Same layout as the Farmhouse: sky band y 0-36, five 44 px lanes, one doorway per lane whose bottom row is that lane's soles row (feet line − 1: y 73, 117, 161, 205, 249), the roof/top under the pause button.
3. **Each pair has its defender with pacing and throw animations.** `scenes/levels/horde_rush/knight.tscn` and `lifeguard.tscn` have the `farmer.tscn` structure: root Node2D with the shared defender sprite script (AC 6), `Body` AnimatedSprite2D at (−16, −31), `centered = false`, animations `idle` (2 f, 8 fps, loop), `walk` (4 f, 10 fps, loop), `throw` (3 f, 12 fps, once: wind-up, release, follow-through), autoplay `idle`. Sheets 32×32 frames, soles on row 30, facing left: `assets/sprites/characters/knight/knight_{idle,walk,throw}.png`, `assets/sprites/characters/lifeguard/lifeguard_{idle,walk,throw}.png`.
4. **Each pair has its projectile and its hit effect.** Knight: a suction-cup dart (`assets/sprites/props/dart_fly.png`, 2 f 16×16, 10 fps loop; `scenes/levels/horde_rush/dart.tscn`) and its hit (`dart_hit.png`, 3 f 16×16, 12 fps once; `dart_hit.tscn`). Lifeguard: a water balloon (`water_balloon_fly.png`, `water_balloon.tscn`) and its splash (`water_balloon_splash.png`, `water_balloon_splash.tscn`). Projectile scenes copy `tomato.tscn` (root Node2D, `%Sprite` AnimatedSprite2D `fly`, centred, autoplay); hit scenes copy `tomato_splat.tscn` (the shared hit-effect script, `%Sprite` with 3 frames, no autoplay). Every hit (non-final and final) spawns the pair's own hit effect; a miss spawns none (unchanged rule).
5. **Each pair has its own throw and hit sounds.** Four new generated sounds in `tools/gen_audio.gd`: `sfx_dart_throw`, `sfx_dart_hit`, `sfx_balloon_throw`, `sfx_balloon_hit` (16-bit mono WAV in `assets/audio/sfx/`, fixed seeds, normalized to `FILE_PEAK`, zero start/end, no leading silence), registered in `data/audio/audio_library.tres` with `volume_db` and `min_interval_s` like the tomato pair, listed in `assets/audio/CREDITS.md`. The spawn (`sfx_zombie_spawn`) and the melt (`sfx_melt`) stay pair-independent. Rerunning the tool leaves every existing audio file byte-identical.
6. **The pair travels with the defender scene; two shared scripts renamed.** `HordeFarmer` becomes `HordeDefenderSprite` (`scripts/levels/horde_rush/defender_sprite.gd`, `git mv` with its `.uid`) and gains four exports: `projectile_scene: PackedScene`, `hit_scene: PackedScene`, `throw_sfx: StringName`, `hit_sfx: StringName`. `HordeTomatoSplat` becomes `HordeHitEffect` (`scripts/levels/horde_rush/hit_effect.gd`, same). Behaviour of both is byte-for-byte the same apart from the name, the doc and the warning wording. `farmer.tscn` sets its four exports to the tomato, the splat and the tomato sounds. `horde_rush_level.gd` reads the four from its `%Defender` once in `_ready`; when `%Defender` is not a `HordeDefenderSprite` or an export is empty, it uses the current tomato constants (no warning for a non-sprite defender, so 10.1's plain-Node2D fixture test stays at zero warnings; one warning per empty export on a real sprite). `LevelTheme` gets **no** new property (its property-list test passes unchanged).
7. **Same defender tuning (FR56, FR76).** No change to `data/levels/horde_rush.tres`, `HordeDefender`, `HordeField`, `HordeMarcher`, `HordeProjectile`, `DEFENDER_X`, `TOMATO_RISE_PX`, the lane layout or the step order. Tested: one RunFrame start per theme (payload `"theme"` forced, same seed, scripted words through the session and fixed `_process` steps) gives identical targets, `LevelConfig`, thrown/hit/miss/stopped/arrived counts and arrival brains; zero warnings and errors; `%Field` and `%Defender` are that theme's scenes.
8. **No guns, kid-safe (FR58, NFR10).** Both throws are by hand: the Knight throws a toy suction-cup dart overarm (no blaster, no bow, no crossbow, no sword, no spear, no lance); the Lifeguard lobs a water balloon (no water gun, no hose nozzle). The dart is visibly a toy (big rubber cup leading, no point) and its hit never sticks into or pierces a copy. Nothing scary: no skulls, no blood (`stamp-red` reserved, D16), defeat is the existing melt. No letters, numbers or text-like marks anywhere (no heraldic letters, no lifeguard cross or "+", no sign text).
9. **They follow the style sheet (NFR13).** Code-authored by a new tool (never a hand-edited PNG), maps and shapes at fixed positions (no RNG: a rerun writes the same bytes); hard alpha, palette only; characters and props have the ink outline; backdrops are outline-exempt; Lossless, no mipmaps. *Tested:* sizes and frame counts; no `candy-yellow`, `stamp-red` or `art-moon` in any new file; no `zombie-green`/`zombie-green-bright` in the lanes (x 0-547, y 36-255) or the house's first 8 px below y 36; each field fully opaque; a doorway per lane on the soles row (the existing doorway test, per house); defender skin human (`art-skin-light`/`art-skin-dark` only, no zombie greens, no `bat-purple`, only legend colours); projectiles small (dart ≤ 12 px wide and ≤ 6 px tall, balloon ≤ 8 px wide) per frame.
10. **A pair is easy to see on demand (debug only).** The F3 overlay gets one jump button per Horde Rush theme (payload `{"level_id": &"horde_rush", "theme": <id>}`), built from the registry the same way as 10.2's Zombie Run theme buttons (if 10.2 is done, extend its builder; if not, build it here for every real level with 2+ themes). Never visible in a release build. The debug art review screen (`scripts/debug/art_review.gd`) lists every new sheet.
11. **Approval gates.** Gate 1 (every new sheet and both backdrops at 1× and 3× plus grayscale, before wiring), Gate 2 (in game on the real RunFrame) and the Audio gate (a listen) are approved by Smuck; each answer verbatim with the date in `## Art Approval` / `## Audio Approval`. The readability and listen checklists are filled in pass/fail per pair.
12. **No regressions.** Full GUT suite green; the count only goes up; zero `Parse Error|Compile Error|Failed to load script`; `SCRIPT ERROR` / `WARNING` counts unchanged except deliberate, asserted ones. All existing PNGs and WAVs byte-identical (`git status` shows no modified `.png` or `.wav`). The real `user://save.json` is untouched by the test run and the captures (sha256 before/after).

## Tasks / Subtasks

- [x] **Task 1: Baseline** (AC: 12)
  - [x] 1.1 Check `sprint-status.yaml`: is 10.2 `done`? It changes the registry (`load_steps`, ext ids 17/18), the F3 overlay (theme buttons), `test_level_registry.gd::test_shipped_registry_themes`, `test_run_frame.gd::test_shipped_levels_start_in_their_theme` and `deferred-work.md`. Read the current files, never the numbers in this story, before editing them.
  - [x] 1.2 `git status` clean. `"/c/Program Files/Godot/Godot.exe" --headless --path . --import`, then `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`. Record the count, `SCRIPT ERROR` and `WARNING` line counts (10.1 ended at 2106 / 3 / 167 before its review patches; 10.2 adds more; the recount is authoritative); grep for `Parse Error|Compile Error|Failed to load script`.
  - [x] 1.3 sha256 of the real save (`%APPDATA%/Godot/app_userdata/<project>/save.json`).

- [x] **Task 2: Renames, no behaviour change** (AC: 6) — do first, run the suite before any art
  - [x] 2.1 `git mv scripts/levels/horde_rush/farmer.gd scripts/levels/horde_rush/defender_sprite.gd` (+ `.gd.uid`); `class_name HordeDefenderSprite`. Doc: one shared sprite for every Horde Rush defender (Farmer 6.6, Knight and Lifeguard 10.3); keep the rest. Warning texts: `"farmer has no ..."` → `"defender has no ..."` (update any test that asserts them).
  - [x] 2.2 `git mv scripts/levels/horde_rush/tomato_splat.gd scripts/levels/horde_rush/hit_effect.gd` (+ `.uid`); `class_name HordeHitEffect`; doc generalised (a projectile's hit effect: tomato splat, dart hit, water splash; 3 frames at 12 fps, stepped by the tween). Warning `"tomato splat has no sprite frames"` → `"hit effect has no sprite frames"`.
  - [x] 2.3 Update the script paths in `farmer.tscn` and `tomato_splat.tscn`; references in `horde_rush_level.gd` (`HordeFarmer` type of `_farmer`, the docs), `level_theme.gd` doc, tests (`test_horde_farmer.gd` → `git mv` to `test_horde_defender_sprite.gd` + `.uid`; `test_horde_rush_level.gd` `_farmer()` / `HordeFarmer.ANIM_*` / `_splats()` / `HordeTomatoSplat.*`; `test_level_themes.gd`), `docs/art-style-sheet.md`. Rename the level's `_farmer` var to `_defender_sprite`; keep the test helper names if you like, but no `HordeFarmer`/`HordeTomatoSplat` left: grep the repo (excluding `_bmad-output/` and `.godot/`) for `HordeFarmer|HordeTomatoSplat|farmer\.gd|tomato_splat\.gd` → zero hits.
  - [x] 2.4 Keep level-internal names that tests use (`TOMATO_SCENE`, `TOMATO_SPLAT_SCENE`, `SFX_THROW`, `SFX_HIT`, `TOMATO_RISE_PX`, `_tomato_position`, `get_projectile_view`); they become the built-in pair's fallbacks. `--import` (class cache), full suite: same count, all green.

- [x] **Task 3: The pair travels with the defender** (AC: 6)
  - [x] 3.1 `defender_sprite.gd`: `@export var projectile_scene: PackedScene`, `@export var hit_scene: PackedScene`, `@export var throw_sfx: StringName = &""`, `@export var hit_sfx: StringName = &""`, each with a doc line. No logic uses them inside the sprite.
  - [x] 3.2 `farmer.tscn`: set the four to `tomato.tscn`, `tomato_splat.tscn`, `&"sfx_tomato_throw"`, `&"sfx_tomato_hit"` (ext_resources, `load_steps` += 2).
  - [x] 3.3 `horde_rush_level.gd`: in `_ready` (after the theme swap has happened, since `_ready` runs after `apply_theme`), resolve `_projectile_scene`, `_hit_scene`, `_throw_sfx`, `_hit_sfx` from `_defender_sprite`, falling back to `TOMATO_SCENE`, `TOMATO_SPLAT_SCENE`, `SFX_THROW`, `SFX_HIT`. A `HordeDefenderSprite` with an empty export warns once per empty export (NFR16) and uses the fallback; a non-sprite defender (10.1's plain `Node2D`) uses the fallbacks silently. `_add_projectile_view`, `_spawn_splat`, the throw/hit `_play_sfx` calls use the resolved values; the error messages name the scene generically ("projectile scene root is not a Node2D"). Docs: replace the "Still to come: Castle + Knight..." line and the 6.6 sound note.
  - [x] 3.4 Tests in `test_horde_rush_level.gd`: the Farmhouse level (unchanged scene) still emits `SFX_THROW`/`SFX_HIT` and spawns `tomato.tscn`/`tomato_splat.tscn` instances (assert `scene_file_path`); a level whose `%Defender` is a `HordeDefenderSprite` with fixture exports (e.g. instance `farmer.tscn`, set `projectile_scene`/`hit_scene`/sfx to other values before `add_child`) uses them; one with an empty `projectile_scene` warns once (`assert_push_warning`) and throws tomatoes. Every existing test passes unchanged.

- [x] **Task 4: Art tool** (AC: 2, 3, 4, 8, 9) — new `tools/gen_horde_rush_pairs_art.gd`
  - [x] 4.1 `extends SceneTree`, header doc like `gen_horde_rush_art.gd`'s (what it writes, the run line, the rules). `const Proto := preload("res://tools/gen_art_prototypes.gd")` (palette); `const Farm := preload("res://tools/gen_horde_rush_art.gd")` to reuse **consts** only (layout `SKY_H`, `LANE_H`, `LANE_COUNT`, `FEET_INSET`, `HOUSE_W`, `FIELD_W/H`, `DOOR_W/H`, and the Farmer leg maps if their legend characters fit). Copy the helpers (`_sheet_image`, `_put`, `_rect`, `_box`, `_blob`, `_feet_y`, `_save`, `_color`): **never edit `gen_horde_rush_art.gd`** (its PNGs must stay byte-identical; 8.6/10.2 precedent).
  - [x] 4.2 `_init`: write all 14 PNGs (6 defender sheets, 4 prop sheets, 4 backdrop layers; see "Expected new asset files"), non-zero exit on any bad map, legend, path, or a reserved colour in any legend or shape (`candy-yellow`, `stamp-red`, `art-moon`).
  - [x] 4.3 Draw both pairs (compositions and colour rules in Dev Notes). Run: `"/c/Program Files/Godot/Godot.exe" --headless --path . -s tools/gen_horde_rush_pairs_art.gd`, then `--import`. Rerun once: `git status` shows no change. Commit PNGs with their `.import` (Lossless `compress/mode=0`, no mipmaps, no per-file filter).

- [x] **Task 5: Art tests** (AC: 9)
  - [x] 5.1 `tests/unit/test_art_backdrop.gd`: turn the Farmhouse checks into helpers taking a dir, a house file name and the house's wall colours (`_farmhouse_*` tests keep calling them with today's values and pass unchanged), and run them for `castle/` (`castle.png`) and `beach_hut/` (`beach_hut.png`): sizes, `_alpha_palette_problems`, reserved colours (+ `art-moon`), no zombie greens in lanes and the house front, field opaque, a doorway per lane (`DOOR_COLUMNS`, `DOOR_MIN_H`, each house's own `WALL_COLOURS`), `_assert_pixel_crisp_import`. Header doc: a Story 10.3 paragraph.
  - [x] 5.2 `tests/unit/test_art_sprites.gd`: add the new sheets to `SHEETS` / `PROP_SHEETS` (frame counts), a `HORDE_RUSH_PAIR_SHEETS` list for the stamp-red/candy-yellow/art-moon check, `test_knight_skin_is_human` and `test_lifeguard_skin_is_human` (the Farmer rule with each legend's colour list), `test_dart_is_small` (≤ 12 × 6 per frame) and `test_water_balloon_is_small` (≤ 8 wide), plus the existing per-sheet generic checks (outline, hard alpha, palette, soles row 30 for the characters, import settings). Every existing test passes unchanged.
  - [x] 5.3 Run the two files (`-gdir=res://tests/unit -gselect=test_art_`). Fix the art in the tool, never the rule (a gate may relax a rule: record why).

- [x] **Task 6: Gate 1 — sheet and backdrop review** (AC: 11) — before wiring
  - [x] 6.1 Scratch compositions (scripts in `tools/_scratch_10_3/`, deleted after use): each field + house at 1× with the defender in lanes 0, 2 and 4, a projectile in flight in two lanes, a hit effect on a copy, small/medium/brute copies (the brute with the Pumpkin hat) at the left edge, mid-field and at a door; every sheet as a strip at 3×; a grayscale copy (`"/c/Program Files/Godot/Godot.exe" --headless --path . -s tools/capture_screens.gd -- --convert <png>`). Save to `_bmad-output/implementation-artifacts/screenshots/10-3/gate1-<pair>-*.png`.
  - [x] 6.2 Show Smuck; record the verbatim answer with the date in `## Art Approval`. Don't wire anything before Gate 1 passes; redraw in the tool, regenerate, re-show.

- [x] **Task 7: Scenes and registry** (AC: 1, 2, 3, 4)
  - [x] 7.1 Props: `dart.tscn`, `water_balloon.tscn` (copy `tomato.tscn`, swap the texture, root names `Dart` / `WaterBalloon`); `dart_hit.tscn`, `water_balloon_splash.tscn` (copy `tomato_splat.tscn`, the `hit_effect.gd` script, animation name kept as in the copy).
  - [x] 7.2 Defenders: `knight.tscn`, `lifeguard.tscn` (copy `farmer.tscn`: same frames/fps/loop, root names `Knight` / `Lifeguard`, the four pair exports set to their own props and sounds).
  - [x] 7.3 Themes: `scenes/levels/horde_rush/themes/castle.tscn`, `beach_hut.tscn` (copy `farmhouse.tscn`; child `House` instead of `Farmhouse`). Keep `format=3`, correct `load_steps`, unique ext ids; let `--import` write uids; commit what it writes.
  - [x] 7.4 `data/levels/level_registry.tres`: four `PackedScene` ext_resources (two themes, two defenders), two `LevelTheme` sub-resources (`Resource_theme_castle`, `Resource_theme_beach_hut`: `script`, `id`, `backdrop`, `defender`), `horde_rush`'s `themes = Array[ExtResource("12_theme")]([SubResource("Resource_theme_farmhouse"), SubResource("Resource_theme_castle"), SubResource("Resource_theme_beach_hut")])`, `load_steps` += 6. Use the next free ext ids **in the file as it is** (17+ today; 19+ if 10.2 added 17/18). Farmhouse stays first.
  - [x] 7.5 Do **not** touch `horde_rush_level.tscn` (its built-in `%Field` and `%Defender` stay the Farmhouse pair, so `themes[0]` is the no-op), `horde_rush.tres`, or any other entry.

- [x] **Task 8: Sounds** (AC: 5)
  - [x] 8.1 `tools/gen_audio.gd`: four functions after `_melt()` with doc lines (length, recipe), each with its own fixed seed where noise is used; four `_save_sfx` lines appended at the end of the `errors` list (append, so earlier RNG streams never shift); a header line "Story 10.3 adds ...". Suggested recipes in Dev Notes.
  - [x] 8.2 Run: `"/c/Program Files/Godot/Godot.exe" --headless --path . -s tools/gen_audio.gd -- --music-dir=<scratch dir>` then `--import`. `git status`: only the four new WAVs (+ `.import`) appear; every existing WAV unchanged (if one changed, the tool change is wrong). Do not re-encode any OGG.
  - [x] 8.3 `data/audio/audio_library.tres`: four `AudioCue` sub-resources + ext_resources, added to the cue list exactly like `Resource_throw`/`Resource_hit` (start with the tomato pair's `volume_db` −11/−9 and `min_interval_s` 0.08/0.06). `assets/audio/CREDITS.md`: four rows. `tests/unit/test_audio_library.gd`: add the ids to the lists that enumerate SFX (l.~128 and ~262) so the existing per-file rules (format, peak, zero edges) cover them.

- [x] **Task 9: Tests for the shipped pairs** (AC: 1, 6, 7)
  - [x] 9.1 `tests/unit/test_level_registry.gd::test_shipped_registry_themes`: Horde Rush ships `farmhouse`, `castle`, `beach_hut` in order, each with a backdrop and a defender (paths asserted), empty `music_id`; the other levels as they are; `validate() == ""`.
  - [x] 9.2 `tests/integration/test_run_frame.gd::test_shipped_levels_start_in_their_theme`: `horde_rush`'s theme is now drawn among three; assert membership (and equal to `get_level().theme_id` and the saved last theme). Keep exact assertions for single-theme levels.
  - [x] 9.3 New RunFrame cases (same file; injected temp `PlayerData`, never the autoload): (a) **AC 7**: seed 42, `"theme"` forced to each of the three ids; feed the same scripted words through the frame's session and step `_process` a fixed number of times → identical `_targets()`, `get_level_config()`, defender thrown/hit/miss counts, field stopped/arrived counts and `get_brains_earned()`; `%Field.scene_file_path` and `%Defender.scene_file_path` are that theme's; zero warnings/errors. (b) Rotation: five consecutive Horde Rush starts on one temp PlayerData, different seeds → no two consecutive ids equal. (c) Seeds 1..60 with last = `&""` → all three appear.
  - [x] 9.4 `tests/unit/test_level_themes.gd`: the Horde Rush scene with `castle` and with `beach_hut` applied: `%Field` and `%Defender` swapped (scene paths), `%Defender` under `%Zombies` at the old index and position, `get_defender_view()` is a `HordeDefenderSprite`; after one throw the projectile view's `scene_file_path` is the pair's projectile, the sfx recorder got the pair's throw id; after a hit the `%Effects` child is the pair's hit scene; zero warnings. `test_each_shipped_theme_is_a_no_op` keeps using `themes[0]` and passes unchanged.
  - [x] 9.5 `tests/unit/test_horde_defender_sprite.gd`: the animation test (frames, fps, loop) runs for `farmer.tscn`, `knight.tscn` and `lifeguard.tscn`; each has all four pair exports set and pointing at existing resources/known audio ids. `tests/unit/test_no_placeholder_chrome.gd`: add the new prop, defender and theme scenes to its explicit "no ColorRect" lists if it keeps them (it already walks both folders).

- [x] **Task 10: Debug jumps and art review** (AC: 10)
  - [x] 10.1 `scripts/debug/debug_overlay.gd` (+ scene): Horde Rush theme jump buttons (see AC 10); lazy `load` of the registry, never `preload`; each wired with `_jump.bind(Router.Screen.RUN, {"level_id": &"horde_rush", "theme": theme.id})`; label = theme id; `_refresh_jumps()` treats them like the others. `tests/unit/test_debug_overlay.gd`: three buttons with the right payloads (existing jump-test pattern; never navigate the live Router).
  - [x] 10.2 `scripts/debug/art_review.gd`: add the 10 new sheets (knight/lifeguard idle, walk, throw; dart fly/hit; balloon fly/splash) with their fps; update `tests/unit/test_art_review.gd`'s expected list and page assertions.

- [x] **Task 11: Gate 2, Audio gate, checklists, smoke** (AC: 8, 11, 12)
  - [x] 11.1 In-game captures on the real `RunFrame` per new pair (scratch capture scene under `tools/_scratch_10_3/`, forced theme, fixed seed, temp `SaveService` dir — **never the real save**, sha256 before/after): `gate2-<pair>-start.png` (idle defender), `-mid.png` (6+ copies of all three sizes, a projectile in flight, a hit effect, a melt), `-door.png` (a copy shuffling into a door), `-end.png` (the dance), plus a 3× crop of the defender mid-throw and a grayscale of `-mid`. Save to `screenshots/10-3/`; commit the `.import` files Godot writes for them (8.7 lesson).
  - [x] 11.2 Fill in the **Horde Rush pair readability checklist** per pair (Dev Notes) in Debug Log References.
  - [x] 11.3 Show Smuck; record the verbatim Gate 2 answer with the date in `## Art Approval`. Tell Smuck how to reach each pair: F3 → the theme jump buttons (from the menu card the pair is random).
  - [x] 11.4 Audio gate: Smuck plays each pair with sound (web debug build via the `web-debug` launch config, its `user://` is browser storage); fill in the **pair listen checklist**; record the verbatim answer with the date in `## Audio Approval`. Adjust only `volume_db`/`min_interval_s` or regenerate the new sounds in the tool.
  - [x] 11.5 Perf smoke (same web build): a full Horde Rush run per new pair with the F4 stress hold; worst frame under 33 ms (NFR1, F3 overlay); console clean.

- [x] **Task 12: Wrap-up** (AC: 12)
  - [x] 12.1 Full suite as in Task 1; record count, `SCRIPT ERROR` / `WARNING` deltas (explain each), zero parse/compile errors; real save sha256 unchanged; `git status` shows no modified existing `.png` or `.wav`.
  - [x] 12.2 Mutation pass (each must turn a test red): `stamp-red` in the dart's cup; zombie-green in a castle lane; a beach hut doorway moved 1 px up; a knight sheet pixel in `zombie-green`; a 14 px dart frame; drop `beach_hut` from the registry; empty `projectile_scene` in `knight.tscn` without the fallback warning; the forced-theme RunFrame test with one theme's `horde_rush.tres` duplicated and `defender_throw_cooldown_s` changed. (Edit, run, restore.)
  - [x] 12.3 `docs/art-style-sheet.md`: section 1 (Epic 10 Horde Rush pairs done in 10.3), the animation table rows (knight/lifeguard idle/walk/throw, dart/balloon fly and hit), section 3 (a Castle and Beach Hut paragraph: folders, layout, the no-weapon rule, *tested*), "How sprites are made" (the new tool), the `HordeDefenderSprite`/`HordeHitEffect` names.
  - [x] 12.4 `deferred-work.md`: under the 10-1 dev section append "Resolved in 10.3: Horde Rush projectile and SFX per pair (on the defender scene, not `LevelTheme`); non-Farmer defenders animate (`HordeDefenderSprite`)" (never delete history). New "Deferred from: dev of story 10-3" (at least: the copy flash stays pumpkin for every pair; the Horde Rush level card still shows the Farmhouse; per-pair music not used; the registry now eagerly loads three Horde Rush pairs; `HordeHitEffect` fixes 3 frames for every pair; anything accepted at a gate).
  - [x] 12.5 Dev Agent Record, File List, Change Log; `sprint-status.yaml` → `review`.

### Review Findings

- [x] [Review][Patch] (resolved from decision: rename now) Remaining tomato-named internals now hold arbitrary pairs (fixed: level locals, `_projectile_position`, `PROJECTILE_RISE_PX`, `_spawn_hit_effect`, test helper `_defender()`; the `splat` animation/node names in the hit scenes stay, already noted in deferred-work) — `tomato`/`splat` locals, `_tomato_position`, `TOMATO_RISE_PX`, `_spawn_splat` in the level; `splat` animation and `AtlasTexture_splat_*` in hit scenes; `_farmer()` test helper. [scripts/levels/horde_rush/horde_rush_level.gd:1042]
- [x] [Review][Patch] Water balloon test bounds width only (≤8), not height; a tall frame passes [tests/unit/test_art_sprites.gd:980]
- [x] [Review][Patch] `test_new_horde_rush_pairs_really_swap` runs on the shipped, un-pinned config (throw delay, flight time); a retune fails it though pair logic is fine. Use `_pinned_config` like the other pair tests [tests/unit/test_level_themes.gd:190]
- [x] [Review][Patch] `_with_defender` fixture: `replace_by` moves the old Farmer's children onto the replacement (duplicate `Body`; plain `Node2D` gets the Farmer's `Body`). Free the transferred children [tests/unit/test_horde_rush_level.gd:1256]
- [x] [Review][Defer] `THEME_JUMP_LEVELS` is hard-coded, so a future themed level needs a manual edit; button names `JumpTheme_<id>` are unique only while theme ids are unique across levels [scripts/debug/debug_overlay.gd:64] — deferred, matches spec ("same way as 10.2"); revisit when a third themed level lands
- [x] [Review][Defer] Pixel-level art rules (cup/point/no weapon/no letter marks) and the lane-floor-not-wood rule have no automated guard, only Gate 1/2 approval [tests/unit/test_art_backdrop.gd] — deferred, matches Farmhouse precedent


## Dev Notes

### What this story is (and isn't)

- **Is:** two new Horde Rush house + defender pairs (art tool, 14 PNGs, 2 theme scenes, 2 defender scenes, 4 prop scenes, 2 registry entries), four new sounds, the per-pair projectile/hit/sound plumbing on the defender scene, two class renames, art/audio tests, debug jumps, three gates.
- **Isn't:** any theme plumbing change (10.1 did it: `LevelTheme`, `ThemePicker`, `last_themes`, `_swap_slot` work as is), Zombie Run (10.2), Pitchfork Panic (10.4), trends (10.5), new music, a new copy flash colour, the level card, Horde Rush tuning. If you find yourself editing `run_frame.gd`, `level_base.gd`, `theme_picker.gd`, `level_theme.gd` (other than its doc), `save_schema.gd`, `player_data.gd`, `horde_rush.tres`, `horde_defender.gd`, `horde_field.gd`, `horde_marcher.gd`, `horde_projectile.gd`, `player_zombie.*` or `gen_horde_rush_art.gd`, stop: out of scope.

### Design decisions made for this story (follow them; record any change and why)

- **The projectile, hit effect and sounds live on the defender scene, not on `LevelTheme`.** 10.1's notes expected `LevelTheme` to grow projectile/SFX fields. Putting them on `HordeDefenderSprite` instead keeps each pair whole in one scene (a Lifeguard can never be registered with tomatoes by mistake), keeps `LevelTheme` level-agnostic (its pinned 4-property list stays true for every level), needs no new registry validation, and keeps the 10.1 fallback behaviour (a plain-Node2D defender throws tomatoes). Record it in `deferred-work.md` as the resolution of the 10.1 deferral.
- **Rename `HordeFarmer` → `HordeDefenderSprite`, `HordeTomatoSplat` → `HordeHitEffect`.** Knight and Lifeguard scenes use these scripts; a Knight typed as `HordeFarmer` is misleading (10.2 renamed `SunnyVillageBackdrop` for the same reason). Level-internal names (`TOMATO_*`, `_tomato_position`, `SFX_THROW/HIT`) stay: they are the built-in pair's fallback, and renaming them only churns tests.
- **Theme ids `castle` and `beach_hut`** (the house, like `farmhouse`). Folders: `backdrops/castle/`, `backdrops/beach_hut/`, `characters/knight/`, `characters/lifeguard/`.
- **Same tuning, same geometry.** `DEFENDER_X` 520, the throw height `TOMATO_RISE_PX` 14, the 5 × 44 px lanes, `HOUSE_FRONT_X` 548 are layout constants of the level, shared by every pair. Each new house draws its doorways on the same feet lines and its throw frame's hand at chest height (≈ y −14 from the feet, in front of the body).
- **The copy flash and melt stay pair-independent** (pumpkin flash, green puddle; `PlayerZombie` sheets). A pumpkin "splatted" flash after a water balloon is slightly off; accepted and deferred (a per-pair flash means new zombie sheets for every pose; not worth it).
- **New tool, old tool untouched** (8.6/10.2 precedent): `gen_horde_rush_art.gd`'s PNGs must stay byte-identical. Reading its consts via `preload` is fine; editing it is not.
- **Hit effects keep 3 frames at 12 fps** (`HordeHitEffect.FRAMES`/`FPS` are consts). Draw each pair's hit in 3 frames.

### Layout facts (horde_rush_level.gd; unchanged)

- Sky band y 0-36; lanes from 36, 44 px each, to y 256 (HUD band below). Feet lines **74, 118, 162, 206, 250**; soles rows 73, 117, 161, 205, 249.
- House at x 548 (92 px wide, 256 tall), copies arrive at feet x `548 − 16·scale` and shuffle 8 px into the door. The pause button covers x ≥ 600, y ≤ 40 (over the roof/top). Arrival pops clamp at y 32.
- Defender feet at x 520, y = the continuous lane feet line; projectiles fly at feet − 14 from x ≈ 532 leftward; `%Projectiles` and `%Effects` draw above the y-sorted `%Zombies`.

### Colour rules (most *tested*)

| Rule | Where | Why |
|---|---|---|
| no `candy-yellow`, `stamp-red`, `art-moon` | every new file | focus / stamp (D16: never blood) / moon reserved |
| no `zombie-green`, `zombie-green-bright` | lanes x 0-547, y 36-255; house x 0-7 below y 36 | copies must not camouflage |
| skin only `art-skin-light`/`art-skin-dark`; no zombie greens, no `bat-purple` | defenders | a defender never reads as a zombie or a villager-zombie |
| lane floor not `wood`/`wood-dark` | lanes | the zombie's trousers and shoes would sink in (6.6 lesson) |
| palette only, alpha 0 or 255; ink outline on characters and props | every file | NFR13 |

### Suggested compositions (Gate 1 decides; keep the Farmhouse shape style: rects, boxes, blobs, ink edges)

**Castle + Knight** (`castle`): a friendly toy-castle siege.
- `field.png`: `art-sky` band with `art-sky-light` clouds and distant `stone-light` towers with `pumpkin`/`bat-purple` pennant flags (no emblems) on an `art-grass` horizon. Lanes: jousting lists of `parchment-shade` packed sand with `wood-light` rake lines (different pattern from the farm furrows), separated by 8 px low `wood-light` jousting fences with `wood` posts and small alternating `pumpkin`/`bat-purple` pennant triangles on the rails (pennants are fine in lanes: not green).
- `castle.png`: `stone-light` block wall with `stone` mortar joints in a running bond, an ink edge on the field side; crenellations (merlons) along the top under the pause button with a `bat-purple` banner hanging between; per lane an arched gateway (`night` opening, `dusk` floor rows, a raised `wood` portcullis band with `wood-dark` bars at the arch top — never closed over the opening) whose bottom row is the soles row, a `stone` step. Wall colours for the doorway test: the block fill, the mortar and the ink edge.
- **Knight** (faces left): a round `stone-light` helmet with the visor **up** showing a smiling human face, a `pumpkin` plume, `stone-light`/`stone` armour with `ink-muted` joints, an `art-sky` tabard (plain or a pumpkin picture, no letters), `wood-dark` boots. Reuse the Farmer's leg rhythm (stand / walk A / pass A / walk B / pass B) for the same gait. **No sword, shield, lance or scabbard.** Throw: frame 1 the dart drawn back over the shoulder, frame 2 the arm forward at chest height (the hand near x +12, y −14 from the feet), frame 3 follow-through low.
- **Dart** (`dart_fly`, 2 f): a horizontal toy dart ≤ 12 × 6 px, the big `pumpkin-light` rubber cup with an `pumpkin` rim on the **left** (leading), a `chalk`/`stone-light` shaft, `art-sky` fletching on the right; frame 2 a slight wobble (fletching up 1 px). No point anywhere.
- **Dart hit** (`dart_hit`, 3 f): 1 the cup squashed flat against the copy with short `chalk` impact lines; 2 the dart springing off (tilted) with a "boing" squiggle; 3 a tiny `chalk` star puff. It never shows a hole or anything stuck in the copy.

**Beach Hut + Lifeguard** (`beach_hut`): a sunny beach day.
- `field.png`: `art-sky` band with a `pumpkin-light` sun disc (not candy-yellow, not art-moon) high and away from the top-right pause corner; the sea along the bottom of the band (`art-sky`/`art-sky-light` wave rows with `chalk` foam caps above y 36 only). Lanes: sand (`parchment` or `parchment-shade` with `wood-light` ripple dashes, a pattern different from both other fields), separated by 8 px strips of beach things at fixed positions: striped towels (`bat-purple`/`chalk`, `art-sky`/`chalk`), little sandcastles (`parchment-shade`), small shells (`chalk`/`pumpkin-light`) and a beach ball (`pumpkin`/`chalk`/`art-sky` segments). Keep the middle rows of every lane calm (6.6 rule).
- `beach_hut.png`: vertical `chalk`/`art-sky-light` (or `art-sky`) painted planks with `wood` seams, an ink edge; a `bat-purple` or `pumpkin` peaked roof and eave under the pause button; per lane a doorway (`night` opening, `dusk` floor, an `art-sky` door leaf swung open, a `wood-light` step). One small Halloween touch is welcome (a carved pumpkin on a step) but optional. Avoid a plain ring buoy (it can read as an "O"): if used, give it rope and 4 stripes so it reads as an object. Wall colours for the doorway test: the plank colours, the seam and the ink edge.
- **Lifeguard** (faces left): a sun hat or visor, `chalk` zinc stripe on the nose, a whistle on a cord (`stone`), a `pumpkin` swimsuit or tank top with `art-sky` shorts — **not** stamp-red, and **no cross or "+" symbol**. Use `art-skin-dark` as the main skin with `art-skin-light` highlights for a different look from the Farmer (the skin test allows exactly these two). Throw: an underarm lob — frame 1 the balloon held low behind, frame 2 the arm swinging up and forward at chest height, frame 3 follow-through high.
- **Water balloon** (`water_balloon_fly`, 2 f): ≤ 8 px wide, `art-sky` with an `art-sky-light`/`chalk` highlight, a tiny knot; frame 2 squished 1 px (wobble).
- **Splash** (`water_balloon_splash`, 3 f): 1 the balloon flattening with a burst ring; 2 a wide splash of `art-sky-light`/`art-sky` droplets with `chalk` highlights; 3 a few drops falling. Clearly water.

### Sound recipes (suggested; Audio gate decides)

- `sfx_dart_throw` (~120 ms): a light "fwip": band-passed noise sweeping up 1.5 → 4 kHz with a fast decay (fixed seed).
- `sfx_dart_hit` (~200 ms): a rubbery suction "thwop/plook": a sine pop falling 600 → 180 Hz with a short wobble (a "boing" tail, 2-3 cycles of 12 Hz vibrato), no noise burst (so it differs from the tomato splut).
- `sfx_balloon_throw` (~180 ms): a soft "whuh" lob: low-passed noise, slower attack than the dart, lower band (~500 Hz-1.5 kHz).
- `sfx_balloon_hit` (~300 ms): a "sploosh": a noise burst closing 4 kHz → 600 Hz plus 3-4 short high droplet blips at fixed offsets (fixed seed).
- Compare against `_tomato_throw`/`_tomato_hit` (l.263-295) for structure; keep them clearly distinct from each other and from the tomato pair (listen checklist L3).

### Horde Rush pair readability checklist (per pair, 1×, pass/fail each; from 6.6)

1. A small copy reads by silhouette in every lane, at the left edge, mid-field and at the door.
2. Medium and brute copies read as bigger, not blurry; the Pumpkin hat sits on the crown (3× crops).
3. The defender reads as a friendly Knight / Lifeguard (not a villager, not a zombie, not the Farmer recoloured) in every lane position, and never looks like he holds a weapon (no sword, gun, bow).
4. The projectile is visible against the lanes, the separators and the house in every lane.
5. The hit reads as a toy dart boing / a water splash, never as blood or a wound; the flash still reads as "ouch".
6. The melt is still goofy; nothing in the pair is scary for a 6-year-old or babyish for a 13-year-old (NFR10).
7. Each lane's doorway is obvious; an arriving copy clearly goes into its own door.
8. Nothing looks like a target, a word, a letter or UI (pennants, towels, flags, buoys); the HUD word sign is unaffected.
9. The pause button reads over the castle top / hut roof.
10. Grayscale (NFR8): copies, defender and projectiles separate from the lanes by value or outline.
11. It feels like a different place from the Farmhouse at a glance.

### Pair listen checklist (per pair; Smuck listens)

| # | Check | Pass when |
|---|---|---|
| L1 | Throw and hit over the march | both heard; the march never needs turning down |
| L2 | Throw vs hit | clearly different; a miss is silent |
| L3 | Pair identity | dart sounds rubbery/toy, balloon sounds wet; neither sounds like the tomato pair or like a weapon |
| L4 | Bursts | several throws/hits close together: no wall of noise, no crackle |
| L5 | With melt, groans, Brainsss | nothing masks the others; no clipping |

### Existing code: current state, what changes, what must be preserved

- `scripts/levels/horde_rush/farmer.gd` → `defender_sprite.gd` (RENAME + 4 exports). `play_idle`/`play_walk`/`play_throw`, the throw blocks loops until `animation_finished`, `_wanted` loop resumes, missing animation warns once, `sprite_frames == null` hides the body. Preserve every line of behaviour.
- `scripts/levels/horde_rush/tomato_splat.gd` → `hit_effect.gd` (RENAME). A node-bound tween steps `FRAMES` (3) at `FPS` (12) then `queue_free`; the sprite never plays on its own (tests `custom_step` the tween). Preserve.
- `scripts/levels/horde_rush/horde_rush_level.gd` (UPDATE): `TOMATO_SCENE`, `TOMATO_SPLAT_SCENE`, `SFX_THROW`, `SFX_HIT` consts (~l.69-81) become fallbacks; `_farmer` (`@onready ... as HordeFarmer`, ~l.159) → `_defender_sprite`; `apply_theme` swaps `%Field` and `%Defender` (~l.177, keep the both-null single-warning patch from the 10.1 review); `_logic_step` plays throw/hit/melt sounds (~l.455-477); `_add_projectile_view` (~l.512), `_spawn_splat` (~l.524). Preserve: step order (field then defender), RNG order (words, lanes; the defender none), spawn in the key's call, logic-before-visual, every dictionary bookkeeping rule, `MAX_FRAME_S`/`MAX_STEP_S`, the outro, `_reset`.
- `scripts/run/level_base.gd` (NO CHANGE): `_swap_slot` is a no-op when the slot already is that scene, copies only `position`, checks `accepts` (none passed for `%Defender`), keeps parent/index/owner/unique name. That is why the Farmhouse must stay `themes[0]`.
- `scripts/resources/level_theme.gd` (doc only): the `defender` line should say the defender scene brings its projectile, hit effect and sounds (`HordeDefenderSprite`).
- `data/levels/level_registry.tres` (UPDATE): today `load_steps=25`, ext ids to `16_moonlit_village`, theme script `12_theme`, farmer `15_farmer`. 10.2 (if done) adds 17/18 and +4 steps.
- `scripts/debug/debug_overlay.gd` (UPDATE): jump buttons wired ~l.94-100 (`%JumpHordeRushButton` etc. under `Panel/Box/JumpRow` and `JumpRow2`), `_refresh_jumps()` ~l.353, `_jump()` ~l.364.
- **Must not change:** `horde_rush_level.tscn`, `horde_rush.tres`, `farmhouse.tscn`, `tomato.tscn`, every existing PNG/WAV/OGG, `tools/gen_horde_rush_art.gd`, `tools/horde_rush_sim.gd`, `scripts/run/*`, `scripts/core/*`, `scripts/autoloads/*`, `player_zombie.*`.

### Known test fallout (so you are not surprised)

| Test | Why | Fix |
|---|---|---|
| `test_horde_farmer.gd`, `test_horde_rush_level.gd`, `test_level_themes.gd` | class renames, warning texts | Task 2 (names only) |
| `test_level_registry.gd::test_shipped_registry_themes` | Horde Rush ships one theme / farmer path | Task 9.1 |
| `test_run_frame.gd::test_shipped_levels_start_in_their_theme` | expects `farmhouse` | Task 9.2 (membership) |
| `test_audio_library.gd` | enumerated SFX ids | Task 8.3 |
| `test_art_review.gd` | exact sheet list and pages | Task 10.2 |
| `test_debug_overlay.gd` | if it counts jump buttons | Task 10.1 |
| `test_no_placeholder_chrome.gd` | walks `horde_rush/` and `horde_rush/themes/` | expected to pass (no ColorRect in new scenes) |
| `test_level_theme.gd` (property list) | — | must pass unchanged (no new `LevelTheme` field) |

### Testing notes

- Commands in Task 1. Run `--import` after the renames (class cache: stale caches give "Could not find type" parse errors), after the tools write PNGs/WAVs and after adding scenes.
- Never write the real save: temp-dir `SaveService` + injected `PlayerData` (`test_run_frame.gd::_make(payload, null, data)`, `_fake_player_data()`). 10.1 incident: a test starting a real level through RunFrame on the live autoload wrote the real save.
- In level tests, use the `play_sfx` / `request_voice` recorder seams (assigned before `add_child`), `_pinned_config`, `_copy_in_lane`, `_steps`, `_until_landed` helpers in `test_horde_rush_level.gd`.
- GUT 9.7.1: `assert_push_warning` / `assert_push_warning_count` / `assert_push_error_count` for deliberate logs; GUT silently skips a script that fails to parse and still exits 0 — always grep the log for `Parse Error|Compile Error|Failed to load script`.
- Image tests read committed PNG bytes with `Image.load_from_file(ProjectSettings.globalize_path(path))`, not `load()`.
- Sort `String`s, never `StringName`s. Type every `for` variable (`untyped_declaration = Error` in tests too).
- Flaky `test_audio_manager` pool test: rerun once before investigating.

### Previous story intelligence

- **10.2 (ready-for-dev, may or may not be done when you start):** same pattern for Zombie Run: new art tool copying helpers, per-theme folder, registry entries with the built-in look first, a class rename done first and proven by an unchanged suite, debug theme jump buttons built from the registry, forced-theme RunFrame tests with a fixed seed, rotation and "all appear over seeds 1..60" tests, Gate 1 before wiring. Mirror its test shapes; if it is done, extend its overlay builder rather than writing a second one.
- **10.1 (theme plumbing):** review patches you rely on: a forced payload theme is not saved as last; Horde Rush with both slots null warns once; `apply_theme` only for levels with themes; `_theme_id` set once the start succeeds. Deferred items this story resolves: per-pair projectile/SFX, non-Farmer defenders animating.
- **6.6 (Farmhouse + Farmer):** the template: ASCII-map characters (32×32, soles row 30, `FARMER_LEGEND` style), 16×16 props, static field + house layers, the doorway-per-lane rule and test, "soil is not wood" lesson, Gate 1 / Gate 2 / Audio gate with checklists, `gen_audio.gd` sounds with fixed seeds. Gate answers were "Approved" / "Approved of sound".
- **8.6:** copied helpers into a new tool; shared test helpers (`_alpha_palette_problems`, `_assert_pixel_crisp_import`); Gate captures with a temp save dir; lesson that props near a character's crown read as a hat (check the castle crenellations and hut roof never sit on a brute's crown at the door in lane 0).
- **Traps:** files LF (`.gitattributes eol=lf`; working copies may be CRLF via `core.autocrlf`, normalise before scripted matching). Hand-edited `.tscn`/`.tres`: `format=3`, correct `load_steps`, unique ids. Godot rewrites uids on import — commit what it writes. Screenshots get `.import` files too (8.7).

### Git intelligence

- Recent: `2aafc7b Story 10.1: random theme rotation, code review patches applied, done`, `8b1fe1b Story 9.3`, `74aeef4 Add Godot import files for Story 8.7 screenshots`, `f8944cd Story 9.2`, `9d498a4 Story 9.1`. One commit per story with code, art, audio, data, tests, screenshots, the story file, `deferred-work.md` and `sprint-status.yaml` together.
- Expected shape: new `tools/gen_horde_rush_pairs_art.gd` (+ `.uid`); 14 PNGs + `.import` (see "Expected new asset files"); 4 WAVs + `.import`; 8 new scenes; 2 renamed scripts + 1 renamed test (+ `.uid`s); `horde_rush_level.gd`, `level_theme.gd`, `farmer.tscn`, `tomato_splat.tscn`, `level_registry.tres`, `audio_library.tres`, `CREDITS.md`, `gen_audio.gd`, `debug_overlay.gd` (+ scene), `art_review.gd`; ~10 test files; style sheet; screenshots. Suggested message: `Story 10.3: Castle + Knight and Beach Hut + Lifeguard`.

### Expected new asset files

- `assets/sprites/characters/knight/knight_idle.png`, `knight_walk.png`, `knight_throw.png` (64×32, 128×32, 96×32)
- `assets/sprites/characters/lifeguard/lifeguard_idle.png`, `lifeguard_walk.png`, `lifeguard_throw.png` (same)
- `assets/sprites/props/dart_fly.png` (32×16), `dart_hit.png` (48×16), `water_balloon_fly.png` (32×16), `water_balloon_splash.png` (48×16)
- `assets/sprites/backdrops/castle/field.png` (640×256), `castle.png` (92×256); `assets/sprites/backdrops/beach_hut/field.png`, `beach_hut.png`
- = **14 PNGs**; `assets/audio/sfx/sfx_dart_throw.wav`, `sfx_dart_hit.wav`, `sfx_balloon_throw.wav`, `sfx_balloon_hit.wav`

### Latest tech notes (Godot 4.7.2, GUT 9.7.1)

- No new libraries or engine APIs; nothing to research. Godot 4.7.2, Compatibility renderer, GDScript only, static typing.
- `git mv` of a script with its `.gd.uid` keeps the uid; `ext_resource` lines by path must be updated. After a `class_name` rename run `--import` so `.godot/global_script_class_cache.cfg` is rebuilt.
- `@export var x: PackedScene` on a script attached to an instanced scene root is set in that scene's `.tscn` as `projectile_scene = ExtResource("...")`; `StringName` exports serialise as `throw_sfx = &"sfx_dart_throw"`.
- A `const X := preload("res://tools/gen_horde_rush_art.gd")` in a SceneTree tool gives access to that script's consts without running its `_init`.
- `Image.save_png` writes deterministic bytes for the same pixels, so a rerun of the tool shows no diff.

### Project Structure Notes

- Art tool in `tools/`; character sheets in `assets/sprites/characters/<defender>/`; props in `assets/sprites/props/`; backdrops in `assets/sprites/backdrops/<theme_id>/` (one folder per house + defender pair, 6.6 rule); level-local scenes in `scenes/levels/horde_rush/` (defenders and props, next to `farmer.tscn` and `tomato.tscn`), theme scenes in `scenes/levels/horde_rush/themes/<theme_id>.tscn`; scratch in `tools/_scratch_10_3/` (deleted); screenshots in `_bmad-output/implementation-artifacts/screenshots/10-3/`.

### Project Context Rules

- There is no `project-context.md`. Rules from the architecture and earlier stories:
  - Levels never read input, the clock or PlayerData; RunFrame calls down (`apply_theme`), levels signal up.
  - One RNG per run; the theme has its own seed-derived RNG; the defender has none; art and sound tools use no unseeded RNG.
  - Static data via `@export` Resources; theme ids permanent once shipped (`castle`, `beach_hut` join the saved ids).
  - NFR16: a missing texture, scene or export never stops a run (warn + built-in fallback).
  - NFR10 / FR58: food and toys only, never guns; no gore; defeat is melting. NFR9/NFR10: no text in art; theme ids are debug-only text.
  - Debug code only in `scenes/debug/` / `scripts/debug/`; release-hidden.
  - Visible and audible changes wait for Smuck's approval (Gate 1 before wiring, Gate 2 in game, Audio gate), recorded verbatim with dates.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 10.3: Castle + Knight and Beach Hut + Lifeguard]; Epic 10 overview; FR56, FR58, FR76; NFR1, NFR8, NFR10, NFR13, NFR16
- [Source: _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md] l.324 (house + defender pairs, no guns)
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/DESIGN.md] l.332 (no grit, gore, horror lighting, guns), D16 (stamp red reserved)
- [Source: docs/art-style-sheet.md] sections 1-3 (animation table l.147-151, Farmhouse paragraph l.202-211, how sprites are made l.236+)
- [Source: tools/gen_horde_rush_art.gd] (header, FARMER_* maps, TOMATO/SPLAT maps, `sheets`, field/farmhouse drawing l.369-614), [tools/gen_art_prototypes.gd PALETTE], [tools/gen_audio.gd l.1-20, 90-126, 263-315], [tools/capture_screens.gd --convert]
- [Source: scripts/levels/horde_rush/horde_rush_level.gd], [farmer.gd], [tomato_splat.gd], [horde_defender.gd], [scripts/run/level_base.gd l.17-100], [scripts/resources/level_theme.gd], [data/levels/level_registry.tres], [data/audio/audio_library.tres l.125-153], [scenes/levels/horde_rush/*.tscn], [scripts/debug/debug_overlay.gd l.94-100, 353-367], [scripts/debug/art_review.gd l.60-75]
- [Source: tests/unit/test_horde_rush_level.gd l.800-1045], [test_horde_farmer.gd], [test_level_themes.gd l.115-160], [test_art_backdrop.gd l.247-360], [test_art_sprites.gd l.45-60, 756-790], [test_level_registry.gd ~l.245-270], [tests/integration/test_run_frame.gd l.2309-2323], [test_audio_library.gd l.128, 262], [test_art_review.gd l.51, 127]
- [Source: _bmad-output/implementation-artifacts/10-1-random-theme-rotation.md], [10-2-pumpkin-patch-farm-and-snowy-town.md], [6-6-farmhouse-farmer-and-march-music.md] (checklists l.156-177, gates), [deferred-work.md] (10-1 sections ~l.828-841)

## Art Approval

<!-- Gate 1 (Task 6.2) and Gate 2 (Task 11.3): Smuck's verbatim answers, with dates. -->

**Gate 1 (sheet and backdrop review), 2026-10-14:** "i approve"

Shown: `screenshots/10-3/gate1-<pair>-3x.png` (also `-1x.png` on disk; field + house with the defender idle in lane 0,
winding up in lane 2 and releasing in lane 4, a projectile in flight in lanes 1 and 3, the hit effect on a small copy
in lane 2, small/medium/brute copies with the Pumpkin hat at the left edge, mid-field and at the door),
`gate1-<pair>-sheets-3x.png` (every new sheet) and `gate1-<pair>-1x-gray.png`, for `castle` and `beach_hut`. Fixed before
showing: the castle's arrow slits had a cross bar (read as "+", now plain slits); the beach ripples were short repeated
squiggles (could read as marks, now long gentle arcs); splash frame 3 looked like a face (now drops at different
heights over a flat puddle).

**Gate 2 (in-game look), 2026-10-14:** "approved"

Shown: `screenshots/10-3/gate2-<pair>-mid.png` (6+ copies of all three sizes, a projectile in flight, a hit flash, a
melt), `-door.png` (a copy shuffling into its door), `-end.png` (the dance), `-defender-3x.png` (the defender
mid-throw) and `-mid-gray.png`, for `castle` and `beach_hut`, on the real RunFrame with the theme forced (seed 7,
temp save dir; real save sha256 unchanged). Also `-start.png` on disk. The copies wear the hat equipped in the real
save (read-only); brutes were given the Pumpkin hat for the crop check.

## Audio Approval

<!-- Audio gate (Task 11.4): Smuck's verbatim answer and the filled listen checklist, with the date. -->

**Audio gate (a listen), 2026-10-14:** "Approved of sound"

Smuck played both pairs with sound in the web debug build (browser pane, F3 → `castle` / `beach_hut`). Listen
checklist (per pair, Castle + Knight / Beach Hut + Lifeguard), passed with the approval:

| # | Check | Castle (dart) | Beach Hut (balloon) |
|---|---|---|---|
| L1 | Throw and hit over the march | pass | pass |
| L2 | Throw vs hit clearly different; a miss silent | pass | pass |
| L3 | Pair identity (rubbery toy / wet), never the tomato or a weapon | pass | pass |
| L4 | Bursts: no wall of noise, no crackle | pass | pass |
| L5 | With melt, groans, Brainsss: nothing masked, no clipping | pass | pass |

Shipped as generated: `volume_db` −11 (throws) / −9 (hits), `min_interval_s` 0.08 / 0.06, the tomato pair's values.

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Debug Log References

- **Baseline (Task 1):** 2121/2121 passing, `SCRIPT ERROR` 3, `WARNING` 167, 0 parse/compile/load errors. 10.2 was `done`
  (registry ext ids to `18_snowy_town`, `load_steps=29`, the overlay's Zombie Run theme row). Real save sha256
  `2859cbaa61d4fc9a7a4b7b7e8019794def38313e28a8ba71d8b6a0cd347d647a`.
- **After the renames + pair plumbing (Tasks 2-3):** 2121 green with the same counts before the new tests; then 2127.
- **Running a `-s` tool loads the autoloads, which read the real save** ("loaded save.json, migrated to schema 4" is
  logged); it is never written: sha256 checked after the art tool, the audio tool and every capture run.
- **Horde Rush pair readability checklist (Gate 1 + Gate 2 captures, 1×):**

  | # | Castle + Knight | Beach Hut + Lifeguard |
  |---|---|---|
  | 1 | pass: small copies read in every lane, left edge, mid-field, at the door | pass |
  | 2 | pass: medium/brute bigger, crisp; the Pumpkin hat on the crown (`gate1-*-3x`) | pass |
  | 3 | pass: helmet, visor up with a smiling face, plume; no sword/shield/lance; reads as neither Farmer nor zombie | pass: visor, dark hair, zinc nose, pumpkin top; no water gun |
  | 4 | pass: dart (pumpkin cup, chalk shaft) visible on sand, fences and the wall | pass: blue balloon visible on pale sand and strips |
  | 5 | pass: squash / boing / chalk star; nothing sticks into the copy | pass: flatten / splash / drops, clearly water |
  | 6 | pass: friendly, toy siege | pass: sunny beach day |
  | 7 | pass: one arched gateway per lane, copies shuffle into their own door (`gate2-castle-door`) | pass (`gate2-beach_hut-door`) |
  | 8 | pass: pennants are plain triangles; arrow slits plain (cross bar removed before Gate 1) | pass: towels, sandcastles, shells, balls; ripples changed to long arcs; no "+" window bars |
  | 9 | pass: the pause button sits on the merlons | pass: on the roof's right slope |
  | 10 | pass: copies, Knight and dart separate by value and ink (`gate1-castle-1x-gray`, `gate2-castle-mid-gray`) | pass (sand is light; copies and balloon dark-outlined) |
  | 11 | pass: grey stone and jousting lists vs the farm's soil and wood | pass: pale sand, sea, purple roof |
- **Perf smoke (Task 11.5):** a web debug export (`--export-debug "Web" build/web/index.html`) served by the `web-debug`
  launch config in the browser pane (browser storage, never the real save). F3 → `castle`, then `beach_hut`; first word
  typed, F4 stress hold (30 copies), full 3:00 run each. The overlay's "Run" worst frame: Castle 20.4 ms, Beach Hut
  29.2 ms (both under 33 ms, NFR1; 60 FPS while running). Higher "worst 10 s" readings (34-37 ms) appeared only after the
  run ended, on the report-card transition. No console errors in the buffered log (the debug log is verbose, so older
  lines were dropped from the pane's buffer before reading).
- **Mutation pass (Task 12.2), each turned a test red, then restored (PNGs regenerated byte-identical, data and code
  files copied back):** stamp-red in the dart's cup → `test_horde_rush_pair_sheets_never_use_reserved_colours`;
  zombie-green in a castle lane → `test_hr_pairs_no_zombie_green_where_copies_walk`; a beach hut doorway 1 px up (soles
  row painted wall) → `test_hr_pairs_a_doorway_per_lane_on_the_feet_line`; a knight pixel in zombie-green →
  `test_knight_skin_is_human`; a 14 px dart frame → `test_dart_is_small`; `beach_hut` dropped from the registry → 4
  tests (registry, RunFrame same-rules and drawn-over-seeds, overlay jumps); empty `projectile_scene` in `knight.tscn`
  → 5 tests; the fallback warning removed → `test_an_empty_projectile_scene_warns_once_and_throws_tomatoes`,
  `test_every_empty_export_warns_once`; the Castle run's `defender_throw_cooldown_s` doubled →
  `test_horde_rush_rules_do_not_change_with_the_pair` (config and outcome differ). The first attempt at the last
  mutation keyed on the node name and never fired (a swapped slot keeps the name `Defender`); re-run keyed on the
  scene path.
- **Final (Task 12.1):** 2144/2144 passing (+23 test functions: 6 level pair-plumbing, 7 art backdrop, 5 art sprite,
  1 defender sprite, 3 RunFrame, 1 level themes; the overlay theme-jump test renamed and extended), `SCRIPT ERROR` 3 (Δ0),
  `WARNING` 172 (Δ+5: the deliberate, asserted "defender has no projectile scene / hit scene / throw sound / hit sound"
  warnings of `test_an_empty_projectile_scene_warns_once_and_throws_tomatoes` (1) and `test_every_empty_export_warns_once`
  (4)), 0 parse/compile/load errors. `git status` shows no modified existing `.png` or `.wav`. Real save sha256
  unchanged after the suite, the tool runs and every capture.
- `_bmad-output/` now carries a `.gdignore`, so the 10-3 screenshots get no `.import` files (nothing to commit for
  them, unlike 8.7).

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created
- Renames first, suite unchanged: `HordeFarmer` → `HordeDefenderSprite` (`defender_sprite.gd`), `HordeTomatoSplat` →
  `HordeHitEffect` (`hit_effect.gd`), test file → `test_horde_defender_sprite.gd`, all with `git mv` and their `.uid`;
  warnings now say "defender has no ..." / "hit effect has no ...". No `HordeFarmer|HordeTomatoSplat|farmer.gd|tomato_splat.gd`
  left outside `_bmad-output/` and `.godot/`.
- The pair travels with the defender scene (design decision kept): four exports on `HordeDefenderSprite`
  (`projectile_scene`, `hit_scene`, `throw_sfx`, `hit_sfx`), set in `farmer.tscn` (tomato pair), `knight.tscn` (dart)
  and `lifeguard.tscn` (water balloon). `horde_rush_level.gd` resolves them once in `_ready` (`_resolve_pair`, after the
  theme swap), falling back to the tomato consts: silently for a non-sprite defender, one warning per empty export on a
  real sprite. `LevelTheme` gained no property (doc only). `horde_rush_level.tscn`, `horde_rush.tres`, `farmhouse.tscn`,
  `tomato.tscn` and `gen_horde_rush_art.gd` are untouched.
- New art tool `tools/gen_horde_rush_pairs_art.gd` writes the 14 PNGs (reuses the Farmer's leg maps and arm erasers and
  the layout consts by `preload`; helpers copied; exits non-zero on a reserved colour in a legend or shape); a rerun is
  byte-identical. Gate 1 approved after three pre-show fixes (plain arrow slits, long ripple arcs, splash frame 3).
- 8 scenes (2 themes, 2 defenders, 2 projectiles, 2 hit effects) copied from the Farmhouse pair's; registry: ext ids
  19-22, `Resource_theme_castle` / `Resource_theme_beach_hut`, `load_steps` 29 → 35, Farmhouse still `themes[0]`.
- Four sounds appended to `gen_audio.gd` (seeds 10301-10303; the dart hit is pure tone), registered with the tomato
  pair's `volume_db` / `min_interval_s`; every existing WAV byte-identical. Audio gate approved as generated.
- Debug: the overlay's theme row is built for `THEME_JUMP_LEVELS` (Zombie Run, Horde Rush), so it now also shows
  `farmhouse`, `castle`, `beach_hut`; the art review lists the 10 new sheets (10 pages).
- Gate 2 captured on the real RunFrame (windowed scratch runner, temp save dir); perf smoke under the F4 stress hold:
  worst in-run frame 20.4 ms (Castle) and 29.2 ms (Beach Hut).
- Reach a pair: F3 → `castle` / `beach_hut` (from the menu card the pair is random, never the previous one).

### File List

Modified:
- `_bmad-output/implementation-artifacts/deferred-work.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `assets/audio/CREDITS.md`
- `data/audio/audio_library.tres`
- `data/levels/level_registry.tres`
- `docs/art-style-sheet.md`
- `scenes/levels/horde_rush/farmer.tscn`
- `scenes/levels/horde_rush/tomato_splat.tscn`
- `scripts/debug/art_review.gd`
- `scripts/debug/debug_overlay.gd`
- `scripts/levels/horde_rush/horde_rush_level.gd`
- `scripts/resources/level_theme.gd`
- `tests/integration/test_run_frame.gd`
- `tests/unit/test_art_backdrop.gd`
- `tests/unit/test_art_review.gd`
- `tests/unit/test_art_sprites.gd`
- `tests/unit/test_audio_library.gd`
- `tests/unit/test_debug_overlay.gd`
- `tests/unit/test_horde_rush_level.gd`
- `tests/unit/test_level_registry.gd`
- `tests/unit/test_level_themes.gd`
- `tests/unit/test_no_placeholder_chrome.gd`
- `tools/gen_audio.gd`

Renamed (git mv, uid kept):
- `scripts/levels/horde_rush/farmer.gd` → `scripts/levels/horde_rush/defender_sprite.gd`
- `scripts/levels/horde_rush/farmer.gd.uid` → `scripts/levels/horde_rush/defender_sprite.gd.uid`
- `scripts/levels/horde_rush/tomato_splat.gd` → `scripts/levels/horde_rush/hit_effect.gd`
- `scripts/levels/horde_rush/tomato_splat.gd.uid` → `scripts/levels/horde_rush/hit_effect.gd.uid`
- `tests/unit/test_horde_farmer.gd` → `tests/unit/test_horde_defender_sprite.gd`
- `tests/unit/test_horde_farmer.gd.uid` → `tests/unit/test_horde_defender_sprite.gd.uid`

Added:
- `_bmad-output/implementation-artifacts/screenshots/10-3/gate1-beach_hut-1x-gray.png`
- `_bmad-output/implementation-artifacts/screenshots/10-3/gate1-beach_hut-1x.png`
- `_bmad-output/implementation-artifacts/screenshots/10-3/gate1-beach_hut-3x.png`
- `_bmad-output/implementation-artifacts/screenshots/10-3/gate1-beach_hut-sheets-3x.png`
- `_bmad-output/implementation-artifacts/screenshots/10-3/gate1-castle-1x-gray.png`
- `_bmad-output/implementation-artifacts/screenshots/10-3/gate1-castle-1x.png`
- `_bmad-output/implementation-artifacts/screenshots/10-3/gate1-castle-3x.png`
- `_bmad-output/implementation-artifacts/screenshots/10-3/gate1-castle-sheets-3x.png`
- `_bmad-output/implementation-artifacts/screenshots/10-3/gate2-beach_hut-defender-3x.png`
- `_bmad-output/implementation-artifacts/screenshots/10-3/gate2-beach_hut-door.png`
- `_bmad-output/implementation-artifacts/screenshots/10-3/gate2-beach_hut-end.png`
- `_bmad-output/implementation-artifacts/screenshots/10-3/gate2-beach_hut-mid-gray.png`
- `_bmad-output/implementation-artifacts/screenshots/10-3/gate2-beach_hut-mid.png`
- `_bmad-output/implementation-artifacts/screenshots/10-3/gate2-beach_hut-start.png`
- `_bmad-output/implementation-artifacts/screenshots/10-3/gate2-castle-defender-3x.png`
- `_bmad-output/implementation-artifacts/screenshots/10-3/gate2-castle-door.png`
- `_bmad-output/implementation-artifacts/screenshots/10-3/gate2-castle-end.png`
- `_bmad-output/implementation-artifacts/screenshots/10-3/gate2-castle-mid-gray.png`
- `_bmad-output/implementation-artifacts/screenshots/10-3/gate2-castle-mid.png`
- `_bmad-output/implementation-artifacts/screenshots/10-3/gate2-castle-start.png`
- `assets/audio/sfx/sfx_balloon_hit.wav`
- `assets/audio/sfx/sfx_balloon_hit.wav.import`
- `assets/audio/sfx/sfx_balloon_throw.wav`
- `assets/audio/sfx/sfx_balloon_throw.wav.import`
- `assets/audio/sfx/sfx_dart_hit.wav`
- `assets/audio/sfx/sfx_dart_hit.wav.import`
- `assets/audio/sfx/sfx_dart_throw.wav`
- `assets/audio/sfx/sfx_dart_throw.wav.import`
- `assets/sprites/backdrops/beach_hut/beach_hut.png`
- `assets/sprites/backdrops/beach_hut/beach_hut.png.import`
- `assets/sprites/backdrops/beach_hut/field.png`
- `assets/sprites/backdrops/beach_hut/field.png.import`
- `assets/sprites/backdrops/castle/castle.png`
- `assets/sprites/backdrops/castle/castle.png.import`
- `assets/sprites/backdrops/castle/field.png`
- `assets/sprites/backdrops/castle/field.png.import`
- `assets/sprites/characters/knight/knight_idle.png`
- `assets/sprites/characters/knight/knight_idle.png.import`
- `assets/sprites/characters/knight/knight_throw.png`
- `assets/sprites/characters/knight/knight_throw.png.import`
- `assets/sprites/characters/knight/knight_walk.png`
- `assets/sprites/characters/knight/knight_walk.png.import`
- `assets/sprites/characters/lifeguard/lifeguard_idle.png`
- `assets/sprites/characters/lifeguard/lifeguard_idle.png.import`
- `assets/sprites/characters/lifeguard/lifeguard_throw.png`
- `assets/sprites/characters/lifeguard/lifeguard_throw.png.import`
- `assets/sprites/characters/lifeguard/lifeguard_walk.png`
- `assets/sprites/characters/lifeguard/lifeguard_walk.png.import`
- `assets/sprites/props/dart_fly.png`
- `assets/sprites/props/dart_fly.png.import`
- `assets/sprites/props/dart_hit.png`
- `assets/sprites/props/dart_hit.png.import`
- `assets/sprites/props/water_balloon_fly.png`
- `assets/sprites/props/water_balloon_fly.png.import`
- `assets/sprites/props/water_balloon_splash.png`
- `assets/sprites/props/water_balloon_splash.png.import`
- `scenes/levels/horde_rush/dart.tscn`
- `scenes/levels/horde_rush/dart_hit.tscn`
- `scenes/levels/horde_rush/knight.tscn`
- `scenes/levels/horde_rush/lifeguard.tscn`
- `scenes/levels/horde_rush/themes/beach_hut.tscn`
- `scenes/levels/horde_rush/themes/castle.tscn`
- `scenes/levels/horde_rush/water_balloon.tscn`
- `scenes/levels/horde_rush/water_balloon_splash.tscn`
- `tools/gen_horde_rush_pairs_art.gd`
- `tools/gen_horde_rush_pairs_art.gd.uid`
- `_bmad-output/implementation-artifacts/10-3-castle-knight-and-beach-hut-lifeguard.md` (this story)

Deleted (scratch, never committed): `tools/_scratch_10_3/`

### Change Log

- 2026-10-14: Story 10.3 implemented: `HordeFarmer` → `HordeDefenderSprite` and `HordeTomatoSplat` → `HordeHitEffect`;
  the projectile, hit effect and throw/hit sounds travel with the defender scene (tomato fallbacks); Castle + Knight
  (toy suction-cup dart) and Beach Hut + Lifeguard (water balloon) art from the new `gen_horde_rush_pairs_art.gd`,
  4 sounds in `gen_audio.gd`, 8 scenes, 2 registry themes; art, level, registry, RunFrame, overlay and art-review
  tests (2121 → 2144); F3 jumps per Horde Rush pair; style sheet and deferred-work updated. Gate 1, Gate 2 and the
  Audio gate approved by Smuck. Status → review.
