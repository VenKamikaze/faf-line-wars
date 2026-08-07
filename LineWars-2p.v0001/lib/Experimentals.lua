-- Land experimentals: one per faction (Fatboy / Colossus / Monkeylord /
-- Ythotha), built DIRECTLY by the ACU once it reaches tech 3, then handed
-- straight to the builder's wave army so it marches down the lane.
--
-- Three engine facts shape this module; all three were verified in
-- ~/.faforever/gamedata (units.nx2, lua.nx2) rather than assumed.
--
-- 1. FACTION LOCKING IS FREE. All four experimentals carry both
--    BUILTBYTIER3COMMANDER and their own faction category, and every stock ACU's
--    Economy.BuildableCategory is exactly {"BUILTBYCOMMANDER <F>",
--    "BUILTBYTIER2COMMANDER <F>", "BUILTBYTIER3COMMANDER <F>"}
--    (UEL0001_unit.bp:227-231). The faction term means a Cybran ACU can only
--    ever match the Monkeylord — no blueprint merge needed, unlike the T3 Point
--    Defense in UnitTypes.AcuStructures.
--
-- 2. TIER GATING IS THE ENGINE'S JOB, and the script's gate is belt-and-braces.
--    Reading the blueprint alone suggests otherwise: that BUILTBYTIER3COMMANDER
--    term is present from tick 0 with no enhancement prerequisite, and the
--    T3Engineering enhancement's BuildableCategoryAdds is the identical string,
--    so on paper nothing gates T3. In practice the engine does hide T3 items
--    from a pre-upgrade ACU's build menu — original SupCom behaviour, confirmed
--    in game by Kamikaze (2026-07-27). The AddRestriction/RemoveRestriction below
--    (the pattern lib/AirGate.lua uses for the air lock, sitting ON TOP of the
--    script's `ALLUNITS - allowed` since these ids are inside `allowed`) is
--    therefore a second belt on the same trousers. It is kept because it makes
--    the rule explicit and survives a mod that widens the ACU's menu, but it is
--    behind Config.ExperimentalsScriptTierGate: the failure mode of a stuck
--    script gate is "experimentals never buildable at all", so if the unlock
--    ever misfires, turn the flag off and let the engine handle it.
--    The gate polls Unit:HasEnhancement('T3Engineering') (sim/Unit.lua:3368) —
--    all four ACUs name it identically, and units/LineWars_units.bp reprices it
--    to 1500 mass. There is no "enhancement finished" callback a map can reach,
--    hence the poll; it shares the loop with the completion sweep below.
--
-- 3. OWNERSHIP TRANSFER RECREATES THE UNIT. SimUtils.TransferUnitsOwnership
--    (lua/SimUtils.lua:246) wraps ChangeUnitArmy, carrying health, veterancy,
--    orientation and — the reason to use it rather than ChangeUnitArmy directly
--    — the Fatboy's ExternalFactory child, which it handles explicitly. It
--    refuses anything under construction (GetFractionComplete() < 1), which is
--    exactly the completion test we want, but we check it ourselves too so the
--    log line and the march order only fire on a real handover. The returned
--    list holds the NEW units; the originals are gone.
--
-- Not needed here, and deliberately so:
--   * PurgeStrayUnits cannot see these — UnitTypes.AcuExperimentals is a table of
--     its own, outside AllUnitIds(), precisely so a half-built experimental can
--     sit in the player's army without being swept away every tick.
--   * AcuRules' no-build/midline sweep only walks categories.STRUCTURE, and these
--     are MOBILE. Nothing stops an ACU siting one inside a no-build corridor, but
--     it leaves under its own orders within the second, so there is nothing to
--     wall a lane with.
local ScenarioFramework = import('/lua/ScenarioFramework.lua')
local SimUtils = import('/lua/SimUtils.lua')
local DIR = ScenarioInfo.directory or '/maps/LineWars-2p.v0001/'
local Config = import(DIR .. 'lib/Config.lua')
local UnitTypes = import(DIR .. 'lib/UnitTypes.lua')
local FactoryQueue = import(DIR .. 'lib/FactoryQueue.lua')
local WaveSpawner = import(DIR .. 'lib/WaveSpawner.lua')

local ENHANCEMENT = 'T3Engineering'

-- Category union of the four experimentals, built once. Used both for the
-- script's allowed set and as the thing the tier gate restricts.
local expCategory
local expCategoryBuilt = false

function ExperimentalCategory()
    if expCategoryBuilt then
        return expCategory
    end
    expCategoryBuilt = true
    for i, bp in UnitTypes.AllExperimentalIds() do
        if categories[bp] then
            expCategory = expCategory and (expCategory + categories[bp]) or categories[bp]
        else
            WARN('LineWars: Experimentals no category for ' .. tostring(bp))
        end
    end
    return expCategory
end

-- Same union, for LineWars-2p_script.lua's allowed set. Kept as its own name so
-- that call site reads like the CoreStorage/FactoryQueue ones beside it.
function AllowedCategories()
    return ExperimentalCategory()
end

-- Does this army's ACU have the Tech 3 Engineering Suite yet? Any ACU will do:
-- a player has one, and if a rebuilt one somehow lacks the upgrade the gate
-- simply stays open, which is the harmless direction to fail.
local function HasTech3(armyName)
    for i, acu in GetArmyBrain(armyName):GetListOfUnits(categories.COMMAND, false) do
        if not acu.Dead and acu:HasEnhancement(ENHANCEMENT) then
            return true
        end
    end
    return false
end

-- Hand one completed experimental to the builder's wave army and send it down
-- the lane it was built in.
local function Handover(armyName, unit)
    local waveArmy = Config.WaveArmyOf(armyName)
    local lane = FactoryQueue.LaneForPosition(armyName, unit:GetPosition())
    local name = unit.UnitId

    local newUnits = SimUtils.TransferUnitsOwnership({ unit }, GetArmyBrain(waveArmy):GetArmyIndex())
    if not newUnits or table.getn(newUnits) == 0 then
        WARN('LineWars: failed to transfer ' .. tostring(name) .. ' from ' .. armyName ..
            ' to ' .. waveArmy)
        return
    end

    -- The transfer returns NEW units, so they carry the stock command caps
    -- whatever the original had — the second of the two places a unit enters a
    -- wave army, and so the second place reclaim has to be taken off it. No
    -- experimental in the roster has the capability today; this is here so the
    -- rule holds for the unit that arrives by this path rather than by a spawn.
    WaveSpawner.SuppressReclaim(newUnits)

    -- March it now rather than leaving it to WaveSpawner's idle watchdog, which
    -- would take up to ten seconds to notice a new idle unit in the wave army.
    WaveSpawner.MarchUnits(armyName, lane, newUnits)
    Config.Log('experimental ' .. tostring(name) .. ' completed for ' .. armyName ..
        ', transferred to ' .. waveArmy .. ' in lane ' .. tostring(lane))
    Config.PrintTextForSide(Config.PlayerArmies[armyName].side,
        GetArmyBrain(armyName).Nickname .. "'s experimental has joined lane " ..
        tostring(lane) .. '!', 16, 'ffFFD700', 6, 'center')
end

-- Sweep one army for finished experimentals sitting in the player's own hands.
--
-- Sorted by the cached .EntityId before transferring: each transfer destroys a
-- unit and creates a replacement, so the order two experimentals completing on
-- the same tick are processed in decides which entity id each new unit gets —
-- sim state, and a raw traversal of a list built from an engine query is not
-- guaranteed to match across clients. Same rule as FactoryQueue.SortedFactories.
local function SweepCompleted(armyName)
    local cat = ExperimentalCategory()
    if not cat then
        return
    end
    local done = {}
    for i, u in GetArmyBrain(armyName):GetListOfUnits(cat, false) do
        if not u.Dead and u:GetFractionComplete() == 1 then
            table.insert(done, u)
        end
    end
    if table.getn(done) == 0 then
        return
    end
    table.sort(done, function(a, b) return a.EntityId < b.EntityId end)
    for i, u in done do
        Handover(armyName, u)
    end
end

-- `gated` is false when Config.ExperimentalsScriptTierGate is off: nothing was
-- restricted at start, so every army begins unlocked and the loop is purely the
-- completion sweep (the engine's own build menu is then the only tier gate).
local function ExperimentalLoop(gated)
    local LW = ScenarioInfo.LW
    local unlocked = {}   -- armyName -> true once its tier-3 restriction is lifted
    while not LW.GameOver do
        for i, armyName in LW.ActivePlayers do
            if not LW.Dead[armyName] then
                if gated and not unlocked[armyName] then
                    if HasTech3(armyName) then
                        unlocked[armyName] = true
                        ScenarioFramework.RemoveRestriction(armyName, ExperimentalCategory())
                        Config.PrintTextFor(armyName, 'Tech 3 reached - experimentals unlocked!',
                            18, 'ffFFD700', 8, 'center')
                        Config.Log(armyName .. ' reached tech 3; experimentals unlocked')
                    end
                else
                    SweepCompleted(armyName)
                end
            end
        end
        WaitSeconds(Config.ExperimentalTickSeconds)
    end
end

function Start()
    local cat = ExperimentalCategory()
    if not cat then
        WARN('LineWars: Experimentals found no units to manage')
        return
    end
    local gated = Config.ExperimentalsScriptTierGate
    if gated then
        for i, armyName in ScenarioInfo.LW.ActivePlayers do
            ScenarioFramework.AddRestriction(armyName, cat)
        end
        Config.Log('experimentals restricted until the ACU has ' .. ENHANCEMENT)
    else
        Config.Log('experimental tier gate left to the engine (script gate off)')
    end
    ForkThread(ExperimentalLoop, gated)
end
