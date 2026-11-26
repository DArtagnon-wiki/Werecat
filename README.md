# Werecat

A Cute vs. Scary territory puzzle game for tweens (creepy and menacing, no gore), built with Godot 4.7.

**How it plays:** the only walls are the field's border. Put your finger down in one territory and draw any shape into the other: that's a safe blueprint. When it gets back to your own side, the edge or moonstone, the real wall grows along it from both ends. If anything touches a grown section before the ends meet, the wall snaps and you lose a heart. When they meet, every pocket you cut off with no bouncer inside flips to your color, and bouncers squeezed into tiny pockets are trapped. Lifting your finger before closing is free. Hold the meter inside the gold band for 3 seconds to win the night.

**20 nights in 4 worlds**, each teaching something new:

| World | New mechanics |
| --- | --- |
| 1 · Moonrise | Claiming, the goal band, trapping |
| 2 · Boom Night | Bombs, moonstone, moon charms (freeze) |
| 3 · Creeping Dark | Gloom grubs and sugar slugs (carvers), thorn seeds, bat roosts |
| 4 · Blood Moon | Wisps (cross any border), hunters (chase your line), the Night Mother |

Plus **Endless**: a drifting goal band, escalating bouncers and random bombs, charms and seeds. Progress, stars and best score are saved on the device.

**Play:** https://dartagnon-wiki.github.io/Werecat/ (works in Safari on iPhone and Chrome on Android; use "Add to Home Screen" for full-screen play).

## Build flow

Every push to `main` runs `.github/workflows/build-web.yml`:

1. Installs Godot 4.7.2 and its web export templates (cached between runs).
2. Runs the headless smoke tests in `tests/smoke_test.gd` (every mechanic, every level loads and simulates).
3. Runs `tests/bot_test.gd`: a bot plays all 20 levels and must win each one, so no unwinnable level ships.
4. Exports the **Web** preset to `build/web/`.
5. Deploys that build to GitHub Pages.

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
| `scripts/main.gd` | Game: claims, entities and mechanics, goal band, Endless, all screens, save file |
| `scripts/levels.gd` | The 20 levels, mechanic tips, and starting-layout generators |
| `scripts/audio.gd` | Music crossfade (cute ↔ scary by morph) and the SFX voice pool |
| `scripts/werecat.gd` | Layered werecat rig: 5 morph tiers, blink, glow, drool, mantis strikes |
| `shaders/` | Territory (smooth organic edges, dissolve), night sky + moon, trail ribbon |
| `assets/sprites/` | Rendered art (generated, don't hand-edit) |
| `assets/fonts/` | Fredoka and Grenze Gotisch (SIL Open Font License) |
| `tests/` | Headless smoke tests run in CI |
| `export_presets.cfg` | Export presets (Web for now; Android and iOS later) |
| `tools/gen_audio.py` | Composes and synthesizes all music and SFX from math (needs numpy, scipy, ffmpeg) |
| `assets/audio/` | Generated music loops and sound effects (OGG) |
| `tools/gen_art.py` | Generates every sprite as layered SVG, renders to PNG (needs `rsvg-convert`) |
| `tools/preview_werecat.py` | Composites the werecat at several morph values for art review |
| `art/concept/` | Early concept GIF and its generator |
