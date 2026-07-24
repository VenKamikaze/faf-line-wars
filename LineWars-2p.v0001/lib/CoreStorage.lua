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

-- Faction mass-storage building; index matches brain:GetFactionIndex()
-- (1 UEF, 2 Aeon, 3 Cybran, 4 Seraphim). StorageMass is overridden in
-- units/LineWars_units.bp.
local STORAGE_BY_FACTION = { 'ueb1106', 'uab1106', 'urb1106', 'xsb1106' }

-- Category union of the storage buildings, for the script's allowed set so the
-- restriction system doesn't destroy the ones we spawn (same reason the Core is
-- exempted — see Unit.OnStopBeingBuilt / Game.IsRestricted).
function AllowedCategories()
    local allowed = nil
    for i, bp in STORAGE_BY_FACTION do
        if categories[bp] then
            allowed = allowed and (allowed + categories[bp]) or categories[bp]
        else
            WARN('LineWars: no category for storage building ' .. bp)
        end
    end
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

-- Spawn one storage unit for this army, stacked on its Core, and track it.
local function GrantOne(armyName)
    local LW = ScenarioInfo.LW
    local core = LW.Cores[armyName]
    if not core or core.Dead then
        return   -- no Core to grow (dead or never placed)
    end
    local pos = core:GetPosition()
    local brain = GetArmyBrain(armyName)
    local bp = STORAGE_BY_FACTION[brain:GetFactionIndex()] or STORAGE_BY_FACTION[1]
    local unit = CreateUnitHPR(bp, armyName, pos[1], pos[2], pos[3], 0, 0, 0)
    if not unit then
        WARN('LineWars: failed to spawn storage unit for ' .. armyName)
        return
    end
    Conceal(unit)
    LW.Storage[armyName] = LW.Storage[armyName] or {}
    table.insert(LW.Storage[armyName], unit)
end

-- Called at the start of every round's build phase: grant one storage unit
-- (worth the merged StorageMass) to each living player.
function GrantForRound(round)
    local LW = ScenarioInfo.LW
    for i, armyName in LW.ActivePlayers do
        if not LW.Dead[armyName] then
            GrantOne(armyName)
        end
    end
    local step = __blueprints[STORAGE_BY_FACTION[1]]
    step = step and step.Economy and step.Economy.StorageMass or '?'
    Config.Log('granted +' .. tostring(step) .. ' storage/player for round ' .. round)
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
