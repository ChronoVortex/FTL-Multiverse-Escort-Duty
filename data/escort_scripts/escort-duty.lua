if not mods or not mods.vertexutil then
    error("Couldn't find Vertex Tags and Utility Functions! Make sure it's above mods which depend on it in the Slipstream load order")
end

-------------
-- UTILITY --
-------------
local vter = mods.multiverse.vter
local userdata_table = mods.multiverse.userdata_table
local time_increment = mods.multiverse.time_increment
local get_ship_crew_point = mods.vertexutil.get_ship_crew_point
local ShowTutorialArrow = mods.vertexutil.ShowTutorialArrow
local HideTutorialArrow = mods.vertexutil.HideTutorialArrow

-- Shuffle the elements of an ordered unbroken table
local function shuffle_table(t)
    for i = #t, 2, -1 do
        local j = math.random(i)
        t[i], t[j] = t[j], t[i]
    end
end

-- Check if the game is paused in any way
local function check_paused()
    return Hyperspace.App.gui.bPaused or Hyperspace.App.gui.menu_pause or Hyperspace.App.gui.event_pause
end

-- System for executing code on a delay
local delayedFuncs = {}
local function execute_func_delayed(func, args, delay, ignorePause)
    table.insert(delayedFuncs, {func = func, args = args, time = delay, ignorePause = ignorePause or false})
end
script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    local delayedFuncCount = #delayedFuncs
    local index = 1
    while index <= delayedFuncCount do
        local delayedFuncData = delayedFuncs[index]
        if delayedFuncData.ignorePause or not check_paused() then
            delayedFuncData.time = delayedFuncData.time - time_increment()
        end
        if delayedFuncData.time <= 0 then
            table.remove(delayedFuncs, index)
            delayedFuncData.func(table.unpack(delayedFuncData.args))
            delayedFuncCount = delayedFuncCount - 1
        else
            index = index + 1
        end
    end
