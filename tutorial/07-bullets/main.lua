-- Chapter 7: bullets.
-- Left/Right rotate, Up thrusts, Space fires. Esc quits.

local W, H = 800, 600

local SHIP_TURN = 4.6
local SHIP_THRUST = 430
local SHIP_DRAG = 0.5
local SHIP_MAX_SPEED = 540
local SHIP_SHAPE = { 20, 0, -13, -12, -7, 0, -13, 12 }

local BULLET_SPEED = 780
local BULLET_LIFE = 0.8 -- seconds before a bullet fizzles out
local MAX_BULLETS = 8

local ship
local bullets = {}

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

local function fire()
    if #bullets >= MAX_BULLETS then return end
    local c, s = math.cos(ship.angle), math.sin(ship.angle)
    table.insert(bullets, {
        x = ship.x + c * 20, -- start at the ship's nose
        y = ship.y + s * 20,
        vx = c * BULLET_SPEED + ship.vx, -- bullets inherit the ship's speed
        vy = s * BULLET_SPEED + ship.vy,
        life = BULLET_LIFE,
    })
end

function love.load()
    ship = { x = W / 2, y = H / 2, vx = 0, vy = 0, angle = -math.pi / 2, thrusting = false }
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
    -- Walk the list backwards so removing a bullet doesn't skip the next one.
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

function love.update(dt)
    updateShip(dt)
    updateBullets(dt)
end

function love.draw()
    love.graphics.setLineWidth(2)
    love.graphics.setColor(0.25, 0.95, 1)
    love.graphics.polygon("line", transform(SHIP_SHAPE, ship.x, ship.y, ship.angle))

    if ship.thrusting then
        local len = 10 + love.math.random() * 14
        love.graphics.setColor(1, 0.45, 0.25)
        love.graphics.line(transform({ -9, -5, -9 - len, 0, -9, 5 }, ship.x, ship.y, ship.angle))
    end

    -- each bullet is a short streak pointing back along its path
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
