## 15. Sound from scratch

The game has no audio files. Every zap, crunch and wail is **calculated**, sample by sample, when the game starts. It's easier than it sounds, and it's how the 1980s arcade machines that inspired this game made their sounds too.

### What is digital sound?

A speaker makes sound by moving back and forth. Digital audio describes that movement as a long list of numbers called **samples**, each between **−1 and 1** (the speaker's position), played back very quickly. The game uses **44,100 samples per second** (the *sample rate*, the same as a CD).

- **Pitch** is how fast the wave repeats. A wave that goes up and down 440 times a second is the note A. Faster means higher.
- **Volume** is how big the wave is. Multiplying every sample by 0.5 makes it quieter.

### Waveforms

The simplest waveform to make in code is a **square wave**: +1 for half of each cycle, −1 for the other half. It has the buzzy, electronic sound of old game consoles. To make one, keep a **phase** that counts cycles, adding `frequency / RATE` every sample:

```lua
phase = phase + frequency / RATE
local sample = (phase % 1) < 0.5 and 1 or -1   -- first half of each cycle: +1
```

Because the phase *accumulates*, you can change the frequency on every sample without clicks. That's how **sweeps** work: a laser is just a square wave whose pitch falls quickly.

**Noise** is random numbers: `rng:random() * 2 - 1`. Noise is the basis of every explosion, engine and hiss.

An **envelope** shapes the volume over time. A quick rise (the *attack*) then a fade, often `(1 - progress) ^ 2`, turns a steady buzz into a "pew".

### The Williams explosion

The arcade game *Defender* (Williams Electronics, 1981) had famously crunchy, powerful explosions. The trick is **sample-and-hold noise**: pick a random value and *hold* it for a while before picking the next one. Holding briefly sounds like a hiss, and holding for longer sounds like a low rumble. Sweep the hold rate **downward** as the sound fades, and the explosion "falls" from a crack into a rumble. Add some **bit-crushing** (rounding samples to a few levels, like the old 8-bit sound chips) for grit.

### Turning numbers into sound in LÖVE

```lua
local data = love.sound.newSoundData(sampleCount, 44100, 16, 1)  -- 16-bit, mono
data:setSample(i, value)                  -- i counts from 0; value is -1..1
local source = love.audio.newSource(data, "static")
source:play()
```

A **Source** is something that can play. One Source can only play once at a time, so for sounds that overlap (like rapid fire) we make a small **pool** of Sources per effect and use whichever one is free. If they're all busy, the oldest is cut off and reused.

### The Sfx module

Create `src/sfx.lua`. It's long, but each effect is a short recipe, and the file reads from top to bottom: helpers, then effects, then playback.

@@include 15-sound/src/sfx.lua@@

A few details worth pointing out:

- **Seamless loops.** The engine hum and saucer warbles loop forever. A loop clicks if the wave doesn't end where it began. `warble` uses a whole number of wobble (LFO) cycles and a whole number of tone cycles in its 0.5 seconds, so the end joins the start perfectly.
- **Stereo panning.** Every sound is placed left or right by where it happens on screen. `setPosition` puts a Source in 3D space around the listener. Setting the distance model to `"none"` means position only *pans* and never makes sounds quieter. (Positioning only works on **mono** sounds, which is why everything is made with 1 channel.)
- **Pitch variation.** `Sfx.play("fire", pan, 0.95 + rnd() * 0.1)` plays each shot at a slightly different pitch. It's a tiny change, but hearing the identical sound 200 times is surprisingly tiring.
- **Failing gracefully.** If audio can't start (no sound device), `pcall` catches the error and `Sfx.enabled` stays false, so every call quietly does nothing.

### Hooking up the sounds

Add `local Sfx = require "src.sfx"` to `game.lua`, call `Sfx.load()` in `Game.load`, and add a helper that turns an x position into a pan value from −1 to 1:

@@include 15-sound/src/game.lua | ^local function pan | ^end$@@

Then play sounds where things happen:

| Where | Call |
|---|---|
| `fire` | `Sfx.play("fire", pan(x), 0.95 + rnd() * 0.1)` |
| `destroyAsteroid` (unless `quiet`) | `Sfx.play(def.sound, pan(a.x), 0.92 + rnd() * 0.16)` with a new `sound` field in `ASTEROID` |
| `killShip` | `Sfx.loop("thrust", false)` and `Sfx.play("player_die", pan(s.x))` |
| `updateShip` | `Sfx.loop("thrust", thrust)` starts or stops the engine loop |
| `startGame`, new wave, respawn | `"start"`, `"wave_start"`, `"warp_in"` |
| `enterGameOver` | `Sfx.stopLoops()` then `Sfx.play("game_over")` |
| `addScore`, extra life | `Sfx.play("extra_life")` |
| `Game.keypressed` | `M` calls `Sfx.toggleMute()` |

Finally, the original Asteroids' unforgettable **heartbeat**: two low thumps that alternate faster and faster the longer a wave lasts. It goes at the end of `updatePlay`:

@@include 15-sound/src/game.lua | ^    -- the classic heartbeat | ^    end$@@

The sound bank also builds saucer and smart-bomb sounds that won't be used until Chapter 18.

> **Tip:** Want to hear an effect on its own, or tweak it quickly? Put `Sfx.play("boom_large")` inside `love.keypressed` for a test key, change the numbers in its recipe, and re-run.

> **Try it:** Make the laser more "Star Wars": in the `fire` recipe, change `2400 * math.exp(-t * 16)` to `3500 * math.exp(-t * 30)`. Make explosions longer by changing the `1.5` in `boom_large`.

The game sounds different now, but looks the same as Chapter 14.

## 16. A twinkling starfield

The background comes from the [retro-starfield-starter-kit](https://github.com/pmirvine/retro-starfield-starter-kit), a small MIT-licensed library that recreates the twinkling star field of 1979's *Galaxian*. It even uses the real colours that Galaxian's hardware could produce. Using it shows how to work with **someone else's library**.

### Adding the library

Copy `lib/starfield.lua` from the checkpoint into a `lib` folder in your project (keeping libraries you didn't write separate from `src/` is a good habit) and require it:

```lua
local Starfield = require "lib.starfield"
```

A library usually documents itself at the top of the file. Open `lib/starfield.lua` and read the first 40 lines. The author explains how to use it before any code appears.

### Objects with colons

`Starfield.new(...)` returns an **object**: a table with data and methods. You call its methods with a colon, `field:update(dt)`, which (as Chapter 4 explained) is short for `field.update(field, dt)`. The object passes itself along so the method knows which starfield to update.

@@include 16-starfield/src/game.lua | ^function Game.load | ^end$@@

- `layers = 3` gives three depths of stars. Far layers are dimmer, smaller and move less. That's **parallax**, and it gives a sense of depth.
- `velocity = { -4, 2 }` makes the whole field drift slowly.
- `background` fills the space behind the stars with a deep navy.

### How the twinkle works

Each star gets its own blink **period** and **phase** when it's created:

@@include 16-starfield/lib/starfield.lua | ^function Starfield:_make_star | ^end$@@

and it's drawn only for the first part of each period:

```lua
if not (twinkling and (t + s[5]) % s[4] > s[4] * TWINKLE_DUTY) then
    -- draw this star
end
```

`(t + phase) % period` counts from 0 up to `period` and starts again. The star is visible while that count is under 55% of the period (`TWINKLE_DUTY`). With every star on a slightly different period and phase, the field shimmers instead of blinking in unison. The library draws all the stars with a **SpriteBatch**, LÖVE's fast way to draw many copies of one image in a single call.

### Plugging it in

Three changes to `game.lua`:

1. `field:update(dt)` in `Game.update`, next to `Fx.updateShake`, so the stars keep twinkling during hitstop.
2. In `updateShip`, scroll the stars *against* the ship's movement for parallax: `field:scroll(-s.vx * dt * 0.06, -s.vy * dt * 0.06)`.
3. At the start of `Game.draw`, draw the field and then a translucent rectangle over it, so the stars don't compete with the neon:

```lua
lg.setBlendMode("alpha")
field:draw()
-- dim the stars a touch so the neon stays the star of the show
lg.setColor(0.012, 0.008, 0.03, 0.3)
lg.rectangle("fill", 0, 0, W, H)
```

The stars are drawn *inside* the glow canvas, so the bloom gives each one a faint halo.

![Twinkling Galaxian stars behind the neon](images/ch16.png)

> **Try it:** Change `palette` to `"white"` in the options for a more modern look, or set `twinkle_speed = 0` to stop the twinkling and see how much life it adds.

## 17. A vector font

The game's text still uses LÖVE's standard font, which looks out of place next to the glowing lines. Arcade vector games drew their letters with the same beam that drew the ships, as a few straight strokes each. We'll do the same, and every letter will glow for free.

### Designing glyphs

Each character (a **glyph**) is drawn on a tiny **4 × 6 grid** (x across, y down), as one or more **strokes**, each a list of points:

```
 A = "0,6 0,2 2,0 4,2 4,6|0,3.5 4,3.5"

     0   1   2   3   4
  0          ●                 stroke 1: up the left side,
  1        ╱   ╲                          over the peak,
  2      ●       ●                        down the right side
  3.5    ●───────●             stroke 2:  the crossbar
  6      ●       ●
```

`|` separates strokes. The whole alphabet is a table of these strings:

@@include 17-vector-font/src/neon.lua | ^local GLYPH_SRC | ^}$@@

### Parsing the strings once

At startup, each string is turned into lists of numbers using Lua's **pattern matching**. `gmatch` loops over every match of a pattern in a string:

@@include 17-vector-font/src/neon.lua | ^local GLYPHS = | ^end$@@

- `"[^|]+"` means "one or more characters that aren't `|`", so it yields each stroke in turn.
- `"(-?[%d%.]+),(-?[%d%.]+)"` captures two numbers separated by a comma. `%d` is a digit, `%.` a literal dot, and the brackets `( )` mark the parts to capture. So `x` and `y` come out as separate strings.

Doing this once, at startup, means drawing text never has to parse anything.

### Drawing text

@@include 17-vector-font/src/neon.lua | ^function Neon.textWidth | ^end$ | 2@@

- `size` is the height of a capital letter in pixels, so each grid unit is `size / 6` pixels.
- Each character takes 4 units plus `spacing` (default 2), which is how `textWidth` can work out the width without drawing anything. That's what makes centring and right-aligning possible.
- `buf` is one table reused for every stroke. The loop `for k = #buf, n + 1, -1 do buf[k] = nil end` trims off leftover points from a longer previous stroke.

### Swapping it in

Chapter 10 routed all text through `drawText(str, x, y, size, r, g, b, a, align)`, and `Neon.text` takes the same arguments (plus optional spacing). So the swap is: delete the `drawText` function and its `fonts` table, then replace every `drawText(` with `Neon.text(`. VS Code's **Find and Replace** (`Ctrl+H`) does it in one go.

![The glowing vector font on the title screen](images/ch17.png)

> **Try it:** Add glyphs for `#`, `*` and `%` to `GLYPH_SRC`, then use them somewhere. Try making the letters italic by adding `- pts[k + 1] * s * 0.2` to the x coordinate in `Neon.text`.

<div class="part">Part 5 · Finishing the game</div>

## 18. Saucers, hyperspace and smart bombs

The final chapter of new features. Its checkpoint is the **finished game** at the top of the project (`main.lua`, `conf.lua`, `src/`, `lib/`). Open `src/game.lua` there and follow along.

### Flying saucers

Saucers are described with a data table, just like asteroids:

@@include ../src/game.lua | ^local UFO = | ^}$@@

@@include ../src/game.lua | ^local function spawnUfo | ^end$ | 2@@

- The **small saucer becomes more likely** as the wave and score go up: `0.1 + (S.wave - 1) * 0.12 + S.score / 50000`, capped at 80%.
- Saucers fly across the screen once, changing vertical direction every second or so, and are removed when they leave the far side.
- **Aiming:** `math.atan2(dy, dx)` converts a direction (dx, dy) into an angle. It's the opposite of `cos`/`sin`. The small saucer aims at the ship, plus a random error that shrinks as you get better. The big saucer just fires at random.
- The saucer's warbling sound loop is panned to follow it across the screen.

Enemy bullets share the `S.bullets` list, marked with `enemy = true`. Collisions now cover every pair that matters:

@@include ../src/game.lua | ^local function collide | ^end$@@

### Hyperspace

Press ↓ (or S or Shift) to vanish and reappear somewhere random. The trick is picking a *safe* somewhere: try up to 40 random spots, and use the first one that isn't near an asteroid:

@@include ../src/game.lua | ^local function hyperspace | ^end$@@

### The smart bomb

A nod to *Defender*. Press B for an expanding shockwave that destroys everything it touches. It's also the game's biggest explosion, so it gets the biggest shake and a screen flash:

@@include ../src/game.lua | ^local function smartBomb | ^end$@@

@@include ../src/game.lua | ^local function updateBomb | ^end$@@

The shockwave is a circle whose radius `b.r` grows 1,500 pixels per second. Anything whose distance from the centre is less than `b.r` plus its own radius has been hit. The first version destroyed every asteroid outright, and a single bomb could clear a whole wave in a second. That was too strong, so now **large asteroids shatter** instead: their pieces are flung outward and tagged `child.bomb = b` so the same shockwave doesn't hit them again.

### Pause, gamepads and focus

**Pause** (P or Esc) stops updating the game and pauses all sound. `love.audio.pause()` pauses every playing Source and returns a list of them, so unpausing can resume exactly those:

@@include ../src/game.lua | ^local function togglePause | ^end$@@

**Gamepads** work alongside the keyboard. LÖVE maps most controllers to a standard Xbox-style layout, so button names like `"a"` and `"dpleft"` work on any pad:

@@include ../src/game.lua | ^local function gamepad | ^end$ | 2@@

In `main.lua`, `love.gamepadpressed` forwards button presses, and `love.focus` **auto-pauses** when the player switches to another window. It's a small courtesy that players really notice.

![The finished game](images/ch18.png)

**Congratulations: you've built the whole game.** Run `love .` at the top of the project and play the finished version.

## 19. Debugging and testing

Every programmer spends a lot of time working out why something doesn't work. Here's how to get good at it in LÖVE.

### Reading the error screen

```
Error

src/game.lua:212: attempt to perform arithmetic on a nil value (field 'radius')

Traceback

src/game.lua:212: in function 'destroyAsteroid'
src/game.lua:587: in function 'collide'
src/game.lua:668: in function 'updatePlay'
...
```

- The **first line** says where it happened (file:line) and what went wrong.
- The **traceback** is the chain of calls that led there, most recent first. Here, `updatePlay` called `collide`, which called `destroyAsteroid`, which crashed. The bug is often a few steps up the chain, where the bad value came from.

### The errors you'll see most

| Message | What it usually means |
|---|---|
| `attempt to call a nil value (global 'foo')` | `foo` doesn't exist *here*: a typo, or a `local function foo` defined **below** this line |
| `attempt to index a nil value (local 'ship')` | you wrote `ship.x` while `ship` is `nil` |
| `attempt to perform arithmetic on a nil value (field 'speed')` | a maths operation on a missing field, often a misspelled name |
| `attempt to compare number with nil` | same idea, in `<` or `>` |
| `attempt to concatenate a nil value` | `"Score: " .. score` while `score` is `nil`. Use `tostring(score)` |
| `'end' expected (to close 'function' at line 40)` | a missing `end`. Line 40 is where the unclosed block *starts* |
| `unexpected symbol near '='` | often `+=`, which Lua doesn't have |

### A real case study

The very first version of this game was generated by a small AI model running locally. It *looked* plausible, but it didn't run at all. Its bugs make a great checklist, because they're exactly what beginners (and AIs) get wrong:

```lua
player.vx += math.cos(math.rad(player.angle)) * PLAYER_THRUST * dt   -- no += in Lua
if key == love.keys.space then                                       -- no love.keys: keys are strings, "space"
function love.keyPressed(key)                                        -- wrong case: LÖVE calls love.keypressed
love.graphics.font = love.graphics.newFont(28)                       -- not how fonts work, and made every frame
love.graphics.fillRect(0, 0, SCREEN.width, SCREEN.height)            -- not a LÖVE function: rectangle("fill", ...)
```

It also called `local function`s from code written *above* them, stored asteroid sizes as numbers but looked them up by name (`"large"`), and wrote particles into a table that didn't exist. None of these are hard to fix once you know how to read the errors, and callback names are case-sensitive, so check them against the [LÖVE wiki](https://love2d.org/wiki).

> **Gotcha:** When LÖVE doesn't call your callback at all (nothing happens, and there's no error), check the spelling and capitalisation: `love.keypressed`, `love.mousepressed`, `love.gamepadpressed`. A misspelled callback is just a function nobody calls.

