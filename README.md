# Werecat

A Cute vs. Scary territory puzzle game for tweens (creepy and menacing, no gore), built with Godot 4.7.

**How it plays:** the only walls are the field's border. Put your finger down in one territory and draw any shape into the other: that's a safe blueprint. When it gets back to your own side, the edge or moonstone, the real wall grows along it from both ends. If anything touches a grown section before the ends meet, the wall snaps and you lose a heart. When they meet, pockets touching the new wall that have no bouncer inside flip to your color, and bouncers squeezed into tiny pockets next to it are trapped. Pockets elsewhere are never affected. Lifting your finger before closing is free. Hold the meter inside the gold band for 3 seconds to win the night.

**100 nights in 20 worlds**, each teaching something new:

| World | Theme | Teaches |
| --- | --- | --- |
| 1 · Moonrise | Learn the claim | Claiming, the goal band, small finishing claims, trapping |
| 2 · Moonstone | Tools that help | Bombs, moonstone, moon charms, must-hold regions |
| 3 · Creeping Dark | Threats that grow | Thorn seeds, roosts, gloom grubs and sugar slugs |
| 4 · Hallowed Ground | Rules that change | Shrines (bless/curse), line curl: straight, arcs, curly |
| 5 · Blood Moon | Hunters of the night | Idols, crowned creatures, wisps, hunters, the Night Mother |
| 6 · The Hunt | Mastery | Remixes of everything, ending with The Last Idol |
| 7 · Gift Boxes | Generators to push into | Gift boxes and huggy huts in the ground you're taking |
| 8 · Strange Shores | New ground shapes | Diagonals, donuts, archipelagos, waves, an hourglass |
| 9 · Hunter Dens | Generators that hunt | Dens (hunter bats) and huggy huts (huggy puffs) |
| 10 · Burrows | Tunnelers on tap | Grub burrows and candy burrows |
| 11 · Lantern Light | Wisps on tap | Wisp lanterns |
| 12 · Stone Halls | Bricks and straight lines | Corridors, peg grids with straight lines, a vault, a cursed diamond hall, a maze |
| 13 · Bat Pens | Lone bats | Win needs N bats each alone in its own Scary pocket; doors between stone rooms |
| 14 · Guardians | Guarded rings | Hold rings with a creature starting inside each, stone halos, rings plus lone bats |
| 15 · Swarm | Generators everywhere | Many generators at once, the Hive Queen |
| 16 · Holy Orders | Rings and generators | Hold rings and shrines guarded by generators |
| 17 · Bone Yard | Targets with backup | Idols and crowned creatures with generators |
| 18 · Labyrinth | Mazes | Mazes with straight lines, a hunter, lone bats |
| 19 · Eclipse | Everything mixed | Mixed objectives on new shapes |
| 20 · Midnight | The gauntlet | Remixes, ending with Midnight |

Each world goes introduce, develop, twist, combine, finale, and every night follows the same design rules (checked by the smoke tests):

- The gold band starts at least 30 points from the starting split (nights declare `"push": [direction, distance, width]` and the band is measured from the real starting ground), so no night falls to one or two swipes.
- The ground you push into is guarded by several creatures, so grabbing huge chunks early is risky.
- Generators sit in the ground you're pushing into, so closing them is part of the job.
- Nights combine mechanics: stone with straight-line curses, hold rings with a creature starting inside each (some behind stone halos), lone bats plus rings, mazes with hunters, and so on.

Difficulty is tuned per night with a creature-speed "tempo" (`TEMPO` in `scripts/levels.gd`, tuned by `tools/tune_tempo.py`) against the bot's win rate: about 85% in World 1 down to about 30% in World 20, with each world's finale its hardest night. The bot plays like a careful person: it picks walls that keep clear of creatures and pockets with nobody inside.

A night that can no longer be won ends at once with the reason (for example, too few bats left to pen and no roost to hatch more).

**Generators** keep hatching until their ground flips: bat roosts and gift boxes (bats / fuzzies), hunter dens and huggy huts (hunters), grub and candy burrows (carvers), and wisp lanterns (wisps, both sides, max 2).

A color can never be wiped out: if a claim would take a color's last ground, its biggest pocket survives as a foothold.

Plus **Endless**: a drifting goal band, random bombs, charms and seeds, and creatures that keep arriving with no cap (faster over time, max 2 untrappable wisps). To run far, you have to trap them. Points only flow while you're actively claiming: full rate for 6 s after each finished wall, fading to zero over the next 4 s, so idling while the band drifts over you scores nothing. Sitting in a band that has settled scores normally. Progress, stars and best score are saved on the device.

**Play:** https://dartagnon-wiki.github.io/Werecat/ (works in Safari on iPhone and Chrome on Android; use "Add to Home Screen" for full-screen play).

## Graphics and performance

Graphics setting (title screen or pause menu): **Auto** (default), **High**, **Medium**, **Lite**.

| Tier | What changes |
| --- | --- |
| High | Full shaders at the screen's native resolution |
| Medium | Full shaders at the 720-wide design resolution, upscaled (screens wider than 760 px) |
| Lite | Medium plus cheap shaders (baked noise texture, pre-blurred halo), 40% particles, one music loop decoded at a time |

Auto starts at the last tier it picked and steps down when a 3-second stretch averages under 40 fps (straight to Lite under 22 fps). Choosing Auto again re-detects from High.

On every tier the werecat's 800x800 layers draw only their visible rectangle (`scripts/sprite_crops.gd`, generated by `tools/gen_crops.py`), and fully faded layers are hidden.

**Debug release.** A small fps readout is shown at the top; tap it for details: frame times, script time, a GPU-wait estimate, the claim fill time, render size, tier, GPU and device. Link options:

| Link option | Effect |
| --- | --- |
| `?debug=0` | hide the readout |
| `?debug` | start with the details expanded |
| `?gfx=lite` (or high, medium, auto) | force a tier for this visit (not saved) |
| `?play=25` | jump straight into night 25 |
| `?hide=bg,field,cat,ui,fx` | hide layers to find what costs GPU time |

Benchmark on a simulated weak GPU (Chrome SwiftShader): `python3 tests/browser_bench.py build/web "?gfx=lite" 3 20`.

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
| `scripts/levels.gd` | The 100 levels, mechanic tips, and the territory and stone layout generators (splits, islands, checkers, rings, spirals, diagonals, donuts, blobs, frames, waves, hourglass; pillars, chambers, mazes, bars, pegs, rocks, box, diamond, comb) |
| `scripts/audio.gd` | Music crossfade (cute ↔ scary by morph) and the SFX voice pool |
| `scripts/werecat.gd` | Layered werecat rig: 5 morph tiers, blink, glow, drool, mantis strikes |
| `shaders/` | Territory (smooth organic edges, dissolve), night sky + moon, trail ribbon |
| `assets/sprites/` | Rendered art (generated, don't hand-edit) |
| `assets/fonts/` | Fredoka and Grenze Gotisch (SIL Open Font License) |
| `tests/` | Headless smoke tests and the bot playtest (run in CI); `level_sheet.gd` renders every starting layout to `build/levels.png` |
| `export_presets.cfg` | Export presets (Web for now; Android and iOS later) |
| `tools/gen_audio.py` | Composes and synthesizes all music and SFX from math (needs numpy, scipy, ffmpeg) |
| `assets/audio/` | Generated music loops and sound effects (OGG) |
| `tools/gen_art.py` | Generates every sprite as layered SVG, renders to PNG (needs `rsvg-convert`) |
| `tools/preview_werecat.py` | Composites the werecat at several morph values for art review |
| `art/concept/` | Early concept GIF and its generator |
