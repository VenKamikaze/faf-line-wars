-- The single balance table: every factory a player may build and every unit
-- those factories may queue. Nothing else here is mechanism — FactoryQueue reads
-- these lists to build the restriction set, to decide which factory produces
-- which units, and to price the queue.
--
-- AcuStructures (below) is a deliberately SEPARATE table for structures the ACU
-- builds directly (never queued in a factory) — see its own header comment for
-- why it must never be folded into Factories/roles/AllUnitIds().
--
-- UNITS.md at the repo root is GENERATED from this file plus the stock
-- blueprints and the cost overrides in units/LineWars_units.bp. After editing
-- either, re-run tools/gen-units-md.py so the balance table stays honest.
--
-- Every byFaction list holds exactly four entries, ordered to match
-- brain:GetFactionIndex(): 1 UEF, 2 Aeon, 3 Cybran, 4 Seraphim. Where a faction
-- has no unit for a role at all, the slot holds `false` rather than being
-- omitted — the position IS the faction, so a shorter list would silently
-- re-label the rest. (No role needs that today; the convention is fixed here so
-- that a future one can, and the derived lookups below already skip `false`.)

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
            [3] = { 'ueb0301', 'uab0301', 'urb0301', 'xsb0301' },
        },
        roles = {
            { name = 'Light Assault Bot', tier = 1, byFaction = { 'uel0106', 'ual0106', 'url0106', 'xsl0101' } },
            { name = 'Tank',              tier = 1, byFaction = { 'uel0201', 'ual0201', 'url0107', 'xsl0201' } },
            { name = 'Mobile Artillery',  tier = 1, byFaction = { 'uel0103', 'ual0103', 'url0103', 'xsl0103' } },
            { name = 'Mobile AA',         tier = 1, byFaction = { 'uel0104', 'ual0104', 'url0104', 'xsl0104' } },
            { name = 'Heavy Tank',        tier = 2, byFaction = { 'uel0202', 'ual0202', 'url0202', 'xsl0202' } },
            { name = 'Mobile Missile Launcher', tier = 2, byFaction = { 'uel0111', 'ual0111', 'url0111', 'xsl0111' } },
            { name = 'Mobile Flak',       tier = 2, byFaction = { 'uel0205', 'ual0205', 'url0205', 'xsl0205' } },
            -- Tier 3. Siege Assault Bot is the workhorse (Titan/Harbinger/
            -- Loyalist/Othuum); Heavy Artillery and T3 Mobile AA are the
            -- symmetric support pair.
            { name = 'Siege Assault Bot', tier = 3, byFaction = { 'uel0303', 'ual0303', 'url0303', 'xsl0303' } },
            { name = 'Heavy Artillery',   tier = 3, byFaction = { 'uel0304', 'ual0304', 'url0304', 'xsl0304' } },
            -- NOTE the `d*lk*` ids: the T3 mobile AA units are expansion-pack
            -- blueprints, not the `*l0xxx` pattern, exactly like the T2
            -- fighter/bombers below. They are live FAF units (build-mode hotkeys
            -- at lua/ui/game/buildmodedata.lua:230,371,426, AI land platoon
            -- templates, and FAF balance changelogs reference them). Do not
            -- "correct" them.
            { name = 'T3 Mobile AA',      tier = 3, byFaction = { 'delk002', 'dalk003', 'drlk001', 'dslk004' } },
            -- NO T3 MOBILE SHIELD ROW, and do not add one back with `*l0309`:
            -- those ids are the T3 ENGINEERS (Iyathuum et al.), not shields. They
            -- were listed here as 'Mobile Shield' until 2026-07-26, and because an
            -- engineer is MOBILE CONSTRUCTION — which BOTH the T3 land and T3 air
            -- factory's BuildableCategory matches (UEB0301_unit.bp:99,
            -- UEB0302_unit.bp:98) — a T3 engineer appeared in both build menus.
            -- There is no symmetric replacement: stock FA ships mobile shields only
            -- at T2 for UEF/Aeon (uel0307/ual0307), T3 for Seraphim (xsl0307), and
            -- none at all for Cybran. Any future row here has to accept that
            -- asymmetry, like the Faction Special below does.
            -- The faction-signature slot. Deliberately NOT symmetric: UEF and
            -- Cybran get their heavy brawlers, Aeon and Seraphim their long-range
            -- snipers. These are the dearest things in the game (see the mass-cap
            -- note in units/LineWars_units.bp) and are meant to be a late-game
            -- statement, not a staple.
            { name = 'Faction Special',   tier = 3, byFaction = { 'xel0305', 'xal0305', 'xrl0305', 'xsl0305' } },
        },
    },
    {
        kind = 'AIR',
        name = 'Air Factory',
        byFaction = { 'ueb0102', 'uab0102', 'urb0102', 'xsb0102' },
        tiers = {
            [2] = { 'ueb0202', 'uab0202', 'urb0202', 'xsb0202' },
            [3] = { 'ueb0302', 'uab0302', 'urb0302', 'xsb0302' },
        },
        roles = {
            { name = 'Interceptor',   tier = 1, byFaction = { 'uea0102', 'uaa0102', 'ura0102', 'xsa0102' } },
            { name = 'Attack Bomber', tier = 1, byFaction = { 'uea0103', 'uaa0103', 'ura0103', 'xsa0103' } },
            { name = 'Gunship',       tier = 2, byFaction = { 'uea0203', 'uaa0203', 'ura0203', 'xsa0203' } },
            -- NOTE the odd blueprint prefixes: the UEF and Cybran fighter/bombers
            -- are `dea`/`dra`, the Aeon one `xaa` — they are expansion-pack ids,
            -- not the `uea`/`uaa`/`ura`/`xsa` pattern every other row here uses.
            -- They are NOT typos and must not be "corrected". All four are live
            -- FAF units (icons in textures.nx2, meshes in the retail archives, AI
            -- platoon templates and build-mode hotkeys reference them, and FAF
            -- still balance-patches the Swift Wind). Aeon's is the odd one out in
            -- role too: Swift Wind is a pure air-to-air Combat Fighter with no
            -- bombs, where the other three genuinely bomb ground as well.
            { name = 'Fighter/Bomber', tier = 2, byFaction = { 'dea0202', 'xaa0202', 'dra0202', 'xsa0202' } },
            -- Tier 3. The air-superiority fighter is symmetric across all four
            -- (`*a0303`) and is the answer to a T3 air push.
            { name = 'Air Superiority Fighter', tier = 3, byFaction = { 'uea0303', 'uaa0303', 'ura0303', 'xsa0303' } },
            -- Faction-signature air, and the least symmetric row in this file:
            -- UEF Broadsword and Cybran Wailer are the two stock T3 heavy
            -- gunships; Aeon has no gunship so it gets the Restorer (its T3
            -- air-superiority gunship, hits ground AND air); Seraphim has
            -- neither, so it gets the Sinntha strategic bomber. If that reads
            -- as too strong in play, drop the Seraphim slot to `false` (the
            -- sparse-faction convention above) rather than reshuffling the row.
            { name = 'Heavy Air',      tier = 3, byFaction = { 'uea0305', 'xaa0305', 'xra0305', 'xsa0304' } },
        },
    },
}

