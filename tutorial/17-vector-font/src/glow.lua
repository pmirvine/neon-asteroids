--[[ glow.lua — neon bloom post-processing.

The frame is drawn into an HDR scene canvas. finish() then builds three
progressively smaller, blurred copies of it (half, quarter, eighth size) and
composites them back over the scene, so every bright line gets a tight halo
plus a wide soft glow. The composite pass also adds a little chromatic
aberration (driven by screen shake), faint scanlines, a vignette and a
full-screen flash.
]]

local Glow = {}
Glow.__index = Glow

-- 9-tap Gaussian using linear sampling (5 texture reads per pass).
local BLUR_SRC = [[
extern vec2 direction;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec2 o1 = direction * 1.3846153846;
    vec2 o2 = direction * 3.2307692308;
    vec4 sum = Texel(tex, uv) * 0.2270270270;
    sum += Texel(tex, uv + o1) * 0.3162162162;
    sum += Texel(tex, uv - o1) * 0.3162162162;
    sum += Texel(tex, uv + o2) * 0.0702702703;
    sum += Texel(tex, uv - o2) * 0.0702702703;
    return sum;
}
]]

-- First downsample: cap brightness (keeping hue) so a dense pile of additive
-- sparks blooms into a soft halo rather than a huge flat white disc.
local PREFILTER_SRC = [[
extern float ceiling;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec3 c = Texel(tex, uv).rgb;
    float peak = max(c.r, max(c.g, c.b));
    c *= min(1.0, ceiling / max(peak, 0.0001));
    return vec4(c, 1.0);
}
]]

local BLOOM_CEILING = 1.6

local COMPOSITE_SRC = [[
extern Image bloom1;
extern Image bloom2;
extern Image bloom3;
extern vec3 strength;
extern float aberration;
extern float flash;
vec4 effect(vec4 color, Image scene, vec2 uv, vec2 sc) {
    vec2 c = uv - 0.5;
    vec2 off = c * aberration;
    vec3 col = vec3(Texel(scene, uv + off).r, Texel(scene, uv).g, Texel(scene, uv - off).b);
    col += Texel(bloom1, uv).rgb * strength.x;
    col += Texel(bloom2, uv).rgb * strength.y;
    col += Texel(bloom3, uv).rgb * strength.z;
    col += vec3(flash);
    // over-bright cores burn toward white, like a real neon tube
    float peak = max(col.r, max(col.g, col.b));
    col += vec3(max(peak - 1.0, 0.0) * 0.4);
    col *= 0.965 + 0.035 * sin(sc.y * 3.14159265);
    float vig = 1.0 - smoothstep(0.4, 0.85, length(c));
    col *= mix(0.6, 1.0, vig);
    return vec4(col, 1.0);
}
]]

local BLUR_PASSES = 2 -- blur iterations per level; more = wider, softer glow

local function send(shader, name, ...)
    if shader:hasUniform(name) then shader:send(name, ...) end
end

function Glow.new(w, h)
    local self = setmetatable({}, Glow)
    local formats = love.graphics.getCanvasFormats()
    self.format = formats.rgba16f and "rgba16f" or "normal"
    self.msaa = math.min(4, love.graphics.getSystemLimits().canvasmsaa or 0)
    self.blur = love.graphics.newShader(BLUR_SRC)
    self.prefilter = love.graphics.newShader(PREFILTER_SRC)
    self.prefilter:send("ceiling", BLOOM_CEILING)
    self.composite = love.graphics.newShader(COMPOSITE_SRC)
    self.strength = { 1.0, 0.9, 0.8 }
    self:resize(w, h)
    return self
end

function Glow:resize(w, h)
    w, h = math.max(1, math.floor(w)), math.max(1, math.floor(h))
    self.w, self.h = w, h

    local ok, canvas = pcall(love.graphics.newCanvas, w, h, { format = self.format, msaa = self.msaa })
    if not ok then
        canvas = love.graphics.newCanvas(w, h)
    end
    self.scene = canvas

    self.levels = {}
    local lw, lh = w, h
    for i = 1, 3 do
        lw, lh = math.max(1, math.floor(lw / 2)), math.max(1, math.floor(lh / 2))
        local a = love.graphics.newCanvas(lw, lh, { format = self.format })
        local b = love.graphics.newCanvas(lw, lh, { format = self.format })
        a:setFilter("linear", "linear")
        b:setFilter("linear", "linear")
        self.levels[i] = { a = a, b = b, w = lw, h = lh }
    end
end

-- Start drawing the frame into the scene canvas.
function Glow:begin()
    love.graphics.setCanvas(self.scene)
    love.graphics.clear(0, 0, 0, 1)
end

-- Blur, composite and present the frame to the screen.
function Glow:finish(aberration, flash)
    local lg = love.graphics
    -- Unbind the scene canvas *before* push("all"), otherwise pop() would
    -- re-activate it and LÖVE can't present the frame.
    lg.setCanvas()
    lg.push("all")
    lg.origin()
    lg.setColor(1, 1, 1, 1)
    lg.setBlendMode("replace", "premultiplied")

    local src, sw, sh = self.scene, self.w, self.h
    for i, level in ipairs(self.levels) do
        lg.setShader(i == 1 and self.prefilter or nil)
        lg.setCanvas(level.a)
        lg.draw(src, 0, 0, 0, level.w / sw, level.h / sh)

        lg.setShader(self.blur)
        for _ = 1, BLUR_PASSES do
            self.blur:send("direction", { 1 / level.w, 0 })
            lg.setCanvas(level.b)
            lg.draw(level.a)
            self.blur:send("direction", { 0, 1 / level.h })
            lg.setCanvas(level.a)
            lg.draw(level.b)
        end
        src, sw, sh = level.a, level.w, level.h
    end

    lg.setCanvas()
    lg.setShader(self.composite)
    send(self.composite, "bloom1", self.levels[1].a)
    send(self.composite, "bloom2", self.levels[2].a)
    send(self.composite, "bloom3", self.levels[3].a)
    send(self.composite, "strength", self.strength)
    send(self.composite, "aberration", aberration or 0)
    send(self.composite, "flash", flash or 0)
    lg.draw(self.scene)
    lg.pop()
end

return Glow
