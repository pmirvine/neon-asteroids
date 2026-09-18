-- Vector Asteroids Game
-- Glowing vector style with screen shake and particle effects
-- Pure Love2D, no external assets needed

-- ============================================================
-- CONFIGURATION
-- ============================================================
local SCREEN = { width = 800, height = 600 }

-- Player settings
local PLAYER_ROTATION_SPEED = 400 -- degrees per second
local PLAYER_THRUST = 1200
local PLAYER_FRICTION = 0.98 -- velocity multiplier per 1/60s
local PLAYER_MAX_SPEED = 500
local BULLET_SPEED = 600
local BULLET_LIFE = 2.0 -- seconds
local MAX_BULLETS = 10

-- Asteroid settings
local ASTEROID_COUNT = 4 -- starting count
local ASTEROID_SIZES = { large = 40, medium = 22, small = 12 } -- radius in pixels
local ASTEROID_SCORES = { large = 20, medium = 50, small = 100 }
local ASTEROID_CHILDREN = 2 -- pieces spawned when a large/medium asteroid splits

-- Explosion settings
local EXPLOSION_PARTICLES = { large = 40, medium = 25, small = 12 }

-- Screen shake settings
local SCREEN_SHAKE_DECAY = 8.0 -- how fast shake fades
local MAX_SCREEN_SHAKE = 15 -- maximum offset

-- ============================================================
-- GAME STATE
-- ============================================================
local state = {
    score = 0,
    lives = 3,
    level = 1,
    gameOver = false,
    levelComplete = false,
    screenShakeX = 0,
    screenShakeY = 0,
    shakeIntensity = 0,
}

local player = nil
local asteroids = {}
local bullets = {}
local particles = {}
local stars = {}
local fonts = {}

