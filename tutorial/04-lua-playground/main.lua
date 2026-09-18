-- Chapter 4: a Lua playground.
-- Each example calls say(), which adds a line to the window (and prints it to
-- the console if you started the game with lovec). Change things and re-run!

local lines = {}

local function say(text)
    table.insert(lines, tostring(text))
    print(text)
end

-- 1. Variables: a name for a value. `local` keeps it private to this file.
local playerName = "Ada"
local lives = 3
local speed = 2.5
local alive = true
say("Name: " .. playerName .. ", lives: " .. lives .. ", speed: " .. speed)
say("Alive? " .. tostring(alive))

-- 2. Maths. Lua has no  lives -= 1  shortcut: write it out in full.
lives = lives - 1
say("After a crash: " .. lives .. " lives")
say("7 / 2 = " .. 7 / 2 .. "    7 % 2 = " .. 7 % 2 .. "    2 ^ 10 = " .. 2 ^ 10)

-- 3. Making decisions
if lives > 2 then
    say("Plenty of lives left")
elseif lives > 0 then
    say("Careful now")
else
    say("Game over")
end

-- 4. Tables as lists. Lists start at index 1, not 0!
local colors = { "red", "green", "blue" }
say("First color: " .. colors[1] .. ", how many: " .. #colors)
table.insert(colors, "magenta")
for i, color in ipairs(colors) do
    say("  color " .. i .. " is " .. color)
end

-- 5. Tables as records (named fields)
local ship = { x = 400, y = 300, name = "Viper" }
ship.x = ship.x + 10
say(ship.name .. " is at " .. ship.x .. ", " .. ship.y)

-- 6. Counting loops
local total = 0
for n = 1, 10 do
    total = total + n
end
say("1 + 2 + ... + 10 = " .. total)

-- 7. Functions. They can return more than one value.
local function minMax(a, b)
    if a < b then
        return a, b
    end
    return b, a
end
local lo, hi = minMax(9, 4)
say("min is " .. lo .. ", max is " .. hi)

-- 8. nil means "nothing here". ~= means "not equal".
local shield = ship.shield
say("ship.shield is " .. tostring(shield))
if shield ~= nil then
    say("this line never appears")
end

function love.draw()
    for i, text in ipairs(lines) do
        love.graphics.print(text, 20, 20 + (i - 1) * 20)
    end
end
