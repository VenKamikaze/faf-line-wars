-- Drives the round loop: timed build phase, countdown announcements, then
-- wave launch for every living player.
local DIR = ScenarioInfo.directory or '/maps/LineWars-2p.v0001/'
local Config = import(DIR .. 'lib/Config.lua')
local WaveSpawner = import(DIR .. 'lib/WaveSpawner.lua')
local CoreStorage = import(DIR .. 'lib/CoreStorage.lua')

-- Config.Announce, not PrintText: nothing may reach the screen before the UI
-- exists, or PrintText is dead for the rest of the session (see the gate in
-- lib/Config.lua).
local function Announce(text)
    Config.Announce(text, 20, 'ffFFD700', 8, 'center')
end

local function AnnounceMinor(text)
    Config.Announce(text, 14, 'ffffffff', 5, 'center')
end

local function RoundLoop()
    local LW = ScenarioInfo.LW
    -- "Map start delay" lobby option: hold the build rounds until the grace
    -- period elapses so players can settle in / position the ACU first.
    local startDelay = Config.GetStartDelaySeconds()
    if startDelay > 0 then
        -- Hold the notice until the screen can actually show it, then quote the
        -- time that is genuinely left — a queued "starts in 10 seconds" flushed
        -- at the 10-second mark would be a lie.
        local gate = Config.HudStartDelaySeconds
        if startDelay > gate then
            WaitSeconds(gate)
            AnnounceMinor('Game starts in ' .. (startDelay - gate) ..
                ' seconds - position your ACU')
            WaitSeconds(startDelay - gate)
        else
            WaitSeconds(startDelay)
        end
    end
    while not LW.GameOver do
        local t = Config.GetRoundSeconds()
        -- Round 1 keeps the bare base cap (216); +100 storage starts at round 2,
        -- so the cap is 216 / 316 / 416 / ... at rounds 1 / 2 / 3 / ...
        if LW.Round > 1 then
            CoreStorage.GrantForRound(LW.Round)   -- +storage, before players bank
        end
        -- Core energy output ramps with the round (WinCondition.SpawnCores set
        -- the round-1 value); re-applied every round, and after round 1 also
        -- catches a Core that was rebuilt or a player who joined the ramp late.
        CoreStorage.ApplyCoreEnergy(LW.Round)
        Announce('Round ' .. LW.Round .. ' — build phase (' .. t .. 's)')
        if t > 30 then
            WaitSeconds(t - 30)
            AnnounceMinor('30 seconds until the wave!')
            WaitSeconds(20)
        else
            WaitSeconds(t - 10)
        end
        AnnounceMinor('10 seconds!')
        WaitSeconds(10)
        if LW.GameOver then
            break
        end
        Announce('Wave ' .. LW.Round .. ' incoming!')
        for i, armyName in LW.ActivePlayers do
            if not LW.Dead[armyName] then
                -- THIS THREAD IS THE GAME. If it throws it is gone — there is no
                -- restart, no more rounds, no more waves, and no error on screen;
                -- FactoryQueue carries on charging players for waves that will
                -- never arrive. That is exactly what happened in game 27565454:
                -- one CreateUnitHPR refusal inside a wave spawn at round 26
                -- unwound through here and the match froze for its last six
                -- minutes. pcall is Lua's try/catch — it runs the call in
                -- protected mode and hands back ok=false plus the error message
                -- instead of propagating. Per army, so one player's failure costs
                -- that player their wave and nobody else theirs.
                --
                -- Nothing under SpawnWaveForArmy may WaitSeconds: this Lua cannot
                -- yield across a pcall boundary. It doesn't today, and the
                -- comments in WaveSpawner say so.
                local ok, err = pcall(WaveSpawner.SpawnWaveForArmy, armyName)
                if not ok then
                    WARN('LineWars: wave spawn for ' .. armyName .. ' failed: ' ..
                        tostring(err))
                end
            end
        end
        -- Diagnostic for the cap theory above, printed after the spawn so it
        -- shows the round's peak. See WaveSpawner.LogWaveArmyUnitCaps. Guarded
        -- for the same reason as everything else in this loop, and doubly so
        -- because a diagnostic that ends the game would be a poor trade.
        pcall(WaveSpawner.LogWaveArmyUnitCaps)
        LW.Round = LW.Round + 1
    end
end

function Start()
    ForkThread(RoundLoop)
    WaveSpawner.StartIdleWatchdog()
end
