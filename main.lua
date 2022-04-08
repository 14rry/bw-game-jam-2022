local sti = require "sti"
require('menu')

function love.load()

    initializeMainMenu()

    gameState = 5 -- 0: normal, 1: rewinding, 2: win, 3: pause, 4: game over, 5: main menu

    levelFiles = { "level1.lua","level2.lua","level3.lua","level4.lua" }
    levelIndex = 1
    levelSizes = {{x=24,y=18},{x=24,y=18},{x=24,y=18},{x=24,y=18},{x=29,y=29},{x=33,y=48}}

    -- only two colors for bw game jam
    -- dark_color = { r = 59/255, g = 11/255, b = 51/255}
    -- light_color = { r = 216/255, g = 191/255, b = 170/255 }

    dark_color = { r = 144/255, g = 0/255, b = 255/255}
    light_color = { r = 255/255, g = 207/255, b = 219/255 }

    love.graphics.setBackgroundColor(dark_color.r,dark_color.g,dark_color.b)
    font = love.graphics.newFont( "Perfect DOS VGA 437 Win.ttf",28,"normal")
    outlineFont = love.graphics.newFont( "Perfect DOS VGA 437 Win.ttf",30,"normal")
    --love.keyboard.setKeyRepeat(false) -- uncomment for toggling direction instead of on/off dir

    -- properties that will remain constant
    start_length = 100
    snake_length_delta = 20 -- num points to add on pickup
    normal_move_rate = 40
    fast_turn_move_rate = 40 -- min speed (happens during turning)
    move_rate = normal_move_rate -- snake speed .. smaller number is faster
    dir_change_rate = 3.5/start_length -- snake turn speed
    snake_size = 7
    
    collision_size = 1 -- give some wiggle room
    max_rewind_amount = start_length/2
    numPickups = 8
    spriteSize = 32
    shakeDuration = 0
    levelStartTimer = 0

    levelIsLooped = false -- snake is looping around the whole level

    collided_object_center = { x = 0, y = 0 }

    -- load spritesheet
    spriteSheet = love.graphics.newImage("spritesheet.png")
    pickupSprite = love.graphics.newQuad(1*32,2*32,32,32,spriteSheet:getDimensions())
    starSprite = love.graphics.newQuad(2*32,2*32,32,32,spriteSheet:getDimensions())
    arrowSprite = love.graphics.newQuad(3*32,1*32,32,32,spriteSheet:getDimensions())
    headSprite = love.graphics.newQuad(3*32,0,32,32,spriteSheet:getDimensions())
    pizzaSprite = love.graphics.newQuad(3*32,3*32,32,32,spriteSheet:getDimensions())
    appleSprite = love.graphics.newQuad(4*32,2*32,32,32,spriteSheet:getDimensions())
    chickenSprite = love.graphics.newQuad(4*32,3*32,32,32,spriteSheet:getDimensions())

    foodSprites = {pizzaSprite,appleSprite,chickenSprite}

    -- set up audio
    backgroundMusic = love.audio.newSource("music.wav", "stream")
    backgroundMusic:setLooping(true)
    musicBPM = 126

    --newGame() -- now handled by main menu
end

function nextLevel()
    if levelIndex < #levelFiles then
        levelIndex = levelIndex + 1
        loadLevel()
        newGame()
    else
        levelIndex = 1
        gameState = 2
    end
end

function loadLevel()
    map = sti(levelFiles[levelIndex], { "box2d" })
    map:addCustomLayer("pickups", 3)

    -- not working for some reason, have to hard code
    -- mapWidth = map.layers["layer1"].width
    -- mapHeight = map.layers["layer1"].height

    mapWidth = levelSizes[levelIndex].x*spriteSize
    mapHeight = levelSizes[levelIndex].y*spriteSize

    print(mapWidth)

    -- Prepare physics world with horizontal and vertical gravity
	world = love.physics.newWorld(0, 0)

	-- Prepare collision objects
	map:box2d_init(world)
end

function gameOver()
    gameState = 4
    levelIndex = 1
end

function newGame()
    -- properties that could change during game
    dir_dir = 1
    move_dir_radians = math.pi/4
    timer = 0
    dir_sum = 0
    player_did_collide = false
    snake_length = start_length
    rewindCount = 1
    gameState = 0
    start_x = 4*32/snake_size
    start_y = 4*32/snake_size
    shakeDuration = 0
    levelStartTimer = 3
    levelIsLooped = false
    musicPitch = 1
    maxMusicPitch = 1.3
    musicPitchChangeRate = .01

    backgroundMusic:play()

    loadLevel()

    initSnakePoints()
    initPickups()
end

