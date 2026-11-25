# Werecat

A Cute vs. Scary territory puzzle game for tweens (creepy and menacing, no gore), built with Godot 4.7.

**How it plays:** the only walls are the field's border. Put your finger down in one territory and draw any shape into the other. When your line gets back to your own side, or reaches the edge, every pocket you cut off that has no bouncer inside flips to your color. If a bouncer touches your line while it's open, the line snaps and you lose a life. Lifting your finger early is free. Level mode: hold the target Scary % for 3 seconds. Endless mode: chase a band that drifts every 12 seconds.

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
| `scripts/main.gd` | Game: freehand claims, bouncers, goal band, Endless, HUD, menu |
| `scripts/werecat.gd` | Layered werecat rig: 5 morph tiers, blink, glow, drool, mantis strikes |
| `shaders/` | Territory (smooth organic edges, dissolve), night sky + moon, trail ribbon |
| `assets/sprites/` | Rendered art (generated, don't hand-edit) |
| `assets/fonts/` | Fredoka and Grenze Gotisch (SIL Open Font License) |
| `tests/` | Headless smoke tests run in CI |
| `export_presets.cfg` | Export presets (Web for now; Android and iOS later) |
| `tools/gen_art.py` | Generates every sprite as layered SVG, renders to PNG (needs `rsvg-convert`) |
| `tools/preview_werecat.py` | Composites the werecat at several morph values for art review |
| `art/concept/` | Early concept GIF and its generator |
