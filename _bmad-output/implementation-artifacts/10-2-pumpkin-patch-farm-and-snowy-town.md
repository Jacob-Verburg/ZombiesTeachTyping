---
baseline_commit: 2aafc7ba68206e94a6a7f5263459884ba1ebd725
---

# Story 10.2: Pumpkin Patch Farm and Snowy Town

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a kid,
I want new places for Zombie Run,
so that my runs feel like trips to different towns.

## Acceptance Criteria

1. **Two new Zombie Run themes ship (FR76).** `data/levels/level_registry.tres` gives `zombie_run` three themes, in this order: `sunny_village_green` (unchanged, stays first: it is the level scene's built-in look), `pumpkin_patch_farm`, `snowy_town`. Each new theme is a `LevelTheme` with only `id` and `backdrop` set (`defender` null, `music_id` empty, so Zombie Run keeps `mus_zombie_run`). The ids are permanent once shipped (they go into players' saves). Horde Rush and Pitchfork Panic keep their single theme. With three themes, 10.1's `ThemePicker` picks one per run, never the previous one; no picker, RunFrame or save change is needed.
2. **Each theme is a full parallax backdrop.** `scenes/levels/zombie_run/themes/pumpkin_patch_farm.tscn` and `snowy_town.tscn` have exactly the `sunny_village_green.tscn` node layout: root `Backdrop` (Node2D, the shared parallax backdrop script, see AC 6), `Sky` (ColorRect 640×192, palette colour, `mouse_filter = 2`), `Clouds/A,B`, `Far/A,B`, `Near/A,B`, `Ground/A,B` (Ground at y 192; copy B at x 640; `centered = false`). Textures live in `assets/sprites/backdrops/pumpkin_patch_farm/` and `assets/sprites/backdrops/snowy_town/`: `clouds.png`, `far.png`, `near.png` (640×192 each), `ground_tiles.png` (4 tiles × 16×16 = 64×16, the path tile last) and `ground_strip.png` (640×64, built from the tiles, row 0 = the path).
3. **They tile seamlessly for a full run (FR76, NFR13).** Every 640 px layer and strip is authored with wraparound (seam rows match, and something crosses the seam on purpose); every tile repeats with itself (left col = right col; grass/field tiles also top row = bottom row); the strip is made only of its tiles, row 0 only the path tile, rows 1-3 never the path, every tile used. A full 2:00 run (and an F6 early end) shows no seam, gap, tear or flicker, and the ground moves exactly with the targets.
4. **Target letters stay readable (FR76, NFR13).** The Sunny Village rules hold for both themes (*tested*): the tag band (y 96-166) of `clouds.png`, `far.png`, `near.png` has no `parchment`, `chalk` or `candy-yellow`; the ground strip has none of those three anywhere; no file uses `candy-yellow`, `stamp-red` or `art-moon`. Plus a **day readability band** (*tested*, new themes only): `near.png` rows 160-191 and the ground strip's top 4 rows use no `zombie-green` or `zombie-green-bright` (the zombie's and the party zombies' skin). The **Zombie Run letter readability checklist** (Dev Notes) passes at 1× for each theme, recorded pass/fail.
5. **They follow the style sheet (NFR13, NFR10).** Code-authored by a tool (never a hand-edited PNG), from shapes at fixed positions (no RNG: a rerun writes the same bytes); hard alpha, palette colours only; Lossless, no mipmaps; outline-exempt (backdrops only). Cute-Halloween, daytime: each keeps a light dusting of Halloween dressing (DESIGN.md D6: a pumpkin, bat-purple bunting or a friendly bat) and nothing scary (no gore, no horror lighting, no skulls or bones; a scarecrow or snowman smiles). No letters, numbers or text-like marks anywhere in the art (they would read as targets).
6. **One shared backdrop script, renamed.** `SunnyVillageBackdrop` becomes `ParallaxBackdrop` (`scripts/levels/zombie_run/parallax_backdrop.gd`, moved with `git mv` together with its `.uid` so the uid survives); every reference is updated (both level scripts' `@onready` types and `_accepts_backdrop`, `level_theme.gd`'s doc, the four theme scenes, the test fixture, the tests, the style sheet). Behaviour is byte-for-byte the same: same constants, layer names, factors and rounding. Every existing backdrop/level test passes with only the name changed.
7. **Villagers are unchanged.** "Matching villager recolors if needed" is resolved as **not needed** (Dev Notes "Design decisions"); Snowy Town and Pumpkin Patch Farm use the existing villager, poof and party-hat zombie sheets. If Gate 1 asks for winter or farm villagers, stop and raise it: it needs a `LevelTheme` field and level plumbing that this story does not include.
8. **Rules never change with the theme (FR76).** No change to `data/levels/zombie_run.tres`, `ZombieRunLevel` logic, `TypingSession`, the target source, the HUD, RunFrame or the save. A test starts Zombie Run through RunFrame with each of the three themes forced (payload `"theme"`) and the same seed: same target sequence, same `LevelConfig`, zero warnings and errors, and the level's `%Backdrop` is that theme's scene.
9. **A theme is easy to see on demand (debug only).** The F3 overlay gets one jump button per Zombie Run theme (built from the registry, payload `{"level_id": &"zombie_run", "theme": <id>}`), so Smuck can open each town directly; never visible in a release build.
10. **Approval gates.** Gate 1 (the new layers composed at 1× and 3×, before wiring) and Gate 2 (in game on the real RunFrame) are approved by Smuck; each answer verbatim with the date in `## Art Approval`. Both readability checklists are filled in pass/fail.
11. **No regressions.** Full GUT suite green; the count only goes up; zero `Parse Error|Compile Error|Failed to load script`; `SCRIPT ERROR` / `WARNING` counts unchanged except deliberate, asserted ones. All existing PNGs byte-identical (`git status` shows no modified PNG). The real `user://save.json` is untouched by the test run and the captures (sha256 before/after).

## Tasks / Subtasks

- [x] **Task 1: Baseline** (AC: 11)
  - [x] 1.1 `git status` clean. `"/c/Program Files/Godot/Godot.exe" --headless --path . --import`, then `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`. Record the count (10.1 ended at 2106 before its review patches; the recount is authoritative), `SCRIPT ERROR` (3) and `WARNING` (167 at 10.1) line counts; grep the log for `Parse Error|Compile Error|Failed to load script`.
  - [x] 1.2 sha256 of the real save (`%APPDATA%/Godot/app_userdata/<project>/save.json`).

