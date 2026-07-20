-- ACU quality-of-life and fair-play rules:
--  * faster build rate and movement (this mode is about spawners; the ACU
--    shouldn't spend the round walking — see Config.Acu* multipliers)
--  * no-build zones: structures placed inside a zone are refunded and
--    removed, so lanes cannot be walled off. Zones are axis-aligned
--    rectangles between marker pairs LW_NoBuild<i>_A / LW_NoBuild<i>_B
--    (opposite corners, any number of zones, numbered from 1).
--  * midline rule: an ACU that crosses its lane's halfway line (closer to
--    the enemy Core marker than its own) is warped back in front of its
--    Core, so you cannot rush the enemy with your commander.
local ScenarioUtils = import('/lua/sim/ScenarioUtilities.lua')
local Buff = import('/lua/sim/Buff.lua')
local DIR = ScenarioInfo.directory or '/maps/LineWars-2p.v0001/'
local Config = import(DIR .. 'lib/Config.lua')

BuffBlueprint {
    Name = 'LineWarsAcu',
    DisplayName = 'LineWarsAcu',
    BuffType = 'LINEWARSACU',
    Stacks = 'REPLACE',
    Duration = -1,
    Affects = {
        BuildRate = { Add = 0, Mult = Config.AcuBuildRateMult },
        MoveMult = { Add = 0, Mult = Config.AcuMoveSpeedMult },
    },
}

local zones = nil   -- lazily built list of {x0, x1, z0, z1}

local function NoBuildZones()
    if zones then
        return zones
    end
    zones = {}
    local i = 1
    while true do
        local a = Config.GetMarker(Config.NoBuildMarker(i, 'A'))
        local b = Config.GetMarker(Config.NoBuildMarker(i, 'B'))
        if not (a and b) then
            break
        end
        table.insert(zones, {
            x0 = math.min(a.position[1], b.position[1]),
            x1 = math.max(a.position[1], b.position[1]),
            z0 = math.min(a.position[3], b.position[3]),
            z1 = math.max(a.position[3], b.position[3]),
        })
        i = i + 1
    end
    Config.Log('no-build zones found: ' .. table.getn(zones))
    return zones
end

local function InZone(z, pos)
    return pos[1] >= z.x0 and pos[1] <= z.x1 and pos[3] >= z.z0 and pos[3] <= z.z1
end

-- Remove this army's structures inside no-build zones, refunding what was
-- actually invested so a misclick isn't a death sentence.
local function EnforceNoBuild(armyName)
    if table.getn(NoBuildZones()) == 0 then
        return
    end
    local LW = ScenarioInfo.LW
    local brain = GetArmyBrain(armyName)
    for i, s in brain:GetListOfUnits(categories.STRUCTURE, false) do
        if not s.Dead and s ~= LW.Cores[armyName] then
            local pos = s:GetPosition()
            for j, z in NoBuildZones() do
                if InZone(z, pos) then
                    local eco = s:GetBlueprint().Economy
                    local frac = s:GetFractionComplete()
                    brain:GiveResource('Mass', (eco.BuildCostMass or 0) * frac)
                    brain:GiveResource('Energy', (eco.BuildCostEnergy or 0) * frac)
                    s:Destroy()
                    PrintText('No building in the lane!', 14, 'ffff2222', 4, 'center')
                    break
                end
            end
        end
    end
end

local function EnforceMidline(armyName, acu)
    local info = Config.PlayerArmies[armyName]
    local own = ScenarioUtils.MarkerToPosition(Config.CoreMarker(info.lane, info.side))
    local enemy = ScenarioUtils.MarkerToPosition(Config.CoreMarker(info.lane, Config.OppositeSide[info.side]))
    local p = acu:GetPosition()
    if VDist2(p[1], p[3], enemy[1], enemy[3]) < VDist2(p[1], p[3], own[1], own[3]) then
        -- land a little in front of the Core, not on top of it
        local dx, dz = enemy[1] - own[1], enemy[3] - own[3]
        local len = VDist2(0, 0, dx, dz)
        local x = own[1] + dx / len * Config.MidlineReturnOffset
        local z = own[3] + dz / len * Config.MidlineReturnOffset
        Warp(acu, { x, GetTerrainHeight(x, z), z })
        PrintText(GetArmyBrain(armyName).Nickname .. "'s ACU crossed the midline and was sent home!",
            14, 'ffff2222', 4, 'center')
    end
end

local function RulesLoop()
    local LW = ScenarioInfo.LW
    local buffed = {}   -- keyed by unit object so a rebuilt ACU is buffed again
    while not LW.GameOver do
        for i, armyName in LW.ActivePlayers do
            if not LW.Dead[armyName] then
                for j, acu in GetArmyBrain(armyName):GetListOfUnits(categories.COMMAND, false) do
                    if not acu.Dead then
                        if not buffed[acu] then
                            Buff.ApplyBuff(acu, 'LineWarsAcu')
                            buffed[acu] = true
                        end
                        EnforceMidline(armyName, acu)
                    end
                end
                EnforceNoBuild(armyName)
            end
        end
        WaitSeconds(Config.AcuRulesTickSeconds)
    end
end

function Start()
    ForkThread(RulesLoop)
end
