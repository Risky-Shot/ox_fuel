-- local state  = require 'client.state'
-- local utils  = require 'client.utils'

-- -- Stores Created Fuel Hoses by Players
-- -- Index PlyServerId ?
-- fuelHoses = {}

-- trackedVehicles = {}

-- local activeNozzleId = nil

-- HoseObject = {}
-- HoseObject.__index = HoseObject
-- HoseObject.members = {}

-- ---@field nozzleId 'ply:playerId' or 'veh:netId'
-- ---@field coords vec3 rope pump coords 
-- function HoseObject.get(nozzleId, playerServerId, pumpCoords)
--     if HoseObject.members[nozzleId] then
--         return HoseObject.members[nozzleId]
--     end

--     return HoseObject.new(nozzleId, playerServerId, pumpCoords)
-- end

-- -- Constructor
-- function HoseObject.new(nozzleId, pumpCoords)
--     print('Initiated New Hose Object', nozzleId, pumpCoords)
--     local self = setmetatable({}, HoseObject)

--     self.nozzleId = nozzleId
--     self.pumpCoords = pumpCoords

--     if not lib.requestModel("prop_cs_fuel_nozle") then print('Failed to load model.') return end
--     if not lib.requestModel("prop_tequila_bottle") then print('Failed to load model.') return end
    
--     -- Create invisibleItemItem Item at pumpCoords
--     self.invisibleItem = CreateObject(`prop_tequila_bottle`, self.pumpCoords.x, self.pumpCoords.y, self.pumpCoords.z + 1.0, false, false, false)

--     lib.waitFor(function()
--         if DoesEntityExist(self.invisibleItem) then return true end
--     end, 'Failed To Create Invisible Item', 10000)

--     FreezeEntityPosition(self.invisibleItem, true)
--     SetEntityCollision(self.invisibleItem, false, true)
--     SetEntityVisible(self.invisibleItem, false, 0)
--     SetModelAsNoLongerNeeded(`prop_tequila_bottle`)

--     print('invisibleItem Item', self.invisibleItem, GetEntityCoords(self.invisibleItem))

--     -- Create Nozzle
--     self.nozzle = CreateObject(`prop_cs_fuel_nozle`, self.pumpCoords.x, self.pumpCoords.y, self.pumpCoords.z, false, false, false)

--     lib.waitFor(function()
--         if DoesEntityExist(self.nozzle) then return true end
--     end, 'Failed To Create Nozzle Item', 10000)

--     SetModelAsNoLongerNeeded(`prop_cs_fuel_nozle`)
--     SetEntityCollision(self.nozzle, false, false)

--     print('Nozzle Item', self.nozzle, GetEntityCoords(self.nozzle))

--     -- Wait for rope textures to load
--     lib.waitFor(function()
--         RopeLoadTextures()
--         if RopeAreTexturesLoaded() then print('Rope Texture Loaded') return true end
--     end, 'Failed To Load Texture', 10000)

--     -- Wait for next frame else rope will be invisibleItem
--     Wait(1)

--     local invPumpCoords = GetEntityCoords(self.invisibleItem)

--     -- Create Rope
--     self.rope = AddRope(invPumpCoords.x, invPumpCoords.y, invPumpCoords.z, 0.0, 0.0, 0.0, 3.0, 1, 1000.0, 0.0, 1.0, false, false, false, 1.0, false)

--     -- -- Wait for Rope To Create
--     lib.waitFor(function()
--         if DoesRopeExist(self.rope) then print('Generated Rope', self.rope) return true end
--     end, 'Failed To Generate Rope', 10000)

--     local nozzleCoords = GetEntityCoords(self.nozzle)

--     nozzleCoords = GetOffsetFromEntityInWorldCoords(self.nozzle, 0.0, -0.033, -0.195)

--     AttachEntitiesToRope(self.rope, self.invisibleItem, self.nozzle, invPumpCoords.x, invPumpCoords.y, invPumpCoords.z + 1.45, nozzleCoords.x, nozzleCoords.y, nozzleCoords.z, 5.0, false, false, nil, nil)

--     HoseObject.members[self.nozzleId] = self
--     return self
-- end

-- function HoseObject:AttachToPed(pedHandle)
--     if not self.nozzle or not DoesEntityExist(self.nozzle) then 
--         print('Nozzle Does Not Exist')
--         return false
--     end

--     print('Attached Nozzle to ', pedHandle)
--     -- Attach Nozzel To Ped
--     AttachEntityToEntity(self.nozzle, pedHandle, GetPedBoneIndex(pedHandle, 0x49D9), 0.11, 0.02, 0.02, -80.0, -90.0, 15.0, true, true, false, true, 1, true)
--     return true
-- end

-- function HoseObject:AttachToVehicle(vehicle)

--     if not vehicle or not DoesEntityExist(vehicle) or not self. nozzle or not DoesEntityExist(self.nozzle) or not self.invisibleItem or not DoesEntityExist(self.invisibleItem) or not self.rope or not DoesRopeExist(self.rope) then
--         return false
--     end

--     if self.vehicle then 
--         print('Please put Back nozzle')
--         return 
--     end

--     self.vehicle = vehicle

--     local boneIndex = utils.getVehiclePetrolCapBoneIndex(self.vehicle)
--     local fuelcapPosition = boneIndex and GetWorldPositionOfEntityBone(self.vehicle, boneIndex)

--     local isBike = false
--     local vehClass = GetVehicleClass(self.vehicle)
--     if vehClass == 8 and vehClass ~= 13 then
--         isBike = true
--     end

