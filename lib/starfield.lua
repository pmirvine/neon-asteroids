--[[ starfield.lua — a drop-in, arcade-style starfield background for LÖVE.

This is the whole library — one file, no dependencies beyond LÖVE itself.
Copy it into your own project and you have a starfield that works at any
window size, scrolls in any direction (or stays still), twinkles like the
1979 arcade games, and optionally fakes depth with parallax layers.

Minimal use — three lines on top of a normal LÖVE game:

    local Starfield = require "starfield"
    local field                                 -- 1. create in love.load:
    function love.load()
      field = Starfield.new(love.graphics.getDimensions())
    end
    function love.update(dt) field:update(dt) end   -- 2. animate each frame
    function love.draw()     field:draw()           -- 3. draw first...
      -- ...your ships, aliens and score go on top
    end

By default the stars drift slowly downward, the way Galaxian's did. Common
setups (the third arg is an options table):

    Starfield.new(w, h, {velocity = {0, 0}})        -- static, twinkling backdrop
    Starfield.new(w, h, {velocity = {0, 60}})       -- flying up (stars fall down)
    Starfield.new(w, h, {velocity = {-120, 0}})     -- flying right (stars stream left)
    Starfield.new(w, h, {layers = 3})               -- parallax depth (side-scrollers!)

The one rule to remember: **velocity is the direction the STARS move on
screen**, in pixels per second. If your ship flies right, the stars should
stream left, so use a negative x velocity. For games where the player
controls a camera (Defender-style), leave velocity at {0, 0} and call
field:scroll() with how far the camera moved — see that method's comment.

The default star colors are the actual 63 visible star colors produced by
the Galaxian arcade board's color DAC, so the field looks like the real
thing out of the box. Colors are LÖVE's 0..1 floats.
]]

-- `Starfield` is the table that holds the methods; every field made with
-- Starfield.new is linked to it (the small "object" pattern — docs/lua-notes.md).
local Starfield = {}
Starfield.__index = Starfield

