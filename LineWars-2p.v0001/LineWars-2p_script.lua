-- Line Wars — main map script.
-- Timed rounds: build factories and queue units during the build phase; at round
-- end every factory's standing queue spawns as a wave that marches down its lane
-- attack-moving. Each lane is a mirrored 1v1, but a factory built in a
-- teammate's lane reinforces that lane instead. Lose your Core, lose your lane.
--
-- Mechanics live in lib/ — this file only wires up armies and starts the loops.
local ScenarioUtils = import('/lua/sim/ScenarioUtilities.lua')
local ScenarioFramework = import('/lua/ScenarioFramework.lua')
local DIR = ScenarioInfo.directory or '/maps/LineWars-2p.v0001/'
local Config = import(DIR .. 'lib/Config.lua')
local Economy = import(DIR .. 'lib/Economy.lua')
local RoundManager = import(DIR .. 'lib/RoundManager.lua')
local WinCondition = import(DIR .. 'lib/WinCondition.lua')
local AcuRules = import(DIR .. 'lib/AcuRules.lua')
local FactoryQueue = import(DIR .. 'lib/FactoryQueue.lua')
local CoreStorage = import(DIR .. 'lib/CoreStorage.lua')

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
    -- The Core and the Core-storage buildings must be in the allowed set: the
    -- restriction system destroys script-spawned units too. Players still can't
    -- build the Core (T3, and all engineers are restricted). FactoryQueue's
    -- allowed set covers ACU + the land/air factories + the wave units.
    local allowed = FactoryQueue.AllowedCategories() + categories[Config.CoreBlueprint]
                    + CoreStorage.AllowedCategories()
    for i, armyName in LW.ActivePlayers do
        local brain = GetArmyBrain(armyName)
        local mySide = Config.PlayerArmies[armyName].side
        local myWave = Config.WaveArmyOf(armyName)
        brain:SetResourceSharing(false)
        SetAlliedVictory(armyName, true)
        SetAlliance(armyName, myWave, 'Ally')

        -- Wave armies only: one colour per side, so the tactical view reads as
        -- two sides pushing against each other. Players keep their lobby colours.
        local rgb = Config.SideColors[mySide]
        SetArmyColor(myWave, rgb[1], rgb[2], rgb[3])
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
    CoreStorage.Start()    -- inits LW.Storage; must follow SpawnCores, precede RoundManager
    FactoryQueue.Start()   -- starts the queue poll; players build their own factories
    Economy.Start()
    RoundManager.Start()
    AcuRules.Start()
end
