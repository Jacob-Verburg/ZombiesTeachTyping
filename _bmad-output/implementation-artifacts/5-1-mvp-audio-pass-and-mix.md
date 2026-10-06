---
baseline_commit: 4d3fb6ff6c8459307386ecb9300371603effe393
---

# Story 5.1: MVP Audio Pass and Mix

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a kid,
I want bouncy music and funny sounds that never get annoying,
So that the game feels alive and fun to play again.

## Acceptance Criteria

1. **Library contents (FR49, FR50).** **Given** the MVP audio list **When** `data/audio/audio_library.tres` is inspected **Then** it holds 4 groans, 2 "Brainsss" lines, brain bonk, hug-poof, wrong-key tick, purchase jingle, report card chalk-scratch and chime, UI click, a menu music loop and a Zombie Run music loop (60–120 s each), as OGG music and 16-bit WAV effects.
2. **Credits (NFR14).** **And** every file's source and license (CC0-style or self-recorded) is listed in `assets/audio/CREDITS.md`. No placeholder rows are left for files that no longer exist.
3. **Event sounds.** **Given** each sound event in the game **When** it happens **Then** the matching sound plays through `AudioManager`: bonk on a brain block, hug-poof on a villager, chalk-scratch and chime on the report card, click on UI buttons, jingle on purchase.
4. **Music per screen.** **Given** the screens and runs **When** they are entered **Then** the menu loop plays on the title, menu, Closet, Welcome Gift and report card; the Zombie Run loop plays during a run (a paused run keeps it at a lower volume); switching between them is a 0.5 s crossfade; and the same loop never restarts when it is already playing.
5. **The mix (NFR14).** **Given** a full Zombie Run at 30+ WPM **When** it is played **Then** music sits below the effects, the wrong-key tick is quiet, and no sound stacks into noise, checked against the named manual checklist in this file (`### Review Findings

- [x] [Review][Decision] (resolved: keep clicks, update M10 wording) Closet "Buy" press clicks, but M10 says "Buy → Yes plays the jingle only" — Gate B passed M10 with the click present; keep the Buy/No clicks or drop them? [scripts/screens/crypt_closet.gd]
- [x] [Review][Decision] (resolved: accept) A third music change (menu → run → report card, Play Again) hard-stops the loop still fading out (audible pop); pinned by `test_a_third_loop_cuts_the_one_fading_out`. Accept, or fade it out / use equal-power fades? [scripts/autoloads/audio_manager.gd `_start_music`]
- [x] [Review][Decision] (resolved: accept source-file check) AC1/Task 7.1 asks for 16-bit runtime streams, but Task 2.2 imports effects as QOA (`compress/mode=2`). Tests check the source RIFF header instead. Accept the source-file check, or switch the import to PCM? [tests/unit/test_audio_library.gd, assets/audio/sfx/*.import]
- [x] [Review][Patch] Chime plays one reveal step after the last row shows; spec says when the last row has shown — use `(size-1) * REVEAL_STEP_S` and update the test [scripts/screens/report_card.gd `_process`]
- [x] [Review][Patch] `sfx_chalk_scratch` `min_interval_s = 0.05` drops scratches when several fall in one frame after a hitch, so "one scratch per row" isn't guaranteed; also the chime fires with the first scratch [data/audio/audio_library.tres, scripts/screens/report_card.gd]
- [x] [Review][Patch] Unguarded `play_sfx.call` / `duck_music.call` in `zombie_run_level.gd` (~183), `run_frame.gd` (~365–489), `crypt_closet.gd`, `report_card.gd` (~176); errors if `_ready` never ran. Guard with `is_valid()` like `villager.gd`
- [x] [Review][Patch] Same-id restart branch in `_start_music` doesn't re-apply cue volume / `_gain_current` (stale volume on restart) [scripts/autoloads/audio_manager.gd:~446]
- [x] [Review][Patch] `_held_sfx` in the unlock frame is unbounded and un-deduped; cap/dedupe it and keep throttle behaviour consistent (held calls return `null`) [scripts/autoloads/audio_manager.gd `_try_play_sfx`/`_flush_held_sfx`]
- [x] [Review][Patch] `test_audio_credits.gd` only scans `wav`/`ogg`; add mp3/flac/opus so a new format can't skip a credit row [tests/unit/test_audio_credits.gd]
- [x] [Review][Patch] `data.size() / 2` in `_check_wav_file` triggers the integer-division warning [tests/unit/test_audio_library.gd]
- [x] [Review][Patch] (verified: Wear/Take off/leave clicks exist, header correct; M10 wording updated instead) `crypt_closet.gd` header says clicks on "Wear, Take off and leaving", but the diff only adds Buy and No/Esc clicks — verify and fix the header or the code
- [x] [Review][Defer] Voice lines and music started in the unlock frame aren't held like SFX [scripts/autoloads/audio_manager.gd] — deferred, title screen doesn't request voice at unlock
- [x] [Review][Defer] Debug end / F6 while PAUSED leaves music ducked until the scene swap [scripts/run/run_frame.gd] — deferred, debug-only
- [x] [Review][Defer] `sfx_wrong_key` (-14 dB) equals `mus_menu` level, so the tick can be masked in menus [data/audio/audio_library.tres] — deferred, Gate B approved the mix
- [x] [Review][Defer] OGG loop seam (encoder padding/click) untested; `encode_ogg.py` has no per-file error handling [tools/encode_ogg.py] — deferred, checked by ear in M7
- [x] [Review][Defer] Default-seam tests mutate the live `AudioManager` autoload (state can leak between tests) [tests/] — deferred
- [x] [Review][Defer] Failed `buy_item` path plays no sound [scripts/screens/crypt_closet.gd] — deferred, not in spec
- [x] [Review][Defer] `_is_busy`/`_play_player` test seams mean the real `playing` guard is untested against real playback [scripts/autoloads/audio_manager.gd] — deferred, Dummy driver limitation

## Mix Checklist`, what to look for and pass/fail per item).
6. **Muted play (FR46).** **And** with both toggles off, the whole game is still fully playable.

## Tasks / Subtasks

