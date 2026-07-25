-- ACU quality-of-life and fair-play rules:
--  * faster build rate and movement (this mode is about spawners; the ACU
--    shouldn't spend the round walking — see Config.Acu* multipliers)
--  * no-build zones: structures placed inside a zone are refunded and
--    removed, so lanes cannot be walled off. Zones are axis-aligned
--    rectangles between marker pairs LW_NoBuild<i>_A / LW_NoBuild<i>_B
--    (opposite corners, any number of zones, numbered from 1). EXCEPT the
--    five ACU-built defense structures (UnitTypes.AcuStructures — T1/T2 Point
--    Defense, T1/T2 AA, T2 Shield), which ARE allowed inside a zone: that's
--    how you hold a forward choke. They are still bound by the midline rule
--    below, checked on the structure's own position.
--  * midline rule: an ACU (or, for the five exempt structures above, the
--    structure itself) that crosses its lane's halfway line (closer to the
--    enemy Core marker than its own) is warped back / refunded and destroyed,
--    so you cannot rush the enemy with your commander or its defenses.
local ScenarioUtils = import('/lua/sim/ScenarioUtilities.lua')
local Buff = import('/lua/sim/Buff.lua')
local DIR = ScenarioInfo.directory or '/maps/LineWars-2p.v0001/'
local Config = import(DIR .. 'lib/Config.lua')
local UnitTypes = import(DIR .. 'lib/UnitTypes.lua')
local FactoryQueue = import(DIR .. 'lib/FactoryQueue.lua')

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

-- Core marker positions for `lane`, from armyName's own side: own-side Core
-- first, enemy-side Core second. A lookup, not logic — shared by EnforceMidline
-- (the ACU's own position) and the ACU-structure midline check in
-- EnforceNoBuild (a structure's position, possibly in a different, reinforced
-- lane — see FactoryQueue.LaneForPosition).
local function LaneCorePositions(armyName, lane)
    local info = Config.PlayerArmies[armyName]
    local own = ScenarioUtils.MarkerToPosition(Config.CoreMarker(lane, info.side))
    local enemy = ScenarioUtils.MarkerToPosition(Config.CoreMarker(lane, Config.OppositeSide[info.side]))
    return own, enemy
end

-- True if `pos` is at least as close to `own` Core as to `enemy` Core — the
-- "which side of the midline" test.
local function OwnSideOfMidline(own, enemy, pos)
    return VDist2(pos[1], pos[3], enemy[1], enemy[3]) >= VDist2(pos[1], pos[3], own[1], own[3])
end

-- Remove this army's structures inside no-build zones, refunding what was
-- actually invested so a misclick isn't a death sentence. Factories are NOT
-- exempt — players site their own now, and a factory is exactly the thing you'd
-- wall a lane with. FactoryQueue refunds the dead factory's paid queue too.
--
-- The five ACU-built defense structures (UnitTypes.AcuStructures) ARE exempt
-- from the no-build zone — that's the point, they're how you hold the choke —
-- but never past the midline of the lane they're actually sited in, checked on
-- the structure's OWN position (not the ACU's): the ACU's stock
-- MaxBuildDistance (10, confirmed in UEL0001_unit.bp) is small next to the
-- no-build corridor's width but not zero, so a structure can land past the
-- midline even while EnforceMidline keeps the ACU itself on its own side. This
-- runs a single pass over every STRUCTURE and covers both checks, because the
-- midline rule must hold everywhere a structure can be sited, not only inside
-- a zone (lanes without a NoBuild marker pair yet still need it enforced).
local function EnforceNoBuild(armyName)
    local LW = ScenarioInfo.LW
    local brain = GetArmyBrain(armyName)
    local hasZones = table.getn(NoBuildZones()) > 0
    for i, s in brain:GetListOfUnits(categories.STRUCTURE, false) do
        if not s.Dead and s ~= LW.Cores[armyName] and not s.LineWarsStorage then
            local pos = s:GetPosition()
            local isAcuStructure = UnitTypes.IsAcuStructure(s:GetUnitId())
            local reason

            if isAcuStructure then
                local lane = FactoryQueue.LaneForPosition(armyName, pos)
                local own, enemy = LaneCorePositions(armyName, lane)
                if not OwnSideOfMidline(own, enemy, pos) then
                    reason = 'Cannot build past the midline!'
                end
            elseif hasZones then
                for j, z in NoBuildZones() do
                    if InZone(z, pos) then
                        reason = 'No building in the lane!'
                        break
                    end
                end
            end

            if reason then
                local eco = s:GetBlueprint().Economy
                local frac = s:GetFractionComplete()
                brain:GiveResource('Mass', (eco.BuildCostMass or 0) * frac)
                brain:GiveResource('Energy', (eco.BuildCostEnergy or 0) * frac)
                s:Destroy()
                Config.PrintTextFor(armyName, reason, 14, 'ffff2222', 4, 'center')
            end
        end
    end
end

local function EnforceMidline(armyName, acu)
    local info = Config.PlayerArmies[armyName]
    local own, enemy = LaneCorePositions(armyName, info.lane)
    local p = acu:GetPosition()
    if not OwnSideOfMidline(own, enemy, p) then
        -- land a little in front of the Core, not on top of it
        local dx, dz = enemy[1] - own[1], enemy[3] - own[3]
        local len = VDist2(0, 0, dx, dz)
        local x = own[1] + dx / len * Config.MidlineReturnOffset
        local z = own[3] + dz / len * Config.MidlineReturnOffset
        Warp(acu, { x, GetTerrainHeight(x, z), z })
        Config.PrintTextFor(armyName, 'Your ACU crossed the midline and was sent home!',
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
