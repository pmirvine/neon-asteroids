<div class="part">Part 2 · Building the game</div>

## 5. The game loop

Every game, from Pong to Elden Ring, runs the same basic cycle many times a second:

```
        ┌──────────────┐
        │  love.load   │   once, at the start
        └──────┬───────┘
               ▼
   ┌──▶ ┌──────────────┐
   │    │ love.update  │   change the world: move things, check input
   │    └──────┬───────┘
   │           ▼
   │    ┌──────────────┐
   │    │  love.draw   │   show the world as it is right now
   │    └──────┬───────┘
   └───────────┘          …repeat ~60 times a second (each pass is a "frame")
```

The key rule: **`update` changes things, `draw` only shows them.** Never move anything inside `draw`.

### dt: time since the last frame

`love.update` receives one argument, **`dt`** ("delta time"): the number of seconds since the previous frame. At 60 frames per second it's about `0.0167`.

Why does this matter? Suppose you move a circle 2 pixels every frame. On a 60 Hz screen that's 120 pixels per second, but on a 144 Hz gaming monitor it's 288. The game would run more than twice as fast on a better screen!

The fix is to think in **pixels per second** and multiply by `dt`:

```lua
x = x + 120 * dt     -- 120 pixels per second, on any computer
```

At 60 fps, `120 * 0.0167 ≈ 2` pixels per frame. At 144 fps it's about `0.83` pixels per frame, but 144 of them still add up to 120 pixels per second.

### Velocity

A speed with a direction is called a **velocity**. In 2D it's two numbers: how fast you move along x (`vx`) and along y (`vy`). Every moving thing in this game has a position `(x, y)` and a velocity `(vx, vy)`, and each frame does:

```lua
x = x + vx * dt
y = y + vy * dt
```

Replace your `main.lua` with this:

@@include 05-game-loop/main.lua@@

![A circle drifting across the screen](images/ch05.png)

A few new things:

- `love.load` runs once at startup, which makes it the place for setup like setting the window title.
- `love.timer.getFPS()` returns the current frames per second.
- `love.keypressed(key)` is called with the key's name (`"escape"`, `"space"`, `"a"`, `"left"`…) when a key goes down. `love.event.quit()` closes the game.
- The two `if` lines **wrap** the circle: leaving the right edge brings it back on the left.

> **Try it:** Make the circle **bounce** instead of wrapping. When `x > W` or `x < 0`, flip the velocity with `vx = -vx`, and do the same for `y`. Then try giving it gravity: add `vy = vy + 300 * dt` at the start of `update`.

## 6. A ship you can fly

Now for the star of the show. An Asteroids ship doesn't move like a car. It **rotates**, and when you **thrust**, it accelerates in the direction it's facing. Let go and it keeps drifting. That floaty momentum is the whole feel of the game.

### Drawing the ship as points

The classic ship is four points joined into an arrowhead. We describe it **around its own centre, pointing right** (along +x):

```lua
local SHIP_SHAPE = { 20, 0, -13, -12, -7, 0, -13, 12 }
--                  nose   left wing  notch  right wing
```

Reading the pairs in order: the **nose** at (20, 0), the **left wing tip** at (−13, −12), a **notch** at (−7, 0) that gives the classic arrowhead cut, and the **right wing tip** at (−13, 12). `polygon` joins them in order and closes the shape back to the nose. Because y points down, "left wing" means the wing that's up the screen when the ship points right.

It's a **flat list** `{x1, y1, x2, y2, ...}` because that's exactly what `love.graphics.polygon("line", points)` wants.

### Angles, radians and a little trigonometry

Angles in maths libraries are measured in **radians**, not degrees. A full turn is `2π` radians (about 6.283), so:

| Degrees | Radians | Direction (remember y points down!) |
|---|---|---|
| 0° | 0 | → right |
| 90° | π/2 ≈ 1.571 | ↓ down |
| 180° | π ≈ 3.142 | ← left |
| 270° | 3π/2 ≈ 4.712, or −π/2 | ↑ up |

To start pointing up, the ship begins at `angle = -math.pi / 2`.

The two functions that turn an angle into a direction are **cosine** and **sine**. For any angle, **`math.cos(angle)`** is how far you move along x and **`math.sin(angle)`** how far along y, if you take one step of length 1 in that direction. So to push the ship forward at `THRUST` pixels per second per second:

```lua
ship.vx = ship.vx + math.cos(ship.angle) * SHIP_THRUST * dt
ship.vy = ship.vy + math.sin(ship.angle) * SHIP_THRUST * dt
```

That's most of the trigonometry in this whole game, and you'll see it over and over: **`cos` for x, `sin` for y**.

### Rotating the shape

To draw the ship at its current angle and position, we rotate every point of the shape, then move it. Rotating a point `(px, py)` by an angle uses a standard formula:

```
rotated x = px · cos(angle) − py · sin(angle)
rotated y = px · sin(angle) + py · cos(angle)
```