-- Defense structures the ACU may build DIRECTLY on its own side of the lane
-- (see AcuRules' no-build-zone carve-out and midline check) — normal ACU
-- construction, not a FactoryQueue queue. Deliberately a separate table from
-- Factories/roles: AllUnitIds() feeds FactoryQueue.WaveCategory(), which
-- PurgeStrayUnits() uses to Destroy() any unit of that category found sitting
-- in a player army every tick (it assumes that can only be escaped
-- factory-queue production). These structures are SUPPOSED to sit in a player
-- army, so their ids must never be reachable from AllUnitIds() — use
-- AllStructureIds()/IsAcuStructure() instead, which are entirely separate
-- derived lookups.
AcuStructures = {
    { name = 'T1 Point Defense', tier = 1, byFaction = { 'ueb2101', 'uab2101', 'urb2101', 'xsb2101' } },
    { name = 'T1 AA Defense',    tier = 1, byFaction = { 'ueb2104', 'uab2104', 'urb2104', 'xsb2104' } },
    { name = 'T2 Point Defense', tier = 2, byFaction = { 'ueb2301', 'uab2301', 'urb2301', 'xsb2301' } },
    { name = 'T2 AA Defense',    tier = 2, byFaction = { 'ueb2204', 'uab2204', 'urb2204', 'xsb2204' } },
    { name = 'T2 Shield',        tier = 2, byFaction = { 'ueb4202', 'uab4202', 'urb4202', 'xsb4202' } },
    { name = 'T3 AA Defense',    tier = 3, byFaction = { 'ueb2304', 'uab2304', 'urb2304', 'xsb2304' } },
    -- T3 Point Defense is the odd one out: the stock game has EXACTLY ONE, the
    -- UEF Ravager, so all four factions are given the same building. That takes
    -- a blueprint merge, because an ACU's BuildableCategory is faction-scoped
    -- ("BUILTBYTIER3COMMANDER CYBRAN", UEL0001_unit.bp:227-231) and the Ravager
    -- only carries UEF — units/LineWars_units.bp appends AEON/CYBRAN/SERAPHIM to
    -- its Categories so every ACU's expression matches it. It keeps its UEF
    -- model and name for everyone; that is cosmetic and intended.
    --
    -- If a unit-overhaul mod (BlackOps et al.) that ships real per-faction T3 PD
    -- is loaded, this row is NOT replaced by it — their ids aren't listed here so
    -- the map's restriction set hides them, and the Ravager stays. Playing
    -- without those mods is the project's standing recommendation anyway (a map
    -- .bp loses to mods, so none of the costs in units/LineWars_units.bp hold
    -- with them on).
    { name = 'T3 Point Defense', tier = 3, byFaction = { 'xeb2306', 'xeb2306', 'xeb2306', 'xeb2306' } },
}

