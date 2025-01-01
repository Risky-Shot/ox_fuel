local state  = require 'client.state'
local utils  = require 'client.utils'

playerHoldingHoses = {}
vehicleHoldingHoses = {}

ClearPedTasks(cache.ped)
LocalPlayer.state:set('nozzle_pump', nil, true)

-- Create Nozzle and Hose
local function GenerateHose(pumpCoords)
    print('Hose Generate Started', pumpCoords)
    if not lib.requestModel("prop_cs_fuel_nozle", 10000) then print('Failed to load model.') return end
    if not lib.requestModel("prop_tequila_bottle", 10000) then print('Failed to load model.') return end
    
    -- Create invisibleItemItem Item at pumpCoords
    local invisibleItem = CreateObject(`prop_tequila_bottle`, pumpCoords.x, pumpCoords.y, pumpCoords.z, false, false, false)

    lib.waitFor(function()
        if DoesEntityExist(invisibleItem) then return true end
    end, 'Failed To Create Invisible Item', 10000)

    FreezeEntityPosition(invisibleItem, true)
    SetEntityCollision(invisibleItem, false, true)
    SetEntityVisible(invisibleItem, false, 0)
    SetModelAsNoLongerNeeded(`prop_tequila_bottle`)

    print('invisibleItem Item', invisibleItem, GetEntityCoords(invisibleItem))

    -- Create Nozzle
    local nozzle = CreateObject(`prop_cs_fuel_nozle`, pumpCoords.x, pumpCoords.y, pumpCoords.z, false, false, false)

    lib.waitFor(function()
        if DoesEntityExist(nozzle) then return true end
    end, 'Failed To Create Nozzle Item', 10000)

    SetModelAsNoLongerNeeded(`prop_cs_fuel_nozle`)
    SetEntityCollision(nozzle, false, false)

    print('Nozzle Item', nozzle, GetEntityCoords(nozzle))

    -- Wait for rope textures to load
    lib.waitFor(function()
        RopeLoadTextures()
        if RopeAreTexturesLoaded() then print('Rope Texture Loaded') return true end
    end, 'Failed To Load Texture', 10000)

    -- Wait for next frame else rope will be invisibleItem
    Wait(1)

    local invPumpCoords = GetEntityCoords(invisibleItem)

    -- Create Rope
    local rope = AddRope(invPumpCoords.x, invPumpCoords.y, invPumpCoords.z, 0.0, 0.0, 0.0, 3.0, 1, 1000.0, 0.0, 1.0, false, true, false, 1.0, false)

    -- -- Wait for Rope To Create
    lib.waitFor(function()
        if DoesRopeExist(rope) then print('Generated Rope', rope) return true end
    end, 'Failed To Generate Rope', 10000)

    local nozzleCoords = GetEntityCoords(nozzle)

    nozzleCoords = GetOffsetFromEntityInWorldCoords(nozzle, 0.0, -0.033, -0.195)

    AttachEntitiesToRope(rope, invisibleItem, nozzle, invPumpCoords.x, invPumpCoords.y, invPumpCoords.z + 1.45, nozzleCoords.x, nozzleCoords.y, nozzleCoords.z, 5.0, false, false, nil, nil)

    return invisibleItem, nozzle, rope
end

local function AttachHoseToPed(ped, pumpCoords)

end

local function AttachHoseToVehicle(veh, pumpCoords)

end

-- Need NozzleId, Need Pump Coords
AddStateBagChangeHandler('nozzle_pump', nil, function(bagName, key, value, reserved, replicated)
    if replicated then return end

    local serverId, pedHandle = utils.getEntityFromStateBag(bagName, key)

    if serverId and not value then
        -- Remove Fuel Hose From Player
        local data = playerHoldingHoses[serverId]

        if data then
            if DoesEntityExist(data.invisibleEntity) then
                DeleteEntity(data.invisibleEntity)
            end
            if DoesEntityExist(data.nozzleEntity) then
                DeleteEntity(data.nozzleEntity)
            end
            if DoesRopeExist(data.ropeEntity) then
                DeleteRope(data.ropeEntity)
            end

            playerHoldingHoses[serverId] = nil
        end
        return
    end

    local nozzleId = value.id
    local pumpCoords = value.pumpCoords

    local pump, nozzle, rope = GenerateHose(pumpCoords)

    AttachEntityToEntity(nozzle, pedHandle, GetPedBoneIndex(pedHandle, 0x49D9), 0.11, 0.02, 0.02, -80.0, -90.0, 15.0, true, true, false, true, 1, true)

    playerHoldingHoses[serverId] = {
        invisibleEntity = pump, 
        nozzleEntity = nozzle, 
        ropeEntity = rope
    }
end)    

AddStateBagChangeHandler('nozzle_veh', nil, function(bagName, key, value, reserved, replicated)
    if replicated then return end

    local entity = utils.getEntityFromStateBag(bagName, key)

    print('---nozzle_veh---')

    if not value then
        print('No Value Hence Removing Hose')
        local data = vehicleHoldingHoses[entity]

        if data then
            if DoesEntityExist(data.invisibleEntity) then
                DeleteEntity(data.invisibleEntity)
            end
            if DoesEntityExist(data.nozzleEntity) then
                DeleteEntity(data.nozzleEntity)
            end
            if DoesRopeExist(data.ropeEntity) then
                DeleteRope(data.ropeEntity)
            end
            vehicleHoldingHoses[entity] = nil
        end
        return
    end

    local nozzleId = value.id
    local pumpCoords = value.pumpCoords

    local pump, nozzle, rope = GenerateHose(pumpCoords)
    
    local boneIndex = utils.getVehiclePetrolCapBoneIndex(entity)
    local fuelcapPosition = boneIndex and GetWorldPositionOfEntityBone(entity, boneIndex)

    local isBike = false
    local vehClass = GetVehicleClass(entity)
    if vehClass == 8 and vehClass ~= 13 then
        isBike = true
    end

    if isBike then
        print('CapPos', fuelcapPosition, nozzle)
        AttachEntityToEntity(nozzle, entity, boneIndex, 0.0, -0.2, 0.2, -80.0, 0.0, 0.0, true, true, false, false, 1, true)
    else
        print('CapPos', fuelcapPosition)
        AttachEntityToEntity(nozzle, entity, boneIndex, -0.18, 0.0 , 0.75 , -125.0, -90.0, -90.0, true, true, false, false, 1, true)
    end

    vehicleHoldingHoses[entity] = {
        invisibleEntity = pump, 
        nozzleEntity = nozzle, 
        ropeEntity = rope
    }
end)

AddEventHandler('onResourceStop', function(resource)
	if resource == GetCurrentResourceName() then
        for k, data in pairs(playerHoldingHoses) do
            if DoesEntityExist(data.invisibleEntity) then
                DeleteEntity(data.invisibleEntity)
            end
            if DoesEntityExist(data.nozzleEntity) then
                DeleteEntity(data.nozzleEntity)
            end
            if DoesRopeExist(data.ropeEntity) then
                DeleteRope(data.ropeEntity)
            end
        end
        for x, data2 in pairs(vehicleHoldingHoses) do
            if DoesEntityExist(data2.invisibleEntity) then
                DeleteEntity(data2.invisibleEntity)
            end
            if DoesEntityExist(data2.nozzleEntity) then
                DeleteEntity(data2.nozzleEntity)
            end
            if DoesRopeExist(data2.ropeEntity) then
                DeleteRope(data2.ropeEntity)
            end
        end
    end
end)