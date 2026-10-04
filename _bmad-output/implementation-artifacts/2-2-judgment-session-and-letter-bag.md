---
baseline_commit: b258390b9a61aae0ccdb13d66ef1467066bf1141
---

# Story 2.2: Judgment Session and Letter Bag

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a kid,
I want the right letter to be accepted instantly and a wrong letter to simply not count,
so that typing feels fair and snappy.

## Acceptance Criteria

1. **`TargetSource` base.** Given `TargetSource` (`scripts/typing/target_source.gd`, `class_name TargetSource extends RefCounted`), when it is inspected, then it has `peek(n: int) -> Array[String]`, `current() -> String` and `advance() -> void`; the base implementations are safe no-ops (`peek` returns `[]`, `current` returns `""`) and `LetterBagSource` overrides all three (FR29, architecture "Typing Pipeline").
2. **Bag rules.** Given `LetterBagSource` built with an injected `RandomNumberGenerator` and a letter pool, when letters are drawn, then every letter in the pool appears exactly once before any repeat, and the same letter never appears twice in a row, **including across bag boundaries** (FR29). Verified over 1,000 draws with several seeds.
3. **Seeded determinism.** Given two `LetterBagSource`s built with RNGs seeded identically and the same pool, when each is advanced the same number of times, then they produce identical sequences; a different seed produces a different sequence (replay by seed, Story 2.10).
4. **Correct key.** Given a `TypingSession` (`RefCounted`, no nodes) holding a `TargetSource`, when `judge(c)` receives the expected character, then it emits `char_accepted(expected, index)` and `target_changed(next)` synchronously inside the same call (no `await`, no deferred call), `index` is the zero-based count of targets accepted so far, and `run_started` is emitted **on the first correct key only** (FR1, FR6).
5. **Wrong key.** Given the same session, when `judge(c)` receives a different printable character, then it emits `char_rejected(expected, typed)`, the target does **not** advance, `target_changed` is not emitted, and the error count rises by 1 (FR2). A wrong key before the first correct key counts as an error but does **not** emit `run_started`.
6. **Per-key record.** Given a sequence of judgments, when the per-key record is read, then each expected character has attempts, errors and a map of what was typed instead, in the run-record shape `"f": [14, 3, {"g": 2, "d": 1}]` (`[attempts, errors, {typed: count}]`) (FR9). Attempts count every judgment against that expected character (correct and wrong).
7. **Counters.** Given a session, then `keys_typed` (correct keys) and `errors` (wrong keys) are readable, and `judge` returns a `Verdict` (`CORRECT` or `WRONG`) so callers can branch without listening to signals.
8. **Tests.** Given `tests/unit/test_typing_session.gd` and `tests/unit/test_letter_bag_source.gd` (plus `test_target_source.gd` or a section in one of them), when GUT runs, then judgment, first-key start, per-key tracking and the bag rules (1,000 draws, several seeds) are covered and pass, and the full suite has no regressions (238 tests passing at `HEAD` `b258390`).

## Tasks / Subtasks

- [x] **Task 1: `TargetSource` base (AC: 1)**
  - [x] 1.1 Create `scripts/typing/target_source.gd`: `class_name TargetSource` then `extends RefCounted`, a `##` doc comment (interface for what the player types next; `LetterBagSource` now, `WordSource` Epic 6, `ParagraphSource` Epic 8; pure logic, no nodes, no autoloads).
  - [x] 1.2 Methods, fully typed: `func peek(_n: int) -> Array[String]: return []`, `func current() -> String: return ""`, `func advance() -> void: pass`. Doc-comment each: `peek(n)` returns the `n` targets *following* the current one, so the Zombie Run queue = `current()` + `peek(3)` (architecture: "at most the active target plus the next 3"). `peek` never consumes anything. No other methods (YAGNI: later sources add their own).
  - [x] 1.3 Do **not** use `@abstract` (GDScript 4.5+ feature, not used anywhere in this repo); a plain base with safe defaults keeps `TypingSession` testable with a stub subclass.

