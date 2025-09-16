-- client/drops.lua

local QBCore = exports['qb-core']:GetCoreObject()

-- =====================
-- State
-- =====================
local Spawned = {}   -- stackId -> { entity, clusterId, amount, itemName, label }
local CurrentDrop = nil

-- =====================
-- Helpers
-- =====================

local function cleanupNearbyDuplicates(modelHash, center, exceptEntity, radius)
    radius = radius or 0.35
    local handle, obj = FindFirstObject()
    local success
    repeat
        if obj ~= 0 and DoesEntityExist(obj) and GetEntityModel(obj) == modelHash then
            local pos = GetEntityCoords(obj)
            local dx, dy, dz = pos.x - center.x, pos.y - center.y, pos.z - center.z
            local dist2 = dx*dx + dy*dy + dz*dz
            if dist2 <= (radius * radius) and (not exceptEntity or obj ~= exceptEntity) then
                SetEntityAsMissionEntity(obj, true, true)
                DeleteEntity(obj)
                if DoesEntityExist(obj) then DeleteObject(obj) end
            end
        end
        success, obj = FindNextObject(handle)
    until not success
    EndFindObject(handle)
end


local function toTitleCase(s)
    s = tostring(s or '')
    s = s:gsub('_', ' ')
    return (s:gsub('(%a)([%w]*)', function(a, b) return a:upper() .. b:lower() end))
end

local function loadModel(model)
    local hash = type(model) == 'number' and model or GetHashKey(model)
    if not IsModelInCdimage(hash) then return false, hash end
    if not HasModelLoaded(hash) then
        RequestModel(hash)
        local deadline = GetGameTimer() + 5000
        while not HasModelLoaded(hash) and GetGameTimer() < deadline do
            Wait(0)
        end
    end
    return HasModelLoaded(hash), hash
end

local function placeObject(obj)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    SetEntityAsMissionEntity(obj, true, false)
end

local function removeTargetsForStack(stackId)
    local entry = Spawned[stackId]
    if not entry or not entry.entity then return end
    exports['qb-target']:RemoveTargetEntity(entry.entity)
end

local function addTargetsForStack(stackId)
    local entry = Spawned[stackId]
    if not entry or not DoesEntityExist(entry.entity) then return end

    exports['qb-target']:AddTargetEntity(entry.entity, {
        options = {
            {
                icon = 'fa-solid fa-hand',
                label = ('Pick up (%s x%d)'):format(entry.label or entry.itemName or 'item', entry.amount or 1),
                action = function()
                    TriggerServerEvent('itemdrops:server:pickupStack', entry.clusterId, stackId)
                end,
            },
            {
                icon = 'fa-solid fa-box-open',
                label = 'Open stash',
                action = function()
                    TriggerServerEvent('itemdrops:server:openCluster', entry.clusterId)
                    CurrentDrop = entry.clusterId
                end,
            },
        },
        distance = 2.0
    })
end

local function deleteStackProp(stackId)
    local entry = Spawned[stackId]
    if not entry then return end

    if entry.entity and DoesEntityExist(entry.entity) then
        exports['qb-target']:RemoveTargetEntity(entry.entity)
        local pos = GetEntityCoords(entry.entity)
        local model = entry.model or GetEntityModel(entry.entity)

        SetEntityAsMissionEntity(entry.entity, true, true)
        DeleteEntity(entry.entity)
        if DoesEntityExist(entry.entity) then DeleteObject(entry.entity) end

        -- After deleting ours, purge any remaining duplicates in a small bubble
        if model and pos then
            cleanupNearbyDuplicates(model, pos, nil, 0.45)
        end
    end

    Spawned[stackId] = nil
end



