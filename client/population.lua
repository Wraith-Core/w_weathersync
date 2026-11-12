-- w_weathersync · client/population.lua
-- Fewer ambient NPC people (owner 2026-11-13: cut the bots by 95 %, people only).
-- The game's own per-frame density multipliers for HUMANS only: animals, horses, wagons and trains are untouched,
-- and peds made by scripts (shop keepers, helpers, mission peds) are not ambient, so they are not affected.
-- 1.0 = the game's normal crowd, 0.05 = 5 % of it. Change it live with: setr w_weathersync:humanDensity 0.05

local DEFAULT = 0.05

local function value()
    local v = tonumber(GetConvar('w_weathersync:humanDensity', tostring(DEFAULT)))
    if not v then return DEFAULT end
    return math.max(0.0, math.min(1.0, v))
end

CreateThread(function()
    local density, nextRead = value(), 0
    while true do
        local now = GetGameTimer()
        if now >= nextRead then density, nextRead = value(), now + 5000 end
        if density >= 1.0 then
            Wait(1000)
        else
            Citizen.InvokeNative(0xBA0980B5C0A11924, density) -- SET_AMBIENT_HUMAN_DENSITY_MULTIPLIER_THIS_FRAME
            Citizen.InvokeNative(0x28CB6391ACEDD9DB, density) -- SET_SCENARIO_HUMAN_DENSITY_MULTIPLIER_THIS_FRAME
            Wait(0)
        end
    end
end)
