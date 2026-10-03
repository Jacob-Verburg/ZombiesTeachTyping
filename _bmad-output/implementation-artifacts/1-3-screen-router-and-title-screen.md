---
baseline_commit: 64cb50fd0729593de3554d5e3df05baa028a4559
---

# Story 1.3: Screen Router and Title Screen

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a kid,
I want to see a title screen that moves on when I press any key or click,
so that the game starts the way I expect.

## Acceptance Criteria

1. **Router.** Given the `Router` autoload with `enum Screen { TITLE, MAIN_MENU, RUN, REPORT_CARD, WELCOME_GIFT, CRYPT_CLOSET }`, when `Router.go(screen, payload)` is called, then a CanvasLayer fade covers the switch, the target scene is loaded with `change_scene_to_packed`, and the new screen can read the payload once with `take_payload()`; and a screen that fails to load is logged with `Log.error()` and the Router goes to `MAIN_MENU` instead.
2. **Title screen.** Given the title screen, when it is shown, then it displays a placeholder logo and the text "Click or press any key" in the project pixel font at 16 px or larger; and any key press or mouse click goes to the main menu (FR23).
3. **Pixel font and theme.** Given an SIL OFL pixel font in `assets/fonts/` with its license file, when `l`, `I`, `1`, `O` and `0` are rendered at 16 px and 32 px, then each is clearly distinguishable (NFR7); and `data/ui_theme.tres` uses it as the default font and is set as the project's custom theme.
4. **Placeholder flow.** Given placeholder scenes for Main Menu, Run, Report Card, Welcome Gift and Crypt Closet, when the placeholder buttons are used, then the flow Title → Main Menu → Run → Report Card → Menu can be walked end to end (FR24 skeleton).
5. **Autoload order.** Given the autoloads registered in `project.godot`, when the project starts, then they are registered in the order `WebPlatform → SaveService → PlayerData → AudioManager → Router` (stubs are fine for services not built yet).

## ⚠ Decision gate (Smuck)

**The font choice is Smuck's call.** UX D11 deferred the specific font to this story, and the traits are the spec: chunky, friendly, slightly rounded, early-90s DOS edutainment; not condensed, not script, not all-caps-only; mixed case; clear `l`/`I`/`1` and `O`/`0`. The dev agent builds a glyph comparison (Task 3), shows it to Smuck, and **stops for a pick**. If Smuck says "you pick", use the recommendation in Dev Notes → Font.

## Tasks / Subtasks

- [x] **Task 1: Autoload stubs and registration** (AC: 5)
  - [x] 1.1 Create `scripts/autoloads/web_platform.gd`, `save_service.gd`, `player_data.gd` and `audio_manager.gd` as stubs: `extends Node`, **no `class_name`** (it would clash with the autoload name), a `##` doc line saying which story fills it in (1.5, 1.6, 1.7, 1.4). `audio_manager.gd` gets one stub method, `func unlock() -> void: pass`, so the title can already call it (Story 1.4 fills it in).
  - [x] 1.2 Create `scripts/autoloads/router.gd` (Task 2).
  - [x] 1.3 Register all five in `project.godot` under `[autoload]`, **in this exact order**: `WebPlatform`, `SaveService`, `PlayerData`, `AudioManager`, `Router`, each as `"*res://scripts/autoloads/<file>.gd"` (`*` = enabled singleton). Order in the file = load order.
  - [x] 1.4 Remove `scripts/autoloads/.gitkeep`.
- [x] **Task 2: Router** (AC: 1). Write `tests/unit/test_router.gd` first (Testing Requirements), then implement.
  - [x] 2.1 `enum Screen { TITLE, MAIN_MENU, RUN, REPORT_CARD, WELCOME_GIFT, CRYPT_CLOSET }`, in this order, because later stories store or compare these values.
  - [x] 2.2 Screen registry: a `const SCREEN_PATHS: Dictionary[Screen, String]` mapping every `Screen` to its `.tscn` path (see File Structure). Use **paths plus `ResourceLoader.load()`**, not `preload`. A `preload` failure is a parse error at startup, so the "fails to load → MAIN_MENU" rule could never trigger. A path registry also avoids cyclic preloads, since the screens call `Router`. This is the "preload constants in autoloads" exception in spirit: the paths live in one place only.
  - [x] 2.3 `func go(screen: Screen, payload: Dictionary = {}) -> void`. If a transition is already running, ignore the call (`Log.debug`) and don't queue it. Otherwise: store the payload, pause the tree, fade out, swap, fade in, unpause. The sequence is in Dev Notes → Router transition.
  - [x] 2.4 `func take_payload() -> Dictionary`: returns the stored payload and clears it, so a second call returns `{}`. Screens call it once in `_ready()`.
  - [x] 2.5 Load failure: `_load_screen(screen) -> PackedScene` returns `null` when `ResourceLoader.exists(path)` is false or the load isn't a `PackedScene`. On `null`: `Log.error(&"router", "screen %s failed to load" % Screen.keys()[screen])`, and retry with `MAIN_MENU` (payload cleared). If `MAIN_MENU` itself fails, log it, end the fade (fade back in on the current scene) and stay. **Never loop.** Also treat a non-`OK` return from `change_scene_to_packed()` as a failure.
  - [x] 2.6 Fade overlay is built in code in `_ready()`: a `CanvasLayer` (`layer = 100`) with a full-rect `ColorRect` in night `#2B1D3F`, `modulate.a = 0`, `mouse_filter = MOUSE_FILTER_IGNORE` while idle and `MOUSE_FILTER_STOP` during a transition. `Router.process_mode = PROCESS_MODE_ALWAYS`, so its tweens run while the tree is paused.
  - [x] 2.7 Fade timings are `const FADE_OUT_SEC: float = 0.15` and `const FADE_IN_SEC: float = 0.15` (UX `[ASSUMPTION]`, tune later).
  - [x] 2.8 Signals: `screen_changed(screen: Screen)` (past tense), emitted after the fade-in finishes. Nothing needs it yet; it's cheap and useful for the debug overlay (1.8). Don't add other signals.
  - [x] 2.9 Track `current_screen: Screen` (read-only by convention). Set it after a successful swap. Its initial value is `TITLE`, because the title is the main scene and is never reached through `go()` at boot.
