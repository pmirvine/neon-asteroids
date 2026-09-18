--[[ neon.lua — glowing vector strokes.

Every shape is drawn three times with additive blending: a wide faint halo,
a medium glow, and a thin core pushed toward white. The bloom pass in
glow.lua then spreads that light further.

Call with the blend mode already set to "add".
]]

local Neon = {}
local lg = love.graphics

local HALO_WIDTH, HALO_ALPHA = 3.4, 0.10
local GLOW_WIDTH, GLOW_ALPHA = 1.8, 0.32
local CORE_WHITE = 0.5 -- how far the core line is pushed toward white

local function stroke(points, closed)
    if closed then
        lg.polygon("line", points)
    else
        lg.line(points)
    end
end

-- points: flat {x1, y1, x2, y2, ...}; closed draws it as a polygon outline.
function Neon.lines(points, r, g, b, a, width, closed)
    a, width = a or 1, width or 2
    lg.setLineWidth(width * HALO_WIDTH)
    lg.setColor(r, g, b, a * HALO_ALPHA)
    stroke(points, closed)
    lg.setLineWidth(width * GLOW_WIDTH)
    lg.setColor(r, g, b, a * GLOW_ALPHA)
    stroke(points, closed)
    lg.setLineWidth(width)
    lg.setColor(r + (1 - r) * CORE_WHITE, g + (1 - g) * CORE_WHITE, b + (1 - b) * CORE_WHITE, a)
    stroke(points, closed)
end

function Neon.circle(x, y, radius, r, g, b, a, width, segments)
    a, width, segments = a or 1, width or 2, segments or 64
    lg.setLineWidth(width * HALO_WIDTH)
    lg.setColor(r, g, b, a * HALO_ALPHA)
    lg.circle("line", x, y, radius, segments)
    lg.setLineWidth(width * GLOW_WIDTH)
    lg.setColor(r, g, b, a * GLOW_ALPHA)
    lg.circle("line", x, y, radius, segments)
    lg.setLineWidth(width)
    lg.setColor(r + (1 - r) * CORE_WHITE, g + (1 - g) * CORE_WHITE, b + (1 - b) * CORE_WHITE, a)
    lg.circle("line", x, y, radius, segments)
end

function Neon.dot(x, y, radius, r, g, b, a)
    a = a or 1
    lg.setColor(r, g, b, a * 0.18)
    lg.circle("fill", x, y, radius * 2.6)
    lg.setColor(r + (1 - r) * CORE_WHITE, g + (1 - g) * CORE_WHITE, b + (1 - b) * CORE_WHITE, a)
    lg.circle("fill", x, y, radius)
end

return Neon
