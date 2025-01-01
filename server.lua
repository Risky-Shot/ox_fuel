local config = require 'config'
local stations = require 'data.stations'

if not config then return end

if config.versionCheck then lib.versionCheck('overextended/ox_fuel') end

local ox_inventory = exports.ox_inventory

local function setFuelState(netId, fuel)
	local vehicle = NetworkGetEntityFromNetworkId(netId)

	if vehicle == 0 or GetEntityType(vehicle) ~= 2 then
		return
	end

	local state = Entity(vehicle)?.state
	fuel = math.clamp(fuel, 0, 100)

	state:set('fuel', fuel, true)
end

---@param playerId number
---@param price number
---@return boolean?
local function defaultPaymentMethod(playerId, price)
	local player  = exports.qbx_core:GetPlayer(playerId)
    if not player or not player.PlayerData.citizenid then 
        print('Not Player Found')
        return false 
    end

    local citizenid = player.PlayerData.citizenid

    local playerAccount = exports.ox_banking:GetCharacterAccount(citizenid)

    if not playerAccount then 
        print('Not Account Found')
        return false 
    end

    local accountId = playerAccount.accountId

    local response = exports.ox_banking:RemoveBalance(accountId, price, "Gas Refuel", true)

	return response.success or false
end

local payMoney = defaultPaymentMethod

exports('setPaymentMethod', function(fn)
	payMoney = fn or defaultPaymentMethod
end)

RegisterNetEvent('ox_fuel:pay', function(totalfuel, initialFuel, netid)
	local source = source
	local filledFuel  = totalfuel - initialFuel
	local price = filledFuel * config.defaultPrice
	if not payMoney(source, price) then return end

	totalfuel = math.floor(totalfuel)
	setFuelState(netid, totalfuel)

	TriggerClientEvent('ox_lib:notify', source, {
		type = 'success',
		description = locale('fuel_success', totalfuel, price)
	})
end)

-- Refill FuelCan Event
RegisterNetEvent('ox_fuel:fuelCan', function(currentFuel, stationId)
	local source = source
	local item = ox_inventory:GetCurrentWeapon(source)

	if not item or item.name ~= 'WEAPON_PETROLCAN' then return end

	local currentFuel = item.metadata.durability or item.metadata.ammo
	local price = (100 - currentFuel) * config.defaultPrice

	if not payMoney(source, price) then
		TriggerClientEvent('ox_lib:notify', source, {
			type = 'error',
			description = locale('not_enough_money', price)
		})
		return
	end

	item.metadata.durability = 100
	item.metadata.ammo = 100

	ox_inventory:SetMetadata(source, item.slot, item.metadata)

	print(currentFuel, stationId)

	TriggerClientEvent('ox_lib:notify', source, {
		type = 'success',
		description = locale('petrolcan_refill', price)
	})
end)

RegisterNetEvent('ox_fuel:updateFuelCan', function(durability, netid, fuel)
	local source = source
	local item = ox_inventory:GetCurrentWeapon(source)

	if item and durability > 0 then
		durability = math.floor(item.metadata.durability - durability)
		item.metadata.durability = durability
		item.metadata.ammo = durability

		ox_inventory:SetMetadata(source, item.slot, item.metadata)
		setFuelState(netid, fuel)
	end

	-- player is sus?
end)

lib.callback.register('ox_fuel:server:isRefuelAllowed', function(source, stationId, fuelAmount)
	if not stations[stationId] or not stations[stationId]?.isPlayerOwned then return false end

	local data = MySQL.single.await('SELECT `owned`, `fuel` FROM `fuel_stations` WHERE `stationId` = ? LIMIT 1', {
		stationId
	})

	if data.owned  == 1 and data.fuel > fuelAmount and data.fuel > config.stationReserve then
		return true
	end

	return false
end)

-- Nozzle Hose Sync
ActiveFuelHoses = {}

lib.callback.register('ox_fuel:server:checkPumpInUse', function(source, station, pumpId)
	local nozzleId = station..':'..pumpId

	-- Already In Use
	if ActiveFuelHoses[nozzleId] then return true end

	-- Set In Use
	ActiveFuelHoses[nozzleId] = true
	return false
end)

lib.callback.register('ox_fuel:server:removePumpInUse', function(source, nozzleId)
	-- Already In Use
	if not ActiveFuelHoses[nozzleId] then
		return false 
	end

	-- Set In Use
	ActiveFuelHoses[nozzleId] = false

	return true
end)

local refuelingVehicles = {}

AddStateBagChangeHandler('nozzle_veh', nil, function(bagName, key, value)
	local netId = tonumber(bagName:gsub('entity:', ''), 10)

	local entity = NetworkGetEntityFromNetworkId(netId)

	if not value then
		local data = refuelingVehicles[netId]

		if not data then 
			print('No Old Fuel Data Found')
			return 
		end

		local currentFuel = Entity(entity).state.fuel
		local oldFuel = data.currentFuel
		local payer = data.citizenid

		local playerAccount = exports.ox_banking:GetCharacterAccount(payer) or exports.qbx_core:GetOfflinePlayer(citizenid)

		if not playerAccount then 
			print('Not Account Found. Shouldnt be ideal situation')
			return false 
		end

		local accountId = playerAccount.accountId

		local price = (currentFuel - oldFuel) * config.defaultPrice

		if price > 0 then
			local response = exports.ox_banking:RemoveBalance(accountId, price, "Gas Refuel", true)
		end

		local player = exports.qbx_core:GetPlayerByCitizenId(payer)

		if player and not player.offline then
			local src = player.PlayerData.source
			TriggerClientEvent('ox_lib:notify', src, {
				type = 'success',
				description = locale('fuel_success', currentFuel, (currentFuel - oldFuel) * config.defaultPrice)
			})
		end

		refuelingVehicles[netId] = nil
		return
	end

	refuelingVehicles[netId] = {
		currentFuel = value.currentFuel,
		citizenid = value.citizenid,
		refueling = true
	}
end)

CreateThread(function()
	while true do
		for k,v in pairs(refuelingVehicles) do
			if not v.refueling then
				goto continue
			end

			local entity = NetworkGetEntityFromNetworkId(k)

			local state = Entity(entity).state

			state.fuel = lib.math.clamp(state.fuel + config.refillValue, 0, 100)

			if state.fuel >= 100 then
				v.refueling = false
			end

			::continue::
		end
		Wait(config.refillTick)
	end
end)