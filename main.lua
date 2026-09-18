-- Neon Asteroids
-- Glowing vector asteroids for LÖVE 11: bloom, particles, synthesized
-- Defender-style sound and screen shake. No external assets.

local Glow = require "src.glow"
local Game = require "src.game"

local glow
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
    local w, h = love.graphics.getDimensions()
    glow = Glow.new(w, h)
    fitView(w, h)
    Game.load()
end

function love.resize(w, h)
    glow:resize(w, h)
    fitView(w, h)
end

function love.update(dt)
    Game.update(math.min(dt, 1 / 30))
end

function love.draw()
    glow:begin()
    love.graphics.push()
    love.graphics.translate(view.x, view.y)
    love.graphics.scale(view.scale)
    love.graphics.setScissor(view.x, view.y, math.ceil(Game.W * view.scale), math.ceil(Game.H * view.scale))
    Game.draw()
    love.graphics.setScissor()
    love.graphics.pop()
    glow:finish(Game.aberration(), Game.flash())
end

function love.keypressed(key, scancode, isrepeat)
    if key == "f11" or (key == "return" and love.keyboard.isDown("lalt", "ralt")) then
        love.window.setFullscreen(not love.window.getFullscreen(), "desktop")
        return
    end
    Game.keypressed(key, isrepeat)
end

function love.gamepadpressed(joystick, button)
    Game.gamepadpressed(button)
end

function love.focus(focused)
    Game.focus(focused)
end
