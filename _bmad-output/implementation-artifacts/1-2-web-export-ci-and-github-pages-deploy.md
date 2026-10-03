---
baseline_commit: 9450abe280724d2c1b2a005d0a50f029069f8219
---

# Story 1.2: Web Export, CI and GitHub Pages Deploy

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As the developer,
I want every push to `main` to run the tests and export the web build, and every version tag to publish it to GitHub Pages,
so that broken tests never ship and kids only ever see finished releases.

## Acceptance Criteria

1. **Export presets.** Given `export_presets.cfg`, when the presets are inspected, then a `Web` preset exists with Thread Support off and no PWA, and a `Windows Desktop` preset exists; and both exclude `addons/gut/*`, `tests/*`, `tools/*`, `docs/*`, `_bmad/*`, `_bmad-output/*` and `build/*`.
2. **CI workflow.** Given `.github/workflows/build.yml`, when a commit is pushed to `main` or a pull request is opened, then the workflow downloads Godot 4.7.2 headless and its export templates, imports the project, runs GUT, exports the Web preset and uploads it as a workflow artifact, without deploying; and when a tag matching `v*` is pushed, the same steps run and the build is deployed to GitHub Pages; and the hello-world is published by tagging `v0.0.1`; and the current major versions of `actions/checkout`, `actions/upload-pages-artifact` and `actions/deploy-pages` are pinned and noted in the story file.
3. **Failing tests block.** Given a failing GUT test, when the workflow runs, then the job fails before the export and nothing is deployed.
4. **Plain static hosting and load budget.** Given the deployed hello-world page, when it is opened in desktop Chrome, Edge and Firefox from the Pages URL, then it runs without any special server headers (NFR5); and the compressed transfer size and the first-load and cached-load times at 25 Mbit/s (throttled dev tools) are recorded in the story file against the ≤ 10 s / ≤ 3 s / ≤ 40 MB targets (NFR3); if over 10 s, a "custom export template without 3D" item is added to the backlog.
5. **Scaling on the target laptop.** Given the deployed page in a maximised Chrome, Edge and Firefox window on a 1366×768 screen (or a dev-tools emulation of it), when the title screen is shown, then the game fills the available height with fractional scaling and nearest filtering, with no blurry pixels, and a screenshot per browser is kept in the story file.

## ⚠ Prerequisites (Smuck must do these; the dev agent must not)

These are outward-facing GitHub actions. The dev agent stops and asks Smuck before each one; it never changes repository settings itself.

- [x] **P1. Commit and push Story 1.1.** Its work (settings, GUT, `Log`, tests) is still uncommitted on `main`. CI can't run GUT without `addons/gut/` in the repo.
- [x] **P2. Make the repo public** (`Jacob-Verburg/ZombiesTeachTyping`, Settings → General → Danger Zone). It is **private** today (the public API returns 404). GitHub Pages on a private repo needs a paid plan, and ADR-4 chose a public repo. Everything in the repo becomes public, including `_bmad/` and `_bmad-output/` planning docs. No secrets are in the repo today; confirm before flipping.
- [x] **P3. Pages source = GitHub Actions** (Settings → Pages → Build and deployment → Source: *GitHub Actions*).
- [x] **P4. Allow tags to deploy.** Settings → Environments → `github-pages` → Deployment branches and tags → **Add deployment branch or tag rule** → type *Tag*, pattern `v*`. By default only the default branch may deploy, and a tag deploy fails with "Tag "v0.0.1" is not allowed to deploy to github-pages due to environment protection rules". The environment appears after P3 (or after the first deploy attempt).
- [x] **P5. Push the `v0.0.1` tag** (after the `main` run is green): `git tag v0.0.1 && git push origin v0.0.1`. This publishes the public link.
- [x] **P6. Manual browser checks** for Edge and Firefox (AC 4, 5). The agent can do the Chromium checks in its built-in browser. Smuck provides the Edge and Firefox numbers and screenshots.

## Tasks / Subtasks

- [x] **Task 1: Placeholder main scene** (AC: 4, 5; needed so the export has something to run)
  - [x] 1.1 Create `scenes/screens/title.tscn`: root `Control` named `Title` (full rect), a `ColorRect` background in night `#2B1D3F` (full rect), a `Label` reading "Zombies Teach Typing" and a second `Label` "hello world v0.0.1", plus a **pixel-sharpness probe**: 4 vertical `ColorRect`s 1 px wide, 1 px apart, 16 px tall, in `#F07A1C` (pumpkin). No script. Story 1.3 rebuilds this scene as the real title screen.
  - [x] 1.2 Set it as the main scene: `application/run/main_scene="res://scenes/screens/title.tscn"` (use the uid form if the editor writes one).
  - [x] 1.3 Remove `.gitkeep` from `scenes/screens/` now that the folder has a real file.
