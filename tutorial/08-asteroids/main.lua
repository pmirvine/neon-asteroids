-- Chapter 8: asteroids.
-- Randomly shaped rocks drift, spin and wrap. Nothing collides yet.

local W, H = 800, 600
local TAU = math.pi * 2 -- one full turn, in radians
local rnd = love.math.random -- short name for a function we use a lot

local SHIP_TURN = 4.6
local SHIP_THRUST = 430
local SHIP_DRAG = 0.5
local SHIP_MAX_SPEED = 540
local SHIP_SHAPE = { 20, 0, -13, -12, -7, 0, -13, 12 }

local BULLET_SPEED = 780
local BULLET_LIFE = 0.8
local MAX_BULLETS = 8

-- One entry per asteroid size: 3 = large, 2 = medium, 1 = small.
local ASTEROID = {
    [3] = { radius = 54, speedLo = 35, speedHi = 75 },
    [2] = { radius = 29, speedLo = 55, speedHi = 115 },
    [1] = { radius = 15, speedLo = 75, speedHi = 165 },
}

local ship
local bullets = {}
local asteroids = {}

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

-- Call fn(obj) to draw it, then again shifted by a screen width/height when
-- it pokes over an edge, so it appears on both sides at once.
local function drawWrapped(x, y, r, fn, obj)
    local x2 = (x < r and W) or (x > W - r and -W) or nil
    local y2 = (y < r and H) or (y > H - r and -H) or nil
    fn(obj)
    if x2 then love.graphics.push(); love.graphics.translate(x2, 0); fn(obj); love.graphics.pop() end
    if y2 then love.graphics.push(); love.graphics.translate(0, y2); fn(obj); love.graphics.pop() end
    if x2 and y2 then love.graphics.push(); love.graphics.translate(x2, y2); fn(obj); love.graphics.pop() end
end

local function newAsteroid(size, x, y)
    local def = ASTEROID[size]
    -- a lumpy circle: 10-14 points, each at a slightly random distance
    local n = rnd(10, 14)
    local verts = {}
    for i = 0, n - 1 do
        local ang = (i + (rnd() - 0.5) * 0.5) / n * TAU
        local rad = def.radius * (0.7 + rnd() * 0.35)
        table.insert(verts, math.cos(ang) * rad)
        table.insert(verts, math.sin(ang) * rad)
    end
    -- drift in a random direction at a random speed for its size
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

local function fire()
    if #bullets >= MAX_BULLETS then return end
    local c, s = math.cos(ship.angle), math.sin(ship.angle)
    table.insert(bullets, {
        x = ship.x + c * 20, y = ship.y + s * 20,
        vx = c * BULLET_SPEED + ship.vx, vy = s * BULLET_SPEED + ship.vy,
        life = BULLET_LIFE,
    })
end

function love.load()
    ship = { x = W / 2, y = H / 2, vx = 0, vy = 0, angle = -math.pi / 2, thrusting = false }
    for _ = 1, 4 do
        table.insert(asteroids, newAsteroid(3, rnd() * W, rnd() * H))
    end
end

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

function love.update(dt)
    updateShip(dt)
    updateBullets(dt)
    moveAsteroids(dt)
end

local function drawAsteroid(a)
    love.graphics.setColor(1, 0.4, 0.85)
    love.graphics.polygon("line", transform(a.verts, a.x, a.y, a.angle))
end

local function drawShip(s)
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
    drawWrapped(ship.x, ship.y, 32, drawShip, ship)

    love.graphics.setColor(1, 0.95, 0.5)
    for _, b in ipairs(bullets) do
        love.graphics.line(b.x, b.y, b.x - b.vx * 0.022, b.y - b.vy * 0.022)
    end
end

function love.keypressed(key)
    if key == "space" then
        fire()
    elseif key == "escape" then
        love.event.quit()
    end
end
