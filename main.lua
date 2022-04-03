local sti = require "sti"

function love.load()

    -- only two colors for bw game jam
    dark_color = { r = 0, g = 0, b = 0}
    light_color = { r = 1, g = 1, b = 1 }

    --love.graphics.setBackgroundColor(light_color.r,light_color.g,light_color.b)
    --love.keyboard.setKeyRepeat(false) -- uncomment for toggling direction instead of on/off dir

    -- properties that will remain constant
    start_length = 50
    start_x = 30
    start_y = 30
    normal_move_rate = 0.02 
    fast_turn_move_rate = 0.005 -- min speed (happens during turning)
    move_rate = normal_move_rate -- snake speed .. smaller number is faster
    dir_change_rate = 0.14 -- snake turn speed
    snake_size = 6
    collision_size = 1 -- give some wiggle room
    knockback_amt = .5 -- how far player gets pushed back after hitting wall

    max_rewind_amount = 20

    collided_object_center = {x = 0,y = 0}

    map = sti("bwtilemap.lua", { "box2d" })

    -- Prepare physics world with horizontal and vertical gravity
	world = love.physics.newWorld(0, 0)

	-- Prepare collision objects
	map:box2d_init(world)

    newGame()
    print('welcome!')
end

function newGame()
    -- properties that could change during game
    dir_dir = 1
    move_dir_radians = 0
    timer = 0
    dir_sum = 0
    player_did_collide = false

    initSnakePoints()
end

function initSnakePoints()
    snakePoints = {}
    oldSnakePoints = {}
    tx = start_x
    ty = start_y
    for i = 1,start_length do

        table.insert(snakePoints,1, {
            x = tx, y = ty
        })

        if i < max_rewind_amount then
            table.insert(oldSnakePoints,1, {
                x = tx, y = ty
            })
        end

        tx = tx + 1
    end
end

function collision_handler(collided_fixture)
    topLeftX, topLeftY, bottomRightX, bottomRightY = collided_fixture:getBoundingBox( 1 )
    player_did_collide = true
    collided_object_center.x = (bottomRightX + topLeftX) / 2
    collided_object_center.y = (bottomRightY + topLeftY) / 2
    return false -- tell the world queryBoundingBox function to stop its search
end

function love.update(dt)

    timer = timer + dt
    if timer >= move_rate then

        timer = 0
        move_dir_radians = (move_dir_radians + dir_dir*dir_change_rate) % (2*math.pi)
        dir_sum = dir_sum + dir_change_rate

        local newX = (snakePoints[1].x + math.cos(move_dir_radians))
        local newY = (snakePoints[1].y - math.sin(move_dir_radians))

        player_did_collide = false

        -- check if player collides with wall
        world:queryBoundingBox( newX*snake_size,newY*snake_size,newX*snake_size+2,newY*snake_size+2,collision_handler)

        if player_did_collide == true then --knockback

            -- TODO: new idea = on wall collision, rewind player by half the length of the snake
            --  need to store additional 'vanished' snake locations as backups so we can rewind
            yjump = (newY*snake_size - collided_object_center.y) * knockback_amt
            xjump = (newX*snake_size - collided_object_center.x) * knockback_amt
            newX = newX + xjump
            newY = newY + yjump
        end

        table.insert(snakePoints,1, {
            x = newX, y = newY
        })

        oldVal = table.remove(snakePoints) -- remove last element
        table.insert(oldSnakePoints,1,oldVal)
        table.remove(oldSnakePoints)

        --TODO: add this last element to oldSnakePoints for rewind feature

        if dir_sum > 2*math.pi then -- player did a full loop
            print("loop!!!")
            dir_sum = 0
        -- elseif dir_sum > math.pi then -- half loop.. speed up
        --     move_rate = fast_turn_move_rate
        end

        -- check for self-intersects with lead point
        for idx, segment in ipairs(snakePoints) do
            if idx > 2 then
                if (math.abs(segment.x - snakePoints[1].x) < collision_size) and (math.abs(segment.y - snakePoints[1].y) < collision_size) then
                    -- collision!!! game over...
                    print('ow')
                    newGame()
                end
            end
        end
    end

    local old_dir = dir_dir
    -- change turn direction
    if love.keyboard.isDown("up") then
        dir_dir = 1
    else
        dir_dir = -1
    end

    if old_dir ~= dir_dir then -- dir changed, record new starting angle for loop logic
        dir_sum = 0
        move_rate = normal_move_rate
    end

    -- update world
    map:update(dt)
end

function love.keypressed(key, scancode, isrepeat)
    -- if key == "up" then
    --     dir_dir = dir_dir * -1
    -- end
    if key == "escape" then
        love.exit()
    end
end

function love.draw()

    
    -- get coordinate of player to center world
    local tx = math.floor((snake_size*(snakePoints[1].x)) - love.graphics.getWidth() / 2)
    local ty = math.floor((snake_size*(snakePoints[1].y)) - love.graphics.getHeight() / 2)

    -- Draw World
    love.graphics.setColor(light_color.r,light_color.g,light_color.b)
    map:draw(-tx,-ty)

    love.graphics.setColor(1, 0, 0)
	map:box2d_draw(-tx,-ty)

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
            segment.x * snake_size -tx,
            segment.y * snake_size -ty,
            2
        )
    end

    -- debug drawing
    love.graphics.setColor(0,1,0)
    for idx, segment in ipairs(oldSnakePoints) do
        love.graphics.circle(
            'fill',
            segment.x * snake_size -tx,
            segment.y * snake_size -ty,
            2
        )
    end

    love.graphics.circle(
        'fill',
        collided_object_center.x - tx,
        collided_object_center.y - ty,
        4
    )

    
end