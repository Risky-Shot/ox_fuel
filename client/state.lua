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
	refillingValue = 0.0,
	currentNozzleId = nil,
	currentPumpCoords = nil,
	nearestVehicle = nil
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
		ClearPedTasks(cache.ped)
	end
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', function(source) 
	
end)

return state
