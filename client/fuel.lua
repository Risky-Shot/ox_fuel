local config = require 'config'
local state = require 'client.state'
local utils = require 'client.utils'
local fuel = {}

local stations = lib.load 'data.stations'

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

function fuel.getPetrolCan(coords, currentFuel)
	if state.nearestStation and stations[state.nearestStation].isPlayerOwned then
		local canRefuel = lib.callback.await('ox_fuel:server:isRefuelAllowed', false, state.nearestStation, 100 - currentFuel)

		if not canRefuel then 
			return lib.notify({ type = 'error', description = locale('station_empty') })
		end
	end

	TaskTurnPedToFaceCoord(cache.ped, coords.x, coords.y, coords.z, config.petrolCan.duration)
	Wait(500)

	if lib.progressCircle({
			duration = config.petrolCan.duration,
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

	if not isPump then
		TaskTurnPedToFaceEntity(cache.ped, vehicle, duration)
	end
	Wait(500)

	if not config.useHose then
		CreateThread(function()
			lib.progressCircle({
				duration = duration,
				useWhileDead = false,
				canCancel = true,
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
	elseif isPump then
		-- CreateThread(function()
		-- 	lib.progressCircle({
		-- 		duration = duration,
		-- 		useWhileDead = false,
		-- 		canCancel = true,
		-- 		disable = {
		-- 			car = true,
		-- 		},
		-- 	})

		-- 	state.isFueling = false
		-- end)
	end

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

		print('Started Refueling', fuelAmount)

		if fuelAmount >= 100 then
			state.isFueling = false
			fuelAmount = 100.0
		end

		Wait(config.refillTick)
	end

	ClearPedTasks(cache.ped)
	RemoveAnimDict("anim@am_hold_up@male") -- Grabbing Nozle
	RemoveAnimDict("timetable@gardener@filling_can") -- Fueling Vehicle

	print('Stopped Filling Fuel')

	if isPump then
		TriggerServerEvent('ox_fuel:pay', fuelAmount, initialAmount, NetworkGetNetworkIdFromEntity(vehicle))
	else
		TriggerServerEvent('ox_fuel:updateFuelCan', durability, NetworkGetNetworkIdFromEntity(vehicle), fuelAmount, initialAmount)
	end
end

RegisterCommand('setfuel:ox', function()
	if not cache.vehicle then print('No Car Found') return end

	local vehState = Entity(cache.vehicle).state
	
	fuel.setFuel(vehState, cache.vehicle, 10, true)
end)

return fuel
