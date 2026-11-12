-- w_weathersync · client/population.lua
-- Fewer ambient NPCs (owner 2026-11-13): people cut by 95 %, then wagons and horses too.
--  * people  : the game's per-frame HUMAN density multipliers (ambient + scenario)
--  * wagons  : the game's per-frame vehicle density multipliers (moving + parked); trains are not touched
--  * horses  : the game has no horse-only multiplier, so riderless AMBIENT horses near the player are removed,
--              keeping about 1 in 20. Never a mission/script horse (players' horses from w_stables, shop/heist
--              peds), never one with a rider, never one we do not control.
-- Other animals and every ped made by a script are untouched.
-- 1.0 = the game's normal amount, 0.05 = 5 % of it. Change live (no update needed):
--   setr w_weathersync:humanDensity 0.05 | setr w_weathersync:vehicleDensity 0.05 | setr w_weathersync:horseKeep 0.05

local function read(name, default)
    local v = tonumber(GetConvar(name, tostring(default)))
    if not v then return default end
    return math.max(0.0, math.min(1.0, v))
end

local human, vehicle, horseKeep = 0.05, 0.05, 0.05
local function refresh()
    human = read('w_weathersync:humanDensity', 0.05)
    vehicle = read('w_weathersync:vehicleDensity', 0.05)
    horseKeep = read('w_weathersync:horseKeep', 0.05)
end

CreateThread(function()
    refresh()
    local nextRead = 0
    while true do
        local now = GetGameTimer()
        if now >= nextRead then refresh(); nextRead = now + 5000 end
        if human >= 1.0 and vehicle >= 1.0 then
            Wait(1000)
        else
            if human < 1.0 then
                Citizen.InvokeNative(0xBA0980B5C0A11924, human)   -- SET_AMBIENT_HUMAN_DENSITY_MULTIPLIER_THIS_FRAME
                Citizen.InvokeNative(0x28CB6391ACEDD9DB, human)   -- SET_SCENARIO_HUMAN_DENSITY_MULTIPLIER_THIS_FRAME
            end
            if vehicle < 1.0 then
                Citizen.InvokeNative(0x606374EBFC27B133, vehicle) -- SET_VEHICLE_DENSITY_MULTIPLIER_THIS_FRAME
                Citizen.InvokeNative(0x1F91D44490E1EA0C, vehicle) -- SET_RANDOM_VEHICLE_DENSITY_MULTIPLIER_THIS_FRAME
                Citizen.InvokeNative(0xFEDFA97638D61D4A, vehicle) -- SET_PARKED_VEHICLE_DENSITY_MULTIPLIER_THIS_FRAME
            end
            Wait(0)
        end
    end
end)

-- Horses: every 3 s, riderless ambient horses we control are removed, except about horseKeep of them.
local function isHorse(ped)
    local r = Citizen.InvokeNative(0x772A1969F649E902, GetEntityModel(ped)) -- _IS_THIS_MODEL_A_HORSE
    return r == true or r == 1
end

-- a horse beside a wagon may be its draft horse (a player's wagon too): left alone
local function nearWagon(ped, wagons)
    local p = GetEntityCoords(ped)
    for i = 1, #wagons do
        if #(p - GetEntityCoords(wagons[i])) < 8.0 then return true end
    end
    return false
end

local function hasRider(horse)
    local rider = Citizen.InvokeNative(0xB676EFDA03DADA52, horse, false) -- _GET_RIDER_OF_MOUNT
    return rider and rider ~= 0
end

local function keep(ped)
    -- a fixed choice per horse (not random each pass), so the kept ones stay
    local id = NetworkGetEntityIsNetworked(ped) and NetworkGetNetworkIdFromEntity(ped) or ped
    return (id % 100) < math.floor(horseKeep * 100 + 0.5)
end

CreateThread(function()
    while true do
        Wait(3000)
        if horseKeep < 1.0 then
            local me = PlayerPedId()
            local wagons = GetGamePool('CVehicle')
            for _, ped in ipairs(GetGamePool('CPed')) do
                if ped ~= me and DoesEntityExist(ped) and not IsPedAPlayer(ped)
                    and not IsEntityAMissionEntity(ped) and isHorse(ped)
                    and not hasRider(ped) and not IsEntityAttached(ped)
                    and not IsPedInAnyVehicle(ped, false)
                    and NetworkHasControlOfEntity(ped) and not keep(ped)
                    and not nearWagon(ped, wagons) then
                    SetEntityAsMissionEntity(ped, true, true)
                    DeleteEntity(ped)
                end
            end
        end
    end
end)
