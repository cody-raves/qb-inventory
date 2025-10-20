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
    advancedlockpick = `prop_cs_package_01`,
    advancedrepairkit = `prop_tool_box_02`,
    advscope_attachment = `prop_box_guncase_02a`,
    aluminum = `prop_ld_scrap`,
    aluminumoxide = `prop_ld_scrap`,
    antipatharia_coral = `prop_cs_package_01`,
    armor = `prop_bodyarmour_03`,
    attachment_bench = `prop_cs_package_01`,
    bandage = `prop_ld_health_pack`,
    bank_card = `prop_ld_keypad_01`,
    barrel_attachment = `prop_box_guncase_02a`,
    beer = `prop_beer_bottle`,
    bellend_muzzle_brake = `prop_box_guncase_02a`,
    binoculars = `prop_cs_package_01`,
    boomcamo_attachment = `prop_box_guncase_02a`,
    brushcamo_attachment = `prop_box_guncase_02a`,
    casinochips = `prop_cash_pile_01`,
    certificate = `prop_ld_purse_01`,
    cleaningkit = `prop_cs_package_01`,
    clip_attachment = `prop_box_guncase_02a`,
    coffee = `p_ing_coffeecup_01`,
    coke_brick = `prop_coke_block_01`,
    coke_small_brick = `prop_coke_block_half_b`,
    cokebaggy = `prop_meth_bag_01`,
    comp_attachment = `prop_box_guncase_02a`,
    copper = `prop_ld_scrap`,
    crack_baggy = `prop_meth_bag_01`,
    cryptostick = `prop_cs_usb_drive`,
    dendrogyra_coral = `prop_cs_package_01`,
    digicamo_attachment = `prop_box_guncase_02a`,
    diving_fill = `p_s_scuba_mask_s`,
    diving_gear = `p_s_scuba_tank_s`,
    drill = `hei_prop_heist_drill`,
    driver_license = `prop_ld_purse_01`,
    drum_attachment = `prop_box_guncase_02a`,
    electronickit = `prop_cs_usb_drive`,
    emp_ammo = `prop_ld_ammo_pack_01`,
    empty_evidence_bag = `prop_cs_heist_bag_02`,
    empty_weed_bag = `prop_cs_package_01`,
    fat_end_muzzle_brake = `prop_box_guncase_02a`,
    filled_evidence_bag = `prop_cs_heist_bag_02`,
    firework1 = `ind_prop_firework_01`,
    firework2 = `ind_prop_firework_01`,
    firework3 = `ind_prop_firework_01`,
    firework4 = `ind_prop_firework_01`,
    firstaid = `prop_ld_health_pack`,
    fitbit = `prop_cs_package_01`,
    flashlight_attachment = `prop_box_guncase_02a`,
    flat_muzzle_brake = `prop_box_guncase_02a`,
    gatecrack = `prop_cs_package_01`,
    geocamo_attachment = `prop_box_guncase_02a`,
    glass = `prop_rub_scrap_06`,
    goldbar = `prop_gold_bar`,
    grapejuice = `rop_food_bs_juice02`,
    grip_attachment = `prop_box_guncase_02a`,
    harness = `p_mrk_harness_s`,
    heavy_duty_muzzle_brake = `prop_box_guncase_02a`,
    heavyarmor = `prop_bodyarmour_06`,
    holoscope_attachment = `prop_box_guncase_02a`,
    id_card = `p_ld_id_card_01`,
    ifaks = `prop_ld_health_pack`,
    iphone = `prop_phone_ing`,
    iron = `prop_rub_scrap_06`,
    ironoxide = `prop_rub_scrap_06`,
    item_bench = `prop_cs_package_01`,
    jerry_can = `w_am_jerrycan`,
    joint = `prop_weed_bottle`,
    kurkakola = `prop_vend_soda_01`,
    labkey = `prop_ld_keypad_01`,
    laptop = `prop_laptop_lester2`,
    largescope_attachment = `prop_box_guncase_02a`,
    lawyerpass = `p_ld_id_card_01`,
    leopardcamo_attachment = `prop_box_guncase_02a`,
    lighter = `p_cs_lighter_01`,
    luxuryfinish_attachment = `prop_box_guncase_02a`,
    markedbills = `prop_cash_pile_02`,
    medscope_attachment = `prop_box_guncase_02a`,
    metalscrap = `prop_ld_scrap`,
    meth = `prop_meth_bag_01`,
    mg_ammo = `prop_ld_ammo_pack_01`,
    moneybag = `prop_cs_heist_bag_02`,
    newsbmic = `prop_cs_package_01`,
    newscam = `prop_pap_camera_01`,
    newsmic = `prop_cs_package_01`,
    nitrous = `prop_gascyl_03a`,
    nvscope_attachment = `prop_box_guncase_02a`,
    oxy = `prop_cs_pills`,
    painkillers = `prop_cs_pills`,
    parachute = `p_parachute_s`,
    patriotcamo_attachment = `prop_box_guncase_02a`,
    perseuscamo_attachment = `prop_box_guncase_02a`,
    phone = `prop_phone_ing`,
    pinger = `prop_cs_usb_drive`,
    pistol_ammo = `prop_ld_ammo_pack_01`,
    plastic = `prop_ld_scrap`,
    police_stormram = `prop_cs_package_01`,
    precision_muzzle_brake = `prop_box_guncase_02a`,
    printerdocument = `prop_ld_purse_01`,
    radio = `prop_cs_hand_radio`,
    radioscanner = `prop_police_radio_main`,
    repairkit = `prop_tool_box_04`,
    rifle_ammo = `prop_ld_ammo_pack_01`,
    rolex = `prop_gold_bar`,
    rolling_paper = `prop_cs_package_01`,
    rubber = `prop_ld_scrap`,
    samsungphone = `prop_cs_package_01`,
    sandwich = `prop_cs_burger_01`,
    screwdriverset = `prop_tool_box_04`,
    security_card_01 = `prop_ld_keypad_01`,
    security_card_02 = `prop_ld_keypad_01`,
    sessantacamo_attachment = `prop_box_guncase_02a`,
    shotgun_ammo = `prop_ld_ammo_pack_01`,
    skullcamo_attachment = `prop_box_guncase_02a`,
    slanted_muzzle_brake = `prop_box_guncase_02a`,
    smallscope_attachment = `prop_box_guncase_02a`,
    smg_ammo = `prop_ld_ammo_pack_01`,
    snikkel_candy = `prop_vend_soda_01`,
    snp_ammo = `prop_ld_ammo_pack_01`,
    split_end_muzzle_brake = `prop_box_guncase_02a`,
    squared_muzzle_brake = `prop_box_guncase_02a`,
    steel = `prop_ld_scrap`,
    stickynote = `prop_notepad_02`,
    suppressor_attachment = `prop_box_guncase_02a`,
    tablet = `prop_cs_tablet`,
    tactical_muzzle_brake = `prop_box_guncase_02a`,
    tenkgoldchain = `prop_gold_bar`,
    thermalscope_attachment = `prop_box_guncase_02a`,
    thermite = `hei_prop_heist_thermite`, 
    tirerepairkit = `prop_tool_box_02`,
    tosti = `prop_cs_burger_01`,
    trojan_usb = `prop_cs_usb_drive`,
    tunerlaptop = `prop_laptop_02_closed`,
    twerks_candy = `prop_candy_pqs`,
    veh_armor = `prop_tool_box_01`,
    veh_brakes = `prop_tool_box_01`,
    veh_engine = `prop_tool_box_01`,
    veh_exterior = `prop_tool_box_01`,
    veh_interior = `prop_tool_box_01`,
    veh_neons = `prop_tool_box_01`,
    veh_plates = `prop_tool_box_01`,
    veh_suspension = `prop_tool_box_01`,
    veh_tint = `prop_tool_box_01`,
    veh_toolbox = `prop_tool_box_01`,
    veh_transmission = `prop_tool_box_01`,
    veh_turbo = `prop_tool_box_01`,
    veh_wheels = `prop_tool_box_01`,
    veh_xenons = `prop_tool_box_01`,
    vodka = `prop_vodka_bottle`,                   
    walkstick = `prop_cs_package_01`,
    water_bottle = `prop_ld_flow_bottle`,
    weapon_advancedrifle = `w_ar_advancedrifle`,
    weapon_appistol = `w_pi_appistol`,
    weapon_assaultrifle = `w_pi_pistol`,
    weapon_assaultrifle_mk2 = `w_ar_assaultrifle`,
    weapon_assaultshotgun = `w_sg_assaultshotgun`,
    weapon_assaultsmg = `w_pi_pistol`,
    weapon_autoshotgun = `w_sg_sweeper`,
    weapon_ball = `w_am_baseball`,
    weapon_bat = `w_pi_pistol`,
    weapon_battleaxe = `w_me_battleaxe`,
    weapon_bottle = `w_pi_pistol`,
    weapon_bread = `w_pi_pistol`,
    weapon_briefcase = `w_pi_pistol`,
    weapon_briefcase_02 = `w_pi_pistol`,
    weapon_bullpuprifle = `w_ar_bullpuprifle`,
    weapon_bullpuprifle_mk2 = `w_ar_bullpuprifle`,
    weapon_bullpupshotgun = `w_pi_pistol`,
    weapon_bzgas = `w_ex_bzgas`,
    weapon_candycane = `w_pi_pistol`,
    weapon_carbinerifle = `w_ar_carbinerifle`,
    weapon_carbinerifle_mk2 = `w_ar_carbinerifle`,
    weapon_ceramicpistol = `w_pi_ceramic_pistol`,
    weapon_combatmg = `w_mg_combatmg`,
    weapon_combatmg_mk2 = `w_mg_combatmg`,
    weapon_combatpdw = `w_sb_pdw`,
    weapon_combatpistol = `w_pi_combatpistol`,
    weapon_combatshotgun = `w_pi_pistol`,
    weapon_compactlauncher = `w_pi_pistol`,
    weapon_compactrifle = `w_pi_pistol`,
    weapon_crowbar = `w_me_crowbar`,
    weapon_dagger = `w_pi_pistol`,
    weapon_dbshotgun = `w_sg_doublebarrel`,
    weapon_doubleaction = `w_pi_pistol`,
    weapon_fireextinguisher = `w_am_fire_exting`,
    weapon_firework = `w_pi_pistol`,
    weapon_flare = `w_am_flare`,
    weapon_flaregun = `w_pi_flaregun`,
    weapon_flashlight = `w_pi_pistol`,
    weapon_gadgetpistol = `w_pi_pistol`,
    weapon_garbagebag = `w_pi_pistol`,
    weapon_golfclub = `w_me_gclub`,
    weapon_grenade = `w_ex_grenadefrag`,
    weapon_grenadelauncher = `w_ex_grenadefrag`,
    weapon_grenadelauncher_smoke = `w_ex_grenadefrag`,
    weapon_gusenberg = `w_sb_gusenberg`,
    weapon_hammer = `w_me_hammer`,
    weapon_handcuffs = `w_pi_pistol`,
    weapon_hatchet = `w_me_hatchet`,
    weapon_hazardcan = `w_am_jerrycan`,
    weapon_heavypistol = `w_pi_pistol`,
    weapon_heavyshotgun = `w_sg_heavyshotgun`,
    weapon_heavysniper = `w_sr_heavysniper`,
    weapon_heavysniper_mk2 = `w_sr_heavysniper`,
    weapon_hominglauncher = `w_pi_pistol`,
    weapon_knife = `w_me_knife_01`,
    weapon_knuckle = `w_pi_pistol`,
    weapon_machete = `w_me_machette_lr`,
    weapon_machinepistol = `w_pi_pistol`,
    weapon_marksmanpistol = `w_pi_singleshot`,
    weapon_marksmanrifle = `w_sr_marksmanrifle`,
    weapon_marksmanrifle_mk2 = `w_sr_marksmanrifle`,
    weapon_mg = `w_mg_mg`,
    weapon_microsmg = `w_sb_microsmg`,
    weapon_militaryrifle = `w_ar_assaultrifle`,
    weapon_minigun = `w_mg_minigun`,
    weapon_minismg = `w_sb_minismg`,
    weapon_molotov = `w_ex_molotov`,
    weapon_musket = `w_ar_musket`,
    weapon_navyrevolver = `w_pi_pistol`,
    weapon_nightstick = `w_me_nightstick`,
    weapon_petrolcan = `w_am_jerrycan`,
    weapon_pipebomb = `w_pi_pistol`,
    weapon_pistol = `w_pi_pistol`,
    weapon_pistol50 = `w_pi_pistol50`,
    weapon_pistol_mk2 = `w_pi_pistol`,
    weapon_pistolxm3 = `w_pi_pistol`,
    weapon_poolcue = `w_me_poolcue`,
    weapon_proxmine = `w_ex_apmine`,
    weapon_pumpshotgun = `w_sg_pumpshotgun`,
    weapon_pumpshotgun_mk2 = `w_sg_pumpshotgun`,
    weapon_railgun = `w_ar_railgun`,
    weapon_railgunxm3 = `w_ar_railgun`,
    weapon_raycarbine = `w_ar_srifle`,
    weapon_rayminigun = `w_mg_minigun`,
    weapon_raypistol = `w_pi_raygun`,
    weapon_remotesniper = `w_pi_pistol`,
    weapon_revolver = `w_pi_revolver`,
    weapon_revolver_mk2 = `w_pi_revolver`,
    weapon_rpg = `w_pi_pistol`,
    weapon_sawnoffshotgun = `w_sg_sawnoff`,
    weapon_smg = `w_sb_smg`,
    weapon_smg_mk2 = `w_sb_smg`,
    weapon_smokegrenade = `w_pi_pistol`,
    weapon_sniperrifle = `w_sr_sniperrifle`,
    weapon_snowball = `w_ex_snowball`,
    weapon_snspistol = `w_pi_pistol`,
    weapon_snspistol_mk2 = `w_pi_pistol`,
    weapon_specialcarbine = `w_ar_specialcarbine`,
    weapon_specialcarbine_mk2 = `w_ar_specialcarbine`,
    weapon_stickybomb = `w_ex_pe`,
    weapon_stone_hatchet = `w_me_hatchet`,
    weapon_stungun = `w_pi_stungun`,
    weapon_switchblade = `w_me_switchblade`,
    weapon_unarmed = `w_me_fist`,
    weapon_vintagepistol = `w_pi_vintage_pistol`,
    weapon_wrench = `w_me_wrench`,
    weaponlicense = `prop_ld_purse_01`,
    weapontint_0 = `prop_cs_package_01`,
    weapontint_1 = `prop_cs_package_01`,
    weapontint_2 = `prop_cs_package_01`,
    weapontint_3 = `prop_cs_package_01`,
    weapontint_4 = `prop_cs_package_01`,
    weapontint_5 = `prop_cs_package_01`,
    weapontint_6 = `prop_cs_package_01`,
    weapontint_7 = `prop_cs_package_01`,
    weapontint_mk2_0 = `prop_cs_package_01`,
    weapontint_mk2_1 = `prop_cs_package_01`,
    weapontint_mk2_10 = `prop_cs_package_01`,
    weapontint_mk2_11 = `prop_cs_package_01`,
    weapontint_mk2_12 = `prop_cs_package_01`,
    weapontint_mk2_13 = `prop_cs_package_01`,
    weapontint_mk2_14 = `prop_cs_package_01`,
    weapontint_mk2_15 = `prop_cs_package_01`,
    weapontint_mk2_16 = `prop_cs_package_01`,
    weapontint_mk2_17 = `prop_cs_package_01`,
    weapontint_mk2_18 = `prop_cs_package_01`,
    weapontint_mk2_19 = `prop_cs_package_01`,
    weapontint_mk2_2 = `prop_cs_package_01`,
    weapontint_mk2_20 = `prop_cs_package_01`,
    weapontint_mk2_21 = `prop_cs_package_01`,
    weapontint_mk2_22 = `prop_cs_package_01`,
    weapontint_mk2_23 = `prop_cs_package_01`,
    weapontint_mk2_24 = `prop_cs_package_01`,
    weapontint_mk2_25 = `prop_cs_package_01`,
    weapontint_mk2_26 = `prop_cs_package_01`,
    weapontint_mk2_27 = `prop_cs_package_01`,
    weapontint_mk2_28 = `prop_cs_package_01`,
    weapontint_mk2_29 = `prop_cs_package_01`,
    weapontint_mk2_3 = `prop_cs_package_01`,
    weapontint_mk2_30 = `prop_cs_package_01`,
    weapontint_mk2_31 = `prop_cs_package_01`,
    weapontint_mk2_32 = `prop_cs_package_01`,
    weapontint_mk2_4 = `prop_cs_package_01`,
    weapontint_mk2_5 = `prop_cs_package_01`,
    weapontint_mk2_6 = `prop_cs_package_01`,
    weapontint_mk2_7 = `prop_cs_package_01`,
    weapontint_mk2_8 = `prop_cs_package_01`,
    weapontint_mk2_9 = `prop_cs_package_01`,
    weed_ak47 = `prop_meth_bag_01`,
    weed_ak47_seed = `prop_meth_bag_01`,
    weed_amnesia = `prop_meth_bag_01`,
    weed_amnesia_seed = `prop_meth_bag_01`,
    weed_brick = `prop_meth_bag_01`,
    weed_nutrition = `prop_meth_bag_01`,
    weed_ogkush = `prop_meth_bag_01`,
    weed_ogkush_seed = `prop_meth_bag_01`,
    weed_purplehaze = `prop_meth_bag_01`,
    weed_purplehaze_seed = `prop_meth_bag_01`,
    weed_skunk = `prop_meth_bag_01`,
    weed_skunk_seed = `prop_meth_bag_01`,
    weed_whitewidow = `prop_meth_bag_01`,
    weed_whitewidow_seed = `prop_meth_bag_01`,
    whiskey = `prop_ld_keypad_01`,
    wine = `prop_wine_bot_01`,
    woodcamo_attachment = `prop_box_guncase_02a`,
    xtcbaggy = `prop_cs_heist_bag_02`,
    zebracamo_attachment = `prop_box_guncase_02a`,
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
    -- ignore shop moves
    if type(toInventory) == 'string' and toInventory:find('shop%-') then return end

    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    -- Normalize inputs but DON'T hard-fail on nils (UI sometimes omits)
    fromSlot   = tonumber(fromSlot)
    toSlot     = tonumber(toSlot)          -- may be nil when dragging into world drop
    fromAmount = tonumber(fromAmount) or 0
    toAmount   = tonumber(toAmount)   or 0

    if not fromInventory or not toInventory or not fromSlot then return end
    if fromAmount < 0 or toAmount < 0 then return end

    -- === custom path: moving FROM player TO a cluster drop ===
    if fromInventory == 'player' and type(toInventory) == 'string' and toInventory:find('drop%-') == 1 then
        local dropId = toInventory
        local drop   = Drops[dropId]

        if not drop then
            local pcoords = GetEntityCoords(GetPlayerPed(src))
            drop = {
                name        = dropId,
                label       = 'Drop',
                createdTime = os.time(),
                coords      = pcoords,
                maxweight   = Config.DropSize.maxweight,
                slots       = Config.DropSize.slots,
                isOpen      = true,
                stacks      = {}
            }
            Drops[dropId] = drop
            if DBSaveCluster then DBSaveCluster(dropId, pcoords) end
        end

        local fromItem = getItem('player', src, fromSlot)
        if not fromItem then return end

        -- prefer explicit fromAmount; fall back to toAmount; else full stack
        local moveAmount = (fromAmount > 0 and fromAmount) or (toAmount > 0 and toAmount) or (fromItem.amount or 0)
        moveAmount = math.max(0, math.min(moveAmount, fromItem.amount or 0))
        if moveAmount <= 0 then return end

        -- proximity (centroid or any stack)
        local ped, pcoords = GetPlayerPed(src), GetEntityCoords(GetPlayerPed(src))
        local near = (drop.coords and #(pcoords - drop.coords) <= 3.0)
        if not near and drop.stacks then
            for _, s in pairs(drop.stacks) do
                if s.coords and #(pcoords - s.coords) <= 3.0 then near = true break end
            end
        end
        if not near then
            TriggerClientEvent('QBCore:Notify', src, 'Too far from drop.', 'error')
            return
        end

        if not RemoveItem(src, fromItem.name, moveAmount, fromSlot, 'drop into world cluster') then
            return
        end
        if fromItem.type == 'weapon' then checkWeapon(src, fromItem) end

        -- merge by name + exact meta (info)
        local function sameMeta(a, b) return json.encode(a or {}) == json.encode(b or {}) end
        local merged = false
        for sid, st in pairs(drop.stacks or {}) do
            if st.item and string.lower(st.item.name) == string.lower(fromItem.name)
               and sameMeta(st.item.metadata or st.item.info, fromItem.info) then
                st.item.amount = (st.item.amount or 0) + moveAmount
                if DBSaveStack then DBSaveStack(dropId, sid, st) end
                merged = true
                break
            end
        end

        if not merged then
            local mdl  = ItemModels[string.lower(fromItem.name)] or (Config.FallbackModel or `prop_cs_package_01`)
            local base = drop.coords or pcoords
            local ang  = math.random() * math.pi * 2
            local rad  = (Config.DropClusterRadius or 1.5) * (0.45 + math.random() * 0.55)
            local pos  = vector3(base.x + math.cos(ang) * rad, base.y + math.sin(ang) * rad, base.z)

            local stackId = ('stack-%d'):format(math.random(100000, 999999))
            drop.stacks[stackId] = {
                item   = { name = fromItem.name, amount = moveAmount, type = fromItem.type, info = fromItem.info, metadata = fromItem.info },
                coords = pos,
                model  = mdl,
            }
            if DBSaveStack then DBSaveStack(dropId, stackId, drop.stacks[stackId]) end

            TriggerClientEvent('itemdrops:client:spawnProp', -1, {
                stackId   = stackId,
                clusterId = dropId,
                item      = { name = fromItem.name, amount = moveAmount, type = fromItem.type, info = fromItem.info, metadata = fromItem.info },
                coords    = { x = pos.x, y = pos.y, z = pos.z },
                model     = mdl,
            })
        end

        -- 🔄 re-open the drop with updated contents so more drags are accepted
        local items = buildClusterInventory(drop)
        local formatted = {
            name      = dropId,
            label     = dropId,
            maxweight = drop.maxweight or Config.DropSize.maxweight,
            slots     = math.max(#items, drop.slots or Config.DropSize.slots or 40),
            inventory = items
        }
        TriggerClientEvent('qb-inventory:client:openInventory', src, Player.PlayerData.items, formatted)

        -- also refresh player's side
        TriggerClientEvent('qb-inventory:client:updateInventory', src)
        return
    end

    -- === custom path: moving FROM a cluster drop TO player ===
    if type(fromInventory) == 'string' and fromInventory:find('drop%-') == 1 and toInventory == 'player' then
        local drop = Drops[fromInventory]
        if not drop then return end

        local list = buildClusterInventory(drop)
        local disp = list[fromSlot]
        if not disp then return end

        -- prefer toAmount (what UI intends to take), else fromAmount, else whatever’s there
        local moveAmount = (toAmount > 0 and toAmount) or (fromAmount > 0 and fromAmount) or (disp.amount or 0)
        moveAmount = math.max(0, math.min(moveAmount, disp.amount or 0))
        if moveAmount == 0 then return end

        if not CanAddItem(src, disp.name, moveAmount) then
            TriggerClientEvent('QBCore:Notify', src, 'Cannot hold item', 'error')
            return
        end

        local ok = consumeFromCluster(fromInventory, disp.name, (disp.metadata or disp.info), moveAmount)
        if not ok then
            TriggerClientEvent('QBCore:Notify', src, 'Not enough in stash', 'error')
            return
        end

        AddItem(src, disp.name, moveAmount, toSlot, disp.info or disp.metadata, 'pickup world stash')
        TriggerClientEvent('qb-inventory:client:updateInventory', src)
        return
    end

    -- === original logic (player <-> player, named stashes, trunks, etc.) ===
    local fromItem = getItem(fromInventory, src, fromSlot)
    local toItem   = getItem(toInventory,   src, toSlot)

    if fromItem then
        if not toItem and toAmount > fromItem.amount then return end
        if fromInventory == 'player' and toInventory ~= 'player' then checkWeapon(src, fromItem) end

        local fromId = getIdentifier(fromInventory, src)
        local toId   = getIdentifier(toInventory,   src)

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
                local toItemAmount   = toItem.amount

                if RemoveItem(fromId, fromItem.name, fromItemAmount, fromSlot, 'swapped item')
                and RemoveItem(toId,   toItem.name, toItemAmount,   toSlot,   'swapped item') then
                    AddItem(toId,   fromItem.name, fromItemAmount, toSlot,   fromItem.info, 'swapped item')
                    AddItem(fromId, toItem.name,   toItemAmount,   fromSlot, toItem.info,   'swapped item')
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
