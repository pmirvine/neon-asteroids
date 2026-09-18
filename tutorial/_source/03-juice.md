<div class="part">Part 3 · Growing the project</div>

## 10. Files, screens and a proper structure

Chapter 9's single file is about 330 lines. The finished game is over 1,500 lines. One giant file becomes hard to find your way around, so before adding effects we'll reorganise, and add three things every real game needs:

1. **Several files**, each with one job.
2. **Screens** (modes): a title screen, the game itself, and a game-over screen.
3. **Resolution independence**: the game looks right in any window size, or fullscreen.

This chapter is mostly *reorganisation* of code you already understand, so the easiest way through it is to **copy the checkpoint `tutorial/10-structure` into your project** (replacing your `main.lua`), then read along. The new ideas are explained below.

The new layout:

```
my-asteroids/
├── conf.lua        window settings, read before the game starts
├── main.lua        glue: scaling to the window, passing input to the game
└── src/
    └── game.lua    the whole game: state, entities, update, draw
```

Over the next chapters `src/` will gain `neon.lua`, `fx.lua`, `glow.lua` and `sfx.lua`, one module per effect.

### conf.lua

LÖVE runs `conf.lua` *before* it opens the window, so window settings belong here:

@@include 10-structure/conf.lua@@

`t.identity` names the folder where the game can save files (we'll save the high score there). Turning off modules we don't use (`physics`, `video`) makes startup slightly faster.

### A bigger virtual screen, scaled to fit

The game is designed for a fixed **1280 × 720 "virtual" screen**. All positions, speeds and sizes are in those units. `main.lua` scales that screen to fit whatever window the player has, adding black bars (**letterboxing**) if the shape doesn't match:

@@include 10-structure/main.lua@@

- `fitView` works out the largest scale at which 1280 × 720 fits the window, and the offsets that centre it.
- In `love.draw`, `translate` + `scale` mean the game can *draw* in 1280 × 720 coordinates and LÖVE stretches it to fit. **The game code never needs to know the real window size.**
- `setScissor` clips drawing to the game area, so nothing spills into the black bars. (Scissor coordinates are in real window pixels, which is why it uses the scaled numbers.)
- `love.resize` is called whenever the window changes size, including going fullscreen with F11.
- `math.min(dt, 1 / 30)` caps `dt`. If the window is dragged or the computer hiccups, one frame could take half a second. Without the cap, everything would jump a long way at once and bullets could pass straight through asteroids.

### The game as a module

`main.lua` does `local Game = require "src.game"`. The file `src/game.lua` builds a table called `Game`, puts a few public functions on it (`Game.load`, `Game.update`, `Game.draw`, `Game.keypressed`) and returns it at the end. **Everything else in the file is `local`**, so it's private to the module and can't clash with anything elsewhere.

### One table for all the state

Instead of a dozen loose variables (`score`, `lives`, `bullets`, …), all changing game state lives in a single table, `S`:

```lua
local S = {} -- all mutable game state
-- S.mode, S.score, S.lives, S.wave, S.ship, S.asteroids, S.bullets, ...
```

Resetting the game means resetting one table, and any function can see the state without long argument lists.

### Screens as modes

`S.mode` is `"title"`, `"play"` or `"gameover"`. `Game.update` and `Game.draw` check it and do different things, and a few small functions switch between modes:

@@include 10-structure/src/game.lua | ^local function resetState | ^end$ | 4@@

| In mode | When… | Go to |
|---|---|---|
| `title` | Space or Enter is pressed | `play` (`startGame`) |
| `play` | the last life is lost | `gameover` (`enterGameOver`) |
| `play` | Esc is pressed | `title` (`enterTitle`) |
| `gameover` | Space or Enter, after 1.5 seconds | `play` (`startGame`) |
| `gameover` | Esc is pressed | `title` (`enterTitle`) |

This is called a **state machine**: a set of states, and clear rules for moving between them. The title screen keeps asteroids drifting behind the text (the arcade **attract mode**) by running only `moveAsteroids` when not playing.

Input is handled per mode too:

@@include 10-structure/src/game.lua | ^function Game.keypressed | ^end$@@

### Hold to fire

Modern players expect to hold the fire button. The ship now has a `fireTimer`. `updateShip` counts it down and fires whenever the button is held and the timer has run out:

```lua
s.fireTimer = s.fireTimer - dt
if firing and s.fireTimer <= 0 then fire() end   -- fire() resets fireTimer to 0.14
```

### Reusing tables

`transform` now takes an `out` table to write into, instead of creating a new table every call:

@@include 10-structure/src/game.lua | ^-- Rotate \+ translate | ^end$@@

Each asteroid keeps its own `pts` table and the ship keeps `s.pts`. Creating thousands of small tables every second makes Lua's **garbage collector** work hard to clean them up, which can cause tiny stutters. Reusing tables avoids that. The optional `scale` argument lets the HUD draw small ships for the lives counter.

### Saving the high score

@@include 10-structure/src/game.lua | ^local function loadHighScore | ^end$ | 2@@

`love.filesystem.write` saves into the game's **save folder**, named by `t.identity` in `conf.lua`:

| System | Save folder |
|---|---|
| Windows | `%APPDATA%\LOVE\neon-asteroids` |
| macOS | `~/Library/Application Support/LOVE/neon-asteroids` |
| Linux | `~/.local/share/love/neon-asteroids` |

**`pcall`** ("protected call") runs a function and catches any error instead of crashing. `pcall(f, a, b)` returns `true` plus `f`'s results if it worked, or `false` plus the error message if it didn't. A missing or unreadable save file should never crash the game, so we fall back to 0.

### Score pop-ups and banners

Two small touches make the game read better. Points float up from each destroyed asteroid (`popup`), and a big **"WAVE 2"** banner fades in and out (`S.banner`). Both are tables with a timer that `Game.update` counts down, and `drawPopups` and `drawBanner` fade them out by using the remaining time as alpha. Text is drawn through a small `drawText` helper, so Chapter 17 can swap in a glowing font by changing one function.

![The restructured game in a 1280 × 720 window](images/ch10.png)

> **Try it:** Resize the window and press F11. The game always stays in proportion. Then find the `ASTEROID` table in `src/game.lua` and try doubling every `speedHi`.

<div class="part">Part 4 · Making it glow</div>

## 11. Neon lines

Now the fun begins. Real neon, and old vector arcade screens, have a **bright, almost white core** surrounded by a **soft coloured halo**. We fake that by drawing every line three times:

1. a **wide, faint** line: the outer halo
2. a **medium, brighter** line: the glow
3. a **thin, bright** line pushed toward white: the hot core

### Additive blending

Normally, drawing a colour *covers* what's underneath (**alpha blending**). Neon needs **additive blending**, where colours *add*: red on top of blue gives magenta, and overlapping glows get brighter, just like light:

```lua
love.graphics.setBlendMode("add")    -- colours add up, like light
love.graphics.setBlendMode("alpha")  -- the normal "paint over" mode
```

With additive blending, drawing black does nothing (adding zero), and three faint overlapping passes become one bright line. It's the single most important trick behind "glowing" game graphics.

### The Neon module

Create `src/neon.lua`:

@@include 11-neon/src/neon.lua@@

`Neon.lines` takes a flat point list, a colour, an alpha, a width, and whether the shape is closed. The core colour `r + (1 - r) * CORE_WHITE` moves each channel halfway toward 1, so a pure blue core becomes a pale blue.

### Colours by wave: HSV

Picking pleasing neon colours by mixing red, green and blue is fiddly. **HSV** describes a colour as **hue** (where it is on the colour wheel, 0 to 1), **saturation** (how vivid), and **value** (how bright). Walk the hue around the wheel and you get a rainbow of equally bright colours. The game gives each wave its own hue:

```lua
local WAVE_HUES = { 0.88, 0.07, 0.76, 0.14, 0.97, 0.30, 0.62 }
--                  pink  orange violet amber rose  green  blue
```

@@include 11-neon/src/game.lua | ^local function hsv | ^end$@@

`newAsteroid` now picks its colour with `hsv(S.hue + ..., 0.78, 1)`, nudging the hue for each size so a wave has a family of related colours.

### Drawing with Neon

In `src/game.lua`, add `local Neon = require "src.neon"` at the top, then switch the draw functions over:

@@include 11-neon/src/game.lua | ^local function drawAsteroid | ^end$ | 3@@

And at the start of `Game.draw`, after painting the background, switch to additive blending and smooth, bevelled line joins:

```lua
lg.setBlendMode("add")
lg.setLineStyle("smooth")
lg.setLineJoin("bevel")
```

Switch back with `lg.setBlendMode("alpha")` at the end of `Game.draw`. (`lg` is a local shortcut for `love.graphics` at the top of `game.lua`.)

![Three-pass neon lines](images/ch11.png)

It's subtler than you might expect. The lines look *cleaner* and slightly soft, but they don't really *glow* yet. That's Chapter 14's job. Each of these steps builds on the others.

> **Try it:** Change `HALO_WIDTH` to 8 and `HALO_ALPHA` to 0.25 to see what the halo pass does on its own. Then set `CORE_WHITE` to 0 and then 1 to see the core's effect.

## 12. Particles

Nothing sells an explosion like a shower of sparks. A **particle** is a tiny short-lived object with a position, velocity and lifetime. A **particle system** is just a list of them that you update and draw every frame. You already built one: the bullets!

The game uses four kinds:

| Kind | Looks like | Used for |
|---|---|---|
| **spark** | a streak along its velocity, starting white-hot and cooling to its colour | explosions, engine exhaust, muzzle flash |
| **debris** | one edge of a destroyed shape, tumbling away | asteroid, ship and saucer wreckage |
| **ring** | an expanding circle that thins and fades | shockwaves |
| **flash** | a soft glowing blob that swells and fades | the bright moment of detonation |

Create `src/fx.lua`:

@@include 12-particles/src/fx.lua@@

The ideas worth studying:

- **One list, many kinds.** Every particle is a table with a `kind` field. `Fx.update` and `Fx.draw` check it. (More advanced engines keep one list per kind for speed, but a few thousand particles is no problem for LuaJIT.)
- **Swap-remove.** Particles don't need to stay in order, so a dead one is removed by moving the *last* particle into its slot. `table.remove` would shift every later element, which is slow with thousands of particles.
- **Life as a fraction.** `t = p.life / p.max` goes from 1 (just born) to 0 (about to die). Nearly every visual uses it. Alpha fades with `t`, and sparks start **white-hot** (`hot = t * t * t`) and cool to their colour.
- **Easing.** Rings grow with `1 - (1 - k)³`, which moves fast at first and then slows, like a real shockwave losing energy.
- **Debris from any shape.** `Fx.debris` takes a polygon, the same point list used to draw it, and turns each edge into a tumbling line that flies away from the centre. The wreckage is literally the thing that was destroyed.
- **The flash sprite** is a small image generated in code. `love.image.newImageData` creates a blank image and `mapPixel` sets every pixel's colour from a function, in this case a soft radial falloff.
- **A particle cap** (`MAX_PARTICLES`) stops a huge chain reaction from slowing the game to a crawl.

### Hooking particles into the game

`Fx.explosion(x, y, scale, r, g, b, vx, vy)` bundles a flash, a ring and two bursts of sparks into one call. `destroyAsteroid` uses it, sized by a new `fx` field in the `ASTEROID` table (3.2 for large, 1.2 for small), plus debris from the asteroid's own outline:

@@include 12-particles/src/game.lua | ^local function destroyAsteroid | ^end$@@

The ship's death is the biggest effect in the game:

@@include 12-particles/src/game.lua | ^local function killShip | ^end$@@

A few smaller additions: thrust spawns three orange sparks per frame out of the back of the ship, firing makes a tiny muzzle burst, a respawning ship "materialises" with `Fx.implode` (sparks rushing *inward*), and `Game.update`/`Game.draw` call `Fx.update(dt)` and `Fx.draw()`. The title screen now blows up an asteroid every couple of seconds, which gives the attract mode something to show off:

@@include 12-particles/src/game.lua | ^local function updateAttract | ^end$@@

![Sparks, debris and shockwave rings](images/ch12.png)

> **Try it:** In `Fx.explosion`, multiply the spark counts by 3. Then try making sparks fall under gravity: in `Fx.update`, add `p.vy = p.vy + 200 * dt` for sparks only.

## 13. Screen shake, hitstop and slow motion

Three techniques that make big moments *hit*.

### Screen shake with "trauma"

Shaking the camera randomly each frame looks jittery and cheap. A much better approach, popularised by game developer Squirrel Eiserloh, uses **trauma**:

- Events **add trauma**, a number from 0 to 1. A large asteroid adds 0.3, the ship exploding adds 0.8.
- Trauma **decays** steadily over time.
- The visible shake is **trauma squared**. Small amounts give almost no shake, and big amounts give a lot. It feels natural, and several small hits add up to a big shake.
- The offset comes from **smooth noise**, not random numbers. `love.math.noise(t)` gives a value that changes *smoothly* as `t` increases, so the camera sways and rattles instead of teleporting around.

@@include 13-shake/src/fx.lua | ^local SHAKE_OFFSET | ^local TRAUMA_DECAY@@

@@include 13-shake/src/fx.lua | ^function Fx.shake | ^end$@@

@@include 13-shake/src/fx.lua | ^-- Runs on real | ^end$@@

The three different second numbers in `noise(t, 11.3)`, `noise(t, 47.9)` and `noise(t, 83.1)` read three unrelated slices of the noise, so x, y and rotation don't move in step.

**Shake is reserved for big events.** Small and medium asteroids add none. If *everything* shakes the screen, nothing feels big, and the constant motion gets tiring. The `ASTEROID` table gets a `shake` field: 0.3 for large, 0 for the others.

Applying the shake is one transform around the screen centre, at the start of the world drawing in `Game.draw`. The HUD is drawn *after* the matching `lg.pop()`, so the score stays still:

```lua
lg.push()
lg.translate(W / 2 + Fx.shakeX, H / 2 + Fx.shakeY)
lg.rotate(Fx.shakeAngle)
lg.translate(-W / 2, -H / 2)
-- ... draw particles, asteroids, bullets, ship ...
lg.pop()
```

(Rotation happens around the origin, so we move the origin to the screen centre, rotate, and move it back.)

### Hitstop and slow motion

When the ship explodes, the game **freezes for 0.09 seconds** (*hitstop*, a trick from fighting games that makes impacts feel solid), then runs in **slow motion** that speeds back up to normal over 0.9 seconds. Both are done by changing `dt` before the rest of the game sees it:

@@include 13-shake/src/game.lua | ^function Game.update | ^end$@@

Notice `Fx.updateShake(dt)` runs **before** hitstop and slow motion, on real time. The camera keeps shaking during the freeze, which is what makes it feel like an impact rather than a lag spike. Everything after that line, including particles, runs on the slowed `dt`.

`killShip` sets it all off:

```lua
Fx.shake(0.8)
S.hitstop = HITSTOP_TIME   -- 0.09
S.slowmo = SLOWMO_TIME     -- 0.9
```

`destroyAsteroid` gains a `quiet` parameter. The attract mode passes `true` so the title screen explodes quietly, with no shake (and, from Chapter 15, no sound).

![A large asteroid exploding with the screen mid-shake](images/ch13.png)

> **Try it:** Set `SLOWMO_TIME` to 3 and die on purpose. Then look at what's happening to `dt` during slow motion, and change the `0.7` to make it even slower.

## 14. Bloom with shaders

This is the chapter that makes it *neon*. **Bloom** is the soft glow that spreads out around bright light. The plan:

1. Draw the whole frame into an off-screen image (a **canvas**) instead of the screen.
2. Make blurred, shrunken copies of it.
3. Add the blurred copies back on top of the original.

Bright lines get a halo because their light has been smeared outwards. Dark areas stay dark, because blurring black gives black.

### Canvases

A **canvas** is an image you can draw into:

```lua
local canvas = love.graphics.newCanvas(1280, 720)

love.graphics.setCanvas(canvas)    -- everything now draws into the canvas
love.graphics.clear(0, 0, 0, 1)
-- ... draw the game ...
love.graphics.setCanvas()          -- back to drawing on the screen
love.graphics.draw(canvas)         -- show the canvas like any image
```

Two optional settings matter here:

- **`format = "rgba16f"`** stores colours as floating-point numbers, so they can go **above 1**. When additive neon piles up, a normal canvas clips at pure white, but an HDR ("high dynamic range") canvas remembers *how much* brighter than white it was. That makes the glow much more convincing.
- **`msaa = 4`** turns on anti-aliasing, for smoother lines.

### Shaders in two minutes

A **shader** is a small program that runs on the graphics card, once for **every pixel** being drawn, all in parallel. LÖVE shaders are written in **GLSL**, a C-like language. A "pixel shader" in LÖVE is a function called `effect`:

```glsl
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen_coords) {
    vec4 pixel = Texel(tex, uv);   // read the image being drawn, at this spot
    return pixel * color;          // the colour this pixel should become
}
```

- `vec2`, `vec3` and `vec4` are groups of 2, 3 or 4 numbers (positions, colours).
- `uv` is the position in the image, from (0, 0) at one corner to (1, 1) at the other.
- `Texel(image, uv)` reads a colour from an image.
- **`extern`** declares an input you set from Lua with `shader:send("name", value)`.

You use a shader by setting it and drawing: `love.graphics.setShader(shader)`, draw something, then `love.graphics.setShader()` to switch it off.

### Blurring fast

A blur averages each pixel with its neighbours. A wide blur reads many neighbours, which gets slow, so we use two tricks:

- **Separable blur:** blurring horizontally and then vertically gives the same result as a 2D blur, for far fewer reads.
- **Downsampling:** blur a *half-size* copy, then a quarter-size one, then an eighth. Each smaller copy spreads the glow twice as far for the same cost. Adding all three gives a tight halo *and* a wide soft glow.

### The Glow module

Create `src/glow.lua`:

@@include 14-glow/src/glow.lua@@

Walking through `Glow:finish`:

1. **Unbind the scene canvas first**, then `push("all")` saves *all* graphics state. (There's a story about this line below.)
2. For each of the three levels, draw the previous image shrunk into canvas `a`. The first time, a **prefilter** caps brightness at 1.6 while keeping the hue. Then blur `a → b` horizontally and `b → a` vertically, twice.
3. Draw the scene to the screen through the **composite** shader. It adds the three blurred levels, plus four finishing touches:
   - **chromatic aberration**: red and blue are read slightly apart toward the edges, like a cheap lens
   - faint **scanlines**, using `sin(screen y)`
   - a **vignette** darkening the corners
   - a whole-screen **flash**

`setBlendMode("replace", "premultiplied")` makes each blur pass *overwrite* its target instead of blending into it.

> **Gotcha: the canvas that wouldn't let go.** The first version of `finish` called `push("all")` *while the scene canvas was still active*, then unbound it inside. `pop()` faithfully restored the saved state, *including the active canvas*. LÖVE then tried to show the frame with a canvas still bound, and crashed: `present cannot be called while a Canvas is active`. The fix is the `lg.setCanvas()` before `push("all")`. The lesson: `push("all")`/`pop()` saves and restores **everything**, including things you might not think of as "state".

> **Gotcha: the white disc.** Bloom adds the blurred image back about **three times over** (the strengths 1.0 + 0.9 + 0.8). That's right for thin lines, whose light is spread thin by the blur. But a *big, soft, bright* area, like an explosion's flash sprite, stays bright after blurring, gets roughly tripled, and clips to a flat white disc. That's why the flash sprites in `fx.lua` are drawn at only 20% alpha, and why the prefilter caps brightness. **Tune effects with the bloom on.**

### Plugging it in

`main.lua` creates the glow and wraps the frame in it:

@@include 14-glow/main.lua | ^function love.load | ^end$ | 4@@

`Game.aberration()` and `Game.flash()` let the game drive the post-processing. Aberration grows with shake trauma, so big hits smear the colours, and the flash is a new `Fx.flash` value that decays quickly (`killShip` sets it to 0.25):

@@include 14-glow/src/game.lua | ^-- Post-processing parameters | ^end$ | 2@@

![The same game with bloom: now it glows](images/ch14.png)

Compare this screenshot with Chapter 12's. Same game, same lines, but now it *glows*.

> **Try it:** In `glow.lua`, set `self.strength = { 2, 0, 0 }`, then `{ 0, 0, 2 }`, to see the tight halo and the wide glow separately. Set `BLUR_PASSES` to 4 for a dreamy look.
