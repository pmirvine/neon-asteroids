--[[ sfx.lua — arcade sound effects synthesized at startup, Williams/Defender style.

No audio files: every effect is computed sample by sample into a SoundData.
The signature Williams-board explosion is "sample-and-hold" noise: a random
value is held for a while, then replaced, and the replacement rate sweeps
downward — so the crunch falls in pitch as it fades. Everything is lightly
bit-crushed for that 8-bit DAC grit.

    Sfx.load()
    Sfx.play("fire", pan, pitch, volume)   -- pan -1..1
    Sfx.loop("thrust", true / false)

Synthesis approach adapted from retro-starfield-starter-kit's src/retro/sfx.lua (MIT).
]]

local Sfx = { enabled = false, muted = false, volume = 0.8 }

local RATE = 44100
local TAU = math.pi * 2
local rng

-- per-effect mix levels
local LEVEL = {
    fire = 0.42, thrust = 0.55, beat1 = 0.7, beat2 = 0.7,
    ufo_big = 0.28, ufo_small = 0.26, ufo_fire = 0.5,
    boom_small = 0.7, boom_medium = 0.85, boom_large = 1.0,
    player_die = 1.0, smart_bomb = 1.0,
}

-- simultaneous voices per effect (older voices are stolen when all are busy)
local VOICES = { fire = 6, boom_small = 6, boom_medium = 5, boom_large = 5, ufo_fire = 4 }
local DEFAULT_VOICES = 2

local bank = {}
local loops = {}

-- ============================================================
-- SYNTH HELPERS
-- ============================================================
local function render(duration, gen)
    local n = math.floor(RATE * duration)
    local data = love.sound.newSoundData(n, RATE, 16, 1)
    for i = 0, n - 1 do
        local v = gen(i / RATE, i / n)
        if v > 1 then v = 1 elseif v < -1 then v = -1 end
        data:setSample(i, v)
    end
    return data
end

local function square(phase, duty)
    return (phase % 1) < (duty or 0.5) and 1 or -1
end

local function tri(phase)
    return 4 * math.abs(phase % 1 - 0.5) - 1
end

local function crush(v, bits)
    local levels = 2 ^ (bits - 1)
    return math.floor(v * levels + 0.5) / levels
end

local function attack(t, seconds)
    return math.min(1, t / seconds)
end

-- Williams sample-and-hold noise: hold rate sweeps from rateHi to rateLo.
-- rumbleHz/rumble add a falling sine underneath for body.
local function crunch(duration, rateHi, rateLo, volume, rumbleHz, rumble, curve)
    local hold, acc, lp, ph = 0, 1, 0, 0
    return render(duration, function(t, p)
        local rate = rateHi * (rateLo / rateHi) ^ p
        acc = acc + rate / RATE
        if acc >= 1 then
            acc = acc % 1
            hold = rng:random() * 2 - 1
        end
        lp = lp + (hold - lp) * 0.35
        local v = lp
        if rumble then
            ph = ph + rumbleHz * (1 - 0.5 * p) / RATE
            v = v + math.sin(ph * TAU) * rumble
        end
        local env = attack(t, 0.003) * (1 - p) ^ (curve or 2)
        return crush(v * env * volume, 6)
    end)
end