-- ---------------------------------------------------------------------------
-- Palettes  (colors are {r, g, b} with each component in 0..1, LÖVE's range)
-- ---------------------------------------------------------------------------

-- The Galaxian arcade board drove each color gun (red, green, blue) with two
-- bits through a 100/150 ohm resistor DAC, giving four levels per gun:
local DAC_LEVELS = { 0, 194, 214, 255 }

-- extract bit `shift` of `value` (0 or 1) — the DAC math reads like the wiring
local function nth_bit(value, shift)
  return math.floor(value / (2 ^ shift)) % 2
end

local function galaxian_palette()
  -- The 63 visible star colors of the real Galaxian hardware. Each of the 64
  -- possible 6-bit colors uses two bits per gun (the hardware wires the
  -- 100-ohm bit as the high bit). Color 0 is black — invisible on a black
  -- sky — so we leave it out.
  local colors = {}
  for i = 0, 63 do
    local r = DAC_LEVELS[nth_bit(i, 4) * 2 + nth_bit(i, 5) + 1]
    local g = DAC_LEVELS[nth_bit(i, 2) * 2 + nth_bit(i, 3) + 1]
    local b = DAC_LEVELS[nth_bit(i, 0) * 2 + nth_bit(i, 1) + 1]
    if not (r == 0 and g == 0 and b == 0) then
      colors[#colors + 1] = { r / 255, g / 255, b / 255 }
    end
  end
  return colors
end

local GALAXIAN_PALETTE = galaxian_palette()

-- A plain white-to-grey mix, for a subtler modern look.
local WHITE_PALETTE = {
  { 1.0, 1.0, 1.0 },
  { 1.0, 1.0, 1.0 },
  { 214 / 255, 214 / 255, 214 / 255 },
  { 170 / 255, 170 / 255, 170 / 255 },
}

local PALETTE_PRESETS = {
  galaxian = GALAXIAN_PALETTE,
  white = WHITE_PALETTE,
}

-- ---------------------------------------------------------------------------
-- Tuning constants (up here so curious readers can find them)
-- ---------------------------------------------------------------------------

-- density = 1.0 means one star per this many pixels of screen area.
local PIXELS_PER_STAR = 2000

-- Each star blinks on/off with its own period in this range (seconds) at
-- twinkle_speed = 1.0. Centered near the ~0.53 s blink of the arcade original.
local TWINKLE_PERIOD_LO, TWINKLE_PERIOD_HI = 0.35, 0.9

-- Fraction of each blink period that the star is visible.
local TWINKLE_DUTY = 0.55

-- With layers > 1, layer depth factors run from FAR_FACTOR to 1.0. A factor
-- scales a layer's scroll speed; brightness and star size shrink with it too.
local FAR_FACTOR = 0.3

-- A single white pixel, drawn (scaled + tinted) once per star. Building a
-- SpriteBatch from it and drawing that batch is LÖVE's fast path for many
-- small identical sprites — the analog of pygame's fblits().
local STAR_PIXEL

local function star_pixel()
  if not STAR_PIXEL then
    local data = love.image.newImageData(1, 1)
    data:setPixel(0, 0, 1, 1, 1, 1)
    STAR_PIXEL = love.graphics.newImage(data)
    STAR_PIXEL:setFilter("nearest", "nearest")
  end
  return STAR_PIXEL
end

-- ---------------------------------------------------------------------------
-- Construction
-- ---------------------------------------------------------------------------

-- Starfield.new(width, height, opts) — opts is an optional table:
--   velocity      {x, y} px/sec the stars move; {0, 0} = static.
--   density       how crowded (1.0 ≈ one star / 2000 px²); ignored if count set.
--   count         exact number of stars (overrides density).
--   twinkle_speed blink rate; 1.0 = arcade, 0 disables twinkling.
--   layers        parallax depth planes; 1 = flat, 3 = good for side-scrollers.
--   palette       "galaxian" (default), "white", or a list of {r,g,b} (0..1).
--   star_size     px size of the biggest stars; nil = pick automatically.
--   background    {r,g,b} filled behind the stars each frame; nil = stars only.
--   seed          integer for a reproducible sky; nil = fresh each run.
function Starfield.new(width, height, opts)
  opts = opts or {}
  local layers = opts.layers or 1
  if layers < 1 then error("layers must be at least 1") end

  local self = setmetatable({}, Starfield)
  self._width = math.floor(width)
  self._height = math.floor(height)
  self._velocity = { (opts.velocity and opts.velocity[1]) or 0, (opts.velocity and opts.velocity[2]) or 30 }
  self.twinkle_speed = opts.twinkle_speed or 1.0
  self.background = opts.background == nil and { 0, 0, 0 } or opts.background
  self._density = opts.density or 1.0
  self._explicit_count = opts.count
  self._star_size = opts.star_size and math.max(1, math.floor(opts.star_size)) or nil
  self._twinkle_clock = 0.0

  -- Seeded RNG so a given seed reproduces the exact sky. love.math's generator
  -- is independent of the global one, so games seeding elsewhere are unaffected.
  self._rng = love.math.newRandomGenerator(opts.seed or os.time() + math.floor(love.timer.getTime() * 1000))

  -- Resolve the palette.
  local palette = opts.palette or "galaxian"
  if type(palette) == "string" then
    self._palette = PALETTE_PRESETS[palette]
    if not self._palette then
      error("unknown palette '" .. tostring(palette) .. "'; choose galaxian or white")
    end
  else
    self._palette = palette
    if #self._palette == 0 then error("palette must contain at least one color") end
  end

  -- Depth factors from far (slow, faint, small) to near (full speed).
  self._layers = {}
  if layers == 1 then
    self._layers[1] = { factor = 1.0, stars = {}, offset_x = 0, offset_y = 0, size = 1, alpha = 1 }
  else
    local step = (1.0 - FAR_FACTOR) / (layers - 1)
    for i = 0, layers - 1 do
      self._layers[i + 1] = { factor = FAR_FACTOR + step * i, stars = {}, offset_x = 0, offset_y = 0, size = 1, alpha = 1 }
    end
  end

  self:_populate(self:_target_count())
  self:_rebuild_layers()
  return self
end

-- ---------------------------------------------------------------------------
-- Live properties (plain methods — Lua has no property syntax)
-- ---------------------------------------------------------------------------

function Starfield:getSize() return self._width, self._height end

function Starfield:getStarCount()
  local n = 0
  for _, layer in ipairs(self._layers) do n = n + #layer.stars end
  return n
end

-- velocity: assign a new {x, y} at any time (field:setVelocity(0, 80) = warp).
function Starfield:getVelocity() return self._velocity[1], self._velocity[2] end
function Starfield:setVelocity(vx, vy) self._velocity = { vx, vy } end

-- star_size: a pixel size, or nil for automatic. Rebuilds the star sprite.
function Starfield:getStarSize() return self._star_size end
function Starfield:setStarSize(value)
  self._star_size = value and math.max(1, math.floor(value)) or nil
  self:_rebuild_layers()
end

-- ---------------------------------------------------------------------------
-- The three methods you call from a game loop
-- ---------------------------------------------------------------------------

-- Advance the animation by dt seconds (time since the last frame). Call once
-- per frame, before draw(). Movement is frame-rate independent.
function Starfield:update(dt)
  self._twinkle_clock = self._twinkle_clock + dt * self.twinkle_speed
  local vx, vy = self._velocity[1], self._velocity[2]
  if vx ~= 0 or vy ~= 0 then
    for _, layer in ipairs(self._layers) do
      layer.offset_x = (layer.offset_x + vx * dt * layer.factor) % self._width
      layer.offset_y = (layer.offset_y + vy * dt * layer.factor) % self._height
    end
  end
end

-- Shift the stars by (dx, dy) pixels right now. This is for games where the
-- *camera* moves through a world (Defender, Mario, any side-scroller). Each
-- frame, after you move the camera, push the stars the opposite way:
--
--     camera_x = camera_x + player_vx * dt       -- camera follows the player
--     field:scroll(-player_vx * dt, 0)           -- so the stars stream past
--
-- Parallax layers automatically move at their own depth-scaled rates, which
-- is what sells the effect. scroll() and a nonzero velocity simply add.
function Starfield:scroll(dx, dy)
  for _, layer in ipairs(self._layers) do
    layer.offset_x = (layer.offset_x + dx * layer.factor) % self._width
    layer.offset_y = (layer.offset_y + dy * layer.factor) % self._height
  end
end

-- Draw the field with its top-left corner at (dest_x, dest_y) (default 0, 0).
-- Call this before drawing ships, aliens and score so the stars sit behind
-- everything. Leaves love.graphics color reset to white.
function Starfield:draw(dest_x, dest_y)
  local left, top = dest_x or 0, dest_y or 0
  local w, h = self._width, self._height

  if self.background then
    love.graphics.setColor(self.background)
    love.graphics.rectangle("fill", left, top, w, h)
  end

  local t = self._twinkle_clock
  local twinkling = self.twinkle_speed > 0
  local img = star_pixel()

  for _, layer in ipairs(self._layers) do
    local batch = layer.batch
    batch:clear()
    local size, alpha = layer.size, layer.alpha
    local ox, oy = layer.offset_x, layer.offset_y
    for _, s in ipairs(layer.stars) do
      -- s = {nx, ny, color, period, phase}
      if not (twinkling and (t + s[5]) % s[4] > s[4] * TWINKLE_DUTY) then
        local c = s[3]
        batch:setColor(c[1], c[2], c[3], alpha)
        local x = (s[1] * w + ox) % w
        local y = (s[2] * h + oy) % h
        batch:add(math.floor(x) + left, math.floor(y) + top, 0, size, size)
      end
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(batch)
  end
  love.graphics.setColor(1, 1, 1, 1)
end

-- ---------------------------------------------------------------------------
-- Occasional operations
-- ---------------------------------------------------------------------------

-- Fit the field to a new (width, height) — call from love.resize. The star
-- layout is preserved (positions scale with the field) and, when using
-- density, stars are added or removed to keep the same crowdedness.
function Starfield:resize(width, height)
  self._width = math.floor(width)
  self._height = math.floor(height)
  self:_populate(self:_target_count())
  self:_rebuild_layers()
end

-- ---------------------------------------------------------------------------
-- Internals
-- ---------------------------------------------------------------------------

function Starfield:_target_count()
  if self._explicit_count ~= nil then
    return math.max(0, math.floor(self._explicit_count))
  end
  local area = self._width * self._height
  return math.max(1, math.floor(self._density * area / PIXELS_PER_STAR + 0.5))
end

function Starfield:_make_star()
  local rng = self._rng
  return {
    rng:random(),                                                        -- nx: x as a fraction of width
    rng:random(),                                                        -- ny: y as a fraction of height
    self._palette[rng:random(#self._palette)],                           -- color
    TWINKLE_PERIOD_LO + rng:random() * (TWINKLE_PERIOD_HI - TWINKLE_PERIOD_LO), -- blink period (s)
    rng:random() * TWINKLE_PERIOD_HI,                                    -- blink phase, so stars desync
  }
end

-- Add or remove stars so the layers hold `total` between them, distributed
-- evenly, without disturbing existing stars.
function Starfield:_populate(total)
  local n = #self._layers
  for i, layer in ipairs(self._layers) do
    local want = math.floor(total / n) + ((i - 1) < (total % n) and 1 or 0)
    while #layer.stars < want do
      layer.stars[#layer.stars + 1] = self:_make_star()
    end
    for j = #layer.stars, want + 1, -1 do
      layer.stars[j] = nil
    end
  end
end

-- Set each layer's star size and alpha (far layers get smaller, fainter
-- stars), and give it a fresh SpriteBatch sized to its star count.
function Starfield:_rebuild_layers()
  local base = self._star_size
  if base == nil then
    -- A size that reads well at this resolution: 1 px up to ~600 px tall
    -- windows, 2 px up to ~1200, and so on.
    base = self._height >= 600 and math.max(1, math.floor(self._height / 600) + 1) or 1
  end
  local img = star_pixel()
  for _, layer in ipairs(self._layers) do
    layer.size = math.max(1, math.floor(base * layer.factor + 0.5))
    layer.alpha = 0.45 + 0.55 * layer.factor
    layer.batch = love.graphics.newSpriteBatch(img, math.max(1, #layer.stars), "stream")
  end
end

-- Exported so games can pass e.g. Starfield.GALAXIAN_PALETTE explicitly.
Starfield.GALAXIAN_PALETTE = GALAXIAN_PALETTE
Starfield.WHITE_PALETTE = WHITE_PALETTE

return Starfield