- [x] **Task 2: `LetterBagSource` (AC: 2, 3)**
  - [x] 2.1 Create `scripts/typing/letter_bag_source.gd`: `class_name LetterBagSource extends TargetSource`. Constructor: `func _init(rng: RandomNumberGenerator, pool: Array[String]) -> void`. Store both. The RNG is **injected**; never create one inside, never call `randi()`/`randf()`/`shuffle()` (global RNG) anywhere in `scripts/typing/` (architecture "Randomness", boundary grep in Task 6).
  - [x] 2.2 Contract checks in `_init`: `assert(rng != null)` and `assert(pool.size() >= 2)` (a one-letter pool cannot satisfy "no immediate repeat"; an empty pool cannot draw). On violation `Log.error(&"typing", ...)` and fall back to a safe state: null rng → create a fresh `RandomNumberGenerator.new()` is **not** allowed (hides bugs and breaks seeding); instead leave the source empty so `current()` returns `""`. Pool duplicates are a contract violation too: dedupe silently is wrong, assert instead. Tests do **not** construct invalid sources (an `assert` fails the GUT run, as in 2.1 Task 5.10); cover the guards by code review and say so in the Debug Log.
  - [x] 2.3 Internal state: `_pool: Array[String]`, `_queue: Array[String]` (already drawn, not yet consumed; index 0 is `current()`), `_bag: Array[String]` (letters still to deal in the current bag), `_last: String` (last letter placed in `_queue`, for the boundary rule). Fill `_queue` lazily so `peek(n)` for any `n` works: `_ensure(count)` deals letters until `_queue.size() >= count`.
  - [x] 2.4 Dealing a new bag: copy `_pool` to `_bag`, shuffle it **with the injected rng** using a Fisher-Yates loop (`for i in range(size - 1, 0, -1): var j := rng.randi_range(0, i); swap`). `Array.shuffle()` uses the global RNG, not the injected one, so it must not be used. Boundary rule: if the first letter of the freshly shuffled bag equals `_last`, swap it with a different position (e.g. the last element; the pool has >= 2 distinct letters, so this always resolves). Within a bag no letter can repeat because letters are unique.
  - [x] 2.5 Behaviour: `current()` returns `_queue[0]` after `_ensure(1)`; `peek(n)` returns `_queue[1..n]` after `_ensure(n + 1)` (a copy, typed `Array[String]`); `advance()` removes `_queue[0]` and keeps at least the current target dealt. `peek(0)` returns `[]`; negative `n` is treated as 0.
  - [x] 2.6 Deal order vs `peek`: because letters are placed in `_queue` in dealing order, calling `peek(5)` before `advance()` must not change the sequence later seen by `current()`. Test: draw-by-advancing vs draw-with-big-peeks give identical sequences for the same seed.
  - [x] 2.7 Pool is the constructor argument, never hard-coded in this file. Story 2.4's test level passes the 26 lowercase letters (MVP: "Zombie Run uses all 26 letters on every run"); Epic 7 passes tier rows. A `GameConstants` constant is **not** needed now; the caller supplies the pool (a small helper `static func alphabet() -> Array[String]` in the test level in 2.4 is fine).

