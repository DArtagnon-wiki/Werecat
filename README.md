# Werecat

A Cute vs. Scary territory puzzle game for tweens (creepy and menacing, no gore), built with Godot 4.7.

**Rules:** walls only invade. Touch the Cute/Scary border or a finished wall and swipe into the other territory. The wall takes the color of what it grew from. If a bouncer touches it while it's growing, it breaks and you lose a life. When it finishes, every pocket of the invaded side with no bouncer inside flips. Level mode: hold the target Scary % for 3 seconds. Endless mode: chase a band that drifts every 12 seconds.

**Play:** https://dartagnon-wiki.github.io/Werecat/ (works in Safari on iPhone and Chrome on Android; use "Add to Home Screen" for full-screen play).

## Build flow

Every push to `main` runs `.github/workflows/build-web.yml`:

1. Installs Godot 4.7.2 and its web export templates (cached between runs).
2. Runs the headless smoke tests in `tests/smoke_test.gd`.
3. Exports the **Web** preset to `build/web/`.
4. Deploys that build to GitHub Pages.

Pull requests run the same build and tests and attach the web build as a downloadable artifact, but don't deploy.

The web export is single-threaded (`variant/thread_support=false`), so it runs on GitHub Pages without special cross-origin headers.

## Working locally

1. Install [Godot 4.7](https://godotengine.org/download) and open `project.godot`.
2. Press F5 to play. Mouse drags act as touch.
3. Run the tests: `godot --headless --path . -s res://tests/smoke_test.gd`
4. Export the web build: `godot --headless --path . --export-release "Web" build/web/index.html`

## Layout

| Path | What |
| --- | --- |
| `scenes/main.tscn`, `scripts/main.gd` | The prototype: menu, Level 1-3, Endless, wall rules, pocket flipping, werecat morph |
| `tests/` | Headless smoke tests run in CI |
| `export_presets.cfg` | Export presets (Web for now; Android and iOS later) |
| `art/` | Concept art, including the cute-to-scary morph GIF |
| `tools/` | The script that generated the morph GIF |
