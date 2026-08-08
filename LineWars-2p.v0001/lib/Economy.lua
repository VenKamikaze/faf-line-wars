-- Income loop. Every player earns the same script-granted income: a flat base
-- rate for mass and energy alike, scaled by the periodic growth multiplier (the
-- "Income growth interval"/"Income growth step" lobby options).
--
-- There used to be an "Income model" lobby option choosing between this and a
-- +25%-of-base-per-round mass ramp. It was removed: the growth options above
-- reproduce that ramp (interval 1, step 25%) and the other model's spawner term
-- had been dead since spawner structures were replaced by the factory queue.
local DIR = ScenarioInfo.directory or '/maps/LineWars-2p.v0001/'
local Config = import(DIR .. 'lib/Config.lua')

local function MassIncomeFor(round)
    return Config.BaseMassIncome * Config.IncomeGrowthMultiplier(round)
end

local function EnergyIncomeFor(round)
    return Config.BaseEnergyIncome * Config.IncomeGrowthMultiplier(round)
end

local function EconomyLoop()
    local LW = ScenarioInfo.LW
    local tick = Config.EconomyTickSeconds
    local logged = nil   -- last round whose income was logged
    while not LW.GameOver do
        WaitSeconds(tick)
        local mass = MassIncomeFor(LW.Round)
        local energy = EnergyIncomeFor(LW.Round)
        if logged ~= LW.Round then
            logged = LW.Round
            Config.Log('round ' .. LW.Round .. ' income multiplier x' ..
                Config.IncomeGrowthMultiplier(LW.Round) ..
                ' (mass ' .. mass .. '/s, energy ' .. energy .. '/s)')
        end
        for i, armyName in LW.ActivePlayers do
            if not LW.Dead[armyName] then
                local brain = GetArmyBrain(armyName)
                brain:GiveResource('Mass', mass * tick)
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