function initSnakePoints()
    snakePoints = {}
    rewindDirs = {} -- keep track of the direction the player was going
    tx = start_x
    ty = start_y

    table.insert(snakePoints,1, {
        x = tx, y = ty, r = 1
    })
end

function pickupCreationCollisionHandler(fixture)
    pickup_create_collision = true
    return false
end

function addSinglePickup()
    local pickupsLayer = map.layers["pickups"]
    local xr = 0
    local yr = 0
    while(1) do
        xr = math.random(mapWidth)
        yr = math.random(mapHeight)
        

        pickup_create_collision = false
        world:queryBoundingBox(xr-16,yr-16,xr+16,yr+16,pickupCreationCollisionHandler)

        if pickup_create_collision == false then
            break
        end
    end
    table.insert(pickupsLayer.sprites,1,{x=xr,y=yr,r=math.random()*math.pi*2,sprite = foodSprites[math.random(#foodSprites)]})
end

function initPickups()
    local pickupsLayer = map.layers["pickups"]
    pickupsLayer.sprites = {}
    for i = 1,numPickups do
        -- get world bounds
        -- select x,y pair at random
        -- 
        addSinglePickup()
    end

    -- Draw callback for Custom Layer
	function pickupsLayer:draw()
        scaleAmt = getDistanceFromMusicBeat()/2
		for _, sprite in pairs(self.sprites) do
            --love.graphics.setColor(1,1,1)
            love.graphics.draw(spriteSheet, sprite.sprite, 
                sprite.x,
                sprite.y,
                sprite.r,1+scaleAmt,1+scaleAmt,16,16
            )

		end
	end

    function pickupsLayer:update()
        for idx, sprite in pairs(self.sprites) do
            sprite.r = sprite.r + .05

            if sprite.r > 2*math.pi then
                sprite.r = sprite.r - 2*math.pi
            end
			-- check against player collision
            if box_collision_detect(sprite.x-16,sprite.y-16,32,32,snakePoints[1].x*snake_size-3,snakePoints[1].y*snake_size-3,snake_size,snake_size) then
                table.remove(self.sprites,idx)
                snake_length = snake_length + snake_length_delta
                addSinglePickup()
                --snakePoints[1].r = 2
            end
		end
    end
end

function box_collision_detect(x1,y1,w1,h1,x2,y2,w2,h2)
    if (x1 < x2 + w2 and
        x1 + w1 > x2 and
        y1 < y2 + h2 and
        h1 + y1 > y2) then
        return true
    else
        return false
    end
end

function collision_handler(collided_fixture)
    topLeftX, topLeftY, bottomRightX, bottomRightY = collided_fixture:getBoundingBox( 1 )
    player_did_collide = true
    collided_object_center.x = (bottomRightX + topLeftX) / 2
    collided_object_center.y = (bottomRightY + topLeftY) / 2
    return false -- tell the world queryBoundingBox function to stop its search
end

function getDistanceFromMusicBeat() -- return value between 0 and 1 with 1 being on beat and 0 off beat
    local musicPos = backgroundMusic:tell() -- how many seconds into the song
    local beatPos = (126/60)*musicPos
    local distFromBeat = (1-math.abs(beatPos - math.floor(beatPos) - 0.5)*2)
    return distFromBeat
end

function love.update(dt)

    print(getDistanceFromMusicBeat())

    if shakeDuration > 0 then
        shakeDuration = shakeDuration - dt
    end

    if levelStartTimer > 0 then
        levelStartTimer = levelStartTimer - dt
    elseif gameState == 0 then

        if move_dir_radians == nil then -- something went very wrong
            gameOver()
        end

        move_dir_radians = (move_dir_radians + dir_dir*dir_change_rate*dt*100) % (2*math.pi)

        local newX = snakePoints[1].x + math.cos(move_dir_radians)*move_rate*dt
        local newY = snakePoints[1].y - math.sin(move_dir_radians)*move_rate*dt

        player_did_collide = false

        -- check if player collides with wall
        world:queryBoundingBox( newX*snake_size,newY*snake_size,newX*snake_size+2,newY*snake_size+2,collision_handler)

        if player_did_collide == true then --knockback
            gameState = 1 -- start rewinding
            shakeDuration = 0.1
            rewindCount = 1
            -- pop out of if?
        end

        table.insert(snakePoints,1, {
            x = newX, y = newY, r = 1
        })

        table.insert(rewindDirs,1,move_dir_radians)

        if #snakePoints > snake_length then
            table.remove(snakePoints) -- remove last element
            table.remove(rewindDirs)
        end

        -- check for loops
        dir_sum = dir_sum + dir_change_rate
        if dir_sum > 2*math.pi then -- player did a full loop
            print("loop!!!")
            dir_sum = 0
        --elseif dir_sum > 4.7 then -- 3pi/2 loop.. speed up
            --move_rate = fast_turn_move_rate --move_rate + .2
        end

        -- check for self-intersects with lead point
        for idx, segment in ipairs(snakePoints) do
            if idx > 10 then
                if levelIsLooped == true and idx > #snakePoints-10 then
                    if (math.abs(segment.x - snakePoints[1].x) < collision_size*2) and (math.abs(segment.y - snakePoints[1].y) < collision_size*2) then
                        -- looped and caught the tail
                        nextLevel()
                    end
                else
                    if (math.abs(segment.x - snakePoints[1].x) < collision_size) and (math.abs(segment.y - snakePoints[1].y) < collision_size) then
                        gameState = 1 -- start rewinding
                        rewindCount = 1
                        shakeDuration = 0.1
                        -- pop out of if?
                        
                    end
                end
            end
        end

        local old_dir = dir_dir
        -- change turn direction
        if isAnyPressed() then
            dir_dir = 1
        else
            dir_dir = -1
        end

        if old_dir ~= dir_dir then -- dir changed, record new starting angle for loop logic
            dir_sum = 0
            move_rate = normal_move_rate
        end

        levelIsLooped = checkLevelLoop()

        if levelIsLooped then
            -- if musicPitch < maxMusicPitch then
            --     musicPitch = musicPitch + musicPitchChangeRate
            -- end
            musicPitch = maxMusicPitch
        else
            musicPitch = 1
        end

        backgroundMusic:setPitch(musicPitch)

        -- update world
        map:update(dt)
    elseif gameState == 1 then -- rewind

        if rewindCount <= max_rewind_amount then
            table.remove(snakePoints,1)
            table.remove(rewindDirs,1)
            rewindCount = rewindCount + 1
            --love.timer.sleep(.00001)

            if #snakePoints < 1 then
                gameOver()
            end
        else
            gameState = 0
            --if rewinDirs ~= nil then
            move_dir_radians = rewindDirs[1] -- set direction to what it was at the point we rewinded to
            --end
            snake_length = snake_length - max_rewind_amount
        end
    elseif gameState == 5 then
        updateMainMenu()
    end
end

function checkLevelLoop()
    -- check lines in each direction out from center
    -- if snake is crossing at least three lines, then we're looping
    local cx = math.floor(mapWidth/2)
    local cy = math.floor(mapHeight/2)

    local cr = false
    local cl = false
    local cu = false
    local cd = false

    for _,pt in pairs(snakePoints) do
        if cr == false and box_collision_detect(pt.x*snake_size,pt.y*snake_size,1,1,cx,cy,cx,snake_size) then -- center to right
            cr = true
        end

        if cl == false and box_collision_detect(pt.x*snake_size,pt.y*snake_size,1,1,0,cy,cx,snake_size) then -- center to left
            cl = true
        end

        if cu == false and box_collision_detect(pt.x*snake_size,pt.y*snake_size,1,1,cx,0,snake_size,cy) then -- center to right
            cu = true
        end

        if cd == false and box_collision_detect(pt.x*snake_size,pt.y*snake_size,1,1,cx,cy,snake_size,cy) then -- center to right
            cd = true
        end

        local count = 0
        if cr == true then
            count = count + 1
        end
        if cl == true then
            count = count + 1
        end
        if cd == true then
            count = count + 1
        end
        if cu == true then
            count = count + 1
        end

        if count >= 3 then
            return true
        end
    end
    return false
end

function love.keypressed(key, scancode, isrepeat)
    -- if key == "up" then
    --     dir_dir = dir_dir * -1
    -- end
    if key == "escape" then
        love.event.quit(0)
    elseif key == "r" then
        gameState = 0
        newGame()
    elseif key == "p" then
        if gameState == 0 then -- playing
            gameState = 3 -- pause
        elseif gameState == 3 then -- paused
            gameState = 0 -- unpause
        end
    end

    if gameState == 3 and isAnyPressed() then -- continue from pause
        gameState = 0
    end

    if gameState == 5 then
        mainMenuKeyHandler(key)
    end
end

function love.draw()

    if gameState == 5 then
        drawMainMenu()
    else

        local sx = 0
        local sy = 0

        if shakeDuration > 0 then
            -- Translate with a random number between -5 an 5.
            -- This second translate will be done based on the previous translate.
            -- So it will not reset the previous translate.
            sx = love.math.random(-2,2)
            sy = love.math.random(-2,2)
            --love.graphics.translate(love.math.random(-3,3), love.math.random(-3,3))
        end

        local tx = 0
        local ty = 0

        if (mapHeight/32 <= 18) and (mapWidth/32 <= 25) then
            tx = 1
            ty = 5
        else
            -- get coordinate of player to center world
            tx = math.floor((snake_size*(snakePoints[1].x)) - love.graphics.getWidth() / 2)
            ty = math.floor((snake_size*(snakePoints[1].y)) - love.graphics.getHeight() / 2)
        end

        tx = tx + sx
        ty = ty + sy

        -- Draw World
        love.graphics.setColor(1,1,1) -- has to be white for the world draw to work
        map:draw(-tx,-ty)

        -- love.graphics.setColor(1, 0, 0)
        -- map:box2d_draw(-tx,-ty)

        -- love.graphics.setColor(.28,.28,.28)
        -- love.graphics.rectangle(
        --     'fill',
        --     0,
        --     0,
        --     gridXCount * cellSize,
        --     gridYCount * cellSize
        -- )

        -- draw snake
        love.graphics.setColor(dark_color.r,dark_color.g,dark_color.b)
        for idx, segment in ipairs(snakePoints) do
            love.graphics.circle(
                'fill',
                (segment.x * snake_size -tx),
                (segment.y * snake_size -ty),
                snake_size*segment.r
            )

            if levelIsLooped and idx > #snakePoints - 10 then
                love.graphics.circle(
                    'fill',
                    (segment.x * snake_size -tx),
                    (segment.y * snake_size -ty),
                    snake_size*2
                )
                -- love.graphics.setColor(1,1,1)
                -- if idx == #snakePoints then
                --     love.graphics.draw(spriteSheet, starSprite, 
                --     (segment.x * snake_size -tx)-16, 
                --     (segment.y * snake_size -ty)-16)
                -- end
            end
        end

        -- head sprite
        -- love.graphics.setColor(1,1,1)
        -- local tilt = -move_dir_radians-(math.pi/2)
        -- love.graphics.draw(spriteSheet,headSprite,
        --     (snakePoints[1].x*snake_size-tx)-16*math.cos(tilt),
        --     (snakePoints[1].y*snake_size-ty)-16*math.sin(tilt),
        --     tilt
        -- )

        if levelIsLooped then -- draw arrow pointing at tail
            local tailPoint = snakePoints[#snakePoints]
            love.graphics.setColor(dark_color.r,dark_color.g,dark_color.b)

            -- circle outline
            love.graphics.circle(
                    'line',
                    (tailPoint.x * snake_size -tx),
                    (tailPoint.y * snake_size -ty),
                    snake_size*4
                )

            love.graphics.setColor(1,1,1) -- set white for sprites
            -- star on tail
            love.graphics.draw(spriteSheet, starSprite, 
                (tailPoint.x * snake_size -tx)-16, 
                (tailPoint.y * snake_size -ty)-16)

            -- arrow
            love.graphics.draw(spriteSheet, arrowSprite,
                (tailPoint.x * snake_size -tx)-16, 
                (tailPoint.y * snake_size -ty)+32
            )
        end

        -- debug drawing
        love.graphics.setColor(0,1,0)

        love.graphics.circle(
            'fill',
            collided_object_center.x - tx,
            collided_object_center.y - ty,
            4
        )

        if gameState == 2 then -- win!
            printOutlineFont("You Win!!!")
        elseif gameState == 3 then -- draw pause
            printOutlineFont("Paused.")
        elseif gameState == 4 then -- game over
            printOutlineFont("Game over. Press R to restart.")
        end

        if levelStartTimer > 0 then
            printOutlineFont(string.format("Level #%d starting in %d...",levelIndex,math.floor(levelStartTimer)))
        end
    end
end

function printOutlineFont(str)
    local x = 100
    local y = love.graphics.getHeight()/2 - 10
    love.graphics.setColor(dark_color.r,dark_color.g,dark_color.b)

    love.graphics.rectangle(
        'fill',
        x,
        y-20,
        love.graphics.getWidth()-(x*2),
        60
    )

    love.graphics.setColor(light_color.r,light_color.g,light_color.b)

    love.graphics.rectangle(
        'fill',
        x+10,
        y-10,
        love.graphics.getWidth()-(x*2)-20,
        40
    )

    love.graphics.setColor(dark_color.r,dark_color.g,dark_color.b)
    love.graphics.setFont(font)
    love.graphics.print(str,x+20,y)

end

function isAnyPressed() -- lots of keys can be used to switch directions
    if love.keyboard.isDown("up") or 
        love.keyboard.isDown("z") or
        love.keyboard.isDown("space") or
        love.keyboard.isDown("n") or
        love.mouse.isDown(1) or
        #love.touch.getTouches() > 0 then

            return true
        end
    return false

end