----------------------
-- HELPER FUNCTIONS --
----------------------

local userdata_table = mods.multiverse.userdata_table
local string_starts = mods.multiverse.string_starts

local function should_track_achievement(achievement, ship, shipClassName)
    return ship and
           Hyperspace.Global.GetInstance():GetCApp().world.bStartedGame and
           Hyperspace.CustomAchievementTracker.instance:GetAchievementStatus(achievement) < Hyperspace.Settings.difficulty and
           string_starts(ship.myBlueprint.blueprintName, shipClassName)
end

local function current_sector()
    return Hyperspace.Global.GetInstance():GetCApp().world.starMap.worldLevel + 1
end

local function count_ship_achievements(achPrefix)
    local count = 0
    for i = 1, 3 do
        if Hyperspace.CustomAchievementTracker.instance:GetAchievementStatus(achPrefix.."_"..tostring(i)) > -1 then
            count = count + 1
        end
    end
    return count
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
script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function(ship)
    local event = Hyperspace.App.world.starMap.currentLoc.event
    if should_track_achievement("ACH_SHIP_ESCORT_DUTY_2", ship, "PLAYER_SHIP_ESCORT_DUTY") and event and event.environment == 1 then
        Hyperspace.playerVariables.loc_escort_asteroid_visits = Hyperspace.playerVariables.loc_escort_asteroid_visits + 1
        if Hyperspace.playerVariables.loc_escort_asteroid_visits >= 4 then
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

-------------------------------------
-- LAYOUT UNLOCKS FOR ACHIEVEMENTS --
-------------------------------------

local achLayoutUnlocks = {
    {
        achPrefix = "ACH_SHIP_ESCORT_DUTY",
        unlockShip = "PLAYER_SHIP_ESCORT_DUTY_3"
    }
}

script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    local unlockTracker = Hyperspace.CustomShipUnlocks.instance
    for _, unlockData in ipairs(achLayoutUnlocks) do
        if not unlockTracker:GetCustomShipUnlocked(unlockData.unlockShip) and count_ship_achievements(unlockData.achPrefix) >= 2 then
            unlockTracker:UnlockShip(unlockData.unlockShip, false)
        end
    end
end)