-- Spawns a per-item prop for a stack
-- payload: { stackId, clusterId, item={name,amount,...}, coords={x,y,z}, model }
local function spawnStackProp(payload)
    if not payload or not payload.stackId or not payload.model or not payload.coords then return end

    local model = type(payload.model) == 'number' and payload.model or GetHashKey(payload.model)
    if not IsModelInCdimage(model) then return end
    if not HasModelLoaded(model) then
        RequestModel(model)
        local deadline = GetGameTimer() + 5000
        while not HasModelLoaded(model) and GetGameTimer() < deadline do Wait(0) end
        if not HasModelLoaded(model) then return end
    end

    local c = payload.coords
    local center = vec3(c.x + 0.0, c.y + 0.0, (c.z or 0.0) + 0.0)

    -- First pass: clear any stale duplicates from previous session
    cleanupNearbyDuplicates(model, center, nil, 0.35)

    -- Create the object (non-networked for reliable cleanup)
    local obj = CreateObjectNoOffset(model, center.x, center.y, center.z + 0.25, false, false, false)
    if not obj or obj == 0 then return end

    -- Ground it
    local found, gz = GetGroundZFor_3dCoord(center.x, center.y, center.z + 50.0, false)
    if found then
        SetEntityCoordsNoOffset(obj, center.x, center.y, gz + 0.02, false, false, false)
    end
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    SetEntityAsMissionEntity(obj, true, false)

    -- Pretty label
    local rawName   = payload.item and payload.item.name or 'unknown'
    local shared    = QBCore.Shared.Items[(rawName or ''):lower()]
    local niceLabel = (shared and shared.label) or (rawName:gsub('_',' '):gsub('(%a)([%w]*)', function(a,b) return a:upper()..b:lower() end))

    Spawned[payload.stackId] = {
        entity    = obj,
        clusterId = payload.clusterId,
        amount    = payload.item and (payload.item.amount or 1) or 1,
        itemName  = rawName,
        label     = niceLabel,
        model     = model,
    }

    addTargetsForStack(payload.stackId)

    -- Persist the *final* grounded coords (prevents floating on next restart)
    local pos = GetEntityCoords(obj)
    TriggerServerEvent('itemdrops:server:updateStackCoords', payload.clusterId, payload.stackId, { x = pos.x, y = pos.y, z = pos.z })

    -- Second pass: if any other stray copies still exist in the bubble, nuke them (except ours)
    cleanupNearbyDuplicates(model, pos, obj, 0.35)

    SetModelAsNoLongerNeeded(model)
end



-- =====================
-- Initial Sync
-- =====================

local function syncExistingDrops()
    -- Ask the server to rebroadcast every stack to this client (includes correct models)
    TriggerServerEvent('itemdrops:server:syncAllStacks')
end

-- =====================
-- Events (from server)
-- =====================

-- Spawn a per-item prop (called when a player drops something or on sync)
RegisterNetEvent('itemdrops:client:spawnProp', function(payload)
    spawnStackProp(payload)
end)

-- Remove a specific stack prop (called after pickup/cleanup)
RegisterNetEvent('itemdrops:client:removeProp', function(stackId)
    deleteStackProp(stackId)
end)

-- Backwards-compat no-ops for old bag logic (avoid errors if other code still triggers these)
RegisterNetEvent('qb-inventory:client:removeDropTarget', function(_) end)
RegisterNetEvent('qb-inventory:client:setupDropTarget', function(_) end)

-- =====================
-- NUI callbacks
-- =====================

-- Called when you drag/drop from your inventory into the world
-- Server returns a clusterId (e.g., "drop-123456"), and broadcasts spawnProp for the new stack.
RegisterNUICallback('DropItem', function(item, cb)
    QBCore.Functions.TriggerCallback('qb-inventory:server:createDrop', function(clusterId)
        if clusterId then
            cb(clusterId)
        else
            cb(false)
        end
    end, item)
end)

-- =====================
-- Threads / startup
-- =====================

CreateThread(function()
    Wait(500)
    -- clean any leftovers from a client-side resource restart
    for sid in pairs(Spawned) do
        deleteStackProp(sid)
    end
    -- request authoritative sync from server (spawns correct models + labels)
    syncExistingDrops()
end)
