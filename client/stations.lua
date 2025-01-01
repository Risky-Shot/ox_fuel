local config = require 'config'
local state = require 'client.state'
local utils = require 'client.utils'
local stations = lib.load 'data.stations'

if config.showBlips == 2 then
	for stationId, stationData in pairs(stations) do 
		if stationData.showBlip then
			utils.createBlip(stationData.coords) 
		end
	end
end

---@param point CPoint
local function onEnterStation(zone)
	state.nearestStation = zone.stationId

	if not zone.stationData.pumps then
		lib.notify({ type = 'inform', description = locale('command_suggest') })
	end

	CreateThread(function()
		while state.nearestStation do
			state.nearestVehicle = lib.getClosestVehicle(cache.coords, 4.0)
			if vehicleHoldingHoses[state.nearestVehicle] then
				state.nearestVehicleFuel = Entity(state.nearestVehicle).state.fuel
			end
			Wait(1000)
		end
	end)
end

---@param zone CPoint
local function nearbyStation(zone)
	if not cache.coords then return end

	if not state.nearestVehicle then return end

	if vehicleHoldingHoses[state.nearestVehicle] then
		local data = vehicleHoldingHoses[state.nearestVehicle]
		qbx.drawText3d({ coords = GetEntityCoords(data.nozzleEntity), text = tostring(state.nearestVehicleFuel or 0.0) })
	end
end

---@param point CPoint
local function onExitStation(zone)
	if zone.blip then
		zone.blip = RemoveBlip(zone.blip)
	end
	state.nearestStation = nil

	if state.isFueling then return end

	state.nearestVehicle = nil
	state.nearestVehicleFuel = nil

	if LocalPlayer.state.nozzle_pump and state.currentNozzleId then
		local removedUse = lib.callback.await('ox_fuel:server:removePumpInUse', false, state.currentNozzleId)

		if not removedUse then return end

		state.currentNozzleId = nil
		state.currentPumpCoords = nil

		LocalPlayer.state:set('nozzle_pump', nil, true)
	end
end

for stationId, stationData in pairs(stations) do
	lib.zones.poly({
		points = stationData.zoneData.points,
		thickness = stationData.zoneData.thickness,
		onEnter = onEnterStation,
		onExit = onExitStation,
		inside = nearbyStation,
		stationData = stationData,
		stationId = stationId,
		debug = true
	})
end
