-- server/main.lua

QBCore = exports['qb-core']:GetCoreObject()
Inventories = {}
Drops = {}               -- clusters with per-item stacks
RegisteredShops = {}

-- =========================
-- Per-item props + clusters
-- =========================

-- Config defaults (safe if missing in your config)
Config.DropClusterRadius = Config.DropClusterRadius or 1.5   -- meters; items within this are one stash
Config.FallbackModel     = Config.FallbackModel     or `prop_paper_bag_small`

-- Item name (lowercase) -> GTA model. Extend as you like.
ItemModels = ItemModels or {
    phone         = `prop_npc_phone_02`,
    weapon_pistol = `w_pi_pistol`,
    pistol_ammo   = `prop_ld_ammo_pack_01`,
    water_bottle  = `prop_ld_flow_bottle`,
}

-- Helpers
local function newClusterId()
    return ('drop-%d'):format(math.random(100000, 999999))
end

local function findNearbyCluster(coords)
    local bestId, bestDist
    for id, d in pairs(Drops) do
        if d.coords then
            local dist = #(coords - d.coords)
            if dist <= (Config.DropClusterRadius or 1.5) and (not bestDist or dist < bestDist) then
                bestId, bestDist = id, dist
            end
        end
    end
    return bestId
end

local function clusterIsEmpty(cluster)
    if not cluster or not cluster.stacks then return true end
    for _ in pairs(cluster.stacks) do
        return false
    end
    return true
end

-- Builds the stash UI inventory from per-stack records (merging same item+meta)
-- Returns a NUMERIC array with sequential slot ids (1..N) and NUI-friendly fields.
local function buildClusterInventory(cluster)
    local function toTitleCase(s)
        s = tostring(s or '')
        s = s:gsub('_', ' ')
        return (s:gsub('(%a)([%w]*)', function(a, b) return a:upper() .. b:lower() end))
    end

    local merged = {}

    local function metaKey(it)
        local m = it and (it.metadata or it.info) or {}
        local n = it and it.name or 'unknown'
        return (n:lower()) .. '|' .. (m and json.encode(m) or 'null')
    end

    if cluster and cluster.stacks then
        for _, s in pairs(cluster.stacks) do
            local it = s.item
            if it and it.name then
                local originalName = it.name
                local lookupName   = originalName:lower()
                local shared       = QBCore.Shared.Items[lookupName]
                local key          = metaKey(it)

                if not merged[key] then
                    merged[key] = {
                        -- core fields
                        name     = originalName,
                        label    = (shared and shared.label) or it.label or toTitleCase(originalName),
                        amount   = tonumber(it.amount) or 1,
                        type     = it.type or (shared and shared.type) or 'item',
                        info     = it.info,
                        metadata = it.metadata,

                        -- NUI extras (fixes icon/tooltip/weight)
                        image       = (shared and shared.image) or it.image or (lookupName .. '.png'),
                        weight      = (shared and shared.weight) or 0,
                        description = (shared and (shared.description or shared.desc)) or it.description or '',
                    }
                else
                    merged[key].amount = (merged[key].amount or 0) + (tonumber(it.amount) or 1)
                end
            end
        end
    end

    -- sequential slots for the UI
    local list, idx = {}, 1
    for _, v in pairs(merged) do
        v.slot = idx
        list[idx] = v
        idx = idx + 1
    end
    return list
end

-- =====================================================
-- PERSISTENCE (DB): auto-create tables and save/load ops
-- =====================================================

local DROP_DB = {
    clusters = 'inventory_drop_clusters',
    stacks   = 'inventory_drop_stacks',
}

