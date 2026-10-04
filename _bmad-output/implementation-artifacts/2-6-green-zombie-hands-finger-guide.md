---
baseline_commit: beb24d28c69a09f1a6d138feb046b3dbea69abfd
---

# Story 2.6: Green Zombie Hands Finger Guide

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a kid,
I want the zombie hands to light up the finger I should use next,
so that I learn to touch type without looking at a chart.

## Acceptance Criteria

1. **Finger map data.** Given `data/finger_map.tres` (`FingerMap`, `scripts/resources/finger_map.gd`), when it is inspected, then it holds every character in the GDD finger table (letters, digits, punctuation, Space) with hand, finger and a Shift flag, plus the 26 capitals and the shifted symbols of the table's keys (`! @ # $ % ^ & * ( ) _ + : " < > ?`) with `shift = true` and their base key's finger (FR16, architecture "Finger Guide Resolution").
2. **Lookup.** Given `FingerMap.fingers_for(c)`, when it is called with `a`, `J`, `A` and Space, then it returns left pinky; right index + left pinky; left pinky + right pinky; both thumbs (FR17), as `Array[Vector2i]` of `(Hand, Finger)` with the character's own finger first. An unmapped single character logs a warning (`Log.warn(&"hands", ...)`) and returns an empty list; `""` returns an empty list without a warning (no target).
3. **Hands show the next finger.** Given `ZombieHands` in the HUD's hands area (below the target), when the target changes (`TypingSession.target_changed` → `Hud.show_target`, and the first target in `Hud.setup`), then the finger(s) for that character glow brighter green **and** get a pulsing candy-yellow outline (about 2 Hz, 1↔2 px), so the cue doesn't rely on colour alone; every other finger is in its resting state (FR15, NFR8).
4. **Home-row bumps.** The `f` (left index) and `j` (right index) fingertips always show a small bump mark, whatever is lit (FR18).
5. **Robust.** An unmapped or empty target lights no finger and never stops the run (NFR16); a multi-character target lights the finger for its first character (word mode refines this in Story 6.2).
6. **Tests.** Given `tests/unit/test_finger_map.gd` and `tests/unit/test_zombie_hands.gd` (plus additions to `test_hud.gd` / `test_run_frame.gd`), when GUT runs, then all 26 letters, `A`, `J` and Space pass against an independent copy of the GDD table, as do digits, punctuation, shifted symbols, the warning path, the lit/rest states, the pulse, the bumps and the HUD wiring; the full suite has no regressions (401 at the end of 2.5 dev plus any 2.5 review additions; confirm in the first run).

## Tasks / Subtasks