- [x] **Task 2: Export presets** (AC: 1)
  - [x] 2.1 Install the **standard 4.7.2 export templates** locally (Editor → Manage Export Templates → Download and Install, or install `Godot_v4.7.2-stable_export_templates.tpz` from file). They go to `%APPDATA%\Godot\export_templates\4.7.2.stable\`, which is empty today.
  - [x] 2.2 In the editor (Project → Export), add a **Web** preset named exactly `Web`: Thread Support **off**, Extensions Support off, PWA **off**, VRAM compression for desktop **on** and for mobile **off**, canvas resize policy Adaptive, focus canvas on start on, `html/head_include` empty (Story 5.0 owns it). Export path `build/web/index.html`.
  - [x] 2.3 Add a **Windows Desktop** preset named exactly `Windows Desktop`, x86_64, export path `build/windows/ZombiesTeachTyping.exe`. Set `application/modify_resources=false` so rcedit is not required.
  - [x] 2.4 On **both** presets: export mode *Export all resources*, and **Filters to exclude** = `addons/gut/*, tests/*, tools/*, docs/*, _bmad/*, _bmad-output/*, build/*`.
  - [x] 2.5 Commit `export_presets.cfg`. It holds no secrets, since credentials go to `.godot/export_credentials.cfg`, which is gitignored with `.godot/`. Check the file contains no `encryption`/`script_encryption_key` values.
  - [x] 2.6 Add `tests/unit/test_export_presets.gd` (Testing Requirements): loads `res://export_presets.cfg` with `ConfigFile` and asserts the AC 1 values for both presets.
- [x] **Task 3: Local export proof** (AC: 1, 4)
  - [x] 3.1 `mkdir -p build/web` then `"/c/Program Files/Godot/Godot.exe" --headless --path . --export-release "Web" build/web/index.html`. Godot fails if the output folder doesn't exist. Record the exit code and the file list and sizes in `build/web/`.
  - [x] 3.2 Confirm GUT is not shipped: `strings build/web/index.pck | grep -c "addons/gut"`. Hits that are only `res://addons/gut/...` paths inside the global class cache (`global_script_class_cache.cfg`) are acceptable. GUT script source or `.tscn` data in the pck is not. Record the result. This closes the deferred item from Story 1.1.
  - [x] 3.3 Serve locally to smoke-test with a plain static server, so no special headers are involved: `python -m http.server 8060 -d build/web`. Open `http://localhost:8060/` and confirm the placeholder scene renders. Single-threaded builds need no COOP/COEP headers.
- [x] **Task 4: CI workflow** (AC: 2, 3)
  - [x] 4.1 Create `.github/workflows/build.yml` per the skeleton in Dev Notes. Triggers: `push` to `main`, `push` of tags `v*`, `pull_request`. Jobs: `build` (always) → `deploy` (tags only).
  - [x] 4.2 Pin `actions/checkout@v7`, `actions/cache@v6`, `actions/upload-artifact@v7`, `actions/upload-pages-artifact@v5`, `actions/deploy-pages@v5`. These were the latest majors on 2026-10-02 (checked with `git ls-remote --tags`). Re-check them at implementation time and record the final versions in the Dev Agent Record (AC 2).
  - [x] 4.3 Download and cache Godot: the editor `Godot_v4.7.2-stable_linux.x86_64.zip` (78 MB) and **only the web templates** from `Godot_v4.7.2-stable_export_templates.tpz` (1.28 GB). Unzip just `templates/web_nothreads_release.zip`, `templates/web_nothreads_debug.zip` and `templates/version.txt` into `~/.local/share/godot/export_templates/4.7.2.stable/`. Cache that folder plus the editor binary with key `godot-4.7.2-stable-web-v1`, so the 1.28 GB download only happens on a cache miss.
  - [x] 4.4 Import: `godot --headless --path . --import`. `.godot/` is not in the repo, so class names such as `GutTest`, `Log` and `GameConstants` don't exist until this runs.
  - [x] 4.5 Test: run GUT with `tee` to a log. **Fail the step** if GUT exits non-zero **or** the log contains `Parse Error`, `Failed to load script` or `SCRIPT ERROR`. Story 1.1 found that GUT skips a test file that fails to parse and still exits 0. Use `set -o pipefail`.
  - [x] 4.6 Export: `mkdir -p build/web` then `godot --headless --path . --export-release "Web" build/web/index.html`. Fail if `build/web/index.html`, `index.wasm` or `index.pck` is missing (Godot can exit 0 on some export errors).
  - [x] 4.7 Upload: `actions/upload-artifact@v7` (`name: web-build`, `path: build/web`) on every run; `actions/upload-pages-artifact@v5` (`path: build/web`) only when `startsWith(github.ref, 'refs/tags/v')`.
  - [x] 4.8 `deploy` job: `needs: build`, `if: startsWith(github.ref, 'refs/tags/v')`, `environment: { name: github-pages, url: ${{ steps.deployment.outputs.page_url }} }`, permissions `pages: write`, `id-token: write`, and `actions/deploy-pages@v5`. The `build` job only gets `contents: read`. Add `concurrency: { group: pages, cancel-in-progress: false }` to the deploy job.
- [x] **Task 5: Prove the gates** (AC: 2, 3). Pushes need Smuck's go-ahead, see Prerequisites.
  - [x] 5.1 After P1–P4: push `main` → the run is green, the `web-build` artifact exists, and the `deploy` job is **skipped**. Record the run URL.
  - [x] 5.2 Failing-test proof: on a throwaway branch with an open PR (or a push to a branch with a temporary trigger), add `tests/unit/test_ci_must_fail.gd` with `assert_true(false)`. The run fails at the test step, the export step doesn't run, and nothing deploys. Record the run URL, then delete the branch.
  - [x] 5.3 Parse-error proof: same approach with a test file containing `var x = 1` (an untyped-declaration error). The run must fail at the test step. Record the run URL, then delete the branch.
  - [x] 5.4 P5: tag `v0.0.1` → the `deploy` job succeeds. Record the Pages URL (expected `https://jacob-verburg.github.io/ZombiesTeachTyping/`).
- [x] **Task 6: Measure and check in browsers** (AC: 4, 5)
  - [x] 6.1 Partly done: Chrome and Edge run with no SharedArrayBuffer or isolation errors; Firefox **SKIPPED by Smuck's decision (2026-10-02)** — not installed. Open the Pages URL in Chrome, Edge and Firefox. It runs with no console errors about SharedArrayBuffer or cross-origin isolation.
  - [x] 6.2 Cached loads measured (Chrome ~1.2 s, Edge ~1.3 s); throttled first loads **SKIPPED by Smuck's decision (2026-10-02)** — estimated instead (10.35 MB at 25 Mbit/s ≈ 3.3 s transfer). Dev tools → Network → custom throttling profile **25 Mbit/s down** (25000 kbit/s), "Disable cache" on, then hard reload. Record transferred bytes (the compressed total), and the time to the first frame of the placeholder scene (the `load` event or a visual check). Then turn off "Disable cache" and reload to record the cached-load time. Fill in the results table in the Dev Agent Record.
  - [x] 6.3 Check `Content-Encoding` on `index.wasm` and `index.pck` in the Network panel. Record whether Pages served gzip.
  - [x] 6.4 Not triggered: the estimated first load (~3.3 s transfer + startup) is well under 10 s, so no backlog item. Not measured with throttling (Smuck's decision). If first load is over 10 s: add "Custom export template without 3D" to `_bmad-output/implementation-artifacts/deferred-work.md` and tell Smuck.
  - [x] 6.5 Partly done: Edge 1366×768 fills the viewport (screenshot saved); the 100% zoom sharpness check, the Chrome 1366×768 shot and Firefox are **SKIPPED by Smuck's decision (2026-10-02)** — the bars are black (deferred to 5.0). At 1366×768 (a real screen or dev-tools device emulation at 1366×768 with the browser's own UI accounted for, giving a viewport of about 1366×650): the scene fills the height with night-colored bars left and right only, and the 1 px probe lines are sharp with no blur. Save one screenshot per browser to `_bmad-output/implementation-artifacts/screenshots/1-2/` (`chrome.png`, `edge.png`, `firefox.png`) and link them in the story.
- [x] **Task 7: Regression**
  - [x] 7.1 Local GUT run: all tests pass (17+ with the new export-preset tests), exit 0.
  - [x] 7.2 `git status`: `build/` is not tracked; new `.uid` files are committed.

## Dev Notes

### Scope boundaries (what this story is NOT)

- **No real title screen, router, font or theme.** That's Story 1.3. The placeholder `title.tscn` has no script and no input handling.
- **No custom loading page or boot splash** (`html/head_include`, `application/boot_splash/*`). That's Story 5.0. Leave Godot's default boot splash.
- **No Windows export in CI.** The Windows preset just needs to exist (AC 1). Optionally check that it exports locally.
- **No custom no-3D template.** Only add a backlog item if the 10 s budget is missed.

### Previous story intelligence (Story 1.1, done)

- Use the **standard** Godot exe `C:\Program Files\Godot\Godot.exe` (4.7.2.stable.official), called directly. The `_console.exe` wrapper next to it is broken because the exe was renamed. Never open the project with `Godot_C#.exe` or the mono build, which can re-add `[dotnet]`.
- **A GUT parse error does not fail the run** (exit 0). CI must grep the log (Task 4.5).
- GUT 9.7.1 is vendored in `addons/gut/`; `.gutconfig.json` sets `include_subdirs: true`. Command: `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`.
- Strict typing is on (`untyped_declaration = 2`): type every `var`, parameter and return, including in tests. `ConfigFile.get_value()` returns `Variant`, so assign it to a typed variable (`var v: bool = cfg.get_value(...)`) or compare it directly.
- Godot 4.7 writes `.uid` files next to every script, and `uid://` references into `.tscn` files. Commit them.
- `project.godot` now has `window/size/window_width_override=1280` / `window_height_override=720` (review patch for a usable desktop window). This **doesn't affect the web build**, where the canvas follows the browser window. Keep it.
- `tests/unit/test_project_settings.gd` guards the settings. Setting `run/main_scene` doesn't break it.
- Deferred from 1.1 and closed here: "confirm the web export excludes `addons/gut`" (Task 3.2).

### Current state of files being modified

- **`project.godot`:** sections `[application]` (name, features `4.7`/`GL Compatibility`, icon), `[debug]` (`untyped_declaration=2`), `[display]` (640×360, overrides 1280×720, viewport/keep/fractional), `[editor_plugins]` (GUT), `[physics]`, `[rendering]` (Nearest filter, snap, gl_compatibility). There's no `run/main_scene` yet; add it under `[application]`. Preserve everything else.
- **`.gitignore`:** `.godot/`, `/android/`, `.claude/settings.local.json`, `build/`. No change needed. Keep `export_presets.cfg` tracked; it is not ignored.
- **`_bmad-output/implementation-artifacts/deferred-work.md`:** append only (Task 6.4, if needed).

### CI workflow skeleton (`.github/workflows/build.yml`)

Adapt as needed, but keep the gates:

```yaml
name: build
on:
  push:
    branches: [main]
    tags: ['v*']
  pull_request:

env:
  GODOT_VERSION: 4.7.2
  GODOT_BIN: ${{ github.workspace }}/.godot-bin/Godot_v4.7.2-stable_linux.x86_64
  TEMPLATES_DIR: ~/.local/share/godot/export_templates/4.7.2.stable

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@v7

      - name: Cache Godot + web templates
        id: godot-cache
        uses: actions/cache@v6
        with:
          path: |
            .godot-bin
            ~/.local/share/godot/export_templates/4.7.2.stable
          key: godot-4.7.2-stable-web-v1

      - name: Download Godot + web templates
        if: steps.godot-cache.outputs.cache-hit != 'true'
        run: |
          set -euo pipefail
          base=https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable
          mkdir -p .godot-bin ~/.local/share/godot/export_templates/4.7.2.stable
          curl -fsSL -o godot.zip "$base/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"
          unzip -q godot.zip -d .godot-bin && rm godot.zip
          curl -fsSL -o templates.tpz "$base/Godot_v${GODOT_VERSION}-stable_export_templates.tpz"
          unzip -q -j templates.tpz templates/web_nothreads_release.zip templates/web_nothreads_debug.zip templates/version.txt \
            -d ~/.local/share/godot/export_templates/4.7.2.stable
          rm templates.tpz
          chmod +x "$GODOT_BIN"

      - name: Import project
        run: '"$GODOT_BIN" --headless --path . --import'

      - name: Run GUT
        run: |
          set -o pipefail
          "$GODOT_BIN" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit 2>&1 | tee gut.log
          if grep -E "Parse Error|Failed to load script|SCRIPT ERROR" gut.log; then
            echo "::error::A test script failed to load (GUT skips it and still exits 0)"; exit 1
          fi

      - name: Export Web
        run: |
          set -euo pipefail
          mkdir -p build/web
          "$GODOT_BIN" --headless --path . --export-release "Web" build/web/index.html
          for f in index.html index.wasm index.pck index.js; do test -f "build/web/$f" || { echo "::error::missing $f"; exit 1; }; done
          ls -la build/web

      - uses: actions/upload-artifact@v7
        with:
          name: web-build
          path: build/web

      - if: startsWith(github.ref, 'refs/tags/v')
        uses: actions/upload-pages-artifact@v5
        with:
          path: build/web

  deploy:
    needs: build
    if: startsWith(github.ref, 'refs/tags/v')
    runs-on: ubuntu-latest
    permissions:
      pages: write
      id-token: write
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    concurrency:
      group: pages
      cancel-in-progress: false
    steps:
      - id: deployment
        uses: actions/deploy-pages@v5
```

Notes on the skeleton:
- `actions/cache` can't expand `~` in `env:` values that are later used in `path:`, so the literal path is repeated in `path:`. `TEMPLATES_DIR` is informational; drop it if unused.
- `unzip -j` flattens `templates/…` into the target folder, which is exactly the layout Godot expects (`<version>/web_nothreads_release.zip`).
- `deploy-pages@v4+` needs the artifact from `upload-pages-artifact@v3+`. The v5/v5 pair is compatible. `upload-pages-artifact@v4+` drops dotfiles, and the web export has none.
- The grep is safe on green runs. This was verified locally on 2026-10-02: the expected `Log.error()` in `test_log.gd` prints `ERROR: [ERROR][test] boom`, not `SCRIPT ERROR`, so the current suite passes the grep. A real runtime script error inside a test prints `SCRIPT ERROR` and should fail anyway.
- Make sure `if grep … gut.log` runs even when GUT passes. With `set -o pipefail`, a GUT failure already stops the step before the grep, which is correct.
- `GODOT_BIN` path: the zip contains a single file `Godot_v4.7.2-stable_linux.x86_64`. Confirm with `ls .godot-bin` on the first run.

### Technical requirements and gotchas

- **Thread Support off = the `web_nothreads_*` templates.** That's the single-threaded build that runs on plain static hosting with no COOP/COEP headers (NFR5). With threads on, Pages would need headers it can't send.
- **Template names verified** inside the 4.7.2 `.tpz` (read remotely on 2026-10-02): `templates/web_nothreads_release.zip` (10.2 MB), `templates/web_nothreads_debug.zip`, `templates/version.txt` = `4.7.2.stable`. The whole `.tpz` is 1,281,349,702 bytes, so don't download it every run.
- **Export preset keys** (what the editor writes for Godot 4.7; verify against your generated file rather than hand-writing it): `name="Web"`, `platform="Web"`, `export_filter="all_resources"`, `exclude_filter="addons/gut/*, tests/*, tools/*, docs/*, _bmad/*, _bmad-output/*, build/*"`, `export_path="build/web/index.html"`, and under `[preset.N.options]`: `variant/thread_support=false`, `variant/extensions_support=false`, `vram_texture_compression/for_desktop=true`, `vram_texture_compression/for_mobile=false`, `progressive_web_app/enabled=false`, `html/canvas_resize_policy=2`, `html/focus_canvas_on_start=true`, `html/head_include=""`. **Create the presets in the editor, then inspect them.** Don't hand-write the file from scratch.
- **The Pages subpath works.** Godot's web export uses relative URLs, so `/ZombiesTeachTyping/` needs no base-path setting.
- **Gzip:** Pages compresses responses automatically (ADR-4). Record the actual `Content-Encoding` (Task 6.3) rather than assuming it, especially for `.wasm` and `.pck`.
- **Godot can exit 0 after some export errors** (for example missing templates print an error). That's why Task 4.6 checks that the output files exist.
- **Import step:** `--import` imports and quits. If it ever hangs on CI, use `--editor --quit` instead (it worked locally in Story 1.1).
- **Pages environment and tags:** see Prerequisite P4. It's the most likely first-deploy failure.
- **No secrets** are needed: Pages deploy uses the job's OIDC token (`id-token: write`).
- **Browser key-capture is out of scope.** The placeholder has no input. Story 1.5 handles Space, `'`, `/`, Backspace and Tab.

### Architecture compliance

- D8 / ADR-4: GitHub Pages from a public repo, deployed by Actions. Deploy **only** on `v*` tags; `main` and PRs build and upload an artifact only.
- D9: CI order is download → import → GUT (fail fast) → web export → (tag) deploy. Fail the build on any test failure.
- Export exclusions exactly as the architecture's Project Structure lists them.
- Naming: `snake_case` files. The scene and its future script share a path (`scenes/screens/title.tscn` ↔ `scripts/screens/title.gd` in Story 1.3).
- Boundary note: `test_export_presets.gd` reads a file with `ConfigFile`. That's fine in **tests**; the "only `SaveService` touches files" rule applies to game code.

### File structure requirements

New:
```
.github/workflows/build.yml
export_presets.cfg
scenes/screens/title.tscn            (placeholder; rebuilt in 1.3)
tests/unit/test_export_presets.gd (+ .uid)
_bmad-output/implementation-artifacts/screenshots/1-2/{chrome,edge,firefox}.png
```
Modified: `project.godot` (`run/main_scene`), possibly `deferred-work.md`. Deleted: `scenes/screens/.gitkeep`.

### Testing requirements

- `tests/unit/test_export_presets.gd` (`extends GutTest`, typed). Loads `res://export_presets.cfg` with `ConfigFile.load()` (assert `OK`). Iterate the `preset.N` sections to find the presets by `name`, then assert:
  - A preset named `Web` with `platform == "Web"`, `[preset.N.options] variant/thread_support == false` and `progressive_web_app/enabled == false`.
  - A preset named `Windows Desktop` with `platform == "Windows Desktop"`.
  - For both: `exclude_filter` contains each of `addons/gut/*`, `tests/*`, `tools/*`, `docs/*`, `_bmad/*`, `_bmad-output/*` and `build/*`. Split on `,` and strip, so formatting differences don't matter.
- Write the test first (red: the file doesn't exist yet, so the load fails), then create the presets (green).
- CI gate proofs (Tasks 5.2 and 5.3) are manual runs recorded by URL. The temporary failing test files must never land on `main`.
- Browser and load measurements are manual and recorded (Task 6).

### Latest tech information (checked 2026-10-02)

| Item | Version / fact |
|---|---|
| `actions/checkout` | `v7` (latest major tag) |
| `actions/cache` | `v6` |
| `actions/upload-artifact` | `v7` |
| `actions/upload-pages-artifact` | `v5` (uses upload-artifact v7; dotfiles excluded since v4; `include-hidden-files` input available) |
| `actions/deploy-pages` | `v5` (Node 24 runtime; needs upload-pages-artifact v3+) |
| Godot editor (Linux) | `Godot_v4.7.2-stable_linux.x86_64.zip`, 77,860,424 bytes |
| Godot templates | `Godot_v4.7.2-stable_export_templates.tpz`, 1,281,349,702 bytes |

### Project Structure Notes

- Matches the architecture's tree (`.github/workflows/build.yml`, `export_presets.cfg`, `build/` gitignored).
- Variance: a placeholder `title.tscn` arrives one story early, because the export needs a main scene. Story 1.3 owns its real content.
- Variance: `_bmad-output/implementation-artifacts/screenshots/1-2/` is a new folder for AC 5 evidence. It's excluded from export through `_bmad-output/*`.

### Project Context Rules

- No `project-context.md` exists. The rules come from the architecture's Consistency Rules and Story 1.1: strict static typing, `Log` for logging (no new logging in this story), tests for logic, standard Godot build only.
- Godot MCP (`mcp__godot__*`) is available. It reports the standard 4.7.2 build and can run the project for a desktop smoke check.
- The built-in browser can do the Chromium-side checks (Task 6). Edge and Firefox are Smuck's manual checks.

### References

- [Source: _bmad-output/planning-artifacts/epics.md#Story 1.2]
- [Source: _bmad-output/planning-artifacts/epics.md#Additional Requirements → Build, hosting & CI]
- [Source: _bmad-output/game-architecture.md#Hosting, Build & CI], [#Decision Summary D8, D9], [#ADR-4], [#Directory Structure → Export exclusions], [#Development Environment]
- [Source: _bmad-output/planning-artifacts/sprint-change-proposal-2026-09-27.md: U1 fractional scaling + 1366×768 check; tag-only deploy]
- [Source: _bmad-output/planning-artifacts/sprint-change-proposal-2026-09-27-b.md: boot splash belongs to Story 5.0]
- [Source: _bmad-output/implementation-artifacts/1-1-project-settings-folder-skeleton-and-test-harness.md: Dev Agent Record, Review Findings]
- [Source: _bmad-output/implementation-artifacts/deferred-work.md: GUT export exclusion]
- [Source: _bmad-output/planning-artifacts/ux-designs/ux-zombies-teach-typing-2026-09-27/DESIGN.md: night `#2B1D3F`, pumpkin `#F07A1C`, letterbox bars night]
- Actions: https://github.com/actions/deploy-pages/releases · https://github.com/actions/upload-pages-artifact/releases · https://github.com/actions/checkout/releases
- Environments: https://docs.github.com/actions/managing-workflow-runs-and-deployments/managing-deployments/managing-environments-for-deployment

## Dev Agent Record

### Agent Model Used

Claude Opus 5.5 (claude-opus-5-5)

### Implementation Plan

- Red/green per task. `test_main_scene_is_set_and_loads` (added to `test_project_settings.gd`) failed until `run/main_scene` was set. The 4 `test_export_presets.gd` tests failed until `export_presets.cfg` existed.
- **Deviation (Task 2.2–2.3):** the presets were written as a minimal `export_presets.cfg` instead of through the editor UI, which the agent can't drive. Each option key was verified against the exported output rather than assumed: `GODOT_THREADS_ENABLED = false`, `canvasResizePolicy: 2`, `focusCanvas: true`, and no manifest or service-worker files (so PWA is off). Godot's headless export accepted the file without rewriting it.
- **Deviation (Task 2.1):** the templates were installed by extracting only `version.txt`, `web_nothreads_{release,debug}.zip` and `windows_{release,debug}_x86_64[_console].exe` from the official 4.7.2 `.tpz`, using HTTP range requests, into `%APPDATA%\Godot\export_templates.7.2.stable\`. That's the same layout the editor's template manager uses, without the 1.28 GB download.
- **Addition beyond AC 1:** `.gutconfig.json` was also excluded in both presets. Godot treats `.json` as a resource, so the first export shipped it inside `index.pck`. `REQUIRED_EXCLUDES` in the test includes it.

### Debug Log References

- Pinned action versions (AC 2), re-checked 2026-10-02 with `git ls-remote --tags`: `actions/checkout@v7`, `actions/cache@v6`, `actions/upload-artifact@v7`, `actions/upload-pages-artifact@v5`, `actions/deploy-pages@v5`.
- Local web export (`Godot.exe --headless --export-release "Web"`): exit 0. Files: `index.html` 5,447 · `index.js` 279,815 · `index.wasm` 39,514,754 · `index.pck` 10,404 (after the `.gutconfig.json` exclusion) · `index.audio.worklet.js` 7,298 · `index.audio.position.worklet.js` 2,973 · `index.png` 21,443 · `index.icon.png` 5,765 · `index.apple-touch-icon.png` 11,939.
- GUT in pck (Task 3.2): the pck has no `GutTest`, no GUT scripts or scenes, no `res://tests/` and no `.gutconfig.json`. The single `addons/gut` hit is the `editor_plugins/enabled` project-setting string (`res://addons/gut/plugin.cfg`) in `project.binary`. Editor plugins never load at runtime, so it's harmless. (`strings` isn't available on this machine; Python byte search was used instead.)
- Local Windows Desktop export: exit 0 (`ZombiesTeachTyping.exe` + `.pck`, 10,404 bytes).
- Local static-server smoke test (`python -m http.server 8060`, built-in Chromium): renders, console shows "single-threaded, no GDExtension support", no errors.
- CI, first tag push (`v0.0.1` → `64cb50f`) **before** `main` had the workflow: **no run was created**, and `/actions/workflows` listed 0 workflows. After `main` was pushed, the workflow registered. The tag was deleted and re-pushed (with Smuck's approval) to trigger the deploy. Lesson: a workflow must be on the default branch before tag pushes trigger it in a new repo.
- CI `main` run (Task 5.1): https://github.com/Jacob-Verburg/ZombiesTeachTyping/actions/runs/37087019328. Build succeeded in 26 s (cache miss, full download), `upload-pages-artifact` skipped, `deploy` job skipped. Artifact `web-build` is 10,305,727 bytes. Cache `godot-4.7.2-stable-web-v1` saved.
- CI tag run (Task 5.4): https://github.com/Jacob-Verburg/ZombiesTeachTyping/actions/runs/37087079542. Cache hit (download skipped), GUT, export, Pages artifact and `deploy` all succeeded.
- Pages URL: https://jacob-verburg.github.io/ZombiesTeachTyping/ (HTTP 200).
- CI failing-test proof (Task 5.2): branch `ci-proof/failing-test` (`tests/unit/test_ci_must_fail.gd`, `assert_true(false)`; the branch added itself to the push trigger only on that branch). Run https://github.com/Jacob-Verburg/ZombiesTeachTyping/actions/runs/37087458947 failed at **Run GUT**; Export Web, artifact upload, Pages upload and `deploy` were all skipped; no artifacts. Branch deleted locally and on origin.
- CI parse-error proof (Task 5.3): branch `ci-proof/parse-error` (`tests/unit/test_ci_parse_error.gd` with `var x = 1`). Run https://github.com/Jacob-Verburg/ZombiesTeachTyping/actions/runs/37087459032 failed at **Run GUT**, with everything after it skipped and no artifacts. A lone unparseable script makes GUT exit 0 (Story 1.1), so the log grep is what failed the step. Run logs need a login, so this is inferred from the step result. Branch deleted.
- Content-Encoding (Task 6.3, curl and the browser): `index.html`, `index.js`, `index.wasm`, `index.pck` and the worklets are served **gzip**. The PNGs are uncompressed. `index.wasm` is 39,514,754 → 10,248,949 bytes on the wire. There are no COOP/COEP headers, and `crossOriginIsolated` is false: it runs with no special headers.
- Pages caching: `Cache-Control: max-age=600`, weak ETag. In the built-in Chromium pane a reload served everything from cache **except `index.wasm`** (10.2 MB re-downloaded). Godot's loader sets no cache options, so this is probably the pane's small HTTP cache. It must be checked in real Chrome, Edge and Firefox (Task 6.2 cached-load).

### Completion Notes List

- Ultimate context engine analysis completed - comprehensive developer guide created.
- AC 1 ✅: `Web` (threads off, no PWA) and `Windows Desktop` presets, both with the 7 required exclusions plus `.gutconfig.json`. Guarded by `tests/unit/test_export_presets.gd` (4 tests).
- AC 2 ✅: workflow written. `main` builds and uploads an artifact without deploying; the `v0.0.1` tag deployed to Pages; versions pinned (above).
- AC 3 ✅: proven on CI. Both a failing test and an unparseable test script fail the build at Run GUT, before the export, and nothing deploys (runs above).
- AC 4 ⏳ Chromium (unthrottled) shown working with no special headers. Compressed transfer is **10,350,910 bytes (~10.4 MB)**, well under the 40 MB check. At 25 Mbit/s the transfer alone is about 3.3 s, so first load should land well under 10 s. The official throttled first and cached loads in Chrome, Edge and Firefox are still to be measured (P6).
- AC 5 ⏳ Chromium at 1366×650: the canvas is 1366×650 and fills the full height with side bars only (scale about 1.8×). The 1 px probe sharpness and the per-browser screenshots are still to be done (P6). The bars are **black, not night**; that's logged in `deferred-work.md` for Story 5.0 (AC 5 doesn't require a bar color).
- Smuck's DevTools screenshot (**Edge**, confirmed by Smuck): cached reload with no throttling. `index.wasm` came from **disk cache** (0 B, 91 ms), the other files from memory or disk cache, 135 B transferred, DOMContentLoaded and Load at 84 ms, Finish 1.27 s. So real browsers do cache the wasm; the re-download seen earlier was the built-in pane. Cached load is about 1.3 s, under the 3 s target. Throttling doesn't change a fully cached load. Saved as [edge-cached-reload.png](screenshots/1-2/edge-cached-reload.png). The console's "AudioContext was not allowed to start" warning is expected; Story 1.4 adds the audio unlock on first input.
- **Firefox skipped (Smuck's decision, 2026-10-02):** Firefox isn't installed on the dev machine, so the AC 4 and AC 5 Firefox checks were not done. Risk: Firefox-specific behaviour (quick-find on `'`/`/`, IndexedDB persistence) is still untested. Stories 1.5 and 1.7 require Chrome **and Firefox** checks, and NFR4 names Firefox, so Firefox will be needed by then.
- **Closed as done by Smuck's decision (2026-10-02), with these checks skipped:** throttled first-load measurements (Chrome, Edge), the 100% zoom pixel-sharpness check and the Chrome 1366×768 screenshot, plus all Firefox checks (not installed). AC 4 first load rests on the measured transfer size (10.35 MB) and the arithmetic estimate, not a throttled measurement. AC 5 sharpness was only seen at "Fit to window" scale and in an unthrottled wide Chrome window, where the probe lines looked distinct.
- Tests: 22/22 passing locally (`gut exit=0`, no parse-error lines).

**Load-budget results (AC 4)**

| Browser | Transferred (compressed) | First load @25 Mbit/s | Cached load | Gzip on .wasm/.pck | Notes |
|---|---|---|---|---|---|
| Chrome | pending (throttled, cache disabled) | pending | ~1.2 s (Finish 1.19 s, DOMContentLoaded 76 ms, 154 B transferred, unthrottled, wasm from disk cache in 107 ms) | gzip (curl) | [chrome-cached-reload.png](screenshots/1-2/chrome-cached-reload.png) |
| Edge | pending (throttled, cache disabled) | pending | ~1.3 s (Finish 1.27 s, Load 84 ms, 135 B transferred, unthrottled, wasm from disk cache) | gzip (curl) | [edge-cached-reload.png](screenshots/1-2/edge-cached-reload.png) |
| Firefox | skipped | skipped | skipped | gzip (curl, browser-independent) | **Skipped by Smuck's decision (2026-10-02): Firefox isn't installed.** |

**1366×768 screenshots (AC 5):** chrome: pending · edge: [edge-1366x768-fit-to-window.png](screenshots/1-2/edge-1366x768-fit-to-window.png) (device toolbar 1366×768: fills the whole viewport with no bars at about 2.13×; taken at "Fit to window", so the 1 px probe sharpness still needs a 100% zoom shot) · firefox: skipped (not installed)

### File List

- `.github/workflows/build.yml` (new)
- `export_presets.cfg` (new)
- `scenes/screens/title.tscn` (new, placeholder)
- `scenes/screens/.gitkeep` (deleted)
- `project.godot` (modified: `run/main_scene`)
- `tests/unit/test_export_presets.gd`, `tests/unit/test_export_presets.gd.uid` (new)
- `tests/unit/test_project_settings.gd` (modified: main-scene test)
- `_bmad-output/implementation-artifacts/deferred-work.md` (modified: black letterbox bars, Firefox checks)
- `_bmad-output/implementation-artifacts/screenshots/1-2/edge-cached-reload.png`, `chrome-cached-reload.png`, `edge-1366x768-fit-to-window.png` (new)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified)
- `_bmad-output/implementation-artifacts/1-2-web-export-ci-and-github-pages-deploy.md` (this file)

### Change Log

- 2026-10-02: Story 1.2 implemented: Web and Windows Desktop export presets (with a `.gutconfig.json` exclusion), placeholder title main scene, GitHub Actions build/test/export workflow with Pages deploy on `v*` tags, `v0.0.1` published, and CI gates proven on throwaway branches. Browser checks partly skipped by Smuck's decision. Status → done (Smuck's call; code review skipped).
