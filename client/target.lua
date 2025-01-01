local config = require 'config'
local state  = require 'client.state'
local utils  = require 'client.utils'
local fuel   = require 'client.fuel'

local bones = {
	"petroltank",
	"petroltank_l",
	"petroltank_r",
	"hub_lr",
	"seat_dside_r",
}

-- Fuel Vehicle (on select -> show menu -> )
--
-- Grab Nozzle

exports.ox_target:addGlobalVehicle({
	{
		distance = 2,
		icon = "",
		label = locale('start_fueling'),
		onSelect = function(data)
			if GetIsVehicleEngineRunning(data.entity) then return lib.notify({ type = 'error', description = locale('engine_on') }) end

			if not state.currentNozzleId and not state.currentPumpCoords then 
				return lib.notify({ type = 'error', description = locale('already_nozzle_veh')})
			end

			local netId = VehToNet(data.entity)

			local hasControl = lib.waitFor(function()
				NetworkRequestControlOfNetworkId(netId)
				if NetworkHasControlOfNetworkId(netId) then 
					print('Received Control of NetId')
					return true 
				end
			end, 'Failed to request Entity Control', 10000)

			if not hasControl then 
				print('Failed to Get Control of Entity')
				return 
			end

			local entState = Entity(data.entity).state

			if entState and entState.nozzle_veh then 
				return lib.notify({ type = 'error', description = locale('already_nozzle_veh') })
			end

			Entity(data.entity).state:set('nozzle_veh', {
				id = state.currentNozzleId,
				pumpCoords = state.currentPumpCoords,
				currentFuel = Entity(data.entity).state?.fuel,
				citizenid = QBX.PlayerData.citizenid
			}, true)

			state.currentNozzleId = nil
			state.currentPumpCoords = nil

			LocalPlayer.state:set('nozzle_pump', nil, true)

			lib.notify({ type = 'success', description = locale('nozzle_veh_success') })
		end,
		canInteract = function(entity)
			if not state.nearestStation or not state.currentNozzleId then
				return false
			end
			return true
		end,
		bones = bones
	},
	{	
		icon = "",
		label = locale('grab_nozzle'),
		distance = 2,
		onSelect = function(data)

			local netId = VehToNet(data.entity)

			local hasControl = lib.waitFor(function()
				NetworkRequestControlOfNetworkId(netId)
				if NetworkHasControlOfNetworkId(netId) then 
					print('Received Control of NetId')
					return true 
				end
			end, 'Failed to request Entity Control', 10000)

			if not hasControl then 
				print('Failed to Get Control of Entity')
				return 
			end

			local entState = Entity(data.entity).state

			if not entState.nozzle_veh then 
				return 
			end

			LocalPlayer.state:set('nozzle_pump', {
				id = entState.nozzle_veh.id,
				pumpCoords = entState.nozzle_veh.pumpCoords,
			}, true)

			state.currentNozzleId = entState.nozzle_veh.id
			state.currentPumpCoords = entState.nozzle_veh.pumpCoords

			Entity(data.entity).state:set('nozzle_veh', nil, true)
		end,
		canInteract = function(entity)
			if not vehicleHoldingHoses[entity] then return false end

			return true
		end,
		bones = bones
	}
})

exports.ox_target:addModel(config.pumpModels, {
	{
		icon = "fas fa-gas-pump",
		label = locale('grab_nozzle'),
		distance = 2,
		onSelect = function(data)		
			local pump = utils.getNearestPump(state.nearestStation, GetEntityCoords(data.entity))

			local inUse = lib.callback.await('ox_fuel:server:checkPumpInUse', false, state.nearestStation, pump)

			if inUse then return lib.notify({ type = 'error', description = 'Fuel Pump Already in Use'}) end

			local nozzleId = tostring(state.nearestStation .. ':'..pump)
			
			LocalPlayer.state:set('nozzle_pump', {
				id = nozzleId,
				pumpCoords = GetEntityCoords(data.entity)
			}, true)

			-- Wait(100)
			state.currentNozzleId = nozzleId
			state.currentPumpCoords = GetEntityCoords(data.entity)
		end,
		canInteract = function(entity)
			if state.currentNozzleId or not state.nearestStation then
				return false
			end
			return true
		end
	},
	{
		distance = 2,
		icon = "fas fa-gas-pump",
		label = locale('insert_nozzle'),
		onSelect = function(data)
			if not state.currentNozzleId or not state.currentPumpCoords then return end

			local removedUse = lib.callback.await('ox_fuel:server:removePumpInUse', false, state.currentNozzleId)

			if not removedUse then return end

			LocalPlayer.state:set('nozzle_pump', nil, true)

			state.currentNozzleId = nil
			state.currentPumpCoords = nil
		end,
		canInteract = function(entity)
			if not state.currentNozzleId or not state.nearestStation then
				return false
			end
			return true
		end
	},
	{
		distance = 2,
		onSelect = function(data)
			local petrolCan = config.petrolCan.enabled and GetSelectedPedWeapon(cache.ped) == `WEAPON_PETROLCAN`

			if not petrolCan then return lib.notify({ type = 'error', description = locale('petrolcan_not_equipped') }) end

			local currentWeapon = exports.ox_inventory:getCurrentWeapon() 

			if not currentWeapon.hash == `WEAPON_PETROLCAN` then return end

			local currentFuel = currentWeapon.metadata?.ammo or 0

			fuel.getPetrolCan(data.coords, currentFuel)
		end,
		icon = "fas fa-faucet",
		label = locale('petrolcan_refill_pump'),
		canInteract = function(entity)
			if not state.nearestStation then 
				return false
			end

			return true
		end
	}
})

if config.petrolCan.enabled then
	exports.ox_target:addGlobalVehicle({
		{
			distance = 2,
			onSelect = function(data)
				if not state.petrolCan then
					return lib.notify({ type = 'error', description = locale('petrolcan_not_equipped') })
				end

				if state.petrolCan.metadata.ammo <= config.durabilityTick then
					return lib.notify({
						type = 'error',
						description = locale('petrolcan_not_enough_fuel')
					})
				end

				fuel.startFueling(data.entity)
			end,
			icon = "fas fa-gas-pump",
			label = locale('start_fueling'),
			canInteract = function(entity)
				if state.isFueling or cache.vehicle or lib.progressActive() then
					return false
				end
				return state.petrolCan and config.petrolCan.enabled
			end
		}
	})
end

--[[
	-- Holding Nozzle (Player Entity)
	-- Inserted Nozzle (Vehicle Entity)
	-- a variable storing all ropes data
	-- fueling_rope state (contains vehicle, pump) on pump
]]