-- Cores, elimination, and victory. Each player gets a Core structure at their
-- lane's Core marker; when it dies that player is out. A side wins when every
-- player on the other side has been eliminated.
local ScenarioUtils = import('/lua/sim/ScenarioUtilities.lua')
local ScenarioFramework = import('/lua/ScenarioFramework.lua')
local VictoryLib = import('/lua/victory.lua')
local DIR = ScenarioInfo.directory or '/maps/LineWars-2p.v0001/'
local Config = import(DIR .. 'lib/Config.lua')
local CoreStorage = import(DIR .. 'lib/CoreStorage.lua')

local function ArmyOfCore(coreUnit)
    for armyName, core in ScenarioInfo.LW.Cores do
        if core == coreUnit then
            return armyName
        end
    end
    return nil
end

local function KillArmyUnits(armyName)
    local units = GetArmyBrain(armyName):GetListOfUnits(categories.ALLUNITS, false)
    for i, u in units do
        if not u.Dead then
            u:Kill()
        end
    end
end

local function CheckForVictory()
    local LW = ScenarioInfo.LW
    local alive = { A = {}, B = {} }
    for i, armyName in LW.ActivePlayers do
        if not LW.Dead[armyName] then
            table.insert(alive[Config.PlayerArmies[armyName].side], armyName)
        end
    end
    local winners = nil
    if table.getn(alive.A) == 0 and table.getn(alive.B) > 0 then
        winners = alive.B
    elseif table.getn(alive.B) == 0 and table.getn(alive.A) > 0 then
        winners = alive.A
    elseif table.getn(alive.A) == 0 and table.getn(alive.B) == 0 then
        winners = {}
    end
    if winners then
        LW.GameOver = true
        for i, armyName in winners do
            Config.Announce(GetArmyBrain(armyName).Nickname .. ' is victorious!', 24, 'ff00ff00', 15, 'center')
            GetArmyBrain(armyName):OnVictory()
        end
        ForkThread(function()
            WaitSeconds(5)
            VictoryLib.CallEndGame()
        end)
    end
end

local function OnCoreKilled(coreUnit)
    local LW = ScenarioInfo.LW
    local armyName = ArmyOfCore(coreUnit)
    if not armyName or LW.Dead[armyName] then
        return
    end
    LW.Dead[armyName] = true
    local info = Config.PlayerArmies[armyName]
    Config.Announce(GetArmyBrain(armyName).Nickname .. ' has lost lane ' .. info.lane .. '!', 20, 'ffff2222', 10, 'center')
    CoreStorage.CleanupFor(armyName)   -- remove the hidden storage units stacked on the dead Core
    KillArmyUnits(Config.WaveArmyOf(armyName))
    KillArmyUnits(armyName)
    GetArmyBrain(armyName):OnDefeat()
    CheckForVictory()
end

function SpawnCores()
    local LW = ScenarioInfo.LW
    for i, armyName in LW.ActivePlayers do
        local info = Config.PlayerArmies[armyName]
        local markerName = Config.CoreMarker(info.lane, info.side)
        if not Config.GetMarker(markerName) then
            WARN('LineWars: missing Core marker ' .. markerName .. ' — no Core for ' .. armyName)
        else
            local pos = ScenarioUtils.MarkerToPosition(markerName)
            local core = CreateUnitHPR(Config.CoreBlueprint, armyName, pos[1], pos[2], pos[3], 0, 0, 0)
            local mult = Config.GetCoreHealthMultiplier()
            core:SetMaxHealth(core:GetMaxHealth() * mult)
            core:SetHealth(nil, core:GetMaxHealth())
            core:SetCapturable(false)
            core:SetReclaimable(false)
            LW.Cores[armyName] = core
            ScenarioFramework.CreateUnitDeathTrigger(OnCoreKilled, core)
        end
    end
    -- Dial the Cores down from the stock T3 pgen's flat 2500 e/s to what round 1
    -- is worth, before the start delay hands anyone free energy. RoundManager
    -- re-applies this at the top of every round.
    CoreStorage.ApplyCoreEnergy(ScenarioInfo.LW.Round)
end