end)

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
    PLAYER_SHIP_ESCORT_DUTY_2 = {
        tpLinkages = {
            -- Coordinates of the individual TP pads on the escort fighter
            tpRoomShip1 = 14,
            tpPadsShip1 = {
                { x = 350, y = 210, slot = 0 },
                { x = 385, y = 210, slot = 1 }
            },
            -- Coordinates of the individual TP pads on the freighter
            tpRoomShip2 = 6,
            tpPadsShip2 = {
                { x = 210, y = 105, slot = 0 },
                { x = 245, y = 105, slot = 1 },
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
        droneSpeedFactor = 1.7,
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
    },
    ELITE_SHIP_ESCORT_DUTY = {
        tpLinkages = {
            -- Coordinates of the individual TP pads on the escort C fighter
            tpRoomShip1 = 11,
            tpPadsShip1 = {
                { x = 35,  y = 105, slot = 0 },
                { x = 35,  y = 140, slot = 1 }
            },
            -- Coordinates of the individual TP pads on the escort A fighter
            tpRoomShip2 = 3,
            tpPadsShip2 = {
                { x = 280, y = 140, slot = 0 },
                { x = 315, y = 140, slot = 1 },
            }
        },
        tpLinkages2 = {
            -- Coordinates of the individual TP pads on the escort A fighter
            tpRoomShip1 = 5,
            tpPadsShip1 = {
                { x = 280, y = 280, slot = 0 },
                { x = 315, y = 280, slot = 1 }
            },
            -- Coordinates of the individual TP pads on the escort B fighter
            tpRoomShip2 = 16,
            tpPadsShip2 = {
                { x = 70,  y = 315, slot = 0 },
                { x = 105, y = 315, slot = 1 },
            }
        }
    }
}

------------------------
-- CUSTOM DRONE ORBIT --
------------------------
do
    -- Utility function for repeated sub-calculation of drone orbit
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
                    -- No custom ellipse to orbit
                    if not escortData.droneOrbitEllipse then break end

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
end

-----------------------------
-- SHORT-RANGE TRANSPORTER --
-----------------------------
script.on_game_event("INITIAL_START_BEACON_ESCORT_DUTY", false, function() ShowTutorialArrow(1, 918, 561) end)
script.on_game_event("INITIAL_START_BEACON_ESCORT_DUTY_ELITE", false, function() ShowTutorialArrow(1, 918, 561) end)
script.on_game_event("INITIAL_START_BEACON_ESCORT_DUTY_ELITE_2", false, HideTutorialArrow)
script.on_game_event("LIGHTSPEED_DROPPOINT", false, HideTutorialArrow)
script.on_game_event("START_BEACON_PRESELECT", false, HideTutorialArrow) -- Just in case the tut arrow is active on game start

local function handle_mini_teleporters(linkageName)
    local ship = Hyperspace.ships.player
    if ship then
        for shipName, escortData in pairs(escortDutyShips) do
            -- Check if ship is an escort duty variant
            if shipName == ship.myBlueprint.blueprintName then
                local playTpSound = false
                local links = escortData[linkageName]
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
end
script.on_game_event("LUA_ESCORT_TELEPORT", false, function()
    handle_mini_teleporters("tpLinkages")
end)
script.on_game_event("LUA_ESCORT_TELEPORT_2", false, function()
    handle_mini_teleporters("tpLinkages2")
end)

------------------------
-- MULTIFACET SHIELDS --
------------------------
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(ship)
    if ship:HasEquipment("ENERGY_SHIELD_MULTIFACET") > 0 then
        ship.shieldSystem.shields.power.super.first = math.min(4, ship.shieldSystem.shields.power.super.first)
        local roomDefs = Hyperspace.CustomShipSelect.GetInstance():GetDefinition(ship.myBlueprint.blueprintName).roomDefs
        for room in vter(Hyperspace.ShipGraph.GetShipInfo(ship.iShipId).rooms) do
            local system = ship:GetSystemInRoom(room.iRoomId)
            if system then
                local resistChance = 6*system.iBonusPower
                if roomDefs:has_key(room.iRoomId) then
                    local roomDef = roomDefs[room.iRoomId]
                    room.extend.hullDamageResistChance = math.max(roomDef.hullDamageResistChance, resistChance)
                    room.extend.sysDamageResistChance = math.max(roomDef.sysDamageResistChance, resistChance)
                    room.extend.ionDamageResistChance = math.max(roomDef.ionDamageResistChance, resistChance)
                else
                    room.extend.hullDamageResistChance = resistChance
                    room.extend.sysDamageResistChance = resistChance
                    room.extend.ionDamageResistChance = resistChance
                end
            end
        end
    end
end)
do
    local resistIcon = Hyperspace.Resources:CreateImagePrimitiveString("effects/escort_resist_ico.png", 0, 0, 0, Graphics.GL_Color(1, 0.98, 0.353, 1), 1, false)
    script.on_render_event(Defines.RenderEvents.SHIP_SPARKS, function() end, function(ship)
        if ship:HasEquipment("ENERGY_SHIELD_MULTIFACET") > 0 then
            ship = Hyperspace.ships(ship.iShipId)
            local shipGraph = Hyperspace.ShipGraph.GetShipInfo(ship.iShipId)
            for room in vter(shipGraph.rooms) do
                local system = ship:GetSystemInRoom(room.iRoomId)
                if system and system.iBonusPower > 0 then
                    local shape = shipGraph:GetRoomShape(room.iRoomId)
                    Graphics.CSurface.GL_PushMatrix()
                    Graphics.CSurface.GL_Translate(shape.x, shape.y)
                    Graphics.CSurface.GL_RenderPrimitive(resistIcon)
                    Graphics.CSurface.GL_PopMatrix()
                end
            end
        end
    end)
end

-------------------------
-- FIRE BOMB ARTILLERY --
-------------------------
do
    -- Utility function for creating the extra fire bombs
    local fireBombBp = Hyperspace.Blueprints:GetWeaponBlueprint("BOMB_CLUSTER_FIRE_ARTILLERY")
    local function create_fire_bomb(owner, target, space, bypass)
        Hyperspace.App.world.space:CreateBomb(fireBombBp, owner, target, space).superShieldBypass = bypass
    end

    -- Create two extra bombs for the 3-shot cluster and spread the targeting randomly
    script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
        local targetShip = Hyperspace.ships(projectile.targetId)
        if targetShip and weapon and weapon.blueprint and weapon.blueprint.name == fireBombBp.name then
            local rooms = {}
            for room in vter(Hyperspace.ShipGraph.GetShipInfo(targetShip.iShipId).rooms) do
                table.insert(rooms, room.iRoomId)
            end
            if #rooms >= 3 then
                shuffle_table(rooms)
                projectile.target = targetShip:GetRoomCenter(table.remove(rooms, #rooms))
                projectile:ComputeHeading()
                execute_func_delayed(create_fire_bomb, {projectile.ownerId, targetShip:GetRoomCenter(table.remove(rooms, #rooms)), projectile.destinationSpace, projectile.superShieldBypass}, 0.1)
                execute_func_delayed(create_fire_bomb, {projectile.ownerId, targetShip:GetRoomCenter(table.remove(rooms, #rooms)), projectile.destinationSpace, projectile.superShieldBypass}, 0.2)
            end
        end
    end)
end
