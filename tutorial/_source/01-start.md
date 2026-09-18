# Learn LÖVE by Building Neon Asteroids

![The finished game: glowing vector asteroids, a twinkling starfield and a smart-bomb shockwave](images/ch18.png)

This tutorial takes you from *"I've never used Lua"* to a finished, polished arcade game. It has glowing neon graphics, particle explosions, screen shake, a twinkling starfield and sound effects that are generated entirely in code.

You'll build it one step at a time. Every chapter adds something you can run and see, and every chapter ends with a working **checkpoint** you can compare against your own code.

**You'll need:**

- A Windows, macOS or Linux computer you're comfortable using.
- Visual Studio Code (VS Code).
- A little coding experience in *any* language. If you know what a variable, an `if` and a loop are, you're ready. No Lua or LÖVE experience needed.

**By the end you'll know how to:**

- write Lua, the small, fast language LÖVE games are written in
- use the game loop, input, drawing, timing and randomness
- move things with velocity, rotation and a little friendly trigonometry
- detect collisions and organise a growing game into files and screens
- make a game *feel* good: additive glow, particles, screen shake and slow motion
- write GPU shaders for a bloom effect
- synthesize retro sound effects from raw numbers
- debug, test and share your game

<div class="part">Part 1 · Getting started</div>

## 1. Welcome

### What is LÖVE?