You don't need to derive it. Just recognise it when you see it. Here it is as a reusable function:

@@include 06-ship/main.lua | ^-- Rotate a flat list | ^end$@@

### Keyboard input: polling

Chapter 5 used `love.keypressed`, which is an **event**: it fires once when a key goes down. For steering you want to know whether a key *is being held right now*, every frame. That's **polling**:

```lua
if love.keyboard.isDown("left", "a") then
    ship.angle = ship.angle - SHIP_TURN * dt
end
```

`isDown` accepts several keys and returns `true` if *any* of them is held, so arrow keys and WASD both work.

### Drag and a speed limit

Real space has no friction, but a little **drag** makes the ship controllable. Each second the ship should lose the same *fraction* of its speed. The frame-rate-independent way to write that is with `math.exp`:

```lua
local drag = math.exp(-SHIP_DRAG * dt)   -- a number just below 1
ship.vx = ship.vx * drag
ship.vy = ship.vy * drag
```

> **Gotcha:** A tempting shortcut is `ship.vx = ship.vx * 0.98` every frame. It works, but the ship then slows down *faster on faster computers*, because they run more frames per second. Anything that happens "per frame" needs `dt` in it somewhere.

To cap the speed, we measure it with Pythagoras (`speed = √(vx² + vy²)`). If it's too fast, we scale both parts down so the direction stays the same:

```lua
local speed = math.sqrt(ship.vx * ship.vx + ship.vy * ship.vy)
if speed > SHIP_MAX_SPEED then
    ship.vx = ship.vx / speed * SHIP_MAX_SPEED
    ship.vy = ship.vy / speed * SHIP_MAX_SPEED
end
```

### Wrapping with `%`

`%` gives the remainder after division, and it's the neatest way to wrap. `(810) % 800` is `10`, and in Lua `(-5) % 800` is `795`. So one line handles both edges:

```lua
ship.x = (ship.x + ship.vx * dt) % W
```

### The whole ship

Replace `main.lua` with the full chapter checkpoint:

@@include 06-ship/main.lua@@

![Flying the ship, with the thrust flame on](images/ch06.png)

The flame is a little three-point line behind the ship. Its length is random every frame (`love.math.random()` returns a number between 0 and 1), which makes it flicker.

> **Try it:** Change `SHIP_DRAG` to `0` for true, frictionless space, then to `3` for something like driving on ice. Change `SHIP_SHAPE` to design your own ship. Keep the nose pointing right.

## 7. Bullets

Bullets introduce an idea every game relies on: **a list of things that are created and destroyed while the game runs.**

### A list of tables

Each bullet is a small table with a position, a velocity and a remaining **life** in seconds:

@@include 07-bullets/main.lua | ^local function fire | ^end$@@

- `table.insert(list, value)` adds to the end of the list.
- Bullets start at the ship's nose (20 pixels ahead, in the facing direction).
- Bullets **inherit the ship's velocity**. Without this, shooting while flying fast looks as if the bullets are dragging behind.
- `MAX_BULLETS` limits how many can be on screen, which was part of the original game's challenge.

Firing happens in `love.keypressed`, because one press should fire one shot. That's an event, not polling.

### Removing things safely: loop backwards

Each frame, every bullet moves and loses life, and dead bullets are removed:

@@include 07-bullets/main.lua | ^local function updateBullets | ^end$@@

Why does the loop run **backwards** (`#bullets, 1, -1`)? `table.remove(list, i)` shifts every later item down by one. Going forwards, removing item 3 moves item 4 into slot 3, and the loop moves straight on to slot 4, *skipping* the old item 4. Going backwards, the shifted items have already been visited, so nothing is skipped.

> **Gotcha:** Whenever you remove items from a list you're looping over, loop backwards. It's one of the most common bugs in game code.

### Tidying up with functions

`love.update` was getting long, so this chapter moves the ship code into `updateShip(dt)` and adds `updateBullets(dt)`. `love.update` just calls them in order. Both are `local function`s written *above* `love.update`, because a local function must be defined before the code that uses it.

@@include 07-bullets/main.lua@@

![Bullets streaking from the ship](images/ch07.png)

Each bullet is drawn as a short line pointing back along its velocity (`b.x - b.vx * 0.022`), so fast bullets look like streaks.

> **Try it:** Make a "shotgun" that fires three bullets at once, at `ship.angle - 0.15`, `ship.angle` and `ship.angle + 0.15`. You'll need to give `fire` an angle parameter.

## 8. Asteroids

### Making random rocks

Every asteroid gets its own lumpy shape. The trick is to walk around a circle, placing 10–14 points, each at a slightly random distance from the centre:

@@include 08-asteroids/main.lua | ^local function newAsteroid | ^end$@@

