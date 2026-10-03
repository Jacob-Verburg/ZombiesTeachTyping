
## Deferred from: code review of story-1-1 (2026-10-02)

- `test_debug_disabled_in_release` does not verify that nothing printed; only the `is_level_enabled` seam is tested.
- `Log.verbose_typing` is declared but not consumed; wire it up when per-keystroke logging arrives (Epic 2).
- `directory_rules={"res://addons": 0}` not persisted in `project.godot`; relies on the Godot 4.7 default.
- `Log.debug` evaluates its `msg` argument even when DEBUG is disabled; keep calls out of hot paths.
- GUT plugin is enabled in `project.godot`; confirm the web export (Story 1.2) excludes `addons/gut`.

## Deferred from: dev of story-1-2 (2026-10-02)

- Web letterbox bars render **black**, not night `#2B1D3F` (DESIGN.md marks night bars as `[ASSUMPTION]`). Not required by Story 1.2 AC 5. Natural home: Story 5.0 (loading page / boot splash styling); options are the HTML page background in `html/head_include` plus the engine's black-bar color.
