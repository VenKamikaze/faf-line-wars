-- Income loop. Two models, chosen in the lobby:
--   1 (default): base income + each spawner structure adds its income value
--   2: flat income for everyone, growing every round
local DIR = ScenarioInfo.directory or '/maps/LineWars-2p.v0001/'
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

-- Both models feed their BASE term through the periodic growth multiplier (the
-- "Income growth interval"/"Income growth step" lobby options). It is folded into
-- the same bracket as model 2's own per-round growth rather than multiplied over
-- the top of it, so the two curves ADD instead of compounding — one 50% step and
-- one 25% step is 175% of base, not 187.5%.
local function MassIncomeFor(brain, round)
    local growth = Config.IncomeGrowthMultiplier(round) - 1
    if Config.GetIncomeModel() == 2 then
        return Config.BaseMassIncome *
            (1 + Config.FlatIncomeGrowthPerRound * (round - 1) + growth)
    end
    return Config.BaseMassIncome * (1 + growth) + SpawnerIncomeFor(brain)
end

-- Energy has only the one curve, so it is the plain multiplier.
local function EnergyIncomeFor(round)
    return Config.BaseEnergyIncome * Config.IncomeGrowthMultiplier(round)
end

local function EconomyLoop()
    local LW = ScenarioInfo.LW
    local tick = Config.EconomyTickSeconds
    local logged = nil   -- last round whose income was logged
    while not LW.GameOver do
        WaitSeconds(tick)
        local energy = EnergyIncomeFor(LW.Round)
        if logged ~= LW.Round then
            logged = LW.Round
            Config.Log('round ' .. LW.Round .. ' income multiplier x' ..
                Config.IncomeGrowthMultiplier(LW.Round) .. ' (energy ' .. energy .. '/s)')
        end
        for i, armyName in LW.ActivePlayers do
            if not LW.Dead[armyName] then
                local brain = GetArmyBrain(armyName)
                brain:GiveResource('Mass', MassIncomeFor(brain, LW.Round) * tick)
                brain:GiveResource('Energy', energy * tick)
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