-- Land experimentals the ACU builds DIRECTLY once it has the Tech 3 Engineering
-- Suite. Unlike everything above they are MOBILE, and they do not stay with the
-- player: lib/Experimentals.lua transfers each one into the builder's
-- ARMY_WAVE_n the instant it completes, so it joins that lane's march like any
-- other wave unit.
--
-- A THIRD separate table, for the same reason AcuStructures is a second one:
-- these ids must never be reachable from AllUnitIds(), which feeds
-- FactoryQueue.WaveCategory() and hence PurgeStrayUnits() — that sweep Destroy()s
-- any unit of its category sitting in a player army, and an experimental
-- legitimately sits there for the whole time the ACU is building it.
--
-- NO BLUEPRINT CATEGORY MERGE IS NEEDED HERE, unlike the T3 Point Defense above.
-- All four already carry BUILTBYTIER3COMMANDER *and* their own faction category
-- (verified in units.nx2), and every ACU's stock BuildableCategory includes
-- "BUILTBYTIER3COMMANDER <FACTION>" (UEL0001_unit.bp:227-231). So the roster is
-- faction-locked for free: a Cybran ACU's expression can only ever match the
-- Monkeylord. Note the same blueprint line means the tier-3 gate is NOT free —
-- that BuildableCategory entry is present from tick 0 with no enhancement
-- prerequisite, so Experimentals.lua has to gate on the T3Engineering
-- enhancement itself.
--
-- The faction order is the usual one; url0402 (not url0401 — that is the Cybran
-- experimental air unit) is the Monkeylord.
AcuExperimentals = {
    { name = 'Fatboy',     faction = 1, id = 'uel0401' },
    { name = 'Colossus',   faction = 2, id = 'ual0401' },
    { name = 'Monkeylord', faction = 3, id = 'url0402' },
    { name = 'Ythotha',    faction = 4, id = 'xsl0401' },
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
            -- `false` marks a faction with no unit for this role (see the header
            -- comment): skip it, don't key the lookups on a boolean.
            for k, id in role.byFaction do
                if id then
                    unitKind[id] = def.kind
                    table.insert(unitsByKind[def.kind], id)
                    table.insert(allUnits, id)
                end
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

--------------------------------------------------------------------------
-- AcuStructures derived lookups. Kept entirely separate from Build() above —
-- see the AcuStructures header comment for why these ids must never end up in
-- AllUnitIds()/unitsByKind.
--------------------------------------------------------------------------
local structureIds   -- { every AcuStructures id }
local structureSet   -- id -> true, for fast membership tests

local function BuildStructures()
    if structureIds then
        return
    end
    structureIds, structureSet = {}, {}
    for i, role in AcuStructures do
        for j, id in role.byFaction do
            -- Deduped, unlike Build() above: the T3 Point Defense row lists the
            -- same Ravager id for all four factions, and a repeated id would be
            -- added to the allowed-category union four times over.
            if id and not structureSet[id] then
                table.insert(structureIds, id)
                structureSet[id] = true
            end
        end
    end
end

function AllStructureIds()
    BuildStructures()
    return structureIds
end

-- True if `id` is one of the ACU-buildable defense structures (T1/T2 Point
-- Defense, T1/T2 AA, T2 Shield). Used by AcuRules to exempt them from the
-- no-build-zone sweep (subject to the midline check).
function IsAcuStructure(id)
    BuildStructures()
    return structureSet[id] == true
end

--------------------------------------------------------------------------
-- AcuExperimentals derived lookups. Separate again — see that table's header
-- for why these ids must stay out of AllUnitIds()/AllStructureIds().
--------------------------------------------------------------------------
local experimentalIds   -- { every AcuExperimentals id }
local experimentalSet   -- id -> true

local function BuildExperimentals()
    if experimentalIds then
        return
    end
    experimentalIds, experimentalSet = {}, {}
    for i, def in AcuExperimentals do
        if def.id and not experimentalSet[def.id] then
            table.insert(experimentalIds, def.id)
            experimentalSet[def.id] = true
        end
    end
end

function AllExperimentalIds()
    BuildExperimentals()
    return experimentalIds
end

-- True if `id` is one of the four ACU-buildable land experimentals.
function IsAcuExperimental(id)
    BuildExperimentals()
    return experimentalSet[id] == true
end
