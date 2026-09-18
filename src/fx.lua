--[[ fx.lua — particles, screen shake and screen flash.

Particle kinds:
  spark   a streak drawn along its velocity; starts white-hot, cools to its color
  debris  one line segment of a destroyed shape, tumbling away
  ring    an expanding shockwave circle
  flash   a bright filled blob that swells and fades

Screen shake uses the "trauma" model: events add trauma (0..1), the visible
shake is trauma squared, and trauma decays over time. Only big explosions add
trauma, so small hits don't jostle the screen.
]]

local Fx = {}
local lg = love.graphics
local rnd = love.math.random
local TAU = math.pi * 2

local SPARK, DEBRIS, RING, FLASH = 1, 2, 3, 4
local MAX_PARTICLES = 5000

local SHAKE_OFFSET = 26 -- px at full trauma
local SHAKE_ANGLE = 0.03 -- radians at full trauma
local SHAKE_FREQ = 22
local TRAUMA_DECAY = 0.85 -- per second
local FLASH_DECAY = 2.5

local particles = {}

-- Soft radial falloff sprite used for explosion flashes.
local glowImage
local GLOW_SIZE = 128
local function getGlowImage()
    if not glowImage then
        local half = GLOW_SIZE / 2
        local data = love.image.newImageData(GLOW_SIZE, GLOW_SIZE)
        data:mapPixel(function(x, y)
            local dx, dy = (x + 0.5 - half) / half, (y + 0.5 - half) / half
            local d = math.min(1, math.sqrt(dx * dx + dy * dy))
            return 1, 1, 1, (1 - d) ^ 2.5
        end)
        glowImage = lg.newImage(data)
        glowImage:setFilter("linear", "linear")
    end
    return glowImage
end

Fx.trauma = 0
Fx.flash = 0
Fx.shakeX, Fx.shakeY, Fx.shakeAngle = 0, 0, 0
Fx.time = 0

function Fx.reset()
    particles = {}
    Fx.trauma = 0
    Fx.flash = 0
end

function Fx.count()
    return #particles
end