- [x] **Task 1: `FingerMap` resource (AC: 1, 2, 5)**
  - [x] 1.1 Create `scripts/resources/finger_map.gd`: `class_name FingerMap extends Resource`, `##` doc (the GDD touch-typing table, US QWERTY, authored once in `data/finger_map.tres`; `ZombieHands` is the only user). `enum Hand { LEFT, RIGHT }`, `enum Finger { PINKY, RING, MIDDLE, INDEX, THUMB }`.
  - [x] 1.2 `@export var entries: Dictionary[String, Vector3i] = {}`: character → `Vector3i(hand, finger, shift 0/1)` (architecture shape; the typed dictionary saves cleanly in a `.tres` in Godot 4.4+).
  - [x] 1.3 `func fingers_for(c: String) -> Array[Vector2i]`:
    - `c == ""` → `[]`, no log.
    - `c.length() != 1` → `Log.warn` and `[]` (contract: exactly one character; picking the first character is the caller's job, and `ZombieHands` does it, Task 3.4).
    - not in `entries` → `Log.warn(&"hands", "no finger mapping for '%s'" % c)` and `[]`.
    - otherwise `[Vector2i(hand, finger)]`; if `finger == THUMB`, append the **other** hand's thumb (Space lights both thumbs, the table lists Space under both hands); else if `shift == 1`, append the **opposite** hand's `PINKY` (FR17). Always build the result as a typed `Array[Vector2i]` (append, don't assign an untyped literal).
  - [x] 1.4 Also `static func finger_id(hand_finger: Vector2i) -> int` = `hand * 5 + finger` (0–9: left pinky … left thumb, right pinky … right thumb), used by the hands view and tests. Keep it tiny; no other API.
  - [x] 1.5 No GDD table inside `finger_map.gd`: the data lives in the `.tres` (architecture "Static data … as typed Resources"; "no GDD gameplay number as a literal in a script").

- [x] **Task 2: Author `data/finger_map.tres` with a generator tool (AC: 1)**
  - [x] 2.1 Create `tools/gen_finger_map.gd` (`extends SceneTree`, dev-only, same style as `tools/gen_art_prototypes.gd` / `gen_placeholder_audio.gd`: header comment with the run command, non-zero exit on failure). It holds the GDD table in compact form, one string per (hand, finger):
    - Left pinky `1qaz`, left ring `2wsx`, left middle `3edc`, left index `45rtfgvb`
    - Right pinky `0p;/'-=`, right ring `9ol.`, right middle `8ik,`, right index `67yuhjnm`
    - Space → left thumb (the lookup adds the right thumb)
    - Shifted pairs (base key → shifted character, `shift = 1`, base key's hand and finger): `1!` `2@` `3#` `4$` `5%` `6^` `7&` `8*` `9(` `0)` `-_` `=+` `;:` `'"` `,<` `.>` `/?`
    - Capitals: every lowercase letter's uppercase with `shift = 1`, same hand and finger.
    Builds a `FingerMap`, fills `entries`, and `ResourceSaver.save()`s it to `res://data/finger_map.tres`. Prints the entry count. Expected count: **87** = 26 lowercase letters + 10 digits + 7 unshifted punctuation (`; / ' - = . ,`) + 1 Space + 17 shifted symbols + 26 capitals. Assert the count in the tool and print it; a duplicate key in the table is a tool failure (exit 1).
  - [x] 2.2 Keys outside the GDD table (`` ` ~ [ ] { } \ | ``, Tab, Enter) are **not** mapped (Enter/Shift keys are not typed characters; the others never appear in MVP or Pitchfork Panic text). Note this in the tool header.
  - [x] 2.3 Run it: `"/c/Program Files/Godot/Godot.exe" --headless --path . -s tools/gen_finger_map.gd`, then `--import`. Commit the `.tres` (and the tool + `.uid`). The `.tres` is the shipped data; the tool is how it was made (like the art prototypes).

- [x] **Task 3: `ZombieHands` view (AC: 3, 4, 5)**
  - [x] 3.1 Create `scenes/run/zombie_hands.tscn` + `scripts/run/zombie_hands.gd` (architecture paths): root `ZombieHands` (`Control`, size 312×48, `mouse_filter = IGNORE`, `focus_mode = NONE`), `@export var finger_map: FingerMap` set to `data/finger_map.tres` **in the scene** (injection, no hard-coded data path in the script). No `class_name`, matching `hud.gd` (`extends Control`, no class name); tests preload the script or call methods on the node.
  - [x] 3.2 Placeholder drawing with `_draw()` (final art, 2 hands + 10 glow states, is Story 5.0; no PNGs now). Constraints, not pixel-exact art:
    - Two cartoon hands, palms down, fingers up, thumbs inward, mirror-symmetric about the hands area's centre x (156 local = 220 canvas, right under the target sign), inside 312×48 with ≥ 2 px margin.
    - Each hand: a palm block plus four fingers (pinky shortest, middle tallest) and a shorter thumb on the inner side; left hand order (outer → inner) pinky, ring, middle, index, thumb; right hand mirrored.
    - Resting finger: `zombie-green #6CC24A` fill, 1 px `ink #1E1428` outline (DESIGN.md hands tokens).
    - Lit finger: `zombie-green-bright #B8F27C` fill **plus** a `candy-yellow #FFD23F` outline drawn outside the ink outline, width pulsing between 1 and 2 px.
    - Bumps: a small `zombie-green-dark #2E6B26` mark (e.g. 4×2 px) near the tip of the left and right index fingers, drawn in both rest and lit states.
    - Hard pixels only: integer rects, no anti-aliasing (`draw_rect` with `filled = true` plus outline rects; avoid `draw_circle`/polygons with AA), palette colours only.
    Keep the geometry in a few `const` rect tables at the top of the script (named, `##`-commented), so Story 5.0 can swap the drawing for sprites without changing the API.
  - [x] 3.3 Pulse: `const PULSE_HZ: float = 2.0` (`##` EXPERIENCE.md Game Feel `[ASSUMPTION]` "~2 Hz", below the 3 flashes/s limit). `_process(delta)` advances `_pulse_time` only while at least one finger is lit, and switches the outline between 1 and 2 px every half period (`1 / (2 * PULSE_HZ)` = 0.25 s); call `queue_redraw()` only when the width actually changes. The pulse restarts at 2 px whenever the lit fingers change (the new cue starts strong). Deterministic for tests (`_process` driven by hand); no `Tween`, no `await`.
  - [x] 3.4 API (all `##`-documented):
    - `func show_char(target: String) -> void`: `c := target.left(1)`; `_lit = finger_map.fingers_for(c)` if `finger_map` else `[]`; redraw. Called by `Hud`.
    - `func get_lit_fingers() -> Array[Vector2i]` (copy), `func is_lit(hand_finger: Vector2i) -> bool`, `func get_outline_width() -> int` (current pulse width, 0 when nothing is lit), `func get_finger_fill(hand_finger: Vector2i) -> Color`, `func has_bump(hand_finger: Vector2i) -> bool` (true only for left index and right index). These are the test seams and the contract the 5.0 sprite version keeps.
  - [x] 3.5 `finger_map == null` (scene misconfigured): `Log.error(&"hands", ...)` once in `_ready`, then nothing ever lights (NFR16). Not called in tests beyond one case that sets `finger_map = null` before `add_child` and asserts the error and that `show_char("a")` lights nothing.

- [x] **Task 4: Wire into the HUD (AC: 3)**
  - [x] 4.1 `scenes/run/hud.tscn`: instance `zombie_hands.tscn` as `%ZombieHands`, child of `%HandsArea`, filling it (0, 0, 312, 48). `focus_mode = NONE`, `mouse_filter = IGNORE` (the 2.5 `test_focus_and_mouse_rules` walks every HUD control and will catch a miss).
  - [x] 4.2 `scripts/run/hud.gd`: in `setup(...)` after showing the first target, and in `show_target(target)`, call `%ZombieHands.show_char(target)`. Nothing else in `hud.gd` changes. `RunFrame` needs **no change**: it already calls `Hud.setup(config, first_target)` and connects `target_changed → Hud.show_target`.
  - [x] 4.3 Update the `hud.gd` header comment ("hands area below it" → hands live there now, Story 2.6).

- [x] **Task 5: Tests (AC: 6)**
  - [x] 5.1 `tests/unit/test_finger_map.gd`:
    - Load the shipped `res://data/finger_map.tres` as `FingerMap`.
    - An **independent oracle** in the test: the GDD table written out again in the test (`const TABLE := {"1qaz": [L, PINKY], …}`) — do not import the tool's table. For each of the 26 lowercase letters assert `fingers_for(c) == [Vector2i(hand, finger)]` exactly.
    - Digits and unshifted punctuation (`0-9 ; / ' - = . ,`) exactly one finger each, from the same oracle.
    - The four AC cases: `a` → `[LP]`; `J` → `[RI, LP]`; `A` → `[LP, RP]`; `" "` → `[LT, RT]` (exact arrays, order included).
    - Capitals: every `A`–`Z` returns the lowercase finger plus the opposite pinky.
    - Shifted symbols: `!` → `[LP, RP]`; `?` → `[RP, LP]`; `"` → `[RP, LP]`; `(` → `[RR, LP]`; `<` → `[RM, LP]`; `%` → `[LI, RP]`.
    - Unmapped: `"€"` and `` "`" `` → `[]` and `assert_push_warning("[WARN][hands]")`; `""` → `[]` with no warning (check GUT's warning count did not change, or use a fresh test where `assert_push_warning` would fail); `"ab"` → `[]` + warning.
    - Coverage: the shipped `entries` has exactly the expected count and no entry with an out-of-range hand/finger/shift.
    - `finger_id`: left pinky 0, left thumb 4, right pinky 5, right index 8, right thumb 9.
  - [x] 5.2 `tests/unit/test_zombie_hands.gd` (instance the scene, `PROCESS_MODE_DISABLED`, drive `_process` by hand):
    - after `show_char("f")`: only left index lit; its fill is the bright green, all other fills the resting green; `get_outline_width() == 2`;
    - `show_char("A")`: left pinky and right pinky lit; `show_char(" ")`: both thumbs; `show_char("jam")`: right index only (first character);
    - `show_char("")` and an unmapped char: nothing lit, outline width 0, no crash;
    - pulse: lit, width 2 → `_process(0.25)` → 1 → `_process(0.25)` → 2; switching to another letter mid-pulse resets to 2; with nothing lit `_process` leaves width 0;
    - bumps: `has_bump` true for left index and right index only, in every state (nothing lit, `f` lit, `k` lit);
    - NFR8 brightness: the relative luminance of bright vs resting green differs by at least 0.2 (compute `0.2126 R + 0.7152 G + 0.0722 B` on the linearised colours, or Godot's `Color.get_luminance()`), so the cue reads without hue; plus the outline exists only on lit fingers (shape cue);
    - every `Control` in the scene is `FOCUS_NONE` and mouse-ignoring;
    - `finger_map = null` case (Task 3.5).
  - [x] 5.3 `tests/unit/test_hud.gd`: after `setup(config, "f")` the hands light left index; `show_target("j")` lights right index; the hands node sits at `%HandsArea`'s rect (64, 308, 312, 48 in canvas terms). Keep every 2.5 test unchanged and passing.
  - [x] 5.4 `tests/integration/test_run_frame.gd`: with a fixed seed, the hands light the finger for `get_session().get_current_target()` while waiting, and after a correct key they light the finger for the new target in the same call (`handle_key` returned → `is_lit` already true); a wrong key leaves the lit finger unchanged.
  - [x] 5.5 Mutation checks (one change at a time, restore and diff-verify, log them): (a) drop the opposite-pinky rule → capital/`J`/`A`/symbol tests fail; (b) light the **same** hand's pinky → `J` and `A` fail; (c) Space returns one thumb → Space test fails; (d) a typo in one tool string (e.g. `q` under ring) regenerated into the `.tres` → the oracle letter test fails (then regenerate back); (e) pulse never toggles → pulse test fails; (f) bumps drawn only when unlit (`has_bump` tied to lit state) → bump test fails; (g) `show_target` stops forwarding to the hands → the HUD and run-frame hands tests fail.

- [x] **Task 6: Run and verify (AC: 6)**
  - [x] 6.1 Red first: write `test_finger_map.gd`, `test_zombie_hands.gd` and the HUD/run-frame additions before the code; record the parse errors and failures. GUT exits 0 on parse failures, so judge by the pass count.
  - [x] 6.2 Generate the map (Task 2.3), `--import`, then run GUT: `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`. All pass; no `Parse Error`, `Failed to load script`, `SCRIPT ERROR`, GUT warnings. Commit `.uid` files.
  - [x] 6.3 Boundary greps: no `await` in `zombie_hands.gd`, `finger_map.gd`, `hud.gd`; no autoload names (`Router`, `PlayerData`, `AudioManager`, `SaveService`, `WebPlatform`) in `zombie_hands.gd` / `finger_map.gd`; no `res://data` path literal in `zombie_hands.gd` or `hud.gd`; `tools/` stays excluded from exports (`tools/*` is in both presets' `exclude_filter`; nothing to change).
  - [x] 6.4 Visual check in the built-in browser pane (web debug export, `web-debug` launch entry on :8060, as in 2.4/2.5): start the test level and screenshot the waiting state (first letter's finger lit and pulsing, f/j bumps visible) and two or three letters later (the lit finger moves). Compare with the Run HUD mock frame A (left index lit for `f`, bumps). Show Smuck; record the reaction in the Debug Log. Also look at one screenshot in grayscale (any image tool, or the pane's zoom on a desaturated copy) and confirm the lit finger still stands out (NFR8; the formal grayscale review is Story 5.2).
  - [x] 6.5 `deferred-work.md`: add "Deferred from: dev of story-2-6": placeholder code-drawn hands until Story 5.0 (2 hand sprites + 10 glow states); word/paragraph mode must pass the cursor character, not the whole target (6.2/8.2); unmapped keys (`` ` ~ [ ] { } \ | ``) for Epic 8 punctuation if paragraphs ever use them; non-US layouts show US fingers (GDD A1, accepted).

### Review Findings

- [x] [Review][Patch] The last target's finger keeps pulsing through the end-of-run outro (and would through a pause): nothing clears the hands on `ENDING`, so they cue a key that is no longer accepted. Add `Hud.clear_hands()` and call it on `ENDING` next to `set_caps_hint(false)`, with a test [scripts/run/run_frame.gd:185-191, scripts/run/hud.gd:97-100]
- [x] [Review][Patch] `show_char` resets the pulse on every call, so a repeated letter ("ff", or the same letter dealt twice) keeps the outline at its strong width and the 2 Hz pulse goes static; only reset when the lit set changes [scripts/run/zombie_hands.gd:64-69]
- [x] [Review][Patch] Header comments in `zombie_hands.gd` and `hud.gd` say they touch "any autoload", but both use `Log` (the spec requires it); say "no autoload but Log", and rewrap the over-long `hud.gd` header line [scripts/run/zombie_hands.gd:1-7, scripts/run/hud.gd:1-6]
- [x] [Review][Defer] An unmapped first character (newline, tab, curly quote, accent, `` ` ~ [ ] { } \ | ``) lights no finger and logs a warning on every `target_changed` — deferred, the Epic 6/8 text sources decide whether such characters occur; dedupe the warning or extend the map then [scripts/resources/finger_map.gd:26-28] — deferred, pre-existing
- [x] [Review][Defer] The pulse runs from `ZombieHands._process`, so it keeps animating if Story 2.7 pauses through `RunFrame` state instead of the tree — deferred to Story 2.7 [scripts/run/zombie_hands.gd:51-60] — deferred, pre-existing

Dismissed as noise (22): all 87 finger-map entries verified correct by two layers; `has_bump` ignoring the hand (valid inputs only, spec wording); lit-cue contrast (brightness plus outline per DESIGN.md tokens and NFR8, test threshold met); outline partly under the palm and `_draw` untested (placeholder drawing until Story 5.0); tests using local colour copies, constant-vs-itself and root-only focus checks; copy-pasted oracle table (the explicit acceptance-case tests cover it); `_finger_for` taking `[0]` (test level is lowercase letters); hard-coded hands rect in the HUD test; `finger_id` used only by tests (spec'd API); generator under `-s` (the `.tres` exists); `show_target` re-warning; unbounded `_pulse_time`; `setup()` reaching the hands through `show_target`; hands area geometry.

## Dev Notes

### What this story is (and isn't)

- It adds the **finger guide**: a data table (`FingerMap`), a view (`ZombieHands`) in the HUD's empty 48 px hands area from 2.5, and two one-line calls in `Hud` that keep the view in step with the target. Nothing new reaches `RunFrame`.
- **New files:** `scripts/resources/finger_map.gd`, `data/finger_map.tres`, `tools/gen_finger_map.gd`, `scenes/run/zombie_hands.tscn`, `scripts/run/zombie_hands.gd`, `tests/unit/test_finger_map.gd`, `tests/unit/test_zombie_hands.gd`.
- **Updated files:** `scenes/run/hud.tscn` (instance), `scripts/run/hud.gd` (forward the target), `tests/unit/test_hud.gd`, `tests/integration/test_run_frame.gd`, `deferred-work.md`.
- **Don't build:** final hand art or glow sprites (5.0), word-cursor / paragraph-cursor logic (6.2 / 8.2), any change to `TypingSession`, `RunFrame` or `TypingInput`, a settings toggle for the hands, non-US layouts (out of scope, EXPERIENCE.md Accessibility).

### The GDD table (source of truth) and what the map adds

| Finger | Left hand | Right hand |
|---|---|---|
| Pinky | `1 q a z`, Left Shift | `0 p ; / ' - =`, Right Shift, Enter |
| Ring | `2 w s x` | `9 o l .` |
| Middle | `3 e d c` | `8 i k ,` |
| Index | `4 5 r t f g v b` | `6 7 y u h j n m` |
| Thumbs | Space | Space |

- **Capitals and shifted symbols:** the character's own finger **and the opposite hand's pinky** (Shift). `J` (right index) → also left pinky; `A` (left pinky) → also right pinky; `?` (right pinky, `/` key) → also left pinky.
- **Shift keys and Enter** are listed in the table as keys the pinkies press, but they are never typed characters (`TypingInput` ignores them), so they are not map entries; the Shift pairing rule covers Shift.
- **Space** lights both thumbs (both hands list it). The map stores one entry; `fingers_for` adds the other thumb.
- Result order: the character's own finger first, then the partner (other thumb or opposite pinky). Tests assert exact order so the 5.0 art or a future "primary finger" cue can rely on it.

### Existing code: current state, what changes, what must be preserved

- **`scripts/run/hud.gd`** (2.5, committed `beb24d2`): a pure view, no autoloads. `setup(config, first_target)` sizes the target by mode, shows the first target, resets stats/prompt/hint; `show_target(target)` sets `%TargetLabel` and re-lays the sign; `_process` runs the 0.2 s shake; `update_clock`, `set_counts`, `set_brains`, `hide_start_prompt`, `set_caps_hint`, `shake_target`, `pause_pressed`. **Add** the two `%ZombieHands.show_char(...)` calls only. **Preserve** the shake (only the glyph moves: the hands must **not** shake), layout rects, and all 29 `test_hud.gd` tests.
- **`scenes/run/hud.tscn`**: `%HandsArea` is an empty `Control` under `%TargetArea` at local (0, 52)–(312, 100), i.e. canvas (64, 308, 312, 48), `mouse_filter = IGNORE`. Put `%ZombieHands` inside it.
- **`scripts/run/run_frame.gd`** (2.4/2.5): calls `%Hud.setup(config, _session.get_current_target())` after the session exists and connects `_session.target_changed` → `%Hud.show_target`. Synchronous; `handle_key()` returns after the HUD has updated. **Not modified.**
- **`scripts/typing/typing_session.gd`**: `target_changed(next)` fires after every correct key with the new current target (one character in letter mode). Not modified.
- **`tools/gen_art_prototypes.gd`, `tools/gen_placeholder_audio.gd`**: the house style for dev tools (`extends SceneTree`, run headless with `-s`, header comment with the command, explicit exit code). Follow it.
- **`export_presets.cfg`**: excludes `tools/*` (Epic 1). Check the new tool stays excluded (`test_export_presets.gd` may already assert this).

### Visual spec (DESIGN.md + mock), placeholder level

- DESIGN.md Components → Zombie hands: two cartoon green hands, palms down, `zombie-green` with ink outline, 48 px tall; next finger `zombie-green-bright` **and** a pulsing 1–2 px `candy-yellow` outline ("brightness plus shape, never hue alone"); `f`/`j` fingertips carry a `zombie-green-dark` bump at all times.
- EXPERIENCE.md Game Feel: active finger pulse ~2 Hz `[ASSUMPTION]`, below any flash-risk threshold (≤ 3 flashes/s).
- Mock frame A: hands centred under the target sign; left index lit for `f`; thumbs inward; f/j bumps visible. Its outline reads 2–3 px at the widest pulse frame; DESIGN.md (the spine) says 1–2 px, so use 1–2.
- Colour contrast for the cue is by design: resting `#6CC24A` vs bright `#B8F27C` (clearly brighter), plus the candy outline only on the lit finger. The grayscale review is formally Story 5.2; Task 6.4 is an early look.
- Art standard (art style sheet): palette only, 1 px ink outline, hard pixels, Nearest. Code-drawn placeholder rectangles satisfy this; no new PNGs in this story.

### Testing approach

- Same pattern as 2.4/2.5: instances `PROCESS_MODE_DISABLED`, `_process(delta)` driven by hand, state read through the view's getters (not pixels).
- Warnings: `Log.warn` → `push_warning`; assert with `assert_push_warning("[WARN][hands]")`.
- The finger-map test must use its **own** copy of the GDD table (independent oracle), so a typo in the tool is caught (mutation (d)). Previous art tests used the same "independent oracle" idea for the palette (1.9).
- Every test must be able to fail (Task 5.5). Contract `assert`s are never called in tests (this story has none; contract issues log instead).

### Coding conventions

- Static typing everywhere (`untyped_declaration = Error`); typed `Dictionary[String, Vector3i]` and `Array[Vector2i]`.
- `##` docs on every public member; `_on_<node>_<signal>` names; constants `UPPER_SNAKE`; enums PascalCase with UPPER values.
- Logging tag `&"hands"` (architecture example). No logging in `_process` or per key, except the unmapped-character warning (rare; accepted).
- "Call down": `Hud` calls `ZombieHands.show_char`; the hands never look up the session, autoloads or the clock.

### Project Structure Notes

- Matches the architecture tree exactly: `scripts/resources/finger_map.gd`, `data/finger_map.tres`, `scenes/run/zombie_hands.tscn`, `scripts/run/zombie_hands.gd`, test `tests/unit/test_finger_map.gd` (named in the architecture and the epic).
- `tools/gen_finger_map.gd` is new; `tools/` is the architecture's place for offline scripts.
- Architecture's data flow says `ZombieHands` "listens to `TypingSession.target_changed`". Here the HUD forwards the target instead (the HUD already receives `target_changed` from `RunFrame`, and the hands are the HUD's child: "call down", no sibling wiring). Same timing, fewer connections; note it in the Completion Notes.

### Previous story intelligence (2.5, 2.4)

- **2.5:** the approved sketch fixes the hands area at canvas (64, 308, 312, 48) with the target centred at x = 220; the HUD is a pure view driven by `RunFrame`; `test_hud.gd` checks every control's focus/mouse rules and font glyphs; the shake moves only `%TargetLabel` (the hands must stay still on a wrong key, mock frame C). Review lesson: state that must reset at run end needs an explicit test (they fixed the Caps hint in `ENDING`); the hands keep showing the last target through the outro, which is fine.
- **2.4/2.5:** the web debug build in the built-in browser pane works for visual checks (`.claude/launch.json` → `web-debug`); the pane's `type` action sends no keydown events, use `key` presses; it cannot send Shift+letter as a capital.
- GUT trap: a preload constant named `Test…` is treated as an inner test class.
- Habits: red run first; one-change mutation checks with byte-for-byte restore; `##` docs; exact assertions.

### Git intelligence

- One commit per story; 2.5 is `beb24d2 Story 2.5: shared HUD with wrong-key feedback`. Use `Story 2.6: green zombie hands finger guide` if Smuck asks.
- No new dependencies.

### Latest tech notes (Godot 4.7.2)

- Typed dictionaries (`Dictionary[String, Vector3i]`) export and save in `.tres` since 4.4; `ResourceSaver.save(resource, path)` returns an `Error`.
- `Control._draw()` with `draw_rect(rect, color, filled)`; `queue_redraw()` to repaint. With `snap_2d_transforms_to_pixel` on and integer rects, edges stay crisp.
- `Color.get_luminance()` returns perceived luminance (0–1), handy for the NFR8 test.
- `String.left(1)` is safe on an empty string (returns `""`).

### Project Context Rules

No `project-context.md` exists in this repo. Binding rules come from `_bmad-output/game-architecture.md` (Finger Guide Resolution, Static Game Data, Communication Patterns, Project Structure) and the UX spines `UX/DESIGN.md` / `UX/EXPERIENCE.md` (spines > mocks > sketches). Tools: Godot binary at `/c/Program Files/Godot/Godot.exe`; the built-in browser pane for the visual check.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 2.6: Green Zombie Hands Finger Guide] — story and BDD acceptance criteria.
- [Source: _bmad-output/planning-artifacts/epics.md#Functional Requirements] — FR15, FR16, FR17, FR18; NFR6, NFR8, NFR16.
- [Source: _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md#Finger Guide (Green Zombie Hands)] — the finger table, Shift pairing, f/j bumps; A1 US QWERTY.
- [Source: _bmad-output/game-architecture.md#Finger Guide Resolution] — `FingerMap` shape, `fingers_for` example, unit-test cases.
- [Source: UX/DESIGN.md#Components → HUD → Zombie hands; front-matter `components.zombie-hands`] — colours, 48 px, pulse outline, bumps.
- [Source: UX/EXPERIENCE.md#zombie-hands, #Game Feel & Juice (Active finger), #Accessibility] — behaviour, ~2 Hz pulse, never colour alone.
- [Source: UX/mockups/key-run-hud.html] — frame A (left index lit for `f`, bumps), frame C (hands do not react to a wrong key).
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/sketches/hud-band-2-5.md] — approved hands-area rect.
- [Source: _bmad-output/implementation-artifacts/2-5-shared-hud-with-wrong-key-feedback.md] — HUD API and test patterns.

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Debug Log References

- Baseline: 402 tests (401 at 2.5 dev + 1 from the 2.5 review).
- Red run (6.1): new tests and the HUD / run-frame additions written first. Parse errors: `Could not find type "FingerMap"`, `Assigned value for constant "L" / "PINKY" / ... isn't a constant expression`, `"HandsScript" is a constant but does not contain a type`. Because `test_hud.gd` and `test_run_frame.gd` now name `FingerMap`, they failed to parse too: 34 scripts, 345 tests, 345 passing (402 - 29 HUD - 28 run-frame).
- Generator: `tools/gen_finger_map.gd` printed `finger map: 87 entries (expected 87)` and `res://data/finger_map.tres -> OK`, exit 0.
- Green: 38 scripts, 436 tests, 436 passing on the first run; no `Parse Error`, `Failed to load script`, `SCRIPT ERROR` or GUT warning. Fixed the HUD scene header's stale `load_steps` (10 -> 11) after adding the hands instance.
- Pulse test deltas use binary-exact values (0.125 + 0.125) so the half-period boundaries never hinge on float rounding.
- Mutation checks (5.5), one change at a time, by a script that restores each source byte for byte (and, for (d), regenerates the `.tres` and checks it is byte-identical to the shipped one):
  - (a) no opposite-pinky rule: `test_acceptance_cases`, `test_every_capital_adds_the_opposite_pinky`, `test_every_shifted_symbol_uses_its_base_key`, `test_shifted_symbols`, `test_capital_lights_both_pinkies` fail.
  - (b) the same hand's pinky: the same five tests fail.
  - (c) Space returns one thumb: `test_acceptance_cases`, `test_space_lights_both_thumbs` fail.
  - (d) tool typo (`q` moved from left pinky to left ring), regenerated into the `.tres` (still 87 entries): `test_every_lowercase_letter`, `test_every_capital_adds_the_opposite_pinky` fail (the independent oracle catches it); regenerated back, `.tres` byte-identical.
  - (e) the pulse never toggles: `test_pulse_toggles_every_quarter_second`, `test_new_letter_restarts_the_pulse_strong` fail.
  - (f) bumps only when unlit: `test_bumps_on_f_and_j_in_every_state` fails.
  - (g) `show_target` stops forwarding to the hands: `test_hands_follow_the_target` (HUD) and `test_hands_light_the_next_finger` (run frame) fail.
- Boundary greps (6.3): no `await` in `zombie_hands.gd`, `finger_map.gd`, `hud.gd`; no autoload names in `zombie_hands.gd` / `finger_map.gd`; no `res://data` literal in `zombie_hands.gd` / `hud.gd`; no `draw_circle` / polygons / anti-aliasing in the hands; `tools/*` excluded in both export presets (unchanged).
- 6.4 visual check (web debug export, browser pane, `web-debug` on :8060): waiting on `h` lit the right index finger (bright green, candy-yellow outline), f/j bumps visible on both index fingertips, hands centred under the target sign; after typing `h` the target became `v` and the left index lit while the right returned to rest. Grayscale (CSS `grayscale(1)` on the canvas): the lit finger still stands out (lighter fill plus the outline ring). Differences from mock frame A are placeholder art only (blocky rect hands, smaller than the mock's). **Smuck, 2026-10-04: "Good for a placeholder".**

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created
- `FingerMap` resource (`Hand`, `Finger` enums; `entries: Dictionary[String, Vector3i]`; `fingers_for(c)` with the own finger first, then the other thumb for Space or the opposite pinky for shifted characters; `""` silent, unmapped or multi-character input warns with `[WARN][hands]`; `finger_id`). No table in the script.
- `tools/gen_finger_map.gd` writes `data/finger_map.tres` (87 entries: 26 letters, 10 digits, 7 punctuation, Space, 17 shifted symbols, 26 capitals); fails on a duplicate key or a wrong count.
- `ZombieHands` (`scenes/run/zombie_hands.tscn`, `scripts/run/zombie_hands.gd`): two mirrored code-drawn hands in 312 x 48 (hard-pixel rects, palette colours), lit fingers bright green plus a candy-yellow outline pulsing 2 <-> 1 px at 2 Hz (restarts strong on every new cue), f/j bumps always on, `finger_map` injected in the scene, `[ERROR][hands]` and nothing lit when it is missing. Getters are the contract for Story 5.0's sprites.
- HUD: `%ZombieHands` instanced in `%HandsArea`; `Hud.show_target()` forwards the target (and `setup()` reaches it through `show_target()`), so `RunFrame` is unchanged. Design note: the architecture has `ZombieHands` listening to `TypingSession.target_changed`; the HUD forwards it instead (same call stack, no sibling wiring).
- Tests: new `test_finger_map.gd` (13, independent GDD oracle), `test_zombie_hands.gd` (16); `test_hud.gd` +3 (hands follow the target, fill the hands area, do not shake), `test_run_frame.gd` +2 (lit finger tracks the session target in the same call; a wrong key leaves it). Suite 402 -> 436.
- `deferred-work.md`: new "dev of story-2-6" section.

### File List

- `scripts/resources/finger_map.gd` (new) + `.uid`
- `tools/gen_finger_map.gd` (new) + `.uid`
- `data/finger_map.tres` (new, generated)
- `scripts/run/zombie_hands.gd` (new) + `.uid`
- `scenes/run/zombie_hands.tscn` (new)
- `scenes/run/hud.tscn` (modified: `%ZombieHands` instance)
- `scripts/run/hud.gd` (modified: forwards the target to the hands)
- `tests/unit/test_finger_map.gd` (new) + `.uid`
- `tests/unit/test_zombie_hands.gd` (new) + `.uid`
- `tests/unit/test_hud.gd` (modified)
- `tests/integration/test_run_frame.gd` (modified)
- `_bmad-output/implementation-artifacts/deferred-work.md` (modified)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified)
- `_bmad-output/implementation-artifacts/2-6-green-zombie-hands-finger-guide.md` (this story)

## Change Log

- 2026-10-04: Story 2.6 implemented: FingerMap resource and generated data, ZombieHands placeholder view with the pulsing lit finger and f/j bumps, HUD wiring; 34 new tests (suite 402 -> 436), mutation-checked; visual and grayscale check in the browser pane, placeholder look approved by Smuck. Status -> review.
