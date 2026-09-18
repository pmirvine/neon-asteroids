-- Neon Asteroids

local Game = require "src.game"

local view = { scale = 1, x = 0, y = 0 }

-- Letterbox the fixed virtual screen into the window.
local function fitView(w, h)
    view.scale = math.min(w / Game.W, h / Game.H)
    view.x = math.floor((w - Game.W * view.scale) / 2)
    view.y = math.floor((h - Game.H * view.scale) / 2)
end

function love.load()
    love.graphics.setDefaultFilter("linear", "linear")
    love.mouse.setVisible(false)
    fitView(love.graphics.getDimensions())
    Game.load()
end

function love.resize(w, h)
    fitView(w, h)
end

function love.update(dt)
    Game.update(math.min(dt, 1 / 30))
end

function love.draw()
    love.graphics.push()
    love.graphics.translate(view.x, view.y)
    love.graphics.scale(view.scale)
    love.graphics.setScissor(view.x, view.y, math.ceil(Game.W * view.scale), math.ceil(Game.H * view.scale))
    Game.draw()
    love.graphics.setScissor()
    love.graphics.pop()
end

function love.keypressed(key, scancode, isrepeat)
    if key == "f11" or (key == "return" and love.keyboard.isDown("lalt", "ralt")) then
        love.window.setFullscreen(not love.window.getFullscreen(), "desktop")
        return
    end
    Game.keypressed(key, isrepeat)
end
