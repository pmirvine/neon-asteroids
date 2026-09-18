-- Chapter 6: a ship you can fly.
-- Left/Right (or A/D) rotate, Up (or W) thrusts. Esc quits.

local W, H = 800, 600

local SHIP_TURN = 4.6 -- radians per second
local SHIP_THRUST = 430 -- speed gained per second while thrusting
local SHIP_DRAG = 0.5 -- how quickly the ship slows down
local SHIP_MAX_SPEED = 540
local SHIP_SHAPE = { 20, 0, -13, -12, -7, 0, -13, 12 } -- nose points right (+x)

local ship

-- Rotate a flat list of points {x1, y1, x2, y2, ...} by `angle`,
-- then move them so (0, 0) lands on (x, y).
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

function love.load()
    ship = {
        x = W / 2, y = H / 2,
        vx = 0, vy = 0,
        angle = -math.pi / 2, -- pointing up (angles are in radians)
        thrusting = false,
    }
end

function love.update(dt)
    if love.keyboard.isDown("left", "a") then ship.angle = ship.angle - SHIP_TURN * dt end
    if love.keyboard.isDown("right", "d") then ship.angle = ship.angle + SHIP_TURN * dt end

    ship.thrusting = love.keyboard.isDown("up", "w")
    if ship.thrusting then
        ship.vx = ship.vx + math.cos(ship.angle) * SHIP_THRUST * dt
        ship.vy = ship.vy + math.sin(ship.angle) * SHIP_THRUST * dt
    end

    -- drag: lose the same fraction of speed each second, whatever the frame rate
    local drag = math.exp(-SHIP_DRAG * dt)
    ship.vx = ship.vx * drag
    ship.vy = ship.vy * drag

    -- speed limit
    local speed = math.sqrt(ship.vx * ship.vx + ship.vy * ship.vy)
    if speed > SHIP_MAX_SPEED then
        ship.vx = ship.vx / speed * SHIP_MAX_SPEED
        ship.vy = ship.vy / speed * SHIP_MAX_SPEED
    end

    -- move, wrapping around the screen edges with % (remainder)
    ship.x = (ship.x + ship.vx * dt) % W
    ship.y = (ship.y + ship.vy * dt) % H
end

function love.draw()
    love.graphics.setLineWidth(2)
    love.graphics.setColor(0.25, 0.95, 1)
    love.graphics.polygon("line", transform(SHIP_SHAPE, ship.x, ship.y, ship.angle))

    if ship.thrusting then
        local len = 10 + love.math.random() * 14 -- a flickering flame
        love.graphics.setColor(1, 0.45, 0.25)
        love.graphics.line(transform({ -9, -5, -9 - len, 0, -9, 5 }, ship.x, ship.y, ship.angle))
    end
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
end
