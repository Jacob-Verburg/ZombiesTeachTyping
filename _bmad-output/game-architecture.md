---
title: 'Game Architecture'
project: 'zombies-teach-typing'
date: '2026-09-27'
author: 'Smuck'
version: '1.0'
stepsCompleted: [1, 2, 3, 4, 5, 6, 7, 8, 9]
status: 'complete'

# Source Documents
gdd: '_bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/gdd.md'
epics: '_bmad-output/planning-artifacts/gdds/gdd-zombies-teach-typing-2026-09-27/epics.md'
brief: '_bmad-output/planning-artifacts/briefs/brief-zombies-teach-typing-2026-09-27/brief.md'
engine: 'Godot 4.7 (Compatibility renderer, GDScript)'
platform: 'Web (HTML5, GitHub Pages) primary; Windows desktop fallback'
---

# Game Architecture

## Executive Summary

**Zombies Teach Typing** architecture is designed for Godot 4.7 (Compatibility renderer, GDScript only), targeting a single-threaded HTML5 build on GitHub Pages, with a Windows desktop fallback.

**Key Architectural Decisions:**

- **One shared typing pipeline** (`TypingInput` → `TypingSession` → `RunFrame`) feeds every level through the `LevelBase` contract; levels never read input (ADR-1).
- **Versioned, profile-shaped JSON save** in `user://`, with atomic writes, a backup, ordered migrations and coalesced writes, owned by `SaveService`/`PlayerData` (ADR-2, ADR-3).
- **"Logic leads, visuals chase":** game state updates on the same frame as a correct key; animations retarget and never gate input (17 ms feedback target).
- **Five autoloads** (`WebPlatform`, `SaveService`, `PlayerData`, `AudioManager`, `Router`), local typed signals, and no global event bus (ADR-5).
- **GitHub Actions CI:** GUT tests → web export → GitHub Pages deploy (ADR-4).

**Project Structure:** Hybrid organization (type folders with mirrored feature folders), with 16 core systems mapped to locations.

**Implementation Patterns:** 2 novel + 4 standard patterns and 12 consistency rules keep AI agents' code consistent.

**Ready for:** Epic implementation phase (Epics 1–5 = MVP).

## Project Context

### Game Overview

**Zombies Teach Typing** - A goofy typing tutor for kids 6–13 where the player *is* the zombie. Three standalone, replayable lessons (Zombie Run: letters; Horde Rush: words; Pitchfork Panic: paragraphs) share one typing frame; brains earned buy cosmetics in the Crypt Closet.

### Technical Scope

**Platform:** Web (HTML5, single-threaded, static hosting, desktop Chrome/Edge/Firefox) primary; Windows desktop fallback
**Engine:** Godot 4.7, Compatibility renderer, GDScript only
**Genre:** Educational typing arcade (2D pixel art, 640×360 logical)
**Project Level:** Low–medium complexity; solo developer; MVP = Epics 1–5, post-MVP = Epics 6–11

### Core Systems

| System | Complexity | GDD Reference | Phase |
|---|---|---|---|
| Typing input & judgment (letter/word/paragraph target modes, ignored keys, echo/dead-key handling, case rules, browser key capture) | High | M1, Controls and Input | MVP (word/paragraph post-MVP) |
| Stats & run recording (WPM, accuracy, per-key attempts/errors) | Medium | M2, Input & Judgment Model | MVP |
| Save service (versioned, migratable; 500-run history; web persistence) | Medium | Platform-Specific Details | MVP |
| Shared frame: HUD, zombie hands finger guide, pause/focus-loss, report card | Medium | M2b, M3, Finger Guide, Screens & Flow | MVP |
| Screen flow / scene management | Low | Screens & Flow | MVP |
| Brains economy & Crypt Closet (catalogue, buy/equip, welcome gift tutorial) | Low-Medium | M4, M5, Economy | MVP |
| Cosmetic overlay system (hat anchor per pose, pet slot) | Medium | Art Style, M4 | MVP |
| Zombie Run level (target queue, amble/scoot, letter bag, conga line) | Medium | Level 1 | MVP |
| Audio (unlock, throttled groans/voice lines, Music/SFX buses, toggles) | Low-Medium | Audio and Music | MVP |
| Automated tests (GUT, headless; judgment, stats, save migration, tiers) | Low | Epic 2 story 1, Epic 7 story 1 | MVP |
| Build & deploy pipeline (web export preset, static-host publish) | Low | Epic 1 story 1 | MVP |
| Horde Rush (lanes, spawning, size classes, defender AI, projectiles) | Medium | Level 2 | Post-MVP |
| Adaptive curriculum (rolling WPM, 5 tiers, hysteresis, placement) | Medium | Adaptive Difficulty | Post-MVP |
| Content pipeline (word list tagging, paragraph pools, sentence generator) | Medium | Content: Word Lists & Paragraphs | Post-MVP |
| Pitchfork Panic (step movement, mob model, camera, pickups, endings) | Medium | Level 3 | Post-MVP |
| Theme rotation, trends screen, profiles + save migration | Low-Medium | Level Progression, Epics 10–11 | Post-MVP |

### Technical Requirements

- **Frame rate:** 60 FPS steady; no frame > 33 ms over a full 2:00 Zombie Run with 12 conga followers (post-MVP: 30-zombie stress scene)
- **Input latency:** correct keystroke → visible feedback on the next rendered frame (≤ 17 ms); animations never gate input (≈5+ keys/s)
- **Input edge cases:** key-repeat (echo) events are ignored entirely (neither progress nor error); events with no printable character (`unicode == 0`, dead keys, IME composition) are ignored; matching is by typed character, not physical key
- **Resolution:** 640×360 logical, integer scaling where possible, 32-color palette, pixel-perfect sprites
- **Load:** first load ≤ 10 s @ 25 Mbit/s (the governing budget, ≈30 MB compressed on the wire); cached ≤ 3 s; hard cap on total download ≤ 500 MB; measured in Epic 1
- **Save integrity:** zero loss across 10 reloads + 10 tab closes; writes at run end, quit, purchase/equip, settings change
- **Audio (web):** playback uses Web Audio samples; per-bus volume/mute supported, bus effects not relied upon
- **Networking:** none (no multiplayer, accounts, cloud saves or analytics)
- **Input hardware:** physical keyboard only; US QWERTY finger map; character-based matching

### Complexity Drivers

- **Shared typing frame reused by three very different levels** — requires a clean level-plugin contract so levels consume judgment events rather than reading input.
- **Long-lived save schema** — run history and per-key data must remain valid through adaptive difficulty (Epic 7) and profiles (Epic 11); needs versioning and migration from the start.
- **Browser platform quirks** — key swallowing, audio unlock, focus-loss pause, IndexedDB persistence timing.
- **Non-blocking feedback** — overlapping/skippable animations and throttled audio at high typing speed.
- **AI-generated art consistency** — overlay anchors and sprite standards must be encoded as data so cosmetics fit every pose.

### Technical Risks

- Web export (single-threaded, no special headers) behaving differently from desktop for input, audio or saves — retired in Epic 1.
- Save loss on tab close: `user://` → IndexedDB sync is asynchronous; must be proven with the reload/tab-close test in Epic 1.
- Web export size versus the 10 s first-load budget; if exceeded, strip unused engine modules (3D) via a custom export template.
- Input feedback latency on low-end integrated graphics under the Compatibility renderer.
- Current `project.godot` stretch settings (`canvas_items` / `expand`, default viewport) conflict with the 640×360 pixel-art spec; leftover `[dotnet]` and Jolt 3D settings are unused.

## Engine & Framework

### Selected Engine

**Godot** v4.7 (stable; track 4.7.x patches — 4.7.2 current as of 2026-09-27)

