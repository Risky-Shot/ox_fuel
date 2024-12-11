---@class State
---@field petrolCan SlotWithItem?
---@field isFueling boolean
---@field nearestPump vector3?
---@field lastVehicle number?
---@field holdingNozzle boolean
---@field nozzleEntity number?
---@field rope number?
local state = {
	isFueling = false,
	lastVehicle = cache.vehicle or GetPlayersLastVehicle(),
	holdingNozzle = false,
	insertedNozzle = false,
	refillingValue = 0.0
}

if state.lastVehicle == 0 then state.lastVehicle = nil end

---@param data? SlotWithItem
local function setPetrolCan(data)
	state.petrolCan = data?.name == 'WEAPON_PETROLCAN' and data or nil
end

setPetrolCan(exports.ox_inventory:getCurrentWeapon())

AddEventHandler('ox_inventory:currentWeapon', setPetrolCan)

AddEventHandler('onResourceStop', function(resource)
	if resource == GetCurrentResourceName() then
		if state.rope then
			DeleteRope(state.rope)
		end

		if state.nozzleEntity and DoesEntityExist(state.nozzleEntity) then
			DeleteEntity(state.nozzleEntity)
		end
		ClearPedTasks(cache.ped)
		RopeUnloadTextures()
		print('Unloaded Data')
	end
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(source) 
	if state.rope then
		DeleteRope(state.rope)
	end

	if state.nozzleEntity and DoesEntityExist(state.nozzleEntity) then
		DeleteEntity(state.nozzleEntity)
	end
	ClearPedTasks(cache.ped)
	RopeUnloadTextures()
	print('Unloaded Data')
end)

return state
