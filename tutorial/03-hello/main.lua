-- Chapter 3: the smallest LÖVE game.
-- LÖVE calls love.draw about 60 times a second; whatever it draws is shown.

function love.draw()
    love.graphics.print("Hello, LÖVE!", 350, 290)
end