**Rationale:** Free and open source, first-class 2D, small solo-friendly workflow, and a web export that runs single-threaded on plain static hosting with no special headers. GDScript only (C# cannot export to web). Chosen in the game brief; verified against 4.7 web-export documentation.

### Project Initialization

No starter template. The existing project is used, with these settings corrected in Epic 1:

- `display/window/size/viewport_width = 640`, `viewport_height = 360`
- `display/window/stretch/mode = "viewport"`, `aspect = "keep"`, `scale_mode = "integer"`
- `rendering/textures/canvas_textures/default_texture_filter = Nearest`
- `rendering/2d/snap/snap_2d_transforms_to_pixel = true`
- Remove the unused `[dotnet]` section; 3D physics setting is irrelevant (no 3D)
- Web export preset: Thread Support **off**, VRAM compression for desktop only

### Engine-Provided Architecture

| Component | Solution | Notes |
| --------- | -------- | ----- |
| Rendering | Compatibility renderer (OpenGL ES 3 / WebGL 2), 2D canvas | Pixel-perfect via viewport stretch + integer scale + nearest filtering |
| Physics | Not used | No collisions needed; movement is scripted/tweened |
| Audio | AudioServer with buses; web uses sample playback | Per-bus volume/mute only; no bus effects; audio starts after first user gesture |
| Input | InputEvent pipeline (`_input` / `_unhandled_input`), `InputEventKey.unicode`, `echo` | Typing reads characters, not InputMap actions; menus use InputMap (`ui_*`) |
| Scene Management | SceneTree, PackedScene, autoload singletons | Screen switching approach decided in Architectural Decisions |
| UI | Control nodes, Theme resource | One shared Theme with the pixel font |
| Animation | AnimatedSprite2D / SpriteFrames, Tween, AnimationPlayer | Non-blocking by design |
| Persistence | FileAccess on `user://` → IndexedDB on web | Format, versioning and flush strategy decided in Architectural Decisions |
| Build System | Godot export presets (Web, Windows Desktop), headless CLI export | Compression and hosting decided in Architectural Decisions |
| Testing | GUT 9.7.x (addon, headless CLI) | Supports Godot 4.7 |

### Development Tools (AI-assisted)

- **Godot MCP** (already connected): launch editor, run project, read debug output, scene/node creation, UID management
- **Context7** (`upstash/context7`): current Godot 4.7 API docs — recommended
- **GoPeak** (`HaD0Yun/Gopeak-godot-mcp`): optional upgrade for runtime screenshots and input injection

**Decision:** the connected Godot MCP is used as-is. Context7 and GoPeak are optional and can be added at any time; no setup is required for Epic 1.

### Remaining Architectural Decisions

1. Scene/screen flow management (scene swap vs persistent root with swappable screen)
2. Autoload (singleton) set and responsibilities
3. Typing pipeline architecture and the level-plugin contract (signals/events)
4. Save format (JSON vs Resource), schema versioning, migration and IndexedDB flush strategy
5. Game data definition (catalogue, finger map, level tuning) — Resources vs JSON
6. Cosmetic overlay anchoring (per-frame anchor data)
7. Audio manager: throttling, unlock, bus layout
8. Hosting target and deploy path (GitHub Pages auto-gzip vs itch.io)
9. Test strategy and CI (GUT headless; what is unit-tested vs manually playtested)

## Architectural Decisions

### Decision Summary

| # | Category | Decision | Version | Rationale |
|---|---|---|---|---|
| D1 | Scene Flow | `Router` autoload + `change_scene_to_packed` with fade layer; payloads passed via `Router.go(screen, payload)` | Godot 4.7.x | Engine-native, screens stay independent |
| D2 | Global Services | 5 autoloads: `SaveService`, `PlayerData`, `Router`, `AudioManager`, `WebPlatform`; no global EventBus | — | Minimal globals; local signals are traceable for AI agents |
| D3 | Typing Pipeline | `TypingInput` → `TypingSession` (pure logic) → `RunFrame` → `Level` (extends `LevelBase`) | — | One set of input rules shared by all levels; testable without scenes |
| D4 | Save System | JSON via `FileAccess`, versioned, profile-shaped from v1, atomic write + backup | — | Readable, migratable, no Resource-loading risks; avoids an Epic 11 migration |
| D5 | Static Game Data | Typed custom Resources (`.tres`); generated content (word lists, paragraphs) as JSON | — | Inspector-editable and type-checked; separate from save data |
| D6 | Cosmetic Anchoring | `SpriteAnchors` resource (head point per animation frame) + `HatSlot` following `frame_changed` | — | Any hat fits every pose without redrawing sprites |
| D7 | Audio | `Master → Music / SFX` buses; pooled SFX players; throttling centralized in `AudioManager`; OGG music, WAV SFX | — | Works within web sample playback; one place for audio rules |
| D8 | Hosting & Deploy | GitHub Pages (public repo) via GitHub Actions | — | Automatic gzip for load budget; avoids itch.io iframe storage risk |
| D9 | Testing & CI | GUT in `addons/gut`; GitHub Actions: official Godot headless → GUT → web export → Pages deploy | GUT 9.7.1, Godot 4.7.2 (verified 2026-09-27) | Pure logic is unit-tested; feel is playtested |
| D10 | Asset Loading | Per-scene `preload`; no streaming or threaded loading | — | Small game; single-threaded web build |

### State Management

**Approach:** Autoload services for persistent state; enum state machine for the run.

- `PlayerData` is the single in-memory source of truth for the active profile (brains, owned/equipped cosmetics, flags, settings, bests, run history). All mutations go through its methods (`add_brains()`, `buy_item()`, `equip()`, `record_run()`, `set_setting()`), each of which emits a typed change signal and requests a save. No other code writes save fields directly.
- The run lifecycle lives in `RunFrame` as an enum state machine:
  `WAITING_FIRST_KEY → RUNNING ⇄ PAUSED → COUNTDOWN → RUNNING … → ENDING → DONE`
  - `WAITING_FIRST_KEY`: first target shown, clock stopped, "Type the letter to start!"
  - `PAUSED`: entered by Esc, the pause button or `WebPlatform.focus_lost`; clock and world frozen (`get_tree().paused = true`; `PausePanel` and `Countdown` use `PROCESS_MODE_WHEN_PAUSED`)
  - `COUNTDOWN`: 3-2-1 at 0.5 s each; the tree **stays paused** (world frozen) and input is rejected; focus loss returns to `PAUSED`. The tree is unpaused only on entering `RUNNING`.
  - `ENDING`: level outro (dance, dust cloud, escape); input rejected
- `RunClock` accumulates `delta` only while `RUNNING`; it is not wall-clock based, so pausing is exact.

### Screen Flow

`Router` (autoload) owns a `CanvasLayer` fade overlay and a screen registry:

```gdscript
enum Screen { TITLE, MAIN_MENU, RUN, REPORT_CARD, WELCOME_GIFT, CRYPT_CLOSET }
func go(screen: Screen, payload: Dictionary = {}) -> void
func take_payload() -> Dictionary   # called once by the incoming screen in _ready()
```

- `RUN` payload: `{ "level_id": StringName }`. `RunFrame` instances the level scene named in the level registry.
- `REPORT_CARD` payload: `{ "result": RunResult }`.
- Flow: Title → Main Menu → Run → Report Card → (Welcome Gift → Crypt Closet, first completed run only) → Play Again (Run, same level) | Menu.

### Typing Pipeline & Level Contract

```
TypingInput (Node)
  InputEventKey → reject echo, unicode == 0, ignored keys → apply case rule → emit char_typed(char)
      ↓
TypingSession (RefCounted — no nodes, fully unit-testable)
  holds TargetSource; judge(char) → CORRECT | WRONG
  tracks keys_typed, errors, per-key {attempts, errors, mistyped_as{}}, implied spaces
  signals: run_started, char_accepted(expected, index), char_rejected(expected, typed),
           target_completed(target), target_changed(next)
      ↓
RunFrame (scene)
  owns HUD, ZombieHands, RunClock, pause/countdown, state machine; builds RunResult at end
  └── Level (scene extending LevelBase)
```

- **`TargetSource`** (RefCounted interface): `peek(n) -> Array`, `current() -> String`, `advance()`. Implementations: `LetterBagSource` (MVP), `WordSource` (Epic 6), `ParagraphSource` (Epic 8).
- **`LevelBase`** (extends `Node2D`) is the only contract a level implements:

```gdscript
class_name LevelBase extends Node2D
signal end_requested(reason: StringName)          # e.g. &"caught"
func get_level_config() -> LevelConfig             # duration, case rule, target mode, bonuses
func create_target_source(rng: RandomNumberGenerator) -> TargetSource
func on_run_started() -> void
func on_char_accepted(expected: String, index: int) -> void
func on_char_rejected(expected: String, typed: String) -> void
func on_target_completed(target: String) -> void
func on_run_ending(reason: StringName) -> float    # returns outro duration in seconds
func get_brains_earned() -> int
```

- **`TypingInput` configuration:** `RunFrame` configures it from the level's `LevelConfig` (`case_sensitive`, `space_is_input`). In lowercase levels, letters are lowercased and Space is ignored; in Pitchfork Panic, case is kept and Space is input.
- **Caps Lock hint:** `TypingInput` emits `caps_lock_suspected` after 3 consecutive capital letters (checked on the raw character, before lowercasing) and `caps_lock_cleared` on the next lowercase; `Hud` shows or hides the hint.
- **Rules:** levels never read input, never touch the clock, and never write to `PlayerData`. `RunFrame` awards brains and records the run.
- **Brains during a run:** the in-run brain counter shows the level's local total. Brains reach `PlayerData` only at run end or quit, so closing the tab mid-run loses that run's brains. This is intended and matches the GDD save points.
- **Feedback latency:** `char_accepted` is emitted synchronously inside the input callback, and levels start their reaction in the same frame. Animations are fire-and-forget (Tweens and AnimatedSprite2D); nothing awaits an animation before the next input.
- **Randomness:** each run creates one `RandomNumberGenerator`, which is passed to the target source and the level; tests inject a fixed seed.

### Data Persistence

**Save System:** a versioned JSON file at `user://save.json`.

```json
{
  "schema_version": 1,
  "active_profile": "p1",
  "profiles": {
    "p1": {
      "name": "",
      "brains": 0,
      "owned_items": [],
      "equipped": { "hat": "", "pet": "" },
      "flags": { "welcome_bonus_claimed": false, "tutorial_seen": false, "placement_done": false },
      "tier": 0,
      "settings": { "music_on": true, "sound_on": true },
      "best_wpm": { "zombie_run": 0 },
      "run_history": []
    }
  }
}
```

- **Run record:** `{ timestamp, level_id, duration_s, keys_typed, errors, wpm, accuracy, brains, letter_pool_or_tier, per_key: { "f": [attempts, errors, { "g": 2, "d": 1 }] }, end_reason }`. The history is capped at the newest 500 runs. Quit runs are not recorded; the brains from a quit run are still saved.
- **Write strategy:** serialize → write `save.tmp` → rename it over `save.json`, keeping the previous file as `save.bak`. On load, fall back to `.bak` if the main file fails to parse. If renaming proves unreliable on the web file system in Epic 1, switch to direct write plus backup.
- **When to save:** run end, quitting a run, purchase or equip, settings change, `WebPlatform.visibility_hidden`, and `NOTIFICATION_WM_CLOSE_REQUEST`.
- **Coalescing:** `SaveService.request_save()` sets a dirty flag and schedules one write with `call_deferred`, so several changes in the same frame (buy then equip) produce a single write. `visibility_hidden` and close requests write immediately.
- **Migration:** `SaveService` runs ordered `migrate_N_to_N1(data: Dictionary) -> Dictionary` functions up to `CURRENT_SCHEMA`. Every migration has a GUT test with a fixture file.
- **Persistence check:** if `OS.is_userfs_persistent()` is false, the main menu shows a small plain-words notice ("Progress may not be saved in this browser mode").
- **Defaults:** a missing field is filled from defaults on load, and unknown fields are kept rather than dropped.

### Static Game Data

- Typed custom Resources live under `res://data/`:
  - `CosmeticItem` (id, slot, price, row, is_available, icon, overlay texture, pet SpriteFrames)
  - `Catalogue` (the item list)
  - `FingerMap` (character → finger and hand, plus the Shift pairing)
  - `LevelConfig` (duration, case rule, target mode, tuning numbers)
  - `SpriteAnchors`
- Tuning numbers from the GDD live in `LevelConfig` resources, never as literals in scripts.
- Generated content (post-MVP) is JSON under `res://data/content/`. It includes the word list with row/length tags, paragraphs by tier, and a pool validation report, and it is produced by an offline GDScript tool run headless (`godot --headless -s tools/tag_words.gd`), so no Python toolchain is needed.

### Asset Management

**Loading Strategy:** per-scene `preload()`. There is no runtime streaming or threaded loading.

- Art imports as 2D pixel textures with the Nearest filter and no mipmaps.
- Sprite sheets use `SpriteFrames` resources.
- Audio: OGG Vorbis for music loops, 16-bit WAV for short sound effects.

### Cosmetics

- **Hat:** each zombie scene has a `HatSlot` (Node2D) child. On `AnimatedSprite2D.frame_changed`, it moves to `SpriteAnchors.head[animation][frame]`. The same anchors serve Horde Rush size classes through the zombie's scale. Professor Zombie uses its own anchor set.
- **Pet:** the HUD and the report card each hold a `PetSlot` that instances the equipped pet's idle `SpriteFrames`.
- Both slots update from the `PlayerData.equipment_changed` signal.

### Audio Architecture

- Buses: `Master` → `Music`, `SFX`. The Music and Sound toggles mute their bus. No bus effects are used.
- `AudioManager` API: `play_sfx(id: StringName)`, `play_music(id: StringName)`, `play_voice(id: StringName)`, `start_ambience()` / `stop_ambience()`.
- **Throttling lives only in `AudioManager`:** wrong-key tick at most 1 per 150 ms; voice lines at least 8 s apart; the "Brainsss" chance (20%) is decided by the caller, and the cooldown by `AudioManager`; groans every 3–8 s at random and muted within 2 s of a voice line.
- A pool of 8 `AudioStreamPlayer`s for SFX, plus one music player.
- **Unlock:** no audio plays before the first key press or click on the title screen; `AudioManager.unlock()` is called from that input callback.

### Web Platform

`WebPlatform` (autoload) is a no-op on desktop exports (`OS.has_feature("web")`). On web:

- Emits `focus_lost` and `visibility_hidden` from browser blur and visibility events, via `JavaScriptBridge` callbacks.
- **Key swallowing:** during a run, Space, `'`, `/`, Backspace and Tab must not trigger browser actions. Epic 1 checks whether the Godot canvas already prevents these defaults; if not, `WebPlatform` installs a JS `keydown` listener that calls `preventDefault()` for those keys while `WebPlatform.capture_keys = true`.
- Exposes `is_storage_persistent()`.

### Hosting, Build & CI

- **Host:** GitHub Pages from a public repository; the web export is published by GitHub Actions and Pages serves it gzip-compressed.
- **Export:** a `Web` preset with Thread Support off and no PWA. A `Windows Desktop` preset is kept as a fallback.
- **CI workflow** (`.github/workflows/build.yml`) on each push to `main`:
  1. Download the official Godot 4.7.2 Linux headless build and export templates.
  2. Import the project headlessly, then run GUT (`-s addons/gut/gut_cmdln.gd`); fail the build on any test failure.
  3. Export the Web preset.
  4. Deploy to GitHub Pages.
- **Action versions:** Epic 1 story 1 pins and verifies the current major versions of `actions/checkout`, `actions/upload-pages-artifact` and `actions/deploy-pages`.
- **Load-budget check:** Epic 1 records the compressed transfer size and first-load time. If the time is over 10 s, a custom export template with 3D disabled goes on the backlog.

### Testing

- **GUT 9.7.1** in `addons/gut`. Tests live in `tests/unit/` and `tests/integration/`.
- **Must be unit-tested:** `TypingInput` filtering (tested with synthetic `InputEventKey`s), `TypingSession` judgment and case rules, stats and WPM formulas, `LetterBagSource` (no immediate repeats across bags), brain-block group shuffle, economy awards, `PlayerData` wallet and purchase rules, save migration and defaults, and tier hysteresis (Epic 7).
- **Playtested manually:** feel, animation timing, audio mix, readability. Epic checklists live in the story files.

### Architecture Decision Records

- **ADR-1: Levels never read input (D3).** *Context:* 3 levels must share identical typing rules. *Decision:* a single `TypingInput` + `TypingSession` feeds levels through `LevelBase` callbacks. *Consequence:* a new level only implements `LevelBase`; typing-rule fixes happen in one place.
- **ADR-2: Profile-shaped save from v1 (D4).** *Context:* Epic 11 adds profiles. *Decision:* `profiles` map with one entry in the MVP. *Consequence:* no data migration needed for profiles; one extra indirection in `PlayerData`.
- **ADR-3: JSON saves, Resource static data (D4/D5).** *Context:* saves must survive code changes; static data benefits from the Inspector. *Decision:* split the formats by purpose. *Consequence:* the save needs manual serialization code; static data is type-checked.
- **ADR-4: GitHub Pages over itch.io (D8).** *Context:* 10 s load budget; itch.io iframe can block IndexedDB. *Decision:* GitHub Pages via Actions. *Consequence:* public repository; no itch.io discoverability (acceptable: friends-and-family distribution).
- **ADR-5: No global EventBus (D2).** *Context:* small game, AI agents implementing features. *Decision:* signals stay local (parent/child, or on the owning autoload). *Consequence:* the flow is explicit; cross-screen communication goes through `Router` payloads and `PlayerData` signals.

## Cross-cutting Concerns

These patterns apply to ALL systems and must be followed by every implementation.

### Error Handling

**Strategy:** Check return values + fail safe. GDScript has no exceptions; errors are handled where they occur, logged through `Log`, and the game recovers to a safe state. **Errors never pause the game and never show technical text to the player.**

**Error Levels:**

| Level | Meaning | Handling |
|---|---|---|
| **Bug (contract violation)** | Code called wrongly (null level, unknown item id, target index out of range) | `assert(cond, "msg")` (debug builds only) + `Log.error()`; in release, return early with a safe default |
| **Recoverable** | File/JSON/IO failures, missing optional resource, storage not persistent | Check `Error` / null, `Log.warn()` or `Log.error()`, fall back (defaults, `.bak` save, skip the sound) |
| **Fatal to a screen** | A level or screen scene fails to load | `Log.error()`, then `Router.go(Screen.MAIN_MENU)`; brains already earned are kept |

**Player-visible errors:** only the plain-words "Progress may not be saved in this browser mode" notice on the main menu. Everything else recovers silently.

**Rules:**

- Functions that can fail return an `Error` code (IO) or a nullable object (lookups); callers must check.
- Never use `assert()` for runtime conditions (file missing, bad JSON), because it's stripped from release builds.
- Never let a missing sound, sprite or cosmetic stop a run.

**Example:**

```gdscript
# save_service.gd
func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		Log.error(&"save", "open failed %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return {}
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	if err != OK or typeof(json.data) != TYPE_DICTIONARY:
		Log.warn(&"save", "parse failed %s line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return {}
	return json.data

func load_save() -> Dictionary:
	var data := _read_json(SAVE_PATH)
	if data.is_empty():
		data = _read_json(BACKUP_PATH)          # fall back to backup
	if data.is_empty():
		Log.info(&"save", "no valid save, starting fresh")
		data = SaveSchema.defaults()
	return _migrate(data)

# catalogue lookup — contract violation
func get_item(id: StringName) -> CosmeticItem:
	var item: CosmeticItem = _items.get(id)
	assert(item != null, "Unknown cosmetic id: %s" % id)
	if item == null:
		Log.error(&"catalogue", "unknown item %s" % id)
	return item                                   # caller handles null
```

### Logging

**Format:** `[LEVEL][tag] message`. The tag is a `StringName` naming the system (`&"save"`, `&"typing"`, `&"audio"`, `&"router"`, `&"web"`, `&"economy"`, `&"level"`).
**Destination:** Godot output. That means the editor Output panel, the browser developer console on web, and `user://logs/` on desktop through Godot's built-in file logging. There is no external service and no analytics.

**Log Levels:**

| Level | Function | Use for | In release builds |
|---|---|---|---|
| ERROR | `Log.error()` → `push_error` | Something broke; a fallback was used | Yes |
| WARN | `Log.warn()` → `push_warning` | Unexpected but handled (parse fallback, storage not persistent) | Yes |
| INFO | `Log.info()` → `print` | Milestones: save loaded/written, run started/ended, purchase, screen change | Yes |
| DEBUG | `Log.debug()` → `print` | Diagnostics (judgments, anchor positions, audio throttles) | **No** (`OS.is_debug_build()` only) |

**Rules:**

- **Hot path:** never log inside `_process`. Per-keystroke logging is DEBUG only, and only while `Log.verbose_typing` is on.
- `Log` is a static class (`class_name Log`), not an autoload, so pure-logic classes and GUT tests can use it.
- Never log personal data. There isn't any besides the future zombie name, and that isn't logged either.

**Example:**

```gdscript
# scripts/core/log.gd
class_name Log

static var verbose_typing := false

static func error(tag: StringName, msg: String) -> void:
	push_error("[ERROR][%s] %s" % [tag, msg])

static func warn(tag: StringName, msg: String) -> void:
	push_warning("[WARN][%s] %s" % [tag, msg])

static func info(tag: StringName, msg: String) -> void:
	print("[INFO][%s] %s" % [tag, msg])

static func debug(tag: StringName, msg: String) -> void:
	if OS.is_debug_build():
		print("[DEBUG][%s] %s" % [tag, msg])

# usage
Log.info(&"run", "ended level=%s reason=%s wpm=%d" % [result.level_id, result.end_reason, result.wpm])
if Log.verbose_typing:
	Log.debug(&"typing", "rejected expected=%s typed=%s" % [expected, typed])
```

### Configuration

**Approach:** four kinds of values, each with one home.

| Kind | Home | Examples |
|---|---|---|
| **Game constants** (never change) | `const` in `GameConstants` (`class_name`, `scripts/core/game_constants.gd`) for shared values; `const` in the owning script for local ones | `LOGICAL_SIZE = Vector2i(640, 360)`, `RUN_HISTORY_CAP = 500`, `CURRENT_SCHEMA = 1`, `IGNORED_KEYCODES` |
| **Balancing values** (tuned in playtest) | Typed Resources in `res://data/` (`LevelConfig`, `EconomyConfig`, `CosmeticItem`) | Run length, targets 48 px apart, brain-block ratio, completion bonus, welcome bonus 100, item prices |
| **Player settings** | Save profile `settings`, via `PlayerData.set_setting()` | `music_on`, `sound_on` |
| **Platform settings** | `project.godot` + export presets; runtime checks **only** inside `WebPlatform` | Stretch mode, thread support, `OS.has_feature("web")` |

**Rules:**

- No gameplay number from the GDD appears as a literal in a script. It comes from a config Resource.
- There is no remote config.
- `OS.has_feature("web")` is called only in `WebPlatform`. Other code asks `WebPlatform`.

**Example:**

```gdscript
# data/levels/zombie_run.tres  (LevelConfig)
#   duration_s = 120, target_spacing_px = 48, visible_upcoming = 3,
#   amble_speed_px_s = 24, scoot_time_s = 0.15, brain_block_every = 4,
#   completion_bonus = 10, case_sensitive = false, target_mode = LETTER

# zombie_run_level.gd
@export var config: LevelConfig
func _scoot_to(target_x: float) -> void:
	create_tween().tween_property(_zombie, "position:x", target_x, config.scoot_time_s)
```

### Event System

**Pattern:** Godot typed signals (observer), synchronous, local ownership. No global EventBus (ADR-5).

**Event Naming:** `snake_case`, past tense for things that happened (`char_accepted`, `run_ended`, `brains_changed`, `equipment_changed`), and `_requested` for asks (`end_requested`, `pause_requested`). Parameters are always typed.

**Rules:**

- The node or service that owns the state declares and emits the signal. Listeners connect in code in `_ready()` using `signal.connect(callable)`, never string names.
- Parent calls child directly. Child tells parent through a signal. Siblings communicate through their parent.
- Cross-screen data goes through `Router` payloads. Persistent-state changes go through `PlayerData` signals.
- Connections made to autoload signals are disconnected in `_exit_tree()`, or made with `CONNECT_ONE_SHOT` where it applies.
- Handlers never `await` inside a typing callback (latency rule, D3).

**Example:**

```gdscript
# player_data.gd (autoload)
signal brains_changed(total: int, delta: int)
signal equipment_changed(slot: StringName, item_id: StringName)

func add_brains(amount: int) -> void:
	_profile.brains += amount
	brains_changed.emit(_profile.brains, amount)
	SaveService.request_save()

# brain_counter.gd (HUD widget)
func _ready() -> void:
	PlayerData.brains_changed.connect(_on_brains_changed)
	_label.text = str(PlayerData.get_brains())

func _exit_tree() -> void:
	PlayerData.brains_changed.disconnect(_on_brains_changed)

func _on_brains_changed(total: int, _delta: int) -> void:
	_label.text = str(total)
```

### Debug Tools

**Available Tools (debug builds only):**

- **Debug overlay** (`scenes/debug/debug_overlay.tscn`, a CanvasLayer on top) shows:
  - FPS and frame time, plus the worst frame in the last 10 s
  - Run state and clock
  - Current target and the next 3
  - Keys typed, errors and live WPM
  - The RNG seed for the current run
  - Save status: last write time, and whether storage is persistent
- **Cheat keys** (only while the overlay is open):
  - F5: +100 brains
  - F6: end the run now
  - F7: toggle verbose typing logs
  - F8: reset the save (asks for confirmation)
- **Fixed seed:** `RunFrame.debug_seed` (exported; `-1` means random) replays the same letter sequence.
- **Engine tools:**
  - The Godot editor debugger and profiler for desktop runs.
  - Browser developer tools (Performance tab) for the web frame-time check in Epic 5.
  - The Godot MCP server's `get_debug_output` for AI-driven runs.

**Activation:** F3 toggles the overlay. Everything is gated by `OS.is_debug_build()`. The overlay scene is instanced only in debug builds, so release web exports carry none of the cheat code paths.

## Project Structure

### Organization Pattern

**Pattern:** Hybrid — type folders at the top level (`scenes/`, `scripts/`, `data/`, `assets/`), feature folders inside each.

**Rationale:** Matches Godot's common conventions and the paths used throughout this document. Mirrored feature folders make placement predictable: a scene and its script share the same relative path under `scenes/` and `scripts/`.

### Directory Structure

```
zombies-teach-typing/
├── .github/workflows/build.yml      # CI: GUT → web export → GitHub Pages
├── addons/
│   └── gut/                         # GUT 9.7.1 (editor/test only; excluded from export)
├── assets/                          # Raw imported media only (no .tres/.gd)
│   ├── palette/
│   │   └── palette_32.png           # The 32-color master palette (art-style sheet)
│   ├── sprites/
│   │   ├── characters/
│   │   │   ├── zombie/              # Player zombie sheets
│   │   │   ├── villager/
│   │   │   ├── party_zombie/
│   │   │   └── professor/           # Cap/gown overlay + pointing pose
│   │   ├── props/                   # brain_block, brain_pop, arrow_marker
│   │   ├── cosmetics/
│   │   │   ├── hats/
│   │   │   └── pets/
│   │   ├── backdrops/
│   │   │   └── sunny_village_green/ # sky, far, near, ground tiles
│   │   └── ui/
│   │       ├── hud/
│   │       ├── hands/               # zombie hands + finger glow states + f/j bumps
│   │       ├── menu/                # logo, level cards, coming-soon sign
│   │       ├── closet/
│   │       └── report_card/
│   ├── audio/
│   │   ├── music/                   # mus_*.ogg
│   │   ├── sfx/                     # sfx_*.wav
│   │   └── voice/                   # vo_*.wav
│   └── fonts/                       # OFL pixel font + license file
├── data/                            # Authored .tres instances (+ generated JSON)
│   ├── cosmetics/
│   │   ├── catalogue.tres
│   │   ├── hat_pumpkin.tres
│   │   └── pet_cute_ghost.tres      # + 16 placeholder "coming soon" entries
│   ├── levels/
│   │   ├── level_registry.tres      # level_id → scene + card art + available flag
│   │   └── zombie_run.tres          # LevelConfig
│   ├── anchors/
│   │   ├── zombie_anchors.tres      # SpriteAnchors (head point per anim frame)
│   │   └── professor_anchors.tres
│   ├── audio/
│   │   └── audio_library.tres       # sound id → stream + volume
│   ├── economy.tres                 # EconomyConfig (welcome bonus, etc.)
│   ├── finger_map.tres              # FingerMap
│   ├── ui_theme.tres                # Shared Theme (pixel font, button styles)
│   └── content/                     # Post-MVP generated JSON: words.json, paragraphs.json
├── scenes/
│   ├── screens/
│   │   ├── title.tscn
│   │   ├── main_menu.tscn
│   │   ├── report_card.tscn
│   │   ├── welcome_gift.tscn
│   │   └── crypt_closet.tscn
│   ├── run/
│   │   ├── run_frame.tscn           # Hosts HUD, hands, clock, pause, the level instance
│   │   ├── hud.tscn
│   │   ├── zombie_hands.tscn
│   │   ├── pause_panel.tscn
│   │   └── countdown.tscn
│   ├── levels/
│   │   ├── zombie_run/
│   │   │   ├── zombie_run_level.tscn
│   │   │   ├── brain_block.tscn
│   │   │   ├── villager.tscn
│   │   │   └── conga_line.tscn
│   │   ├── horde_rush/              # Epic 6
│   │   └── pitchfork_panic/         # Epic 8
│   ├── characters/
│   │   ├── player_zombie.tscn       # AnimatedSprite2D + HatSlot
│   │   ├── party_zombie.tscn
│   │   └── professor_zombie.tscn
│   ├── cosmetics/
│   │   ├── hat_slot.tscn
│   │   └── pet_slot.tscn
│   ├── ui/                          # Reusable widgets
│   │   ├── brain_counter.tscn
│   │   ├── pixel_button.tscn
│   │   └── closet_item_tile.tscn
│   └── debug/
│       └── debug_overlay.tscn
├── scripts/
│   ├── autoloads/                   # Registered in project.godot, in this order
│   │   │                            # (an autoload may only use earlier ones in _ready()):
│   │   ├── web_platform.gd          #   1 WebPlatform
│   │   ├── save_service.gd          #   2 SaveService
│   │   ├── player_data.gd           #   3 PlayerData
│   │   ├── audio_manager.gd         #   4 AudioManager
│   │   └── router.gd                #   5 Router
│   ├── core/                        # Pure helpers, no scene dependencies
│   │   ├── log.gd                   # class_name Log
│   │   ├── game_constants.gd        # class_name GameConstants
│   │   └── save_schema.gd           # class_name SaveSchema (defaults, migrations)
│   ├── typing/                      # Pure logic — no nodes except TypingInput
│   │   ├── typing_input.gd          # class_name TypingInput (Node)
│   │   ├── typing_session.gd        # class_name TypingSession (RefCounted)
│   │   ├── target_source.gd         # class_name TargetSource (base)
│   │   ├── letter_bag_source.gd     # class_name LetterBagSource
│   │   ├── stats_calculator.gd      # class_name StatsCalculator (static)
│   │   └── run_result.gd            # class_name RunResult (RefCounted)
│   ├── run/
│   │   ├── run_frame.gd
│   │   ├── run_clock.gd             # class_name RunClock
│   │   ├── level_base.gd            # class_name LevelBase
│   │   ├── hud.gd
│   │   ├── zombie_hands.gd
│   │   ├── pause_panel.gd
│   │   └── countdown.gd
│   ├── levels/
│   │   └── zombie_run/
│   │       ├── zombie_run_level.gd
│   │       ├── brain_block.gd
│   │       ├── villager.gd
│   │       └── conga_line.gd
│   ├── screens/                     # title.gd, main_menu.gd, report_card.gd, welcome_gift.gd, crypt_closet.gd
│   ├── characters/                  # player_zombie.gd, party_zombie.gd, professor_zombie.gd
│   ├── cosmetics/                   # hat_slot.gd, pet_slot.gd
│   ├── resources/                   # Custom Resource class definitions (class_name)
│   │   ├── cosmetic_item.gd
│   │   ├── catalogue.gd
│   │   ├── level_config.gd
│   │   ├── level_registry.gd
│   │   ├── economy_config.gd
│   │   ├── finger_map.gd
│   │   ├── sprite_anchors.gd
│   │   └── audio_library.gd
│   ├── ui/                          # brain_counter.gd, pixel_button.gd, closet_item_tile.gd
│   └── debug/                       # debug_overlay.gd
├── tests/
│   ├── unit/                        # test_typing_input.gd, test_typing_session.gd, test_letter_bag_source.gd,
│   │                                # test_stats_calculator.gd, test_player_data.gd, test_save_schema.gd, ...
│   ├── integration/                 # test_run_frame.gd (scene-level flows)
│   └── fixtures/
│       └── saves/                   # save_v1_fresh.json, save_v1_full.json, save_corrupt.json
├── tools/                           # Offline scripts (post-MVP word tagging), not exported
├── docs/                            # Project knowledge (BMAD project_knowledge)
├── _bmad/  _bmad-output/            # Planning artifacts (not exported)
├── build/                           # Local export output (gitignored)
├── export_presets.cfg
├── project.godot
└── .gitignore
```

**Export exclusions** (both presets): `addons/gut/*`, `tests/*`, `tools/*`, `docs/*`, `_bmad/*`, `_bmad-output/*`, `build/*`.

### System Location Mapping

| System | Location | Responsibility |
| ------ | -------- | -------------- |
| Save file I/O, backup, migration | `scripts/autoloads/save_service.gd`, `scripts/core/save_schema.gd` | Only code that touches `user://` |
| Profile state, wallet, cosmetics, history | `scripts/autoloads/player_data.gd` | Single source of truth; emits change signals |
| Screen flow | `scripts/autoloads/router.gd` + `scenes/screens/` | Screen registry, fade, payloads |
| Audio | `scripts/autoloads/audio_manager.gd`, `data/audio/audio_library.tres` | Buses, pool, throttling, unlock |
| Browser integration | `scripts/autoloads/web_platform.gd` | Only code using `JavaScriptBridge` / `OS.has_feature("web")` |
| Typing input & judgment | `scripts/typing/` | Key filtering, judgment, stats, target sources |
| Run frame (HUD, hands, pause, clock) | `scenes/run/`, `scripts/run/` | Shared frame for every level; builds `RunResult` |
| Level contract | `scripts/run/level_base.gd` | The only interface levels implement |
| Zombie Run | `scenes/levels/zombie_run/`, `scripts/levels/zombie_run/`, `data/levels/zombie_run.tres` | Level-specific world, targets, reactions |
| Report card, menu, closet, welcome gift | `scenes/screens/`, `scripts/screens/` | Screens; read/write state only via `PlayerData` |
| Cosmetics display | `scenes/cosmetics/`, `scripts/cosmetics/`, `data/anchors/` | Hat anchoring, pet slot |
| Catalogue & prices | `data/cosmetics/`, `scripts/resources/cosmetic_item.gd` | Static item data |
| Finger map | `data/finger_map.tres`, `scripts/resources/finger_map.gd` | Char → finger/hand/Shift |
| Logging & constants | `scripts/core/` | `Log`, `GameConstants` |
| Debug tools | `scenes/debug/`, `scripts/debug/` | Debug-build-only overlay and cheats |
| Tests | `tests/` | GUT unit/integration tests + fixtures |
| CI/deploy | `.github/workflows/build.yml`, `export_presets.cfg` | Build, test, publish |

### Naming Conventions

#### Files

- All files and folders: `snake_case` (`zombie_run_level.gd`, `crypt_closet.tscn`, `hat_pumpkin.tres`).
- A scene and its root script share a base name and a mirrored path: `scenes/levels/zombie_run/villager.tscn` ↔ `scripts/levels/zombie_run/villager.gd`.
- Test files: `test_<unit_under_test>.gd` in `tests/unit/` or `tests/integration/`.

#### Code Elements

| Element | Convention | Example |
| ------- | ---------- | ------- |
| Classes (`class_name`) | PascalCase; used for Resources, pure logic, base classes and reusable nodes | `TypingSession`, `LevelBase`, `CosmeticItem` |
| Autoloads | PascalCase autoload name; the script has **no** `class_name` (it would clash) | `PlayerData` → `player_data.gd` |
| Functions / variables | `snake_case`, statically typed | `func add_brains(amount: int) -> void` |
| Private members | `_` prefix | `_profile`, `_on_brains_changed()` |
| Constants | `UPPER_SNAKE_CASE` | `RUN_HISTORY_CAP` |
| Enums | PascalCase type, UPPER_SNAKE values | `enum RunState { WAITING_FIRST_KEY, RUNNING }` |
| Signals | `snake_case` past tense; `_requested` for asks | `char_accepted`, `end_requested` |
| Signal handlers | `_on_<emitter>_<signal>` | `_on_session_char_accepted` |
| Node names in scenes | PascalCase; `%UniqueName` for nodes referenced from script | `%TargetLabel`, `HatSlot` |
| IDs (items, levels, sounds) | `StringName`, `snake_case`, category prefix for items | `&"hat_pumpkin"`, `&"pet_cute_ghost"`, `&"zombie_run"`, `&"sfx_brain_bonk"` |
| Indentation | Tabs (Godot default) | — |

#### Game Assets

- Sprite sheets: `<subject>_<animation>.png` (`zombie_walk.png`, `villager_poof.png`). Single images use `<subject>.png` (`brain_block.png`).
- Cosmetics: `hat_<name>.png`, `pet_<name>_idle.png`.
- UI: `ui_<element>[_<state>].png` (`ui_button_pressed.png`, `ui_finger_glow_l_index.png`).
- Audio: `mus_<context>.ogg`, `sfx_<event>.wav`, `vo_<line>_<nn>.wav` (`mus_zombie_run.ogg`, `sfx_wrong_key.wav`, `vo_brainsss_01.wav`).
- Animation names in `SpriteFrames`: lowercase verbs matching the GDD (`idle`, `walk`, `hop`, `hug`, `dance`, `poof`, `wave`).
- Data instances: `<type_prefix>_<name>.tres` for items; level configs use the level id (`zombie_run.tres`).

### Architectural Boundaries

1. **`scripts/typing/` and `scripts/core/` are pure.** Apart from `TypingInput`, they don't use autoloads, scenes or the scene tree. That keeps them fully unit-testable.
2. **Levels depend only on:**
   - `LevelBase`
   - their own scenes
   - their `LevelConfig`
   - `AudioManager`, to play sounds
   - `HatSlot` and `PetSlot`, for cosmetic display

   Levels never import another level, never read input, and never write to `PlayerData`.
3. **Only `SaveService` touches files.** Only `WebPlatform` touches browser APIs. Only `AudioManager` creates audio players.
4. **Screens change state only through `PlayerData` methods, and navigate only through `Router`.**
5. **`data/` holds instances. `scripts/resources/` holds the definitions.** A `.tres` file only references classes from `scripts/resources/`.
6. **`assets/` holds only imported media.** No scripts or `.tres` files go there.
7. **Debug code lives only in `scenes/debug/` and `scripts/debug/`,** and is instanced only when `OS.is_debug_build()` is true.

## Implementation Patterns

These patterns ensure consistent implementation across all AI agents.

### Novel Patterns

#### Logic Leads, Visuals Chase

**Purpose:** A correct key must change game state and start visible feedback on the same frame, and animation length must never limit typing speed (GDD M1: overlapping or skipped animations allowed at 5+ keys/s).

**Components:**

- **Logical state** (plain variables in the level script): index of the active target, the zombie's logical position (target slot or step count), conga count, brains. Updated **synchronously** in `on_char_accepted`.
- **View** (nodes): sprites and tweens that move toward the logical state. They never hold authoritative state.
- **Retargeting tween**: one tween per moving actor. Every new logical position kills the running tween and starts a new one from the *current visual position* to the *new logical position*.

**Data Flow:**

```
key → TypingSession.char_accepted (same frame)
    → level.on_char_accepted()
        1. update logical state            (instant, authoritative)
        2. resolve the target visually     (spawn one-shot effect: hop/hug/poof; fire-and-forget)
        3. retarget the actor's move tween (kill + restart toward the new logical position)
    → HUD updates from TypingSession signals (same frame)
```

**Rules:**

- Never `await` in a typing callback. Never gate input on `animation_finished` or `tween.finished`.
- One-shot effects (brain pop, poof, "+1") are self-freeing child scenes. They can overlap freely.
- If a character-state animation (hop, hug) is still playing when the next key arrives, restart it on the new target. The animation is cut short, and the logic is never delayed.
- Anything that reads position for gameplay (the Pitchfork Panic gap, Horde Rush arrivals) uses **logical** values, never sprite positions.

**Implementation Guide:**

```gdscript
# zombie_run_level.gd
var _active_index: int = 0                 # logical — authoritative
var _move_tween: Tween

func on_char_accepted(_expected: String, _index: int) -> void:
	var target: ZombieRunTarget = _targets[_active_index]
	_active_index += 1                      # 1. logic first
	_brains += target.resolve()             # 2. one-shot visual; returns brains (0 or 1)
	_scoot_to(_approach_x(_active_index))   # 3. visuals chase

func _scoot_to(x: float) -> void:
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = create_tween()
	_move_tween.tween_property(_zombie, "position:x", x, config.scoot_time_s)

func _process(delta: float) -> void:
	# Amble only while no scoot is running and the zombie is short of its approach point
	if (_move_tween == null or not _move_tween.is_running()) and _zombie.position.x < _approach_x(_active_index):
		_zombie.position.x = minf(_zombie.position.x + config.amble_speed_px_s * delta, _approach_x(_active_index))
```

**Usage:** every level reaction to typing: the Zombie Run scoot, the Horde Rush spawn and march, Pitchfork Panic steps and the mob gap.

#### Finger Guide Resolution

**Purpose:** show which finger or fingers to use for the next character, including capitals and shifted symbols (GDD Finger Guide).

**Components:**

- `FingerMap` (Resource): `char → { hand: Hand, finger: Finger, shift: bool }` for lowercase letters, digits, punctuation, Space. The GDD finger table is authored once here. Capitals and shifted symbols (`!`, `?`, `"`) have `shift = true`, with a base finger.
- `ZombieHands` (scene): shows 10 finger glow states plus the permanent f/j bumps. Listens to `TypingSession.target_changed`.
- The Shift rule: if `shift` is true, also light the **opposite** hand's pinky.

**Data Flow:** `target_changed(next)` → `next_char = next[cursor]` → `FingerMap.lookup(next_char)` → `ZombieHands.show(fingers: Array[FingerId])`.

**Implementation Guide:**

```gdscript
# finger_map.gd
class_name FingerMap extends Resource
enum Hand { LEFT, RIGHT }
enum Finger { PINKY, RING, MIDDLE, INDEX, THUMB }
@export var entries: Dictionary = {}   # String(char) → Vector3i(hand, finger, shift 0/1)

func fingers_for(c: String) -> Array[Vector2i]:   # Vector2i(hand, finger)
	var e: Vector3i = entries.get(c, Vector3i(-1, -1, 0))
	if e.x < 0:
		Log.warn(&"hands", "no finger mapping for '%s'" % c)
		return []
	var result: Array[Vector2i] = [Vector2i(e.x, e.y)]
	if e.z == 1:
		var other := Hand.RIGHT if e.x == Hand.LEFT else Hand.LEFT
		result.append(Vector2i(other, Finger.PINKY))
	return result
```

**Usage:** `ZombieHands` only. Unit-tested for all 26 letters, a capital (`A` → left pinky + right pinky), a right-hand capital (`J` → right index + left pinky) and Space (both thumbs).

### Communication Patterns

**Pattern:** "Call down, signal up", plus autoload services.

- A parent calls methods on its children directly (it owns them).
- Children report to their parent with signals. Siblings never reference each other.
- Anyone may call autoload service methods (`PlayerData.add_brains()`, `AudioManager.play_sfx()`, `Router.go()`), but only within the boundaries in Project Structure.
- Dependencies that aren't autoloads are **injected** by the owner through a `setup()` method or `@export`. Nothing uses `get_node("/root/...")` or reaches up with `get_parent()`.

**Example:**

```gdscript
# run_frame.gd  (parent)
func _start_level(level_scene: PackedScene) -> void:
	_level = level_scene.instantiate() as LevelBase
	%LevelHost.add_child(_level)
	_session = TypingSession.new(_level.create_target_source(_rng), _level.get_level_config())
	_session.char_accepted.connect(_level.on_char_accepted)     # call down (via connection)
	_session.char_accepted.connect(%Hud.on_char_accepted)
	_level.end_requested.connect(_on_level_end_requested)       # signal up
	%TypingInput.char_typed.connect(_on_typing_input_char_typed)

func _on_typing_input_char_typed(c: String) -> void:
	if _state == RunState.RUNNING or _state == RunState.WAITING_FIRST_KEY:
		_session.judge(c)
```

### Entity Patterns

**Creation:** scene instancing from `preload`ed `PackedScene`s, owned by the spawning script. No global factory. Object pooling is **not** used by default. It's added only if the profiler shows spawn cost in a frame over 16 ms (the candidate is Horde Rush with 30 zombies on screen).

- Spawners `preload` their scenes as constants and call a `setup(...)` method on the instance **before** `add_child`.
- Off-screen entities are freed with `queue_free()`. Zombie Run keeps at most the active target plus the next 3, and frees resolved targets once they scroll off screen.
- Capped visuals: the conga line draws at most 12 followers and shows a "×N" badge for the rest. No hidden nodes are created beyond the cap.

**Example:**

```gdscript
# zombie_run_level.gd
const VILLAGER_SCENE: PackedScene = preload("res://scenes/levels/zombie_run/villager.tscn")
const BRAIN_BLOCK_SCENE: PackedScene = preload("res://scenes/levels/zombie_run/brain_block.tscn")

func _spawn_target(letter: String, kind: TargetKind, slot: int) -> ZombieRunTarget:
	var scene := BRAIN_BLOCK_SCENE if kind == TargetKind.BRAIN_BLOCK else VILLAGER_SCENE
	var t := scene.instantiate() as ZombieRunTarget
	t.setup(letter, slot, config)
	%Targets.add_child(t)
	return t
```

### State Patterns

**Pattern:** an enum state machine inside the owning script (`match` + one `_set_state()` function). Node-based state machines are not used; the state sets here are small and flat.

- Every transition goes through `_set_state(new)`, which runs exit and enter logic and logs at DEBUG level.
- Input handlers check the state first. For example, `RunFrame` rejects typing in `PAUSED`, `COUNTDOWN`, `ENDING` and `DONE`.
- Entities with visual states (a villager: `WAITING → HUGGED → POOFED`) use the same pattern and never go backwards.

**Example:**

```gdscript
# run_frame.gd
enum RunState { WAITING_FIRST_KEY, RUNNING, PAUSED, COUNTDOWN, ENDING, DONE }
var _state: RunState = RunState.WAITING_FIRST_KEY

func _set_state(new_state: RunState) -> void:
	if new_state == _state:
		return
	Log.debug(&"run", "state %s → %s" % [RunState.keys()[_state], RunState.keys()[new_state]])
	_state = new_state
	match _state:                             # enter
		RunState.RUNNING:
			get_tree().paused = false         # only place the tree is unpaused
			_clock.resume()
		RunState.PAUSED:
			_clock.pause()
			get_tree().paused = true
			%PausePanel.open()
		RunState.COUNTDOWN:
			%Countdown.start(3, 0.5)          # tree still paused; emits finished → _set_state(RUNNING)
		RunState.ENDING:
			_clock.pause()
			_begin_outro()
```

### Data Patterns

**Access:**

- **Runtime state** is read through `PlayerData` getters and changed through its methods. The save dictionary is never passed around or edited outside `PlayerData` and `SaveService`.
- **Static data** comes from Resources. They're injected with `@export` on the scene that needs them, or looked up through a registry Resource (`Catalogue`, `LevelRegistry`, `AudioLibrary`). No script contains a hard-coded `res://` path to a data file, except the `preload` constants in autoloads and registries.
- **IDs, not references,** are stored in save data: `&"hat_pumpkin"`, never a Resource path.

**Example:**

```gdscript
# crypt_closet.gd
@export var catalogue: Catalogue          # data/cosmetics/catalogue.tres assigned in the scene

func _on_item_tile_buy_requested(item_id: StringName) -> void:
	var item := catalogue.get_item(item_id)
	if item == null:
		return
	match PlayerData.buy_item(item):      # returns PurchaseResult enum
		PlayerData.PurchaseResult.OK:
			AudioManager.play_sfx(&"sfx_purchase")
			_refresh_tiles()
		PlayerData.PurchaseResult.NOT_ENOUGH_BRAINS:
			_show_need_more(item.price - PlayerData.get_brains())
		PlayerData.PurchaseResult.ALREADY_OWNED, PlayerData.PurchaseResult.UNAVAILABLE:
			Log.warn(&"economy", "unexpected buy of %s" % item_id)
```

### Consistency Rules

| Pattern | Convention | Enforcement |
| ------- | ---------- | ----------- |
| Static typing | Every var, parameter and return type is typed; `:=` only when the type is obvious | Project setting: `debug/gdscript/warnings/untyped_declaration = Error` |
| Typing callbacks | Synchronous; no `await`; logic before visuals | Code review; latency check in the debug overlay |
| Game numbers | From `LevelConfig` / `EconomyConfig` / `CosmeticItem`, never literals | Code review; GUT tests read the same resources |
| State changes | Through `_set_state()` only | Code review |
| Save writes | Only via `PlayerData` methods → `SaveService.request_save()` | Boundary rule; `grep FileAccess` finds only `save_service.gd` |
| Browser APIs | Only in `WebPlatform` | `grep JavaScriptBridge` / `has_feature("web")` finds only `web_platform.gd` |
| Node references | `%UniqueName` or `@onready` child paths; no `/root/` paths, no `get_parent()` chains | Code review |
| Signals | Typed, past tense, connected in code with Callables | Code review |
| Randomness | Injected `RandomNumberGenerator`; never global `randi()` / `randf()` in gameplay | `grep` for global random functions in `scripts/levels` and `scripts/typing` |
| New level | Extends `LevelBase`, lives in `scenes/levels/<id>/` + `scripts/levels/<id>/`, registered in `level_registry.tres` | Checklist in the level's first story |
| Tests | Every class in `scripts/typing/`, `scripts/core/` and `player_data.gd` has a `tests/unit/test_*.gd` | CI fails on any GUT failure |
| Kid-facing text | Plain words a 6-year-old can read; no technical error text | Readability check in Epic 5 |

## Architecture Validation

### Validation Summary

| Check | Result | Notes |
| ----- | ------ | ----- |
| Decision Compatibility | Pass | After fixes: autoload order and pause/countdown behavior corrected |
| GDD Coverage | Pass | After fixes: Caps Lock hint, space and case rules for each level, and in-run brains now covered |
| Pattern Completeness | Pass | Entity creation, communication, state, error handling, data access and events all defined with examples |
| Epic Mapping | Pass | Epics 1–11 all map to locations and patterns; post-MVP levels plug into `LevelBase` and `TargetSource` |
| Document Completeness | Pass | No placeholders; versions verified (Godot 4.7.2, GUT 9.7.1); CI action versions pinned in Epic 1 |

### Coverage Report

**Systems Covered:** 16/16 (Core Systems table in Project Context)
**Patterns Defined:** 2 novel + 4 standard, plus 12 consistency rules
**Decisions Made:** 10 (D1–D10) + 5 ADRs

### Issues Resolved

1. Autoload order changed to `WebPlatform → SaveService → PlayerData → AudioManager → Router`; an autoload may only use earlier autoloads in `_ready()`.
2. The tree stays paused through `COUNTDOWN` and is unpaused only on entering `RUNNING`; focus loss during countdown returns to `PAUSED`.
3. Added the `caps_lock_suspected` / `caps_lock_cleared` signals on `TypingInput` for the GDD's "Caps Lock is on" hint.
4. `TypingInput` is configured from `LevelConfig` (`case_sensitive`, `space_is_input`).
5. Recorded that in-run brains reach `PlayerData` only at run end or quit (intended; matches GDD save points).
6. The Epic 7 word-tagging tool is a headless GDScript tool (`tools/tag_words.gd`).
7. GitHub Actions versions are to be pinned and verified in Epic 1 story 1.
8. MCP decision recorded: the connected Godot MCP is used; Context7 and GoPeak are optional.
9. `SaveService.request_save()` combines same-frame requests into one write.

### Validation Date

2026-09-27

## Development Environment

### Prerequisites

- **Godot 4.7.2** (standard build, not .NET) with **Web** and **Windows Desktop** export templates for 4.7.2 installed (Editor → Manage Export Templates)
- **Git** and a **public GitHub repository** with GitHub Pages set to deploy from GitHub Actions
- **GUT 9.7.1** (installed into `addons/gut/` from the Asset Library or GitHub release)
- Desktop Chrome, Edge and Firefox for web testing
- Optional: Node.js 18+ (only if adding Context7 or GoPeak MCP servers)

### AI Tooling (MCP Servers)

| MCP Server | Purpose | Install Type |
| ---------- | ------- | ------------ |
| Godot MCP (already connected) | Launch editor, run project, read debug output, create scenes/nodes, manage UIDs | Already configured in this Claude Code environment |
| Context7 (`upstash/context7`) — optional | Current Godot 4.7 API documentation lookup | `npx` MCP server |
| GoPeak (`HaD0Yun/Gopeak-godot-mcp`) — optional | Runtime screenshots, input injection, LSP/DAP debugging | `npx` MCP server |

**Setup (optional servers):**

```bash
claude mcp add context7 -- npx -y @upstash/context7-mcp
```

GoPeak: follow the repository README (Node 18+, point it at the Godot 4.7.2 executable). Verify that the repository is still maintained before installing.

### Setup Commands

```bash
# 1. Push the repo to GitHub (public) and set Pages → Source: GitHub Actions
git remote add origin https://github.com/<you>/zombies-teach-typing.git
git push -u origin main

# 2. Run the unit tests headlessly (after GUT is installed)
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit

# 3. Local web export (after the Web preset exists)
godot --headless --path . --export-release "Web" build/web/index.html
```

### First Steps

1. **Fix project settings (Epic 1):** 640×360 viewport, `viewport` stretch + `keep` aspect + `integer` scale, Nearest texture filter, pixel snap; remove `[dotnet]`; set `untyped_declaration` warnings to Error.
2. **Create export presets:** Web (Thread Support off, no PWA) and Windows Desktop, with the export exclusions from Project Structure.
3. **Install GUT 9.7.1** and add one passing smoke test.
4. **Add `.github/workflows/build.yml`** (Godot 4.7.2 headless → GUT → web export → Pages), pinning the current action versions.
5. **Create the folder skeleton and the 5 autoloads** in the specified order, with `Log` and `GameConstants`.
6. **Publish the hello-world build** and record the first-load time and compressed size against the 10 s budget.
7. Optional: configure Context7 and GoPeak per AI Tooling above.
