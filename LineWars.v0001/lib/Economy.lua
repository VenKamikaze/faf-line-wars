-- Income loop. Two models, chosen in the lobby:
--   1 (default): base income + each spawner structure adds its income value
--   2: flat income for everyone, growing every round
local DIR = ScenarioInfo.directory or '/maps/LineWars.v0001/'
local Config = import(DIR .. 'lib/Config.lua')
local SpawnerTypes = import(DIR .. 'lib/SpawnerTypes.lua')

local function SpawnerIncomeFor(brain)
    local income = 0
    local structures = brain:GetListOfUnits(categories.STRUCTURE, false)
    for i, s in structures do
        if not s.Dead and s:GetFractionComplete() == 1 then
            local def = SpawnerTypes.Spawners[s:GetUnitId()]
            if def then
                income = income + def.income
            end
        end
    end
    return income
end

local function MassIncomeFor(brain, round)
    if Config.GetIncomeModel() == 2 then
        return Config.BaseMassIncome * (1 + Config.FlatIncomeGrowthPerRound * (round - 1))
    end
    return Config.BaseMassIncome + SpawnerIncomeFor(brain)
end

local function EconomyLoop()
    local LW = ScenarioInfo.LW
    local tick = Config.EconomyTickSeconds
    while not LW.GameOver do
        WaitSeconds(tick)
        for i, armyName in LW.ActivePlayers do
            if not LW.Dead[armyName] then
                local brain = GetArmyBrain(armyName)
                brain:GiveResource('Mass', MassIncomeFor(brain, LW.Round) * tick)
                brain:GiveResource('Energy', Config.BaseEnergyIncome * tick)
            end
        end
    end
end

function Start()
    for i, armyName in ScenarioInfo.LW.ActivePlayers do
        SetArmyEconomy(armyName, Config.StartingMass, Config.StartingEnergy)
    end
    ForkThread(EconomyLoop)
end