- [x] **Task 1: Gate A — sourcing plan (AC: 1, 2)** — before any final file goes in
  - [x] 1.1 Fill the `## Audio Sources` table (one row per file in "MVP audio list" below) with the proposed source for each: **(S)** self-recorded by Smuck, **(C)** a CC0 file Smuck downloads or approves downloading (give the page URL, the author and the license text), or **(G)** generated by `tools/gen_audio.gd` (CC0 by authorship). Recommended default in Dev Notes "Sourcing".
  - [x] 1.2 **Stop and ask Smuck** to approve the plan. Never download a file, never install a package (e.g. `soundfile` from PyPI) without Smuck's explicit yes in chat, naming the file/package, source and size. Record the answer verbatim under `## Audio Approval`.
  - [x] 1.3 If Smuck records voice lines, give Smuck the recording spec (Dev Notes "Recording spec") and wait for the files. Work on Tasks 3–7 meanwhile (they don't depend on the final files).
- [x] **Task 2: Assets (AC: 1, 2)**
  - [x] 2.1 Put each file at its path from the MVP audio list (naming per architecture: `mus_<context>.ogg`, `sfx_<event>.wav`, `vo_<line>_<nn>.wav`). SFX/voice: 16-bit PCM WAV, mono, 44.1 or 22.05 kHz, trimmed (no leading silence > 10 ms), peak ≤ -1 dBFS, starting and ending at zero (no click). Music: OGG Vorbis, stereo or mono, 60–120 s, seamless loop.
  - [x] 2.2 Import settings: music `.ogg.import` `loop=true` (and `loop_offset=0`); SFX `.wav.import` `edit/loop_mode=0` (disabled), `compress/mode=2` like the existing files. Run `--import` and commit every `.import`.
  - [x] 2.3 Delete `assets/audio/music/mus_menu.wav` (+ `.import`) once `mus_menu.ogg` is in. Replace every other placeholder that has a final file. Keep `tools/gen_placeholder_audio.gd` only if a (G) row still uses it; otherwise retire it into `tools/gen_audio.gd` (see Dev Notes "Generated sounds") and delete it.
  - [x] 2.4 Rewrite `assets/audio/CREDITS.md`: File | Source | Author | License, one row per file under `assets/audio/` (no `.import`), matching `## Audio Sources`.
- [x] **Task 3: Library and cues (AC: 1, 4, 5)** — `scripts/resources/audio_cue.gd`, `audio_library.gd`, `data/audio/audio_library.tres`
  - [x] 3.1 `AudioCue`: add `@export var alt_streams: Array[AudioStream] = []` — extra takes of the same cue; AudioManager picks one of `[stream] + alt_streams` at random. `vo_brainsss` uses `vo_brainsss_01.wav` as `stream` and `vo_brainsss_02.wav` in `alt_streams`. The id stays `&"vo_brainsss"` (the level's call doesn't change).
  - [x] 3.2 `AudioLibrary`: add `@export_range(0.0, 2.0, 0.05) var music_crossfade_s: float = 0.0` (set to 0.5 in the .tres, AC 4) and `@export_range(-40.0, 0.0, 0.5) var music_pause_duck_db: float = 0.0` (start at -10 in the .tres; tuned by the checklist).
  - [x] 3.3 `.tres`: cues `sfx_ui_click`, `sfx_wrong_key` (keep `min_interval_s = 0.15`), `sfx_brain_bonk`, `sfx_hug_poof`, `sfx_purchase`, `sfx_chalk_scratch`, `sfx_report_chime`, `sfx_groan_01..04`, `vo_brainsss`, `mus_menu`, `mus_zombie_run`. Give `sfx_brain_bonk`, `sfx_hug_poof` and `sfx_chalk_scratch` a `min_interval_s` (start 0.06 / 0.08 / 0.05) so bursts can't stack. Starting volumes in Dev Notes "Mix starting values"; final values come from the checklist.
  - [x] 3.4 Let Godot write the ext_resource UIDs (save the .tres from the editor or copy the uid from each new `.import`); never hand-invent a UID (4.4 deferral: `uid://51tlvsl155x7`).
- [x] **Task 4: AudioManager — music crossfade, duck, variants (AC: 4, 5)** — `scripts/autoloads/audio_manager.gd`
  - [x] 4.1 Two music players, `MusicA` and `MusicB` (bus `Music`), replacing the single `Music` node. One is "current", the other fades out. Update the header doc ("Later: the music crossfade (5.1)" goes).
  - [x] 4.2 `play_music(id)`: locked → validate with `_get_playable_cue()` first (unknown id warns and never overwrites a valid pending id; 1.5 deferral), then pending. Unlocked: same id as the current loop → nothing (no restart, even mid-fade-in). Same id as the loop that is fading out → swap roles and fade it back in from its current volume, no restart. Otherwise start the new loop on the idle player at silence and fade it in while the old one fades out, both over `library.music_crossfade_s`; when the fade-out ends, stop that player. An unknown id while unlocked warns and keeps the current loop.
  - [x] 4.3 Drive the fade by hand in `_process(delta)` (a `_step_music(delta)` like `_update_ambience()`), not a Tween: deterministic in GUT and unaffected by the Router's tree pause (this node is `PROCESS_MODE_ALWAYS`). Work in linear gain 0..1 and write `volume_db = cue.volume_db + linear_to_db(maxf(gain, 0.0001)) + duck_db` — never assign `-INF` (NaN errors on some paths).
  - [x] 4.4 `set_music_ducked(on: bool)`: moves the music's extra attenuation toward `library.music_pause_duck_db` (on) or 0 (off) over a short ramp (0.15 s look value). Starting a different loop clears the duck. `is_music_ducked()` getter.
  - [x] 4.5 `stop_music()`: stops both players, clears current, pending and duck. While locked it still clears the pending id (unchanged; the 1.4 deferral stays recorded).
  - [x] 4.6 Variants: `_play_on_pool()` picks `cue.stream` or one of `alt_streams` with a dedicated `variant_rng` (created and randomized in `_init`, a test seam like `ambience_rng`; never the run RNG — seed replay — nor the global one). Skip null entries.
  - [x] 4.7 Testability seam (deferred from 1.4/2.5/3.7): add `func _is_busy(player: AudioStreamPlayer) -> bool` (default `player.playing`) used by `_pick_sfx_player()` and the music "already playing" check, so tests can override it on a subclass/inner script. Use it to make `test_play_music_same_id_does_not_restart` and the steal/voice-steal tests meaningful.
  - [x] 4.8 First click on web (1.4 deferral, AC 3 "click on UI buttons" includes the title's): SFX requested in the same frame as `unlock()` are held and played on the next `_process` tick instead of being lost to the still-suspended AudioContext. Verify in Chrome; if one frame isn't enough, hold them for a short window (≤ 100 ms look value) and play once. If neither is audible, record it in the story and in deferred-work (do not add JS outside `WebPlatform`).
- [x] **Task 5: Music per screen (AC: 4)**
  - [x] 5.1 `LevelConfig`: add `@export var music_id: StringName = &""`. `data/levels/zombie_run.tres` → `&"mus_zombie_run"`; `scripts/resources/level_config.gd` gets the field. `data/levels/test_level.tres` keeps it empty (an empty id means "leave the music as it is").
  - [x] 5.2 `RunFrame`: new seams `play_music: Callable` and `duck_music: Callable` (default `AudioManager.play_music` / `AudioManager.set_music_ducked` in `_ready`, recorders in tests — like `set_ambience`). After a successful `_start_level`, `play_music.call(config.music_id)` if non-empty. `_set_state`: entering `PAUSED` → `duck_music.call(true)`; leaving `COUNTDOWN` into `RUNNING`/`WAITING_FIRST_KEY` → `duck_music.call(false)` (the countdown stays ducked: the run isn't live yet). `_exit_tree` → `duck_music.call(false)` if valid (Quit to Menu, scene swaps).
  - [x] 5.3 `report_card.gd`, `crypt_closet.gd`, `welcome_gift.gd`: call `play_music(&"mus_menu")` in `_ready` through a `play_music` seam (default `AudioManager.play_music`). Title and main menu already call it; route them through the same kind of seam only if a test needs it.
  - [x] 5.4 Run end: the Zombie Run loop keeps playing through ENDING (the dance) and crossfades to the menu loop when the report card opens. No dance music (not in FR49).
- [x] **Task 6: Event sounds (AC: 3)**
  - [x] 6.1 Brain bonk: `ZombieRunLevel` gets a `play_sfx: Callable` seam (default `AudioManager.play_sfx`, set in `_ready` like `request_voice`). In `on_char_accepted`, when `done is BrainBlock` → `play_sfx.call(&"sfx_brain_bonk")`. Never touch `_rng` for it (`test_run_rng_has_one_consumer`).
  - [x] 6.2 Hug-poof: the sound goes with the visible poof, not the keypress. `Villager` gets a `play_sfx: Callable` (the level sets it in `_spawn()` before `add_child`, next to `configure()`); `_start_poof()` calls `play_sfx.call(&"sfx_hug_poof")` if valid. A villager without the seam stays silent (no autoload fallback inside `Villager`, so its unit tests stay silent).
  - [x] 6.3 Report card: a `play_sfx` seam. In `_process`, play `sfx_chalk_scratch` once for each row the moment it is first shown, then `sfx_report_chime` once when the last row has shown (before the stamp). Track "already played" per row so `_process` never replays. A fresh card with 6 or 7 rows plays 6 or 7 scratches and 1 chime. The stamp gets no sound (no stamp thump in FR50; note it for post-MVP).
  - [x] 6.4 UI clicks — every button the kid presses plays `sfx_ui_click` exactly once: report card Play Again / Menu (in `_leave`, only when it actually navigates; Esc / Enter too); pause panel Resume / Quit to Menu / Music / Sound toggles (in `RunFrame`'s handlers, so `PausePanel` stays dumb — or a `play_sfx` seam on the panel; pick one and test it). Already clicking: title, main menu (cards, Closet, toggles), Closet (Wear / Unwear / leave), Welcome Gift button. Confirm the Closet's Buy → Yes plays the jingle and **not** a click on top. Locked / Coming soon cards: no sound (EXPERIENCE: "nope" wiggle, no sound).
  - [x] 6.5 Wrong-key tick: unchanged call; it just gets the quiet final file and a lower volume (checklist).
- [x] **Task 7: Tests (AC: 1–6)**
  - [x] 7.1 `test_audio_library.gd`: replace the placeholder tests. Every FR50/FR49 id exists with a stream; `vo_brainsss` has exactly 2 takes; `groan_ids` has 4 ids that all resolve; music cues are `AudioStreamOggVorbis` with `loop == true` and `get_length()` in [60, 120]; every `sfx_*`/`vo_*` stream is an `AudioStreamWAV` with `format == FORMAT_16_BITS` and loop disabled; every `mus_*` `volume_db` is below every `sfx_*`/`vo_*` cue's except the wrong-key tick; the wrong-key tick is the quietest SFX cue; `music_crossfade_s == 0.5`.
  - [x] 7.2 New `test_audio_credits.gd`: parses `CREDITS.md`; every audio file under `res://assets/audio/` (no `.import`) has exactly one row, every row names an existing file, and the license column is one of the allowed values (`CC0`, `CC0 1.0`, `Self-recorded (CC0)` — fix the list in the test and the file together).
  - [x] 7.3 `test_audio_manager.gd`: update the pool test (8 SFX + 2 music players, names `MusicA`/`MusicB`). New: crossfade volumes at 0 / 0.25 / 0.5 s via `_step_music(delta)`; old player stopped at the end; same id → no restart (with the `_is_busy` seam); return to the fading-out id → no restart; unknown id while locked keeps the valid pending id; unknown id while unlocked keeps the current loop; crossfade keeps running under a paused tree (`process_mode`); duck on/off and cleared by a new loop; `stop_music` clears duck; variant pick uses `variant_rng` and both takes come up over N seeded picks; SFX in the unlock frame play on the next tick, never twice; never a NaN/`-INF` `volume_db`.
  - [x] 7.4 `test_run_frame.gd` (integration) / unit: music seam called once with `mus_zombie_run` at start; duck true on pause, still true in COUNTDOWN, false back in RUNNING; false on `_exit_tree` after Quit; test level (empty `music_id`) never calls it. `test_zombie_run_level.gd`: one bonk per brain block key, no bonk for villagers, `test_run_rng_has_one_consumer` still passes. `test_villager.gd`: hug-poof once at poof start with the seam, silent without. `test_report_card.gd`: scratch per row, one chime after the last row, nothing replays on later frames, clicks on leave (once, not during the guard). Pause clicks. Closet: jingle without a click on Yes.
  - [x] 7.5 Live-autoload hygiene: any new screen `_ready()` → `play_music` must not break `test_title_requests_menu_music_on_ready` (it reads the live `_pending_music`; all menu screens request the same `mus_menu`, but RunFrame must use its seam in tests). Run the full suite twice; the known flaky voice-steal test should become deterministic with `_is_busy`.
- [x] **Task 8: The mix and Gate B (AC: 3, 4, 5, 6)**
  - [x] 8.1 Export the web debug build, serve it (`web-debug` in `.claude/launch.json`), and confirm per-player volume changes are audible on web (the crossfade and the duck). Godot web uses sample playback by default; if a player's `volume_db` change is not applied there, set the two music players' `playback_type = AudioServer.PLAYBACK_TYPE_STREAM` and re-check for crackle. Record what you found.
  - [x] 8.2 Smuck walks the `## Mix Checklist` in desktop Chrome (and one other browser) with speakers on, then with both toggles off. Tune volumes in the `.tres` only (no literals in scripts) and repeat until every row passes. Record pass/fail and the final volumes in the checklist.
  - [x] 8.3 **Gate B:** Smuck's listen approval recorded verbatim under `## Audio Approval`. No story completion without it.
- [x] **Task 9: Docs and wrap-up**
  - [x] 9.1 `game-architecture.md` Audio Architecture: "A pool of 8 `AudioStreamPlayer`s for SFX, plus one music player" → "plus two music players (0.5 s crossfade, Story 5.1)"; add `set_music_ducked()` to the API line.
  - [x] 9.2 `deferred-work.md`: strike the items this story closes (Dev Notes "Deferred items closed"); add what stays open (stamp thump, brain counter tick, conga join, gift/arrow sounds, dance music → post-MVP or Smuck's call).
  - [x] 9.3 Update header comments of every touched script (they record story history; keep that style).

## Mix Checklist

Walk a full 2:00 Zombie Run at 30+ WPM (fast bursts included) plus the menu flow. Record **Pass / Fail + note** per row.

| # | Check | What to listen for | Pass when | Result |
|---|-------|-------------------|-----------|--------|
| M1 | Music under SFX | Menu and run loops vs the click, bonk, poof | Every effect is clearly heard over the music; the music never needs turning down to hear a bonk | Pass (Gate B, 2026-10-06) |
| M2 | Quiet wrong-key tick | Mash 5 wrong keys fast, then type right | Ticks are softer than the bonk and the click; never more than ~6/s (150 ms throttle); not harsh | Pass (Gate B, 2026-10-06) |
| M3 | No stacking at speed | 10-key bursts at 5+ keys/s on brain blocks and villagers | No crackle, no clipping, no "wall" of bonks; it still sounds like separate hits | Pass (Gate B, 2026-10-06) |
| M4 | Groans | 2:00 of play | A groan every 3–8 s, never on a keypress, never within 2 s after a Brainsss; goofy, not scary | Pass (Gate B, 2026-10-06) |
| M5 | Brainsss | Collect many brains | Both takes heard over a run; never two within 8 s; clear over the music | Pass (Gate B, 2026-10-06) |
| M6 | Pause duck | Esc mid-run, wait, Resume | Run loop drops noticeably but keeps playing; back to full only when the countdown ends | Pass (Gate B, 2026-10-06) |
| M7 | Crossfades | Title → menu → run → report card → menu → Closet → menu → run → Pause → Quit | Each music change is a smooth 0.5 s blend; no gap, no pop; menu loop never restarts between menu, Closet, gift and report card | Pass (Gate B, 2026-10-06) |
| M8 | Loops | Leave the menu idle 2+ minutes; play a full run | No audible seam or click at the loop point | Pass (Gate B, 2026-10-06) |
| M9 | Report card | Finish a run | One scratch per row as rows appear, then one chime; stamp silent; all inside ~1 s | Pass (Gate B, 2026-10-06) |
| M10 | Clicks | Every button: title, menu, cards, toggles, Closet, gift, pause, report card | One click per press; in the Closet, Buy and No click and Yes plays the jingle only | Pass (Gate B, 2026-10-06) |
| M11 | First input | Fresh tab, first key on the title | The menu loop starts; the first click is heard (or the result of Task 4.8 recorded) | Pass (Gate B, 2026-10-06) |
| M12 | Muted play | Music off and Sound off, walk the whole MVP loop | Fully playable; nothing needs sound; toggles saved after reload | Pass (Gate B, 2026-10-06) |
| M13 | Levels | Overall at normal laptop volume | Nothing is louder than the click; no file peaks harshly; a 6-year-old wouldn't cover their ears | Pass (Gate B, 2026-10-06) |

## Audio Sources

_(Task 1 fills this; Gate A approves it.)_

| File | Plan (S / C / G) | Source / URL | Author | License |
|------|------------------|--------------|--------|---------|
| `sfx/sfx_ui_click.wav` | G (alt: C) | `tools/gen_audio.gd` (alt: Kenney "Interface Sounds", https://kenney.nl/assets/interface-sounds) | Generated (alt: Kenney) | CC0 |
| `sfx/sfx_wrong_key.wav` | G | `tools/gen_audio.gd` — soft low tick | Generated | CC0 |
| `sfx/sfx_brain_bonk.wav` | G (alt: C) | `tools/gen_audio.gd` — pitched-down "boing" bonk (alt: Kenney "Impact Sounds", https://kenney.nl/assets/impact-sounds) | Generated (alt: Kenney) | CC0 |
| `sfx/sfx_hug_poof.wav` | G | `tools/gen_audio.gd` — filtered noise puff + pop | Generated | CC0 |
| `sfx/sfx_purchase.wav` | G (alt: C) | `tools/gen_audio.gd` — rising major jingle (alt: Kenney "Music Jingles", https://kenney.nl/assets/music-jingles) | Generated (alt: Kenney) | CC0 |
| `sfx/sfx_chalk_scratch.wav` | G | `tools/gen_audio.gd` — short band-passed noise scratch | Generated | CC0 |
| `sfx/sfx_report_chime.wav` | G | `tools/gen_audio.gd` — two-note bell chime | Generated | CC0 |
| `sfx/sfx_groan_01..04.wav` | G | `tools/gen_audio.gd` — four goofy formant groans | Generated | CC0 |
| `voice/vo_brainsss_01.wav`, `_02.wav` | G | `tools/gen_audio.gd` — two formant "braaains" takes (drawn out / quick) | Generated | CC0 |
| `music/mus_menu.ogg` | G | `tools/gen_audio.gd` → WAV in scratchpad → OGG via `tools/encode_ogg.py` (`uv run --with soundfile`) | Generated | CC0 |
| `music/mus_zombie_run.ogg` | G | same route as `mus_menu.ogg`; calmer tempo | Generated | CC0 |

## Audio Approval

_(Gate A and Gate B: Smuck's words, verbatim, with the date.)_

**Gate A — 2026-10-06** (answers to the sourcing questions, verbatim):
- Voice lines: "Generate them"
- Sound effects: "Generate all (Recommended)"
- OGG encoding: "Install soundfile (Recommended)" — approves the dev-only `soundfile` PyPI package via `uv run --with soundfile tools/encode_ogg.py` (~1 MB wheel with libsndfile, uv cache only, never shipped).
- Size correction, 2026-10-06 (soundfile pulls numpy): asked "OK to proceed?" for soundfile (~1 MB) + numpy (~12–13 MB) + cffi/pycparser (<1 MB), ~15 MB into uv's cache only. Answer: "Yes, download (~15 MB)"

**Gate B — 2026-10-06** (after walking the Mix Checklist, verbatim): "all is good please continue"

Final volumes (unchanged from the starting values): mus_menu -14, mus_zombie_run -16, sfx_ui_click -8, sfx_wrong_key -14, sfx_brain_bonk -6, sfx_hug_poof -7, sfx_purchase -5, sfx_chalk_scratch -12, sfx_report_chime -6, groans -9, vo_brainsss -4, music_pause_duck_db -10, music_crossfade_s 0.5.

## Dev Notes

### What this story is (and isn't)

- **Is:** final MVP audio files and credits; the library's 16 cues; the music crossfade and pause duck in `AudioManager`; the run's own music; every FR50 event wired to its sound; clicks on every button; the mix tuned by a checklist; two approval gates (sourcing, listen).
- **Isn't:** new sound events beyond FR50 (no stamp thump, brain-counter tick, conga join, gift or arrow sounds, dance music — the deferred notes that pointed at 5.1 for these get "post-MVP / Smuck's call"); the brain counter pop / ×N pop juice (visual); any typing, save, economy or Router change; bus effects (none on web, architecture D7); Horde Rush or chase music (Epics 6/8).

### MVP audio list (paths are the plan; FR50 + FR49)

| Cue id | File(s) | Event | Notes |
|--------|---------|-------|-------|
| `sfx_ui_click` | `sfx/sfx_ui_click.wav` | every button | short (≤ 60 ms), soft |
| `sfx_wrong_key` | `sfx/sfx_wrong_key.wav` | wrong printable key | the GDD's "soft bonk tick", quiet; `min_interval_s 0.15` |
| `sfx_brain_bonk` | `sfx/sfx_brain_bonk.wav` | brain block resolved | ≤ 250 ms, cartoony |
| `sfx_hug_poof` | `sfx/sfx_hug_poof.wav` | villager poof starts | ≤ 400 ms, puff/pop |
| `sfx_purchase` | `sfx/sfx_purchase.wav` | Closet buy confirmed | happy jingle ≤ 1 s |
| `sfx_chalk_scratch` | `sfx/sfx_chalk_scratch.wav` | each report row appears | ≤ 90 ms (rows are 0.1 s apart) |
| `sfx_report_chime` | `sfx/sfx_report_chime.wav` | after the last row | ≤ 1 s |
| `sfx_groan_01..04` | `sfx/sfx_groan_0N.wav` | ambience (3.7) | goofy, 0.5–1.2 s each, not scary (NFR10) |
| `vo_brainsss` | `voice/vo_brainsss_01.wav` + `_02.wav` (alt) | 20 % on a brain | ≤ 1.5 s each |
| `mus_menu` | `music/mus_menu.ogg` | title, menu, Closet, gift, report card | light, bouncy, 60–120 s loop |
| `mus_zombie_run` | `music/mus_zombie_run.ogg` | Zombie Run | "calm" loop (GDD), 60–120 s |

### Sourcing (Gate A — Smuck decides; this is the recommendation)

- **Voice (groans, Brainsss): (S)** self-recorded by Smuck — the GDD names this (A5), it fits "goofy, not scary", and it needs no license search. Fallback (G): keep improved generated groans.
- **SFX: (C)** CC0 packs Smuck downloads (e.g. Kenney's audio packs at kenney.nl are CC0) **or (G)** generated. Any (C) file needs the page URL and license recorded; the dev agent never downloads without Smuck's yes in chat.
- **Music: (C)** CC0 loops (OpenGameArt filtered to CC0, or Kenney music) of 60–120 s, **or (G)** a longer generated arpeggio/bass loop. Godot cannot encode OGG; a (G) music file is rendered to WAV by `tools/gen_audio.gd` and encoded to OGG outside Godot: options are Smuck exporting it from Audacity, or (with Smuck's yes to install it) a dev-only Python script `tools/encode_ogg.py` using `soundfile` (`uv run --with soundfile tools/encode_ogg.py in.wav out.ogg`; its Windows wheels bundle libsndfile with Vorbis). Neither `ffmpeg`, `oggenc`, `sox` nor `soundfile` is installed on this machine today (checked).
- `tools/` is export-excluded (`export_presets.cfg` exclude_filter), so generator/encoder scripts never ship.

### Recording spec (for Smuck, if (S))

- Quiet room, phone or headset mic is fine; 44.1 kHz; one take per file plus a spare; say each line 3 different ways so 2 can be picked.
- Groans: 4 different, short, silly "uuuh", "hrrm", "mmh?", "braa" (the placeholders' contours); Brainsss: 2 different "Braaainsss…", one drawn out, one quick and happy.
- Deliver WAV (or anything; the dev converts with Godot's importer → `AudioStreamWAV.save_to_wav` in a tool, 16-bit mono). The dev trims, normalizes to about -3 dBFS peak and fades the ends.

### Generated sounds (if any (G) row)

- New `tools/gen_audio.gd` (`extends SceneTree`, run headless like the other tools) takes over `gen_placeholder_audio.gd`: same `_save()` 16-bit WAV writer, fixed RNG seeds so reruns are byte-identical, every sound starts and ends at zero. Write only the (G) files. Music from it is a WAV intermediate under the scratchpad (never committed), then encoded to `.ogg`.
- Run: `"/c/Program Files/Godot/Godot.exe" --headless --path . -s tools/gen_audio.gd` then `--headless --import`.

### Mix starting values (look values; the checklist decides)

`mus_menu` -14 dB, `mus_zombie_run` -16 dB, `sfx_ui_click` -8, `sfx_wrong_key` -14, `sfx_brain_bonk` -6, `sfx_hug_poof` -7, `sfx_purchase` -5, `sfx_chalk_scratch` -12, `sfx_report_chime` -6, groans -9, `vo_brainsss` -4, `music_pause_duck_db` -10. Normalize files first (peaks around -3 dBFS) so `volume_db` does the mixing; cue volumes live only in the `.tres` (architecture: no gameplay/audio numbers as literals). Buses stay at 0 dB with no effects (D7, tested by `test_bus_layout_master_music_sfx`).

### Existing code: current state, what changes, what must be preserved

- **`scripts/autoloads/audio_manager.gd`** — today: 8-player SFX pool + one `Music` player; `unlock()` gate with pending music (FR47); per-cue `min_interval_s` throttle; `play_voice()` 8 s gap shared across `vo_*`, never stealing `_voice_player`; ambience groans on its own `ambience_rng`, skipped within 2 s of a voice line; bus mutes follow `PlayerData` `settings_changed` / `profile_replaced`; `PROCESS_MODE_ALWAYS`. **Changes:** two music players + crossfade + duck (Task 4), variants, `_is_busy` seam, unlock-frame SFX hold. **Preserve:** every existing rule and test seam (`library`, `now_msec`, `ambience_rng`, `player_data`), the pool size, "only this script creates audio players", the warn-don't-crash path (NFR16), no bus effects.
- **`scripts/resources/audio_cue.gd` / `audio_library.gd`** — add fields only; `get_cue()` unchanged.
- **`scripts/run/run_frame.gd`** — owns state; ambience on exactly while `RUNNING` via `set_ambience`. Add `play_music` / `duck_music` seams beside it. The pause toggles already mute buses and save settings — keep. Don't add anything that waits in the typing path.
- **`scripts/levels/zombie_run/zombie_run_level.gd`** — `request_voice` seam + the one `_rng.randf()` per brain. Add `play_sfx` seam; the run RNG must keep exactly one consumer.
- **`scripts/levels/zombie_run/villager.gd`** — WAITING → HUGGED → POOFED; `_start_poof()` is where the cloud starts. Add the seam; don't change the sequence timing.
- **`scripts/screens/report_card.gd`** — reveal in `_process` from `_open_s` (not run during the Router's paused fade-in, so sounds start once the card is live); `_leave()` is the only navigation, ignored during the 1 s guard and after the first call. Sounds hook into those exact points.
- **`scripts/screens/crypt_closet.gd`, `welcome_gift.gd`** — already have `play_sfx` seams; add `play_music`. Closet: click on Wear/Unwear/leave, jingle on buy.
- **`scripts/screens/title.gd`, `main_menu.gd`** — already request `mus_menu`; title calls `unlock()` then the click inside the input callback — keep that order.
- **`scripts/autoloads/router.gd`** — untouched. It pauses the tree for ~0.3 s per transition; that's why the fade must run on AudioManager's `_process` (ALWAYS).
- **Tests that encode the old state** and must be updated: `test_audio_library.gd` (`test_real_library_has_placeholders`, `test_real_library_menu_music_loops` asserts WAV), `test_audio_manager.gd` (`_music_player()` uses node `Music`; pool test expects 1 music player).

### Deferred items closed (strike in Task 9.2)

1.4: first UI click silent on web (Task 4.8, or re-recorded); round-robin steal untestable (`_is_busy`). 1.4 review: vacuous no-restart test (`_is_busy`). 1.5 review: unknown id overwrites pending (4.2). 2.9: chalk-scratch per row, chime, menu music on the report card (stamp thump → post-MVP). 3.2: no bonk SFX; placeholder `vo_brainsss_01`. 3.3: no hug-poof SFX. 3.7: real groans and the mix; the flaky voice-steal test. 4.4: Closet music; the hand-written `sfx_purchase` UID (if the file is replaced); the placeholder jingle starting at -1. Leave open with a note: 3.4 conga join SFX, 3.5 dance music, 4.5 gift/arrow sounds, 5.0 brain counter tick / ×N pop / Closet tick-down (not in FR50; post-MVP or Smuck's call).

### Godot 4.7 notes

- OGG import: importer `oggvorbisstr`, type `AudioStreamOggVorbis`; params `loop` (bool) and `loop_offset` (s). Runtime: `AudioStreamOggVorbis.loop`, `get_length()`. Godot has no OGG encoder (only `load_from_file`/`load_from_buffer`).
- WAV import params as in the existing `.import` files (`edit/loop_mode`, `compress/mode=2`). `AudioStreamWAV.save_to_wav()` writes 16-bit PCM from a tool.
- Web: playback uses Web Audio **samples** by default (`audio/general/default_playback_type.web`); bus volume/mute works; per-player volume changes during sample playback must be verified (Task 8.1). Fallback per player: `playback_type = AudioServer.PLAYBACK_TYPE_STREAM` (the project is single-threaded web; listen for crackle). Forum reports note NaN errors when tweening `volume_db` from `-INF` — clamp gain (Task 4.3).
- `AudioStreamPlayer.playing` stays false under the headless Dummy driver, so tests must not depend on it (hence `_is_busy`).

### Testing notes

- GUT 9.7.1; run headless: `"/c/Program Files/Godot/Godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd` (after `--headless --import` when a `class_name` or asset changed). Baseline before starting: record the suite count (5.0 ended at ~1190+ tests passing).
- Never assert on the live `AudioManager` (title `_ready()` talks to it); use fresh instances with a code-built library, like `test_audio_manager.gd`. Mute is global `AudioServer` state: reset it in `after_each`.
- Fake clock via `now_msec`; seeded `ambience_rng` / `variant_rng`; music fade by calling `_step_music(delta)` directly.
- Typed `for` variables and declarations (`untyped_declaration = Error`, tests too). `assert()` shows as SCRIPT ERROR in headless GUT: use `Log` + safe returns. `assert_push_warning` matches substrings.
- Real-save trap (4.5): `test_screen_flow.gd::test_every_screen_instantiates` instances every screen with live autoloads — new `_ready()` calls must be harmless (a locked `play_music` is).

### Previous story intelligence

- **5.0:** art-story template = generator tool in `tools/`, tests that walk every asset, named manual checklist, approval gates recorded verbatim, screenshots/evidence under `screenshots/<story>/`. The browser pane throttles the web build to ~1 fps when hidden — keep it on screen for live walks, or ask Smuck to listen (the dev agent can't hear audio; Gate B is Smuck's ears). The 5.0 note "flaky `test_audio_manager` pool test: rerun once before investigating" — this story should make it deterministic.
- **3.7:** ambience rules and the one-directional 2 s mute; a groan already playing finishes on pause (by design).
- **3.2:** the Brainsss roll is the run RNG's only consumer; voice id `vo_brainsss` stays the call.
- **1.4:** the web unlock gap (first click silent) and why.
- **Traps:** LF line endings, UTF-8; write `.import`-generated UIDs, don't invent them; commit `.import` files with assets.

### Git intelligence

- One commit per story: code, data, assets + `.import`, tests, story file, sprint status. Last: `4d3fb6f Story 5.0: MVP UI art pass (code review patches applied, done)`. Asset stories commit the binaries with their `.import`; tools stay in `tools/`.

### Project Structure Notes

- New: `assets/audio/music/mus_menu.ogg`, `mus_zombie_run.ogg`; `assets/audio/sfx/sfx_brain_bonk.wav`, `sfx_hug_poof.wav`, `sfx_chalk_scratch.wav`, `sfx_report_chime.wav`; `assets/audio/voice/vo_brainsss_02.wav`; replaced: the other placeholders; `tests/unit/test_audio_credits.gd`; possibly `tools/gen_audio.gd`, `tools/encode_ogg.py`.
- Folders match the architecture tree (`assets/audio/{music,sfx,voice}`, `data/audio/audio_library.tres`). Groans stay in `sfx/` (as built in 3.7) though they are voice-like; don't move them (UIDs, tests).
- Variance: two music players instead of one (documented in Task 9.1).

### Project Context Rules

- No `project-context.md`. Binding rules from `_bmad-output/game-architecture.md`:
  - Only `AudioManager` creates audio players and holds audio rules (throttles, gaps, crossfade, duck). Callers only ask (`play_sfx`, `play_voice`, `play_music`, `set_music_ducked`).
  - Static data in Resources (`AudioLibrary` / `AudioCue` / `LevelConfig`); no audio numbers as script literals except look-value `const`s commented as such.
  - Typed GDScript; `%UniqueName`; typed past-tense signals; no global EventBus; autoload signal connections disconnected in `_exit_tree`.
  - Seams as `Callable`s set before `add_child`, defaulting to the autoload in `_ready()` (house pattern).
  - NFR16: a missing sound warns once and never stops anything. NFR10: nothing scary. NFR14: CC0-style or self-recorded only.
  - Autoload order `WebPlatform → SaveService → PlayerData → AudioManager → Router` unchanged; still five autoloads (`test_project_settings.gd`).
- Tools: Godot `/c/Program Files/Godot/Godot.exe` (4.7.2); GUT 9.7.1; Godot MCP server; the built-in browser pane (`web-debug`, port 8060). Downloads and package installs only with Smuck's explicit yes.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 5.1: MVP Audio Pass and Mix] (ACs); Epic 5 goal; FR46–FR50, NFR10, NFR14, NFR16; Stories 1.4, 2.5, 3.2, 3.7, 4.4 (audio ACs already built)
- [Source: _bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md#Audio and Music] (l.374–380), Asset Requirements audio row (l.413), assumption A5 (l.494)
- [Source: …/ux-designs/…/EXPERIENCE.md] Game Feel (l.179–188: wrong key, button press, screen change crossfade 0.5 s, report card scratch/chime), level-card "no sound" (l.89), audio optional (l.211)
- [Source: _bmad-output/game-architecture.md] D7 Audio (l.166), Audio Architecture (l.299–305), formats (l.291), web audio (l.80, 125), directory tree (l.585–602), naming (l.748, 756), boundaries (l.771)
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] items in "Deferred items closed"
- [Source: scripts/autoloads/audio_manager.gd, scripts/resources/audio_cue.gd, audio_library.gd, data/audio/audio_library.tres, assets/audio/CREDITS.md, tools/gen_placeholder_audio.gd, scripts/run/run_frame.gd, scripts/levels/zombie_run/zombie_run_level.gd, villager.gd, scripts/screens/*.gd, tests/unit/test_audio_manager.gd, test_audio_library.gd]
- [Forum: Godot volume tween NaN / web fade reports](https://forum.godotengine.org/t/audio-tweening-audiostreamplayer-volume-db-from-inf-db-to-0-0db/88343), [web popping on stop](https://forum.godotengine.org/t/audiostreamplayer-stop-causes-popping-noise-in-web-build/104413)

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5), Claude Code dev-story workflow.

### Debug Log References

- Baseline before the story: 1236/1236 GUT tests. After: 1298/1298, run twice (the old flaky pool / voice-steal test is now deterministic through `_is_busy`).
- `soundfile` 0.14 (libsndfile 1.2.2) wrote a 3,990-byte OGG and exited silently when given the whole 96 s buffer in one `write()`; writing in 8192-frame blocks fixed it (`tools/encode_ogg.py`).
- `tools/gen_audio.gd` is deterministic: a rerun left all 15 WAVs (13 SFX/voice + 2 music intermediates) byte-identical (md5).
- Imported WAVs keep `compress/mode=2` (QOA) like every earlier file, so the imported `AudioStreamWAV.format` isn't `FORMAT_16_BITS`; the 16-bit check (7.1) reads each source file's RIFF header instead (PCM, 16-bit, mono, 44.1 kHz, peak <= -1 dBFS, no leading silence, zero at both ends).
- **Task 8.1 / 4.8 web check** (debug web export, `web-debug` preview, Chrome-based browser pane; Web Audio `AudioParam` and `AudioBufferSourceNode.start` instrumented from the page):
  - Per-player volume changes are applied with Godot's default web **sample** playback: the music sample's gain params step every frame through the fade-in (0.0001 -> 0.1995 = -14 dB), the crossfade (menu 0.1995 -> 0.0014 then stopped, run loop 0.0001 -> 0.1585 = -16 dB) and the duck (0.1585 -> 0.0501 = -26 dB on Esc, still 0.0501 through the countdown, back to 0.1585 when the run is live). No `PLAYBACK_TYPE_STREAM` fallback needed. Crackle and pops can only be judged by ear (M7, M8).
  - In the pane the run-start crossfade stretched to ~1.6 s: right after the level load the pane ran ~15 fps with smoothed delta (the same throttling 4.4 saw on the run timer). The duck ramp ran at 60 fps as expected. Real Chrome is M7.
  - First-click hold: the held title click starts on the first frame after the unlock frame. On a fresh load: long tasks of 143 ms + 111 ms at unlock (Godot registers the 96 s menu loop as a Web Audio sample on first play), the menu loop started at +256 ms, the click at +371 ms. First run start: one 163 ms long task; later trips have none. Audibility of the first click is M11 (Smuck's ears). Logged in deferred-work.
  - Clicks seen on web: title, Zombie Run card, Esc pause, Resume, Quit to Menu (one `start` of the 0.04 s buffer each).

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created.
- Gate A (2026-10-06): Smuck chose everything generated (voices, SFX, music) and approved `soundfile` via `uv run --with soundfile`; the ~15 MB size (numpy) was corrected and re-approved before downloading. Recorded verbatim under `## Audio Approval`.
- Assets: `tools/gen_audio.gd` (replaces `gen_placeholder_audio.gd`, deleted) synthesizes all 13 SFX/voice files (RBJ biquads, PolyBLEP saw + 3 formant band-passes for the groans and the two Brainsss takes, Karplus-Strong plucks, marimba, soft drums) and renders two 96 s loops (menu: C major 120 bpm oom-pah; Zombie Run: calm A minor 100 bpm tiptoe bass), wrapped so the loop point is seamless. `tools/encode_ogg.py` encodes them. The `mus_menu.wav` placeholder is removed. The purchase jingle's hand-written UID was replaced by a Godot-generated one (`uid://83x7bo15sy2k`). CREDITS.md rewritten (File | Source | Author | License).
- Library: 14 cues (11 SFX incl. 4 groans, `vo_brainsss` with an alt take, 2 music), `alt_streams` on `AudioCue`, `music_crossfade_s = 0.5` and `music_pause_duck_db = -10` on `AudioLibrary`; throttles on bonk 0.06 / poof 0.08 / chalk 0.05; starting volumes from Dev Notes.
- AudioManager: `MusicA`/`MusicB` crossfade driven by `_step_music(delta)` in `_process` (linear gain, `MIN_GAIN` floor, never -INF); the same loop never restarts; the fading-out loop swaps back in from its gain; a third loop cuts the one still fading out. `set_music_ducked()` / `is_music_ducked()` with a 0.15 s ramp, cleared by a new loop and by `stop_music()`. Unknown ids warn and change nothing (locked or not). `variant_rng` take picks. `_is_busy()` and `_play_player()` test seams. SFX in the unlock frame are held and played once on the next frame (`frame_now` seam).
- Music per screen: `LevelConfig.music_id` (Zombie Run `mus_zombie_run`, test level empty). RunFrame `play_music` / `duck_music` / `play_sfx` seams: music at a successful start; duck on PAUSED, kept through COUNTDOWN, off when the countdown ends; un-duck in `_exit_tree`. Report card, Closet and Welcome Gift ask for `mus_menu` through a `play_music` seam; the run loop plays on through the dance and the report card crossfades back.
- Event sounds: bonk in `ZombieRunLevel.on_char_accepted` (no RNG use; `test_run_rng_has_one_consumer` passes); hug-poof in `Villager._start_poof()` through the seam the level hands it (silent without); report card scratch per row the frame it shows + one chime when the reveal is done (stamp silent); click in report card `_leave()`; pause clicks in RunFrame (Esc / pause button when they pause, Resume, Quit, both toggles; focus loss silent). Closet: Buy (prompt opens) and No / Esc now click too (every button clicks once, M10); Yes plays the jingle only; a stale-prompt auto-cancel stays silent.
- Tests: +62 (audio manager crossfade/duck/variants/unlock hold/steal, library spec + source-file checks, new `test_audio_credits.gd`, run frame music/duck/clicks, report card sounds, Closet/gift music + Closet clicks, level bonk/poof, villager poof sound). Every test that builds a run frame, report card, Closet or gift injects recorders, so the live AudioManager's pending music is never touched (7.5).
- Docs: architecture Audio section (two music players, `set_music_ducked()`); deferred-work items closed or left open with notes, plus a new 5.1 section.
- Gate B (2026-10-06): Smuck walked the Mix Checklist and approved ("all is good please continue"); every row Pass, no volume changes needed.

### File List

- `_bmad-output/game-architecture.md` (modified)
- `_bmad-output/implementation-artifacts/5-1-mvp-audio-pass-and-mix.md` (story)
- `_bmad-output/implementation-artifacts/deferred-work.md` (modified)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified)
- `assets/audio/CREDITS.md` (rewritten)
- `assets/audio/music/mus_menu.ogg`, `.ogg.import` (new)
- `assets/audio/music/mus_zombie_run.ogg`, `.ogg.import` (new)
- `assets/audio/music/mus_menu.wav`, `.wav.import` (deleted)
- `assets/audio/sfx/sfx_brain_bonk.wav`, `sfx_hug_poof.wav`, `sfx_chalk_scratch.wav`, `sfx_report_chime.wav` + `.import` (new)
- `assets/audio/sfx/sfx_ui_click.wav`, `sfx_wrong_key.wav`, `sfx_purchase.wav` (+ `.import`, new UID), `sfx_groan_01..04.wav` (replaced)
- `assets/audio/voice/vo_brainsss_01.wav` (replaced), `vo_brainsss_02.wav` + `.import` (new)
- `data/audio/audio_library.tres`, `data/levels/zombie_run.tres` (modified)
- `scripts/autoloads/audio_manager.gd` (modified)
- `scripts/resources/audio_cue.gd`, `audio_library.gd`, `level_config.gd` (modified)
- `scripts/run/run_frame.gd` (modified)
- `scripts/levels/zombie_run/zombie_run_level.gd`, `villager.gd` (modified)
- `scripts/screens/report_card.gd`, `crypt_closet.gd`, `welcome_gift.gd` (modified)
- `tests/unit/test_audio_credits.gd` (+ `.uid`) (new)
- `tests/unit/test_audio_library.gd`, `test_audio_manager.gd`, `test_crypt_closet.gd`, `test_report_card.gd`, `test_villager.gd`, `test_welcome_gift.gd`, `test_zombie_run_level.gd` (modified)
- `tests/integration/test_run_frame.gd`, `test_first_purchase_flow.gd` (modified)
- `tools/gen_audio.gd` (+ `.uid`), `tools/encode_ogg.py` (new)
- `tools/gen_placeholder_audio.gd` (+ `.uid`) (deleted)

## Change Log

- 2026-10-06: Story 5.1 dev: Gate A (all generated), final MVP audio + credits, AudioManager crossfade/duck/variants/unlock-frame hold, music per screen, every FR50 event sound and button clicks, tests (1298 passing), web check of per-player volume, docs. Gate B approved; status -> review.