- [x] **Task 3: `TypingSession` (AC: 4, 5, 6, 7)**
  - [x] 3.1 Create `scripts/typing/typing_session.gd`: `class_name TypingSession extends RefCounted`, `##` doc: pure logic, no nodes, no autoloads, no clock, no `await`; `RunFrame` (Story 2.4) owns the instance and forwards `TypingInput.char_typed` into `judge()` only in `WAITING_FIRST_KEY`/`RUNNING`.
  - [x] 3.2 `enum Verdict { CORRECT, WRONG }`. Signals (typed, past tense, ADR-5 local ownership): `run_started`, `char_accepted(expected: String, index: int)`, `char_rejected(expected: String, typed: String)`, `target_changed(next: String)`. `target_completed(target)` is **not** declared in this story (architecture lists it, but it only has meaning for word/paragraph targets; Epic 6 adds it with `WordSource`). Note this in the file doc comment so nobody "fixes" it.
  - [x] 3.3 `func _init(source: TargetSource, config: LevelConfig = null) -> void`. The architecture example is `TypingSession.new(_level.create_target_source(_rng), _level.get_level_config())`, so accept both arguments now. `config` is stored but not read by anything in this story (case/space rules live in `TypingInput`); keep it for later stories (implied spaces for word mode, Story 2.3/6.2). `assert(source != null)` + `Log.error(&"typing", ...)`; with a null source `judge()` returns `Verdict.WRONG` without emitting (never reached in tests; cover by review).
  - [x] 3.4 State, readable through typed getters or `var` with leading `##` docs: `keys_typed: int`, `errors: int`, `started: bool`, `_per_key: Dictionary` (`String -> [attempts, errors, {typed: count}]`), `_accepted_index: int`. Expose `get_keys_typed()`, `get_errors()`, `has_started()`, `get_per_key() -> Dictionary` (returns a **deep copy** via `duplicate(true)`, so callers (RunResult, 2.3) cannot mutate session state). `get_current_target() -> String` delegates to `source.current()`; `get_upcoming(n) -> Array[String]` delegates to `peek(n)` (HUD/hands need them in 2.5/2.6, but they also receive `target_changed`).
  - [x] 3.5 `func judge(c: String) -> Verdict`, in this order, all synchronous:
    1. `var expected: String = _source.current()`; if `expected == ""` (exhausted/empty source) → return `WRONG` without emitting or counting (defensive; never happens with the bag).
    2. Record attempt: `_per_key[expected][0] += 1` (create `[0, 0, {}]` on first sight).
    3. If `c == expected`: `keys_typed += 1`; capture `index = _accepted_index`; `_accepted_index += 1`; if not `started` → `started = true` and emit `run_started` **first**; `_source.advance()`; emit `char_accepted(expected, index)`; emit `target_changed(_source.current())`; return `CORRECT`.
    4. Else: `errors += 1`; `_per_key[expected][1] += 1`; `_per_key[expected][2][c] = int(_per_key[expected][2].get(c, 0)) + 1`; emit `char_rejected(expected, c)`; return `WRONG`. The source is not touched and `target_changed` is not emitted.
  - [x] 3.6 Emit order for a correct key: `run_started` (first correct key only) → `char_accepted` → `target_changed`. Tested as one ordered log (record all three through lambdas into an `Array[String]`, same trick as 2.1's Caps Lock order test). Rationale: `RunFrame` starts the clock on `run_started` before the level reacts to `char_accepted`; the HUD/hands update from `target_changed` last, when the new target is already current.
  - [x] 3.7 Comparison is exact string equality. `TypingInput` already case-folded for lowercase levels; `TypingSession` never lowercases, never trims, never decides what is "printable" (the filter already did). An empty `c` or multi-char `c` is simply `!= expected` → wrong key (not a crash).
  - [x] 3.8 No logging per key (hot path; architecture Logging). No `Log.debug` in `judge`. No `await`, timers, autoloads, `JavaScriptBridge`, `randi(`/`randf(` in the file.
  - [x] 3.9 `typed` map keys are the typed character as the filter emitted it (single-char strings). The `per_key` shape matches the save's run-record exactly (`save_v1_full.json` `per_key`: `"f": [14, 3, {"d": 1, "g": 2}]`), so Story 2.3's `RunResult` can copy it as-is. JSON round-trips ints as floats; that is the save layer's concern, not this story's.

- [x] **Task 4: Tests (AC: 1–8)**
  - [x] 4.1 `tests/unit/test_letter_bag_source.gd` (`extends GutTest`, `##` line naming the story). Helper `_make(seed: int, pool: Array[String] = _alphabet()) -> LetterBagSource` with `rng.seed = seed`. Cases:
    - first 26 draws of a 26-letter pool are a permutation (each letter exactly once), and the same for every following consecutive 26-chunk, over 1,000 draws;
    - never the same letter twice in a row over 1,000 draws, for at least 5 seeds (e.g. 1, 2, 3, 42, 12345), **including** across bag boundaries (index 25→26, 51→52 … checked explicitly by the same adjacent-pair loop);
    - a tiny pool (`["a", "b"]`) over 1,000 draws strictly alternates and never repeats (hardest boundary case; the swap rule must hold);
    - a 3-letter pool: every consecutive triple window aligned to bag boundaries is a permutation, no adjacent repeats;
    - same seed → identical 200-draw sequence; different seed → different sequence (assert `!=` on the arrays; 26! makes a collision impossible in practice);
    - `peek` consistency: for a fixed seed, sequence built by `current()`+`advance()` equals the sequence read through `peek(10)` windows; `peek(n)` never changes `current()`; `peek(0)` and `peek(-3)` return `[]`; `peek(60)` (more than two bags) works and has no adjacent repeats;
    - the injected RNG is the one used: two sources sharing one `RandomNumberGenerator` instance advance its state (assert `rng.state` changed after draws), proving no hidden RNG;
    - **mutation check**: temporarily remove the boundary swap and confirm a boundary test fails; temporarily use `Array.shuffle()` and confirm the seed-determinism test fails (record in the Debug Log, restore after). Every test must be able to fail.
  - [x] 4.2 `tests/unit/test_target_source.gd` (or a section in the bag test): the base returns `[]`, `""` and does nothing on `advance()`.
  - [x] 4.3 `tests/unit/test_typing_session.gd`. Use a deterministic **stub** `TargetSource` subclass defined inside the test file (`class StubSource extends TargetSource` with a fixed array, e.g. `["f", "j", "f", "d"]`) so judgments are predictable, and one test with a real seeded `LetterBagSource` to prove they cooperate. Cases:
    - correct key: returns `CORRECT`; `char_accepted` emitted once with `["f", 0]`; `target_changed` with `["j"]`; `run_started` once; counters `keys_typed == 1`, `errors == 0`;
    - second correct key: `char_accepted` with index 1, `run_started` **not** emitted again (count stays 1);
    - wrong key: returns `WRONG`; `char_rejected` with `["f", "g"]`; `char_accepted` not emitted, `target_changed` not emitted, `get_current_target()` still `"f"`; `errors == 1`, `keys_typed == 0`;
    - wrong key first, then correct: `run_started` emitted only on the correct one; `has_started()` false after the wrong key;
    - the target does not advance on repeated wrong keys (5 wrong keys → `errors == 5`, still `"f"`);
    - emit order for the first correct key is exactly `run_started, char_accepted, target_changed`; for a later correct key `char_accepted, target_changed`;
    - synchronous: signal handlers connected before `judge()` have already run when `judge()` returns (assert counters set by lambdas right after the call, no `await` in the test);
    - per-key record: after a scripted sequence for expected `f` (e.g. 2 wrong `g`, 1 wrong `d`, and correct keys so attempts reach a known number; mirror the `"f": [14, 3, {"g": 2, "d": 1}]` example, scaled down) assert `get_per_key()["f"]` equals `[attempts, errors, {"g": 2, "d": 1}]` with `assert_eq` on the whole array/dict; a never-wrong key has `errors == 0` and `{}`; attempts include both correct and wrong judgments; keys never expected are absent;
    - `get_per_key()` returns a deep copy: mutating the returned dictionary does not change a second call's result;
    - case is not folded by the session: expected `"f"`, typed `"F"` → `WRONG` (the filter's job is the case rule); empty string and `"ff"` → `WRONG`, no crash;
    - cooperation test: session over a seeded `LetterBagSource`, typing `current()` 100 times gives `keys_typed == 100`, `errors == 0`, `char_accepted` indexes 0..99 in order, `target_changed` never equals the letter just accepted (no-repeat rule visible through the session).
  - [x] 4.4 Contract guards (`null` rng, pool < 2, duplicates, null source) are **not** called in tests (debug `assert` fails the run; same as 2.1 Task 5.10). Say so in the Debug Log.

- [x] **Task 5: Run and verify (AC: 8)**
  - [x] 5.1 Red first: write the tests before the three scripts exist and record the parse failures in the Debug Log (`Could not find type "TypingSession"` etc.). GUT still exits 0 when a test script fails to parse (2.1 note), so judge by pass count.
  - [x] 5.2 `"/c/Program Files/Godot/Godot.exe" --headless --path . --import`, then `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`: all tests pass (238 at `HEAD` + new), no `Parse Error`, `Failed to load script` or `SCRIPT ERROR`. Commit the `.uid` files Godot generates for the new scripts.
  - [x] 5.3 Boundary greps: no `randi(`, `randf(`, `.shuffle(` (global RNG), `await`, `get_node("/root`, `JavaScriptBridge` in `scripts/typing/` (the `.shuffle(` ban applies to the bag; if a grep hits a comment, reword the comment); `FileAccess` still only in `save_service.gd`; `scripts/typing/` still has no node except `typing_input.gd`.
  - [x] 5.4 No manual/browser check: nothing calls `TypingSession` until Story 2.4 (note this in the Debug Log).
  - [x] 5.5 `deferred-work.md`: add a "Deferred from: dev of story-2-2" section for anything new (at least: `target_completed` deliberately not declared until Epic 6; `config` argument stored but unused until 2.3/6.2).

### Review Findings

- [x] [Review][Patch] `peek` consistency test only compares `ahead[0]`; compare the whole `peek(10)` window against `plain[i+1..i+10]` (Task 4.1) [tests/unit/test_letter_bag_source.gd:97]
- [x] [Review][Patch] Injected-RNG test uses one source; add the spec'd case of two sources sharing one `RandomNumberGenerator` (Task 4.1) [tests/unit/test_letter_bag_source.gd:122]
- [x] [Review][Patch] Mutation check 2 not isolated: re-run with only the Fisher-Yates loop swapped for the built-in shuffle (boundary swap kept) and confirm `test_same_seed_gives_identical_sequence` fails; record in Debug Log [tests/unit/test_letter_bag_source.gd:79]
- [x] [Review][Patch] Bag-boundary fix always swaps with the last index, so the previous bag's last letter ends the new bag ~2/n of the time; swap with `_rng.randi_range(1, end)` instead [scripts/typing/letter_bag_source.gd:71]
- [x] [Review][Patch] `get_current_target()` and `get_upcoming()` lack `##` doc comments (house style, Task 3.4) [scripts/typing/typing_session.gd:92]
- [x] [Review][Patch] RNG-sharing hazard for 2.4/3.1 is in `deferred-work.md` but not in the Debug Log as the Dev Notes require [_bmad-output/implementation-artifacts/2-2-judgment-session-and-letter-bag.md:211]
- [x] [Review][Defer] Exhausted/empty source: `judge()` returns `WRONG` (indistinguishable from a typo) and a correct last key emits `target_changed("")`; matters once finite sources exist (Epic 6/8) [scripts/typing/typing_session.gd:47] — deferred, pre-existing
- [x] [Review][Defer] Re-entrant `judge()` from a `run_started` handler would advance the source twice (no re-entrancy guard); revisit when RunFrame wires handlers in 2.4 [scripts/typing/typing_session.gd:57] — deferred, pre-existing

## Dev Notes

### What this story is (and isn't)

- It builds the **second stage of the typing pipeline** (ADR-1): `TypingSession.judge(c)` compares the character `TypingInput` emits against the current target, advances or rejects, and tracks per-key stats. `LetterBagSource` is the first `TargetSource`.
- Pure logic: three `RefCounted` classes, no scene, no node, no autoload, no clock. Nothing calls them yet; `RunFrame` (2.4) wires them. Do not touch `scripts/run/run_frame.gd` (still the 1.3 placeholder), `typing_input.gd`, `level_config.gd`, `project.godot` or any autoload.
- Don't build: `StatsCalculator` / `RunResult` (2.3; the session only exposes `keys_typed`, `errors`, `get_per_key()` for them), `LevelBase` and the test level (2.4), HUD and wrong-key shake/tick (2.5; this story only emits `char_rejected`), the finger map (2.6), word/paragraph sources and implied spaces (Epic 6/8), run state and clock (2.4). The bonk sound and its 150 ms throttle belong to the HUD/`AudioManager` side, not the session.

### Pipeline reminder (architecture: Typing Pipeline & Level Contract)

```
TypingInput (Node, 2.1)  →  char_typed(c)   (already case-folded in lowercase levels)
TypingSession (RefCounted, THIS STORY)  holds TargetSource; judge(c) → CORRECT | WRONG
  signals: run_started, char_accepted(expected, index), char_rejected(expected, typed), target_changed(next)
RunFrame (2.4)  →  Level.on_char_accepted / on_char_rejected, HUD, hands
```

`RunFrame` will do (architecture example): `_session = TypingSession.new(_level.create_target_source(_rng), _level.get_level_config())`, connect `char_accepted` to the level and HUD, and call `_session.judge(c)` from `%TypingInput.char_typed` only in `WAITING_FIRST_KEY` / `RUNNING`. Keep that call shape working: constructor `(source, config)`.

### Judgment rules, with the reasoning

| Situation | Result | Why |
|---|---|---|
| `c == expected` | `CORRECT`: `keys_typed += 1`, advance, emit | FR1: accepted with zero delay, next target in the same call |
| `c != expected` (any non-matching string) | `WRONG`: `errors += 1`, no advance | FR2: no progress, no world change, nothing else |
| First correct key | also emits `run_started` once, before `char_accepted` | FR6: timer starts on the first **correct** key; a wrong first key never starts it |
| Wrong key before the run started | still counts as an error | The GDD says Errors = wrong printable keystrokes; no carve-out for before the first key |
| Case | exact match, no folding | The filter owns the case rule (2.1); `judge("F")` for expected `"f"` is wrong, which only matters in case-sensitive levels |

- **Attempts include correct keys.** The example `"f": [14, 3, {"g": 2, "d": 1}]` reads: `f` was expected 14 times (judged 14 times), 3 of those were errors, typed `g` ×2 and `d` ×1 (the map sums to the error count: 2 + 1 = 3). Invariant to test: for every key, `errors == sum(typed counts)` and `errors <= attempts`.
- **Wrong keys count as attempts too**, so repeated wrong keys on one target raise `attempts` each time. Accuracy for the report card stays `keys ÷ (keys + errors)` (2.3); per-key `attempts` is the post-MVP adaptive data.
- **Index semantics:** `char_accepted(expected, index)` → `index` is the 0-based number of correct keys before this one in this run. For letter mode that equals the target number; Zombie Run (3.1) uses it to find the target in its queue.

### Letter bag algorithm (FR29) in detail

- Bag = the pool shuffled once; deal it out; when empty, shuffle a new bag. Within a bag every letter occurs once. Across a boundary the only possible repeat is `last letter of old bag == first letter of new bag`; fix by swapping the new bag's first element with its last (or any other index). Because the pool has ≥ 2 distinct letters the swap always yields a different first letter. With a 2-letter pool the sequence is forced to alternate, which is correct.
- Use **only** the injected RNG: `rng.randi_range(0, i)` in a Fisher-Yates loop. Do not call `Array.shuffle()` (global RNG, breaks seeding and the debug-seed replay in 2.10) or `randi()`/`randf()`.
- Determinism contract for 2.10: `seed S → same letter sequence`. This also requires that the number of RNG calls does not depend on `peek` timing. Dealing is driven by queue demand, but each bag shuffle consumes exactly `pool.size() - 1` RNG calls, in order, whenever a bag is dealt; since bags are dealt in sequence regardless of when, the letter sequence is the same however `peek` is interleaved **as long as nothing else shares the RNG between draws**. Note for Story 2.4: the level and the source share the run's one RNG ("passed to the target source and the level"), so a level that draws from it (e.g. brain-block placement) while the source lazily deals will interleave RNG calls. That makes the sequence depend on call timing. **Mitigation to document for 2.4/3.1:** either give the source its own `RandomNumberGenerator` seeded from the run RNG (`child.seed = rng.randi()`) at creation, or have the level draw only through the source. Do not solve it in this story beyond documenting it in the Debug Log and `deferred-work.md`; the unit tests here use the RNG exclusively through the source.
- Pool type: `Array[String]` of single-character strings. No validation of "single character" (YAGNI); document the expectation.

### Existing code to reuse and stay consistent with

- **`scripts/typing/typing_input.gd`** (Story 2.1): house style for scripts in `scripts/typing/` (`class_name` first line, `extends` second, `##` doc block, typed signals with `##` docs, `_` private members, `Log.error(&"typing", ...)` after an `assert` for contract violations). Its output is exactly the `c` this story's `judge` receives.
- **`scripts/resources/level_config.gd`**: the `LevelConfig` type for the optional second `TypingSession` argument.
- **`scripts/core/log.gd`**: `Log.error(&"typing", msg)` for contract violations only. No per-key logging.
- **`tests/unit/test_typing_input.gd`**: test style (`extends GutTest`, `watch_signals`, `assert_signal_emitted_with_parameters`, `assert_signal_emit_count`, ordered-emission recording via lambdas into an `Array[String]`). Note GUT's `watch_signals` works on any `Object` with signals, including `RefCounted` (`TypingSession`).
- **`tests/fixtures/saves/save_v1_full.json`**: the `per_key` shape to match.

### Coding conventions (architecture: Naming Conventions, Consistency Rules)

- Static typing everywhere: `debug/gdscript/warnings/untyped_declaration` is **Error** in `project.godot` (an untyped `var`, parameter or return fails the parse). A lambda in a test needs typed parameters too. `Dictionary`/`Array` untyped containers are fine as types, but typed `Array[String]` is preferred where the contents are known; when a function returns an `Array[String]` built from another array, construct it as `var out: Array[String] = []` and append (assigning an untyped `Array` to `Array[String]` is a runtime error).
- Tabs, `snake_case` files/functions, `_` prefix for private members, `UPPER_SNAKE` constants, PascalCase `class_name`, signals past tense and typed, `##` docs on public members.
- Contract violations: `assert` + `Log.error` + safe fallback. Runtime oddities (empty source, odd `c`) are handled, never errors.
- Dependencies are injected through the constructor (no autoloads, no `get_node("/root/...")`).
- Local variable named `seed` shadows the built-in `seed()` function and triggers a warning; name test parameters `rng_seed`.

### Testing standards

- GUT 9.7.1, tests in `tests/unit/`, `extends GutTest`, prefix `test_`; `.gutconfig.json` runs everything under `res://tests/`.
- A `RefCounted` needs no `autofree`. Inner classes (`class StubSource extends TargetSource`) are fine in a test file.
- Every test must be able to fail: assert exact sequences and counts, not just "didn't crash"; do the two mutation checks in Task 4.1 and note them in the Debug Log. Earlier reviews (1.4, 1.5, 1.9, 2.1) repeatedly caught tests that pass with or without the guard.
- Large loops: 1,000 draws × 5 seeds on a 26-letter pool is trivial; keep the suite fast.
- The suite prints some expected `ERROR`/`WARN` lines from earlier error-path tests; judge by GUT's pass count and exit code plus no `Parse Error` / `Failed to load script` / `SCRIPT ERROR`.

### What later stories rely on (keep these stable)

- **2.3** `RunResult` copies `keys_typed`, `errors` and `get_per_key()` (shape `{char: [attempts, errors, {typed: count}]}`); `StatsCalculator` is separate and static (do not put accuracy/WPM in the session).
- **2.4** `RunFrame` builds `TypingSession.new(source, config)`, connects `run_started` (starts `RunClock`), `char_accepted` (level + HUD), `char_rejected` (level + HUD shake/tick) and `target_changed` (HUD, hands). It also passes a letter pool (26 lowercase letters) to `LetterBagSource` through the test level's `create_target_source(rng)`. The test level emits `brains_earned_changed` per 4th correct key from `on_char_accepted` (index is available).
- **2.5/2.6** HUD and finger hands read `get_current_target()` / `get_upcoming(n)` at start (before any `target_changed`) and then follow `target_changed`.
- **2.10** debug seed: `rng.seed = debug_seed` → same sequence (see the RNG-sharing note above).
- **3.1** Zombie Run keeps the active target plus the next 3: `current()` + `peek(3)`. `peek(n)` therefore excludes the current target (Task 1.2).
- **Epic 6** adds `WordSource` and the `target_completed` signal and implied-space accounting; the `TargetSource` interface and `judge` order must not need changes for that beyond additions.

### Previous story intelligence (Story 2.1 and Epic 1)

- **Test-first, red then green** is the project habit: record the red run in the Debug Log. GUT exits 0 even when a test script fails to parse, so read the pass count (238 before this story).
- **Commands:** `"/c/Program Files/Godot/Godot.exe" --headless --path . --import`, then `... -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`. Run `--import` after adding new `class_name` scripts or GUT cannot resolve them.
- **2.1 review fixes worth reusing:** boundary tests for edge values (they added `unicode` 31/32/126/127/128 after review) → here test pool sizes 2 and 3 and bag boundaries explicitly; a "can't fail" test was a recurring review finding; contract-violation asserts are never called in tests.
- **2.1 deferrals that touch this story:** Caps Lock state/enabled gate and run lifecycle belong to 2.4/2.7; none require changes here. `TypingInput` emits only single-character strings, so `judge` never sees multi-character input from the real pipeline.
- Epic 1 placeholders (`run_frame.gd`, keyboard test, art review) are not touched.

### Git intelligence

- One commit per story: `Story 2.1: typing input filtering`, `Story 1.9: …`. Each commits scripts with `.uid` files, tests, the story file, `sprint-status.yaml` and `deferred-work.md` together. Follow `Story 2.2: judgment session and letter bag` if Smuck asks for a commit.
- 2.1 touched only `scripts/typing/typing_input.gd`, `scripts/resources/level_config.gd`, `scripts/core/game_constants.gd`, tests and fixtures. This story adds three files under `scripts/typing/` and three test files; it modifies no existing source file.
- No new dependencies: only built-in Godot APIs and GUT.

### Godot API notes (4.7.2)

- `RandomNumberGenerator`: `seed` (int, set before use), `randi_range(from, to)` inclusive on both ends, `state` (int; changes as numbers are drawn). Same seed → same sequence on the same engine version.
- `Array.shuffle()` and global `randi()`/`randf()` use the global RNG: banned here. `Array.duplicate(true)` / `Dictionary.duplicate(true)` make deep copies.
- Signals on `RefCounted`: declare `signal name(param: Type)` and `name.emit(...)`; emission is synchronous, handlers run before `emit` returns. `GutTest.watch_signals(obj)` works for them.
- `class_name X` followed by `extends Y` on the next line is the style used in this repo (see `typing_input.gd`).

### Project Structure Notes

- Paths follow the architecture directory tree exactly: `scripts/typing/target_source.gd`, `letter_bag_source.gd`, `typing_session.gd`; tests `tests/unit/test_typing_session.gd`, `test_letter_bag_source.gd`. `scripts/typing/` already exists (2.1). `stats_calculator.gd` and `run_result.gd` in the same folder arrive in 2.3.
- Architectural Boundary 1: `scripts/typing/` stays pure logic; `typing_input.gd` remains the only node there.

### Project Context Rules

No `project-context.md` exists in this repo. The binding rules come from `_bmad-output/game-architecture.md` (Typing Pipeline & Level Contract, Consistency Rules, Randomness, Architectural Boundaries, Naming Conventions) and are summarised above. Tools: Godot binary at `/c/Program Files/Godot/Godot.exe`; the Godot MCP server is available but not needed (no scene).

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 2.2: Judgment Session and Letter Bag] — story and BDD acceptance criteria.
- [Source: _bmad-output/planning-artifacts/epics.md#Functional Requirements] — FR1, FR2, FR6, FR9, FR29.
- [Source: _bmad-output/game-architecture.md#Typing Pipeline & Level Contract] — `TypingSession`, `TargetSource`, signals, randomness, feedback latency.
- [Source: _bmad-output/game-architecture.md#Data Persistence] — run-record `per_key` shape.
- [Source: _bmad-output/game-architecture.md#Consistency Rules / Implementation Patterns] — `TypingSession.new(source, config)` construction, no `await` in the typing path, injected dependencies.
- [Source: _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md#M1 Blocking typing input; Input & Judgment Model] — judgment, bag rule, per-key tracking.
- [Source: _bmad-output/implementation-artifacts/2-1-typing-input-filtering.md] — previous story: pipeline stage 1, test style, review learnings.
- [Source: tests/fixtures/saves/save_v1_full.json] — `per_key` example.

## Dev Agent Record

### Agent Model Used

claude-sonnet-5-5

### Debug Log References

- Red run (tests written first): GUT reported `Parse Error: Could not find type "LetterBagSource"`, `"TargetSource"` and `Could not find base class "TargetSource"`; the new scripts failed to load.
- Green run after `--import`: 267 tests, 267 passing (238 at HEAD + 29 new), no `Parse Error` / `Failed to load script` / `SCRIPT ERROR`.
- Mutation check 1: replacing the bag-boundary swap with `if false:` made the no-repeat, 2-letter and 3-letter tests fail (repeats across bag boundaries). Restored (diff-verified).
- Mutation check 2: replacing the Fisher-Yates deal with the built-in array shuffle (my edit also skipped the boundary swap) made the no-repeat tests fail; the same-seed/global-RNG failure was not isolated separately. `test_injected_rng_is_used` covers "no hidden RNG" directly. Restored.
- Contract guards (null rng, pool < 2, duplicates, null source) are not called in tests: the debug `assert` would fail the run (same as 2.1). Covered by code review.
- Boundary greps: no `randi(`, `randf(`, `.shuffle(`, `await`, `get_node("/root`, `JavaScriptBridge` in `scripts/typing/` (two comment hits reworded); `FileAccess` only in `save_service.gd`; `typing_input.gd` is still the only node in `scripts/typing/`.
- No manual/browser check: nothing calls `TypingSession` until Story 2.4.
- RNG sharing (2.4/3.1): the level and `LetterBagSource` would share the run's RNG; the source deals lazily, so a level drawing from it between draws makes the letter sequence depend on call timing (breaks seed replay, 2.10). Mitigation for 2.4: seed a child RNG for the source from the run RNG (`child.seed = rng.randi()`) or have the level draw only through the source. Recorded in `deferred-work.md`.
- Code review: mutation check 2 redone in isolation (Fisher-Yates loop replaced by the built-in shuffle, boundary swap kept): `test_same_seed_gives_identical_sequence`, `test_peek_does_not_change_the_sequence`, `test_peek_excludes_current`, `test_injected_rng_is_used` and `test_two_sources_sharing_one_rng_both_advance_it` failed (5/268). Restored (diff-verified).
- Code review green run: 268 tests, 268 passing (one new test), no `Parse Error` / `Failed to load script` / `SCRIPT ERROR`; boundary greps still clean.

### Completion Notes List

- `TargetSource` base (safe no-ops), `LetterBagSource` (injected RNG, own Fisher-Yates, boundary swap, lazy queue so `peek` never changes the sequence) and `TypingSession` (`judge` returns `Verdict`; signals emitted synchronously in the order `run_started`, `char_accepted`, `target_changed`; per-key record in the run-record shape, returned as a deep copy).
- Tests: `test_letter_bag_source.gd` (1,000 draws x 5 seeds, pools of 2/3/26, determinism, peek, injected RNG), `test_target_source.gd`, `test_typing_session.gd` (stub source plus a real bag; order, sync, per-key shape and invariants).
- Deferred items recorded in `deferred-work.md` (RNG sharing note for 2.4, `target_completed`, unused `config`).

### File List

- scripts/typing/target_source.gd (+ .uid)
- scripts/typing/letter_bag_source.gd (+ .uid)
- scripts/typing/typing_session.gd (+ .uid)
- tests/unit/test_target_source.gd (+ .uid)
- tests/unit/test_letter_bag_source.gd (+ .uid)
- tests/unit/test_typing_session.gd (+ .uid)
- _bmad-output/implementation-artifacts/deferred-work.md
- _bmad-output/implementation-artifacts/sprint-status.yaml
- _bmad-output/implementation-artifacts/2-2-judgment-session-and-letter-bag.md

### Change Log

- 2026-10-04: Implemented story 2.2 (TargetSource, LetterBagSource, TypingSession) with tests; status -> review.
- 2026-10-04: Code review: 6 patches applied (full peek-window test, shared-RNG test, isolated mutation check, random-slot bag-boundary swap, getter docs, RNG note in Debug Log); 2 items deferred; status -> done.