- **`rnd`** is a local shortcut for `love.math.random`. Called with no arguments it gives a decimal between 0 and 1. With two whole numbers, `rnd(10, 14)`, it gives a whole number in that range, both ends included.
- `TAU` is `2π`, a full turn. `i / n * TAU` spaces the points evenly around the circle, and `(rnd() - 0.5) * 0.5` nudges each one a little.
- `0.7 + rnd() * 0.35` makes each point between 70% and 105% of the radius. That's what makes the rock lumpy.
- Each asteroid also gets a random direction, speed and **spin**. Smaller rocks spin faster.

### Data tables

The sizes are described in one table, not scattered through the code:

@@include 08-asteroids/main.lua | ^local ASTEROID = | ^}$@@

`ASTEROID[3]` is "everything about large asteroids". When Chapter 9 adds scores, and later chapters add explosion sizes and sounds, they'll just be new fields in this table. Keeping tuning numbers together makes a game much easier to balance.

### Drawing across the edges

When a big asteroid drifts halfway off the right edge, the part that's gone should appear on the left. We draw it **twice**: once where it is, and once shifted by the screen width.

@@include 08-asteroids/main.lua | ^local function drawWrapped | ^end$@@

Two new ideas here:

- **`love.graphics.push()` / `translate(dx, dy)` / `pop()`**: `translate` shifts everything drawn afterwards. `push` saves the current drawing state and `pop` restores it, so the shift only affects the code in between.
- **Passing a function as an argument:** `drawWrapped` doesn't know *how* to draw an asteroid or a ship. You give it the drawing function (`fn`) and the thing to draw (`obj`), and it calls `fn(obj)` up to four times. This works because functions are values in Lua.

@@include 08-asteroids/main.lua@@

![Four large asteroids drifting](images/ch08.png)

> **Try it:** Change the `for _ = 1, 4` in `love.load` to spawn a mix of sizes: `newAsteroid(rnd(1, 3), ...)`. Try `rnd(6, 8)` points instead of `rnd(10, 14)` for chunkier rocks.

## 9. Collisions, lives and waves

Time to make it a game.

### Circle collisions

Asteroids are lumpy, but for collisions we pretend everything is a **circle**. Two circles overlap when the distance between their centres is less than their radii added together:

```
    distance < radiusA + radiusB    →  hit!
```

Distance comes from Pythagoras again: `√(dx² + dy²)`. It's quick to compute and forgiving to play against. We shrink each asteroid's radius a little (`a.radius * 0.9`), because players feel cheated by hits that "didn't touch", never by near misses.

### Distance on a wrapping screen

On a wrapping screen, an asteroid at `x = 790` and a bullet at `x = 5` are only 15 pixels apart, across the edge. `wrapDelta` finds the shortest way around:

@@include 09-collisions/main.lua | ^-- On a wrapping screen | ^end$ | 2@@

### Checking every bullet against every asteroid

@@include 09-collisions/main.lua | ^local function collide | ^end$@@

Both loops run backwards because both can remove items. After a hit, `break` stops checking the dead bullet against other asteroids.

### Splitting

When an asteroid is destroyed, a size 3 becomes two size 2s, and a size 2 becomes two size 1s:

@@include 09-collisions/main.lua | ^local function destroyAsteroid | ^end$@@

Each child keeps half of its parent's velocity, so the pieces carry on in roughly the same direction.

### Lives, respawning and invulnerability

When the ship is hit, `killShip` sets `ship.alive = false` and starts a `respawnTimer`. `love.update` counts it down. A new ship spawns when it reaches zero, or it's game over if there are no lives left. New ships are **invulnerable** for 2.5 seconds (`SPAWN_INVULN`) so you don't die the moment you appear, and they blink while it lasts:

```lua
if s.invuln > 0 and math.floor(s.invuln * 10) % 2 == 0 then return end
```

`math.floor(s.invuln * 10)` counts down in tenths of a second, and `% 2 == 0` is true every other tenth. The ship skips drawing on those frames, so it blinks five times a second.

### Waves and fonts

When the last asteroid is destroyed, `waveDelay` gives a two-second breather, then `spawnWave` creates one more large asteroid than the previous wave (capped at 11). It picks spots at least 200 pixels from the ship.

Text uses fonts. `love.graphics.newFont(40)` creates a font at size 40, and `setFont` chooses which one `print` uses.

> **Gotcha:** Create fonts, images and sounds **once** (in `love.load`), never inside `love.draw`. Creating a font every frame makes the game slower and slower. The first version of this game did exactly that.

`love.graphics.printf(text, x, y, width, "center")` centres text within a box `width` pixels wide, which is how "GAME OVER" sits in the middle.

### The complete game

@@include 09-collisions/main.lua@@

![A complete (if plain) game of Asteroids](images/ch09.png)

**This is a real game.** Everything from here on is about structure, then *juice*: the glow, the sparks, the shake and the sound that turn a plain game into one that feels great. Play it for a while and notice how flat it feels. By Chapter 18 you won't recognise it.

> **Try it:** Add an extra life every 5,000 points. Keep a `nextLife` variable, and whenever `score >= nextLife`, add a life and raise `nextLife` by 5,000. Then show a message for two seconds when you get one.
