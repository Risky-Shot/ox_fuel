local config = require 'config'
local state  = require 'client.state'
local utils  = require 'client.utils'
local fuel   = require 'client.fuel'

---@field pump entity
local function GenerateNozzleOnPump(pump)
	if not lib.requestAnimDict("anim@am_hold_up@male") then print('Failed to load anim.') return end

	TaskPlayAnim(cache.ped, "anim@am_hold_up@male", "shoplift_high", 2.0, 8.0, -1, 50, 0, 0, 0, 0)

	Wait(300)

	state.nozzleEntity = CreateObject(`prop_cs_fuel_nozle`, 0, 0, 0, true, true, true)

	SetEntityCollision(state.nozzleEntity, false, true)

	AttachEntityToEntity(state.nozzleEntity, cache.ped, GetPedBoneIndex(cache.ped, 0x49D9), 0.11, 0.02, 0.02, -80.0, -90.0, 15.0, true, true, false, true, 1, true)

	RopeLoadTextures()
    while not RopeAreTexturesLoaded() do
		RopeLoadTextures()
        Wait(1)
    end
	RopeLoadTextures()

	Wait(1)

    local pumpCoords = GetEntityCoords(pump)
	state.rope = AddRope(pumpCoords.x, pumpCoords.y, pumpCoords.z, 0.0, 0.0, 0.0, 3.0, 1, 1000.0, 0.0, 1.0, false, false, false, 1.0, false)

	while not state.rope do
		Wait(0)
	end

	local nozzleCoords = GetEntityCoords(state.nozzleEntity)

	nozzleCoords = GetOffsetFromEntityInWorldCoords(state.nozzleEntity, 0.0, -0.033, -0.195)

	AttachEntitiesToRope(state.rope, pump, state.nozzleEntity, pumpCoords.x, pumpCoords.y, pumpCoords.z + 1.45, nozzleCoords.x, nozzleCoords.y, nozzleCoords.z, 5.0, false, false, nil, nil)
end

-- required vehicle, tankBone, isBike, tankPos
local function AttachNozzleToVehicle(vehicle)
	if not lib.requestAnimDict("timetable@gardener@filling_can") then return false end

	TaskPlayAnim(cache.ped, "timetable@gardener@filling_can", "gar_ig_5_filling_can", 2.0, 8.0, -1, 50, 0, 0, 0, 0)
	Wait(300)

	if vehicle and DoesVehicleUseFuel(vehicle) then
		print('Vehicle Uses Fuel')
		local boneIndex = utils.getVehiclePetrolCapBoneIndex(vehicle)
		print('BoneIndex', boneIndex)
		local fuelcapPosition = boneIndex and GetWorldPositionOfEntityBone(vehicle, boneIndex)
		print('CapPos', fuelcapPosition)

		local isBike = false
		local vehClass = GetVehicleClass(vehicle)
		if vehClass == 8 and vehClass ~= 13 then
			isBike = true
		end

		if isBike then
			print('CapPos', fuelcapPosition, state.nozzleEntity)
			AttachEntityToEntity(state.nozzleEntity, vehicle, boneIndex, 0.0, -0.2, 0.2, -80.0, 0.0, 0.0, true, true, false, false, 1, true)
		else
			print('CapPos', fuelcapPosition)
			AttachEntityToEntity(state.nozzleEntity, vehicle, boneIndex, -0.18, 0.0 , 0.75 , -125.0, -90.0, -90.0, true, true, false, false, 1, true)
		end

		ClearPedTasks(cache.ped)
		return true
	else
		return false
	end
end

local function GrabNozzleFromVehicle(vehicle)
	if state.nozzleEntity and DoesEntityExist(state.nozzleEntity) then
		AttachEntityToEntity(state.nozzleEntity, cache.ped, GetPedBoneIndex(cache.ped, 0x49D9), 0.11, 0.02, 0.02, -80.0, -90.0, 15.0, true, true, false, true, 1, true)
		state.isFueling = false
		state.insertedNozzle = false
		state.holdingNozzle = true
	end
end

local function AttachNozzleToPump(pump)
	DeleteEntity(state.nozzleEntity)
    RopeUnloadTextures()
    DeleteRope(state.rope)

	state.nozzleEntity = nil
	state.rope = nil
	state.holdingNozzle = false
end

if config.useHose then
	local bones = {
		"petroltank",
		"petroltank_l",
		"petroltank_r",
		"wheel_rf",
		"wheel_rr",
		"petrolcap ",
		"seat_dside_r",
		"engine",
	}

	-- Fuel Vehicle (on select -> show menu -> )
	--
	-- Grab Nozzle

	exports.ox_target:addGlobalVehicle({
		{
			distance = 2,
			onSelect = function(data)
				print('Refuel Started', json.encode(data, {indent = true}))
				if GetIsVehicleEngineRunning(data.entity) then return lib.notify({ type = 'error', description = locale('engine_on') }) end
				if AttachNozzleToVehicle(data.entity) then	
					state.holdingNozzle = false
					state.insertedNozzle = true
					fuel.startFueling(state.lastVehicle, 1)
				end
			end,
			icon = "",
			label = locale('start_fueling'),
			canInteract = function(entity)
				if state.isFueling then
					return false
				end

				return state.holdingNozzle
			end,
			bones = bones
		},
		{
			distance = 2,
			onSelect = function(data)
				GrabNozzleFromVehicle(data.entity)
			end,
			icon = "",
			label = locale('grab_nozzle'),
			canInteract = function(entity)
				if not state.insertedNozzle then
					return false
				end

				return true
			end,
			bones = bones
		}
	})
end

exports.ox_target:addModel(config.pumpModels, {
	{
		distance = 2,
		onSelect = function(data)
			state.holdingNozzle = true
			GenerateNozzleOnPump(data.entity)
		end,
		icon = "fas fa-gas-pump",
		label = locale('grab_nozzle'),
		canInteract = function(entity)
			if state.isFueling or cache.vehicle or lib.progressActive() or state.holdingNozzle or not state.nearestStation then
				return false
			end

			return state.lastVehicle and #(GetEntityCoords(state.lastVehicle) - GetEntityCoords(cache.ped)) <= 3
		end
	},
	{
		distance = 2,
		onSelect = function(data)
			AttachNozzleToPump(data.entity)
		end,
		icon = "fas fa-gas-pump",
		label = locale('insert_nozzle'),
		canInteract = function(entity)
			if state.isFueling or cache.vehicle or lib.progressActive() or not state.holdingNozzle or not state.nearestStation then
				return false
			end

			return state.lastVehicle and #(GetEntityCoords(state.lastVehicle) - GetEntityCoords(cache.ped)) <= 3
		end
	},
	{
		distance = 2,
		onSelect = function(data)
			local petrolCan = config.petrolCan.enabled and GetSelectedPedWeapon(cache.ped) == `WEAPON_PETROLCAN`

			if petrolCan then
				local currentWeapon = exports.ox_inventory:getCurrentWeapon() 

				if not currentWeapon.hash == `WEAPON_PETROLCAN` then return end

				local currentFuel = currentWeapon.metadata?.ammo or 0

				fuel.getPetrolCan(data.coords, currentFuel)
			end
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
				if state.isFueling or cache.vehicle or lib.progressActive() or not DoesVehicleUseFuel(entity) then
					return false
				end
				return state.petrolCan and config.petrolCan.enabled
			end
		}
	})
end

RegisterCommand("ox:fuel:debug", function()
	print('Nozzel Data', state.nozzleEntity, GetEntityCoords(state.nozzleEntity))
	print(state.lastVehicle)
	print(Entity(state.lastVehicle).state.fuel)
end)