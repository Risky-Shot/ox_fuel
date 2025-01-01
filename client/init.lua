local config = require 'config'

if not config then return end

SetFuelConsumptionState(true)
SetFuelConsumptionRateMultiplier(config.globalFuelConsumptionRate)

AddTextEntry('fuelHelpText', locale('fuel_help'))
AddTextEntry('petrolcanHelpText', locale('petrolcan_help'))
AddTextEntry('fuelLeaveVehicleText', locale('leave_vehicle'))
AddTextEntry('ox_fuel_station', locale('fuel_station_blip'))

local utils = require 'client.utils'
local state = require 'client.state'
local fuel  = require 'client.fuel'

local stations = require 'data.stations'

require 'client.target'
require 'client.stations'

local function startDrivingVehicle()
	local vehicle = cache.vehicle

	if not DoesVehicleUseFuel(vehicle) then return end

	if not NetworkGetEntityIsNetworked(vehicle) then return end

	local vehState = Entity(vehicle).state

	if not vehState.fuel then
		vehState:set('fuel', GetVehicleFuelLevel(vehicle), true)
		while not vehState.fuel do Wait(0) end
	end

	SetVehicleFuelLevel(vehicle, vehState.fuel)

	local usage = config.classUsage[GetVehicleClass(vehicle)] or 1.0

	if usage == 0.0 then return end

	local fuelTick = 0

	while cache.seat == -1 do
		if not DoesEntityExist(vehicle) then return end

		local fuelAmount = tonumber(vehState.fuel)
		local newFuel = fuelAmount

		if fuelAmount > 0 and GetIsVehicleEngineRunning(vehicle) then
			if GetVehiclePetrolTankHealth(vehicle) < 700 then
				newFuel -= math.random(10, 20) * 0.01
			end

			local rpmMultiplier = config.rpmModifier[math.floor(GetVehicleCurrentRpm(vehicle) * 10) / 10]

			newFuel = fuelAmount - (usage * rpmMultiplier)

			if fuelAmount ~= newFuel then
				if fuelTick == 15 then
					fuelTick = 0
				end

				fuel.setFuel(vehState, vehicle, newFuel, fuelTick == 0)
				fuelTick += 1
			end
		end
		Wait(1000)
	end

	fuel.setFuel(vehState, vehicle, vehState.fuel, true)
end

if cache.seat == -1 then CreateThread(startDrivingVehicle) end

lib.onCache('seat', function(seat)
	if cache.vehicle then
		local vehClass = GetVehicleClass(cache.vehicle)

		if vehClass ~= 13 then
			state.lastVehicle = cache.vehicle
		end
	end

	if seat == -1 then
		SetTimeout(0, startDrivingVehicle)
	end
end)

-- Command to refuel vehicle where there pumps = nil in data/stations.lua (usually helipads and boat areas)
RegisterCommand('refuel', function()
	if state.isFueling or cache.vehicle or lib.progressActive() then return end

	local playerCoords = GetEntityCoords(cache.ped)

	local insideStation = state.nearestStation

	local hasPumps = stations[state.nearestStation]?.pumps

	if not insideStation or hasPumps then
		return lib.notify({ type = 'error', description = locale('not_near_station') })
	end

	if not config.commandClass[GetVehicleClass(state.lastVehicle)] then
		return lib.notify({ type = 'error', description = locale('vehicle_class') })
	end

	local vehicleInRange = state.lastVehicle and #(GetEntityCoords(state.lastVehicle) - playerCoords) <= 3

	if not vehicleInRange then 
		return lib.notify({ type = 'error', description = locale('vehicle_far') })
	end
	--- vehicle, isFromPump
	fuel.startFueling(state.lastVehicle, true)
end)

--TriggerEvent('chat:removeSuggestion', '/startfueling')

