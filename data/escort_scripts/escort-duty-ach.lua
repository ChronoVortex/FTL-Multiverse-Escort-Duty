----------------------
-- HELPER FUNCTIONS --
----------------------

local userdata_table = mods.vertexutil.userdata_table

local function string_starts(str, start)
    return string.sub(str, 1, string.len(start)) == start
end

local function should_track_achievement(achievement, ship, shipClassName)
    return ship and
           Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame and
           Hyperspace.CustomAchievementTracker.instance:GetAchievementStatus(achievement) < Hyperspace.Settings.difficulty and
           string_starts(ship.myBlueprint.blueprintName, shipClassName)
end

local function current_sector()
    return Hyperspace.Global.GetInstance():GetCApp().world.starMap.worldLevel + 1
end

-- Track changes in player ship hull value
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(ship)
    if ship.iShipId == 0 and string_starts(ship.myBlueprint.blueprintName, "PLAYER_SHIP_ESCORT_DUTY") then
        local shipData = userdata_table(ship, "mods.escort.achTracking")
        local hullCurrent = ship.ship.hullIntegrity.first
        shipData.hullChange = hullCurrent - (shipData.hullLast or hullCurrent)
        shipData.hullLast = hullCurrent
    end
end)

-------------------------
-- ACHIEVEMENT UNLOCKS --
-------------------------

-- Easy
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(ship)
    if ship.iShipId == 0 and should_track_achievement("ACH_SHIP_ESCORT_DUTY_1", ship, "PLAYER_SHIP_ESCORT_DUTY") then
        local shipData = userdata_table(ship, "mods.escort.achTracking")
        local enemyShip = Hyperspace.ships.enemy
        if enemyShip and enemyShip._targetable.hostile and not enemyShip.bDestroyed then
            if shipData.hullChange > 0 then
                shipData.hullRepairedThisFight = shipData.hullRepairedThisFight + shipData.hullChange
                if shipData.hullRepairedThisFight >= 20 then
                    Hyperspace.CustomAchievementTracker.instance:SetAchievement("ACH_SHIP_ESCORT_DUTY_1", false)
                    return
                end
            end
        else
            shipData.hullRepairedThisFight = 0
        end
    end
end)

-- Normal
script.on_internal_event(Defines.InternalEvents.DRONE_FIRE, function(projectile, drone)
    if drone.iShipId == 0 and drone.blueprint.targetType == 4 and drone.blueprint.typeName == "DEFENSE" and should_track_achievement("ACH_SHIP_ESCORT_DUTY_2", Hyperspace.ships.player, "PLAYER_SHIP_ESCORT_DUTY") then
        userdata_table(projectile, "mods.escort.achTracking").firedFromProjDrone = true
    end
end)
local function check_drone_ach_kill(drone, projectile, damage, response)
    return damage.iIonDamage <= 0 and
           damage.iDamage > 0 and
           response.collision_type == 1 and
           drone.iShipId == 1 and
           drone.blueprint.typeName == "COMBAT" and
           should_track_achievement("ACH_SHIP_ESCORT_DUTY_2", Hyperspace.ships.player, "PLAYER_SHIP_ESCORT_DUTY") and
           userdata_table(projectile, "mods.escort.achTracking").firedFromProjDrone
end
script.on_internal_event(Defines.InternalEvents.DRONE_COLLISION, function(drone, projectile, damage, response)
    if check_drone_ach_kill(drone, projectile, damage, response) then
        Hyperspace.playerVariables.loc_escort_drones_destroyed = Hyperspace.playerVariables.loc_escort_drones_destroyed + 1
        if Hyperspace.playerVariables.loc_escort_drones_destroyed >= 2 then
            Hyperspace.CustomAchievementTracker.instance:SetAchievement("ACH_SHIP_ESCORT_DUTY_2", false)
        end
    end
end)

-- Hard
script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(ship)
    if ship.iShipId == 0 and Hyperspace.playerVariables.loc_escort_damage_taken <= 5 and should_track_achievement("ACH_SHIP_ESCORT_DUTY_3", ship, "PLAYER_SHIP_ESCORT_DUTY") then
        local hullChange = userdata_table(ship, "mods.escort.achTracking").hullChange
        if hullChange < 0 then
            Hyperspace.playerVariables.loc_escort_damage_taken = Hyperspace.playerVariables.loc_escort_damage_taken - hullChange
        end
        if current_sector() >= 5 then
            Hyperspace.CustomAchievementTracker.instance:SetAchievement("ACH_SHIP_ESCORT_DUTY_3", false)
        end
    end
end)