- [x] **Task 2: Rename `SunnyVillageBackdrop` → `ParallaxBackdrop`** (AC: 6) — pure rename, do it first and run the suite before any art
  - [x] 2.1 `git mv scripts/levels/zombie_run/sunny_village_backdrop.gd scripts/levels/zombie_run/parallax_backdrop.gd` and the same for the `.gd.uid`. `class_name ParallaxBackdrop`. Rewrite the class doc's first paragraph: one shared 4-layer parallax for every scrolling look (Sunny Village Green 3.6, Moonlit Village 8.6, Pumpkin Patch Farm and Snowy Town 10.2); keep the rest of the doc and every line of code.
  - [x] 2.2 Update references: `scripts/levels/zombie_run/zombie_run_level.gd` (`@onready var _backdrop`, `_accepts_backdrop`, the doc line ~54), `scripts/levels/pitchfork_panic/pitchfork_panic_level.gd`, `scripts/resources/level_theme.gd` (doc), the `ext_resource` path in `sunny_village_green.tscn`, `moonlit_village.tscn` and `tests/fixtures/levels/test_backdrop.tscn` (keep the uid in `moonlit_village.tscn`'s line; it stays valid because the `.uid` moved), `docs/art-style-sheet.md` (Moonlit paragraph).
  - [x] 2.3 Tests: `git mv tests/unit/test_sunny_village_backdrop.gd tests/unit/test_parallax_backdrop.gd` (+ `.uid`), and rename the type in `test_zombie_run_level.gd`, `test_pitchfork_panic_level.gd`, `test_level_themes.gd`. Grep the repo (excluding `_bmad-output/` history and `.godot/`) for `SunnyVillageBackdrop|sunny_village_backdrop`: zero hits left.
  - [x] 2.4 `--import` (the global class cache must learn the new `class_name`), full suite: same count, all green. If anything fails, the rename is wrong, not the test.

- [x] **Task 3: Art tool** (AC: 2, 3, 5) — new `tools/gen_zombie_run_themes_art.gd`
  - [x] 3.1 `extends SceneTree`, header doc like `tools/gen_pitchfork_panic_art.gd`'s (what it writes, the run line, the backdrop rules, the day readability band). `const Proto := preload("res://tools/gen_art_prototypes.gd")` for `Proto.PALETTE` (the one palette source). Copy the shape helpers (`_layer`, `_put`, `_rect`, `_box`, `_blob`, `_roof`, `_sheet_image`, `_tiles_image`, `_ground_strip`, `_save`) from `gen_zombie_run_art.gd` (8.6 precedent: SceneTree instance methods can't be shared; do **not** refactor the old tools, their PNGs must stay byte-identical). Every x wraps with `posmod(x, PERIOD)`.
  - [x] 3.2 One function set per theme, writing to its own `BACKDROP_DIR`; both themes written by one run. Named consts for every position (look values, not GDD numbers). Non-zero exit on any bad map, legend, path or a reserved colour (check in `_init`: no `candy-yellow`, `stamp-red`, `art-moon` in any legend or shape colour).
  - [x] 3.3 Ground strip helper: same layout and validation as Sunny's `_ground_strip` (4 rows of 40; row 0 path only; rows 1-3 never the path). Tile 3 is the path in both themes, so the existing Sunny strip test logic applies unchanged.
  - [x] 3.4 Draw Pumpkin Patch Farm and Snowy Town (suggested compositions and colour rules in Dev Notes). Run: `"/c/Program Files/Godot/Godot.exe" --headless --path . -s tools/gen_zombie_run_themes_art.gd`, then `--import`. Rerun once: `git status` shows no change (deterministic). Commit PNGs with their `.import` (Lossless `compress/mode=0`, no mipmaps; do not set a per-file filter).