-- Square-wave notes played back to back, with a touch of vibrato.
local function notes(freqs, noteLength, volume, vibrato)
    local ph = 0
    local total = #freqs * noteLength
    return render(total, function(t)
        local idx = math.min(#freqs, math.floor(t / noteLength) + 1)
        local local_t = t - (idx - 1) * noteLength
        local f = freqs[idx] * (1 + (vibrato or 0) * math.sin(t * TAU * 7))
        ph = ph + f / RATE
        local env = attack(local_t, 0.004) * (1 - local_t / noteLength) ^ 0.6
        return (square(ph, 0.5) * 0.6 + tri(ph * 2) * 0.4) * env * volume
    end)
end

-- ============================================================
-- EFFECTS
-- ============================================================
local function build()
    local fx = {}

    -- Player laser: a bright falling zap with a sub-octave for body.
    do
        local p1, p2 = 0, 0
        fx.fire = render(0.2, function(t, p)
            local f = 2400 * math.exp(-t * 16) + 220
            p1 = p1 + f / RATE
            p2 = p2 + f * 0.5 / RATE
            local v = square(p1, 0.5) * 0.55 + square(p2, 0.25) * 0.3
            return crush(v * attack(t, 0.002) * (1 - p) ^ 1.4 * 0.6, 5)
        end)
    end

    fx.boom_small = crunch(0.45, 9000, 700, 0.8, nil, nil, 2.2)
    fx.boom_medium = crunch(0.85, 7000, 350, 0.85, 70, 0.25, 2.0)
    fx.boom_large = crunch(1.5, 6000, 120, 0.9, 52, 0.45, 1.8)

    -- Ship destroyed: crunch plus a long falling, warbling wail.
    do
        local hold, acc, lp, ph = 0, 1, 0, 0
        fx.player_die = render(2.4, function(t, p)
            local rate = 6000 * (80 / 6000) ^ p
            acc = acc + rate / RATE
            if acc >= 1 then acc = acc % 1; hold = rng:random() * 2 - 1 end
            lp = lp + (hold - lp) * 0.35
            local f = 900 * (1 - p) ^ 2 + 40 + 30 * math.sin(t * TAU * 14) * (1 - p)
            ph = ph + f / RATE
            local tone = square(ph, 0.5) * 0.4 * (1 - p)
            local env = attack(t, 0.003) * (1 - p) ^ 1.5
            return crush((lp * 0.8 + tone) * env * 0.75, 6)
        end)
    end

    -- Smart bomb: a huge white-noise blast collapsing into a deep rumble.
    fx.smart_bomb = crunch(2.2, 15000, 60, 0.9, 42, 0.6, 1.3)

    -- Engine: doubly low-passed noise, looped.
    do
        local lp1, lp2 = 0, 0
        fx.thrust = render(0.6, function()
            local n = rng:random() * 2 - 1
            lp1 = lp1 + (n - lp1) * 0.12
            lp2 = lp2 + (lp1 - lp2) * 0.12
            return lp2 * 2.2
        end)
    end

    -- Saucer warbles. Whole LFO cycles and a whole number of carrier cycles
    -- per loop, so the loop point is seamless.
    local function warble(base, depth, lfo, volume)
        local ph = 0
        return render(0.5, function(t)
            local f = base + depth * math.sin(TAU * lfo * t)
            ph = ph + f / RATE
            return square(ph, 0.5) * volume
        end)
    end
    fx.ufo_big = warble(330, 90, 8, 0.5)
    fx.ufo_small = warble(760, 220, 12, 0.45)

    do
        local ph = 0
        fx.ufo_fire = render(0.14, function(t, p)
            ph = ph + (1500 - 1000 * p) / RATE
            return tri(ph) * (1 - p) * 0.7
        end)
    end

    -- Heartbeat thumps.
    local function beat(freq)
        local ph, lp = 0, 0
        return render(0.16, function(t)
            ph = ph + freq / RATE
            lp = lp + (square(ph) - lp) * 0.08
            return lp * math.exp(-t * 18)
        end)
    end
    fx.beat1 = beat(62)
    fx.beat2 = beat(55)

    fx.extra_life = notes({ 784, 988, 1175, 1568, 1175, 1568, 2093 }, 0.065, 0.45)
    fx.game_over = notes({ 523, 440, 349, 262, 196 }, 0.24, 0.45, 0.02)

    -- Hyperspace: a rising, warbling whoop.
    do
        local ph = 0
        fx.hyperspace = render(0.5, function(t, p)
            local f = 120 + 2600 * p * p
            f = f * (1 + 0.12 * math.sin(t * TAU * 40))
            ph = ph + f / RATE
            return crush(square(ph, 0.3) * attack(t, 0.005) * (1 - p) ^ 0.7 * 0.45, 5)
        end)
    end

    -- Materialize: two detuned triangles sweeping up with tremolo.
    do
        local p1, p2 = 0, 0
        fx.warp_in = render(0.6, function(t, p)
            local f = 200 + 1300 * p
            p1 = p1 + f / RATE
            p2 = p2 + f * 1.01 / RATE
            local trem = 0.6 + 0.4 * math.sin(t * TAU * 30)
            return (tri(p1) + tri(p2)) * 0.25 * trem * math.sin(math.pi * p)
        end)
    end

    -- New wave: three quick upward zips.
    do
        local ph = 0
        fx.wave_start = render(0.42, function(t)
            local k = (t % 0.14) / 0.14
            ph = ph + (300 + 1400 * k) / RATE
            return square(ph, 0.5) * (1 - k) * 0.35
        end)
    end

    -- Game start: a launch sweep with a crunchy tail.
    do
        local ph, hold, acc = 0, 0, 1
        fx.start = render(0.9, function(t, p)
            local f = 150 + 1700 * p
            f = f * (1 + 0.05 * math.sin(t * TAU * 25))
            ph = ph + f / RATE
            acc = acc + 3000 / RATE
            if acc >= 1 then acc = acc % 1; hold = rng:random() * 2 - 1 end
            local v = square(ph, 0.5) * 0.45 + hold * 0.25 * p
            return crush(v * attack(t, 0.01) * (1 - p) ^ 0.5 * 0.6, 5)
        end)
    end

    do
        local ph = 0
        fx.blip = render(0.07, function(t, p)
            ph = ph + 880 / RATE
            return square(ph) * (1 - p) * 0.3
        end)
    end

    return fx
end

-- ============================================================
-- PLAYBACK
-- ============================================================
local function setPan(src, pan)
    pan = math.max(-1, math.min(1, pan or 0)) * 0.8
    src:setPosition(pan, 0, -math.sqrt(1 - pan * pan))
end

function Sfx.load()
    local ok, err = pcall(function()
        rng = love.math.newRandomGenerator(1981)
        love.audio.setDistanceModel("none") -- position only pans, never attenuates
        for name, data in pairs(build()) do
            local voices = {}
            for i = 1, VOICES[name] or DEFAULT_VOICES do
                voices[i] = love.audio.newSource(data, "static")
            end
            bank[name] = { voices = voices, nextVoice = 1 }
        end
        love.audio.setVolume(Sfx.volume)
    end)
    Sfx.enabled = ok
    if not ok then print("sound disabled: " .. tostring(err)) end
end

function Sfx.play(name, pan, pitch, volume)
    if not Sfx.enabled then return end
    local entry = bank[name]
    if not entry then return end

    local voice
    for _, v in ipairs(entry.voices) do
        if not v:isPlaying() then voice = v; break end
    end
    if not voice then
        voice = entry.voices[entry.nextVoice]
        entry.nextVoice = entry.nextVoice % #entry.voices + 1
        voice:stop()
    end
    voice:setPitch(pitch or 1)
    voice:setVolume((volume or 1) * (LEVEL[name] or 1))
    setPan(voice, pan)
    voice:play()
end

function Sfx.loop(name, on)
    if not Sfx.enabled then return end
    local src = loops[name]
    if on then
        if not src then
            local entry = bank[name]
            if not entry then return end
            src = entry.voices[1]:clone()
            src:setLooping(true)
            src:setVolume(LEVEL[name] or 1)
            setPan(src, 0)
            loops[name] = src
        end
        if not src:isPlaying() then src:play() end
    elseif src and src:isPlaying() then
        src:stop()
    end
end

function Sfx.setLoopPan(name, pan)
    if loops[name] then setPan(loops[name], pan) end
end

function Sfx.stopLoops()
    for _, src in pairs(loops) do src:stop() end
end

function Sfx.toggleMute()
    Sfx.muted = not Sfx.muted
    love.audio.setVolume(Sfx.muted and 0 or Sfx.volume)
end

return Sfx
