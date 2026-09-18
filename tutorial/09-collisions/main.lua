-- Chapter 9: collisions, score, lives and waves — a complete (plain) Asteroids.
-- Left/Right rotate, Up thrusts, Space fires. Esc quits.

local W, H = 800, 600
local TAU = math.pi * 2
local rnd = love.math.random

local SHIP_RADIUS = 13 -- for collisions: the ship counts as a circle this big
local SHIP_TURN = 4.6
local SHIP_THRUST = 430
local SHIP_DRAG = 0.5
local SHIP_MAX_SPEED = 540
local SHIP_SHAPE = { 20, 0, -13, -12, -7, 0, -13, 12 }

local BULLET_SPEED = 780
local BULLET_LIFE = 0.8
local MAX_BULLETS = 8

local START_LIVES = 3
local RESPAWN_DELAY = 2.2 -- seconds between dying and the next ship
local SPAWN_INVULN = 2.5 -- seconds a new ship can't be hurt

local ASTEROID = {
    [3] = { radius = 54, score = 20, speedLo = 35, speedHi = 75 },
    [2] = { radius = 29, score = 50, speedLo = 55, speedHi = 115 },
    [1] = { radius = 15, score = 100, speedLo = 75, speedHi = 165 },
}

local ship, bullets, asteroids
local score, lives, wave
local respawnTimer, waveDelay
local gameOver = false
local smallFont, bigFont

-- ============================================================
-- HELPERS
-- ============================================================
local function transform(shape, x, y, angle)
    local out = {}
    local c, s = math.cos(angle), math.sin(angle)
    for i = 1, #shape, 2 do
        local px, py = shape[i], shape[i + 1]
        out[i] = x + px * c - py * s
        out[i + 1] = y + px * s + py * c
    end
    return out
end

local function drawWrapped(x, y, r, fn, obj)
    local x2 = (x < r and W) or (x > W - r and -W) or nil
    local y2 = (y < r and H) or (y > H - r and -H) or nil
    fn(obj)
    if x2 then love.graphics.push(); love.graphics.translate(x2, 0); fn(obj); love.graphics.pop() end
    if y2 then love.graphics.push(); love.graphics.translate(0, y2); fn(obj); love.graphics.pop() end
    if x2 and y2 then love.graphics.push(); love.graphics.translate(x2, y2); fn(obj); love.graphics.pop() end
end

-- On a wrapping screen the shortest way from a to b might cross an edge.
local function wrapDelta(d, size)
    if d > size / 2 then return d - size end
    if d < -size / 2 then return d + size end
    return d
end

local function wrappedDist(ax, ay, bx, by)
    local dx, dy = wrapDelta(bx - ax, W), wrapDelta(by - ay, H)
    return math.sqrt(dx * dx + dy * dy)
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
        table.insert(verts, math.cos(ang) * rad)
        table.insert(verts, math.sin(ang) * rad)
    end
    local ang = rnd() * TAU
    local speed = def.speedLo + rnd() * (def.speedHi - def.speedLo)
    return {
        x = x, y = y,
        vx = math.cos(ang) * speed, vy = math.sin(ang) * speed,
        size = size, radius = def.radius,
        angle = rnd() * TAU, spin = (rnd() - 0.5) * (0.8 + (3 - size) * 0.6),
        verts = verts,
    }
end

local function newShip()
    return {
        x = W / 2, y = H / 2, vx = 0, vy = 0, angle = -math.pi / 2,
        thrusting = false, alive = true, invuln = SPAWN_INVULN,
    }
end

local function spawnWave()
    local count = math.min(3 + wave, 11)
    for _ = 1, count do
        -- pick a spot at least 200 px from the ship
        local x, y
        for _ = 1, 30 do
            x, y = rnd() * W, rnd() * H
            if wrappedDist(x, y, ship.x, ship.y) > 200 then break end
        end
        table.insert(asteroids, newAsteroid(3, x, y))
    end
end

local function startGame()
    score, lives, wave = 0, START_LIVES, 1
    bullets, asteroids = {}, {}
    ship = newShip()
    respawnTimer, waveDelay = 0, nil
    gameOver = false
    spawnWave()
end

-- Remove asteroid i, award points, and split it into two smaller ones.
local function destroyAsteroid(i)
    local a = table.remove(asteroids, i)
    score = score + ASTEROID[a.size].score
    if a.size > 1 then
        for _ = 1, 2 do
            local child = newAsteroid(a.size - 1, a.x, a.y)
            child.vx = child.vx + a.vx * 0.5 -- keep some of the parent's motion
            child.vy = child.vy + a.vy * 0.5
            table.insert(asteroids, child)
        end
    end
end

local function killShip()
    ship.alive = false
    lives = lives - 1
    respawnTimer = RESPAWN_DELAY
end

local function fire()
    if #bullets >= MAX_BULLETS then return end
    local c, s = math.cos(ship.angle), math.sin(ship.angle)
    table.insert(bullets, {
        x = ship.x + c * 20, y = ship.y + s * 20,
        vx = c * BULLET_SPEED + ship.vx, vy = s * BULLET_SPEED + ship.vy,
        life = BULLET_LIFE,
    })
end

