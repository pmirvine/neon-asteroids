--[[ game.lua — Neon Asteroids gameplay: modes, entities, collisions, drawing.

The world is a fixed 1280 x 720 virtual screen that wraps at every edge;
main.lua scales it to the window. Modes: "title" (attract mode), "play",
"gameover".
]]

local Starfield = require "lib.starfield"
local Neon = require "src.neon"
local Fx = require "src.fx"
local Sfx = require "src.sfx"

local lg = love.graphics
local rnd = love.math.random
local TAU = math.pi * 2

local Game = {}
local W, H = 1280, 720
Game.W, Game.H = W, H

-- ============================================================
-- TUNING
-- ============================================================
local SHIP_RADIUS = 13
local SHIP_TURN = 4.6 -- radians per second
local SHIP_THRUST = 430
local SHIP_DRAG = 0.5 -- velocity decay rate per second
local SHIP_MAX_SPEED = 540
local SHIP_SHAPE = { 20, 0, -13, -12, -7, 0, -13, 12 }
local SHIP_COLOR = { 0.25, 0.95, 1 }

local FIRE_INTERVAL = 0.14 -- hold fire for autofire at this rate
local BULLET_SPEED = 780
local BULLET_LIFE = 0.8
local MAX_PLAYER_BULLETS = 8
local BULLET_COLOR = { 1, 0.95, 0.5 }

local START_LIVES = 3
local MAX_LIVES = 9
local EXTRA_LIFE_EVERY = 10000
local RESPAWN_DELAY = 2.2
local SPAWN_INVULN = 2.5
local SLOWMO_TIME = 0.9 -- slow motion after the ship explodes
local HITSTOP_TIME = 0.09

local ASTEROID = {
    [3] = { radius = 54, score = 20, speedLo = 35, speedHi = 75, fx = 3.2, shake = 0.3, sound = "boom_large" },
    [2] = { radius = 29, score = 50, speedLo = 55, speedHi = 115, fx = 2.0, shake = 0, sound = "boom_medium" },
    [1] = { radius = 15, score = 100, speedLo = 75, speedHi = 165, fx = 1.2, shake = 0, sound = "boom_small" },
}
local WAVE_HUES = { 0.88, 0.07, 0.76, 0.14, 0.97, 0.30, 0.62 }

local S = {} -- all mutable game state
local field -- starfield background

-- ============================================================
-- HELPERS
-- ============================================================
local function hsv(h, s, v)
    h = (h % 1) * 6
    local i = math.floor(h)
    local f = h - i
    local p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
    if i == 0 then return v, t, p
    elseif i == 1 then return q, v, p
    elseif i == 2 then return p, v, t
    elseif i == 3 then return p, q, v
    elseif i == 4 then return t, p, v
    end
    return v, p, q
end

local function wrapDelta(d, size)
    if d > size / 2 then return d - size end
    if d < -size / 2 then return d + size end
    return d
end

-- Distance on the wrapping playfield, plus the shortest dx, dy from a to b.
local function wrappedDist(ax, ay, bx, by)
    local dx, dy = wrapDelta(bx - ax, W), wrapDelta(by - ay, H)
    return math.sqrt(dx * dx + dy * dy), dx, dy
end

local function pan(x)
    return x / W * 2 - 1
end

-- Rotate + translate a flat local shape into `out` (world space).
local function transform(shape, x, y, angle, out, scale)
    scale = scale or 1
    local c, s = math.cos(angle) * scale, math.sin(angle) * scale
    for i = 1, #shape, 2 do
        local px, py = shape[i], shape[i + 1]
        out[i] = x + px * c - py * s
        out[i + 1] = y + px * s + py * c
    end
    return out
end

-- Draw fn(obj) once, plus shifted copies when obj straddles a screen edge.
local function drawWrapped(x, y, r, fn, obj)
    local x2 = (x < r and W) or (x > W - r and -W) or nil
    local y2 = (y < r and H) or (y > H - r and -H) or nil
    fn(obj)
    if x2 then lg.push(); lg.translate(x2, 0); fn(obj); lg.pop() end
    if y2 then lg.push(); lg.translate(0, y2); fn(obj); lg.pop() end
    if x2 and y2 then lg.push(); lg.translate(x2, y2); fn(obj); lg.pop() end
end

local function loadHighScore()
    local ok, data = pcall(love.filesystem.read, "highscore.txt")
    return ok and tonumber(data) or 0
end

local function saveHighScore(score)
    pcall(love.filesystem.write, "highscore.txt", tostring(score))
