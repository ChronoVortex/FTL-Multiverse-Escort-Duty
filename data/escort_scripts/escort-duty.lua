if not mods or not mods.vertexutil then
    error("Couldn't find Vertex Tags and Utility Functions! Make sure it's above mods which depend on it in the Slipstream load order")
end

local vter = mods.multiverse.vter
local userdata_table = mods.multiverse.userdata_table
local get_ship_crew_point = mods.vertexutil.get_ship_crew_point
local ShowTutorialArrow = mods.vertexutil.ShowTutorialArrow
local HideTutorialArrow = mods.vertexutil.HideTutorialArrow

---------------
-- SHIP DATA --
---------------
local escortDutyShips = {
    PLAYER_SHIP_ESCORT_DUTY = {
        droneOrbitEllipse = {
            center = {
                x = 139,
                y = 280
            }, 
            a = 229,
            b = 103
        },
        droneSpeedFactor = 1.6,
        tpLinkages = {
            -- Coordinates of the individual TP pads on the escort fighter
            tpRoomShip1 = 5,
            tpPadsShip1 = {
                { x = 350, y = 140, slot = 0 },
                { x = 385, y = 140, slot = 1 }
            },
            -- Coordinates of the individual TP pads on the freighter
            tpRoomShip2 = 6,
            tpPadsShip2 = {
                { x = 210, y = 270, slot = 0 },
                { x = 245, y = 270, slot = 1 },
            }
        }
    },
    PLAYER_SHIP_ESCORT_DUTY_3 = {
        droneOrbitEllipse = {
            center = {
                x = 108,
                y = 314
            }, 
            a = 213,
            b = 152
        },
        droneSpeedFactor = 1.6,
        tpLinkages = {
            -- Coordinates of the individual TP pads on the escort fighter
            tpRoomShip1 = 9,
            tpPadsShip1 = {
                { x = 280, y = 105, slot = 0 },
                { x = 280, y = 140, slot = 1 }
            },
            -- Coordinates of the individual TP pads on the freighter
            tpRoomShip2 = 4,
            tpPadsShip2 = {
                { x = 140, y = 245, slot = 1 },
                { x = 140, y = 280, slot = 3 },
            }
        }
    }
}

------------------------
-- CUSTOM DRONE ORBIT --
------------------------
local function calculate_coord_offset(ellipse, angleFromCenter)
    local angleCos = ellipse.b*math.cos(angleFromCenter)
    local angleSin = ellipse.a*math.sin(angleFromCenter)
    local denom = math.sqrt(angleCos^2 + angleSin^2)
    return (ellipse.a*angleCos)/denom, (ellipse.b*angleSin)/denom
end

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(ship)
    if ship.iShipId == 0 then
        for shipName, escortData in pairs(escortDutyShips) do
            -- Check if ship is an escort duty variant
            if shipName == ship.myBlueprint.blueprintName then
                local stillActive = {}
                local activeDroneIds = userdata_table(ship, "mods.escort.dronesActive")

                -- Iterate through all defense drones for the ship
                for drone in vter(ship.spaceDrones) do
                    if drone.deployed and drone.blueprint.typeName == "DEFENSE" then
                        stillActive[drone.selfId] = true
                        local xOffset = nil
                        local yOffset = nil
                        
                        -- Set drone location to a random point on the ellipse if just deployed
                        if not activeDroneIds[drone.selfId] then
                            activeDroneIds[drone.selfId] = true
                            xOffset, yOffset = calculate_coord_offset(escortData.droneOrbitEllipse, (Hyperspace.random32()%360)*(math.pi/180))
                            drone:SetCurrentLocation(Hyperspace.Pointf(
                                escortData.droneOrbitEllipse.center.x + xOffset,
                                escortData.droneOrbitEllipse.center.y + yOffset))
                        end
                        
                        -- Make the drone orbit the fake ellipse
                        if drone.powered then
                            local lookAhead = drone.blueprint.speed*Hyperspace.FPS.SpeedFactor/escortData.droneSpeedFactor
                            xOffset, yOffset = calculate_coord_offset(escortData.droneOrbitEllipse, math.atan(
                                drone.currentLocation.y - escortData.droneOrbitEllipse.center.y,
                                drone.currentLocation.x - escortData.droneOrbitEllipse.center.x))
                            local xIntersect = escortData.droneOrbitEllipse.center.x + xOffset
                            local yIntersect = escortData.droneOrbitEllipse.center.y + yOffset
                            local tanAngle = math.atan((escortData.droneOrbitEllipse.b^2/escortData.droneOrbitEllipse.a^2)*(xOffset/yOffset))
                            if (drone.currentLocation.y < escortData.droneOrbitEllipse.center.y) then
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
                break
            end
        end
    end
end)

-----------------------------
-- SHORT-RANGE TRANSPORTER --
-----------------------------
script.on_game_event("INITIAL_START_BEACON_ESCORT_DUTY", false, function() ShowTutorialArrow(1, 918, 561) end)
script.on_game_event("LIGHTSPEED_DROPPOINT", false, HideTutorialArrow)
script.on_game_event("START_BEACON_PRESELECT", false, HideTutorialArrow) -- Just in case the tut arrow is active on game start

script.on_game_event("LUA_ESCORT_TELEPORT", false, function()
    local ship = Hyperspace.ships.player
    if ship then
        for shipName, escortData in pairs(escortDutyShips) do
            -- Check if ship is an escort duty variant
            if shipName == ship.myBlueprint.blueprintName then
                local playTpSound = false
                local links = escortData.tpLinkages
                for padIndex = 1, #(links.tpPadsShip1), 1 do
                    -- Check for crew on the pad of the first ship and teleport
                    local crewShip1 = get_ship_crew_point(ship,
                        links.tpPadsShip1[padIndex].x, links.tpPadsShip1[padIndex].y, 1)[1]
                    if crewShip1 and not crewShip1:IsDrone() then -- No drones 'cause no TP anims
                        crewShip1.extend:InitiateTeleport(0, links.tpRoomShip2, links.tpPadsShip2[padIndex].slot)
                        playTpSound = true
                    end
                    -- Check for crew on the pad of the second ship and teleport
                    local crewShip2 = get_ship_crew_point(ship,
                        links.tpPadsShip2[padIndex].x, links.tpPadsShip2[padIndex].y, 1)[1]
                    if crewShip2 and not crewShip2:IsDrone() then
                        crewShip2.extend:InitiateTeleport(0, links.tpRoomShip1, links.tpPadsShip1[padIndex].slot)
                        playTpSound = true
                    end
                end
                if playTpSound then
                    Hyperspace.Sounds:PlaySoundMix("teleport", -1, false)
                end
                break
            end
        end
    end
end)
