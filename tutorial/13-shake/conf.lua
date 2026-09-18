function love.conf(t)
    t.identity = "neon-asteroids" -- save folder (high score)
    t.version = "11.5"

    t.window.title = "Neon Asteroids"
    t.window.width = 1280
    t.window.height = 720
    t.window.resizable = true
    t.window.minwidth = 640
    t.window.minheight = 360
    t.window.vsync = 1
    t.window.msaa = 0 -- antialiasing happens on the glow scene canvas instead

    t.modules.physics = false
    t.modules.video = false
end
