local CurrentWeather = Config.StartWeather
local baseTime = Config.BaseTime
local timeOffset = Config.TimeOffset
local freezeTime = Config.FreezeTime
local blackout = Config.Blackout
local newWeatherTimer = Config.NewWeatherTimer

--- Does source have permissions to run admin commands (console always may)
--- @param src number - Source to check
--- @return boolean - has permission
local function isAllowedToChange(src)
	if src == 0 then
		return true
	end
	return exports.w_lib:IsAdmin(src) == true
end

--- Notify a player with a dictionary key; the client translates it in its own language.
--- Extra arguments are format arguments for the key (formatted on the client too).
--- @param src number - player id (console is skipped)
--- @param key string - dictionary key
--- @param ntype string|nil - 'success' | 'error' | 'inform' | 'warning'
local function notify(src, key, ntype, ...)
	if not src or src <= 0 then
		return
	end
	if select("#", ...) > 0 then
		TriggerClientEvent("w_weathersync:client:notify", src, key, ntype or "success", { ... })
	else
		w.notify(src, { title = "notify_title", description = key, type = ntype or "success" })
	end
end

--- Two-digit clock value for the time notification
--- @param value number|string|nil
--- @return string
local function pad(value)
	return ("%02d"):format(tonumber(value) or 0)
end

--- Clock strings as setTime applies them (24 -> 00, minute out of range -> 00)
--- @param hour number|string|nil
--- @param minute number|string|nil
--- @return string, string
local function clockOf(hour, minute)
	local h = tonumber(hour) or 0
	local m = tonumber(minute) or 0
	if h >= 24 then h = 0 end
	if m < 0 or m >= 60 then m = 0 end
	return pad(h), pad(m)
end

--- Sets time offset based on minutes provided
--- @param minute number - Minutes to offset by
local function shiftToMinute(minute)
	timeOffset = timeOffset - (((baseTime + timeOffset) % 60) - minute)
end

--- Sets time offset based on hour provided
--- @param hour number - Hour to offset by
local function shiftToHour(hour)
	timeOffset = timeOffset - ((((baseTime + timeOffset) / 60) % 24) - hour) * 60
end

--- Triggers event to switch weather to next stage
local function nextWeatherStage()
	if CurrentWeather == "SUNNY" or CurrentWeather == "CLOUDS" or CurrentWeather == "HIGHPRESSURE" then
		CurrentWeather = (math.random(1, 5) > 2) and "SUNNY" or "OVERCAST" -- 60/40 chance
	elseif CurrentWeather == "OVERCAST" then
		local new = math.random(1, 6)
		if new == 1 then
			CurrentWeather = "RAIN"
		elseif new == 2 then
			CurrentWeather = "CLOUDS"
		elseif new == 3 then
			CurrentWeather = "SUNNY"
		elseif new == 4 then
			CurrentWeather = "HIGHPRESSURE"
		elseif new == 5 then
			CurrentWeather = "SANDSTORM"
		else
			CurrentWeather = "FOG"
		end
	elseif CurrentWeather == "THUNDER" or CurrentWeather == "RAIN" or CurrentWeather == "THUNDERSTORM" then
		CurrentWeather = "OVERCASTDARK"
	elseif CurrentWeather == "OVERCASTDARK" then
		CurrentWeather = "SUNNY"
	elseif CurrentWeather == "MISTY" or CurrentWeather == "FOG" then
		CurrentWeather = "SUNNY"
	else
		CurrentWeather = "HIGHPRESSURE"
	end
	TriggerEvent("w_weathersync:server:RequestStateSync")
end

--- Switch to a specified weather type
--- @param weather string - Weather type from Config.AvailableWeatherTypes
--- @return boolean - success
local function setWeather(weather)
	if type(weather) ~= "string" then
		return false
	end
	local wanted = weather:upper()
	local validWeatherType = false
	for _, weatherType in pairs(Config.AvailableWeatherTypes) do
		if weatherType == wanted then
			validWeatherType = true
			break
		end
	end
	if not validWeatherType then
		return false
	end
	CurrentWeather = wanted
	newWeatherTimer = Config.NewWeatherTimer
	TriggerEvent("w_weathersync:server:RequestStateSync")
	return true
end

--- Sets sun position based on time to specified
--- @param hour number|string - Hour to set (0-24)
--- @param minute number|string `optional` - Minute to set (0-60)
--- @return boolean - success
local function setTime(hour, minute)
	local argh = tonumber(hour)
	local argm = tonumber(minute) or 0
	if argh == nil or argh < 0 or argh > 24 then
		w.print.warn("setTime: invalid hour %s", tostring(hour))
		return false
	end
	shiftToHour((argh < 24) and argh or 0)
	shiftToMinute((argm >= 0 and argm < 60) and argm or 0)
	w.print.info("time changed to %s:%s", clockOf(argh, argm))
	TriggerEvent("w_weathersync:server:RequestStateSync")
	return true
