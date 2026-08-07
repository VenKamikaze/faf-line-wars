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
local AirGate = import(DIR .. 'lib/AirGate.lua')
local Experimentals = import(DIR .. 'lib/Experimentals.lua')
local WaveSpawner = import(DIR .. 'lib/WaveSpawner.lua')
local CapturePoints = import(DIR .. 'lib/CapturePoints.lua')
local ChatCommands = import(DIR .. 'lib/ChatCommands.lua')
local Sos = import(DIR .. 'lib/Sos.lua')
local Hud = import(DIR .. 'lib/Hud.lua')

function OnPopulate()
    ScenarioUtils.InitializeArmies()
end

function OnStart(self)
    -- The script owns win/loss; disable the standard skirmish conditions.
    ScenarioInfo.Options.Victory = 'sandbox'

    -- The .scmap heightmap is 512x512, but play is confined to the 512x256 band
    -- (AREA_1 = RECTANGLE(0,128,512,384)). Without this, players and AI can build
    -- in the black void above/below the lanes. voFlag=false skips the expansion
    -- camera pan + "map expansion" voiceover. All lane/Core/spawn markers sit
    -- inside this rectangle.
    ScenarioFramework.SetPlayableArea('AREA_1', false)

    -- Shared game state, reachable from every module.
    ScenarioInfo.LW = {
        Round = 1,
        GameOver = false,
        ActivePlayers = {},  -- player armies actually present in the lobby
        Dead = {},           -- armyName -> true once eliminated
        Cores = {},          -- armyName -> Core unit
    }
    local LW = ScenarioInfo.LW

    -- Opens the PrintText gate a few seconds in. Must come before anything that
    -- prints: the very first PrintText a map sends loads the UI's textdisplay
    -- module, and if it does that before the UI exists, on-screen text is dead
    -- for the whole session. See lib/Config.lua.
    Config.StartHudGate()

    for i, armyName in ListArmies() do
        if Config.PlayerArmies[armyName] then
            table.insert(LW.ActivePlayers, armyName)
        end
    end
    Config.Log('active players: ' .. table.getn(LW.ActivePlayers))

    -- Pre-placed lane towers live in each ARMY_WAVE_n's LANE_TOWERS group, which
    -- the engine does NOT auto-spawn (only INITIAL groups are). Spawn them here,
    -- only for players actually in the game, so an empty lane has no defences.
    WaveSpawner.SpawnLaneTowers()

    -- Alliances are dictated by start position (lane pairing), overriding
    -- lobby team settings: same side = allies, opposite side = enemies.
    -- The Core and the Core-storage buildings must be in the allowed set: the
    -- restriction system destroys script-spawned units too. FactoryQueue's
    -- allowed set covers ACU + the land/air factories + the wave units.
    --
    -- BE CAREFUL WHAT YOU ADD HERE: an exemption granted so the script can spawn
    -- something also puts it in reach of the ACU, which is not an engineer and is
    -- not covered by "all engineers are restricted". That assumption was wrong
    -- and cost a game: ueb1301 (the Core) is BUILTBYTIER3COMMANDER + UEF, so a
    -- UEF player who finished T3Engineering could build a second one, paying a
    -- stock 2500 e/s against the 500 the Core is throttled to. The block is now
    -- in units/LineWars_units.bp, which strips the category rather than relying
    -- on this set — see the comment there.
    --
    -- THE SAME HOLE IS STILL OPEN FOR CoreStorage's buildings, deliberately,
    -- pending Kamikaze's call. ueb1106/ueb1105 (and the three faction pairs) carry
    -- BUILTBYTIER2COMMANDER, verified in units.nx2 2026-08-08, so any ACU past
    -- AdvancedEngineering can build them: 200 mass buys +100 mass cap and 250
    -- buys +500 energy cap, repeatable, which is the per-round storage grant on
    -- demand — and storage, not income, is what gates T3. Two ways out: strip
    -- the category as ueb1301 now does, or reprice them and call it a feature.
    local allowed = FactoryQueue.AllowedCategories() + categories[Config.CoreBlueprint]
                    + CoreStorage.AllowedCategories() + Experimentals.AllowedCategories()
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
    AirGate.Start()        -- locks air until the chosen round; must follow the restriction loop
    Experimentals.Start()  -- locks the ACU's experimental until it has tech 3; likewise
    Economy.Start()
    CapturePoints.Start()  -- lane capture points: land units capture, income to the side

    ChatCommands.Start()   -- hooks chat into the sim; must precede any Register
    Sos.Start()            -- registers /sos and hands out its one charge each
    Hud.Start()            -- how-to-play card + the repeating scoreboard

    RoundManager.Start()
    AcuRules.Start()
end