[LÖVE](https://love2d.org) (often written *Love2D*) is a free, open-source framework for making 2D games. You write your game in **Lua**, and LÖVE provides everything around it:

- a window to draw in, plus fast graphics
- keyboard, mouse and gamepad input
- sound, files, maths helpers and timing

It doesn't give you an editor with drag-and-drop scenes like Unity or Godot. You write code, run it, and see the result. That makes it one of the best ways to understand how games actually work, because nothing is hidden. It's also used for real commercial games: the hit card game *Balatro* was made with LÖVE.

This tutorial uses **LÖVE 11.5**.

### What you'll build

*Neon Asteroids* is a modern take on the 1979 arcade classic:

- a ship that rotates, thrusts and drifts with momentum, on a screen that wraps at every edge
- asteroids that split into smaller pieces when shot
- flying saucers that shoot back, hyperspace jumps, and a *Defender*-style smart bomb
- glowing neon lines, particle explosions, and screen shake for the really big explosions
- a twinkling arcade starfield
- chunky retro sound effects, all synthesized in code, with no audio files

There are **no image or sound files** anywhere in the game. Everything you see and hear is made by code you'll write.

### How to use this tutorial

Work through the chapters in order. Each one explains *why* before *how*, then shows the code.

The project you downloaded contains a `tutorial/` folder. For every chapter that has code, there is a matching checkpoint folder: `tutorial/06-ship`, `tutorial/09-collisions`, and so on. Each one is a complete, runnable snapshot of the game at the end of that chapter. If you get stuck, or your version behaves differently, run the checkpoint and compare. (Chapter 18's checkpoint is the finished game itself, at the top of the project.)

You'll see a few kinds of boxes along the way:

> **Tip:** handy extra information.

> **Gotcha:** a mistake almost everyone makes, and how to avoid it.

> **Try it:** a small experiment. Doing these is the fastest way to learn.

Early chapters show *all* of the code. From Chapter 10 onwards the game gets big (over 900 lines by the end), so chapters show the new and changed parts and point you to the checkpoint for the full listing.

## 2. Install LÖVE and set up VS Code

### Install LÖVE

Go to [love2d.org](https://love2d.org) and download LÖVE 11.5 for your system.

**Windows**

1. Run the 64-bit installer and accept the defaults. LÖVE installs to `C:\Program Files\LOVE`.
2. Add LÖVE to your `PATH` so you can run it from any terminal:
   - Press the Windows key and type **environment**. Choose **Edit the system environment variables**, then **Environment Variables…**.
   - Under *User variables*, select **Path**, click **Edit…**, then **New**, and paste `C:\Program Files\LOVE`.
   - Click OK on every window.
3. Open a **new** terminal (PowerShell) and check it works:

```powershell
love --version
```

You should see something like `LOVE 11.5 (Mysterious Mysteries)`.

> **Tip:** Windows has two LÖVE programs. `love.exe` runs your game quietly. `lovec.exe` (the **c** is for *console*) also shows a console window where anything your code `print`s appears. Use `lovec` while developing. You'll see why in Chapter 4.

**macOS**

1. Download the macOS zip, unzip it, and drag `love.app` into **Applications**.
2. The first time, right-click `love.app` and choose **Open** (macOS asks you to confirm apps from the internet).
3. So you can type `love` in the Terminal, add this line to the file `~/.zshrc`, then open a new Terminal window:

```bash
alias love="/Applications/love.app/Contents/MacOS/love"
```

**Linux**

Use the AppImage from the website, or your package manager (for example `sudo apt install love`). Check you have version 11.x with `love --version`.

### Set up VS Code

1. Install [VS Code](https://code.visualstudio.com) if you haven't already.
2. Make a folder for your game, for example `my-asteroids`, and open it in VS Code with **File → Open Folder…**.
3. Open the Extensions view (`Ctrl+Shift+X`, or `Cmd+Shift+X` on macOS). Search for **Lua** and install the one by **sumneko** (it's called *Lua*, published by *sumneko*). It gives you colouring, autocomplete and error squiggles.
4. Teach it about LÖVE. Open the Command Palette (`Ctrl+Shift+P`), run **Lua: Open Addon Manager**, search for **LÖVE**, and click **Enable**. Now VS Code knows every `love.*` function and shows its documentation as you type.

If the Addon Manager isn't available in your version, create a file called `.vscode/settings.json` in your project with this content instead. It stops VS Code from underlining `love` as an unknown variable:

```json
{
    "Lua.runtime.version": "LuaJIT",
    "Lua.diagnostics.globals": ["love"]
}
```

### Run your game with one key

Typing `love .` in the terminal works (the `.` means "the game in this folder"), but it's nicer to press a key. Create a file called `.vscode/tasks.json`:

```json
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "Run LÖVE",
            "type": "shell",
            "command": "lovec .",
            "group": { "kind": "build", "isDefault": true },
            "problemMatcher": []
        }
    ]
}
```

Now **`Ctrl+Shift+B`** (`Cmd+Shift+B` on macOS) runs your game. On macOS and Linux, change `lovec .` to `love .`.

> **Tip:** The checkpoints can run from the project root too. In a terminal opened in the downloaded project, `love tutorial/06-ship` runs the Chapter 6 checkpoint.

## 3. Hello, LÖVE

Create a file called `main.lua` in your project folder and type this in:

@@include 03-hello/main.lua@@

Press `Ctrl+Shift+B` (or type `love .` in the terminal). A window opens with your message in it. Close it with the window's close button.

![Hello, LÖVE](images/ch03.png)

### What just happened?

When LÖVE starts, it looks for a file called **`main.lua`** in the folder you gave it and runs it. Your file *defines a function* called `love.draw`, but it never calls it. **LÖVE calls it for you**, about 60 times every second, and shows whatever it draws.

Functions that LÖVE calls for you are called **callbacks**. You'll meet the important ones soon:

| Callback | When LÖVE calls it |
|---|---|
| `love.load()` | once, when the game starts |
| `love.update(dt)` | every frame, before drawing. Move things here. |
| `love.draw()` | every frame. Draw things here. |
| `love.keypressed(key)` | whenever a key is pressed |

You never have to define all of them. LÖVE only calls the ones that exist.

### Coordinates

`love.graphics.print("Hello, LÖVE!", 350, 290)` draws text with its top-left corner at **x = 350, y = 290**. The origin **(0, 0) is the top-left corner** of the window. **x grows to the right and y grows downwards**, which is the opposite of the graphs you drew at school. The default window is 800 × 600 pixels.

```
(0,0) ────────── x ─────────▶ (800,0)
  │
  │        (350,290) Hello, LÖVE!
  y
  │
  ▼
(0,600)
```

### Colour

Add a line *before* the print:

```lua
function love.draw()
    love.graphics.setColor(1, 0.4, 0.85)
    love.graphics.print("Hello, LÖVE!", 350, 290)
end
```

`setColor(red, green, blue)` takes numbers from **0 to 1**, so `(1, 0.4, 0.85)` is a hot pink. There's an optional fourth number, **alpha**, for transparency (1 = solid, 0 = invisible). The colour stays set for everything drawn afterwards until you change it.

> **Gotcha:** Older LÖVE tutorials (before version 11) use colours from 0 to 255. If you copy `setColor(255, 0, 0)` from an old tutorial, LÖVE 11 treats every value above 1 as 1, and you'll get white.

### Your first error

Delete the closing `)` from the `print` line and run the game. Instead of your window, LÖVE shows a blue **error screen** with something like:

```
Error
Syntax error: main.lua:6: ')' expected (to close '(' at line 5) near 'end'
```

The error screen is your friend. It tells you the **file** (`main.lua`), the **line** where Lua gave up (`6`), and what went wrong: it was still waiting for the `)` that closes the `(` opened on line 5. Put the bracket back, and remember this screen. You'll see it again, and Chapter 19 is all about reading it.

> **Try it:** Draw a second line of text somewhere else, in a different colour. Then add `love.graphics.rectangle("line", 100, 100, 200, 50)` and work out where the rectangle will appear *before* you run it.

## 4. Lua in a hurry

Lua is a small language, and you can learn most of it in an afternoon. This chapter covers everything the game uses. The checkpoint `tutorial/04-lua-playground` contains every example below in one runnable file. Run it, change things, and run it again.

![The Lua playground running](images/ch04.png)

### Comments and printing

```lua
-- Two dashes start a comment. Lua ignores the rest of the line.
--[[ This is a comment
     spanning several lines. ]]

print("Hello")   -- prints to the console, not the game window
```

`print` writes to the console. On Windows you only see it if you ran the game with **`lovec`**. On macOS and Linux it appears in the terminal you launched from.

### Variables and `local`

```lua
local playerName = "Ada"
local lives = 3
local speed = 2.5
local alive = true
```

A variable is a name for a value. Always put **`local`** in front the first time you create one. Without it, Lua creates a **global** variable that every file in your game can see and accidentally change. With `local`, the variable belongs to the file or function it was created in.

Lua has only a few kinds of value: **numbers** (`3`, `2.5`, `-1`), **strings** (text, in `"double"` or `'single'` quotes), **booleans** (`true`/`false`), **`nil`** (meaning "nothing"), **tables** and **functions**. There's no separate integer type: `3` and `3.0` are the same number.

### Maths

```lua
lives = lives - 1           -- no  lives -= 1  or  lives++  in Lua!
local half = 7 / 2          -- 3.5   (division always gives a decimal)
local rest = 7 % 2          -- 1     (remainder)
local big = 2 ^ 10          -- 1024  (power)
local root = math.sqrt(16)  -- 4
local down = math.floor(3.7) -- 3
```

The `math` library has everything else: `math.sin`, `math.cos`, `math.pi`, `math.min`, `math.max`, `math.abs` and more.

> **Gotcha:** `+=`, `-=`, `++` and `--` (as maths) don't exist in Lua. `--` starts a comment! Writing `x += 1` is a syntax error, and the whole file refuses to load.

### Strings

```lua
local name = "Ada"
local greeting = "Hello, " .. name .. "!"   -- .. joins strings
local line = "Lives: " .. 3                 -- numbers join fine
local shout = string.upper("hi")            -- "HI"
local n = tonumber("42")                    -- the number 42
local s = tostring(true)                    -- the string "true"
```

`..` (two dots) glues strings together. Joining a number works, but joining `nil` or a boolean is an error, so wrap those in `tostring(...)`.

### Comparisons and logic

```lua
if lives > 2 then
    print("Plenty of lives left")
elseif lives > 0 then
    print("Careful now")
else
    print("Game over")
end
```

Comparisons are `==`, `<`, `>`, `<=`, `>=`, and **`~=`** for "not equal" (not `!=`). Combine them with the words `and`, `or` and `not`. Every `if` ends with `end`, and so do loops and functions.

> **Gotcha:** In Lua, **only `false` and `nil` count as false**. The number `0` and the empty string `""` both count as *true*, unlike in JavaScript or Python.

Two handy idioms use `and`/`or`:

```lua
local size = userSize or 14             -- "userSize, or 14 if it's nil"
local label = alive and "yes" or "no"   -- a tiny if/else in one line
```

### Tables: Lua's only data structure

Lua has one way to group data: the **table**. It does the jobs of arrays, lists, dictionaries and objects in other languages.

**As a list:**

```lua
local colors = { "red", "green", "blue" }
print(colors[1])            -- "red"   ← lists start at 1, not 0!
print(#colors)              -- 3       ← # gives the length
table.insert(colors, "magenta")   -- add to the end
table.remove(colors, 2)           -- remove "green"; later items shift down

for i, color in ipairs(colors) do
    print(i, color)          -- 1 red, 2 blue, 3 magenta
end
```

> **Gotcha:** Lists start at index **1**. `colors[0]` is `nil`, not the first item. If you know other languages this will trip you up at least once. It's normal.

**As a record** (named fields):

```lua
local ship = { x = 400, y = 300, name = "Viper" }
ship.x = ship.x + 10         -- dot to read or write a field
ship.shield = 100            -- add a new field any time
print(ship.name)             -- "Viper"
print(ship.missing)          -- nil: reading a missing field isn't an error
```

`ship.x` is shorthand for `ship["x"]`. The bracket form is useful when the key is in a variable or isn't a word, as in `ASTEROID[3]`. The game uses records for every ship, asteroid, bullet and particle.

To loop over *all* fields of a record, use `pairs` instead of `ipairs`. The order isn't guaranteed.

```lua
for key, value in pairs(ship) do print(key, value) end
```

### Loops

```lua
for n = 1, 10 do print(n) end          -- 1, 2, … 10 (both ends included)
for n = 10, 1, -1 do print(n) end      -- counting down, step -1
for i = 1, #list, 2 do print(list[i]) end   -- every second item

while lives > 0 do lives = lives - 1 end
```

`break` leaves a loop early.

### Functions

```lua
local function add(a, b)
    return a + b
end

local function minMax(a, b)          -- functions can return several values
    if a < b then return a, b end
    return b, a
end

local lo, hi = minMax(9, 4)          -- lo = 4, hi = 9
```

Functions are values, just like numbers. You can store them in variables and tables, and pass them to other functions. The game does this in Chapter 8.

> **Gotcha:** A `local function` only exists from the line where it's written *downwards*. If function A calls function B, **B must be written above A** in the file. Otherwise Lua looks for a *global* B, finds nothing, and you get `attempt to call a nil value`. This exact bug broke the first version of this very game (see Chapter 19).

### `nil`: the value of nothing

Any variable or field that was never set is `nil`. Using `nil` where a value is expected is the most common runtime error you'll see:

```
attempt to perform arithmetic on a nil value (field 'speed')
attempt to index a nil value (local 'ship')
```

The first means you did maths with something that doesn't exist, usually a typo in a field name. The second means you wrote `ship.x` while `ship` itself is `nil`.

### Modules: splitting code across files

A Lua file can `return` a value, usually a table of functions. Another file loads it with `require`:

```lua
-- src/greet.lua
local Greet = {}

function Greet.hello(name)
    return "Hello, " .. name
end

return Greet
```

```lua
-- main.lua
local Greet = require "src.greet"   -- loads src/greet.lua (dots become folders)
print(Greet.hello("Ada"))
```

`require` runs each file only once and remembers what it returned, so every file that requires `src.greet` gets the same table.

### The colon `:`

You'll see calls like `field:update(dt)`. The colon is shorthand: **`field:update(dt)` means `field.update(field, dt)`**. It passes the table itself as the first argument, which is how Lua does objects. You'll only *use* colons in this tutorial (for LÖVE objects like canvases, sounds and the starfield), not write classes with them.

### If you already know Python or JavaScript

| Idea | Lua | Python | JavaScript |
|---|---|---|---|
| local variable | `local x = 1` | `x = 1` | `let x = 1` |
| not equal | `a ~= b` | `a != b` | `a !== b` |
| logic | `and or not` | `and or not` | `&& \|\| !` |
| join strings | `a .. b` | `a + b` | `a + b` |
| length | `#list` | `len(list)` | `list.length` |
| first item | `list[1]` | `list[0]` | `list[0]` |
| nothing | `nil` | `None` | `null`/`undefined` |
| block end | `end` | indentation | `}` |
| add one | `x = x + 1` | `x += 1` | `x++` |

> **Try it:** In the playground, add a function `clamp(value, lo, hi)` that returns `value` limited to the range `lo`–`hi`, and `say` a few results. (The game uses the same idea to cap the ship's speed.)