end

--- Sets or toggles blackout state and returns the state
--- @param state boolean `optional` - enable blackout?
--- @return boolean - blackout state
local function setBlackout(state)
	if state == nil then
		state = not blackout
	end
	blackout = state and true or false
	TriggerEvent("w_weathersync:server:RequestStateSync")
	return blackout
end

--- Sets or toggles time freeze state and returns the state
--- @param state boolean `optional` - Enable time freeze?
--- @return boolean - Time freeze state
local function setTimeFreeze(state)
	if state == nil then
		state = not freezeTime
	end
	freezeTime = state and true or false
	TriggerEvent("w_weathersync:server:RequestStateSync")
	return freezeTime
end

--- Sets or toggles dynamic weather state and returns the state
--- @param state boolean `optional` - Enable dynamic weather?
--- @return boolean - Dynamic Weather state
local function setDynamicWeather(state)
	if state == nil then
		state = not Config.DynamicWeather
	end
	Config.DynamicWeather = state and true or false
	TriggerEvent("w_weathersync:server:RequestStateSync")
	return Config.DynamicWeather
end

-- EVENTS

-- Audit (2026-10-18): a player's ask is answered to HIM only, at most once a second; the server's own call
-- (setDynamicWeather, TriggerEvent) still syncs everyone. Before, any player could make the server broadcast to all
-- players as fast as he liked.
local lastSyncAsk = {}
RegisterNetEvent("w_weathersync:server:RequestStateSync", function()
	local src = tonumber(source)
	local target = -1
	if src and src > 0 then
		local now = GetGameTimer()
		if lastSyncAsk[src] and now - lastSyncAsk[src] < 1000 then return end
		lastSyncAsk[src] = now
		target = src
	end
	TriggerClientEvent("w_weathersync:client:SyncWeather", target, CurrentWeather, blackout)
	TriggerClientEvent("w_weathersync:client:SyncTime", target, baseTime, timeOffset, freezeTime)
end)

AddEventHandler("playerDropped", function()
	lastSyncAsk[source] = nil
end)

RegisterNetEvent("w_weathersync:server:setWeather", function(weather)
	local src = source
	if not isAllowedToChange(src) then
		return notify(src, "error.not_allowed", "error")
	end
	if setWeather(weather) then
		notify(src, "weather.updated", "success")
	else
		notify(src, "weather.invalid", "error")
	end
end)

RegisterNetEvent("w_weathersync:server:setTime", function(hour, minute)
	local src = source
	if not isAllowedToChange(src) then
		return notify(src, "error.not_allowed", "error")
	end
	if setTime(hour, minute) then
		notify(src, "time.change", "success", clockOf(hour, minute))
	else
		notify(src, "time.invalid", "error")
	end
end)

RegisterNetEvent("w_weathersync:server:toggleBlackout", function(state)
	local src = source
	if not isAllowedToChange(src) then
		return notify(src, "error.not_allowed", "error")
	end
	notify(src, setBlackout(state) and "blackout.enabled" or "blackout.disabled", "success")
end)

RegisterNetEvent("w_weathersync:server:toggleFreezeTime", function(state)
	local src = source
	if not isAllowedToChange(src) then
		return notify(src, "error.not_allowed", "error")
	end
	notify(src, setTimeFreeze(state) and "time.now_frozen" or "time.now_unfrozen", "success")
end)

RegisterNetEvent("w_weathersync:server:toggleDynamicWeather", function(state)
	local src = source
	if not isAllowedToChange(src) then
		return notify(src, "error.not_allowed", "error")
	end
	notify(src, setDynamicWeather(state) and "dynamic_weather.enabled" or "dynamic_weather.disabled", "success")
end)

-- COMMANDS (help texts use the server language: convar w_lib:locale)

WCore.Commands.Add("freezetime", locale("help.freezecommand"), {}, false, function(source)
	local newState = setTimeFreeze()
	notify(source, newState and "time.now_frozen" or "time.now_unfrozen", "success")
	w.print.info(newState and "time is now frozen" or "time is no longer frozen")
end, "god")

WCore.Commands.Add("freezeweather", locale("help.freezeweathercommand"), {}, false, function(source)
	local newState = setDynamicWeather()
	notify(source, newState and "dynamic_weather.enabled" or "dynamic_weather.disabled", "success")
	w.print.info(newState and "dynamic weather enabled" or "dynamic weather disabled")
end, "god")

