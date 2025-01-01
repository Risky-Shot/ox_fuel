local utils = {}

local stations = lib.load 'data.stations'

function utils.getNearestPump(stationId, coords)
	local pump = nil

	for pumpId, pumpCoords in pairs(stations[stationId].pumps) do
		if #(pumpCoords - coords) < 0.5 then
			pump = pumpId
			break
		end
	end

	return pump
end

---@param coords vector3
---@return integer
function utils.createBlip(coords, blipData)
	local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
	SetBlipSprite(blip, 361)
	SetBlipDisplay(blip, 4)
	SetBlipScale(blip, 0.6)
	SetBlipColour(blip, 6)
	SetBlipAsShortRange(blip, true)
	BeginTextCommandSetBlipName('ox_fuel_station')
	EndTextCommandSetBlipName(blip)

	return blip
end

function utils.getVehicleInFront()
	local coords = GetEntityCoords(cache.ped)
	local destination = GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, 2.2, -0.25)
	local handle = StartShapeTestCapsule(coords.x, coords.y, coords.z, destination.x, destination.y, destination.z, 2.2,
		2, cache.ped, 4)

	while true do
		Wait(0)
		local retval, _, _, _, entityHit = GetShapeTestResult(handle)

		if retval ~= 1 then
			return entityHit ~= 0 and entityHit
		end
	end
end

local bones = {
	"petroltank",
	"petroltank_l",
	"petroltank_r",
	"hub_lr",
	"seat_dside_r",
}

---@param vehicle integer
function utils.getVehiclePetrolCapBoneIndex(vehicle)
	for i = 1, #bones do
		local boneIndex = GetEntityBoneIndexByName(vehicle, bones[i])

		if boneIndex ~= -1 then
			return boneIndex
		end
	end
end

function utils.DoesVehicleUseFuel(vehicle)
	if DoesVehicleUseFuel(vehicle) then return true end

end

local min, max, ceil, abs, floor = math.min, math.max, math.ceil, math.abs, math.floor

function utils.clampValue(value, min, max)
    if value < min then
        return min
    elseif value > max then
        return max
    else
        return value
    end
end
---@return number
local function defaultMoneyCheck()
	return exports.ox_inventory:GetItemCount('money')
end

utils.getMoney = defaultMoneyCheck

exports('setMoneyCheck', function(fn)
	utils.getMoney = fn or defaultMoneyCheck
end)

function utils.getEntityFromStateBag(bagName, keyName)

    if bagName:find('entity:') then
        local netId = tonumber(bagName:gsub('entity:', ''), 10)

        local entity =  lib.waitFor(function()
            if NetworkDoesEntityExistWithNetworkId(netId) then return NetworkGetEntityFromNetworkId(netId) end
        end, ('%s received invalid entity! (%s)'):format(keyName, bagName), 10000)

        return entity
    elseif bagName:find('player:') then
        local serverId = tonumber(bagName:gsub('player:', ''), 10)
        local playerId = GetPlayerFromServerId(serverId)

        local entity = lib.waitFor(function()
            local ped = GetPlayerPed(playerId)
            if ped > 0 then return ped end
        end, ('%s received invalid entity! (%s)'):format(keyName, bagName), 10000)

        return serverId, entity
    end

end

return utils
