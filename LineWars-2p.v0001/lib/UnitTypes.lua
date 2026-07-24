-- The single balance table: every factory a player may build and every unit
-- those factories may queue. Nothing else here is mechanism — FactoryQueue reads
-- these lists to build the restriction set, to decide which factory produces
-- which units, and to price the queue.
--
-- UNITS.md at the repo root is GENERATED from this file plus the stock
-- blueprints and the cost overrides in units/LineWars_units.bp. After editing
-- either, re-run tools/gen-units-md.py so the balance table stays honest.
--
-- Every byFaction list holds exactly four ids, ordered to match
-- brain:GetFactionIndex(): 1 UEF, 2 Aeon, 3 Cybran, 4 Seraphim.

FactionNames = { 'UEF', 'Aeon', 'Cybran', 'Seraphim' }

-- One entry per factory kind. `byFaction` are the tier-1 factory buildings
-- themselves (buildable by the ACU); `tiers` are the higher-tier buildings the
-- player upgrades into (native upgrade button; FactoryQueue intercepts the
-- order and charges for it). `roles` are the units that factory kind offers,
-- each tagged with the `tier` of building required to queue it.
--
-- A unit's build menu comes for free: the script restricts everything outside
-- these lists, and the engine's own tier gating means a tier-1 building can only
-- ever show tier-1 roles — you must upgrade the building to reach a tier-2 role.
Factories = {
    {
        kind = 'LAND',
        name = 'Land Factory',
        byFaction = { 'ueb0101', 'uab0101', 'urb0101', 'xsb0101' },
        -- Upgrade chain, indexed by the tier the building becomes. tiers[2] is
        -- the T2 land factory, faction-aligned with byFaction above. Each id must
        -- also be in the allowed set (AllFactoryIds feeds it) or AddRestriction
        -- destroys the upgraded building the moment it appears.
        tiers = {
            [2] = { 'ueb0201', 'uab0201', 'urb0201', 'xsb0201' },
        },
        roles = {
            { name = 'Light Assault Bot', tier = 1, byFaction = { 'uel0106', 'ual0106', 'url0106', 'xsl0101' } },
            { name = 'Tank',              tier = 1, byFaction = { 'uel0201', 'ual0201', 'url0107', 'xsl0201' } },
            { name = 'Mobile Artillery',  tier = 1, byFaction = { 'uel0103', 'ual0103', 'url0103', 'xsl0103' } },
            { name = 'Mobile AA',         tier = 1, byFaction = { 'uel0104', 'ual0104', 'url0104', 'xsl0104' } },
            { name = 'Heavy Tank',        tier = 2, byFaction = { 'uel0202', 'ual0202', 'url0202', 'xsl0202' } },
        },
    },
    {
        kind = 'AIR',
        name = 'Air Factory',
        byFaction = { 'ueb0102', 'uab0102', 'urb0102', 'xsb0102' },
        roles = {
            { name = 'Interceptor',   tier = 1, byFaction = { 'uea0102', 'uaa0102', 'ura0102', 'xsa0102' } },
            { name = 'Attack Bomber', tier = 1, byFaction = { 'uea0103', 'uaa0103', 'ura0103', 'xsa0103' } },
        },
    },
}

--------------------------------------------------------------------------
-- Derived lookups, built once on first use.
--------------------------------------------------------------------------
local factoryKind      -- factory blueprint id -> kind
local unitKind         -- wave unit blueprint id -> kind of factory that makes it
local unitsByKind      -- kind -> { wave unit ids }
local upgradeTarget    -- factory id -> the next-tier factory id it upgrades to
local allUnits         -- { every wave unit id }
local allFactories     -- { every factory id, all tiers }

local function Build()
    if factoryKind then
        return
    end
    factoryKind, unitKind, unitsByKind, upgradeTarget = {}, {}, {}, {}
    allUnits, allFactories = {}, {}
    for i, def in Factories do
        unitsByKind[def.kind] = {}
        for j, id in def.byFaction do
            factoryKind[id] = def.kind
            table.insert(allFactories, id)
        end
        -- Higher tiers, and the upgrade links between them. `prev` walks the
        -- chain so ueb0101 -> ueb0201 (-> ueb0301 ...) stays faction-aligned.
        if def.tiers then
            local prev = def.byFaction
            local tier = 2
            while def.tiers[tier] do
                for j, id in def.tiers[tier] do
                    factoryKind[id] = def.kind
                    table.insert(allFactories, id)
                    upgradeTarget[prev[j]] = id
                end
                prev = def.tiers[tier]
                tier = tier + 1
            end
        end
        for j, role in def.roles do
            for k, id in role.byFaction do
                unitKind[id] = def.kind
                table.insert(unitsByKind[def.kind], id)
                table.insert(allUnits, id)
            end
        end
    end
end

function AllUnitIds()
    Build()
    return allUnits
end

function AllFactoryIds()
    Build()
    return allFactories
end

-- 'LAND' / 'AIR' for a factory blueprint id, or nil if it isn't one of ours
-- (a player can only ever own ours, but mods and the restriction system make
-- a nil-safe answer worth having).
function KindOfFactory(id)
    Build()
    return factoryKind[id]
end

-- The units a factory of this kind may queue.
function UnitIdsForKind(kind)
    Build()
    return unitsByKind[kind] or {}
end

-- The factory id this one upgrades into (next tier), or nil if it is already at
-- the top of its chain (or isn't one of ours). Used by FactoryQueue to validate
-- and fulfil a native upgrade order.
function UpgradeTargetFor(id)
    Build()
    return upgradeTarget[id]
end
