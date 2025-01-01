local config = require 'config'
local state = require 'client.state'
local utils = require 'client.utils'
local fuel = {}

local stations = lib.load 'data.stations'

local math = lib.math

---@param vehState StateBag
---@param vehicle integer
---@param amount number
---@param replicate? boolean
function fuel.setFuel(vehState, vehicle, amount, replicate)
	if DoesEntityExist(vehicle) then
		
		amount = math.clamp(amount, 0, 100)

		SetVehicleFuelLevel(vehicle, amount)
		vehState:set('fuel', amount, replicate)
	end
end

-- Used to Refill Fuel Can
function fuel.getPetrolCan(coords, currentFuel)
	if state.nearestStation and stations[state.nearestStation].isPlayerOwned then
		local canRefuel = lib.callback.await('ox_fuel:server:isRefuelAllowed', false, state.nearestStation, 100 - currentFuel)

		if not canRefuel then 
			return lib.notify({ type = 'error', description = locale('station_empty') })
		end
	end

	local duration = math.ceil((100 - currentFuel) / config.refillValue) * config.refillTick

	duration = math.max(duration, 1000) -- Ensure Atleast 1 second progressbar

	TaskTurnPedToFaceCoord(cache.ped, coords.x, coords.y, coords.z, duration)

	Wait(500)

	if lib.progressBar({
		label = 'Refueling Fuelcan',
		duration = duration, -- Makre sure it's 1 seconds atleast
		useWhileDead = false,
		canCancel = true,
		disable = {
			move = true,
			car = true,
			combat = true,
		},
		anim = {
			dict = 'timetable@gardener@filling_can',
			clip = 'gar_ig_5_filling_can',
			flags = 49,
		}
	}) then
		if exports.ox_inventory:GetItemCount('WEAPON_PETROLCAN') then
			return TriggerServerEvent('ox_fuel:fuelCan', currentFuel, state.nearestStation)
		end
	end

	ClearPedTasks(cache.ped)
end

function fuel.startFueling(vehicle, isPump)
	local vehState = Entity(vehicle).state
	local fuelAmount = vehState.fuel or GetVehicleFuelLevel(vehicle)
	local duration = math.ceil((100 - fuelAmount) / config.refillValue) * config.refillTick

	local initialAmount = fuelAmount
	local durability = 0

	if 100 - fuelAmount < config.refillValue then
		return lib.notify({ type = 'error', description = locale('tank_full') })
	end

	if isPump then
		-- Is Pump thing (used to be money check here)
		-- check if enough fuel
		if state.nearestStation and stations[state.nearestStation].isPlayerOwned then
			-- Check for Fuel in Station
			local canRefuel = lib.callback.await('ox_fuel:server:isRefuelAllowed', false, state.nearestStation, 100 - fuelAmount)

			if not canRefuel then 
				return lib.notify({ type = 'error', description = locale('station_empty') })
			end
		end
	elseif not state.petrolCan then
		return lib.notify({ type = 'error', description = locale('petrolcan_not_equipped') })
	elseif state.petrolCan.metadata.ammo <= config.durabilityTick then
		return lib.notify({
			type = 'error',
			description = locale('petrolcan_not_enough_fuel')
		})
	end

	state.isFueling = true

	TaskTurnPedToFaceEntity(cache.ped, vehicle, duration)

	Wait(500)

	CreateThread(function()
		lib.progressBar({
			label = 'Refueling Vehicle',
			duration = duration,
			useWhileDead = false,
			canCancel = true,
			allowSwimming = true,
			disable = {
				move = true,
				car = true,
				combat = true,
			},
			anim = {
				dict = isPump and 'timetable@gardener@filling_can' or 'weapon@w_sp_jerrycan',
				clip = isPump and 'gar_ig_5_filling_can' or 'fire',
			},
		})

		state.isFueling = false
	end)

	while state.isFueling do
		if isPump then
			-- Check if fuel available here
		elseif state.petrolCan then
			durability += config.durabilityTick

			if durability >= state.petrolCan.metadata.ammo then
				lib.cancelProgress()
				durability = state.petrolCan.metadata.ammo
				break
			end
		else
			break
		end

		fuelAmount += config.refillValue

		state.refillingValue = fuelAmount

		if fuelAmount >= 100 then
			state.isFueling = false
			fuelAmount = 100.0
		end

		Wait(config.refillTick)
	end

	ClearPedTasks(cache.ped)

	if isPump then
		TriggerServerEvent('ox_fuel:pay', fuelAmount, initialAmount, NetworkGetNetworkIdFromEntity(vehicle))
	else
		TriggerServerEvent('ox_fuel:updateFuelCan', durability, NetworkGetNetworkIdFromEntity(vehicle), fuelAmount, initialAmount)
	end
end

return fuel