-- Create tables if they don't exist
local function DBEnsureSchema()
    local sqlClusters = [[
        CREATE TABLE IF NOT EXISTS `]] .. DROP_DB.clusters .. [[` (
          `cluster_id` VARCHAR(32) NOT NULL,
          `x` DOUBLE NOT NULL,
          `y` DOUBLE NOT NULL,
          `z` DOUBLE NOT NULL,
          `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`cluster_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]]

    local sqlStacks = [[
        CREATE TABLE IF NOT EXISTS `]] .. DROP_DB.stacks .. [[` (
          `stack_id`   VARCHAR(32) NOT NULL,
          `cluster_id` VARCHAR(32) NOT NULL,
          `item_name`  VARCHAR(64) NOT NULL,
          `amount`     INT NOT NULL DEFAULT 1,
          `item_type`  VARCHAR(32) NOT NULL,
          `info_json`      LONGTEXT NULL,
          `metadata_json`  LONGTEXT NULL,
          `x` DOUBLE NOT NULL,
          `y` DOUBLE NOT NULL,
          `z` DOUBLE NOT NULL,
          `model` BIGINT UNSIGNED NOT NULL,
          `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`stack_id`),
          KEY `idx_cluster_id` (`cluster_id`),
          CONSTRAINT `fk_drop_cluster` FOREIGN KEY (`cluster_id`)
            REFERENCES `]] .. DROP_DB.clusters .. [[` (`cluster_id`)
            ON DELETE CASCADE ON UPDATE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]]

    MySQL.query.await(sqlClusters)
    MySQL.query.await(sqlStacks)
    print('[drops] schema ensured (clusters + stacks)')
end

local function DBSaveCluster(clusterId, coords)
    MySQL.prepare(
        ('INSERT INTO %s (cluster_id, x, y, z) VALUES (?, ?, ?, ?) ' ..
         'ON DUPLICATE KEY UPDATE x = VALUES(x), y = VALUES(y), z = VALUES(z)')
        :format(DROP_DB.clusters),
        { clusterId, coords.x + 0.0, coords.y + 0.0, coords.z + 0.0 }
    )
end

local function DBSaveStack(clusterId, stackId, s)
    MySQL.prepare(
        ('INSERT INTO %s (stack_id, cluster_id, item_name, amount, item_type, info_json, metadata_json, x, y, z, model) ' ..
         'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) ' ..
         'ON DUPLICATE KEY UPDATE amount = VALUES(amount), x = VALUES(x), y = VALUES(y), z = VALUES(z), model = VALUES(model)')
        :format(DROP_DB.stacks),
        {
            stackId, clusterId,
            s.item.name, tonumber(s.item.amount) or 1, (s.item.type or 'item'),
            json.encode(s.item.info or {}), json.encode(s.item.metadata or {}),
            s.coords.x + 0.0, s.coords.y + 0.0, s.coords.z + 0.0,
            tonumber(s.model) or 0
        }
    )
end

local function DBDeleteStack(stackId)
    MySQL.prepare(('DELETE FROM %s WHERE stack_id = ?'):format(DROP_DB.stacks), { stackId })
end

local function DBDeleteCluster(clusterId)
    MySQL.prepare(('DELETE FROM %s WHERE cluster_id = ?'):format(DROP_DB.clusters), { clusterId })
end

local function DBLoadAllDrops()
    local clusters = MySQL.query.await(('SELECT * FROM %s'):format(DROP_DB.clusters)) or {}
    local stacks   = MySQL.query.await(('SELECT * FROM %s'):format(DROP_DB.stacks))   or {}

    -- Build clusters first
    for _, c in ipairs(clusters) do
        Drops[c.cluster_id] = {
            name        = c.cluster_id,
            label       = 'Drop',
            createdTime = os.time(),
            coords      = vector3(c.x + 0.0, c.y + 0.0, c.z + 0.0),
            maxweight   = Config.DropSize.maxweight,
            slots       = Config.DropSize.slots,
            isOpen      = false,
            stacks      = {}
        }
    end

    -- Then stacks
    for _, s in ipairs(stacks) do
        local cid = s.cluster_id
        if not Drops[cid] then
            Drops[cid] = {
                name        = cid,
                label       = 'Drop',
                createdTime = os.time(),
                coords      = vector3(s.x + 0.0, s.y + 0.0, s.z + 0.0),
                maxweight   = Config.DropSize.maxweight,
                slots       = Config.DropSize.slots,
                isOpen      = false,
                stacks      = {}
            }
            DBSaveCluster(cid, Drops[cid].coords)
        end

        Drops[cid].stacks[s.stack_id] = {
            item = {
                name     = s.item_name,
                amount   = s.amount,
                type     = s.item_type,
                info     = json.decode(s.info_json  or '{}'),
                metadata = json.decode(s.metadata_json or '{}'),
            },
            coords = vector3(s.x + 0.0, s.y + 0.0, s.z + 0.0),
            model  = tonumber(s.model) or Config.FallbackModel,
        }
    end

    print(('[drops] loaded %d clusters, %d stacks from DB'):format(#clusters, #stacks))
end

-- =========================================
-- Helper that PRESERVES source when opening
-- =========================================
-- Opens a cluster (drop) as an "other" inventory
local function OpenDropFor(src, dropId)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        print('[openDrop] no Player for', src)
        return
    end

    local ped     = GetPlayerPed(src)
    local pcoords = GetEntityCoords(ped)

    local drop = Drops[dropId]
    if not drop then
        print('[openDrop] no drop for id:', dropId)
        TriggerClientEvent('QBCore:Notify', src, 'No stash found.', 'error')
        return
    end

    -- allow open if near centroid OR any stack
    local inRange, why = false, 'centroid'
    if drop.coords and #(pcoords - drop.coords) <= 2.5 then
        inRange = true
    elseif drop.stacks then
        for _, s in pairs(drop.stacks) do
            if s.coords and #(pcoords - s.coords) <= 2.5 then
                inRange = true
                why = 'stack'
                break
            end
        end
    end
    if not inRange then
        print(('[openDrop] too far. player=%.2f,%.2f,%.2f  centroidDist=%.2f'):format(
            pcoords.x, pcoords.y, pcoords.z,
            drop.coords and #(pcoords - drop.coords) or -1
        ))
        TriggerClientEvent('QBCore:Notify', src, 'Too far from the stash.', 'error')
        return
    end

    if drop.isOpen then
        print('[openDrop] drop already open:', dropId)
        return
    end

    local invItems = buildClusterInventory(drop)
    print('[openDrop] opening', dropId, 'items=', #invItems, 'reason=', why)

    local formattedInventory = {
        name      = dropId,
        label     = dropId,
        maxweight = drop.maxweight or Config.DropSize.maxweight,
        slots     = math.max(#invItems, drop.slots or Config.DropSize.slots or 40),
        inventory = invItems
    }

    drop.isOpen = true
    TriggerClientEvent('qb-inventory:client:openInventory', src, Player.PlayerData.items, formattedInventory)
end

-- ==================================================
-- Helpers for consuming from cluster stacks on move
-- (also updates persistence for changed/removed stacks)
-- ==================================================
local function sameMeta(a, b)
    local aj = json.encode(a or {})
    local bj = json.encode(b or {})
    return aj == bj
end

-- remove 'amount' from matching stacks in a cluster; deletes props when empty
local function consumeFromCluster(clusterId, name, meta, amount)
    local cluster = Drops[clusterId]
    if not cluster or not cluster.stacks then return false end
    local remaining = tonumber(amount) or 0
    if remaining <= 0 then return false end

    for stackId, s in pairs(cluster.stacks) do
        local it = s.item
        if it and string.lower(it.name) == string.lower(name) and sameMeta(it.metadata or it.info, meta) then
            local cur = tonumber(it.amount) or 1
            local take = math.min(remaining, cur)
            it.amount = cur - take
            remaining = remaining - take

            if it.amount <= 0 then
                cluster.stacks[stackId] = nil
                TriggerClientEvent('itemdrops:client:removeProp', -1, stackId)
                DBDeleteStack(stackId)
            else
                DBSaveStack(clusterId, stackId, s)
            end

            if remaining == 0 then break end
        end
    end

    if clusterIsEmpty(cluster) then
        DBDeleteCluster(clusterId)
    end

    return remaining == 0
end

-- ================
-- DB warmup thread
-- ================

CreateThread(function()
    MySQL.query('SELECT * FROM inventories', {}, function(result)
        if result and #result > 0 then
            for i = 1, #result do
                local inventory = result[i]
                local cacheKey = inventory.identifier
                Inventories[cacheKey] = {
                    items = json.decode(inventory.items) or {},
                    isOpen = false
                }
            end
            print(#result .. ' inventories successfully loaded')
        end
    end)
end)

-- ===================
-- World cleanup thread
-- ===================

CreateThread(function()
    while true do
        for k, v in pairs(Drops) do
            if v and (v.createdTime + (Config.CleanupDropTime * 60) < os.time()) and not v.isOpen then
                if v.stacks then
                    for stackId, _ in pairs(v.stacks) do
                        TriggerClientEvent('itemdrops:client:removeProp', -1, stackId)
                        DBDeleteStack(stackId)
                    end
                end
                DBDeleteCluster(k)
                Drops[k] = nil
            end
        end
        Wait(Config.CleanupDropInterval * 60000)
    end
end)

-- =========
-- Handlers
-- =========

AddEventHandler('playerDropped', function()
    for _, inv in pairs(Inventories) do
        if inv.isOpen == source then
            inv.isOpen = false
        end
    end
end)

AddEventHandler('txAdmin:events:serverShuttingDown', function()
    for inventory, data in pairs(Inventories) do
        if data.isOpen then
            MySQL.prepare('INSERT INTO inventories (identifier, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = ?', { inventory, json.encode(data.items), json.encode(data.items) })
        end
    end
end)

RegisterNetEvent('QBCore:Server:UpdateObject', function()
    if source ~= '' then return end
    QBCore = exports['qb-core']:GetCoreObject()
end)

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    QBCore.Functions.AddPlayerMethod(Player.PlayerData.source, 'AddItem', function(item, amount, slot, info, reason)
        return AddItem(Player.PlayerData.source, item, amount, slot, info, reason)
    end)

    QBCore.Functions.AddPlayerMethod(Player.PlayerData.source, 'RemoveItem', function(item, amount, slot, reason)
        return RemoveItem(Player.PlayerData.source, item, amount, slot, reason)
    end)

    QBCore.Functions.AddPlayerMethod(Player.PlayerData.source, 'GetItemBySlot', function(slot)
        return GetItemBySlot(Player.PlayerData.source, slot)
    end)

    QBCore.Functions.AddPlayerMethod(Player.PlayerData.source, 'GetItemByName', function(item)
        return GetItemByName(Player.PlayerData.source, item)
    end)

    QBCore.Functions.AddPlayerMethod(Player.PlayerData.source, 'GetItemsByName', function(item)
        return GetItemsByName(Player.PlayerData.source, item)
    end)

    QBCore.Functions.AddPlayerMethod(Player.PlayerData.source, 'ClearInventory', function(filterItems)
        ClearInventory(Player.PlayerData.source, filterItems)
    end)

    QBCore.Functions.AddPlayerMethod(Player.PlayerData.source, 'SetInventory', function(items)
        SetInventory(Player.PlayerData.source, items)
    end)
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    local Players = QBCore.Functions.GetQBPlayers()
    for k in pairs(Players) do
        QBCore.Functions.AddPlayerMethod(k, 'AddItem', function(item, amount, slot, info)
            return AddItem(k, item, amount, slot, info)
        end)

        QBCore.Functions.AddPlayerMethod(k, 'RemoveItem', function(item, amount, slot)
            return RemoveItem(k, item, amount, slot)
        end)

        QBCore.Functions.AddPlayerMethod(k, 'GetItemBySlot', function(slot)
            return GetItemBySlot(k, slot)
        end)

        QBCore.Functions.AddPlayerMethod(k, 'GetItemByName', function(item)
            return GetItemByName(k, item)
        end)

        QBCore.Functions.AddPlayerMethod(k, 'GetItemsByName', function(item)
            return GetItemsByName(k, item)
        end)

        QBCore.Functions.AddPlayerMethod(k, 'ClearInventory', function(filterItems)
            ClearInventory(k, filterItems)
        end)

        QBCore.Functions.AddPlayerMethod(k, 'SetInventory', function(items)
            SetInventory(k, items)
        end)

        Player(k).state.inv_busy = false
    end
end)

-- Ensure schema + load persisted drops after DB is up
CreateThread(function()
    Wait(250)
    DBEnsureSchema()
    DBLoadAllDrops()
end)

-- ==========
-- Functions
-- ==========

local function checkWeapon(source, item)
    local currentWeapon = type(item) == 'table' and item.name or item
    local ped = GetPlayerPed(source)
    local weapon = GetSelectedPedWeapon(ped)
    local weaponInfo = QBCore.Shared.Weapons[weapon]
    if weaponInfo and weaponInfo.name == currentWeapon then
        RemoveWeaponFromPed(ped, weapon)
        TriggerClientEvent('qb-weapons:client:UseWeapon', source, { name = currentWeapon }, false)
    end
end

-- =======
-- Events
-- =======

RegisterNetEvent('qb-inventory:server:openVending', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    CreateShop({
        name = 'vending',
        label = 'Vending Machine',
        coords = data.coords,
        slots = #Config.VendingItems,
        items = Config.VendingItems
    })
    OpenShop(src, 'vending')
end)

RegisterNetEvent('qb-inventory:server:closeInventory', function(inventory)
    local src = source
    local QBPlayer = QBCore.Functions.GetPlayer(src)
    if not QBPlayer then return end
    Player(source).state.inv_busy = false

    if inventory:find('shop%-') then return end

    if inventory:find('otherplayer%-') then
        local targetId = tonumber(inventory:match('otherplayer%-(.+)'))
        Player(targetId).state.inv_busy = false
        return
    end

    -- Cluster close
    if Drops[inventory] then
        Drops[inventory].isOpen = false
        if clusterIsEmpty(Drops[inventory]) and not Drops[inventory].isOpen then
            if Drops[inventory].stacks then
                for stackId, _ in pairs(Drops[inventory].stacks) do
                    TriggerClientEvent('itemdrops:client:removeProp', -1, stackId)
                    DBDeleteStack(stackId)
                end
            end
            DBDeleteCluster(inventory)
            Drops[inventory] = nil
        end
        return
    end

    -- Named stash/inventory
    if not Inventories[inventory] then return end
    Inventories[inventory].isOpen = false
    MySQL.prepare(
        'INSERT INTO inventories (identifier, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = ?',
        { inventory, json.encode(Inventories[inventory].items), json.encode(Inventories[inventory].items) }
    )
end)

RegisterNetEvent('qb-inventory:server:useItem', function(item)
    local src = source
    local itemData = GetItemBySlot(src, item.slot)
    if not itemData then return end
    local itemInfo = QBCore.Shared.Items[itemData.name]
    if itemData.type == 'weapon' then
        TriggerClientEvent('qb-weapons:client:UseWeapon', src, itemData, itemData.info.quality and itemData.info.quality > 0)
        TriggerClientEvent('qb-inventory:client:ItemBox', src, itemInfo, 'use')
    elseif itemData.name == 'id_card' then
        UseItem(itemData.name, src, itemData)
        TriggerClientEvent('qb-inventory:client:ItemBox', source, itemInfo, 'use')
        local playerPed = GetPlayerPed(src)
        local playerCoords = GetEntityCoords(playerPed)
        local players = QBCore.Functions.GetPlayers()
        local gender = item.info.gender == 0 and 'Male' or 'Female'
        for _, v in pairs(players) do
            local targetPed = GetPlayerPed(v)
            local dist = #(playerCoords - GetEntityCoords(targetPed))
            if dist < 3.0 then
                TriggerClientEvent('chat:addMessage', v, {
                    template = '<div class="chat-message advert" style="background: linear-gradient(to right, rgba(5, 5, 5, 0.6), #74807c); display: flex;"><div style="margin-right: 10px;"><i class="far fa-id-card" style="height: 100%;"></i><strong> {0}</strong><br> <strong>Civ ID:</strong> {1} <br><strong>First Name:</strong> {2} <br><strong>Last Name:</strong> {3} <br><strong>Birthdate:</strong> {4} <br><strong>Gender:</strong> {5} <br><strong>Nationality:</strong> {6}</div></div>',
                    args = {
                        'ID Card',
                        item.info.citizenid,
                        item.info.firstname,
                        item.info.lastname,
                        item.info.birthdate,
                        gender,
                        item.info.nationality
                    }
                })
            end
        end
    elseif itemData.name == 'driver_license' then
        UseItem(itemData.name, src, itemData)
        TriggerClientEvent('qb-inventory:client:ItemBox', src, itemInfo, 'use')
        local playerPed = GetPlayerPed(src)
        local playerCoords = GetEntityCoords(playerPed)
        local players = QBCore.Functions.GetPlayers()
        for _, v in pairs(players) do
            local targetPed = GetPlayerPed(v)
            local dist = #(playerCoords - GetEntityCoords(targetPed))
            if dist < 3.0 then
                TriggerClientEvent('chat:addMessage', v, {
                    template = '<div class="chat-message advert' ..
                        '" style="background: linear-gradient(to right, rgba(5, 5, 5, 0.6), #657175); display: flex;">' ..
                        '<div style="margin-right: 10px;"><i class="far fa-id-card" style="height: 100%;"></i>' ..
                        '<strong> {0}</strong><br> <strong>First Name:</strong> {1} <br>' ..
                        '<strong>Last Name:</strong> {2} <br><strong>Birth Date:</strong> {3} <br>' ..
                        '<strong>Licenses:</strong> {4}</div></div>',
                    args = {
                        'Drivers License',
                        item.info.firstname,
                        item.info.lastname,
                        item.info.birthdate,
                        item.info.type
                    }
                })
            end
        end
    else
        UseItem(itemData.name, src, itemData)
        TriggerClientEvent('qb-inventory:client:ItemBox', src, itemInfo, 'use')
    end
end)

-- ==========================
-- Cluster-aware open (stash)
-- ==========================

RegisterNetEvent('qb-inventory:server:openDrop', function(dropId)
    OpenDropFor(source, dropId)
end)

RegisterNetEvent('qb-inventory:server:updateDrop', function(dropId, coords)
    if Drops[dropId] then
        Drops[dropId].coords = coords
        DBSaveCluster(dropId, coords)
    end
end)

RegisterNetEvent('qb-inventory:server:snowball', function(action)
    if action == 'add' then
        AddItem(source, 'weapon_snowball', 1, false, false, 'qb-inventory:server:snowball')
    elseif action == 'remove' then
        RemoveItem(source, 'weapon_snowball', 1, false, 'qb-inventory:server:snowball')
    end
end)

-- ==========
-- Callbacks
-- ==========

QBCore.Functions.CreateCallback('qb-inventory:server:GetCurrentDrops', function(_, cb)
    cb(Drops)
end)

-- ==========================
-- CREATE DROP (NO BAG PROP)
-- ==========================

QBCore.Functions.CreateCallback('qb-inventory:server:createDrop', function(source, cb, item)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then cb(false) return end

    local playerPed = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(playerPed)

    if RemoveItem(src, item.name, item.amount, item.fromSlot, 'dropped item') then
        if item.type == 'weapon' then checkWeapon(src, item) end
        TaskPlayAnim(playerPed, 'pickup_object', 'pickup_low', 8.0, -8.0, 2000, 0, 0, false, false, false)

        -- Find or create a cluster
        local clusterId = findNearbyCluster(playerCoords)
        if not clusterId then clusterId = newClusterId() end

        if not Drops[clusterId] then
            Drops[clusterId] = {
                name        = clusterId,
                label       = 'Drop',
                createdTime = os.time(),
                coords      = playerCoords,       -- cluster centroid (first drop)
                maxweight   = Config.DropSize.maxweight,
                slots       = Config.DropSize.slots,
                isOpen      = false,
                stacks      = {}                  -- stackId -> { item, coords, model }
            }
            DBSaveCluster(clusterId, playerCoords) -- <-- ensures FK exists before stacks
        end

        -- Decide world model for this item
        local model = ItemModels[string.lower(item.name)] or Config.FallbackModel

        -- Make a unique stack within the cluster and STORE THE MODEL
        local stackId = ('stack-%d'):format(math.random(100000, 999999))
        Drops[clusterId].stacks[stackId] = {
            item   = item,           -- keep full item (name, amount, type, info/metadata)
            coords = playerCoords,
            model  = model,          -- for rebroadcast / persistence
        }

        DBSaveStack(clusterId, stackId, Drops[clusterId].stacks[stackId])

        -- Tell clients to spawn the prop for this stack
        TriggerClientEvent('itemdrops:client:spawnProp', -1, {
            stackId   = stackId,
            clusterId = clusterId,
            item      = { name = item.name, amount = item.amount, type = item.type, info = item.info, metadata = item.metadata },
            coords    = { x = playerCoords.x, y = playerCoords.y, z = playerCoords.z },
            model     = model
        })

        cb(clusterId)
    else
        cb(false)
    end
end)

QBCore.Functions.CreateCallback('qb-inventory:server:attemptPurchase', function(source, cb, data)
    local itemInfo = data.item
    local amount = data.amount
    local shop = string.gsub(data.shop, 'shop%-', '')
    local Player = QBCore.Functions.GetPlayer(source)

    if not Player then
        cb(false)
        return
    end

    local shopInfo = RegisteredShops[shop]
    if not shopInfo then
        cb(false)
        return
    end

    local playerPed = GetPlayerPed(source)
    local playerCoords = GetEntityCoords(playerPed)
    if shopInfo.coords then
        local shopCoords = vector3(shopInfo.coords.x, shopInfo.coords.y, shopInfo.coords.z)
        if #(playerCoords - shopCoords) > 10 then
            cb(false)
            return
        end
    end

    if shopInfo.items[itemInfo.slot].name ~= itemInfo.name then
        cb(false)
        return
    end

    if amount > shopInfo.items[itemInfo.slot].amount then
        TriggerClientEvent('QBCore:Notify', source, 'Cannot purchase larger quantity than currently in stock', 'error')
        cb(false)
        return
    end

    if not CanAddItem(source, itemInfo.name, amount) then
        TriggerClientEvent('QBCore:Notify', source, 'Cannot hold item', 'error')
        cb(false)
        return
    end

    local price = shopInfo.items[itemInfo.slot].price * amount
    if Player.PlayerData.money.cash >= price then
        Player.Functions.RemoveMoney('cash', price, 'shop-purchase')
        AddItem(source, itemInfo.name, amount, nil, itemInfo.info, 'shop-purchase')
        TriggerEvent('qb-shops:server:UpdateShopItems', shop, itemInfo, amount)
        cb(true)
    else
        TriggerClientEvent('QBCore:Notify', source, 'You do not have enough money', 'error')
        cb(false)
    end
end)

QBCore.Functions.CreateCallback('qb-inventory:server:giveItem', function(source, cb, target, item, amount, slot, info)
    local player = QBCore.Functions.GetPlayer(source)
    if not player or player.PlayerData.metadata['isdead'] or player.PlayerData.metadata['inlaststand'] or player.PlayerData.metadata['ishandcuffed'] then
        cb(false)
        return
    end
    local playerPed = GetPlayerPed(source)

    local Target = QBCore.Functions.GetPlayer(target)
    if not Target or Target.PlayerData.metadata['isdead'] or Target.PlayerData.metadata['inlaststand'] or Target.PlayerData.metadata['ishandcuffed'] then
        cb(false)
        return
    end
    local targetPed = GetPlayerPed(target)

    local pCoords = GetEntityCoords(playerPed)
    local tCoords = GetEntityCoords(targetPed)
    if #(pCoords - tCoords) > 5 then
        cb(false)
        return
    end

    local itemInfo = QBCore.Shared.Items[item:lower()]
    if not itemInfo then
        cb(false)
        return
    end

    local hasItem = HasItem(source, item)
    if not hasItem then
        cb(false)
        return
    end

    local itemAmount = GetItemByName(source, item).amount
    if itemAmount <= 0 then
        cb(false)
        return
    end

    local giveAmount = tonumber(amount)
    if giveAmount > itemAmount then
        cb(false)
        return
    end

    local removeItem = RemoveItem(source, item, giveAmount, slot, 'Item given to ID #' .. target)
    if not removeItem then
        cb(false)
        return
    end

    local giveItem = AddItem(target, item, giveAmount, false, info, 'Item given from ID #' .. source)
    if not giveItem then
        cb(false)
        return
    end

    if itemInfo.type == 'weapon' then checkWeapon(source, item) end
    TriggerClientEvent('qb-inventory:client:giveAnim', source)
    TriggerClientEvent('qb-inventory:client:ItemBox', source, itemInfo, 'remove', giveAmount)
    TriggerClientEvent('qb-inventory:client:giveAnim', target)
    TriggerClientEvent('qb-inventory:client:ItemBox', target, itemInfo, 'add', giveAmount)
    if Player(target).state.inv_busy then TriggerClientEvent('qb-inventory:client:updateInventory', target) end
    cb(true)
end)

-- ===========================
-- Item move (intercept stash->player)
-- ===========================

local function getItem(inventoryId, src, slot)
    local items = {}
    if inventoryId == 'player' then
        local Player = QBCore.Functions.GetPlayer(src)
        if Player and Player.PlayerData.items then
            items = Player.PlayerData.items
        end
    elseif inventoryId:find('otherplayer-') then
        local targetId = tonumber(inventoryId:match('otherplayer%-(.+)'))
        local targetPlayer = QBCore.Functions.GetPlayer(targetId)
        if targetPlayer and targetPlayer.PlayerData.items then
            items = targetPlayer.PlayerData.items
        end
    elseif inventoryId:find('drop-') == 1 then
        if Drops[inventoryId] and Drops[inventoryId]['items'] then
            items = Drops[inventoryId]['items']
        end
    else
        if Inventories[inventoryId] and Inventories[inventoryId]['items'] then
            items = Inventories[inventoryId]['items']
        end
    end

    for _, item in pairs(items) do
        if item.slot == slot then
            return item
        end
    end
    return nil
end

local function getIdentifier(inventoryId, src)
    if inventoryId == 'player' then
        return src
    elseif inventoryId:find('otherplayer-') then
        return tonumber(inventoryId:match('otherplayer%-(.+)'))
    else
        return inventoryId
    end
end

RegisterNetEvent('qb-inventory:server:SetInventoryData', function(fromInventory, toInventory, fromSlot, toSlot, fromAmount, toAmount)
    if toInventory:find('shop%-') then return end
    if not fromInventory or not toInventory or not fromSlot or not toSlot or not fromAmount or not toAmount or fromAmount < 0 or toAmount < 0 then return end
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    fromSlot, toSlot, fromAmount, toAmount = tonumber(fromSlot), tonumber(toSlot), tonumber(fromAmount), tonumber(toAmount)

    -- === custom path: moving FROM a cluster drop TO player ===
    if type(fromInventory) == 'string' and fromInventory:find('drop%-') == 1 and toInventory == 'player' then
        local drop = Drops[fromInventory]
        if not drop then return end

        -- use the same view we gave the UI and resolve the clicked slot
        local list = buildClusterInventory(drop)
        local disp = list[fromSlot]
        if not disp then return end

        local moveAmount = tonumber(toAmount) or tonumber(fromAmount) or disp.amount or 0
        moveAmount = math.max(0, math.min(moveAmount, disp.amount or 0))
        if moveAmount == 0 then return end

        -- capacity check
        if not CanAddItem(src, disp.name, moveAmount) then
            TriggerClientEvent('QBCore:Notify', src, 'Cannot hold item', 'error')
            return
        end

        -- consume from cluster stacks (also persists)
        local ok = consumeFromCluster(fromInventory, disp.name, disp.metadata or disp.info, moveAmount)
        if not ok then
            TriggerClientEvent('QBCore:Notify', src, 'Not enough in stash', 'error')
            return
        end

        AddItem(src, disp.name, moveAmount, toSlot, disp.info or disp.metadata, 'pickup world stash')

        -- refresh player side quickly
        TriggerClientEvent('qb-inventory:client:updateInventory', src)
        return
    end

    -- === original logic (player <-> player, stash, etc.) ===
    local fromItem = getItem(fromInventory, src, fromSlot)
    local toItem = getItem(toInventory, src, toSlot)

    if fromItem then
        if not toItem and toAmount > fromItem.amount then return end
        if fromInventory == 'player' and toInventory ~= 'player' then checkWeapon(src, fromItem) end

        local fromId = getIdentifier(fromInventory, src)
        local toId = getIdentifier(toInventory, src)

        if toItem and fromItem.name == toItem.name then
            if RemoveItem(fromId, fromItem.name, toAmount, fromSlot, 'stacked item') then
                AddItem(toId, toItem.name, toAmount, toSlot, toItem.info, 'stacked item')
            end
        elseif not toItem and toAmount < fromAmount then
            if RemoveItem(fromId, fromItem.name, toAmount, fromSlot, 'split item') then
                AddItem(toId, fromItem.name, toAmount, toSlot, fromItem.info, 'split item')
            end
        else
            if toItem then
                local fromItemAmount = fromItem.amount
                local toItemAmount = toItem.amount

                if RemoveItem(fromId, fromItem.name, fromItemAmount, fromSlot, 'swapped item') and RemoveItem(toId, toItem.name, toItemAmount, toSlot, 'swapped item') then
                    AddItem(toId, fromItem.name, fromItemAmount, toSlot, fromItem.info, 'swapped item')
                    AddItem(fromId, toItem.name, toItemAmount, fromSlot, toItem.info, 'swapped item')
                end
            else
                if RemoveItem(fromId, fromItem.name, toAmount, fromSlot, 'moved item') then
                    AddItem(toId, fromItem.name, toAmount, toSlot, fromItem.info, 'moved item')
                end
            end
        end
    end
end)

-- ==========================================
-- NEW: Single-stack pickup & open via target
-- ==========================================

RegisterNetEvent('itemdrops:server:pickupStack', function(clusterId, stackId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local cluster = Drops[clusterId]
    if not cluster or not cluster.stacks or not cluster.stacks[stackId] then return end
    local stack = cluster.stacks[stackId]

    -- proximity check to that stack
    local ped = GetPlayerPed(src)
    local pcoords = GetEntityCoords(ped)
    if #(pcoords - stack.coords) > 2.5 then return end

    -- try to give item
    if AddItem(src, stack.item.name, stack.item.amount, false, stack.item.metadata or stack.item.info, 'pickup world drop') then
        -- remove stack & tell clients to delete the prop
        cluster.stacks[stackId] = nil
        TriggerClientEvent('itemdrops:client:removeProp', -1, stackId)
        DBDeleteStack(stackId)

        -- cleanup cluster if empty
        if clusterIsEmpty(cluster) then
            DBDeleteCluster(clusterId)
            Drops[clusterId] = nil
        end
    else
        TriggerClientEvent('QBCore:Notify', src, 'No space.', 'error')
    end
end)

-- Client reports the final grounded coords so we persist them (fixes floating after restart)
RegisterNetEvent('itemdrops:server:updateStackCoords', function(clusterId, stackId, coords)
    local src = source
    local cluster = Drops[clusterId]
    if not cluster or not cluster.stacks then return end
    local s = cluster.stacks[stackId]
    if not s then return end

    -- update memory
    s.coords = vector3((coords.x or 0.0) + 0.0, (coords.y or 0.0) + 0.0, (coords.z or 0.0) + 0.0)

    -- persist new coords so next restart uses the grounded Z
    if DBSaveStack then
        DBSaveStack(clusterId, stackId, s)
    end
end)


RegisterNetEvent('itemdrops:server:openCluster', function(clusterId)
    print('[server] openCluster received from', source, 'clusterId=', clusterId)
    OpenDropFor(source, clusterId)
end)

RegisterNetEvent('itemdrops:server:syncAllStacks', function()
    local src = source
    for clusterId, cluster in pairs(Drops) do
        if cluster.stacks then
            for stackId, s in pairs(cluster.stacks) do
                TriggerClientEvent('itemdrops:client:spawnProp', src, {
                    stackId   = stackId,
                    clusterId = clusterId,
                    item      = s.item,
                    coords    = s.coords,
                    model     = s.model or Config.FallbackModel
                })
            end
        end
    end
end)
