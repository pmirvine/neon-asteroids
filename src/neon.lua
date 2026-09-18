--[[ neon.lua — glowing vector strokes and a stroke-based vector font.

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

-- ============================================================
-- VECTOR FONT
-- ============================================================
-- Glyphs live on a 4 x 6 grid (y down). Strokes are separated by "|".
local GLYPH_SRC = {
    A = "0,6 0,2 2,0 4,2 4,6|0,3.5 4,3.5",
    B = "0,0 0,6 3,6 4,5 4,4 3,3 0,3|0,0 3,0 4,1 4,2 3,3",
    C = "4,0 0,0 0,6 4,6",
    D = "0,0 0,6 2,6 4,4 4,2 2,0 0,0",
    E = "4,0 0,0 0,6 4,6|0,3 3,3",
    F = "4,0 0,0 0,6|0,3 3,3",
    G = "4,1 4,0 0,0 0,6 4,6 4,3 2,3",
    H = "0,0 0,6|4,0 4,6|0,3 4,3",
    I = "0,0 4,0|2,0 2,6|0,6 4,6",
    J = "4,0 4,5 3,6 1,6 0,5",
    K = "0,0 0,6|4,0 0,3 4,6",
    L = "0,0 0,6 4,6",
    M = "0,6 0,0 2,2 4,0 4,6",
    N = "0,6 0,0 4,6 4,0",
    O = "0,0 4,0 4,6 0,6 0,0",
    P = "0,6 0,0 4,0 4,3 0,3",
    Q = "0,0 4,0 4,4 2,6 0,6 0,0|2,4 4,6",
    R = "0,6 0,0 4,0 4,3 0,3|1,3 4,6",
    S = "4,0 0,0 0,3 4,3 4,6 0,6",
    T = "0,0 4,0|2,0 2,6",
    U = "0,0 0,6 4,6 4,0",
    V = "0,0 2,6 4,0",
    W = "0,0 0,6 2,4 4,6 4,0",
    X = "0,0 4,6|4,0 0,6",
    Y = "0,0 2,3 4,0|2,3 2,6",
    Z = "0,0 4,0 0,6 4,6",
    ["0"] = "0,0 4,0 4,6 0,6 0,0|4,0 0,6",
    ["1"] = "1,1 2,0 2,6|1,6 3,6",
    ["2"] = "0,0 4,0 4,3 0,3 0,6 4,6",
    ["3"] = "0,0 4,0 4,6 0,6|1,3 4,3",
    ["4"] = "0,0 0,3 4,3|4,0 4,6",
    ["5"] = "4,0 0,0 0,3 4,3 4,6 0,6",
    ["6"] = "4,0 0,0 0,6 4,6 4,3 0,3",
    ["7"] = "0,0 4,0 4,6",
    ["8"] = "0,0 4,0 4,6 0,6 0,0|0,3 4,3",
    ["9"] = "4,3 0,3 0,0 4,0 4,6 0,6",
    ["-"] = "1,3 3,3",
    ["+"] = "2,1.5 2,4.5|0.5,3 3.5,3",
    ["."] = "1.7,5.6 2.3,6",
    [","] = "2,5 1,7",
    [":"] = "2,1.5 2,2.1|2,4.4 2,5",
    ["!"] = "2,0 2,4|2,5.4 2,6",
    ["?"] = "0,1 1,0 3,0 4,1 4,2 2,3 2,4|2,5.4 2,6",
    ["/"] = "4,0 0,6",
    ["'"] = "2,0 2,1.5",
    ["("] = "3,0 1,2 1,4 3,6",
    [")"] = "1,0 3,2 3,4 1,6",
    ["<"] = "3,1 1,3 3,5",
    [">"] = "1,1 3,3 1,5",
    ["="] = "0.5,2 3.5,2|0.5,4 3.5,4",
    [" "] = "",
}

local GLYPHS = {}
for ch, src in pairs(GLYPH_SRC) do
    local strokes = {}
    for part in src:gmatch("[^|]+") do
        local pts = {}
        for x, y in part:gmatch("(-?[%d%.]+),(-?[%d%.]+)") do
            pts[#pts + 1] = tonumber(x)
            pts[#pts + 1] = tonumber(y)
        end
        if #pts >= 4 then strokes[#strokes + 1] = pts end
    end
    GLYPHS[ch] = strokes
end

function Neon.textWidth(str, size, spacing)
    spacing = spacing or 2
    return (#str * (4 + spacing) - spacing) * size / 6
end

local buf = {}

-- Draws str with its cap height = size. align: "left" (default), "center", "right".
function Neon.text(str, x, y, size, r, g, b, a, align, spacing, width)
    str = string.upper(tostring(str))
    spacing = spacing or 2
    width = width or math.min(3.2, math.max(1.3, size / 12))
    local s = size / 6
    local w = Neon.textWidth(str, size, spacing)
    if align == "center" then
        x = x - w / 2
    elseif align == "right" then
        x = x - w
    end

    for i = 1, #str do
        local glyph = GLYPHS[str:sub(i, i)]
        if glyph then
            local ox = x + (i - 1) * (4 + spacing) * s
            for _, pts in ipairs(glyph) do
                local n = #pts
                for k = 1, n, 2 do
                    buf[k] = ox + pts[k] * s
                    buf[k + 1] = y + pts[k + 1] * s
                end
                for k = #buf, n + 1, -1 do buf[k] = nil end
                Neon.lines(buf, r, g, b, a, width, false)
            end
        end
    end
end

return Neon