### print debugging

The simplest tool is still the best one: `print` values and watch the console (run with `lovec` on Windows):

```lua
print("asteroids:", #S.asteroids, "bullets:", #S.bullets)
```

Printing every frame floods the console, so print when something *happens*, or only every 60th frame.

### An on-screen debug overlay

Add a toggle to `main.lua` that draws useful numbers on top of everything:

```lua
local showDebug = false

-- in love.keypressed, before Game.keypressed:
if key == "f3" then showDebug = not showDebug return end

-- at the very end of love.draw, after glow:finish(...):
if showDebug then
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("FPS " .. love.timer.getFPS(), 10, 10)
    love.graphics.print("Lua memory " .. math.floor(collectgarbage("count")) .. " KB", 10, 30)
end
```

If the memory number climbs forever, something is creating objects and never letting them go, like fonts made every frame.

### Testing without playing

While building this game, every checkpoint was tested by a small separate LÖVE project. It loads the game's `main.lua`, replaces `love.keyboard.isDown` with a function that "holds" keys on a timer, runs a few thousand frames, and saves screenshots with `love.graphics.captureScreenshot`. It also replaces `love.errorhandler` so an error prints and exits instead of showing the blue screen. That's how the canvas bug in Chapter 14 was caught and confirmed fixed.