- [x] **Task 4: Art tests** (AC: 3, 4, 5) — `tests/unit/test_art_backdrop.gd`
  - [x] 4.1 Add a Zombie Run themes section: `const ZR_THEME_DIRS: Array[String] = ["res://assets/sprites/backdrops/pumpkin_patch_farm/", "res://assets/sprites/backdrops/snowy_town/"]`. Loop each dir through: sizes (layers 640×192, tiles 64×16, strip 640×64); `_alpha_palette_problems` (already shared); no `candy-yellow`/`stamp-red`/`art-moon`; tag band free of `parchment`/`chalk`/`candy-yellow` in the three layers; strip free of the same; `_seam_mismatch_rows` empty and something crosses the seam (three layers + strip); tiles seamless (all four left = right; tiles 0-2 also top = bottom); strip built from tiles (row 0 = tile 3 only, rows 1-3 never 3, every tile used); the **day readability band** (no `6cc24a`/`b8f27c` in `near.png` rows 160-191 or the strip's top 4 rows); a Halloween dressing check (`near.png` or `far.png` contains `pumpkin` and `bat-purple`); `_assert_pixel_crisp_import` for every file.
  - [x] 4.2 Prefer turning the Sunny-only checks into helpers that take a dir (as 8.6 did with `_alpha_palette_problems`) and calling them for the new dirs. **Every existing Sunny, Farmhouse and Moonlit test stays and passes unchanged.** Update the file's header doc with a Story 10.2 paragraph.
  - [x] 4.3 Run the art tests (`-gdir=res://tests/unit -gselect=test_art_backdrop`). Fix the art in the tool, never the rule (a gate may relax a rule: record why).

- [x] **Task 5: Gate 1 — layer review** (AC: 10) — before wiring into the registry
  - [x] 5.1 Scratch-compose each theme at 1× (sky + 4 layers at scroll offsets 0 and 320, plus one at the run's start offset: camera x -224) with the zombie, a villager with a letter tag, a brain block with a letter tag, the candy-yellow down-arrow, two party-hat zombies in the line and the zombie wearing the pumpkin hat, all on the ground line (y 192). Also a 3× crop and a grayscale copy (`"/c/Program Files/Godot/Godot.exe" --headless --path . -s tools/capture_screens.gd -- --convert <png>`). Scratch scripts in `tools/_scratch_10_2/`, deleted after use. Save to `_bmad-output/implementation-artifacts/screenshots/10-2/gate1-<theme>-*.png`.
  - [x] 5.2 Show Smuck; record the verbatim answer with the date in `## Art Approval`. Don't wire the themes before Gate 1 passes; redraw in the tool what Smuck asks for, regenerate, re-show.

- [x] **Task 6: Theme scenes and registry** (AC: 1, 2, 8)
  - [x] 6.1 `scenes/levels/zombie_run/themes/pumpkin_patch_farm.tscn`, `snowy_town.tscn`: copy `sunny_village_green.tscn` and swap only the texture paths and the `Sky` colour. Keep `format=3`, correct `load_steps`, unique ext_resource ids; let `--import` write uids; commit what it writes.
  - [x] 6.2 `data/levels/level_registry.tres`: two `PackedScene` ext_resources, two `LevelTheme` sub-resources (`Resource_theme_pumpkin_patch_farm`, `Resource_theme_snowy_town`: `script`, `id`, `backdrop` only), `zombie_run`'s `themes = Array[ExtResource("12_theme")]([SubResource("Resource_theme_sunny_village_green"), SubResource("Resource_theme_pumpkin_patch_farm"), SubResource("Resource_theme_snowy_town")])`, `load_steps` += 4. Sunny stays first.
  - [x] 6.3 Do **not** touch `zombie_run_level.tscn` (its built-in `%Backdrop` stays the Sunny instance, so `themes[0]` is the no-op), `zombie_run.tres`, or any other entry.

- [x] **Task 7: Test fallout and new theme tests** (AC: 1, 8, 11)
  - [x] 7.1 `tests/unit/test_level_registry.gd::test_shipped_registry_themes`: Zombie Run ships the three ids in order, the other two levels one; every theme has a backdrop, empty `music_id`; only Horde Rush has a defender; `validate() == ""`. Rename the "ships one theme (Story 10.1)" message.
  - [x] 7.2 `tests/integration/test_run_frame.gd::test_shipped_levels_start_in_their_theme` (~l.2308): `zombie_run`'s theme is now drawn by `ThemePicker.theme_rng(42)` among three. Assert it is one of the three ids (and equals `get_level().theme_id` and the saved last theme); keep the exact assertions for the other two levels.
  - [x] 7.3 New RunFrame cases (same file, injected temp `PlayerData`, never the autoload): (a) **AC 8**: seed 42, `"theme"` forced to each of the three ids → identical `_targets()` sequence and the same `get_level().get_level_config()`; `%Backdrop.scene_file_path` is that theme's scene; zero warnings/errors. (b) Rotation: five consecutive Zombie Run starts on one temp PlayerData with different seeds → no two consecutive theme ids equal. (c) Over seeds 1..60 with last = `&""`, all three themes appear (cheap proof the shipped list is really used).
  - [x] 7.4 `tests/unit/test_level_themes.gd`: new case — the Zombie Run scene with `pumpkin_patch_farm` and with `snowy_town` applied: the node really swaps (scene path), keeps index 0 / name / unique name, `_backdrop` is a `ParallaxBackdrop`, `_set_zombie_x(1000)` moves its ground layer, zero warnings (all eight textures present: the backdrop's own missing-texture warning stays silent). `test_each_shipped_theme_is_a_no_op` keeps using `themes[0]` and passes unchanged.
  - [x] 7.5 `tests/unit/test_no_placeholder_chrome.gd` already walks `scenes/levels/zombie_run/themes/`: check it still passes (each new scene has exactly one `ColorRect`, the `Sky`, which is allowed); adjust the walk-count floor only if it asserts an exact number.

- [x] **Task 8: Debug overlay jump buttons** (AC: 9)
  - [x] 8.1 `scripts/debug/debug_overlay.gd` (+ its scene): one button per Zombie Run theme, built at `_ready` from the registry's `zombie_run` entry (lazy `load` of `res://data/levels/level_registry.tres`, never `preload`, like PlayerData), each wired with `_jump.bind(Router.Screen.RUN, {"level_id": &"zombie_run", "theme": theme.id})`, label the theme id (debug text, 8 px is fine). Put them in the existing jumps container; let `_refresh_jumps()` treat them like the other jumps.
  - [x] 8.2 `tests/unit/test_debug_overlay.gd`: three buttons exist with the right payloads (use the existing jump-test pattern; never navigate the live Router).

- [x] **Task 9: Gate 2, checklists, smoke** (AC: 3, 4, 10, 11)
  - [x] 9.1 In-game captures on the real `RunFrame` for each new theme (scratch capture scene under `tools/_scratch_10_2/`, forced theme, fixed seed, temp `SaveService` dir — **never the real save**, sha256 before/after): `gate2-<theme>-start.png`, `-mid.png` (a block and a villager tagged, 6+ conga followers), `-end.png` (the dance), plus a 3× crop of the zombie with the pumpkin hat and a grayscale of `-mid`. Save to `screenshots/10-2/`.
  - [x] 9.2 Fill in the **Zombie Run letter readability checklist** and the **tone and scroll checklist** (Dev Notes) per theme; record in Debug Log References.
  - [x] 9.3 Show Smuck; record the verbatim Gate 2 answer with the date in `## Art Approval`. Tell Smuck how to reach each town: F3 → the theme jump buttons (from the menu card the theme is random).
  - [x] 9.4 Scroll/perf smoke (web debug build via the `web-debug` launch config, its `user://` is browser storage): a full 2:00 Zombie Run in each new theme; no seam, no flicker, the ground in step with the targets; worst frame under 33 ms with 12+ followers (NFR1, F3 overlay); console clean.

- [x] **Task 10: Wrap-up** (AC: 11)
  - [x] 10.1 Full suite as in Task 1; record count, `SCRIPT ERROR` / `WARNING` deltas (explain each), zero parse/compile errors; real save sha256 unchanged; `git status` shows no modified existing PNG.
  - [x] 10.2 Mutation pass (each must turn a test red): a strip cell that is not a tile; a path tile in row 1; chalk at y 140 in a new `near.png`; zombie-green at y 170 in a new `near.png`; a layer clipped at the seam; drop `snowy_town` from the registry; the RunFrame forced-theme test with a different seed for one theme. (Edit the tool, regenerate, run, restore; or mutate a copy of the image in a scratch test.)
  - [x] 10.3 `docs/art-style-sheet.md`: section 1 (Epic 10 Zombie Run themes done in 10.2), section 3 (a Pumpkin Patch Farm + Snowy Town paragraph: folders, tiles, the day readability band, *tested*; the `ParallaxBackdrop` name; the new tool in "How sprites are made").
  - [x] 10.4 `deferred-work.md`: append "Resolved in 10.2: `SunnyVillageBackdrop` renamed `ParallaxBackdrop`" under the 10-1 dev section (never delete history); new "Deferred from: dev of story 10-2" (at least: villager recolours per theme not built; Zombie Run level card still shows Sunny Village Green; per-theme music not used; snow is static, no falling flakes; the registry now eagerly loads three Zombie Run backdrops; anything accepted at a gate).
  - [x] 10.5 Dev Agent Record, File List, Change Log; `sprint-status.yaml` → `review`.

## Dev Notes

### What this story is (and isn't)

- **Is:** two new Zombie Run looks (art tool, ten PNGs, two theme scenes, two registry entries), the art tests for them, the `ParallaxBackdrop` rename that 10.1 deferred here, debug jump buttons, two gates.
- **Isn't:** any theme plumbing (10.1 did it: `LevelTheme`, `ThemePicker`, `last_themes`, `_swap_slot` all work as is), Horde Rush (10.3), Pitchfork Panic (10.4), trends (10.5), new villagers, new music, falling snow, the level card. If you find yourself editing `run_frame.gd`, `level_base.gd`, `theme_picker.gd`, `save_schema.gd`, `player_data.gd`, `zombie_run.tres` or Zombie Run gameplay code, stop: that is out of scope (the only `zombie_run_level.gd` edit is the rename).

### Design decisions made for this story (follow them; record any change and why)

- **Villager recolours: not needed.** The villager (pumpkin shirt, stone trousers, wood hair) reads on both looks by its ink outline, and the party-hat zombie is defined as "villager recolour + hat" (style sheet section 6) — a per-theme villager would also need a per-theme party zombie and conga follower, plus a `LevelTheme` field and level plumbing. Not worth it for a kid-visible gain this small; deferred. Gate 1 can override (then raise it with Smuck before building anything).
- **Same tile layout as Sunny** (3 ground tiles + path last, row 0 path only) so the existing, proven strip and seam tests apply to the new themes with no new logic.
- **Sky stays a daytime blue for both** (`art-sky` `#7EC8E3`, the Sunny `Sky` colour, or `art-sky-light` for Snowy only if the arrow still reads): the candy-yellow down-arrow was proven readable on `art-sky` in 3.6. A pale or white sky would weaken it; the checklist re-checks.
- **Static snow.** `ParallaxBackdrop` has no `_process` by design (no per-frame work, no RNG). Flakes are fixed dots in `clouds.png` (they drift with the cloud parallax, which reads as a gentle snowfall). Animated snow is deferred.
- **New tool, old tools untouched.** Refactoring `gen_zombie_run_art.gd` into shared helpers risks changing Sunny's bytes; copying ~80 lines of helpers is the 8.6 precedent.
- **Rename now** (10.1 deferral: "rename when 10.2 adds a third parallax look"): with four looks on it, "SunnyVillage" is actively misleading. Same folder (`scripts/levels/zombie_run/`), because Zombie Run owns it and moving folders touches more paths for nothing.

### Colour rules for the new art (most are *tested*)

| Rule | Where | Why |
|---|---|---|
| no `parchment` `#F6E7C1`, `chalk` `#F4F1E4`, `candy-yellow` `#FFD23F` | y 96-166 in clouds/far/near; anywhere in the ground strip | tag and arrow colours (3.6 AC 6) |
| no `candy-yellow`, `stamp-red` `#B02A25`, `art-moon` `#FFF3B0` | every file | reserved: focus / stamp / moon |
| no `zombie-green` `#6CC24A`, `zombie-green-bright` `#B8F27C` | near rows 160-191; strip top 4 rows | the zombie and party zombies must not camouflage (3.6 "greens never sit on their own colour") |
| palette only, alpha 0 or 255 | every file | NFR13 |

- **Snow is NOT chalk.** The obvious snow white is `chalk`, which is banned in the tag band and the whole strip. Use `art-sky-light` `#BFE6F2` for snow, `stone-light` `#BDB6C4` for its shade, `stone` `#6F6A80` for deep shade/footprints. `chalk` may appear only above y 96 (e.g. distant snowcaps, a snowflake high in the sky) and never in the strip.
- **Pumpkins vs villagers.** The villager's shirt is `pumpkin`/`pumpkin-light`. Keep the patch's mass of pumpkins in the far layer and the upper near layer; in near rows 160-191 (where villager bodies pass) use only a few small, ink-outlined pumpkins, never a wall of orange. Checklist item 8 re-checks; the pumpkin hat on the zombie (crown ~y 162) is checklist item 9.
- **Nothing reads as a hat.** 8.6 lesson: a round prop with its bottom just above the zombie's crown row (~y 160-162) at the zombie's screen x (224) reads as a hat. At the run start the near layer is offset 528 px (camera x -224 × 0.5 → posmod), so near-layer x 592-655 shows around screen x 64-127, and layer x 752-ish (= 112) shows behind the zombie at 224. Keep pumpkins, snowballs and lamp tops away from the crown band at the zombie's position at the start, and check offsets in Gate 1.
- **No text.** No signs with letters (a farm stand sign or a shop sign is blank or shows a picture: a pumpkin, a mitten), no numbers, no letter-like shapes (a single vertical post next to a dot can read as `i`).

### Suggested compositions (Gate 1 decides; keep the shape style of Sunny: rects, roofs, discs)

**Pumpkin Patch Farm** (autumn afternoon, folder `pumpkin_patch_farm/`):
- `clouds.png`: a few `art-sky-light` puffy clouds (Sunny style, different positions), one crossing the seam.
- `far.png`: rolling `chalk-dim` or `wood-light` harvested hills with `zombie-green-dark` crest/hedgerows; a red-free barn (`wood-dark` walls, `wood` roof, `stone-light` trim — **never stamp-red**), a `stone-light` silo, rows of tiny `pumpkin` dots on the hillside (the patch in the distance), a crow-free friendly scarecrow silhouette optional.
- `near.png`: bat-purple bunting across the top (the Halloween dressing), a wooden farm fence, hay bales (`parchment-shade` + `wood-light` straw lines — `parchment-shade` is allowed in the band), a smiling scarecrow (hat, patched shirt in `bat-purple`/`wood`, stick arms, button eyes; no stitched mouth, nothing creepy), a few pumpkins on the vines (`zombie-green-dark` vines and leaves above row 160 only for big leaves), a wheelbarrow or a cart with pumpkins.
- `ground_tiles.png`: tile 0 grass (`art-grass`), tile 1 grass with fallen leaves (`pumpkin-light`/`wood-light` specks), tile 2 grass with a tiny pumpkin sprout or straw; tile 3 the path (`parchment-shade` dirt with `ink-faded` edge line on row 0 and `wood-light` pebbles — the Sunny path recipe is proven; a slightly different pebble layout is enough).

**Snowy Town** (winter day, folder `snowy_town/`):
- Sky `art-sky` (or `art-sky-light` if the arrow test passes at Gate 1).
- `clouds.png`: `stone-light` snow clouds and sparse `art-sky-light` flakes (1-2 px dots; keep most flakes above y 96 and none in a pattern that reads as dots of a letter).
- `far.png`: snowy hills (`art-sky-light` fill, `stone-light` crest), little houses and a church spire in `stone`/`ink-muted` with `art-sky-light` snowy roofs and `pumpkin-light` windows, pine trees (`zombie-green-dark` triangles with snow edges — these are in the far layer above row 160, so allowed).
- `near.png`: the town street front: cottages (`wood`/`stone`) with thick snow on the roofs (`art-sky-light`, `stone-light` shade), icicles (`art-sky-light`), lit `pumpkin-light` windows, bat-purple bunting or a wreath, a smiling snowman wearing a jack-o'-lantern hat or a pumpkin-coloured scarf (carrot nose `pumpkin`, coal eyes `ink`), a snow-covered fence, a lamp post.
- `ground_tiles.png`: tile 0 snow (`art-sky-light`), tile 1 snow with `stone-light` drift lines, tile 2 snow with footprints (`stone-light`/`stone`); tile 3 the cleared path (`stone-light` slush with `stone` edge line on row 0 and a few `art-sky-light` patches). The path must contrast with the snow and with the zombie's `wood` trousers and `wood-dark` shoes.

### Zombie Run letter readability checklist (per theme, 1×, pass/fail each; from 3.6, extended)

1. Each active-target letter on its parchment tag is readable over the far layer.
2. The same over the busiest part of the near layer, for a villager tag (y ~139-163) and a brain block tag (y ~102-126).
3. The same over the clouds/flakes and bunting.
4. The candy-yellow down-arrow is clearly visible against the sky, the far layer and the near layer.
5. A resolved target (grey used block, party zombie) does not look like a target to type.
6. The tag's ink outline separates it from every backdrop part; no backdrop element looks like a letter, a number or a second tag.
7. The HUD target letter (the band) is unaffected.
8. Characters (zombie, villager, party zombies) read by silhouette against the near layer, not only by fill (pumpkins vs the villager's pumpkin shirt; snow vs the light tags).
9. The zombie with the pumpkin hat reads (Pumpkin Patch: the hat is not lost among pumpkins; no backdrop pumpkin sits on the zombie's crown at the start).
10. Grayscale (NFR8): zombie, villagers, blocks and tags separate from the backdrop by value or outline.

### Tone and scroll checklist (per theme)

1. Cute-Halloween daytime: a light dusting of Halloween (pumpkin, bunting or a bat); goofy, not spooky; a 13-year-old would not cringe.
2. Nothing scary: scarecrow and snowman smile; no skulls, bones, gore, dark horror lighting.
3. The layers scroll at different speeds; no seam, tear, gap or flicker through a full 2:00 run, a fast 10-key burst and a long pause.
4. The ground slides exactly with the targets (a target never swims on the path).
5. The pause button (top-right) reads over the sky.
6. It feels like a different town from Sunny Village Green at a glance.

### Existing code: current state, what changes, what must be preserved

- `scripts/levels/zombie_run/sunny_village_backdrop.gd` → `parallax_backdrop.gd` (RENAME). A Node2D with `Clouds/Far/Near/Ground` layers of two 640 px copies each; `scroll_to(camera_x)` sets each layer to `-fposmod(roundf(camera_x * factor), 640)`; factors 0.1/0.25/0.5/1.0; `_ready` warns once (via `Log.warn(&"level", ...)`) for a missing layer or texture, naming `owner.name`. No `_process`, no RNG. Preserve every line except `class_name` and the doc.
- `scripts/levels/zombie_run/zombie_run_level.gd` (UPDATE, rename only): `@onready var _backdrop: SunnyVillageBackdrop = %Backdrop` (~l.109), `_accepts_backdrop(node) -> node is SunnyVillageBackdrop` (~l.112, the 10.1 review patch that keeps a wrong-root theme from breaking the typed `@onready`), `_set_zombie_x` calls `_backdrop.scroll_to(x - ZOMBIE_SCREEN_X)` (~l.305). `ZOMBIE_SCREEN_X` 224, `GROUND_Y` 192.
- `scripts/levels/pitchfork_panic/pitchfork_panic_level.gd` (UPDATE, rename only): same `@onready` type and `_accepts_backdrop` pattern.
- `scripts/run/level_base.gd` (NO CHANGE): `apply_theme` → `_swap_slot(_backdrop_slot(), theme.backdrop, _accepts_backdrop)`; no-op when the slot already is that scene (`scene_file_path == resource_path`); otherwise instantiates, checks `accepts`, replaces in place (name, index, position, owner, unique name). That is why Sunny must stay the built-in scene and `themes[0]`.
- `scripts/run/run_frame.gd` (NO CHANGE): `_pick_theme` → payload `"theme"` (forced; not saved as last since the 10.1 review) or `ThemePicker.pick(entry.themes, player_data.get_last_theme(id), ThemePicker.theme_rng(_seed))`; `apply_theme` before `add_child`; `set_last_theme` on success; music = theme `music_id` or the config's.
- `data/levels/level_registry.tres` (UPDATE): currently `load_steps=25`; ext_resource ids up to `16_moonlit_village`; the theme script is `12_theme`. Add `17_pumpkin_patch_farm`, `18_snowy_town`.
- `scripts/debug/debug_overlay.gd` (UPDATE): jump buttons are wired at ~l.94-100 with `_jump.bind(Router.Screen.RUN, {...})`; `_refresh_jumps()` ~l.353; the run line already shows `theme <id>` (~l.306).
- **Must not change:** `zombie_run_level.tscn`, `zombie_run.tres`, `villager*`, `party_zombie*`, `conga_line*`, `brain_block*`, every existing PNG, `tools/gen_zombie_run_art.gd`, `tools/gen_pitchfork_panic_art.gd`, the level card art, `scripts/run/*`, `scripts/core/*`, `scripts/autoloads/*`.

### Known test fallout (so you are not surprised)

| Test | Why | Fix |
|---|---|---|
| `test_level_registry.gd::test_shipped_registry_themes` | asserts every level ships exactly one theme | Task 7.1 |
| `test_run_frame.gd::test_shipped_levels_start_in_their_theme` | expects `sunny_village_green` for Zombie Run | Task 7.2 (membership) |
| `test_sunny_village_backdrop.gd`, `test_zombie_run_level.gd`, `test_pitchfork_panic_level.gd`, `test_level_themes.gd` | the class name | Task 2.3 (name only) |
| `test_debug_overlay.gd` | if it counts jump buttons | Task 8.2 |
| `test_no_placeholder_chrome.gd` | walks the themes folder; new scenes have one `Sky` ColorRect each | expected to pass |
| `test_level_themes.gd::test_each_shipped_theme_is_a_no_op` | uses `themes[0]` | passes if Sunny stays first |
| `test_debug_overlay.gd:610` (`theme sunny_village_green` text) | built from a fake frame | expected to pass |

### Testing notes

- Commands in Task 1. Run `--import` after the rename (class cache), after the tool writes PNGs (`.import` files) and after adding scenes.
- Never write the real save: temp-dir `SaveService` + injected `PlayerData` (patterns: `test_run_frame.gd::_make`, `_fake_player_data`). 10.1 incident: a test that starts a real level through RunFrame on the live autoload writes the real save at run start. Every new RunFrame test injects `player_data`.
- GUT 9.7.1: `assert_push_warning` / `assert_push_warning_count` / `assert_push_error_count` for deliberate logs; GUT silently skips a script that fails to parse and still exits 0 — always grep the log for `Parse Error|Compile Error|Failed to load script`.
- Image tests read committed PNG bytes with `Image.load_from_file(ProjectSettings.globalize_path(path))` (not `load()`, which returns the imported texture).
- Sort `String`s, never `StringName`s. Type every `for` variable (`untyped_declaration = Error` in tests too).
- Flaky `test_audio_manager` pool test: rerun once before investigating.

### Previous story intelligence

- **10.1 (theme plumbing):** final 2106 tests, `SCRIPT ERROR` 3, `WARNING` 167 (+ review patches since). Review patches you rely on: a forced payload theme is **not** saved as last theme; `_swap_slot` checks the backdrop root type (`_accepts_backdrop`) and warns + keeps the built-in look; `apply_theme` is not called for levels without themes; `_theme_id` is set only once the start succeeds; Horde Rush with both slots null warns once. Deferred items relevant here: the rename (do it), "registry eagerly loads every theme backdrop" (two more scenes, small textures; note, don't fix), `_swap_slot` copies only position (the new backdrops sit at (0, 0) like Sunny, so fine).
- **3.6 (Sunny Village Green):** the template for these backdrops: shapes at fixed positions, wraparound, tag band rule, the path's faded edge line on the ground line, the pumpkin-post "never reads as a hat" placement note, the 8-item readability checklist, the 2:00 scroll check, perf with 12+ followers.
- **8.6 (Moonlit Village):** second parallax look on the same script: copied helpers into a new tool, shared test helpers (`_alpha_palette_problems`, `_seam_mismatch_rows`, `_assert_pixel_crisp_import`), Gate 1 scratch composition at offsets 0/320 with grayscale, Gate 2 on the real RunFrame with a temp save dir, a readability band test. Lesson: jack-o'-lanterns on a wall top just over the crown row read as a hat and had to move.
- **Traps:** files LF (`.gitattributes eol=lf`; working copies may be CRLF via `core.autocrlf`, normalise before scripted matching). Hand-edited `.tscn`/`.tres`: `format=3`, correct `load_steps`, unique ids. The browser pane's `shift+a` sends lowercase (8.7). Godot rewrites uids on import — commit what it writes.

### Git intelligence

- Recent: `2aafc7b Story 10.1: random theme rotation, code review patches applied, done`, `8b1fe1b Story 9.3 ...`, `74aeef4 Add Godot import files for Story 8.7 screenshots` (screenshots get `.import` files when Godot scans them: commit those too, or they show as untracked later), `f8944cd Story 9.2 ...`, `9d498a4 Story 9.1 ...`. One commit per story with code, art, data, tests, screenshots, the story file, `deferred-work.md` and `sprint-status.yaml` together.
- Expected shape: new `tools/gen_zombie_run_themes_art.gd` (+ `.uid`); 10 PNGs + 10 `.import`; 2 theme scenes; renamed backdrop script and test (+ `.uid`s); `level_registry.tres`; `zombie_run_level.gd`, `pitchfork_panic_level.gd`, `level_theme.gd`, `debug_overlay.gd` (+ scene); 3 theme/fixture scenes' script path; ~7 test files; style sheet; screenshots. Suggested message: `Story 10.2: Pumpkin Patch Farm and Snowy Town`.

### Latest tech notes (Godot 4.7.2, GUT 9.7.1)

- No new libraries or engine APIs; nothing to research. Godot 4.7.2 standard, Compatibility renderer, GDScript only, static typing.
- `git mv` of a script together with its `.gd.uid` keeps the uid; `ext_resource` lines that reference the script by uid still resolve, and lines by path must be updated to the new path. After a `class_name` rename run `--import` so `.godot/global_script_class_cache.cfg` is rebuilt (stale caches give "Could not find type" parse errors).
- `Image.save_png` writes deterministic bytes for the same pixels, so a rerun of the tool shows no diff.

### Project Structure Notes

- New files follow the architecture: art tool in `tools/`, PNGs in `assets/sprites/backdrops/<theme_id>/` (style sheet: one folder per look; theme id = folder = scene file name), theme scenes in `scenes/levels/zombie_run/themes/<theme_id>.tscn`, scratch in `tools/_scratch_10_2/` (deleted), screenshots in `_bmad-output/implementation-artifacts/screenshots/10-2/`. Variance: the style sheet says backdrops go in `backdrops/<level>/`; since 6.6/8.6 the folder is per look (`farmhouse/`, `moonlit_village/`), which this story follows.

### Project Context Rules

- There is no `project-context.md`. Rules from the architecture and earlier stories:
  - Levels never read input, the clock or PlayerData; RunFrame calls down (`apply_theme`), levels signal up.
  - One RNG per run; the theme has its own seed-derived RNG; art never uses RNG.
  - Static data via `@export` Resources; theme ids permanent once shipped (`pumpkin_patch_farm`, `snowy_town` join the three already in saves).
  - NFR16: a missing texture or scene never stops a run (warn + built-in look).
  - NFR9/NFR10: no text in art; theme ids are debug-only text, never kid-facing.
  - Debug code only in `scenes/debug/` / `scripts/debug/`; jump buttons release-hidden like the existing ones.
  - Visible changes wait for Smuck's approval (Gate 1 before wiring, Gate 2 in game), recorded verbatim with dates.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 10.2: Pumpkin Patch Farm and Snowy Town]; Epic 10 overview; FR76; NFR8, NFR10, NFR13, NFR16
- [Source: _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md] l.347-348 (art rotation; Zombie Run themes), l.474; decision-log.md l.16
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/DESIGN.md] l.330 (cute-Halloween daytime dressing, D6), l.530 (do's and don'ts)
- [Source: docs/art-style-sheet.md] sections 1-3, 5, 6 (palette, backdrop rules, Moonlit paragraph, kid-safe rules, villager legend)
- [Source: tools/gen_zombie_run_art.gd l.554-957 (backdrop consts, helpers, ground strip)], [tools/gen_pitchfork_panic_art.gd header], [tools/gen_art_prototypes.gd PALETTE, VILLAGER_LEGEND, ZOMBIE_LEGEND], [tools/capture_screens.gd --convert]
- [Source: tests/unit/test_art_backdrop.gd (Sunny section l.1-262, shared helpers ~l.395-435, Moonlit section)], [tests/unit/test_level_registry.gd ~l.245], [tests/integration/test_run_frame.gd ~l.2308], [tests/unit/test_level_themes.gd], [tests/unit/test_no_placeholder_chrome.gd]
- [Source: scripts/levels/zombie_run/sunny_village_backdrop.gd], [scripts/levels/zombie_run/zombie_run_level.gd l.54, 74-113, 305], [scripts/run/level_base.gd l.17-100], [data/levels/level_registry.tres], [scenes/levels/zombie_run/themes/sunny_village_green.tscn], [scripts/debug/debug_overlay.gd l.94-100, 306, 353]
- [Source: _bmad-output/implementation-artifacts/10-1-random-theme-rotation.md], [3-6-sunny-village-green-and-zombie-run-art.md] (readability checklist, Task 8), [8-6-moonlit-village-mob-and-chase-music.md] (gates, tool, band test), [deferred-work.md] (10-1 sections ~l.828-843)

## Art Approval

<!-- Gate 1 (Task 5.2) and Gate 2 (Task 9.3): Smuck's verbatim answers, with dates. -->

**Gate 1 (layer review), 2026-10-14:** "i approve"

Shown: `screenshots/10-2/gate1-<theme>-start.png` (run-start scroll, camera x -224), `-start-3x.png`,
`-start-gray.png` and `-offset320.png` for `pumpkin_patch_farm` and `snowy_town` (also `-offset0.png` on disk),
with the pumpkin-hat zombie, two party zombies, a tagged villager with the arrow, a tagged brain block and a
second villager on the ground line. Raised and accepted as-is: at the run-start offset the scarecrow (Farm) and the
snowman (Snowy) sit behind the first brain block position (the tags still read by their ink outline); the Snowy
path is pale (stone-light slush), marked by its stone edge line.

**Gate 2 (in-game look), 2026-10-14:** "approved"

Shown: `screenshots/10-2/gate2-<theme>-start.png`, `-mid.png` (a tagged brain block, tagged villagers, 7 conga
followers), `-end.png` (F6 end, the dance), `-mid-hat-3x.png` (also `-start-hat-3x.png` on disk) and
`-mid-gray.png`, on the real RunFrame with the theme forced (seed 7, temp save dir; real save sha256 unchanged).

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Debug Log References

- **Baseline (Task 1):** 2106/2106 passing, 110 scripts, `SCRIPT ERROR` 3, `WARNING` 167, 0 `Parse Error|Compile Error|Failed to load script`. Working tree had only the story-creation artifacts (sprint-status, the 10-2/10-3 story files). Real save sha256 `2859cbaa61d4fc9a7a4b7b7e8019794def38313e28a8ba71d8b6a0cd347d647a`.
- **Rename (Task 2):** after `--import`, 2106/2106, SE 3, W 167, 0 parse errors. Zero `SunnyVillageBackdrop|sunny_village_backdrop` hits outside `_bmad-output/`, `.godot/`, `build/` and `.git/`.
- **Art tool (Task 3):** exit 0; rerun byte-identical (sha256 of all 10 PNGs equal; rechecked with `cmp` after the mutation pass). The tool also self-checks every seam, the tag band, the day band and reserved colours, and exits 1 on any failure. One redraw before Gate 1: the Snowy snow clouds' light disc (read as a hole) was removed.
- **Art tests (Task 4):** `test_art_backdrop` 27 → 37, all green.
- **Wiring:** first full run after the registry change failed exactly the two expected tests (`test_shipped_registry_themes`, `test_shipped_levels_start_in_their_theme`); fixed per Tasks 7.1/7.2. `test_no_placeholder_chrome` passed unchanged (one `Sky` ColorRect per new scene). `test_debug_overlay::test_never_blocks_the_mouse` needed the theme buttons in its jump list (they are jumps).
- **Zombie Run letter readability checklist (Gate 1 + Gate 2 captures, 1×):**
  - Pumpkin Patch Farm: 1 PASS, 2 PASS (villager tags over fence/haystack, block tag over the scarecrow at the start), 3 PASS, 4 PASS (arrow on `art-sky`), 5 PASS (grey used block, party zombies untagged), 6 PASS (no letter-like marks; the scarecrow's face reads as a face), 7 PASS, 8 PASS (villager's pumpkin shirt vs the few ink-outlined vine pumpkins: separated by outline), 9 PASS (no backdrop pumpkin on the crown at the start; hat clear in the 3× crops), 10 PASS (grayscale).
  - Snowy Town: 1 PASS, 2 PASS, 3 PASS (flakes are dots, mostly above the tag band), 4 PASS, 5 PASS, 6 PASS, 7 PASS, 8 PASS (snowman and snow vs the parchment tags: the ink outline separates them), 9 PASS, 10 PASS (`-start-gray`, `-mid-gray`).
- **Tone and scroll checklist:** both themes 1 PASS, 2 PASS (smiling scarecrow and snowman, no skulls/gore), 3 PASS (full 2:00 web runs with fast 26-key bursts and a ~50 s pause: no seam, tear, gap or flicker seen), 4 PASS (the ground moved with the targets), 5 PASS (pause button over the sky), 6 PASS (Smuck approved both at Gates 1 and 2).
- **Web smoke (Task 9.4):** `--export-debug "Web"`, `web-debug` on port 8060, Claude browser pane (visible). Each town reached via F3 → its theme jump button (the overlay showed `theme pumpkin_patch_farm` / `theme snowy_town`). Pumpkin Patch Farm: full 2:00 run, ×45 conga followers, FPS 60, F3 run worst frame **22.9 ms**. Snowy Town: full 2:00 run, ×25 followers, FPS 60, run worst **19.7 ms** (NFR1: < 33 ms with 12+ followers). Both reached the report card. Error-only console reads at the end of each run were empty (the pane keeps only recent messages; noted in deferred-work). The fresh browser profile also took the first-run welcome gift once (browser storage, never the real save).
- **Mutation pass (Task 10.2), each red then restored:** strip cell not a tile → `test_zr_themes_strip_is_built_from_the_tiles`; path tile in row 1 → same test; chalk at (300,140) in Farm `near.png` → `test_zr_themes_tag_band_and_strip_free_of_tag_colours`; zombie-green at (300,170) in Snowy `near.png` → `test_zr_themes_day_readability_band`; column 639 cleared in Snowy `far.png` → `test_zr_themes_seam_rows_match_and_features_cross`; `snowy_town` dropped from the registry → `test_level_registry` (1) and `test_run_frame` (2) fail; seed 43 for one forced theme → `test_zombie_run_rules_do_not_change_with_the_theme` ("same target sequence"). PNGs restored byte-identical from a backup; registry and test restored.
- **Final (Task 10.1):** 2121/2121 passing (+15 test functions: 10 art, 3 RunFrame, 1 level themes, 1 debug overlay), `SCRIPT ERROR` 3 (Δ0), `WARNING` 167 (Δ0), 0 parse/compile/load errors. `git status` shows no modified existing PNG. Real save sha256 unchanged after the suite, the art tool runs (which only read the save) and every capture.
- **Captures:** Gate 1 and Gate 2 used scratch scripts in `tools/_scratch_10_2/` (SubViewport composition for Gate 1; the real RunFrame with a temp-dir `SaveService` + injected `PlayerData` for Gate 2), deleted after use. `_bmad-output/` has a `.gdignore`, so the screenshots get no `.import` files.

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created
- `SunnyVillageBackdrop` → `ParallaxBackdrop` (`git mv` of the script, test and both `.uid`s, so the uid survives); only `class_name` and the class doc's first paragraph changed; every reference updated (levels, `level_theme.gd` doc, the Sunny/Moonlit/fixture scenes, the tests, the style sheet).
- New `tools/gen_zombie_run_themes_art.gd` writes both looks (10 PNGs) from fixed shapes, with no RNG. The helpers are copied from `gen_zombie_run_art.gd`, which is untouched. A reserved-colour guard runs per pixel, plus seam, tag-band and day-band self-checks.
- Pumpkin Patch Farm and Snowy Town theme scenes (Sunny layout, `art-sky` Sky) and two registry entries; Zombie Run ships `[sunny_village_green, pumpkin_patch_farm, snowy_town]`, Sunny first. No change to RunFrame, `LevelBase`, `ThemePicker`, save, `zombie_run.tres` or Zombie Run gameplay.
- Tests: the Zombie Run themes section in `test_art_backdrop.gd`; registry/RunFrame fallout updated; new RunFrame tests (rules unchanged across the three forced themes with the same seed, no repeated look over five runs, all three drawn over seeds 1..60); real-theme swap test; theme jump buttons test.
- F3 overlay: `%JumpThemeRow` with one button per Zombie Run theme, built from the registry (lazy `load`), same main-menu-only rules as the other jumps. To reach a town: F3 → `pumpkin_patch_farm` / `snowy_town` (from the menu card the theme is random).
- Villager recolours resolved as not needed (Gate 1 accepted). Both gates approved by Smuck; both checklists PASS.

### File List

- `assets/sprites/backdrops/pumpkin_patch_farm/{clouds,far,near,ground_tiles,ground_strip}.png` (+ `.import`) (new)
- `assets/sprites/backdrops/snowy_town/{clouds,far,near,ground_tiles,ground_strip}.png` (+ `.import`) (new)
- `tools/gen_zombie_run_themes_art.gd` (+ `.uid`) (new)
- `scenes/levels/zombie_run/themes/pumpkin_patch_farm.tscn` (new)
- `scenes/levels/zombie_run/themes/snowy_town.tscn` (new)
- `scenes/levels/zombie_run/themes/sunny_village_green.tscn` (modified: script path)
- `scenes/levels/pitchfork_panic/themes/moonlit_village.tscn` (modified: script path)
- `scenes/debug/debug_overlay.tscn` (modified: `JumpThemeRow`)
- `scripts/levels/zombie_run/parallax_backdrop.gd` (+ `.uid`) (renamed from `sunny_village_backdrop.gd`)
- `scripts/levels/zombie_run/zombie_run_level.gd` (modified: rename only)
- `scripts/levels/pitchfork_panic/pitchfork_panic_level.gd` (modified: rename only)
- `scripts/resources/level_theme.gd` (modified: doc)
- `scripts/debug/debug_overlay.gd` (modified: theme jump buttons)
- `data/levels/level_registry.tres` (modified: two Zombie Run themes)
- `tests/fixtures/levels/test_backdrop.tscn` (modified: script path)
- `tests/unit/test_parallax_backdrop.gd` (+ `.uid`) (renamed from `test_sunny_village_backdrop.gd`)
- `tests/unit/test_art_backdrop.gd`, `tests/unit/test_level_registry.gd`, `tests/unit/test_level_themes.gd`, `tests/unit/test_debug_overlay.gd`, `tests/unit/test_zombie_run_level.gd`, `tests/unit/test_pitchfork_panic_level.gd` (modified)
- `tests/integration/test_run_frame.gd` (modified)
- `docs/art-style-sheet.md` (modified)
- `_bmad-output/implementation-artifacts/screenshots/10-2/` (new: 10 Gate 1 and 12 Gate 2 PNGs)
- `_bmad-output/implementation-artifacts/deferred-work.md` (modified)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified)
- `_bmad-output/implementation-artifacts/10-2-pumpkin-patch-farm-and-snowy-town.md` (this file)

### Review Findings

- [x] [Review][Dismissed] All three Zombie Run skies share `art-sky` (matches AC 2; layers cover the sky)
- [x] [Review][Patch] Stale scarecrow comment said "no stitched mouth" [tools/gen_zombie_run_themes_art.gd:640]
- [x] [Review][Patch] `_check_band` reports only the first bad pixel and `_save` writes PNGs after a failed check [tools/gen_zombie_run_themes_art.gd]
- [x] [Review][Patch] Debug `JumpThemeRow` can overflow 640px with more themes: now an `HFlowContainer` [scenes/debug/debug_overlay.tscn]
- [x] [Review][Defer] `_check_seam` compares opacity only, not colour — deferred, same heuristic as the existing seam test
- [x] [Review][Defer] Snowy window "+" crossbar, formula-placed flakes — deferred, passed the Gate visuals
- [x] [Review][Defer] No structural test for the new theme scenes' node layout — deferred, partly covered by the swap and RunFrame tests
- [x] [Review][Defer] 2:00 scroll and follower performance smoke only run at the gates — deferred

Verified after patches: generator rerun leaves all 10 PNGs byte-identical; full GUT run 2121/2121 passing, 3 SCRIPT ERROR lines (same as the 10.1 baseline), no parse or compile errors.

### Change Log

- 2026-10-14: Story 10.2 implemented. `ParallaxBackdrop` rename; Pumpkin Patch Farm and Snowy Town Zombie Run themes (art tool, 10 PNGs, 2 scenes, registry); art, registry, RunFrame, theme-swap and overlay tests (2106 → 2121); F3 theme jump buttons; style sheet and deferred-work updated; Gates 1 and 2 approved. Status → review.
