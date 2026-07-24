-- Drives the round loop: timed build phase, countdown announcements, then
-- wave launch for every living player.
local DIR = ScenarioInfo.directory or '/maps/LineWars-2p.v0001/'
local Config = import(DIR .. 'lib/Config.lua')
local WaveSpawner = import(DIR .. 'lib/WaveSpawner.lua')
local CoreStorage = import(DIR .. 'lib/CoreStorage.lua')

local function Announce(text)
    PrintText(text, 20, 'ffFFD700', 8, 'center')
end

local function AnnounceMinor(text)
    PrintText(text, 14, 'ffffffff', 5, 'center')
end

local function RoundLoop()
    local LW = ScenarioInfo.LW
    WaitSeconds(Config.InitialGraceSeconds)
    while not LW.GameOver do
        local t = Config.GetRoundSeconds()
        -- Round 1 keeps the bare base cap (216); +100 storage starts at round 2,
        -- so the cap is 216 / 316 / 416 / ... at rounds 1 / 2 / 3 / ...
        if LW.Round > 1 then
            CoreStorage.GrantForRound(LW.Round)   -- +storage, before players bank
        end
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
                WaveSpawner.SpawnWaveForArmy(armyName)
            end
        end
        LW.Round = LW.Round + 1
    end
end

function Start()
    ForkThread(RoundLoop)
    WaveSpawner.StartIdleWatchdog()
end
