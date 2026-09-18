-- Chapter 5: the game loop.
-- A circle drifts across the screen at a steady speed and wraps at the edges.

local W, H = 800, 600

local x, y = 400, 300
local vx, vy = 120, 60 -- velocity: pixels per second

function love.load()
    love.window.setTitle("The game loop")
end

function love.update(dt)
    -- dt is the time since the last frame, in seconds (about 0.0167 at 60 fps).
    -- Multiplying by dt makes movement the same speed on every computer.
    x = x + vx * dt
    y = y + vy * dt

    -- wrap around: leave on the right, come back on the left
    if x > W then x = x - W end
    if y > H then y = y - H end
end

function love.draw()
    love.graphics.setColor(0.25, 0.95, 1)
    love.graphics.circle("line", x, y, 30)

    love.graphics.setColor(1, 1, 1)
    love.graphics.print("x = " .. math.floor(x) .. "   y = " .. math.floor(y), 10, 10)
    love.graphics.print("FPS: " .. love.timer.getFPS(), 10, 30)
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
end
