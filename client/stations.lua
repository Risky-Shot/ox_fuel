local config = require 'config'
local state = require 'client.state'
local utils = require 'client.utils'
local stations = lib.load 'data.stations'

if config.showBlips == 2 then
	for stationId, stationData in pairs(stations) do utils.createBlip(stationData.coords) end
end

---@param point CPoint
local function onEnterStation(point)
	if config.showBlips == 1 and not point.blip then
		point.blip = utils.createBlip(point.coords)
	end

	print('Inside Station', point.stationId)
	state.nearestStation = point.stationId
end

---@param point CPoint
local function nearbyStation(point)
	if state.isFueling and state.nozzleEntity then -- for petrol pump
		qbx.drawText3d({ coords = GetEntityCoords(state.nozzleEntity), text = tostring(state.refillingValue) })
	elseif state.isFueling then -- for jerry can
		qbx.drawText3d({ coords = GetEntityCoords(state.lastVehicle), text = tostring(state.refillingValue) })
	end
end

---@param point CPoint
local function onExitStation(point)
	if point.blip then
		point.blip = RemoveBlip(point.blip)
	end
	state.nearestStation = nil

	if not state.holdingNozzle then return end
	if state.rope then
		DeleteRope(state.rope)
		state.rope = nil
	end

	if state.nozzleEntity and DoesEntityExist(state.nozzleEntity) then
		DeleteEntity(state.nozzleEntity)
		state.nozzleEntity = nil
	end
	RopeUnloadTextures()
	ClearPedTasks(cache.ped)
	state.holdingNozzle = false
end

for stationId, stationData in pairs(stations) do
	lib.points.new({
		coords = stationData.coords,
		distance = 40,
		onEnter = onEnterStation,
		onExit = onExitStation,
		nearby = nearbyStation,
		stationData = stationData,
		stationId = stationId
	})
end
