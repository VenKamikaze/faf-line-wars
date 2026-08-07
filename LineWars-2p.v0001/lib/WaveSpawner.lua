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

-- Take the reclaim ability off wave units.
--
-- Kamikaze saw an Aeon T3 Siege Assault Bot reclaiming mass wrecks in the last game
-- instead of fighting. It is the only unit in the whole roster that can: of the
-- 105 blueprint ids in UnitTypes (wave units, factories, ACU structures and
-- experimentals alike), `ual0303` — the Harbinger — is the single one with
-- `RULEUCC_Reclaim = true` and a BuildRate (5), checked against units.nx2 on
-- 2026-08-08. The other three factions' Siege Assault Bots have neither.
--
-- The sweep is deliberately blanket rather than an `if id == 'ual0303'`: it costs
-- one engine call per unit, and it keeps working when the roster gains a unit
-- with a build arm (SACUs and several experimentals have one). RemoveCommandCap
-- (sim/Unit.lua:5145) is safe on a unit that never had the cap — it clears a
-- table key and forwards to the engine.
--
-- This removes the ABILITY, so it does not matter who was issuing the order —
-- and that is worth stating plainly, because what prompts an unattended wave
-- unit to reclaim was never established. If reclaiming somehow survives this,
-- the answer is upstream of the capability and the next place to look is
-- whatever is giving the order, not this function.
--
-- Reclaim only. Assist and repair are left alone: Kamikaze asked for the commander
-- to be the only thing that reclaims, and the Harbinger's build arm doing
-- neither of the other two has never been a problem in play.
function SuppressReclaim(units)
    for i, u in units do
        if u and not u.Dead then
            u:RemoveCommandCap('RULEUCC_Reclaim')
        end
    end
end