--     if isBike then
--         print('CapPos', fuelcapPosition, self.nozzle)
--         AttachEntityToEntity(self.nozzle, self.vehicle, boneIndex, 0.0, -0.2, 0.2, -80.0, 0.0, 0.0, true, true, false, false, 1, true)
--     else
--         print('CapPos', fuelcapPosition)
--         AttachEntityToEntity(self.nozzle, self.vehicle, boneIndex, -0.18, 0.0 , 0.75 , -125.0, -90.0, -90.0, true, true, false, false, 1, true)
--     end

--     return true
-- end

-- function HoseObject:Destroy(identifier)
--     DeleteRope(self.rope)
--     if DoesEntityExist(self.nozzle) then
--         DeleteEntity(self.nozzle)
--     end
--     if DoesEntityExist(self.invisibleItem) then
--         DeleteEntity(self.invisibleItem)
--     end
--     RopeUnloadTextures()
--     ClearPedTasks(self.ped)
-- end

-- AddStateBagChangeHandler('create_nozzle', nil, function(bagName, key, value, reserved, replicated)
--     if replicated then return end

--     if not value then
--         print('Nil Value Received of Statebag', key)
--         return
--     end

--     print('---create_nozzle---')

--     local serverId, pedHandle = utils.getEntityFromStateBag(bagName, key)

--     local nozzleId = value.id
--     local pumpCoords = value.pumpCoords

--     print(nozzleId)

--     -- Reset Already Existing Data if Any
--     if fuelHoses[nozzleId] then
--         print('Nozzle For Pump Already Exists')
--         local obj = fuelHoses[nozzleId]
--         obj:Destroy()
--         HoseObject.members[nozzleId] = nil
--         fuelHoses[nozzleId] = nil
--         print('Hose Object Cleaned. Already for',nozzleId)
--     end

--     -- Create Hose Object For Specific Pump
--     local hoseObj = HoseObject.get(nozzleId, pumpCoords)
--     -- Wait(10000)
--     -- hoseObj:Destroy()
--     fuelHoses[hoseObj.nozzleId] = hoseObj
-- end)

-- AddStateBagChangeHandler('holding_nozzle', nil, function(bagName, key, value, reserved, replicated)
--     if replicated then return end

--     local serverId, pedHandle = utils.getEntityFromStateBag(bagName, key)

--     if serverId and not value then
--         return --removePlayer(serverId)
--     end

--     print('---holding_nozzle---')

--     print('holding_nozzle', json.encode(value))

--     local nozzleId = value.id

--     local pumpCoords = nil

--     local foundObj = lib.waitFor(function()
--         if fuelHoses[nozzleId] then return true end
--     end,  'Failed To Fetch FuelHose Object', 10000)

--     if not foundObj then 
--         print('Failed to Find Object for this pump to create holding nozzle.')
--         return 
--     end

--     -- Reset Already Existing Data if Any
--     if fuelHoses[nozzleId] then
--         print('Nozzle For Pump Already Exists (holding)')
--         local obj = fuelHoses[nozzleId]
--         pumpCoords = obj.pumpCoords
--         Wait(100)
--         obj:Destroy()
--         HoseObject.members[nozzleId] = nil
--         print('Hose Object Cleaned. Already for',nozzleId)
--     end

--     Wait(100)
--     if not pumpCoords then print('Failed to Get Pump Coords') return end

--     print('Player Server Id', serverId)

--     print('Nozzle Data', value)

--     -- Create Hose Object For Specific Pump
--     local hoseObj = HoseObject.get(nozzleId, pumpCoords)

--     hoseObj:AttachToPed(pedHandle)

--     fuelHoses[hoseObj.nozzleId] = hoseObj

--     Wait(100)

-- 	state.currentNozzleId = nozzleId
-- end)

-- AddStateBagChangeHandler('fueling_nozzle', nil, function(bagName, key, value, reserved, replicated)
--     if replicated then 
--         print('Replicated Hence Returned fueling_nozzle')
--         return 
--     end

--     local entity = utils.getEntityFromStateBag(bagName, key)

--     if not entity then 
--         print('No Entity Found For fueling_nozzle')
--         return 
--     end

--     if not value then 
--         print('Cleared Vehicle State fueling_nozzle')
--         return 
--     end

--     print('fueling_nozzle NozzleId', value.id)

--     local hoseObj = fuelHoses[value.id]

--     if not hoseObj then 
--         print('no hose object')
--         return 
--     end

--     hoseObj:AttachToVehicle(entity)
-- end)

-- AddEventHandler('onResourceStop', function(resource)
-- 	if resource == GetCurrentResourceName() then
--         -- for k, v in pairs(holdingFuelHoses) do
--         --     v:Destroy()
--         -- end
--         -- for x,y in pairs(attachedFuelHoses) do
--         --     y:Destroy()
--         -- end
--     end
-- end)

-- RegisterCommand('delEnt', function(_, args)
--     local ent = tonumber(args[1])
--     print(ent)
--     DeleteEntity(ent)
-- end)

-- RegisterCommand('delRope', function(_, args)
--     local ent = tonumber(args[1])
--     print(ent)
--     DeleteRope(ent)
--     RopeUnloadTextures()
-- end)

-- RegisterCommand('resetVeh', function()
--     Entity(cache.vehicle).state:set('fueling_nozzle', nil, true)
-- end)

-- ClearPedTasks(cache.ped)
-- LocalPlayer.state:set('create_nozzle', nil, true)
-- LocalPlayer.state:set('holding_nozzle', nil, true)