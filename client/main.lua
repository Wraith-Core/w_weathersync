local CurrentWeather = Config.StartWeather
local lastWeather = CurrentWeather
local baseTime = Config.BaseTime
local timeOffset = Config.TimeOffset
local timer = 0
local freezeTime = Config.FreezeTime
local blackout = Config.Blackout
local disable = Config.Disabled

RegisterNetEvent("WCore:Client:OnPlayerLoaded", function()
	disable = false
	TriggerServerEvent("w_weathersync:server:RequestStateSync")
end)

-- Server notices arrive as dictionary keys (+ format args) and are translated
-- here, in the player's own language (library key, ar/en).
RegisterNetEvent("w_weathersync:client:notify", function(key, ntype, args)
	w.notify({
		title = locale("notify_title"),
		description = locale(key, table.unpack(args or {})),
		type = ntype or "success",
	})
end)

RegisterNetEvent("w_weathersync:client:EnableSync", function()
	disable = false
	TriggerServerEvent("w_weathersync:server:RequestStateSync")
end)

RegisterNetEvent("w_weathersync:client:SyncWeather", function(NewWeather, newblackout)
	CurrentWeather = NewWeather
	blackout = newblackout
end)

RegisterNetEvent("w_weathersync:client:SyncTime", function(base, offset, freeze)
	freezeTime = freeze
	timeOffset = offset
	baseTime = base
end)

local inTransition = false

CreateThread(function()
	while true do
		if not disable then
			local ped = PlayerPedId()
			local coords = GetEntityCoords(ped)
			-- North detection: Grizzlies West / Colter / Mount Hagen (snowy mountain peaks)
			local isNorth = coords.y > 1400.0 and coords.x < 500.0
			local targetWeather = CurrentWeather

			if isNorth and (targetWeather == "RAIN" or targetWeather == "THUNDER" or targetWeather == "THUNDERSTORM" or targetWeather == "DRIZZLE" or targetWeather == "SHOWER") then
				targetWeather = "SNOW"
			end

			if lastWeather ~= targetWeather then
				inTransition = true
				Citizen.InvokeNative(0x59174F1AFE095B5A, GetHashKey(targetWeather), false, true, true, 20.0, false) -- SetWeatherType
				-- Smooth transition steps from 0.0 to 1.0
				local steps = 30
				for i = 1, steps do
					if disable then break end
					local pct = i / steps
					Citizen.InvokeNative(0xFA3E3CA8A1DE6D5D, GetHashKey(lastWeather), GetHashKey(targetWeather), pct, true)
					Wait(500)
				end
				lastWeather = targetWeather
				inTransition = false
			end

			SetArtificialLightsState(blackout)

			if isNorth or targetWeather == "SNOW" or targetWeather == "BLIZZARD" or targetWeather == "GROUNDBLIZZARD" or targetWeather == "WHITEOUT" then
				Citizen.InvokeNative(0xF6BEE7E80EC5CA40, 0.9) -- SetSnowLevel
			else
				Citizen.InvokeNative(0xF6BEE7E80EC5CA40, 0.0) -- SetSnowLevel
			end

			if targetWeather == "DRIZZLE" or targetWeather == "SLEET" then
				Citizen.InvokeNative(0x193DFC0526830FD6, 0.2) -- SetRain
			elseif targetWeather == "RAIN" or targetWeather == "HAIL" or targetWeather == "SHOWER" or targetWeather == "THUNDER" then
				Citizen.InvokeNative(0x193DFC0526830FD6, 0.5) -- SetRain
			elseif targetWeather == "THUNDERSTORM" then
				Citizen.InvokeNative(0x193DFC0526830FD6, 0.7) -- SetRain
			else
				Citizen.InvokeNative(0x193DFC0526830FD6, 0.0) -- SetRain
			end

			Wait(500)
		else
			Wait(1000)
		end
	end
end)

CreateThread(function()
	local hour = 0
	local minute = 0
	local second = 0 --Add seconds for shadow smoothness
	while true do
		if not disable then
			Wait(0)
			local newBaseTime = baseTime
			if GetGameTimer() - 22 > timer then --Generate seconds in client side to avoid communiation
				second = second + 1 --Minutes are sent from the server every 2 seconds to keep sync
				if second >= 60 then second = 0 end -- frozen time never changes the minute, keep seconds in range
				timer = GetGameTimer()
			end
			if freezeTime then
				timeOffset = timeOffset + baseTime - newBaseTime
			end
			baseTime = newBaseTime
			hour = math.floor(((baseTime + timeOffset) / 60) % 24)
			if minute ~= math.floor((baseTime + timeOffset) % 60) then --Reset seconds to 0 when new minute
				minute = math.floor((baseTime + timeOffset) % 60)
				second = 0
			end
			-- RDR3 signature: (hour, minute, second, transitionTime, pauseClock)
			NetworkClockTimeOverride(hour, minute, second, 0, false)
		else
			Wait(1000)
		end
	end
end)