-- ============================================================
-- HELPERS
-- ============================================================
local function distance(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function wrap(obj, margin)
    if obj.x < -margin then obj.x = SCREEN.width + margin end
    if obj.x > SCREEN.width + margin then obj.x = -margin end
    if obj.y < -margin then obj.y = SCREEN.height + margin end
    if obj.y > SCREEN.height + margin then obj.y = -margin end
end

local function generateStars()
    stars = {}
    for i = 1, 200 do
        stars[i] = { (i * 137) % SCREEN.width, (i * 219) % SCREEN.height }
    end
end

-- ============================================================
-- ASTEROID GENERATION
-- ============================================================
local function generateAsteroidVertices(radius)
    local n = 8 + math.random(0, 6) -- 8 to 14 points
    local vertices = {}
    for i = 0, n - 1 do
        local a = (i / n) * math.pi * 2
        local r = radius * (0.7 + math.random() * 0.3)
        vertices[#vertices + 1] = { x = math.cos(a) * r, y = math.sin(a) * r }
    end
    return vertices
end

local function newAsteroid(x, y, size, speed)
    local radius = ASTEROID_SIZES[size]
    return {
        x = x, y = y,
        vx = (math.random() - 0.5) * speed,
        vy = (math.random() - 0.5) * speed,
        radius = radius,
        size = size,
        angle = math.random() * math.pi * 2,
        rotationSpeed = (math.random() - 0.5) * 1.5, -- radians per second
        vertices = generateAsteroidVertices(radius),
    }
end

local function spawnAsteroids(count)
    local margin = ASTEROID_SIZES.large
    local safeDist = math.min(SCREEN.width, SCREEN.height) / 3

    for _ = 1, count do
        local x, y
        -- avoid spawning on the player
        for _ = 1, 20 do
            x = math.random(margin, SCREEN.width - margin)
            y = math.random(margin, SCREEN.height - margin)
            if not player or distance(x, y, player.x, player.y) > safeDist then break end
        end
        asteroids[#asteroids + 1] = newAsteroid(x, y, "large", 60)
    end
end

local function spawnAsteroidFromParent(parent)
    local childSize = parent.size == "large" and "medium" or "small"
    local child = newAsteroid(parent.x, parent.y, childSize, 80)
    asteroids[#asteroids + 1] = child
end

-- ============================================================
-- INITIALIZATION
-- ============================================================
local function resetPlayer(invulnerable)
    player = {
        x = SCREEN.width / 2,
        y = SCREEN.height / 2,
        vx = 0, vy = 0,
        angle = -90, -- facing up in degrees
        radius = 15,
        invulnerable = invulnerable, -- seconds of invulnerability
    }
end

local function resetGame()
    state.score = 0
    state.lives = 3
    state.level = 1
    state.gameOver = false
    state.levelComplete = false
    state.screenShakeX = 0
    state.screenShakeY = 0
    state.shakeIntensity = 0
    asteroids = {}
    bullets = {}
    particles = {}

    resetPlayer(1.5)
    spawnAsteroids(ASTEROID_COUNT)
end

local function resetLevel()
    state.level = state.level + 1
    state.levelComplete = false
    bullets = {}
    player.invulnerable = 1.5
    spawnAsteroids(ASTEROID_COUNT * state.level)
end

function love.load()
    love.window.setMode(SCREEN.width, SCREEN.height, { resizable = true })
    love.window.setTitle("Vector Asteroids")

    fonts.small = love.graphics.newFont(14)
    fonts.medium = love.graphics.newFont(20)
    fonts.hud = love.graphics.newFont(24)
    fonts.large = love.graphics.newFont(28)
    fonts.huge = love.graphics.newFont(48)

    generateStars()
    resetGame()
end

function love.resize(w, h)
    SCREEN.width, SCREEN.height = w, h
    generateStars()
end

-- ============================================================
-- SCREEN SHAKE
-- ============================================================
local function shakeScreen(intensity)
    state.shakeIntensity = math.min(MAX_SCREEN_SHAKE, math.max(state.shakeIntensity, intensity))
end

local function updateShake(dt)
    if state.shakeIntensity > 0.1 then
        local angle = math.random() * math.pi * 2
        local offset = state.shakeIntensity * (math.random() - 0.5) * 2
        state.screenShakeX = math.cos(angle) * offset
        state.screenShakeY = math.sin(angle) * offset
        state.shakeIntensity = state.shakeIntensity - SCREEN_SHAKE_DECAY * dt
    else
        state.screenShakeX = 0
        state.screenShakeY = 0
        state.shakeIntensity = 0
    end
end

-- ============================================================
-- PARTICLES
-- ============================================================
local function addParticle(x, y, angle, speed, life, size, r, g, b)
    particles[#particles + 1] = {
        x = x, y = y,
        vx = math.cos(angle) * speed,
        vy = math.sin(angle) * speed,
        life = life,
        maxLife = life,
        size = size,
        r = r, g = g, b = b,
    }
end

local function spawnExplosion(x, y, count)
    for _ = 1, count do
        addParticle(x, y,
            math.random() * math.pi * 2,
            30 + math.random() * 80,
            0.5 + math.random() * 0.8,
            1 + math.random() * 2,
            1, 0.9, 0.6)
    end
end

local function updateParticles(dt)
    for i = #particles, 1, -1 do
        local p = particles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.vx = p.vx * 0.98 -- slight friction
        p.vy = p.vy * 0.98
        p.life = p.life - dt

        if p.life <= 0 then
            table.remove(particles, i)
        end
    end
end

-- ============================================================
-- COLLISION DETECTION
-- ============================================================
local function circlesCollide(a, b)
    return distance(a.x, a.y, b.x, b.y) < a.radius + b.radius
end

local function handlePlayerHit()
    -- Big explosion at player position
    spawnExplosion(player.x, player.y, 60)
    shakeScreen(MAX_SCREEN_SHAKE)

    state.lives = state.lives - 1

    if state.lives <= 0 then
        state.gameOver = true
        asteroids = {}
        bullets = {}
    else
        -- Respawn with invulnerability
        resetPlayer(3.0)
    end
end

local function checkCollisions()
    -- Bullet vs Asteroid
    for i = #asteroids, 1, -1 do
        local a = asteroids[i]
        for j = #bullets, 1, -1 do
            if circlesCollide(bullets[j], a) then
                table.remove(bullets, j)

                -- Score
                state.score = state.score + ASTEROID_SCORES[a.size] * state.level

                -- Explosion particles and screen shake (scales with asteroid size)
                spawnExplosion(a.x, a.y, EXPLOSION_PARTICLES[a.size])
                shakeScreen(2 + a.radius * 0.3)

                -- Split asteroid into smaller ones
                if a.size ~= "small" then
                    for _ = 1, ASTEROID_CHILDREN do
                        spawnAsteroidFromParent(a)
                    end
                end

                table.remove(asteroids, i)
                break
            end
        end
    end

    -- Player vs Asteroid (when not invulnerable)
    if not state.gameOver and player.invulnerable <= 0 then
        for _, a in ipairs(asteroids) do
            if circlesCollide(player, a) then
                handlePlayerHit()
                break
            end
        end
    end

    -- Check level complete
    if #asteroids == 0 and not state.gameOver then
        state.levelComplete = true
    end
end

-- ============================================================
-- INPUT HANDLING
-- ============================================================
local function isDown(...)
    return love.keyboard.isDown(...)
end

local function fireBullet()
    if #bullets >= MAX_BULLETS then return end

    local ang = math.rad(player.angle)
    bullets[#bullets + 1] = {
        x = player.x + math.cos(ang) * player.radius,
        y = player.y + math.sin(ang) * player.radius,
        vx = math.cos(ang) * BULLET_SPEED + player.vx,
        vy = math.sin(ang) * BULLET_SPEED + player.vy,
        radius = 2,
        life = BULLET_LIFE,
    }
end

function love.keypressed(key, scancode, isrepeat)
    if key == "escape" then
        love.event.quit()
    elseif key == "space" and not isrepeat then
        if state.gameOver then
            resetGame()
        elseif state.levelComplete then
            resetLevel()
        else
            fireBullet()
        end
    end
end

-- ============================================================
-- UPDATE LOOP
-- ============================================================
local function update(dt)
    if state.gameOver then return end

    -- Player rotation
    if isDown("left", "a") then
        player.angle = player.angle - PLAYER_ROTATION_SPEED * dt
    end
    if isDown("right", "d") then
        player.angle = player.angle + PLAYER_ROTATION_SPEED * dt
    end

    -- Thrust
    local ang = math.rad(player.angle)
    if isDown("up", "w") then
        player.vx = player.vx + math.cos(ang) * PLAYER_THRUST * dt
        player.vy = player.vy + math.sin(ang) * PLAYER_THRUST * dt

        -- Add thrust particles at the back of the ship
        local bx = player.x - math.cos(ang) * player.radius
        local by = player.y - math.sin(ang) * player.radius
        for _ = 1, 2 do
            addParticle(bx, by,
                ang + math.pi + (math.random() - 0.5) * 1.5,
                40 + math.random() * 60,
                0.3 + math.random() * 0.2,
                1 + math.random() * 1.5,
                0.8, 0.6, 0.9)
        end
    end

    -- Apply friction (frame-rate independent)
    local friction = PLAYER_FRICTION ^ (dt * 60)
    player.vx = player.vx * friction
    player.vy = player.vy * friction

    -- Cap speed
    local speed = math.sqrt(player.vx * player.vx + player.vy * player.vy)
    if speed > PLAYER_MAX_SPEED then
        player.vx = (player.vx / speed) * PLAYER_MAX_SPEED
        player.vy = (player.vy / speed) * PLAYER_MAX_SPEED
    end

    -- Move player and wrap around screen edges
    player.x = player.x + player.vx * dt
    player.y = player.y + player.vy * dt
    wrap(player, 20)

    -- Invulnerability timer
    if player.invulnerable > 0 then
        player.invulnerable = player.invulnerable - dt
    end

    -- Update bullets
    for i = #bullets, 1, -1 do
        local b = bullets[i]
        b.x = b.x + b.vx * dt
        b.y = b.y + b.vy * dt
        b.life = b.life - dt
        wrap(b, 5)

        if b.life <= 0 then
            table.remove(bullets, i)
        end
    end

    -- Update asteroids
    for _, a in ipairs(asteroids) do
        a.x = a.x + a.vx * dt
        a.y = a.y + a.vy * dt
        a.angle = a.angle + a.rotationSpeed * dt
        wrap(a, a.radius)
    end
end

-- ============================================================
-- MAIN LOOP
-- ============================================================
function love.update(dt)
    dt = math.min(dt, 0.1) -- cap dt to avoid physics explosions

    update(dt)
    checkCollisions()
    updateParticles(dt)
    updateShake(dt)
end

-- ============================================================
-- DRAWING HELPERS
-- ============================================================
local function drawStars()
    love.graphics.setColor(0.8, 0.75, 0.65, 0.4)
    love.graphics.setPointSize(1)
    love.graphics.points(stars)
end

-- Returns the asteroid outline as a flat {x1, y1, x2, y2, ...} list in world space
local function asteroidPoints(a)
    local c, s = math.cos(a.angle), math.sin(a.angle)
    local points = {}
    for _, v in ipairs(a.vertices) do
        points[#points + 1] = a.x + v.x * c - v.y * s
        points[#points + 1] = a.y + v.x * s + v.y * c
    end
    return points
end

local function drawAsteroid(a)
    local points = asteroidPoints(a)

    -- Outer glow effect (jittered, translucent strokes)
    love.graphics.setColor(0.9, 0.7, 0.4, 0.15)
    love.graphics.setLineWidth(6)
    love.graphics.polygon("line", points)
    love.graphics.setLineWidth(4)
    love.graphics.polygon("line", points)

    -- Main vector shape with thick stroke
    love.graphics.setColor(0.9, 0.75, 0.55, 1)
    love.graphics.setLineWidth(2)
    love.graphics.polygon("line", points)

    -- Glow dots on the vertices
    love.graphics.setColor(1, 0.9, 0.7, 0.6)
    for i = 1, #points, 2 do
        love.graphics.circle("fill", points[i], points[i + 1], 1.5)
    end
end

local function shipPoints(x, y, ang, r)
    local noseX = x + math.cos(ang) * r * 1.3
    local noseY = y + math.sin(ang) * r * 1.3
    local leftX = x + math.cos(ang + 2.5) * r
    local leftY = y + math.sin(ang + 2.5) * r
    local rightX = x + math.cos(ang - 2.5) * r
    local rightY = y + math.sin(ang - 2.5) * r
    return { noseX, noseY, leftX, leftY, rightX, rightY }
end

local function drawPlayer()
    -- Blink when invulnerable
    if player.invulnerable > 0 and math.floor(player.invulnerable * 10) % 2 == 0 then return end

    local points = shipPoints(player.x, player.y, math.rad(player.angle), player.radius)

    -- Outer glow effect
    love.graphics.setColor(0.3, 0.5, 0.9, 0.2)
    love.graphics.setLineWidth(8)
    love.graphics.polygon("line", points)
    love.graphics.setLineWidth(5)
    love.graphics.polygon("line", points)

    -- Fill with semi-transparent color for depth
    love.graphics.setColor(0.95, 0.9, 1, 0.25)
    love.graphics.polygon("fill", points)

    -- Main ship triangle with thick vector lines
    love.graphics.setColor(0.9, 0.85, 1, 1)
    love.graphics.setLineWidth(2)
    love.graphics.polygon("line", points)
end

local function drawBullet(b)
    -- Glow effect with overlapping circles
    love.graphics.setColor(0.9, 0.9, 0.7, 0.2)
    love.graphics.circle("fill", b.x, b.y, 6)
    love.graphics.setColor(0.9, 0.9, 0.7, 0.4)
    love.graphics.circle("fill", b.x, b.y, 4)

    -- Bright center
    love.graphics.setColor(1, 1, 0.9, 1)
    love.graphics.circle("fill", b.x, b.y, 2)
end

local function drawParticles()
    for _, p in ipairs(particles) do
        local alpha = p.life / p.maxLife
        love.graphics.setColor(p.r, p.g, p.b, alpha)
        love.graphics.circle("fill", p.x, p.y, p.size)
    end
end

local function drawMiniShip(x, y, angle, r)
    love.graphics.setColor(0.6, 0.5, 0.9, 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.polygon("line", shipPoints(x, y, angle, r))
end

local function drawHUD()
    -- Score - top left
    love.graphics.setColor(1, 0.9, 0.7, 0.9)
    love.graphics.setFont(fonts.hud)
    love.graphics.print("SCORE: " .. state.score, 30, 30)

    -- Level - top center
    love.graphics.printf("LEVEL " .. state.level, 0, 30, SCREEN.width, "center")

    -- Lives - top right (as ships)
    for i = 1, state.lives do
        drawMiniShip(SCREEN.width - 30 - (i - 1) * 25, 45, -math.pi / 2, 9)
    end

    -- Controls help (bottom left)
    love.graphics.setColor(0.6, 0.6, 0.6, 0.5)
    love.graphics.setFont(fonts.small)
    love.graphics.print("ARROWS / WASD: Move    SPACE: Shoot    ESC: Quit", 30, SCREEN.height - 30)
end

local function drawLevelComplete()
    love.graphics.setColor(0.7, 1, 0.7, 0.8)
    love.graphics.setFont(fonts.large)
    love.graphics.printf("PRESS SPACE FOR NEXT LEVEL", 0, SCREEN.height / 2 - 14, SCREEN.width, "center")
end

local function drawGameOver()
    -- Dark overlay
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, SCREEN.width, SCREEN.height)

    love.graphics.setColor(1, 0.3, 0.3, 1)
    love.graphics.setFont(fonts.huge)
    love.graphics.printf("GAME OVER", 0, SCREEN.height / 2 - 60, SCREEN.width, "center")

    love.graphics.setColor(1, 0.9, 0.7, 0.9)
    love.graphics.setFont(fonts.large)
    love.graphics.printf("SCORE: " .. state.score, 0, SCREEN.height / 2 + 5, SCREEN.width, "center")

    love.graphics.setFont(fonts.medium)
    love.graphics.printf("PRESS SPACE TO RESTART", 0, SCREEN.height / 2 + 50, SCREEN.width, "center")
end

-- ============================================================
-- RENDERING: VECTOR STYLE WITH GLOWING EFFECTS
-- ============================================================
function love.draw()
    -- Clear with dark space background
    love.graphics.clear(0.05, 0.03, 0.1, 1)

    -- Apply screen shake offset
    love.graphics.push()
    love.graphics.translate(state.screenShakeX, state.screenShakeY)

    -- Draw subtle star field
    drawStars()

    -- Draw particles (behind everything for depth)
    drawParticles()

    -- Draw asteroids
    for _, a in ipairs(asteroids) do
        drawAsteroid(a)
    end

    -- Draw bullets
    for _, b in ipairs(bullets) do
        drawBullet(b)
    end

    -- Draw player ship
    if not state.gameOver then
        drawPlayer()
    end

    love.graphics.pop() -- undo screen shake transform

    -- HUD (not affected by screen shake)
    drawHUD()

    if state.levelComplete then
        drawLevelComplete()
    end

    if state.gameOver then
        drawGameOver()
    end
end