local function add(p)
    if #particles < MAX_PARTICLES then
        particles[#particles + 1] = p
    end
end

-- ============================================================
-- EMITTERS
-- ============================================================
function Fx.spark(x, y, vx, vy, life, r, g, b, width, drag)
    add({ kind = SPARK, x = x, y = y, vx = vx, vy = vy, life = life, max = life,
        r = r, g = g, b = b, w = width or 1.6, drag = drag or 2.2 })
end

function Fx.burst(x, y, count, speedLo, speedHi, lifeLo, lifeHi, r, g, b, baseVx, baseVy)
    baseVx, baseVy = baseVx or 0, baseVy or 0
    for _ = 1, count do
        local ang = rnd() * TAU
        local c, s = math.cos(ang), math.sin(ang)
        local speed = speedLo + rnd() * (speedHi - speedLo)
        local offset = rnd() * 8 -- scatter the origin so dense bursts don't clip to a flat white dot
        Fx.spark(x + c * offset, y + s * offset, c * speed + baseVx, s * speed + baseVy,
            lifeLo + rnd() * (lifeHi - lifeLo), r, g, b)
    end
end

-- Sparks that rush inward and meet at (x, y) after `duration` seconds.
function Fx.implode(x, y, radius, count, duration, r, g, b)
    for _ = 1, count do
        local ang = rnd() * TAU
        local dist = radius * (0.6 + rnd() * 0.4)
        local c, s = math.cos(ang), math.sin(ang)
        local speed = dist / duration
        Fx.spark(x + c * dist, y + s * dist, -c * speed, -s * speed, duration, r, g, b, 1.6, 0)
    end
end

function Fx.ring(x, y, radius, duration, r, g, b, width)
    add({ kind = RING, x = x, y = y, radius = radius, life = duration, max = duration,
        r = r, g = g, b = b, w = width or 3 })
end

function Fx.glowFlash(x, y, radius, duration, r, g, b)
    add({ kind = FLASH, x = x, y = y, radius = radius, life = duration, max = duration, r = r, g = g, b = b })
end

-- Break a closed polygon (flat world-space points) into tumbling line segments.
function Fx.debris(points, cx, cy, vx, vy, speed, life, r, g, b)
    local n = #points
    for i = 1, n - 1, 2 do
        local j = (i + 2 > n) and 1 or i + 2
        local x1, y1, x2, y2 = points[i], points[i + 1], points[j], points[j + 1]
        local mx, my = (x1 + x2) / 2, (y1 + y2) / 2
        local dx, dy = mx - cx, my - cy
        local d = math.sqrt(dx * dx + dy * dy)
        if d < 0.001 then dx, dy, d = 1, 0, 1 end
        local sp = speed * (0.5 + rnd())
        local l = life * (0.6 + rnd() * 0.5)
        add({ kind = DEBRIS, x = mx, y = my,
            ax = x1 - mx, ay = y1 - my, bx = x2 - mx, by = y2 - my,
            vx = vx + dx / d * sp + (rnd() - 0.5) * speed * 0.5,
            vy = vy + dy / d * sp + (rnd() - 0.5) * speed * 0.5,
            angle = 0, spin = (rnd() - 0.5) * 9,
            life = l, max = l, r = r, g = g, b = b, drag = 0.7 })
    end
end

-- A complete explosion; scale ~1 (small) to ~5 (huge).
function Fx.explosion(x, y, scale, r, g, b, vx, vy)
    vx, vy = (vx or 0) * 0.3, (vy or 0) * 0.3
    Fx.glowFlash(x, y, 26 * scale, 0.22 + 0.05 * scale, 0.5 + r * 0.5, 0.5 + g * 0.5, 0.5 + b * 0.5)
    Fx.ring(x, y, 42 * scale, 0.35 + 0.08 * scale, r, g, b, 1.5 + scale * 0.6)
    Fx.burst(x, y, math.floor(16 * scale), 50, 170 + 80 * scale, 0.35, 0.7 + 0.18 * scale, r, g, b, vx, vy)
    Fx.burst(x, y, math.floor(5 * scale), 120, 260 + 70 * scale, 0.12, 0.4, 1, 0.95, 0.8, vx, vy)
end

function Fx.shake(amount)
    Fx.trauma = math.min(1, Fx.trauma + amount)
end

-- ============================================================
-- UPDATE
-- ============================================================
function Fx.update(dt)
    for i = #particles, 1, -1 do
        local p = particles[i]
        p.life = p.life - dt
        if p.life <= 0 then
            -- swap-remove: order doesn't matter and this stays O(1)
            particles[i] = particles[#particles]
            particles[#particles] = nil
        elseif p.kind == SPARK or p.kind == DEBRIS then
            local f = math.exp(-p.drag * dt)
            p.vx, p.vy = p.vx * f, p.vy * f
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            if p.kind == DEBRIS then p.angle = p.angle + p.spin * dt end
        end
    end
end

-- Runs on real (unscaled) time so shake keeps moving during slow motion.
function Fx.updateShake(dt)
    Fx.time = Fx.time + dt
    Fx.trauma = math.max(0, Fx.trauma - TRAUMA_DECAY * dt)
    Fx.flash = math.max(0, Fx.flash - FLASH_DECAY * dt)
    local s = Fx.trauma * Fx.trauma
    local t = Fx.time * SHAKE_FREQ
    Fx.shakeX = SHAKE_OFFSET * s * (love.math.noise(t, 11.3) * 2 - 1)
    Fx.shakeY = SHAKE_OFFSET * s * (love.math.noise(t, 47.9) * 2 - 1)
    Fx.shakeAngle = SHAKE_ANGLE * s * (love.math.noise(t, 83.1) * 2 - 1)
end

-- ============================================================
-- DRAW (additive blending)
-- ============================================================
function Fx.draw()
    for _, p in ipairs(particles) do
        local t = p.life / p.max
        if p.kind == SPARK then
            local hot = t * t * t
            -- the streak can't be longer than the path the spark has actually travelled
            local tail = math.min(0.04, p.max - p.life) + 0.004
            lg.setLineWidth(p.w)
            lg.setColor(p.r + (1 - p.r) * hot, p.g + (1 - p.g) * hot, p.b + (1 - p.b) * hot, t)
            lg.line(p.x, p.y, p.x - p.vx * tail, p.y - p.vy * tail)
        elseif p.kind == DEBRIS then
            local c, s = math.cos(p.angle), math.sin(p.angle)
            local x1, y1 = p.x + p.ax * c - p.ay * s, p.y + p.ax * s + p.ay * c
            local x2, y2 = p.x + p.bx * c - p.by * s, p.y + p.bx * s + p.by * c
            lg.setLineWidth(5)
            lg.setColor(p.r, p.g, p.b, t * 0.25)
            lg.line(x1, y1, x2, y2)
            lg.setLineWidth(1.8)
            lg.setColor(0.5 + p.r * 0.5, 0.5 + p.g * 0.5, 0.5 + p.b * 0.5, t)
            lg.line(x1, y1, x2, y2)
        elseif p.kind == RING then
            local k = 1 - t
            local ease = 1 - (1 - k) * (1 - k) * (1 - k)
            lg.setLineWidth(p.w * t + 0.5)
            lg.setColor(p.r, p.g, p.b, t * 0.9)
            lg.circle("line", p.x, p.y, p.radius * ease, 64)
        elseif p.kind == FLASH then
            local img = getGlowImage()
            local scale = p.radius * (1.6 - 0.6 * t) / (GLOW_SIZE / 2)
            -- kept dim: the bloom pass roughly triples large soft areas
            lg.setColor(p.r, p.g, p.b, t * t * 0.2)
            lg.draw(img, p.x, p.y, 0, scale, scale, GLOW_SIZE / 2, GLOW_SIZE / 2)
        end
    end
end

return Fx
