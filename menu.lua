function initializeMainMenu()
    menuItems = {"New Game","Endless Mode","Settings"}
    menuCursorPos = 1
end

function updateMainMenu()

end

function mainMenuKeyHandler(key)
    if key == "up" and menuCursorPos > 1 then
        menuCursorPos = menuCursorPos - 1
    elseif key == "down" and menuCursorPos < #menuItems then
        menuCursorPos = menuCursorPos + 1
    elseif key == "enter" or key == "space" or key == "z" or key == "n" or key == "return" then -- select menu item
        selectMenuItem()
    end
end

function selectMenuItem()
    if menuCursorPos == 1 then
        newGame()
    elseif menuCursorPos == 2 then
        notImplemented=1
    elseif menuCursorPos == 3 then
        notImplemented=1
    end
end

function drawMainMenu()
    love.graphics.setBackgroundColor(light_color.r,light_color.g,light_color.b)

    love.graphics.setColor(dark_color.r,dark_color.g,dark_color.b)
    love.graphics.setFont(font)
    love.graphics.print("Eat food. Grow long. Eat your tail.",20,20)

    for idx,item in pairs(menuItems) do
        if idx == menuCursorPos then
            str = string.format("> %s",item)
        else
            str = string.format("  %s",item)
        end
        love.graphics.print(str,20,20*(idx+2))
    end
end