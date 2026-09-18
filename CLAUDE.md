# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Neon Asteroids — a glowing vector Asteroids for LÖVE 11.5. No image or audio assets: graphics are procedural line art with shader bloom, and all sounds are synthesized at startup. No build step, linter or test suite. `backup/main_v1.lua` is the previous single-file version, kept for reference only (nothing loads it).

## Running

```
love .
```

`lovec` (the Windows console build) shows `print` output. Code must be Lua 5.1/LuaJIT: no `+=`, no `math.hypot`.

**Headless checking**: a throwaway LÖVE project outside the repo can put this repo on `package.path`, `dofile` its `main.lua`, stub `love.keyboard.isDown`, and call the captured `love.update/draw/keypressed` in a loop. To screenshot, redirect `love.graphics.setCanvas(nil)` to a capture canvas (the glow composite draws to the screen) and encode `canvas:newImageData()` to PNG. Restore `setCanvas` before quitting, or LÖVE errors on shutdown with a canvas still active.

That loop never calls `love.graphics.present`, so it can't catch frame-presentation bugs such as a canvas left active after `love.draw`. Also run the game under the normal `love.run` from a harness that `dofile`s `main.lua`, quits itself after a few seconds from `love.update`, and overrides `love.errorhandler` to print the error and `os.exit(1)`.

## Architecture

- `main.lua` is only glue. It letterboxes a fixed **1280×720 virtual screen** (`Game.W/H`) into the window, wraps each frame in `glow:begin()` / `glow:finish()`, and forwards input.
- `src/game.lua` holds all gameplay state in one table `S`. Modes: `"title"` (attract mode, where asteroids explode silently), `"play"` and `"gameover"`. The playfield wraps at every edge:
  - Collisions use `wrappedDist` (the toroidal shortest distance).
  - Entities near an edge are drawn again with an offset via `drawWrapped`.
- `src/glow.lua` is the bloom pipeline:
  - The scene goes to an HDR (`rgba16f`), MSAA canvas.
  - It is downsampled to three blur levels (half, quarter, eighth size). The first downsample passes through a prefilter that caps brightness at `BLOOM_CEILING`.
  - A composite shader adds the bloom, chromatic aberration (driven by shake trauma), scanlines, a vignette and a full-screen flash.
- `src/neon.lua` draws every stroke three times with **additive blending** (wide halo, glow, whitened core) and contains the stroke-based vector font (`GLYPH_SRC`, a 4×6 grid, strokes separated by `|`). All text is drawn with `Neon.text`, never with LÖVE fonts.
- `src/fx.lua` holds particles (spark streaks, tumbling debris segments, shockwave rings, soft flash sprites) and the trauma-based screen shake. `Fx.update` runs on game time (slowed during slow motion); `Fx.updateShake` runs on real time.
- `src/sfx.lua` synthesizes sounds into `SoundData` using Williams-style sample-and-hold noise for explosions. Each effect has a fixed pool of voices (the oldest is stolen when all are busy). Stereo panning uses `setPosition` with the distance model set to `"none"`. Loops (thrust, UFO) are started and stopped with `Sfx.loop(name, bool)`.
- `lib/starfield.lua` is a vendored copy from the retro-starfield-starter-kit (MIT). Treat it as third-party and don't edit it.

## Tutorial (`tutorial/`)

A 21-chapter beginner tutorial built around this game.
- **Checkpoints:** `tutorial/NN-name/` is a standalone, runnable snapshot of the game at the end of chapter NN.
  - Chapters 3–9 are single-file.
  - From Chapter 10 the checkpoints use the same module layout as the game. Each checkpoint is the next one with a feature removed.
  - Chapter 18's checkpoint is the project root itself.
- **Generated files — don't edit them by hand:** `tutorial/README.md` and `tutorial/learn-love.html` are built output.
- **Editing the text:** edit the parts in `tutorial/_source/0*.md`, then run `tutorial/_source/build.ps1` followed by `build-page.ps1`.
  - The parts use `@@include <path> | startRegex | endRegex [| nth]@@` to pull code from checkpoint files. Paths are relative to `tutorial/`, and `../` reaches the finished game.
  - The build fails if an anchor no longer matches.
- **Changing the game's code:** the root game is also the Chapter 18 checkpoint, so check whether earlier checkpoints and excerpts need the same change, then rebuild.
- Leave `tutorial/` and `backup/` out of any packaged `.love`.

## Conventions and gotchas

- **Blending**: gameplay drawing assumes `setBlendMode("add")`. Switch to `"alpha"` only for things that must darken (the starfield, the pause dimmer).
- **Bloom multiplies large soft areas roughly 3×**, so filled glows and flash sprites must be drawn dim (see the FLASH alpha in `fx.lua`) or they clip to flat white discs.
- **Screen shake is reserved for big events** (large asteroid, UFO, ship death, smart bomb); small and medium asteroids add none. Add shake with `Fx.shake(amount)`, not by setting offsets.
- **Tuning constants** live at the top of `game.lua` (ship, bullets, the `ASTEROID`/`UFO` tables, `WAVE_HUES`) and in each module's header.
- **Local functions in `game.lua` are defined before use.** Keep that order when adding functions.
