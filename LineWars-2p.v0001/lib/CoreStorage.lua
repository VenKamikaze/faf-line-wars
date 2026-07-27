-- Per-round mass-storage growth for each player's Core.
--
-- There is NO engine API to change a live unit's storage, and no storage-type
-- buff — a unit's Economy.StorageMass is read once, when it finishes building,
-- and added to the army's storage pool (confirmed by searching the whole
-- gamedata: no SetStorage/SetMaxStorage/AddStorage on the brain, and Buff.lua
-- has no storage affect). So to make the storage bar's MAX grow each round we
-- spawn one real storage-bearing unit per round, stacked ON the Core and made
-- invisible, unselectable, untargetable and invulnerable — so it reads as "the
-- Core gained capacity" with nothing visible on the map and nothing for a wave
-- to shoot. The amount added is the building's StorageMass, set once in
-- units/LineWars_units.bp.
--
-- Cleanup: these units belong to the player army, so WinCondition.OnCoreKilled's
-- KillArmyUnits already removes them when the Core dies; CleanupFor() also
-- Destroy()s them explicitly there so it never depends on Kill()-vs-invulnerable
-- semantics. Victory is decided by LW.Dead flags, not unit counts, so these can
-- never keep an eliminated player "alive" or block a win.
local DIR = ScenarioInfo.directory or '/maps/LineWars-2p.v0001/'
local Config = import(DIR .. 'lib/Config.lua')

-- Faction storage buildings; index matches brain:GetFactionIndex()
-- (1 UEF, 2 Aeon, 3 Cybran, 4 Seraphim). StorageMass/StorageEnergy are
-- overridden in units/LineWars_units.bp.
--
-- Both caps grow, one building each per round. Energy was added 2026-07-26 for
-- tier 3: the cap had been a flat 3900 (the ACU's) all game, and because
-- FactoryQueue charges a queued unit's full energy price ATOMICALLY, nothing
-- dearer than that could ever be queued however long you saved — which capped a
-- unit at 780 mass on the map's 1:5 pricing and made T3 impossible. This is the
-- "energy storage never growing caps any future T3" open question in README.
local STORAGE_BY_FACTION = { 'ueb1106', 'uab1106', 'urb1106', 'xsb1106' }
local ENERGY_BY_FACTION  = { 'ueb1105', 'uab1105', 'urb1105', 'xsb1105' }

-- Category union of the storage buildings, for the script's allowed set so the
-- restriction system doesn't destroy the ones we spawn (same reason the Core is
-- exempted — see Unit.OnStopBeingBuilt / Game.IsRestricted).
function AllowedCategories()
    local allowed = nil
    local function add(list)
        for i, bp in list do
            if categories[bp] then
                allowed = allowed and (allowed + categories[bp]) or categories[bp]
            else
                WARN('LineWars: no category for storage building ' .. bp)
            end
        end
    end
    add(STORAGE_BY_FACTION)
    add(ENERGY_BY_FACTION)
    return allowed
end

local function Conceal(unit)
    unit:HideBone(0, true)         -- hide the entire mesh
    unit:SetUnSelectable(true)
    unit:SetDoNotTarget(true)      -- waves never target it; they hit the Core
    unit:SetCanTakeDamage(false)   -- stray splash at the Core can't chip storage
    unit:SetCapturable(false)
    unit:SetReclaimable(false)
    unit.LineWarsStorage = true    -- flag so AcuRules' no-build sweep skips it
end

-- Spawn one storage unit of `byFaction` for this army, stacked on its Core, and
-- track it.
local function GrantOne(armyName, byFaction)
    local LW = ScenarioInfo.LW
    local core = LW.Cores[armyName]
    if not core or core.Dead then
        return   -- no Core to grow (dead or never placed)
    end
    local pos = core:GetPosition()
    local brain = GetArmyBrain(armyName)
    local bp = byFaction[brain:GetFactionIndex()] or byFaction[1]
    local unit = CreateUnitHPR(bp, armyName, pos[1], pos[2], pos[3], 0, 0, 0)
    if not unit then
        WARN('LineWars: failed to spawn storage unit ' .. bp .. ' for ' .. armyName)
        return
    end
    Conceal(unit)
    LW.Storage[armyName] = LW.Storage[armyName] or {}
    table.insert(LW.Storage[armyName], unit)
end

-- The merged step size of a storage building, for the log line only.
local function StepOf(byFaction, field)
    local bp = __blueprints[byFaction[1]]
    return bp and bp.Economy and bp.Economy[field] or '?'
end

-- Called at the start of every round's build phase: grant one mass-storage and
-- one energy-storage unit (each worth its merged Storage* value) to every living
-- player.
function GrantForRound(round)
    local LW = ScenarioInfo.LW
    for i, armyName in LW.ActivePlayers do
        if not LW.Dead[armyName] then
            GrantOne(armyName, STORAGE_BY_FACTION)
            GrantOne(armyName, ENERGY_BY_FACTION)
        end
    end
    Config.Log('granted +' .. tostring(StepOf(STORAGE_BY_FACTION, 'StorageMass')) ..
        ' mass / +' .. tostring(StepOf(ENERGY_BY_FACTION, 'StorageEnergy')) ..
        ' energy storage per player for round ' .. round)
end

-- Set every living player's Core to the energy output its round is worth
-- (Config.CoreEnergyForRound). Called once from WinCondition.SpawnCores so the
-- Core never pays the stock 2500 e/s even during the start delay, and again at
-- the top of every round from RoundManager.
--
-- SetProductionPerSecondEnergy is a live engine setter, not a blueprint edit —
-- the distinction that matters here is the one in the .bp header: a map .bp
-- merge on ueb1301 would be silently overridden by any unit-overhaul mod that
-- also touches it, whereas this call reaches the engine directly and holds
-- whatever is loaded. Nothing re-applies the blueprint value behind us:
-- Unit.UpdateProductionValues (sim/Unit.lua:1265) only runs when an energy- or
-- mass-production BUFF is applied or removed, and the map never buffs a Core.
function ApplyCoreEnergy(round)
    local LW = ScenarioInfo.LW
    local rate = Config.CoreEnergyForRound(round)
    for i, armyName in LW.ActivePlayers do
        local core = LW.Cores[armyName]
        if core and not core.Dead then
            core:SetProductionPerSecondEnergy(rate)
        end
    end
    Config.Log('core energy set to ' .. rate .. ' e/s for round ' .. tostring(round))
end

-- Destroy this army's storage units (called from WinCondition.OnCoreKilled).
function CleanupFor(armyName)
    local LW = ScenarioInfo.LW
    local list = LW.Storage and LW.Storage[armyName]
    if not list then
        return
    end
    for i, u in list do
        if u and not u.Dead then
            u:Destroy()
        end
    end
    LW.Storage[armyName] = nil
end

function Start()
    ScenarioInfo.LW.Storage = {}   -- armyName -> { storage units }
end