You don't need this for a small game, but it's good to know that game code can be tested automatically too.

## 20. Sharing your game

### A .love file

A `.love` file is just a **zip of your game folder**, renamed, with `main.lua` at the top level of the zip (not inside a subfolder). Anyone with LÖVE installed can run it.

On Windows, in PowerShell, from your project folder:

```powershell
Compress-Archive -Path main.lua, conf.lua, src, lib -DestinationPath NeonAsteroids.zip
Rename-Item NeonAsteroids.zip NeonAsteroids.love
love NeonAsteroids.love
```

On macOS or Linux:

```bash
zip -9 -r NeonAsteroids.love main.lua conf.lua src lib
love NeonAsteroids.love
```

List only what the game needs. Leave out the `tutorial` and `backup` folders and anything else that's just for you.

### A Windows .exe

For friends who don't have LÖVE, you can **fuse** your `.love` onto the end of `love.exe` to make one program:

```powershell
cmd /c 'copy /b "C:\Program Files\LOVE\love.exe"+NeonAsteroids.love NeonAsteroids.exe'
```

Put `NeonAsteroids.exe` in a folder together with the `.dll` files from `C:\Program Files\LOVE` (`love.dll`, `lua51.dll`, `SDL2.dll`, `OpenAL32.dll`, `mpg123.dll`, `msvcp120.dll`, `msvcr120.dll`) and LÖVE's `license.txt`, then zip that folder up and share it. A fused game saves its files to `%APPDATA%\neon-asteroids` instead of the `LOVE` subfolder.