WCore.Commands.Add(
	"weather",
	locale("help.weathercommand"),
	{ { name = locale("help.weathertype"), help = locale("help.availableweather") } },
	true,
	function(source, args)
		local weatherType = tostring(args[1]):lower()
		if setWeather(weatherType) then
			notify(source, "weather.willchangeto", "success", weatherType)
			w.print.info("weather changed to %s", weatherType)
		else
			notify(source, "weather.invalid", "error")
			w.print.warn("invalid weather type %s", weatherType)
		end
	end,
	"god"
)

WCore.Commands.Add("blackout", locale("help.blackoutcommand"), {}, false, function(source)
	local newState = setBlackout()
	notify(source, newState and "blackout.enabled" or "blackout.disabled", "success")
	w.print.info(newState and "blackout enabled" or "blackout disabled")
end, "god")

WCore.Commands.Add("morning", locale("help.morningcommand"), {}, false, function(source)
	setTime(9, 0)
	notify(source, "time.morning", "success")
end, "god")

WCore.Commands.Add("noon", locale("help.nooncommand"), {}, false, function(source)
	setTime(12, 0)
	notify(source, "time.noon", "success")
end, "god")

WCore.Commands.Add("evening", locale("help.eveningcommand"), {}, false, function(source)
	setTime(18, 0)
	notify(source, "time.evening", "success")
end, "god")

WCore.Commands.Add("night", locale("help.nightcommand"), {}, false, function(source)
	setTime(23, 0)
	notify(source, "time.night", "success")
end, "god")

WCore.Commands.Add(
	"time",
	locale("help.timecommand"),
	{
		{ name = locale("help.timehname"), help = locale("help.timeh") },
		{ name = locale("help.timemname"), help = locale("help.timem") },
	},
	false, -- minute is optional
	function(source, args)
		local hour = tonumber(args[1])
		local minute = tonumber(args[2])
		if setTime(hour, minute) then
			notify(source, "time.change", "success", clockOf(hour, minute))
		else
			notify(source, "time.invalid", "error")
		end
	end,
	"god"
)

-- THREAD LOOPS

CreateThread(function()
	local previous = 0
	while true do
		Wait(0)
		local newBaseTime = os.time(os.date("!*t")) / 2 + 360 -- server time follows the OS clock
		if (newBaseTime % 60) ~= previous then -- a new minute passed
			previous = newBaseTime % 60 -- only whole minutes here, seconds are handled on the client
			if freezeTime then
				timeOffset = timeOffset + baseTime - newBaseTime
			end
			baseTime = newBaseTime
		end
	end
end)

CreateThread(function()
	while true do
		Wait(2000)
		TriggerClientEvent("w_weathersync:client:SyncTime", -1, baseTime, timeOffset, freezeTime)
	end
end)

CreateThread(function()
	while true do
		Wait(300000)
		TriggerClientEvent("w_weathersync:client:SyncWeather", -1, CurrentWeather, blackout)
	end
end)

CreateThread(function()
	while true do
		newWeatherTimer = newWeatherTimer - 1
		Wait((1000 * 60) * Config.NewWeatherTimer)
		if newWeatherTimer == 0 then
			if Config.DynamicWeather then
				nextWeatherStage()
			end
			newWeatherTimer = Config.NewWeatherTimer
		end
	end
end)

-- EXPORTS

exports("nextWeatherStage", nextWeatherStage)
exports("setWeather", setWeather)
exports("setTime", setTime)
exports("setBlackout", setBlackout)
exports("setTimeFreeze", setTimeFreeze)
exports("setDynamicWeather", setDynamicWeather)
exports("getBlackoutState", function()
	return blackout
end)
exports("getTimeFreezeState", function()
	return freezeTime
end)
exports("getWeatherState", function()
	return CurrentWeather
end)
exports("getDynamicWeather", function()
	return Config.DynamicWeather
end)

-- Exports for the admin console (w_admin backend): PascalCase names over the same state.
-- None of these checks permissions -- the caller (w_admin) validates the admin first.

--- @param weather string  one of GetWeatherTypes() (case-insensitive)
--- @return boolean success
exports("SetWeather", setWeather)

--- @param hour number|string  0-24
--- @param minute number|string|nil  0-59
--- @return boolean success
exports("SetTime", setTime)

--- @return string  current weather type (upper case, e.g. 'SUNNY')
exports("GetWeather", function()
	return CurrentWeather
end)

--- The in-game clock as the clients compute it from the synced base/offset.
--- @return { hour: number, minute: number, frozen: boolean }
exports("GetTime", function()
	local total = baseTime + timeOffset
	return {
		hour = math.floor((total / 60) % 24),
		minute = math.floor(total % 60),
		frozen = freezeTime,
	}
end)

--- @return string[]  copy of Config.AvailableWeatherTypes
exports("GetWeatherTypes", function()
	local out = {}
	for i = 1, #Config.AvailableWeatherTypes do out[i] = Config.AvailableWeatherTypes[i] end
	return out
end)
