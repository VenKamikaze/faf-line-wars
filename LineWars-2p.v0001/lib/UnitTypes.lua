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

-- One entry per factory kind. `byFaction` are the factory buildings themselves
-- (buildable by the ACU); `roles` are the units that factory kind offers. A
-- unit's build menu comes for free: the script restricts everything outside
-- these lists, so a land factory shows only the land roles and an air factory
-- only the air ones.
Factories = {
    {
        kind = 'LAND',
        name = 'Land Factory',
        byFaction = { 'ueb0101', 'uab0101', 'urb0101', 'xsb0101' },
        roles = {
            { name = 'Light Assault Bot', byFaction = { 'uel0106', 'ual0106', 'url0106', 'xsl0101' } },
            { name = 'Tank',              byFaction = { 'uel0201', 'ual0201', 'url0107', 'xsl0201' } },
            { name = 'Mobile Artillery',  byFaction = { 'uel0103', 'ual0103', 'url0103', 'xsl0103' } },
            { name = 'Mobile AA',         byFaction = { 'uel0104', 'ual0104', 'url0104', 'xsl0104' } },
        },
    },
    {
        kind = 'AIR',
        name = 'Air Factory',
        byFaction = { 'ueb0102', 'uab0102', 'urb0102', 'xsb0102' },
        roles = {
            { name = 'Interceptor',   byFaction = { 'uea0102', 'uaa0102', 'ura0102', 'xsa0102' } },
            { name = 'Attack Bomber', byFaction = { 'uea0103', 'uaa0103', 'ura0103', 'xsa0103' } },
        },
    },
}

--------------------------------------------------------------------------
-- Derived lookups, built once on first use.
--------------------------------------------------------------------------
local factoryKind      -- factory blueprint id -> kind
local unitKind         -- wave unit blueprint id -> kind of factory that makes it
local unitsByKind      -- kind -> { wave unit ids }
local allUnits         -- { every wave unit id }
local allFactories     -- { every factory id }

local function Build()
    if factoryKind then
        return
    end
    factoryKind, unitKind, unitsByKind = {}, {}, {}
    allUnits, allFactories = {}, {}
    for i, def in Factories do
        unitsByKind[def.kind] = {}
        for j, id in def.byFaction do
            factoryKind[id] = def.kind
            table.insert(allFactories, id)
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