The [LÖVE wiki's *Game Distribution* page](https://love2d.org/wiki/Game_Distribution) covers macOS apps, Linux and more. There are also community projects that run LÖVE games in a web browser, but they have limitations (shaders and audio can behave differently), so test carefully.

## 21. Where to go next

You now know the core of 2D game programming: the game loop, input, movement, collisions, state, and a toolbox of effects that most games use. Some ideas to take it further, roughly from easiest to hardest:

- **Combo multiplier:** destroying asteroids quickly one after another raises a score multiplier shown in the HUD.
- **Shield:** hold a key to raise a shield that drains an energy bar.
- **Power-ups:** destroyed asteroids occasionally drop a glowing pickup (triple shot, rapid fire, extra bomb).
- **A new enemy:** a mine that drifts toward the ship, or a "splitter" asteroid that breaks into four.
- **Two players** on one keyboard, co-op or versus.
- **Settings screen:** volume, bloom strength, screen shake on/off. Accessibility matters, and some players get motion sick from shake.
- **Touch controls** for tablets, using `love.touchpressed`.

### Resources

- **[LÖVE wiki](https://love2d.org/wiki)**: the official reference for every function. Keep it open while you code.
- **[Sheepolution's *How to LÖVE*](https://sheepolution.com/learn)**: a friendly, thorough beginner book, great for going deeper on the basics.
- **[Programming in Lua](https://www.lua.org/pil/contents.html)**: the free online first edition, written by Lua's creator. It's older but still accurate for the Lua that LÖVE uses.
- **[awesome-love2d](https://github.com/love2d-community/awesome-love2d)**: a big list of libraries (cameras, tweening, collision, UI…).
- **[retro-starfield-starter-kit](https://github.com/pmirvine/retro-starfield-starter-kit)**: the starfield library from Chapter 16, plus more example games.
- The **LÖVE Discord and forums**, linked from love2d.org, for when you're stuck.

## Appendix A: LÖVE functions used in this game

| Function | What it does |
|---|---|
| `love.load / update(dt) / draw` | the main callbacks (Chapters 3 and 5) |
| `love.keypressed(key, scancode, isrepeat)` | a key went down |
| `love.keyboard.isDown(...)` | is any of these keys held right now? |
| `love.gamepadpressed`, `love.joystick.getJoysticks()` | gamepad input |
| `love.resize(w, h)`, `love.focus(f)` | window resized / focus gained or lost |
| `love.graphics.setColor(r, g, b, a)` | colour for what's drawn next (0–1) |
| `love.graphics.line / polygon / circle / rectangle` | draw shapes (`"line"` or `"fill"`) |
| `love.graphics.print / printf` | draw text (`printf` can wrap and align) |
| `love.graphics.newFont(size)`, `setFont` | create and select fonts |
| `love.graphics.setLineWidth / setLineStyle / setLineJoin` | how lines look |
| `love.graphics.setBlendMode("alpha" / "add" / "replace")` | how new pixels combine with old ones |
| `love.graphics.push / pop / translate / rotate / scale / origin` | move, turn and scale everything drawn after |
| `love.graphics.setScissor(x, y, w, h)` | only draw inside a rectangle |
| `love.graphics.newCanvas`, `setCanvas`, `clear` | draw into off-screen images |
| `love.graphics.newShader`, `setShader`, `shader:send` | GPU effects |
| `love.image.newImageData`, `love.graphics.newImage` | create images in code |
| `love.math.random`, `love.math.noise` | random numbers and smooth noise |
| `love.sound.newSoundData`, `love.audio.newSource` | create and play sounds |
| `love.audio.pause / play / stop / setVolume` | control all sounds at once |
| `love.filesystem.read / write` | save and load files |
| `love.window.setFullscreen`, `love.window.setTitle` | window control |
| `love.timer.getFPS()` | frames per second |
| `love.event.quit()` | close the game |

## Appendix B: Glossary

- **Additive blending**: drawing mode where colours add together, like light. Overlaps get brighter.
- **Attract mode**: the self-playing demo behind an arcade game's title screen.
- **Bloom**: the glow around bright light, made by blurring bright parts of the image and adding them back.
- **Callback**: a function you write that LÖVE calls for you at the right time.
- **Canvas**: an off-screen image you can draw into.
- **dt (delta time)**: seconds since the previous frame. Multiply speeds by it.
- **Easing**: a curve that makes motion start or stop smoothly instead of linearly.
- **Frame**: one pass of update-then-draw, about 1/60 of a second.
- **Garbage collector**: the part of Lua that frees tables you're no longer using.
- **GLSL**: the language shaders are written in.
- **Hitstop**: a very short freeze on impact that makes hits feel solid.
- **HSV**: describing colours by hue, saturation and value (brightness).
- **Letterboxing**: black bars that keep a game's shape when the window is a different shape.
- **Local**: a variable visible only inside its file or function.
- **Module**: a Lua file that returns a table, loaded with `require`.
- **Parallax**: distant things moving less than near things, giving a sense of depth.
- **Particle**: a tiny, short-lived visual object. Many together make sparks, smoke and fire.
- **Radian**: the maths unit for angles. A full turn is 2π.
- **Sample / sample rate**: one number in a digital sound wave / how many samples per second.
- **Shader**: a small program run on the graphics card for every pixel.
- **State machine**: a set of modes plus clear rules for moving between them.
- **Table**: Lua's only data structure, used as both lists and records.
- **Trauma**: a 0–1 value that drives screen shake. Its square gives the shake amount.
- **Velocity**: speed with a direction, stored as `(vx, vy)`.
