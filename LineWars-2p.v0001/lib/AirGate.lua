-- "Allow air units from round" lobby option (Config.GetAirFromRound).
--
-- Until the chosen round, air factories AND air units are build-restricted for
-- every player, using the same AddRestriction/RemoveRestriction pattern the King
-- of the Hill mod uses to phase in tech tiers (sim-restrictions.lua). This gates
-- the ACU/factory BUILD MENU — the clean option — rather than deactivating the
-- queue, so a player simply cannot place the air factory or queue a bomber yet.
--
-- Restricting the air factory alone would suffice (no factory => no air queue),
-- but we restrict the units too so the rule is explicit and a stray or gifted
-- air factory still can't produce.
--
-- The air category is added ON TOP of the script's `ALLUNITS - allowed`
-- restriction (air sits inside `allowed`, so nothing else touches it); removing
-- it at the target round hands air back cleanly.
local DIR = ScenarioInfo.directory or '/maps/LineWars-2p.v0001/'
local Config = import(DIR .. 'lib/Config.lua')
local UnitTypes = import(DIR .. 'lib/UnitTypes.lua')
local ScenarioFramework = import('/lua/ScenarioFramework.lua')

-- Category union of the air factories plus the units they build, built once.
local airCategory
local airCategoryBuilt = false
local function AirCategory()
    if airCategoryBuilt then
        return airCategory
    end
    airCategoryBuilt = true
    local function add(bp)
        if categories[bp] then
            airCategory = airCategory and (airCategory + categories[bp]) or categories[bp]
        else
            WARN('LineWars: AirGate no category for ' .. tostring(bp))
        end
    end
    for i, bp in UnitTypes.AllFactoryIds() do
        if UnitTypes.KindOfFactory(bp) == 'AIR' then
            add(bp)
        end
    end
    for i, bp in UnitTypes.UnitIdsForKind('AIR') do
        add(bp)
    end
    return airCategory
end

-- Restrict air for every active player now, then (unless 'Never') lift it once
-- the round counter reaches the chosen round.
function Start()
    local LW = ScenarioInfo.LW
    local from = Config.GetAirFromRound()

    -- Immediate (0) or round 1: the first build phase is round 1, so there is
    -- nothing to lock — air is available from the outset.
    if from <= 1 then
        Config.Log('air available immediately')
        return
    end

    local cat = AirCategory()
    if not cat then
        WARN('LineWars: AirGate found no air units to gate')
        return
    end

    for i, armyName in LW.ActivePlayers do
        ScenarioFramework.AddRestriction(armyName, cat)
    end

    if from >= Config.AirNeverRound then
        Config.Log('air disabled for the whole game')
        return
    end
    Config.Log('air restricted until round ' .. from)

    ForkThread(function()
        while not LW.GameOver and LW.Round < from do
            WaitSeconds(1)
        end
        if LW.GameOver then
            return
        end
        for i, armyName in LW.ActivePlayers do
            ScenarioFramework.RemoveRestriction(armyName, cat)
        end
        -- Global event: the unlock is symmetric, so announce to everyone (same
        -- bare-PrintText convention RoundManager uses for round announcements).
        PrintText('Air units unlocked!', 20, 'ff66ccff', 6, 'center')
        Config.Log('air unlocked at round ' .. LW.Round)
    end)
end
