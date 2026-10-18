---
baseline_commit: 650c64424b8086a6c0e37912f6a2936bc83fe2b9
---

# Story 11.3: Fully Separate Zombies

Status: review

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a parent,
I want each zombie's progress kept completely separate,
so that one kid's bad day never changes the other kid's game.

## Acceptance Criteria

1. **Every profile field stays separate (FR78, ADR-2).** With two (or more) profiles in one save, every PlayerData mutation changes **only the active profile**. The fields that exist today are the 13 keys of `SaveSchema.profile_defaults()` (schema v5): `name`, `brains`, `owned_items`, `equipped`, `flags` (`welcome_bonus_claimed`, `tutorial_seen`, `placement_done`), `tier`, `settings` (`music_on`, `sound_on`), `best_wpm`, `run_history`, `level_unlocks`, `used_passages`, `last_themes`, `lifetime`. Epics 7 and 8 have landed, so `tier` and `used_passages` are in scope (epic AC). After any mutation, every **inactive** profile Dictionary is deep-equal (`==` on a `duplicate(true)` snapshot taken before) to what it was, in memory **and** in the written `save.json`.
2. **Mutation coverage is complete and stays complete.** A GUT table test runs every public PlayerData mutation on the active profile and checks AC 1 for each: `add_brains`, `record_run` (timer finish: history, best, brains, lifetime, an unlock, tier placement; and a later run that moves the tier), `buy_item`, `equip`, `unequip`, `set_flag` (each flag), `set_setting` (each setting), `mark_unlock_seen`, `mark_level_chosen`, `debug_set_all_unlocked(true/false)`, `set_used_passages`, `set_last_theme`, `set_zombie_name`. A **guard test** lists PlayerData's public script methods (`get_script_method_list()`) and fails, with a message naming the method, when one is neither in the mutation table nor in an explicit allow-list of read-only / profile-level methods (`get_*`, `owns`, `has_named_zombie`, `can_add_zombie`, `switch_profile`, `create_profile`, `reset_all`). A future setter therefore can't skip this check.
3. **Every field is actually exercised.** After the full mutation sequence on profile A, a field-coverage test asserts that **every** top-level key of `profile_defaults()` (and every nested key of `flags`, `settings`, `lifetime`) in A differs from its default value, while profile B still equals its starting snapshot. If a new field is added to `profile_defaults()` later and no mutation touches it, this test fails naming the key.
4. **The epic scenario: two kids play, shop and get a gift (epic AC).** One temp-dir PlayerData shared by real screens (the `test_first_purchase_flow.gd` pattern): kid A (p1) finishes a run → report card → Welcome Gift (+100) → Crypt Closet tutorial → buys and wears a hat; `switch_profile(&"p2")`; kid B gets **its own** report card → **its own** Welcome Gift (+100, flag was false for B) → **its own** Closet tutorial → buys a different hat and a pet. Then: A's brains, owned/equipped items, flags, history, best, lifetime, tier and placement are exactly what A earned; B's are exactly what B earned; neither has the other's items, gift or runs; switching back to A shows A's hat (and no pet) on a `HatSlot`/`PetSlot` that follows PlayerData.
5. **Runs read the active zombie live.** A real `RunFrame` (the `test_tier_follow.gd` `_play` pattern) on the **same** PlayerData: profile A placed at a high tier with some `used_passages` and a `last_themes` entry, profile B unplaced/low tier with its own. Start a run as A → the level gets A's tier, used passages and last theme; `switch_profile(&"p2")`; start a run as B → B's values, and B's finished run lands in B's history/lifetime only. Passages a Pitchfork Panic run marks used for B never appear in A's `used_passages` (use whatever level/text path `test_tier_follow.gd` / `test_run_frame.gd` already drive; Pitchfork Panic only if it is cheap there).
6. **Switching back and forth keeps everything.** A → mutate → switch B → mutate → switch A → mutate → switch B: at each switch the newly active profile reads exactly its last state (brains, items, equipped, flags, settings, tier, unlocks, passages, themes, lifetime, name), nothing is lost or merged, and each switch writes one save request (11.2 behaviour, already tested — just don't break it). A second temp `SaveService` reloading the file sees both profiles exactly as in memory, plus `active_profile`.
7. **No shared references.** No `Array` or `Dictionary` instance is shared between two profiles (walk both profile trees and compare with `is_same`): after `create_profile`, after a load through `SaveService` (JSON + `fill_defaults`), and after the mutation sequence. (Today `profile_defaults()` builds new containers each call and `_merge` deep-copies; this test keeps it that way — a shared `[]` would make one kid's purchase appear in another's list.)
8. **Screens and listeners show only the active zombie.** Extend `tests/integration/test_profile_switch.gd`: after `switch_profile` the Trends screen (`trends.gd`, re-reads on `profile_replaced`) shows B's lifetime totals / bests / history-based charts, not A's; the Crypt Closet shows B's owned/worn states and B's tutorial state; the report card's welcome-gift redirect follows B's `welcome_bonus_claimed`. No listener code is expected to change — if one shows stale or mixed data, fix that listener (smallest change) and say so in Completion Notes.
9. **Fix any leak found, in the owner.** If any test above finds data crossing profiles, the fix goes in `PlayerData` (the only writer) or in the stale listener; never by adding a second copy of profile state anywhere. Record each fix (what crossed, why, the fix) in Completion Notes. If nothing crosses, **no production code changes** — this story is then tests + docs only, and that is a valid outcome.
10. **Out of scope, documented.** F8 debug reset (`reset_all` → `SaveService.reset_to_defaults()`) wipes **every** zombie (dev-only, 11.2 deferred note) — not changed; add one test that pins this current behaviour (both profiles gone, one unnamed `p1`) so a change is a deliberate decision. Global, non-profile state is not per-zombie by design and must **not** be moved into profiles: `schema_version`, `active_profile`, SaveService's read-only flag/backup, AudioManager's voice-spacing timers, `RunFrame`'s static debug seeds, `Log` statics, window/fullscreen state. List these in the class doc paragraph (Task 6).
11. **No migration, no new fields, no visible change.** `GameConstants.CURRENT_SCHEMA` stays **5**; `SaveSchema` unchanged; no fixture changes except an optional new `tests/fixtures/saves/save_v5_two_zombies.json`. No scene, sprite, sound or copy changes, so **no approval gates**.
12. **Names never logged (NFR12).** New tests may use names, but no production log line gains one; the existing 11.1/11.2 source guard in `test_player_data.gd` stays green (extend it only if production files change).
13. **No regressions.** Full GUT suite green and the count only goes up; zero `Parse Error|Compile Error|Failed to load script`; `SCRIPT ERROR` / `WARNING` counts unchanged except deliberate, asserted ones. All existing PNG/WAV byte-identical. The real `user://save.json` sha256 identical before and after every suite run (temp `user://` dirs only).

## Tasks / Subtasks

- [x] **Task 1: Baseline** (AC: 13)
  - [x] 1.1 `"C:\Program Files\Godot\Godot.exe" --headless --path . --import`, then `... --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit` into a scratch log. Record tests/passing, `SCRIPT ERROR`, `WARNING`, zero `Parse Error|Compile Error|Failed to load script`. Expected after 11.2 + review: ~2363+ / all passing, `SCRIPT ERROR` 3, `WARNING` ~190 — re-measure.
  - [x] 1.2 Record the real save's sha256 (`%APPDATA%/Godot/app_userdata/ZombiesTeachTyping/save.json`).

- [x] **Task 2: Isolation unit tests** (AC: 1, 2, 3, 6, 7, 10) — new `tests/unit/test_profile_isolation.gd`
  - [x] 2.1 Setup like `test_player_data.gd`: temp `TEST_DIR = "user://test_profile_isolation/"`, `_make()` (fresh `SaveService` with `save_dir`, PlayerData with `save_service`, code-built `catalogue` and `level_registry` like `_test_catalogue()` / `_test_registry()` in `test_player_data.gd` so buys/unlocks are deterministic), `_clear()` in before/after. Seed p1 and p2 with **different, non-default** values in every field (p2 named "Bo", some brains, an owned+worn item, a flag set, music off, a run in history, a best, an unlock, used passages, a last theme, lifetime totals, placed tier) so "unchanged" is meaningful. Active = p1.
  - [x] 2.2 `_snapshot(id) -> Dictionary` = `save_service.get_data()["profiles"][id].duplicate(true)`; `_written(id)` reads `save.json` (`save_service.save_now()` first, or use the flush the other tests use) and returns that profile.
  - [x] 2.3 Mutation table: `Array[Dictionary]` of `{"name": "add_brains", "run": Callable}` covering every method in AC 2. One test iterates it: per row, snapshot p2, run, assert p2 in memory == snapshot and written p2 == snapshot (message names the row). Also assert p1 actually changed for that row (a no-op row would prove nothing).
  - [x] 2.4 Guard test (AC 2): `PlayerDataScript.get_script_method_list()` names, drop `_`-prefixed and built-ins, every remaining name must be in the table's names ∪ the read-only allow-list; fail message `"PlayerData.%s is not in the profile isolation table (Story 11.3)"`.
  - [x] 2.5 Field coverage (AC 3): run the whole table on p1 starting from **defaults** (a fresh p1 via `profile_defaults()` + name), then for each key of `profile_defaults()` (and nested `flags` / `settings` / `lifetime` keys) assert `p1[key] != default[key]`, message names the key. `settings` keys: toggle off (default is on). Note `debug_set_all_unlocked(false)` empties unlocks — order the table so the final state has unlocks (run `true` last or mark after).
  - [x] 2.6 Back-and-forth (AC 6) and reload through a second temp `SaveService` (copy the 11.2 test `test_two_profiles_survive_a_reload` pattern).
  - [x] 2.7 Shared references (AC 7): recursive helper collecting every Array/Dictionary in a profile tree; assert no `is_same` pair across p1/p2 (and p3 after `create_profile`), after load and after the table.
  - [x] 2.8 F8 pin (AC 10): `reset_all()` with two profiles → `get_profile_ids() == [&"p1"]`, name `""`. Message: `"F8 wipes every zombie (dev-only, deferred 11-2); change on purpose"`.

- [x] **Task 3: Two kids, real screens** (AC: 4) — new `tests/integration/test_two_zombies_flow.gd`
  - [x] 3.1 Copy `test_first_purchase_flow.gd`'s structure (one temp PlayerData through every screen's `player_data` seam, `_record` navigation, `_follow`, `_finish_run`, `Router._store_payload`, `Router.take_payload()` in `after_each`). Reuse its helper code by copying the needed helpers (it has no shared base class; don't refactor it).
  - [x] 3.2 Kid A full flow (run → report card → gift → Closet tutorial → buy + wear), `switch_profile(&"p2")` (p2 created with `create_profile("Bo")` — that also makes it active; then switch back to A and forward again to exercise `switch_profile`), kid B full flow with a different hat + a pet. Assert AC 4 values per kid with exact numbers (run brains + 100 gift − price).
  - [x] 3.3 Switch to A: a `HatSlot`/`PetSlot` following the temp PlayerData show A's hat and no pet; switch to B: B's.

- [x] **Task 4: Runs per zombie** (AC: 5) — in `tests/integration/test_tier_follow.gd` (new test) or a new `test_two_zombies_runs.gd`
  - [x] 4.1 One PlayerData, two profiles with different tiers / `used_passages` / `last_themes`. `_play`-style real `RunFrame` for A, check the level's tier/passages/theme inputs (whatever `test_tier_follow.gd` already inspects: allowed letters/words; `RunFrame` passes `get_tier()`, `get_used_passages()`, `get_last_theme()` at `run_frame.gd:278-279, 337`); finish with debug F6; `switch_profile`; same for B; assert histories/lifetime per profile.
  - [x] 4.2 Keep it cheap: no frame-by-frame waits beyond what the existing helpers use.

- [x] **Task 5: Listeners show only the active zombie** (AC: 8) — extend `tests/integration/test_profile_switch.gd`
  - [x] 5.1 Give p1/p2 distinct `lifetime`, `best_wpm`, `run_history` in `before_each`. Trends screen instance (seams: `navigate`, `player_data`, `play_sfx`, `play_music`, `is_transitioning`, `time_zone_bias`; see `tests/unit/test_trends.gd` for how it reads the totals board) → switch → shows B's totals.
  - [x] 5.2 Crypt Closet instance (seams as in `test_first_purchase_flow.gd`) → switch → tile owned/worn states and `is_tutorial_active()` follow B.
  - [x] 5.3 Report card with a result: gift redirect follows the active profile's `welcome_bonus_claimed`.
  - [x] 5.4 If any is stale, fix the listener minimally (AC 9) and add the fix to the File List.

- [x] **Task 6: Docs** (AC: 9, 10)
  - [x] 6.1 `scripts/autoloads/player_data.gd` class doc: extend the `## Profiles (Story 11.2, FR78)` paragraph with one or two lines: "Story 11.3: every field in a profile is per-zombie; tests/unit/test_profile_isolation.gd checks each mutation leaves other profiles untouched and fails on a new public setter not in its table. Global by design: schema_version, active_profile, SaveService's read-only/backup state; F8 reset wipes every zombie." (Doc-only change; doc changes are fine even when no code changes.)
  - [x] 6.2 `_bmad-output/game-architecture.md` Data Persistence "Profiles" bullet: add "Every profile field is per-zombie (Story 11.3 isolation tests); a new PlayerData setter must be added to the isolation table."
  - [x] 6.3 `deferred-work.md`: anything found but not fixed.

- [x] **Task 7: Wrap-up** (AC: 13)
  - [x] 7.1 Full suite + counts vs baseline; real save sha256 unchanged; `git status` shows no PNG/WAV/scene changes.
  - [x] 7.2 Mutation pass (scratch edits, restore after; each must turn a test red): `add_brains` also adds to every profile; `buy_item` appends to the first profile's `owned_items` instead of the active one's; `set_setting` writes `profiles["p1"]`; `switch_profile` copies the old profile's `brains` into the new one; `profile_defaults()` returns a shared module-level `owned_items` Array; `record_run` appends to `_profiles().values()[0]`; a new public `set_dummy()` with no table row (guard test); a new `profile_defaults()` key nobody writes (coverage test); Trends doesn't re-read on `profile_replaced`.
  - [x] 7.3 Status → review.

## Dev Notes

### What this story is (and isn't)

- **Is:** proof that profiles are fully separate — table-driven isolation tests over every PlayerData mutation, a guard that keeps the table complete, field coverage, a two-kid end-to-end flow through real screens, runs reading the active zombie, listener refresh checks, a shared-reference check, docs. Plus fixes **only if** a test finds a leak.
- **Isn't:** the name on the menu/report card or a "switch zombies" button (Story 11.4); renaming or deleting zombies (no AC); per-profile F8 reset (deferred); any schema change; any visible change (so no Gate 1/2).

### Why we expect no leaks (and where to look hard)

- Every PlayerData getter/setter goes through `_profile()` → `save_service.get_active_profile()` → `_data["profiles"][_data["active_profile"]]`, re-read on every call; nothing caches a profile Dictionary across calls (`player_data.gd:577`). `switch_profile` / `create_profile` only rewrite `active_profile` (`player_data.gd:530-574`).
- Methods that hold a local `profile` reference (`record_run` `:138`, `buy_item` `:265`, `set_last_theme` `:430`, `_reconcile_tier` `:625`) use it only within one call, so they can't cross a switch.
- `profile_defaults()` builds new containers each call; `SaveSchema._merge` / `_copy` deep-duplicate defaults (`save_schema.gd`). `_add_lifetime` uses a fresh `profile_defaults()["lifetime"]`. `set_used_passages` stores a duplicate.
- Things outside PlayerData that read profile data on demand: RunFrame (`get_tier`, `get_used_passages`, `get_last_theme`, `get_setting` at run start/pause; writes via `record_run`, `add_brains`, `set_used_passages`, `set_last_theme`, `set_setting`), report card (`get_flag(welcome_bonus_claimed)`), welcome gift (`add_brains`, `set_flag`), Closet, Trends, main menu, `HatSlot`/`PetSlot`, AudioManager. All listeners that show profile values re-read on `profile_replaced` (grep result: audio_manager, hat_slot, pet_slot, crypt_closet, keyboard_test, main_menu, name_zombie, trends, whos_playing).
- **Look hard at:** anything that caches a value at `_ready()` and only updates on a delta signal (e.g. a screen that reads brains once and then listens to `brains_changed`) — that is the stale-listener pattern AC 8 hunts. Report card and welcome gift are short-lived screens built after any switch, so they read fresh; the switch only happens on the picker today, so no screen that's open during a switch other than those listening to `profile_replaced` matters until 11.4 adds a menu → picker path (which navigates away anyway).
- Global caches found by grep that are **not** profile data (leave them): `AudioManager._last_played_msec` (voice spacing), `RunFrame` static `debug_seed`/`last_seed` (debug replay), `Log` statics, `hud.gd` `_wrap_cache` (text layout), `professor_zombie._rise_cache` (hat geometry by item id), `HatSlot/PetSlot._warned`.

### Existing code: current state, what changes, what must be preserved

- **`scripts/autoloads/player_data.gd`** (779 lines): expected change = class doc only (Task 6.1). If a leak is found, fix it here keeping: one save request per mutation, typed signals, no `assert()`, names never logged, every write through `_profile()`.
- **`scripts/autoloads/save_service.gd`, `scripts/core/save_schema.gd`**: no change. `fill_defaults` merges every profile; `reset_to_defaults()` replaces the whole save (pinned by AC 10's test).
- **`tests/unit/test_player_data.gd`**: unchanged unless production code changes (then extend the NFR12 guard). It already has 11.2's `_add_profile(id, fields)`, `_profile_count()`, `_test_catalogue()`, `_test_registry()`, `_make_shop()`, `_make_unlocks()` — copy what you need into the new test file (helpers aren't shared across GUT scripts in this project).
- **`tests/integration/test_profile_switch.gd`**: add tests only; keep its two existing tests and `before_each` data (extend p1/p2 with lifetime/history/best fields — the existing assertions don't read them).
- **`tests/integration/test_first_purchase_flow.gd`**: model only; don't modify.
- **`tests/integration/test_tier_follow.gd`**: model (`_kid`, `_play` with a real RunFrame, F6 end in a debug build). It uses **separate** saves per kid today; 11.3's point is **one** save with two profiles.

### Testing notes

- Commands in Task 1. Run `--import` after adding new test scripts (GUT needs the `.uid`s; commit them).
- GUT skips a script that fails to parse and still exits 0 — grep the log for `Parse Error|Compile Error|Failed to load script`.
- Never the real save: temp-dir `SaveService` + injected PlayerData for every screen/frame (10.1 real-save incident). Every screen seam (`player_data`, and `HatSlot`/`PetSlot.player_data`, AudioManager `player_data`) must point at the temp one.
- Build the second profile with `save_service.get_data()["profiles"]["p2"] = SaveSchema.profile_defaults()` + fields, or `create_profile("Bo")` (makes it active), or a fixture `save_v5_two_zombies.json` via `_put_fixture`.
- Deep compare: `assert_eq(after, before)` on Dictionaries compares deeply in GDScript 4 (`==` is deep for Dictionary/Array); use `assert_eq_deep` if you want GUT's diff output on failure.
- `get_script_method_list()` on the script returns methods of the script only (includes `_ready`, signals' callbacks if any, and private helpers) — filter `_`-prefixed. Store the allow-list as a `const` with a comment.
- `record_run` in tests: `RunResult.create(level_id, stamp, seconds, keys, wrong, per_key, brains, bonus, pool, end_reason)` as in `test_first_purchase_flow.gd::_finish_run` / `test_tier_follow.gd::_kid`. A `zombie_run` timer finish places the tier on an unplaced profile (`tier_config.placement_level`) and unlocks `horde_rush` with the shipped/test registry.
- `assert_push_warning` / `assert_push_error` for any deliberate refusal; final `WARNING` count rises only by asserted ones.
- After calling `_unhandled_input()` by hand push a no-op `InputEventAction` in `after_each` (`_reset_input_handled`, 10.5/11.1).
- Type every variable incl. loop vars (`untyped_declaration = Error`).
- Flaky `test_audio_manager` pool test: rerun once before investigating.

### Previous story intelligence (11.2, done 2026-10-15)

- Profile API: `get_profile_ids()` (natural sort), `get_active_profile_id()`, `get_profile_summary(id)`, `has_named_zombie()`, `can_add_zombie()` (`MAX_ZOMBIES = 4`), `switch_profile(id)` (reconciles tier, emits `profile_replaced`, one save, logs id only), `create_profile(raw_name)` (lowest free `p<N>`, refuses invalid/duplicate/cap with fixed warnings).
- `test_profile_switch.gd` already proves the main menu (brains, toggles, hat, pet, level cards) and AudioManager refresh on switch — don't duplicate, extend to Trends/Closet/report card.
- `test_player_data.gd::test_switch_profile_reads_the_other_profile_and_leaves_the_old_one_alone` checks one switch; 11.3 generalises to every mutation.
- Review fixes kept: picker cap/dirty rebuild, name screen leaves new-zombie mode on success, Back from 11.1 mode with >1 profile.
- Deferred from 11.2: F8 wipes every zombie; duplicate names only refused for new zombies; read-only save switch is in memory only. None of these is in scope.
- Final 11.2 counts: 2363 / 2363, `SCRIPT ERROR` 3, `WARNING` 190 (plus review-added tests — re-measure).
- Earlier: **7.2** `_reconcile_tier` on switch (done in 11.2); **4.5** first-purchase flow test (model for AC 4); **10.5** lifetime totals + Trends `_show` on `profile_replaced`; **8.2** used passages via RunFrame; **10.1** last themes via RunFrame + real-save incident.

### Git intelligence

- Recent: `650c644 Story 11.2: code review findings resolved, done`, `cd9415b Story 11.2: who's playing picker and new zombies`, `544f6e8 Story 11.1: code review findings resolved, done`, `647aee3 Story 11.1: name the existing zombie`, `b992bce Story 10.5: code review findings resolved, done`. One commit per story: code, tests, docs, story file, `deferred-work.md`, `sprint-status.yaml`.
- Expected shape: new `tests/unit/test_profile_isolation.gd`, `tests/integration/test_two_zombies_flow.gd` (+ `.uid`s), maybe `tests/integration/test_two_zombies_runs.gd` or a new test in `test_tier_follow.gd`, maybe `tests/fixtures/saves/save_v5_two_zombies.json`; updated `tests/integration/test_profile_switch.gd`, `player_data.gd` (doc), `game-architecture.md`. Message: `Story 11.3: fully separate zombies`.

### Latest tech notes (Godot 4.7.2, GUT 9.7.1)

- No new libraries/addons; versions pinned by the architecture. No web research needed.
- `Object.get_script_method_list()` / `Script.get_script_method_list()` → `Array[Dictionary]` with `"name"`.
- `is_same(a, b)` compares Array/Dictionary by instance (not value) — the right tool for AC 7.
- `Dictionary.duplicate(true)` deep-copies nested Arrays/Dictionaries (the snapshot for AC 1).

### Project Structure Notes

- Tests only, in the existing `tests/unit/` and `tests/integration/` folders; no new production files. No variance from the architecture tree.

### Project Context Rules

- There is no `project-context.md`. Rules from the architecture and earlier stories:
  - Only `SaveService` touches files; only `PlayerData` mutates profile/save state (Boundary 4). Tests mutate through PlayerData or seed the save Dictionary before/around it.
  - Static typing everywhere; typed signals; disconnect autoload signals in `_exit_tree`.
  - Never log personal data — zombie names (NFR12). Ids are fine.
  - Junk save values read as safe defaults (NFR16).
  - Visible changes need Smuck's approval — none in this story.
  - Files LF (`.gitattributes eol=lf`); commit the uids Godot writes.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 11.3: Fully Separate Zombies]; Epic 11 overview; FR78
- [Source: _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd-epics-overview.md#Epic 11] (per-zombie brains, cosmetics, history and tier)
- [Source: _bmad-output/game-architecture.md#State Management], [#Data Persistence] (Profiles bullet), [#Architecture Decision Records] (ADR-2)
- [Source: scripts/autoloads/player_data.gd] (all mutations, `_profile()`, `switch_profile`, `create_profile`, `reset_all`), [scripts/core/save_schema.gd profile_defaults/fill_defaults/_merge], [scripts/autoloads/save_service.gd get_data/get_active_profile/reset_to_defaults], [scripts/run/run_frame.gd:278-279,318,337,470,513,552], [scripts/screens/report_card.gd:184], [scripts/screens/welcome_gift.gd:79-88], [scripts/screens/trends.gd], [scripts/screens/crypt_closet.gd]
- [Source: tests/unit/test_player_data.gd], [tests/integration/test_profile_switch.gd], [tests/integration/test_first_purchase_flow.gd], [tests/integration/test_tier_follow.gd], [tests/integration/test_run_frame.gd], [tests/unit/test_trends.gd]
- [Source: _bmad-output/implementation-artifacts/11-2-whos-playing-picker-and-new-zombies.md], [deferred-work.md] (7-2, 11-1, 11-2 entries)

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Debug Log References

- Baseline (Task 1): 2363 / 2363 passing, `SCRIPT ERROR` 3, `WARNING` 190, 0 `Parse Error|Compile Error|Failed to load script`. Real save sha256 `2859cbaa61d4fc9a7a4b7b7e8019794def38313e28a8ba71d8b6a0cd347d647a`.
- Final: 2379 / 2379 passing (+16), `SCRIPT ERROR` 3, `WARNING` 190, 0 parse/compile/load errors. Real save sha256 unchanged. No PNG/WAV/scene changes.
- Mutation pass (Task 7.2), each restored after: `add_brains` adds to every profile (6 red); `buy_item` appends to the first profile (3 red, caught by the reverse-direction table and the two-kid flow); `set_setting` writes `p1` (2 red); `switch_profile` carries brains (4 red); shared module-level `owned_items` in `profile_defaults()` (6 red, incl. the coverage test); `record_run` appends to the first profile (3 red); public `set_dummy()` (guard red, names the method); new `profile_defaults()` key `nickname_color` (coverage red, names the key); Trends without the `profile_replaced` connect (2 red). Reverting the Closet fix turns `test_crypt_closet_shows_the_active_zombies_items_and_tutorial` red (seen before the fix).

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created
- **No data leak in PlayerData.** Every mutation in the table leaves every other profile deep-equal, in memory and in the written `save.json` (compared after a JSON round trip of the snapshot), in both directions (p1 fresh with Bo as the other zombie, and Bo active with p1 as the other) and with a third zombie. No shared Array/Dictionary between profiles after `create_profile`, after a load (JSON + `fill_defaults`, including two empty profiles filled from defaults) and after the table. `player_data.gd` changed in its class doc only.
- **One stale listener found and fixed (AC 8, 9):** a Crypt Closet open across a zombie switch kept the last zombie's tutorial state (an active arrow for a zombie that had seen it, or no tutorial for a zombie whose gift was claimed and tutorial not seen). Why: `_on_profile_replaced` only refreshed tiles; `_tutorial_active` was decided once in `_ready`. Fix (`crypt_closet.gd`): remember the active profile id; on `profile_replaced` with a different id, drop the tutorial, refresh, and start the new zombie's only on the flag rule (gift claimed, tutorial not seen). Same-id `profile_replaced` (F8 reset) keeps the old behaviour, so `test_reset_all_while_active_follows_the_new_state` stays as is. Not reachable in the shipped game today (switching happens on the picker only). No visible change in normal play, no log lines added (NFR12 guard unchanged; no name handling touched).
- Mutation table rows (AC 2): `set_zombie_name`, `add_brains`, `record_run` (placement run: history, best, brains, lifetime, opens horde_rush, places tier 3), `set_flag(placement_done, false)` then a second `record_run` that re-places at tier 5 (the tier moves), `set_flag` for the other two flags, `set_setting` both, `buy_item` hat and pet, `equip` hat and pet, `unequip`, `debug_set_all_unlocked(false)` then `(true)`, `mark_unlock_seen`, `mark_level_chosen`, `set_used_passages`, `set_last_theme`. Allow-list: `get_*`, `owns`, `has_named_zombie`, `can_add_zombie`, `switch_profile`, `create_profile`, `reset_all`.
- Deviation from 2.1: p1 starts from `profile_defaults()` (not seeded) so the same table drives the field-coverage test (AC 3) and every row can be checked to change the active profile; the reverse-direction test then runs the table on the seeded Bo with the named, non-default p1 as the profile that must stay unchanged.
- AC 4: `tests/integration/test_two_zombies_flow.gd` — Sam: run (16 WPM, 35 brains) → report card → gift → Closet tutorial → Pumpkin hat; Bo created, picker switches back and forth; Bo: own report card redirect → own gift → own tutorial → Witch hat (not the arrow's first target) + Cute Ghost. Exact brains, owned, equipped, flags, tier (3 vs 5), history, best and lifetime per kid; HatSlot/PetSlot follow the switch.
- AC 5: `tests/integration/test_two_zombies_runs.gd` — one save, Sam tier 5 / Bo tier 3 with their own used passages and last Pitchfork Panic theme; real Pitchfork Panic RunFrames read each zombie's tier, used passages and last theme; each run's passage, theme and record land in that zombie only (Bo's run leaves Sam's profile deep-equal).
- AC 6: back-and-forth with one save request per switch, then a second temp SaveService reload equal to memory plus `active_profile`.
- AC 8: `test_profile_switch.gd` extended (existing two tests and data kept; p1/p2 gain lifetime, best and history): Progress totals, best and chart bar counts follow the switch (and an empty new zombie shows the sign); Closet tile states, counter and tutorial follow the switch both ways; the report card's gift redirect follows the active zombie, including a card left open across a switch.
- AC 10: F8 pin test (`reset_all` with two zombies → one unnamed `p1`). Global state listed in the PlayerData class doc. AC 11: schema 5 and `SaveSchema` unchanged, no fixture added (the code-built save was enough).

### File List

- `scripts/autoloads/player_data.gd` (class doc only)
- `scripts/screens/crypt_closet.gd` (tutorial re-decided on a zombie switch)
- `tests/unit/test_profile_isolation.gd` (new)
- `tests/unit/test_profile_isolation.gd.uid` (new)
- `tests/integration/test_two_zombies_flow.gd` (new)
- `tests/integration/test_two_zombies_flow.gd.uid` (new)
- `tests/integration/test_two_zombies_runs.gd` (new)
- `tests/integration/test_two_zombies_runs.gd.uid` (new)
- `tests/integration/test_profile_switch.gd`
- `_bmad-output/game-architecture.md`
- `_bmad-output/implementation-artifacts/deferred-work.md`
- `_bmad-output/implementation-artifacts/sprint-status.yaml`
- `_bmad-output/implementation-artifacts/11-3-fully-separate-zombies.md`

### Change Log

- 2026-10-18: Story 11.3 implemented — profile isolation table + guard + field coverage, two-kid real-screen flow, per-zombie RunFrame test, listener checks (Progress, Closet, report card), shared-reference and F8 pin tests; Crypt Closet re-decides its tutorial on a zombie switch; docs. Status → review.
