--[[
    GD50
    Angry Birds

    Author: Colton Ogden
    cogden@cs50.harvard.edu
]]

AlienLaunchMarker = Class{}

function AlienLaunchMarker:init(world)
    self.world = world

    -- starting coordinates for launcher used to calculate launch vector
    self.baseX = 90
    self.baseY = VIRTUAL_HEIGHT - 100

    -- shifted coordinates when clicking and dragging launch alien
    self.shiftedX = self.baseX
    self.shiftedY = self.baseY

    -- whether our arrow is showing where we're aiming
    self.aiming = false

    -- whether we launched the alien and should stop rendering the preview
    self.launched = false

    -- wether we still have a chance to split aliens
    self.canSplit = true

    -- our alien(s) we will eventually spawn
    self.aliens = { }
end


--[[
    Returns true if all aliens launched by player have either gone out of bounds
    or have almost stopped moving. When this function returns true, 
    Level is expected to reset() then re-initialise the AlienLaunchMarker.
]]
function AlienLaunchMarker:movementStopped()
    -- count how many aliens are out of bounds or stopped
    local numAliensStopped = 0

    -- check each alien we may have launched
    for k, alien in pairs(self.aliens) do
        local xPos, yPos = alien.body:getPosition()
        local xVel, yVel = alien.body:getLinearVelocity()
            
        -- if we fired our alien to the left or it's almost done rolling, respawn
        if xPos < 0 or (math.abs(xVel) + math.abs(yVel) < 1.5) then
            numAliensStopped = numAliensStopped + 1
        end
    end

    -- if all aliens stopped return true
    return #self.aliens == numAliensStopped
end


--[[
    Call before disposing of the AlienLaunchMaker, to clean up alien objects
    from the world.
]]
function AlienLaunchMarker:reset()
    for k, alien in pairs(self.aliens) do
        alien.body:destroy()
    end
end


function AlienLaunchMarker:update(dt)
    
    -- if launched, there's a chance to "split" the player's alien
    if self.launched then
        -- can only split if we haven't done so already, and player has not collided.
        -- self.canSplit gets updated by Level:update() just before this function
        -- is called
        if love.keyboard.wasPressed('space') and self.canSplit and #self.aliens == 1 then

            gSounds['powerup']:play()
            local orig = self.aliens[1]

            -- Spawning 2 new aliens at same location as original. Slightly
            -- offset for above/below -- Box2D will reposition so that the 
            -- aliens are not colliding

            local x, y = orig.body:getPosition()
            local topAlien = Alien(self.world, 'round', x, y - 8, 'Player')
            local lowAlien = Alien(self.world, 'round', x, y + 8, 'Player')

            -- adjust top/low Aliens trajectories
            local dx, dy = orig.body:getLinearVelocity()
            topAlien.body:setLinearVelocity(dx - 30, dy + 30)
            lowAlien.body:setLinearVelocity(dx + 30, dy - 30)

            -- make the new Aliens bounce the same
            topAlien.body:setAngularDamping(PLAYER_ANGULAR_DAMPING)
            lowAlien.body:setAngularDamping(PLAYER_ANGULAR_DAMPING)
            topAlien.fixture:setRestitution(PLAYER_RESTITUTION)
            lowAlien.fixture:setRestitution(PLAYER_RESTITUTION)

            -- add to launch table
            table.insert(self.aliens, topAlien)
            table.insert(self.aliens, lowAlien)
        end

    -- perform everything here as long as we haven't launched yet
    else
        -- grab mouse coordinates
        local x, y = push:toGame(love.mouse.getPosition())
        
        -- if we click the mouse and haven't launched, show arrow preview
        if love.mouse.wasPressed(1) and not self.launched then
            self.aiming = true

        -- if we release the mouse, launch an Alien
        elseif love.mouse.wasReleased(1) and self.aiming then
            self.launched = true

            -- spawn new alien in the world, passing in user data of player
            local alien = Alien(self.world, 'round', self.shiftedX, self.shiftedY, 'Player')

            -- apply the difference between current X,Y and base X,Y as launch vector impulse
            alien.body:setLinearVelocity((self.baseX - self.shiftedX) * 10, (self.baseY - self.shiftedY) * 10)

            -- make the alien pretty bouncy
            alien.fixture:setRestitution(PLAYER_RESTITUTION)
            alien.body:setAngularDamping(PLAYER_ANGULAR_DAMPING)

            -- insert this alien into our list
            table.insert(self.aliens, alien)

            -- we're no longer aiming
            self.aiming = false

        -- re-render trajectory
        elseif self.aiming then
            
            self.shiftedX = math.min(self.baseX + 30, math.max(x, self.baseX - 30))
            self.shiftedY = math.min(self.baseY + 30, math.max(y, self.baseY - 30))
        end
    end
end

function AlienLaunchMarker:render()
    if not self.launched then
        
        -- render base alien, non physics based
        love.graphics.draw(gTextures['aliens'], gFrames['aliens'][9], 
            self.shiftedX - 17.5, self.shiftedY - 17.5)

        if self.aiming then
            
            -- render arrow if we're aiming, with transparency based on slingshot distance
            local impulseX = (self.baseX - self.shiftedX) * 10
            local impulseY = (self.baseY - self.shiftedY) * 10

            -- draw 18 circles simulating trajectory of estimated impulse
            local trajX, trajY = self.shiftedX, self.shiftedY
            local gravX, gravY = self.world:getGravity()

            -- http://www.iforce2d.net/b2dtut/projected-trajectory
            for i = 1, 90 do
                
                -- magenta color that starts off slightly transparent
                love.graphics.setColor(255/255, 80/255, 255/255, ((255 / 24) * i) / 255)
                
                -- trajectory X and Y for this iteration of the simulation
                trajX = self.shiftedX + i * 1/60 * impulseX
                trajY = self.shiftedY + i * 1/60 * impulseY + 0.5 * (i * i + i) * gravY * 1/60 * 1/60

                -- render every fifth calculation as a circle
                if i % 5 == 0 then
                    love.graphics.circle('fill', trajX, trajY, 3)
                end
            end
        end
        
        love.graphics.setColor(1, 1, 1, 1)
    else
        for k, alien in pairs(self.aliens) do
            alien:render()
        end
    end
end