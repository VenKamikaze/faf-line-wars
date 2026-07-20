-- Spawns each player's wave at round end and sends it marching down the lane.
local ScenarioUtils = import('/lua/sim/ScenarioUtilities.lua')
local DIR = ScenarioInfo.directory or '/maps/LineWars-2p.v0001/'
local Config = import(DIR .. 'lib/Config.lua')
local SpawnerTypes = import(DIR .. 'lib/SpawnerTypes.lua')

-- Returns the list of unit blueprints this army's completed spawners produce.
function RollWave(armyName)
    local brain = GetArmyBrain(armyName)
    local toSpawn = {}
    local structures = brain:GetListOfUnits(categories.STRUCTURE, false)
    for i, s in structures do
        if not s.Dead and s:GetFractionComplete() == 1 then
            local def = SpawnerTypes.Spawners[s:GetUnitId()]
            if def then
                for j, entry in def.spawns do
                    for n = 1, entry[2] do
                        table.insert(toSpawn, entry[1])
                    end
                end
            end
        end
    end
    return toSpawn
end

-- The ordered list of positions a wave from this army marches through:
-- optional own-side waypoints, then the enemy Core (or the enemy Core marker
-- if the opposing slot is empty).
local function GetMarchPath(armyName)
    local info = Config.PlayerArmies[armyName]
    local path = {}
    local n = 1
    while Config.GetMarker(Config.WaypointMarker(info.lane, info.side, n)) do
        table.insert(path, ScenarioUtils.MarkerToPosition(Config.WaypointMarker(info.lane, info.side, n)))
        n = n + 1
    end
    local enemySide = Config.OppositeSide[info.side]
    local enemyArmy = Config.EnemyOf(armyName)
    local enemyCore = enemyArmy and ScenarioInfo.LW.Cores[enemyArmy]
    if enemyCore and not enemyCore.Dead then
        table.insert(path, enemyCore:GetPosition())
    else
        table.insert(path, ScenarioUtils.MarkerToPosition(Config.CoreMarker(info.lane, enemySide)))
    end
    return path
end

function SpawnWaveForArmy(armyName)
    local toSpawn = RollWave(armyName)
    if table.getn(toSpawn) == 0 then
        Config.Log(armyName .. ' has no spawners; skipping wave')
        return
    end

    local info = Config.PlayerArmies[armyName]
    local marker = ScenarioUtils.MarkerToPosition(Config.SpawnMarker(info.lane, info.side))
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
    Config.Log('spawned ' .. table.getn(units) .. ' units for ' .. armyName)
    if table.getn(units) == 0 then
        return
    end

    local waveBrain = GetArmyBrain(waveArmyName)
    local platoon = waveBrain:MakePlatoon('', '')
    waveBrain:AssignUnitsToPlatoon(platoon, units, 'Attack', 'GrowthFormation')
    for i, pos in GetMarchPath(armyName) do
        platoon:AggressiveMoveToLocation(pos)
    end
end

-- Safety net: waves can end up idle (orders completed while enemies remain,
-- pathing hiccups). Re-issue march orders to any idle wave unit periodically.
function StartIdleWatchdog()
    ForkThread(function()
        local LW = ScenarioInfo.LW
        while not LW.GameOver do
            WaitSeconds(10)
            for i, armyName in LW.ActivePlayers do
                if not LW.Dead[armyName] then
                    local waveBrain = GetArmyBrain(Config.WaveArmyOf(armyName))
                    local idle = {}
                    local waveUnits = waveBrain:GetListOfUnits(categories.ALLUNITS, false)
                    for j, u in waveUnits do
                        if not u.Dead and u:IsIdleState() then
                            table.insert(idle, u)
                        end
                    end
                    if table.getn(idle) > 0 then
                        local platoon = waveBrain:MakePlatoon('', '')
                        waveBrain:AssignUnitsToPlatoon(platoon, idle, 'Attack', 'GrowthFormation')
                        local path = GetMarchPath(armyName)
                        for j, pos in path do
                            platoon:AggressiveMoveToLocation(pos)
                        end
                    end
                end
            end
        end
    end)
end