-- ============================================================
-- UPDATE
-- ============================================================
local function updateShip(dt)
    if love.keyboard.isDown("left", "a") then ship.angle = ship.angle - SHIP_TURN * dt end
    if love.keyboard.isDown("right", "d") then ship.angle = ship.angle + SHIP_TURN * dt end

    ship.thrusting = love.keyboard.isDown("up", "w")
    if ship.thrusting then
        ship.vx = ship.vx + math.cos(ship.angle) * SHIP_THRUST * dt
        ship.vy = ship.vy + math.sin(ship.angle) * SHIP_THRUST * dt
    end

    local drag = math.exp(-SHIP_DRAG * dt)
    ship.vx = ship.vx * drag
    ship.vy = ship.vy * drag

    local speed = math.sqrt(ship.vx * ship.vx + ship.vy * ship.vy)
    if speed > SHIP_MAX_SPEED then
        ship.vx = ship.vx / speed * SHIP_MAX_SPEED
        ship.vy = ship.vy / speed * SHIP_MAX_SPEED
    end

    ship.x = (ship.x + ship.vx * dt) % W
    ship.y = (ship.y + ship.vy * dt) % H
    ship.invuln = math.max(0, ship.invuln - dt)
end

local function updateBullets(dt)
    for i = #bullets, 1, -1 do
        local b = bullets[i]
        b.x = (b.x + b.vx * dt) % W
        b.y = (b.y + b.vy * dt) % H
        b.life = b.life - dt
        if b.life <= 0 then
            table.remove(bullets, i)
        end
    end
end

local function moveAsteroids(dt)
    for _, a in ipairs(asteroids) do
        a.x = (a.x + a.vx * dt) % W
        a.y = (a.y + a.vy * dt) % H
        a.angle = a.angle + a.spin * dt
    end
end

local function collide()
    -- bullets vs asteroids
    for i = #bullets, 1, -1 do
        local b = bullets[i]
        for j = #asteroids, 1, -1 do
            local a = asteroids[j]
            if wrappedDist(b.x, b.y, a.x, a.y) < a.radius * 0.9 then
                destroyAsteroid(j)
                table.remove(bullets, i)
                break -- this bullet is gone; move on to the next bullet
            end
        end
    end

    -- ship vs asteroids
    if ship.alive and ship.invuln <= 0 then
        for j = #asteroids, 1, -1 do
            local a = asteroids[j]
            if wrappedDist(ship.x, ship.y, a.x, a.y) < a.radius * 0.85 + SHIP_RADIUS then
                destroyAsteroid(j)
                killShip()
                break
            end
        end
    end
end

function love.load()
    love.window.setTitle("Asteroids")
    -- Create fonts once, here. Making a new font every frame is slow.
    smallFont = love.graphics.newFont(16)
    bigFont = love.graphics.newFont(40)
    startGame()
end

function love.update(dt)
    if gameOver then
        moveAsteroids(dt)
        return
    end

    if ship.alive then
        updateShip(dt)
    else
        respawnTimer = respawnTimer - dt
        if respawnTimer <= 0 then
            if lives > 0 then
                ship = newShip()
            else
                gameOver = true
            end
        end
    end

    updateBullets(dt)
    moveAsteroids(dt)
    collide()

    -- all asteroids gone: wait a moment, then start the next wave
    if #asteroids == 0 and not waveDelay then
        waveDelay = 2
    end
    if waveDelay then
        waveDelay = waveDelay - dt
        if waveDelay <= 0 then
            waveDelay = nil
            wave = wave + 1
            spawnWave()
        end
    end
end

-- ============================================================
-- DRAW
-- ============================================================
local function drawAsteroid(a)
    love.graphics.setColor(1, 0.4, 0.85)
    love.graphics.polygon("line", transform(a.verts, a.x, a.y, a.angle))
end

local function drawShip(s)
    -- blink while invulnerable: visible for 0.1 s, hidden for 0.1 s
    if s.invuln > 0 and math.floor(s.invuln * 10) % 2 == 0 then return end
    love.graphics.setColor(0.25, 0.95, 1)
    love.graphics.polygon("line", transform(SHIP_SHAPE, s.x, s.y, s.angle))
    if s.thrusting then
        local len = 10 + rnd() * 14
        love.graphics.setColor(1, 0.45, 0.25)
        love.graphics.line(transform({ -9, -5, -9 - len, 0, -9, 5 }, s.x, s.y, s.angle))
    end
end

function love.draw()
    love.graphics.setLineWidth(2)
    for _, a in ipairs(asteroids) do
        drawWrapped(a.x, a.y, a.radius + 8, drawAsteroid, a)
    end
    if ship.alive and not gameOver then
        drawWrapped(ship.x, ship.y, 32, drawShip, ship)
    end

    love.graphics.setColor(1, 0.95, 0.5)
    for _, b in ipairs(bullets) do
        love.graphics.line(b.x, b.y, b.x - b.vx * 0.022, b.y - b.vy * 0.022)
    end

    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(smallFont)
    love.graphics.print("SCORE " .. score .. "    LIVES " .. lives .. "    WAVE " .. wave, 10, 10)

    if gameOver then
        love.graphics.setFont(bigFont)
        love.graphics.printf("GAME OVER", 0, H / 2 - 60, W, "center")
        love.graphics.setFont(smallFont)
        love.graphics.printf("Press Enter to play again", 0, H / 2 + 10, W, "center")
    end
end

function love.keypressed(key)
    if key == "space" and not gameOver and ship.alive then
        fire()
    elseif key == "return" and gameOver then
        startGame()
    elseif key == "escape" then
        love.event.quit()
    end
end