- [x] **Task 3: Font pick** (AC: 3). Stop for Smuck here.
  - [x] 3.1 Download 2–3 candidates (Dev Notes → Font) into a scratch folder, **not** the repo.
  - [x] 3.2 Build a throwaway comparison: either a temporary scene or a screenshot from the built-in browser of a page using the fonts. Show `l I 1 | O 0 | il1 IO0 | Click or press any key | Zombie Run 0123456789` at 16 px and 32 px per candidate. Present it to Smuck with the native pixel size of each candidate.
  - [x] 3.3 After the pick: copy the `.ttf`/`.otf` to `assets/fonts/<font_name>.ttf` (snake_case) and its license as `assets/fonts/<font_name>_OFL.txt`. Remove `assets/.gitkeep` if it's the only thing in `assets/`. Delete the scratch comparison.
  - [x] 3.4 Import settings for the font (`.import` file, via the editor Import dock or by editing the `.import` and re-importing): **Antialiasing = None**, **Hinting = None**, **Subpixel Positioning = Disabled**, Generate Mipmaps off, Multichannel SDF off. Commit the `.import`.
- [x] **Task 4: Theme** (AC: 3)
  - [x] 4.1 Create `data/ui_theme.tres` (`Theme`): `default_font` = the imported font, `default_font_size = 16` (or the smallest multiple of the font's native size that is ≥ 16).
  - [x] 4.2 `project.godot` → `[gui]` `theme/custom="res://data/ui_theme.tres"`. Remove `data/.gitkeep`.
  - [x] 4.3 No button styles yet. `pixel-button`, panels and the rest are Story 5.0 / 4.2. Default Godot button look plus the pixel font is fine for placeholders.
- [x] **Task 5: Title screen** (AC: 2). Rebuild `scenes/screens/title.tscn` (the 1.2 placeholder) and add `scripts/screens/title.gd`.
  - [x] 5.1 Keep: root `Control` `Title` (full rect) and the night `Background` `ColorRect`. Remove `VersionLabel` and the `PixelProbe` (they were 1.2 checks). Replace `TitleLabel` with a **placeholder logo**: a `Label` "Zombies Teach Typing" at 32 px (`theme_override_font_sizes`), centred. The real hand-lettered logo sprite comes later (DESIGN: logos are sprite art). No `[ASSUMPTION]` art is drawn here.
  - [x] 5.2 Add `%Prompt` `Label` "Click or press any key" (copy verbatim from the UX spine), 16 px, color chalk `#F4F1E4` (`title-prompt` token), centred in the lower third. No blinking (no flashing rule, ≤ 3 Hz, and nothing is needed).
  - [x] 5.3 All Controls get `mouse_filter = MOUSE_FILTER_IGNORE`, so clicks reach `_unhandled_input` (a full-rect Control with the default `STOP` would eat them in GUI input).
  - [x] 5.4 `title.gd` (`extends Control`): in `_unhandled_input(event)`, advance on the first `InputEventKey` with `pressed and not echo`, or the first `InputEventMouseButton` with `pressed`. Use a `_advanced: bool` guard so it fires once. On advance: `AudioManager.unlock()`, then `Router.go(Router.Screen.MAIN_MENU)`, then `get_viewport().set_input_as_handled()`. Keep the unlock call **inside the input callback**: the browser's audio-gesture rule needs it there (Story 1.4 relies on it).
  - [x] 5.5 `run/main_scene` stays `res://scenes/screens/title.tscn` (or its `uid://` form if the editor rewrites it). `test_main_scene_is_set_and_loads` must still pass.
- [x] **Task 6: Placeholder screens** (AC: 4). Each one is a scene plus a script at the mirrored path, a night background, a 24 px heading `Label` with the screen name, and `Button`s. Each script calls `Router.take_payload()` once in `_ready()` and shows the payload as text in a small `Label` if it isn't empty (this proves payloads arrive).
  - [x] 6.1 `scenes/screens/main_menu.tscn` + `scripts/screens/main_menu.gd`: "Play" → `Router.go(Router.Screen.RUN, {"level_id": &"zombie_run"})`; "Crypt Closet" → `CRYPT_CLOSET`; "Welcome Gift" (dev-only placeholder button) → `WELCOME_GIFT`. "Play" gets focus on show (`grab_focus()`), so Enter works.
  - [x] 6.2 `scenes/run/run_frame.tscn` + `scripts/run/run_frame.gd`: shows the `level_id` from the payload; "Finish" → `REPORT_CARD` with `{"result": null}` (`RunResult` arrives in 2.3); "Quit" → `MAIN_MENU`. **Story 2.4 replaces this file's content.** It lives at the real path so the Router registry never changes.
  - [x] 6.3 `scenes/screens/report_card.tscn` + `scripts/screens/report_card.gd`: "Play Again" → `RUN` with `{"level_id": &"zombie_run"}`; "Menu" → `MAIN_MENU`.
  - [x] 6.4 `scenes/screens/welcome_gift.tscn` + `.gd`: one button → `CRYPT_CLOSET`.
  - [x] 6.5 `scenes/screens/crypt_closet.tscn` + `.gd`: "Back" button → `MAIN_MENU`, plus Esc (`ui_cancel` in `_unhandled_input`) → `MAIN_MENU`.
  - [x] 6.6 Remove `scripts/screens/.gitkeep`. Create `scenes/run/` and `scripts/run/` (they don't exist yet).
- [x] **Task 7: Verify** (AC: all)
  - [x] 7.1 GUT: all tests pass (22 existing + new), exit 0, no `Parse Error` / `SCRIPT ERROR` lines in the output (CI greps for these).
  - [x] 7.2 Desktop run (`mcp__godot__run_project` or `Godot.exe --path .`): walk Title → (key) Main Menu → Play → Run (shows `zombie_run`) → Finish → Report Card → Menu; and Menu → Crypt Closet → Esc → Menu; Menu → Welcome Gift → Closet. The title advances on a key **and**, after a restart, on a mouse click. Check `mcp__godot__get_debug_output` for errors.
  - [x] 7.3 Fade check: the night fade is visible on each switch, and spamming keys or clicks during a fade doesn't double-navigate or skip a screen.
  - [x] 7.4 Web check (built-in browser): `mkdir -p build/web`, export Web, serve with `python -m http.server 8060 -d build/web` and walk the same flow at `http://localhost:8060/`. The font renders crisp (no blur, no antialiasing smear) at 16 and 32 px. Console has no errors apart from the expected AudioContext warning (1.2 notes).
  - [x] 7.5 Glyph check (AC 3): screenshot `l I 1 O 0` at 16 px and 32 px in the running game. A temporary label on the title is fine; remove it after. Save to `_bmad-output/implementation-artifacts/screenshots/1-3/glyphs.png` and link it in the Dev Agent Record.
  - [x] 7.6 `git status`: new `.uid` and `.import` files are staged; `build/` is untracked.

### Review Findings

- [x] [Review][Patch] Title advances on mouse wheel and Escape, which browsers don't count as a user gesture; exclude both (decision resolved by Smuck: exclude wheel + Escape) [scripts/screens/title.gd:17]
- [x] [Review][Patch] `go()` ignores `_swap_to`'s result: on total failure it still emits `screen_changed` with the old screen, and a failed `go(MAIN_MENU, payload)` leaves `_payload` set for the next screen [scripts/autoloads/router.gd:62]
- [x] [Review][Patch] `go()` doesn't validate `screen`: an out-of-range int raises in `Screen.keys()[screen]` after the tree is paused and faded, freezing the game behind the overlay [scripts/autoloads/router.gd:53]
- [x] [Review][Patch] Payload stored by reference; caller mutations during the 0.15 s fade reach the next screen. Store `payload.duplicate()` [scripts/autoloads/router.gd:82]
- [x] [Review][Patch] Tests add live Title/Menu instances whose `_unhandled_input` and focused buttons call the live `Router.go()`; a keypress during an editor GUT run swaps out the runner. Disable input on instanced screens [tests/unit/test_title.gd, tests/integration/test_screen_flow.gd]
- [x] [Review][Patch] Task 7.6 is checked but nothing is staged: new `.uid`, `.import`, `press_start_2p.ttf` (referenced by `ui_theme.tres`) are all untracked [git index]
- [x] [Review][Patch] Fonts README is missing the font version required by Dev Notes → Font [assets/fonts/README.md:1]
- [x] [Review][Defer] Router sets `paused = false` unconditionally, clobbering any pause owned by someone else (Story 1.5 tab-blur pause) [scripts/autoloads/router.gd:65] — deferred, spec-mandated for now
- [x] [Review][Defer] `go()` during a transition is dropped at DEBUG level, so a redirect from a new screen's `_ready()` (e.g. Welcome Gift → Closet when already claimed) is silently lost [scripts/autoloads/router.gd:53] — deferred, spec-mandated for now
- [x] [Review][Defer] On web, Godot dispatches buffered input from its main loop, not inside the browser event handler; verify the "unlock inside the input callback" assumption when Story 1.4 builds `unlock()` [scripts/screens/title.gd:13] — deferred, belongs to 1.4
- [x] [Review][Defer] Button wiring (targets, payloads, Esc on Closet) and the title's once-only latch aren't tested; needs a Router double [tests/integration/test_screen_flow.gd] — deferred, needs test seam

## Dev Notes

### Scope boundaries (what this story is NOT)

- **No audio.** `AudioManager.unlock()` is an empty stub; Story 1.4 adds buses, the pool and the actual unlock. The call site on the title is wired now.
- **No `WebPlatform` behaviour** (1.5), **no save** (1.6), **no `PlayerData` state** (1.7). The stubs are empty `Node`s.
- **No real Main Menu, Report Card, Welcome Gift or Closet UI.** Those belong to 4.2, 2.9, 4.5 and 4.4. Placeholders are plain Godot Controls with the theme font. No art, no pixel-button styling (5.0), no music crossfade (5.1).
- **No boot splash** (5.0) and no letterbox bar color (deferred to 5.0).
- **No debug overlay** (1.8). Don't add F-key handling.

### Router transition (the exact sequence)

```gdscript
extends Node
## Screen flow: one fade-covered scene swap at a time; payloads go from go() to the next screen's take_payload().

signal screen_changed(screen: Screen)

enum Screen { TITLE, MAIN_MENU, RUN, REPORT_CARD, WELCOME_GIFT, CRYPT_CLOSET }

const SCREEN_PATHS: Dictionary[Screen, String] = {
	Screen.TITLE: "res://scenes/screens/title.tscn",
	Screen.MAIN_MENU: "res://scenes/screens/main_menu.tscn",
	Screen.RUN: "res://scenes/run/run_frame.tscn",
	Screen.REPORT_CARD: "res://scenes/screens/report_card.tscn",
	Screen.WELCOME_GIFT: "res://scenes/screens/welcome_gift.tscn",
	Screen.CRYPT_CLOSET: "res://scenes/screens/crypt_closet.tscn",
}
const FADE_OUT_SEC: float = 0.15
const FADE_IN_SEC: float = 0.15
const FADE_COLOR: Color = Color("#2B1D3F")  # night
```

`go()` (sketch; adapt freely, but keep the order and the guards):

1. If `_transitioning`: `Log.debug(&"router", ...)` and return. Set `_transitioning = true`.
2. `_payload = payload`. `get_tree().paused = true`. Paused screens receive **no** `_input` / `_unhandled_input` and no button presses, so the outgoing screen ignores input during the fade (UX `[ASSUMPTION]`). The Router can't block input itself: the current scene is the last child of root, so it gets `_input` before the autoloads. The overlay switches to `MOUSE_FILTER_STOP`.
3. Tween `modulate:a` 0 → 1 over `FADE_OUT_SEC`; `await tween.finished`. Awaiting is fine here: this isn't a typing callback.
4. `var packed: PackedScene = _load_screen(screen)`. If it's null: log, then fall back to `MAIN_MENU` (if `screen` already was `MAIN_MENU`, skip to step 6 without swapping). Then `var err: Error = get_tree().change_scene_to_packed(packed)`. If `err != OK`, handle it the same way as a null load.
5. `await get_tree().scene_changed`. The swap is **deferred** to the end of the frame, and this signal fires after the new scene is in the tree and `_ready` has run, so the new screen has already called `take_payload()`. Set `current_screen`.
6. Tween 1 → 0 over `FADE_IN_SEC`; await it. `get_tree().paused = false`. The overlay goes back to `MOUSE_FILTER_IGNORE`. `_transitioning = false`. Emit `screen_changed`.

Notes:
- **Unpausing is intentional.** A new screen never starts paused. Story 2.7's Pause → "Quit to Menu" will call `Router.go()` while the tree is already paused; the Router's own pause/unpause covers it. Put a one-line comment on the unpause, because 2.7's dev will look for it.
- `create_tween()` on the Router: tweens bound to a node follow that node's `process_mode`, and the Router is `PROCESS_MODE_ALWAYS`. Also call `tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)` so the fade can't freeze while the tree is paused.
- If `take_payload()` is never called, the next `go()` overwrites the payload, so payloads can't go stale. If the failure fallback goes to `MAIN_MENU`, clear the payload, because the menu must not receive a `RUN` payload.
- Don't use `change_scene_to_file()`: the AC names `change_scene_to_packed`, and the separate load step is what makes failures detectable.
- The architecture's error table: "Fatal to a screen → `Log.error()`, then `Router.go(Screen.MAIN_MENU)`; brains kept". Brains are a non-issue now (no `PlayerData` yet).

### Font

Candidates (all **SIL OFL 1.1**; verify the license file in each download):

| Font | Source | Native grid | Notes |
|---|---|---|---|
| **Pixelify Sans** (recommended default) | `github.com/google/fonts/tree/main/ofl/pixelifysans` → `PixelifySans[wght].ttf` + `OFL.txt` | check, see below | Friendly, mixed case, slightly rounded. Closest to the D11 traits. A variable font: use the default (Regular 400) instance. If Godot renders the variable default oddly, wrap it in a `FontVariation` with `variation_opentype = {"wght": 400}`. |
| Press Start 2P | `github.com/google/fonts/tree/main/ofl/pressstart2p` | 8 px (16/24/32/64 are all clean multiples) | Very legible and safe on sizes, but wide, arcade-flavoured and blocky. Risk: the 32 px target letter is very wide. |
| Another OFL pixel face Smuck likes | itch.io / Font Squirrel | must be stated | Must have mixed case and the five glyphs distinct. Reject all-caps-only faces (Silkscreen) and **CC0/CC-BY fonts** such as monogram or m5x7: the AC says **SIL OFL**. |

- **Native size rule (DESIGN Typography):** every used size (16, 24, 32, 64) must be a whole multiple of the font's native pixel size, or snap to the nearest multiple ≥ the floor. Find the native size by rendering at 1× and counting the pixel rows of a cap height, or from the font's documentation. Record it in the completion notes and in `assets/fonts/README.md` (one line: font, version, license, native px). That README is the only non-media file allowed in `assets/fonts/` (Boundary 6 forbids scripts and `.tres` there; a license and readme are fine, and the architecture says "OFL pixel font + license file").
- If a candidate fails `l`/`I`/`1` or `O`/`0` at 16 px, it's out, however nice it looks.
- Pixel-crisp rendering needs the import settings in Task 3.4. With antialiasing on, Godot's default, glyphs smear under the nearest-filtered fractional stretch. The project's `default_texture_filter = Nearest` doesn't cover font antialiasing.

### Current state of files being modified

- **`project.godot`**: `[application]` (name, `run/main_scene` = title.tscn, features, icon), `[debug]` (`untyped_declaration=2`), `[display]` (640×360, overrides 1280×720, viewport/keep/fractional), `[editor_plugins]` (GUT), `[physics]`, `[rendering]`. **Add** `[autoload]` (5 entries, in order) and `[gui]` (`theme/custom`). **Preserve everything else**: `test_project_settings.gd` guards it. Never open the project with the mono / `Godot_C#.exe` build (it can re-add `[dotnet]`, and `test_dotnet_section_removed` would fail).
- **`scenes/screens/title.tscn`**: 1.2 placeholder, a root `Control` "Title" + `Background` (night) + `TitleLabel` (32 px) + `VersionLabel` + `PixelProbe` (4 orange 1 px lines). No script. This story attaches `title.gd` and replaces the labels and probe. It must stay the main scene and must still load (`test_main_scene_is_set_and_loads`).
- **`.github/workflows/build.yml`**: **no change.** New tests run automatically, and the web export picks up autoloads and the theme. Autoload scripts must parse headless, or CI's import step and GUT grep will fail.
- **`export_presets.cfg`**: no change. `assets/` and `data/` are exported, which is what we want.

### Architecture compliance

- **D1 / Screen Flow:** `Router` autoload, `change_scene_to_packed`, CanvasLayer fade, `go(screen, payload)` / `take_payload()`. `RUN` payload `{ "level_id": StringName }`; `REPORT_CARD` payload `{ "result": RunResult }` (null for now).
- **D2 / ADR-5:** exactly five autoloads, no EventBus. Autoload order `WebPlatform → SaveService → PlayerData → AudioManager → Router`; an autoload may only use **earlier** ones in `_ready()`. `Router` is last, so it may use anything; the stubs use nothing.
- **Autoload scripts have no `class_name`.** Refer to the enum from other scripts as `Router.Screen.MAIN_MENU`. With no `class_name`, the enum is reached through the autoload name. If the parser rejects `Router.Screen` as a **type hint** in another script, type that parameter as `int` and add a comment; the values still come from `Router.Screen.*`. Record which one worked.
- **Boundary 4:** screens navigate only through `Router`; no `get_tree().change_scene_*` anywhere else. Boundary 3 doesn't apply yet.
- **Nothing uses `get_node("/root/...")`.** Autoloads are referenced by name.
- **Logging:** `Log.error/warn/info/debug(&"router", ...)`; tag `&"router"` is already in `Log`'s doc comment. No logs in `_process`. An `info` per screen change is fine (`"→ MAIN_MENU"`), since it's not per frame.
- **Naming:** `snake_case` files; scene ↔ script mirrored (`scenes/screens/title.tscn` ↔ `scripts/screens/title.gd`, `scenes/run/run_frame.tscn` ↔ `scripts/run/run_frame.gd`); `%UniqueName` for nodes referenced from script; handlers `_on_<emitter>_<signal>` (`_on_play_button_pressed`); signals past tense; tabs for indentation.
- **Strict typing:** every `var`, parameter and return is typed (`untyped_declaration = Error`), including tests and stubs. `Dictionary[Screen, String]` typed dictionaries are supported in 4.4+.
- **Copy (NFR9):** player-facing text is "Click or press any key". Placeholder screen names are dev-only and will be replaced; still use plain words, never technical error text.

### File structure requirements

New:
```
scripts/autoloads/web_platform.gd, save_service.gd, player_data.gd, audio_manager.gd, router.gd (+ .uid)
scripts/screens/title.gd, main_menu.gd, report_card.gd, welcome_gift.gd, crypt_closet.gd (+ .uid)
scripts/run/run_frame.gd (+ .uid)
scenes/screens/main_menu.tscn, report_card.tscn, welcome_gift.tscn, crypt_closet.tscn
scenes/run/run_frame.tscn
assets/fonts/<font>.ttf (+ .import), assets/fonts/<font>_OFL.txt, assets/fonts/README.md
data/ui_theme.tres
tests/unit/test_router.gd (+ .uid)
tests/unit/test_ui_theme.gd (+ .uid)
_bmad-output/implementation-artifacts/screenshots/1-3/glyphs.png
```
Modified: `project.godot` (`[autoload]`, `[gui]`), `scenes/screens/title.tscn`, `tests/unit/test_project_settings.gd` (autoload-order test). Deleted: `.gitkeep` in `scripts/autoloads/`, `scripts/screens/`, `data/`, `assets/` (only where real files now exist).

### Testing requirements

GUT 9.7.1 facts that matter here:
- **An unexpected `push_error` or engine error fails the test** (`addons/gut/error_tracker.gd`: `treat_push_error_as` / `treat_engine_errors_as = FAILURE`). So: every test that triggers `Log.error()` must `assert_push_error("[ERROR][router] ...")`, the way `test_log.gd` does. And **check `ResourceLoader.exists(path)` before `ResourceLoader.load(path)`** in `_load_screen`, because loading a missing path raises an engine error ("Resource file not found") that would fail the test and spam the console.
- Autoloads **are** loaded when GUT runs through `gut_cmdln.gd`, but **never call `Router.go()` on the live autoload in a test**: `change_scene_to_packed` would swap out GUT's own runner scene. Test a **fresh instance** instead: `var router: Node = add_child_autofree(load("res://scripts/autoloads/router.gd").new())`. Inside that instance's script, `Screen` and its methods are available.

`tests/unit/test_router.gd` (typed, `extends GutTest`):
- `test_every_screen_has_a_loadable_scene`: for each value in `Router.Screen.values()` (or the fresh instance's), `SCREEN_PATHS` has a key, `ResourceLoader.exists()` is true, and the load `is PackedScene`. This catches a typo in the registry or a missing placeholder.
- `test_take_payload_returns_once`: call `_store_payload(p)` (the small method `go()` uses to store the payload; no test-only setter), then `take_payload()` returns `p` and a second call returns `{}`.
- `test_load_screen_returns_null_and_logs_for_missing_path`: make the path overridable for tests. Simplest: `_load_screen()` reads `_paths: Dictionary[Screen, String]` (initialised from `SCREEN_PATHS` in `_init`); the test replaces one entry with `"res://does_not_exist.tscn"`. Assert `null`, and `assert_push_error("failed to load")` if the log happens inside `_load_screen` (or test the fallback-choosing helper: `_resolve(screen) -> {screen, packed}` returns `MAIN_MENU` plus its scene).
- `test_main_menu_failure_does_not_loop`: with both the target and `MAIN_MENU` paths broken, the resolve helper returns null (no recursion), and 2 errors are pushed (`assert_push_error_count(2)`).
- `test_fade_overlay_is_idle_after_ready`: the fresh instance has a `CanvasLayer` child with `layer >= 100`, and its rect has `modulate.a == 0` and `mouse_filter == MOUSE_FILTER_IGNORE`.

Structure the Router so these are testable **without** the tree swap: keep `go()` as the thin async orchestrator, and put the decisions in small synchronous methods (`_store_payload`, `_load_screen`, `_resolve`). That's the "logic leads" spirit applied to the Router.

`tests/unit/test_project_settings.gd` (add):
- `test_autoloads_registered_in_order`: read `ProjectSettings.get_setting("autoload/WebPlatform")` etc. (each value is `"*res://scripts/autoloads/....gd"`). For order, loop `ProjectSettings.get_property_list()`, collect the names starting with `autoload/` in order, and assert the list equals `["autoload/WebPlatform", "autoload/SaveService", "autoload/PlayerData", "autoload/AudioManager", "autoload/Router"]`. The property list keeps `project.godot` order; if it turns out not to, fall back to checking `get_tree().root.get_children()` order for the five names.
- `test_custom_theme_is_ui_theme`: `gui/theme/custom == "res://data/ui_theme.tres"` (or the uid form; accept either by loading it and checking `is Theme`).

`tests/unit/test_ui_theme.gd`:
- The theme loads as `Theme`; `default_font` isn't null and its `resource_path` starts with `res://assets/fonts/`; `default_font_size >= 16`.
- An OFL license file exists next to the font: `FileAccess.file_exists()` on the license path. Reading a file in a test is fine; the "only SaveService touches files" rule is for game code (1.2 note).
- Glyph presence: `font.has_char(ord(c))` for each of `l I 1 O 0` and for every character in "Click or press any key".

Manual (recorded in the Dev Agent Record): the flow walk (7.2), fade/spam check (7.3), web check (7.4) and glyph screenshot (7.5). Glyph distinctness is a visual judgment; no test can prove it.

Write each test before the code it covers, and see it fail first.

### Previous story intelligence (1.1 and 1.2)

- Godot is **`C:\Program Files\Godot\Godot.exe`** (4.7.2.stable.official, the standard build). The `_console.exe` wrapper is broken. Never use the mono build.
- GUT command: `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`. **A test file that fails to parse is skipped and GUT still exits 0**, so always grep the output for `Parse Error|Failed to load script|SCRIPT ERROR` (CI does). With strict typing that's the most likely trap: e.g. `var x = load(...)` must be `var x: PackedScene = load(...) as PackedScene`.
- New scripts get `.uid` files and `.tscn` files get `uid://` references; commit both. After adding scripts outside the editor, run a headless `--import` (or `--editor --quit`) once so class caches and uids exist before GUT runs.
- `Variant` returns (`ProjectSettings.get_setting`, `ConfigFile.get_value`, `Dictionary.get`) must be assigned to a typed `var` or compared directly.
- `window_width_override=1280` / `height_override=720` give a usable desktop window; keep them.
- The title scene is the export's main scene; the CI web export runs on every push, so a broken title or autoload breaks CI.
- In the built-in browser pane `index.wasm` re-downloads on reload (pane cache); real browsers cache it. That's not a bug.
- The console warning "AudioContext was not allowed to start" is expected until 1.4.
- Firefox isn't installed (deferred-work). This story has no Firefox-specific AC; Chromium checks are enough here.
- 1.2 was closed without code review. Patterns are from the dev record, not a reviewed baseline.

### Git intelligence

- `64cb50f` (1.2): export presets, CI, placeholder title; `9450abe` (1.1): settings, folders, `Log`, `GameConstants`, GUT. Commit style: `Story 1.N: <summary>`, a wrapped body and a Co-Authored-By trailer.
- The working tree has uncommitted edits to the 1.2 story file, `deferred-work.md`, `sprint-status.yaml` and the new `screenshots/` folder (Smuck's 1.2 close-out). Don't revert them; commit only when Smuck asks.

### Latest tech information (checked 2026-10-02)

- `SceneTree.change_scene_to_packed(packed)` returns `OK`, `ERR_CANT_CREATE` (it can't instantiate) or `ERR_INVALID_PARAMETER` (invalid scene). The swap is **deferred** to the end of the frame, with the old scene freed safely.
- `SceneTree.scene_changed` signal: "emitted after the new scene is added to scene tree and initialized. Can be used to reliably access current_scene when changing scenes." It's in the current stable docs. Use it rather than awaiting `process_frame` twice.
- Godot 4.4+ supports typed dictionaries (`Dictionary[K, V]`). Use them.
- Pixel-font import: `FontFile` import options `antialiasing`, `hinting`, `subpixel_positioning`, `generate_mipmaps`, `multichannel_signed_distance_field`. All off/None for pixel crispness.
- Pixelify Sans: Google Fonts, `ofl/pixelifysans/PixelifySans[wght].ttf` with `OFL.txt` (variable weight). Press Start 2P: `ofl/pressstart2p/PressStart2P-Regular.ttf` with `OFL.txt`. Download from `raw.githubusercontent.com/google/fonts/main/ofl/...`. Downloading a font file is a download: ask Smuck before fetching, per session rules.

### Project Structure Notes

- Matches the architecture tree: `scripts/autoloads/` (5 files), `scripts/screens/`, `scenes/screens/`, `scenes/run/run_frame.tscn`, `data/ui_theme.tres`, `assets/fonts/`.
- Variance: `scenes/run/run_frame.tscn` arrives as a placeholder two stories early (2.4 owns the real thing), so the Router registry is final from day one.
- Variance: `assets/fonts/README.md` is a small text note next to the font and license. It isn't a script or a `.tres`, so Boundary 6 holds.
- Variance: Welcome Gift is reachable from a dev-only Main Menu button. In the real flow it is reached only from the Report Card (4.5). The button goes away in 4.2.

### Project Context Rules

- No `project-context.md` exists. The rules come from the architecture's Consistency Rules, Boundaries and Naming, plus 1.1/1.2: strict static typing, `Log` for logging, tests for logic, standard Godot build only, GUT parse-error grep.
- Godot MCP (`mcp__godot__run_project`, `get_debug_output`, `stop_project`) is available for the desktop flow walk.
- The built-in browser does the web check (7.4).

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.3], [#Additional Requirements → Core architecture], [#NonFunctional Requirements NFR7, NFR9, NFR16]
- [Source: _bmad-output/game-architecture.md#Screen Flow], [#Decision Summary D1, D2, D10], [#ADR-5], [#Error Handling (Fatal to a screen)], [#Logging], [#Directory Structure], [#Naming Conventions], [#Architectural Boundaries], [#Communication patterns ("call down, signal up")]
- [Source: ux-designs/ux-zombies-teach-typing-2026-09-27/DESIGN.md#Typography], [#colors: night, chalk], [components.title-prompt]
- [Source: ux-designs/.../EXPERIENCE.md#Information Architecture], [#Voice and Tone (Title copy)], [#Component behaviour: title-prompt], [#State Patterns (Router transition, Title audio locked)], [#Game Feel (Screen change ~0.15 s)]
- [Source: ux-designs/.../.decision-log.md D11 (font deferred, quick fade)]
- [Source: gdd.md#Controls (title screen), #Asset Requirements (Font)]
- [Source: _bmad-output/implementation-artifacts/1-2-web-export-ci-and-github-pages-deploy.md#Dev Agent Record]
- [Source: _bmad-output/implementation-artifacts/1-1-project-settings-folder-skeleton-and-test-harness.md]
- Godot docs: https://docs.godotengine.org/en/stable/classes/class_scenetree.html (`change_scene_to_packed`, `scene_changed`)
- Fonts: https://github.com/google/fonts/tree/main/ofl/pixelifysans · https://github.com/google/fonts/tree/main/ofl/pressstart2p

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Implementation Plan

- Red/green per task. The autoload-order tests failed until `[autoload]` existed. `test_router.gd` failed to parse until `router.gd` existed, and its registry test stayed red until the Task 6 placeholders existed. `test_ui_theme.gd` failed until `ui_theme.tres` and `gui/theme/custom` existed. `test_title.gd` failed until `title.gd` and the rebuilt scene existed. `tests/integration/test_screen_flow.gd` was written **after** the placeholders, as a guard, so it was never seen red.
- Router: `go()` is a thin async orchestrator (pause tree → fade out → `_swap_to` → fade in → unpause). The decisions live in synchronous methods (`_store_payload`, `_load_screen`, `_resolve`), which are tested on a fresh instance through `const RouterScript := preload(...)`. `_swap_to` also falls back to `MAIN_MENU` once when `change_scene_to_packed` returns non-`OK`, and awaits `SceneTree.scene_changed`.
- Added beyond the spec: `is_transitioning()` (read-only accessor, used by a test) and `FADE_LAYER` const.
- `Router.Screen` works as a **static type hint** from other scripts (used in `test_screen_flow.gd`: `func _instance(screen: Router.Screen)`), so the `int` fallback in the Dev Notes wasn't needed.
- **Font: Press Start 2P (Smuck's pick, 2026-10-02).** Pixelify Sans (the story's recommended default) was rejected. Rendered with the game renderer, its `O` and `0` are the same glyph (confirmed from the outlines: same 18-point contour, same advance), `Z` reads as `2` and `5` as `S`, and its ~91-unit grid (~11 px/em) means 16/24/32 px are not whole multiples. That fails NFR7. Press Start 2P has a slashed zero, distinct `l`/`I`/`1`, and an exact 8 px grid (1000 upm / 125-unit step), so 16/24/32/64 are all clean. Trade-off: it's wide and arcade-flavoured rather than "slightly rounded". It's referenced only by `ui_theme.tres`, so it's cheap to swap.
- Title logo: at 32 px Press Start 2P is 32 px per character, so "Zombies Teach Typing" (20 chars) would fill exactly 640 px. Split into two lines ("Zombies" / "Teach Typing"); the test compares with the newline normalised to a space.
- `allow_system_fallback` left at the default (true); not mentioned in the story.

### Debug Log References

- Font grid analysis: fontTools (via `uv run --with fonttools`, scratch only, not a project dependency). Pixelify Sans: variable `wght` 400–700, x coords for `l` 60/161, `I` 60/151/251/343 → ~91-unit step. Press Start 2P: grid step 125 of 1000 → 8 px/em.
- Comparison render: a throwaway `tools/font_compare/font_compare.gd` (`extends SceneTree`, non-headless) captured the root viewport at 640×360 with antialiasing/hinting/subpixel off, and saved a 3× nearest upscale. Deleted after the pick. Evidence: [glyphs.png](screenshots/1-3/glyphs.png) (Press Start 2P at 16/24/32 px, AC 3), [rejected-pixelify-sans.png](screenshots/1-3/rejected-pixelify-sans.png).
- Font import (`press_start_2p.ttf.import`): `antialiasing=0`, `hinting=0`, `subpixel_positioning=0`, `generate_mipmaps=false`, `multichannel_signed_distance_field=false`. Guarded by `test_font_is_imported_pixel_crisp`.
- Desktop flow walk (Task 7.2/7.3): a throwaway SceneTree script (scratchpad, not in repo) ran the real game windowed and injected events with `Input.parse_input_event`. Every step landed on the expected scene, with `paused=false` after each transition: boot → Title; Space → MainMenu; Enter (Play focused) → RunFrame (payload label `{ "level_id": &"zombie_run" }`); Enter → ReportCard; Enter (Menu) → MainMenu; Down+Enter → CryptCloset; Esc → MainMenu; Down×2+Enter → WelcomeGift; Enter → CryptCloset; **Esc + 10 Enters spammed during the fade → a single transition to MainMenu** (one `[INFO][router]` line); `go(TITLE)` then a **mouse click** → MainMenu; a broken REPORT_CARD path → `[ERROR][router] screen REPORT_CARD failed to load` → MainMenu with the payload cleared.
- Web check (Task 7.4): local export exit 0, `python -m http.server 8060`, built-in Chromium. The title renders crisp in Press Start 2P ([title-web.jpg](screenshots/1-3/title-web.jpg)). Click → Main Menu → Enter → Run (payload shown) → Enter → Report Card → Enter → Menu, all walked. Console: no errors. A screenshot 2 s after a key press caught the menu mid fade-in: the browser pane was **hidden**, so `requestAnimationFrame` was paused (WebGL "Attachment has zero size" warnings and a rAF probe that never resolved confirm it), and tweens only advance on rendered frames. It's an environment artefact, not a Router bug; the desktop walk shows the full 0.3 s fade finishing within 0.6 s.
- GUT: `Scripts 8, Tests 54, Passing 54`, exit 0, no `Parse Error` / `Failed to load script` / `SCRIPT ERROR` lines.

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created.
- AC 1 ✅: `Router` autoload with the 6-value `Screen` enum, a path registry, a night CanvasLayer fade (layer 100, 0.15 s out / 0.15 s in), `change_scene_to_packed`, one-shot `take_payload()`, and `Log.error` + `MAIN_MENU` fallback that never loops. The tree is paused during a transition, so the outgoing screen ignores input; `go()` during a transition is ignored. Unit-tested (12 tests) and walked end to end on desktop.
- AC 2 ✅: title shows a placeholder logo (32 px, two lines) and "Click or press any key" (16 px, chalk) in the pixel font. Any key press (not echo or release) or mouse press advances once and calls `AudioManager.unlock()` (stub) inside the input callback. Tested (7 tests) and walked with both key and click.
- AC 3 ✅: Press Start 2P (SIL OFL 1.1) in `assets/fonts/` with `press_start_2p_OFL.txt` and a README (native 8 px). `data/ui_theme.tres` default font, size 16; `gui/theme/custom` set. `l I 1 O 0` distinct at 16 and 32 px (screenshot). Tested (7 tests).
- AC 4 ✅: placeholder Main Menu, Run (`scenes/run/run_frame.tscn`), Report Card, Welcome Gift and Crypt Closet, each reading its payload once. Title → Menu → Run → Report Card → Menu walked on desktop and web; Closet and Welcome Gift also reachable. Integration test (4 tests).
- AC 5 ✅: `[autoload]` registers `WebPlatform → SaveService → PlayerData → AudioManager → Router` (stubs, no `class_name`), guarded by 2 settings tests.
- Not done / follow-ups: Firefox and Edge not checked (no AC requires them here). Godot imports PNGs inside `build/web/` (`index.icon.png.import` etc. exist there since 1.2); harmless because `build/` is gitignored and export-excluded. Logged in `deferred-work.md`.
- Not committed: commit when Smuck asks.

### File List

- `project.godot` (modified: `[autoload]` ×5, `[gui] theme/custom`)
- `scripts/autoloads/web_platform.gd`, `save_service.gd`, `player_data.gd`, `audio_manager.gd`, `router.gd` (+ `.uid` each) (new)
- `scripts/autoloads/.gitkeep` (deleted)
- `scripts/screens/title.gd`, `main_menu.gd`, `report_card.gd`, `welcome_gift.gd`, `crypt_closet.gd` (+ `.uid` each) (new)
- `scripts/screens/.gitkeep` (deleted)
- `scripts/run/run_frame.gd` (+ `.uid`) (new)
- `scenes/screens/title.tscn` (modified: rebuilt with script, logo and prompt; probe and version label removed)
- `scenes/screens/main_menu.tscn`, `report_card.tscn`, `welcome_gift.tscn`, `crypt_closet.tscn` (new)
- `scenes/run/run_frame.tscn` (new, placeholder for 2.4)
- `assets/fonts/press_start_2p.ttf` (+ `.import`), `assets/fonts/press_start_2p_OFL.txt`, `assets/fonts/README.md` (new)
- `assets/.gitkeep` (deleted)
- `data/ui_theme.tres` (new); `data/.gitkeep` (deleted)
- `tests/unit/test_router.gd`, `test_title.gd`, `test_ui_theme.gd` (+ `.uid` each) (new)
- `tests/unit/test_project_settings.gd` (modified: autoload order and singleton tests)
- `tests/integration/test_screen_flow.gd` (+ `.uid`) (new); `tests/integration/.gitkeep` (deleted)
- `_bmad-output/implementation-artifacts/screenshots/1-3/glyphs.png`, `rejected-pixelify-sans.png`, `title-web.jpg` (new)
- `_bmad-output/implementation-artifacts/deferred-work.md` (modified)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified)
- `_bmad-output/implementation-artifacts/1-3-screen-router-and-title-screen.md` (this file)

### Change Log

- 2026-10-02: Story 1.3 implemented: five autoloads registered in order (four stubs plus the Router), Router with a fade-covered `change_scene_to_packed`, one-shot payloads and a MAIN_MENU fallback, Press Start 2P pixel font plus `ui_theme.tres` as the project theme (Pixelify Sans rejected for O/0 ambiguity), the real title screen, and five placeholder screens walking the FR24 skeleton. 54/54 tests. Status → review.
- 2026-10-02: Code review: 7 patches applied (Router failure path, screen validation, payload copy, title ignores wheel and Esc, disabled test instances, staged files, font version), 4 deferred. 57/57 tests. Status → done.
