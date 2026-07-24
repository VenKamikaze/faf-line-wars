-- Spawns each player's waves at round end and sends them marching down a lane.
--
-- A player has one wave per lane they own a factory in — normally just their own
-- lane, but a factory built in a teammate's lane spawns its wave THERE (see
-- FactoryQueue.LaneForPosition). Reinforcements still belong to the builder's own
-- ARMY_WAVE_n, which is allied to that whole side, so they fight alongside the
-- teammate's wave rather than beside it.
local ScenarioUtils = import('/lua/sim/ScenarioUtilities.lua')
local DIR = ScenarioInfo.directory or '/maps/LineWars-2p.v0001/'
local Config = import(DIR .. 'lib/Config.lua')
local FactoryQueue = import(DIR .. 'lib/FactoryQueue.lua')

-- The lane-grouped standing wave this army's factories will spawn this round
-- (committed and already paid for): { { lane = n, units = { bp, ... } }, ... }.
function RollWaves(armyName)
    return FactoryQueue.WavesForArmy(armyName)
end

-- Pre-placed lane defences (the tower groups authored into each ARMY_WAVE_n in
-- _save.lua) are held in a group named LANE_TOWERS rather than the reserved
-- INITIAL group, so the engine does NOT auto-spawn them at map load (only INITIAL
-- groups are created by InitializeArmies). Instead we spawn each lane's towers
-- ourselves here, only for players actually in the game — so an empty lobby slot
-- never sprouts unmanned defences. Called once at start. The towers keep the
-- position/orientation authored in the editor (CreateArmyGroup reads them from
-- the save tree) and belong to the builder's ARMY_WAVE_n, so they take that
-- side's colour and are allied to the whole side.
local TOWER_GROUP = 'LANE_TOWERS'

function SpawnLaneTowers()
    for i, armyName in ScenarioInfo.LW.ActivePlayers do
        local waveArmy = Config.WaveArmyOf(armyName)
        -- Guard: only spawn if this wave army actually has a tower group in the
        -- save (FindUnitGroup returns nil otherwise; CreateArmyGroup tolerates a
        -- missing INITIAL but errors on any other missing named group).
        if ScenarioUtils.FindUnitGroup(TOWER_GROUP, Scenario.Armies[waveArmy].Units) then
            local units = ScenarioUtils.CreateArmyGroup(waveArmy, TOWER_GROUP)
            Config.Log('spawned ' .. table.getn(units or {}) .. ' lane tower(s) for ' ..
                armyName .. ' (' .. waveArmy .. ')')
        end
    end
end

-- The ordered list of positions a wave marching down this lane from this side
-- passes through: optional waypoints, then the enemy Core (or the enemy Core
-- marker if the opposing slot is empty).
local function GetMarchPath(lane, side)
    local path = {}
    local n = 1
    while Config.GetMarker(Config.WaypointMarker(lane, side, n)) do
        table.insert(path, ScenarioUtils.MarkerToPosition(Config.WaypointMarker(lane, side, n)))
        n = n + 1
    end
    local enemySide = Config.OppositeSide[side]
    local enemyArmy = Config.ArmyInLane(lane, enemySide)
    local enemyCore = enemyArmy and ScenarioInfo.LW.Cores[enemyArmy]
    if enemyCore and not enemyCore.Dead then
        table.insert(path, enemyCore:GetPosition())
    else
        table.insert(path, ScenarioUtils.MarkerToPosition(Config.CoreMarker(lane, enemySide)))
    end
    return path
end

-- Spawn one wave: `units` blueprints at this lane's spawn marker, marching down
-- it. The wave belongs to the builder, not to whoever holds the lane.
local function SpawnWave(armyName, lane, toSpawn)
    local side = Config.PlayerArmies[armyName].side
    local marker = ScenarioUtils.MarkerToPosition(Config.SpawnMarker(lane, side))
    local waveArmyName = Config.WaveArmyOf(armyName)
    local r = Config.SpawnSpreadRadius

    local units = {}
    for i, bp in toSpawn do
        local unit = CreateUnitHPR(bp, waveArmyName,
            marker[1] + Random(-r, r), marker[2], marker[3] + Random(-r, r),
            0, 0, 0)
        if unit then
            table.insert(units, unit)
        else
            WARN('LineWars: failed to spawn ' .. bp .. ' for ' .. waveArmyName)
        end
    end
    Config.Log('spawned ' .. table.getn(units) .. ' units for ' .. armyName ..
        ' in lane ' .. lane)
    if table.getn(units) == 0 then
        return
    end

    local waveBrain = GetArmyBrain(waveArmyName)
    local platoon = waveBrain:MakePlatoon('', '')
    waveBrain:AssignUnitsToPlatoon(platoon, units, 'Attack', 'GrowthFormation')
    for i, pos in GetMarchPath(lane, side) do
        platoon:AggressiveMoveToLocation(pos)
    end
end

function SpawnWaveForArmy(armyName)
    local waves = RollWaves(armyName)
    if table.getn(waves) == 0 then
        Config.Log(armyName .. ' has nothing queued; skipping wave')
        return
    end
    for i, wave in waves do
        if table.getn(wave.units) > 0 then
            SpawnWave(armyName, wave.lane, wave.units)
        end
    end
end

-- Safety net: waves can end up idle (orders completed while enemies remain,
-- pathing hiccups). Re-issue march orders to any idle wave unit periodically.
-- Idle units are re-pathed down the lane they are standing in, so a wave sent to
-- reinforce a teammate keeps fighting there rather than being dragged home.
function StartIdleWatchdog()
    ForkThread(function()
        local LW = ScenarioInfo.LW
        while not LW.GameOver do
            WaitSeconds(10)
            for i, armyName in LW.ActivePlayers do
                if not LW.Dead[armyName] then
                    local side = Config.PlayerArmies[armyName].side
                    local waveBrain = GetArmyBrain(Config.WaveArmyOf(armyName))
                    -- Group the idle units by the lane they are currently in, so
                    -- each gets the right march path.
                    -- Exclude STRUCTURE so the pre-placed lane towers (which are
                    -- always "idle") are never dragged into a march platoon.
                    local idleByLane = {}
                    for j, u in waveBrain:GetListOfUnits(categories.ALLUNITS - categories.STRUCTURE, false) do
                        if not u.Dead and u:IsIdleState() then
                            local lane = FactoryQueue.LaneForPosition(armyName, u:GetPosition())
                            idleByLane[lane] = idleByLane[lane] or {}
                            table.insert(idleByLane[lane], u)
                        end
                    end
                    for lane, idle in idleByLane do
                        local platoon = waveBrain:MakePlatoon('', '')
                        waveBrain:AssignUnitsToPlatoon(platoon, idle, 'Attack', 'GrowthFormation')
                        for j, pos in GetMarchPath(lane, side) do
                            platoon:AggressiveMoveToLocation(pos)
                        end
                    end
                end
            end
        end
    end)
end
