if not mods or not mods.vertexutil then
    error("Couldn't find Vertex Tags and Utility Functions! Make sure it's above mods which depend on it in the Slipstream load order", 2)
end

local vter = mods.vertexutil.vter
local get_ship_crew_point = mods.vertexutil.get_ship_crew_point
local ShowTutorialArrow = mods.vertexutil.ShowTutorialArrow
local HideTutorialArrow = mods.vertexutil.HideTutorialArrow

------------------------
-- CUSTOM DRONE ORBIT --
------------------------
local escortEllipse = {
    center = {
        x = 139,
        y = 280
    }, 
    a = 229,
    b = 103
}
local droneSpeedFactor = 1.6
local activeDroneIds = {}

local calculate_coord_offset = function(angleFromCenter)
    local angleCos = escortEllipse.b*math.cos(angleFromCenter)
    local angleSin = escortEllipse.a*math.sin(angleFromCenter)
    local denom = math.sqrt(angleCos^2 + angleSin^2)
    return (escortEllipse.a*angleCos)/denom, (escortEllipse.b*angleSin)/denom
end

script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    -- Iterate through all defense drones if the ship is escort duty
    local isEscort = 0
    if pcall(function() isEscort = Hyperspace.ships.player:HasEquipment("SHIP PLAYER_SHIP_ESCORT_DUTY") end) and isEscort > 0 then
        local stillActive = {}
        for drone in vter(Hyperspace.ships.player.spaceDrones) do
            if drone.deployed and drone.blueprint.typeName == "DEFENSE" then
                stillActive[drone.selfId] = true
                local xOffset = nil
                local yOffset = nil
                
                -- Set drone location to a random point on the ellipse if just deployed
                if not activeDroneIds[drone.selfId] then
                    activeDroneIds[drone.selfId] = true
                    xOffset, yOffset = calculate_coord_offset((Hyperspace.random32()%360)*(math.pi/180))
                    drone:SetCurrentLocation(Hyperspace.Pointf(
                        escortEllipse.center.x + xOffset,
                        escortEllipse.center.y + yOffset))
                end
                
                -- Make the drone orbit the fake ellipse
                if drone.powered then
                    local lookAhead = drone.blueprint.speed*Hyperspace.FPS.SpeedFactor/droneSpeedFactor
                    xOffset, yOffset = calculate_coord_offset(math.atan(
                        drone.currentLocation.y - escortEllipse.center.y,
                        drone.currentLocation.x - escortEllipse.center.x))
                    local xIntersect = escortEllipse.center.x + xOffset
                    local yIntersect = escortEllipse.center.y + yOffset
                    local tanAngle = math.atan((escortEllipse.b^2/escortEllipse.a^2)*(xOffset/yOffset))
                    if (drone.currentLocation.y < escortEllipse.center.y) then
                        drone.destinationLocation = Hyperspace.Pointf(
                            xIntersect + lookAhead*math.cos(tanAngle),
                            yIntersect - lookAhead*math.sin(tanAngle))
                    else
                        drone.destinationLocation = Hyperspace.Pointf(
                            xIntersect - lookAhead*math.cos(tanAngle),
                            yIntersect + lookAhead*math.sin(tanAngle))
                    end
                end
            end
        end
        
        -- Clean out inactive drone IDs
        for droneId in pairs(activeDroneIds) do
            if not stillActive[droneId] then
                activeDroneIds[droneId] = nil
            end
        end
    end
end)

-----------------------------
-- SHORT-RANGE TRANSPORTER --
-----------------------------
script.on_game_event("INITIAL_START_BEACON_ESCORT_DUTY", false, function()
    ShowTutorialArrow(1, 918, 561)
end)
script.on_game_event("LIGHTSPEED_DROPPOINT", false, HideTutorialArrow)
script.on_game_event("START_BEACON_PRESELECT", false, HideTutorialArrow) -- Just in case the tut arrow is active on game start

-- Coordinates of the individual TP pads on the escort fighter
local tpPadsShip1 = {
    { x = 350, y = 140 },
    { x = 385, y = 140 }
}
-- Coordinates of the individual TP pads on the freighter
local tpPadsShip2 = {
    { x = 210, y = 270 },
    { x = 245, y = 270 },
}
local padCount = 2
script.on_game_event("LUA_ESCORT_TELEPORT", false, function()
    local playTpSound = false
    for padIndex = 1, padCount, 1 do
        -- Check for crew on the pad of the first ship and teleport
        local crewShip1 = get_ship_crew_point(Hyperspace.ships.player,
            tpPadsShip1[padIndex].x, tpPadsShip1[padIndex].y, 1)[1]
        if crewShip1 and not crewShip1:IsDrone() then -- No drones 'cause no TP anims
            Hyperspace.Get_CrewMember_Extend(crewShip1):InitiateTeleport(0, 6)
            playTpSound = true
        end
        -- Check for crew on the pad of the second ship and teleport
        local crewShip2 = get_ship_crew_point(Hyperspace.ships.player,
            tpPadsShip2[padIndex].x, tpPadsShip2[padIndex].y, 1)[1]
        if crewShip2 and not crewShip2:IsDrone() then
            Hyperspace.Get_CrewMember_Extend(crewShip2):InitiateTeleport(0, 5)
            playTpSound = true
        end
    end
    if playTpSound then
        Hyperspace.Global.GetInstance():GetSoundControl():PlaySoundMix("teleport", 1, false)
    end
end)