end

-- Text with LÖVE's built-in font, one cached Font object per size.
-- (Chapter 17 swaps this for a glowing vector font with the same arguments.)
local fonts = {}
local function drawText(str, x, y, size, r, g, b, a, align)
    local px = math.floor(size * 1.4)
    fonts[px] = fonts[px] or lg.newFont(px)
    lg.setFont(fonts[px])
    lg.setColor(r, g, b, a or 1)
    if align == "center" then
        lg.printf(str, x - W, y, W * 2, "center")
    elseif align == "right" then
        lg.printf(str, x - W, y, W, "right")
    else
        lg.print(str, x, y)
    end
end

-- ============================================================
-- ENTITIES
-- ============================================================
local function newAsteroid(size, x, y)
    local def = ASTEROID[size]
    local n = rnd(10, 14)
    local verts = {}
    for i = 0, n - 1 do
        local ang = (i + (rnd() - 0.5) * 0.5) / n * TAU
        local rad = def.radius * (0.7 + rnd() * 0.35)
        verts[#verts + 1] = math.cos(ang) * rad
        verts[#verts + 1] = math.sin(ang) * rad
    end
    local ang = rnd() * TAU
    local speed = (def.speedLo + rnd() * (def.speedHi - def.speedLo)) * (1 + (S.wave - 1) * 0.05)
    local r, g, b = hsv(S.hue + (3 - size) * 0.035 + (rnd() - 0.5) * 0.03, 0.78, 1)
    return {
        x = x, y = y,
        vx = math.cos(ang) * speed, vy = math.sin(ang) * speed,
        size = size, radius = def.radius,
        angle = rnd() * TAU, spin = (rnd() - 0.5) * (0.8 + (3 - size) * 0.6),
        verts = verts, pts = {},
        r = r, g = g, b = b,
    }
end

local function asteroidPoints(a)
    return transform(a.verts, a.x, a.y, a.angle, a.pts)
end

local function newShip()
    return {
        x = W / 2, y = H / 2, vx = 0, vy = 0, angle = -math.pi / 2,
        alive = true, invuln = SPAWN_INVULN,
        fireTimer = 0, thrusting = false, pts = {},
    }
end

local function shipPoints(s)
    return transform(SHIP_SHAPE, s.x, s.y, s.angle, s.pts)
end

local function isClear(x, y, margin)
    for _, a in ipairs(S.asteroids) do
        if wrappedDist(x, y, a.x, a.y) < a.radius + margin then return false end
    end
    return true
end

local function popup(text, x, y, r, g, b, size)
    S.popups[#S.popups + 1] = { text = text, x = x, y = y, life = 1.1, max = 1.1, r = r, g = g, b = b, size = size or 14 }
end

local function addScore(points, x, y, r, g, b)
    if S.mode ~= "play" then return end
    S.score = S.score + points
    popup(tostring(points), x, y, r, g, b)
    while S.score >= S.nextLife do
        S.nextLife = S.nextLife + EXTRA_LIFE_EVERY
        S.lives = math.min(S.lives + 1, MAX_LIVES)
        Sfx.play("extra_life")
        S.banner = { text = "EXTRA SHIP", t = 0 }
    end
end

-- ============================================================
-- DESTRUCTION
-- ============================================================
local function destroyAsteroid(i, scored, split, quiet, hitVx, hitVy)
    local a = table.remove(S.asteroids, i)
    local def = ASTEROID[a.size]
    if scored then addScore(def.score, a.x, a.y, a.r, a.g, a.b) end

    Fx.explosion(a.x, a.y, def.fx, a.r, a.g, a.b, a.vx, a.vy)
    Fx.debris(asteroidPoints(a), a.x, a.y, a.vx * 0.5, a.vy * 0.5, 40 + 20 * a.size, 1.0 + 0.3 * a.size, a.r, a.g, a.b)
    if not quiet then
        if def.shake > 0 then Fx.shake(def.shake) end
        Sfx.play(def.sound, pan(a.x), 0.92 + rnd() * 0.16)
    end

    if split and a.size > 1 then
        for _ = 1, 2 do
            local child = newAsteroid(a.size - 1,
                a.x + (rnd() - 0.5) * a.radius * 0.6,
                a.y + (rnd() - 0.5) * a.radius * 0.6)
            child.vx = child.vx + a.vx * 0.5 + (hitVx or 0) * 0.04
            child.vy = child.vy + a.vy * 0.5 + (hitVy or 0) * 0.04
            S.asteroids[#S.asteroids + 1] = child
        end
    end
end

local function killShip()
    local s = S.ship
    s.alive = false
    Sfx.loop("thrust", false)

    local c = SHIP_COLOR
    Fx.debris(shipPoints(s), s.x, s.y, s.vx * 0.4, s.vy * 0.4, 70, 2.4, c[1], c[2], c[3])
    Fx.explosion(s.x, s.y, 4.5, c[1], c[2], c[3], s.vx, s.vy)
    Fx.burst(s.x, s.y, 60, 150, 560, 0.4, 1.4, 1, 0.55, 0.2) -- orange fireball
    Fx.ring(s.x, s.y, 280, 1.0, 1, 1, 1, 4)
    Fx.ring(s.x, s.y, 180, 0.8, c[1], c[2], c[3], 3)
    Fx.glowFlash(s.x, s.y, 160, 0.5, 1, 0.55, 0.25)
    Fx.shake(0.8)
    Fx.flash = 0.25
    S.hitstop = HITSTOP_TIME
    S.slowmo = SLOWMO_TIME
    Sfx.play("player_die", pan(s.x))

    S.lives = S.lives - 1
    S.respawnTimer = RESPAWN_DELAY
end

-- ============================================================
-- PLAYER ACTIONS
-- ============================================================
local function fire()
    local s = S.ship
    if #S.bullets >= MAX_PLAYER_BULLETS then return end

    local c, sn = math.cos(s.angle), math.sin(s.angle)
    local x, y = s.x + c * 20, s.y + sn * 20
    S.bullets[#S.bullets + 1] = {
        x = x, y = y,
        vx = c * BULLET_SPEED + s.vx, vy = sn * BULLET_SPEED + s.vy,
        life = BULLET_LIFE,
    }
    Fx.burst(x, y, 4, 40, 160, 0.06, 0.16, BULLET_COLOR[1], BULLET_COLOR[2], BULLET_COLOR[3], s.vx, s.vy)
    s.fireTimer = FIRE_INTERVAL
    Sfx.play("fire", pan(x), 0.95 + rnd() * 0.1)
end

-- ============================================================
-- WAVES AND MODES
-- ============================================================
local function spawnWave()
    S.hue = WAVE_HUES[(S.wave - 1) % #WAVE_HUES + 1]
    local count = math.min(3 + S.wave, 11)
    local cx, cy = W / 2, H / 2
    if S.ship and S.ship.alive then cx, cy = S.ship.x, S.ship.y end
    for _ = 1, count do
        local x, y
        for _ = 1, 30 do
            x, y = rnd() * W, rnd() * H
            if wrappedDist(x, y, cx, cy) > 280 then break end
        end
        S.asteroids[#S.asteroids + 1] = newAsteroid(3, x, y)
    end
    S.waveTime = 0
    S.banner = { text = "WAVE " .. S.wave, t = 0 }
end

local function resetState()
    S.asteroids, S.bullets, S.popups = {}, {}, {}
    S.banner, S.waveDelay = nil, nil
    S.hitstop, S.slowmo = 0, 0
    S.modeTime = 0
    love.audio.stop()
    Fx.reset()
end

local function enterTitle()
    resetState()
    S.mode = "title"
    S.wave, S.hue = 1, WAVE_HUES[1]
    S.ship = nil
    for _ = 1, 7 do
        S.asteroids[#S.asteroids + 1] = newAsteroid(rnd(1, 3), rnd() * W, rnd() * H)
    end
    S.attractTimer = 2.5
end

local function startGame()
    resetState()
    S.mode = "play"
    S.score, S.lives, S.wave = 0, START_LIVES, 1
    S.nextLife = EXTRA_LIFE_EVERY
    S.ship = newShip()
    S.respawnTimer = 0
    S.beatTimer, S.beatIndex = 1, 0
    spawnWave()
    Sfx.play("start")
end

local function enterGameOver()
    S.mode = "gameover"
    S.modeTime = 0
    S.newHigh = S.score > S.high
    if S.newHigh then
        S.high = S.score
        saveHighScore(S.high)
    end
    Sfx.stopLoops()
    Sfx.play("game_over")
end

-- ============================================================
-- INPUT
-- ============================================================
local function controls()
    local kb = love.keyboard.isDown
    local left, right = kb("left", "a"), kb("right", "d")
    local thrust, firing = kb("up", "w"), kb("space")
    return left, right, thrust, firing
end

-- ============================================================
-- UPDATE
-- ============================================================
local function updateShip(dt)
    local s = S.ship
    local left, right, thrust, firing = controls()
    if left then s.angle = s.angle - SHIP_TURN * dt end
    if right then s.angle = s.angle + SHIP_TURN * dt end

    local c, sn = math.cos(s.angle), math.sin(s.angle)
    s.thrusting = thrust
    if thrust then
        s.vx = s.vx + c * SHIP_THRUST * dt
        s.vy = s.vy + sn * SHIP_THRUST * dt
        local ex, ey = s.x - c * 9, s.y - sn * 9
        for _ = 1, 3 do
            local ang = s.angle + math.pi + (rnd() - 0.5) * 0.5
            local speed = 180 + rnd() * 160
            local k = rnd()
            Fx.spark(ex, ey, math.cos(ang) * speed + s.vx, math.sin(ang) * speed + s.vy,
                0.18 + rnd() * 0.2, 1, 0.35 + 0.35 * k, 0.6 - 0.4 * k, 2, 3)
        end
    end
    Sfx.loop("thrust", thrust)

    local drag = math.exp(-SHIP_DRAG * dt)
    s.vx, s.vy = s.vx * drag, s.vy * drag
    local speed = math.sqrt(s.vx * s.vx + s.vy * s.vy)
    if speed > SHIP_MAX_SPEED then
        s.vx, s.vy = s.vx / speed * SHIP_MAX_SPEED, s.vy / speed * SHIP_MAX_SPEED
    end
    s.x = (s.x + s.vx * dt) % W
    s.y = (s.y + s.vy * dt) % H
    field:scroll(-s.vx * dt * 0.06, -s.vy * dt * 0.06)

    s.invuln = math.max(0, s.invuln - dt)
    s.fireTimer = s.fireTimer - dt
    if firing and s.fireTimer <= 0 then fire() end
end

local function moveAsteroids(dt)
    for _, a in ipairs(S.asteroids) do
        a.x = (a.x + a.vx * dt) % W
        a.y = (a.y + a.vy * dt) % H
        a.angle = a.angle + a.spin * dt
    end
end

local function updateBullets(dt)
    for i = #S.bullets, 1, -1 do
        local b = S.bullets[i]
        b.x = (b.x + b.vx * dt) % W
        b.y = (b.y + b.vy * dt) % H
        b.life = b.life - dt
        if b.life <= 0 then table.remove(S.bullets, i) end
    end
end

local function collide()
    local s = S.ship
    local shipAlive = s and s.alive

    for i = #S.bullets, 1, -1 do
        local b = S.bullets[i]
        for j = #S.asteroids, 1, -1 do
            local a = S.asteroids[j]
            if wrappedDist(b.x, b.y, a.x, a.y) < a.radius * 0.9 + 2 then
                destroyAsteroid(j, true, true, false, b.vx, b.vy)
                table.remove(S.bullets, i)
                break
            end
        end
    end

    if shipAlive and s.invuln <= 0 then
        for j = #S.asteroids, 1, -1 do
            local a = S.asteroids[j]
            if wrappedDist(s.x, s.y, a.x, a.y) < a.radius * 0.85 + SHIP_RADIUS then
                destroyAsteroid(j, true, true, false, s.vx, s.vy)
                killShip()
                break
            end
        end
    end
end

local function updatePlay(dt)
    S.waveTime = S.waveTime + dt
    local s = S.ship

    if s.alive then
        updateShip(dt)
    else
        S.respawnTimer = S.respawnTimer - dt
        if S.lives <= 0 then
            if S.respawnTimer <= -0.5 then enterGameOver() return end
        elseif S.respawnTimer <= 0 and (isClear(W / 2, H / 2, 150) or S.respawnTimer < -3) then
            S.ship = newShip()
            local c = SHIP_COLOR
            Fx.implode(W / 2, H / 2, 150, 60, 0.35, c[1], c[2], c[3])
            Fx.ring(W / 2, H / 2, 90, 0.5, c[1], c[2], c[3], 2)
            Sfx.play("warp_in")
        end
    end

    updateBullets(dt)
    moveAsteroids(dt)
    collide()

    -- wave cleared: short breather, then the next wave
    if #S.asteroids == 0 and not S.waveDelay then S.waveDelay = 2.5 end
    if S.waveDelay then
        S.waveDelay = S.waveDelay - dt
        if S.waveDelay <= 0 then
            S.waveDelay = nil
            S.wave = S.wave + 1
            spawnWave()
            Sfx.play("wave_start")
        end
    end

    -- the classic heartbeat, quickening as the wave drags on
    if S.ship.alive and #S.asteroids > 0 then
        S.beatTimer = S.beatTimer - dt
        if S.beatTimer <= 0 then
            S.beatIndex = 1 - S.beatIndex
            Sfx.play(S.beatIndex == 0 and "beat1" or "beat2")
            S.beatTimer = math.max(0.3, 1.0 - S.waveTime * 0.012)
        end
    end
end

local function updateAttract(dt)
    moveAsteroids(dt)
    if S.mode ~= "title" then return end
    S.attractTimer = S.attractTimer - dt
    if S.attractTimer <= 0 and #S.asteroids > 0 then
        S.attractTimer = 1.5 + rnd() * 2
        destroyAsteroid(rnd(#S.asteroids), false, #S.asteroids < 12, true)
    end
    if #S.asteroids < 6 then
        S.asteroids[#S.asteroids + 1] = newAsteroid(3, rnd() < 0.5 and 0 or W / 2, rnd() * H)
    end
end

-- ============================================================
-- DRAWING
-- ============================================================
local function drawAsteroid(a)
    Neon.lines(a.pts, a.r, a.g, a.b, 1, 2, true)
end

local flame = {}
local function drawShip(s)
    local c = SHIP_COLOR
    if s.invuln > 0 then
        local pulse = 0.5 + 0.5 * math.sin(S.time * 12)
        Neon.circle(s.x, s.y, 27 + pulse * 2, c[1], c[2], c[3], 0.25 + 0.25 * pulse, 1.4, 48)
    end
    Neon.lines(s.pts, c[1], c[2], c[3], 1, 2.2, true)
    if s.thrusting then
        local len = 10 + rnd() * 14
        transform({ -9, -5, -9 - len, 0, -9, 5 }, s.x, s.y, s.angle, flame)
        Neon.lines(flame, 1, 0.45, 0.25, 0.9, 1.8, false)
    end
end

local function drawBullet(b)
    local c = BULLET_COLOR
    Neon.lines({ b.x, b.y, b.x - b.vx * 0.022, b.y - b.vy * 0.022 }, c[1], c[2], c[3], 1, 2, false)
    Neon.dot(b.x, b.y, 1.8, c[1], c[2], c[3], 1)
end

local miniShip = {}
local function drawHud()
    drawText(tostring(S.score), 32, 26, 28, 1, 0.95, 0.85, 1, "left")
    drawText("HI " .. S.high, W / 2, 30, 16, 0.65, 0.7, 1, 0.8, "center")
    local r, g, b = hsv(S.hue, 0.7, 1)
    drawText("WAVE " .. S.wave, W - 32, 30, 16, r, g, b, 0.9, "right")

    local c = SHIP_COLOR
    for i = 1, S.lives do
        transform(SHIP_SHAPE, 44 + (i - 1) * 26, 82, -math.pi / 2, miniShip, 0.6)
        Neon.lines(miniShip, c[1], c[2], c[3], 0.9, 1.5, true)
    end
end

local function drawPopups()
    for _, p in ipairs(S.popups) do
        drawText(p.text, p.x, p.y, p.size, p.r, p.g, p.b, p.life / p.max, "center")
    end
end

local function drawBanner()
    local b = S.banner
    if not b then return end
    local a = math.min(1, b.t * 4, (2.2 - b.t) * 2)
    local r, g, bl = hsv(S.hue, 0.6, 1)
    drawText(b.text, W / 2, H / 2 - 110, 40, r, g, bl, a, "center", 3)
end

local function drawTitle()
    local pulse = 0.8 + 0.2 * math.sin(S.time * 2.4)
    local r1, g1, b1 = hsv(0.5 + math.sin(S.time * 0.3) * 0.05, 0.8, 1)
    local r2, g2, b2 = hsv(0.88 + math.sin(S.time * 0.3) * 0.05, 0.8, 1)
    drawText("NEON", W / 2, 120, 72, r1, g1, b1, pulse, "center", 3)
    drawText("ASTEROIDS", W / 2, 220, 72, r2, g2, b2, pulse, "center", 3)

    if math.floor(S.time * 1.6) % 2 == 0 then
        drawText("PRESS SPACE TO START", W / 2, 370, 22, 1, 1, 1, 1, "center")
    end

    local lines = {
        "ROTATE        LEFT RIGHT / A D",
        "THRUST        UP / W",
        "FIRE          SPACE",
        "MUTE M    FULLSCREEN F11",
    }
    for i, text in ipairs(lines) do
        drawText(text, W / 2, 450 + (i - 1) * 28, 13, 0.6, 0.75, 1, 0.75, "center")
    end
    drawText("HIGH SCORE " .. S.high, W / 2, H - 50, 16, 1, 0.85, 0.4, 0.9, "center")
end

local function drawGameOver()
    drawText("GAME OVER", W / 2, H / 2 - 110, 60, 1, 0.25, 0.45, 1, "center", 3)
    drawText("SCORE " .. S.score, W / 2, H / 2 - 10, 26, 1, 0.95, 0.85, 1, "center")
    if S.newHigh and math.floor(S.time * 3) % 2 == 0 then
        drawText("NEW HIGH SCORE", W / 2, H / 2 + 40, 20, 1, 0.85, 0.3, 1, "center")
    end
    if S.modeTime > 1.5 then
        drawText("SPACE TO PLAY AGAIN    ESC FOR TITLE", W / 2, H / 2 + 110, 16, 0.7, 0.8, 1, 0.9, "center")
    end
end

-- ============================================================
-- PUBLIC API
-- ============================================================
function Game.load()
    Sfx.load()
    field = Starfield.new(W, H, {
        velocity = { -4, 2 },
        layers = 3,
        density = 0.9,
        background = { 0.012, 0.008, 0.03 },
    })
    S.time = 0
    S.high = loadHighScore()
    enterTitle()
end

function Game.update(dt)
    S.time = S.time + dt

    Fx.updateShake(dt)
    field:update(dt)

    if S.hitstop > 0 then
        S.hitstop = S.hitstop - dt
        return
    end
    if S.slowmo > 0 then
        S.slowmo = math.max(0, S.slowmo - dt)
        dt = dt * (1 - 0.7 * S.slowmo / SLOWMO_TIME)
    end

    S.modeTime = S.modeTime + dt
    if S.mode == "play" then
        updatePlay(dt)
    else
        updateAttract(dt)
    end

    Fx.update(dt)
    for i = #S.popups, 1, -1 do
        local p = S.popups[i]
        p.y = p.y - 30 * dt
        p.life = p.life - dt
        if p.life <= 0 then table.remove(S.popups, i) end
    end
    if S.banner then
        S.banner.t = S.banner.t + dt
        if S.banner.t > 2.2 then S.banner = nil end
    end
end

function Game.draw()
    lg.setBlendMode("alpha")
    field:draw()
    -- dim the stars a touch so the neon stays the star of the show
    lg.setColor(0.012, 0.008, 0.03, 0.3)
    lg.rectangle("fill", 0, 0, W, H)

    lg.setBlendMode("add")
    lg.setLineStyle("smooth")
    lg.setLineJoin("bevel")

    lg.push()
    lg.translate(W / 2 + Fx.shakeX, H / 2 + Fx.shakeY)
    lg.rotate(Fx.shakeAngle)
    lg.translate(-W / 2, -H / 2)

    Fx.draw()
    for _, a in ipairs(S.asteroids) do
        asteroidPoints(a)
        drawWrapped(a.x, a.y, a.radius + 8, drawAsteroid, a)
    end
    for _, b in ipairs(S.bullets) do drawBullet(b) end
    local s = S.ship
    if s and s.alive and S.mode == "play" then
        shipPoints(s)
        drawWrapped(s.x, s.y, 32, drawShip, s)
    end
    drawPopups()
    lg.pop()

    if S.mode == "title" then
        drawTitle()
    else
        drawHud()
        drawBanner()
        if S.mode == "gameover" then drawGameOver() end
    end

    lg.setBlendMode("alpha")
    lg.setColor(1, 1, 1, 1)
end

-- Post-processing parameters for the glow composite.
function Game.aberration()
    return 0.0015 + Fx.trauma * Fx.trauma * 0.005
end

function Game.flash()
    return Fx.flash * 0.5
end

function Game.keypressed(key, isrepeat)
    if isrepeat then return end
    if key == "m" then
        Sfx.toggleMute()
        return
    end

    if S.mode == "title" then
        if key == "space" or key == "return" or key == "kpenter" then
            startGame()
        elseif key == "escape" then
            love.event.quit()
        end
    elseif S.mode == "gameover" then
        if S.modeTime > 1.5 and (key == "space" or key == "return" or key == "kpenter") then
            startGame()
        elseif key == "escape" then
            enterTitle()
        end
    elseif key == "escape" then
        enterTitle()
    end
end

return Game
