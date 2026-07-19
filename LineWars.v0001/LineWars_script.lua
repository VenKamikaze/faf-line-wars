-- Line Wars — main map script.
-- Timed rounds: build spawner structures during the build phase; at round end
-- every spawner produces its units, which march down the lane attack-moving.
-- Each lane is a mirrored 1v1. Lose your Core, lose your lane.
--
-- Mechanics live in lib/ — this file only wires up armies and starts the loops.
local ScenarioUtils = import('/lua/sim/ScenarioUtilities.lua')
local ScenarioFramework = import('/lua/ScenarioFramework.lua')
local DIR = ScenarioInfo.directory or '/maps/LineWars.v0001/'
local Config = import(DIR .. 'lib/Config.lua')
local SpawnerTypes = import(DIR .. 'lib/SpawnerTypes.lua')
local Economy = import(DIR .. 'lib/Economy.lua')
local RoundManager = import(DIR .. 'lib/RoundManager.lua')
local WinCondition = import(DIR .. 'lib/WinCondition.lua')

function OnPopulate()
    ScenarioUtils.InitializeArmies()
end

function OnStart(self)
    -- The script owns win/loss; disable the standard skirmish conditions.
    ScenarioInfo.Options.Victory = 'sandbox'

    -- Shared game state, reachable from every module.
    ScenarioInfo.LW = {
        Round = 1,
        GameOver = false,
        ActivePlayers = {},  -- player armies actually present in the lobby
        Dead = {},           -- armyName -> true once eliminated
        Cores = {},          -- armyName -> Core unit
    }
    local LW = ScenarioInfo.LW

    for i, armyName in ListArmies() do
        if Config.PlayerArmies[armyName] then
            table.insert(LW.ActivePlayers, armyName)
        end
    end
    Config.Log('active players: ' .. table.getn(LW.ActivePlayers))

    -- Alliances are dictated by start position (lane pairing), overriding
    -- lobby team settings: same side = allies, opposite side = enemies.
    local allowed = SpawnerTypes.AllowedCategories()
    for i, armyName in LW.ActivePlayers do
        local brain = GetArmyBrain(armyName)
        local mySide = Config.PlayerArmies[armyName].side
        local myWave = Config.WaveArmyOf(armyName)
        brain:SetResourceSharing(false)
        SetAlliedVictory(armyName, true)
        SetAlliance(armyName, myWave, 'Ally')
        ScenarioFramework.AddRestriction(armyName, categories.ALLUNITS - allowed)
        for j, otherName in LW.ActivePlayers do
            if otherName ~= armyName then
                local state = 'Enemy'
                if Config.PlayerArmies[otherName].side == mySide then
                    state = 'Ally'
                end
                SetAlliance(armyName, otherName, state)
                SetAlliance(armyName, Config.WaveArmyOf(otherName), state)
                SetAlliance(myWave, Config.WaveArmyOf(otherName), state)
            end
        end
    end

    WinCondition.SpawnCores()
    Economy.Start()
    RoundManager.Start()
end