-- Put `units` (already in armyName's wave army) into a platoon and send it down
-- `lane` from that player's side. Exported for lib/Experimentals.lua, which hands
-- a finished experimental to the wave army mid-round and wants it marching at
-- once rather than waiting up to ten seconds for the idle watchdog to find it.
function MarchUnits(armyName, lane, units)
    if not units or table.getn(units) == 0 then
        return
    end
    local side = Config.PlayerArmies[armyName].side
    local waveBrain = GetArmyBrain(Config.WaveArmyOf(armyName))
    local platoon = waveBrain:MakePlatoon('', '')
    waveBrain:AssignUnitsToPlatoon(platoon, units, 'Attack', 'GrowthFormation')
    for i, pos in GetMarchPath(lane, side) do
        platoon:AggressiveMoveToLocation(pos)
    end
end

-- Spawn one wave: `units` blueprints at this lane's spawn marker, marching down
-- it. The wave belongs to the builder, not to whoever holds the lane.
local function SpawnWave(armyName, lane, toSpawn)
    local side = Config.PlayerArmies[armyName].side
    local marker = ScenarioUtils.MarkerToPosition(Config.SpawnMarker(lane, side))
    local waveArmyName = Config.WaveArmyOf(armyName)
    local r = Config.SpawnSpreadRadius

    local units = {}
    local failed = 0
    for i, bp in toSpawn do
        -- pcall (= try/catch) because CreateUnitHPR THROWS on refusal rather than
        -- returning nil — the `if unit then ... else WARN` this replaced was dead
        -- code that never once fired. The engine refuses to create a unit once the
        -- owning army is at the lobby's per-army unit cap, which ARMY_WAVE_n
        -- eventually reaches: the queue is persistent, so every round re-spawns
        -- the whole standing wave and a lane with no opposing player accumulates
        -- units that nothing ever kills. In game 27565454 that throw at round 26
        -- unwound all the way into RoundManager's loop and ended the match.
        -- Catch it per unit so one refusal costs one unit, not the rest of the
        -- batch. The Random() draws sit in the argument list, so they are made
        -- exactly as before whether or not the call succeeds — the draw sequence
        -- (which is sim state) is unchanged by this guard.
        local ok, unit = pcall(CreateUnitHPR, bp, waveArmyName,
            marker[1] + Random(-r, r), marker[2], marker[3] + Random(-r, r),
            0, 0, 0)
        if ok and unit then
            table.insert(units, unit)
        else
            failed = failed + 1
        end
    end
    Config.Log('spawned ' .. table.getn(units) .. ' units for ' .. armyName ..
        ' in lane ' .. lane)
    if failed > 0 then
        -- One line, not one per unit: a late-game wave is well over a hundred
        -- units and a cap refusal fails every remaining one of them.
        WARN('LineWars: ' .. waveArmyName .. ' lane ' .. lane .. ': ' .. failed ..
            ' of ' .. table.getn(toSpawn) .. ' units failed to spawn — army unit ' ..
            'cap is the likely cause, see the wave-army unit counts logged each round')
    end
    if table.getn(units) == 0 then
        return
    end

    -- Once, here at creation, rather than inside MarchUnits — the idle watchdog
    -- calls that every ten seconds, and re-applying a unit mutation on a repeating
    -- tick is the shape of bug that cost us the hover panel (see CLAUDE.md).
    SuppressReclaim(units)
    MarchUnits(armyName, lane, units)
end

function SpawnWaveForArmy(armyName)
    local waves = RollWaves(armyName)
    if table.getn(waves) == 0 then
        Config.Log(armyName .. ' has nothing queued; skipping wave')
        return
    end
    for i, wave in waves do
        if table.getn(wave.units) > 0 then
            -- Per-lane try/catch, so a lane that cannot spawn does not cost this
            -- army its other lanes. SpawnWave's remaining throw sources are
            -- MarkerToPosition (which errors rather than returning nil on a
            -- missing marker — the reason Config.GetMarker exists) and the
            -- platoon/order calls in MarchUnits.
            local ok, err = pcall(SpawnWave, armyName, wave.lane, wave.units)
            if not ok then
                WARN('LineWars: wave spawn failed for ' .. armyName .. ' lane ' ..
                    tostring(wave.lane) .. ': ' .. tostring(err))
            end
        end
    end
end

-- Diagnostic, printed once per round: how close each wave army is to the engine's
-- per-army unit cap.
--
-- This exists because of the round-26 freeze in game 27565454, where a
-- CreateUnitHPR refusal is strongly believed to have been the cap (lobby setting
-- 1500) — but could not be proven from the log, since FAF's own JsonStats blob
-- reports human armies only and says nothing about an ExtraArmy like
-- ARMY_WAVE_2. These two numbers settle it either way in the next game: a
-- refusal logged by SpawnWave with the count sitting at the max is the cap, and
-- a refusal with plenty of headroom is something else entirely.
--
-- The stat names are the ones lua/sim/score.lua reads for the score screen.
local function ArmyStat(brain, name)
    local stat = brain:GetArmyStat(name, 0)
    return (stat and stat.Value) or -1
end

function LogWaveArmyUnitCaps()
    for i, armyName in ScenarioInfo.LW.ActivePlayers do
        local waveArmy = Config.WaveArmyOf(armyName)
        local brain = GetArmyBrain(waveArmy)
        Config.Log(waveArmy .. ' units ' .. ArmyStat(brain, 'UnitCap_Current') ..
            '/' .. ArmyStat(brain, 'UnitCap_MaxCap'))
    end
end

-- Safety net: waves can end up idle (orders completed while enemies remain,
-- pathing hiccups). Re-issue march orders to any idle wave unit periodically.
-- Idle units are re-pathed down the lane they are standing in, so a wave sent to
-- reinforce a teammate keeps fighting there rather than being dragged home.
local function RepathIdleUnits(armyName)
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
        MarchUnits(armyName, lane, idle)
    end
end

function StartIdleWatchdog()
    ForkThread(function()
        local LW = ScenarioInfo.LW
        while not LW.GameOver do
            WaitSeconds(10)
            for i, armyName in LW.ActivePlayers do
                if not LW.Dead[armyName] then
                    -- Same try/catch reasoning as the round loop: this thread is
                    -- the only thing that re-paths a stalled wave, it is never
                    -- restarted, and a moho call on a unit that died between the
                    -- Dead check and the call throws. One army must not cost the
                    -- other five their watchdog for the rest of the game.
                    --
                    -- WaitSeconds is deliberately OUTSIDE the pcall: this Lua
                    -- cannot yield across a pcall boundary, so anything called
                    -- from inside one must never wait. RepathIdleUnits does not.
                    local ok, err = pcall(RepathIdleUnits, armyName)
                    if not ok then
                        WARN('LineWars: idle watchdog failed for ' .. armyName ..
                            ': ' .. tostring(err))
                    end
                end
            end
        end
    end)
end
