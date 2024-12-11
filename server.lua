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

	print('Updated Vehicle', netId, fuel)

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

    local response = exports.ox_banking:RemoveBalance(accountId, price, "Gas Refuel", false)

    if response.success == true then 
        print('Paid Money')
        return true 
    end

    return false
end

local payMoney = defaultPaymentMethod

exports('setPaymentMethod', function(fn)
	payMoney = fn or defaultPaymentMethod
end)

RegisterNetEvent('ox_fuel:pay', function(totalfuel, initialFuel, netid)
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

RegisterNetEvent('ox_fuel:fuelCan', function(currentFuel, stationId)
	print(currentFuel, stationId)
	local item = ox_inventory:GetCurrentWeapon(source)

	if not item or item.name ~= 'WEAPON_PETROLCAN' then 
		print('No Enough Money')
		return 
	end

	local currentFuel = item.metadata.durability or item.metadata.ammo
	local price = (100-currentFuel) * config.defaultPrice

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
