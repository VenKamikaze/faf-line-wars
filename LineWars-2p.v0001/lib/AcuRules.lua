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
local ChatCommands = import(DIR .. 'lib/ChatCommands.lua')

-- NOTE: no MoveMult here, deliberately. Movement is applied by ApplyMovement
-- below instead. See the comment there for why.
BuffBlueprint {
    Name = 'LineWarsAcu',
    DisplayName = 'LineWarsAcu',
    BuffType = 'LINEWARSACU',
    Stacks = 'REPLACE',
    Duration = -1,
    Affects = {
        BuildRate = { Add = 0, Mult = Config.AcuBuildRateMult },
    },
}

-- Speed the ACU up.
--
-- WHY NOT A `MoveMult` BUFF, WHICH IS THE OBVIOUS WAY. Because that field is
-- three settings wearing one hat: lua/sim/Buff.lua:386-390 takes the single
-- number and calls SetSpeedMult, SetAccMult AND SetTurnMult with it. Speed,
-- acceleration and turn rate can never differ under a buff, and they need to.
--
-- THE STUTTER THIS FIXES (playtest 2026-08-08): the ACU slowed sharply once it
-- was near its destination, then covered the last stretch in a series of small
-- forward jerks.
--
-- What is CERTAIN: braking is the one motion parameter with no multiplier
-- handle. SetSpeedMult, SetAccMult and SetTurnMult are the only motion Set*Mult
-- calls the engine exposes, grepped across all of lua.nx2 on 2026-08-08. So a
-- 4x MoveMult raised top speed 1.7 -> 6.8 and left braking exactly where it was
-- — and where it was is nowhere: MaxBrake is ABSENT from all four ACU Physics
-- blocks (UEL0001_unit.bp and the other three), while the otherwise
-- near-identical SACU (UEL0301) declares MaxBrake = 2.2 beside the same
-- MaxAcceleration. Stock, an ACU never moves fast enough for that to show.
-- Braking distance goes as v^2/2b, so 4x speed asks ~16x the room, and the
-- engine's arrival behaviour degrades accordingly.
--
-- CONFIRMED in game 27570392 (2026-08-08): merging Physics.MaxBrake into the
-- four ACUs removed the stutter outright, and no combination of these three
-- multipliers reproduced or relieved it. Braking was the whole of it. The fix
-- therefore lives in units/LineWars_units.bp, which is load-time only because
-- no runtime brake setter exists — SetSpeedMult/SetAccMult/SetTurnMult above
-- are the only motion multipliers, and unit:GetNavigator() exposes just SetGoal
-- and AbortMove (both greps over lua.nx2, 2026-08-08).
--
-- So these three CANNOT touch braking, and that is not a gap to be plugged
-- later — it is the shape of the engine. What they are still for: tuning speed
-- against acceleration and turn rate around whatever brake is loaded, and being
-- the only lever left under a unit-overhaul mod, which beats a map .bp and
-- takes the brake fix away with it (see the .bp header).
--
-- Applied once per ACU rather than every tick, per the "never mutate a unit's
-- state on a fast tick when nothing changed" rule in CLAUDE.md. The cost is
-- that a movement debuff would clobber these permanently — the buff system
-- recalculates its own affects, this does not, and nothing re-applies once
-- `buffed[acu]` is set (Unit.lua:4454 is such a caller). Nothing in this map's
-- roster does that today.
function ApplyMovement(acu)
    acu:SetSpeedMult(Config.AcuMoveSpeedMult)
    acu:SetAccMult(Config.AcuMoveAccelMult)
    acu:SetTurnMult(Config.AcuMoveTurnMult)
end

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

-- Split a string on whitespace. string.gmatch does not exist in this Lua
-- dialect (it is the 5.1 name for 5.0's string.gfind), so this walks with
-- string.find, which is spelled the same in both.
local function Words(s)
    local out = {}
    local init = 1
    while true do
        local a, b, w = string.find(s, '(%S+)', init)
        if not a then
            break
        end
        table.insert(out, w)
        init = b + 1
    end
    return out
end

-- Dev-only live tuning of the three movement multipliers: "/acu <speed>
-- <accel> <turn>". Trailing values may be omitted to keep their current value,
-- and a bare "/acu" just reports. Exists because the brake half of the fix
-- (units/LineWars_units.bp) is load-time only and cannot be A/B tested in a
-- running game — this is how the multipliers around it get settled in ONE
-- session instead of one game per guess.
--
-- Applies to every player's ACUs, not just the caller's: the multipliers live
-- in Config, which is global, so a rebuilt enemy ACU would pick up the new
-- values anyway. Better that both sides match than that they silently drift.
--
-- THIS COMMAND CANNOT CHANGE BRAKING — which is easy to miss while tuning, so
-- the reply below says so out loud. Braking is blueprint-only; see
-- ApplyMovement. Retuning it means editing units/LineWars_units.bp and
-- relaunching.
local function TuneCommand(armyName, args)
    local w = Words(args)
    local names = { 'AcuMoveSpeedMult', 'AcuMoveAccelMult', 'AcuMoveTurnMult' }
    local parsed = {}

    -- Validated in full BEFORE anything is assigned. A half-applied "/acu 4 abc
    -- 8" would leave Config disagreeing with the live ACUs, in the one tool
    -- whose entire job is correlating those numbers to how the ACU feels.
    for i, key in names do
        if w[i] then
            local v = tonumber(w[i])
            if not v or v < 0.1 or v > 20 then
                Config.PrintTextFor(armyName, 'usage: ' .. Config.AcuTuneCommand ..
                    ' <speed> <accel> <turn>   (0.1 - 20, trailing values optional)',
                    14, 'ffff2222', 5, 'center')
                return
            end
            parsed[key] = v
        end
    end
    for i, key in names do
        if parsed[key] then
            Config[key] = parsed[key]
        end
    end

    for i, name in ScenarioInfo.LW.ActivePlayers do
        for j, acu in GetArmyBrain(name):GetListOfUnits(categories.COMMAND, false) do
            if not acu.Dead then
                ApplyMovement(acu)
            end
        end
    end

    local msg = 'ACU move: speed ' .. tostring(Config.AcuMoveSpeedMult) ..
        '  accel ' .. tostring(Config.AcuMoveAccelMult) ..
        '  turn ' .. tostring(Config.AcuMoveTurnMult) ..
        '  (braking is blueprint-only, not tunable here)'
    Config.Log(msg .. ' (set by ' .. armyName .. ')')
    Config.PrintTextFor(armyName, msg, 14, 'ff00ff00', 5, 'center')
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
                            ApplyMovement(acu)
                            buffed[acu] = true
                            -- Proof the units/LineWars_units.bp brake merge
                            -- actually loaded. Every other merge in that file
                            -- writes a key the stock blueprint already has;
                            -- MaxBrake is a NEW key on Physics, so whether
                            -- BlueprintMerged adds it is untested. nil here
                            -- means the merge never reached the engine (a mod
                            -- winning, per the .bp header) and the stutter fix
                            -- is not in play — don't chase it in-game.
                            Config.Log('ACU ' .. tostring(acu.UnitId) .. ' MaxBrake=' ..
                                tostring(acu:GetBlueprint().Physics.MaxBrake) ..
                                ' speed/accel/turn mult=' ..
                                tostring(Config.AcuMoveSpeedMult) .. '/' ..
                                tostring(Config.AcuMoveAccelMult) .. '/' ..
                                tostring(Config.AcuMoveTurnMult))
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

-- ORDER MATTERS. The rules loop is forked FIRST so that nothing in the optional
-- dev-tool path below can stop it starting. In game 27570431 it was the other
-- way round and a single bad Config value (AcuTuneCommand = nil, which throws on
-- read under FA's strict globals — see the note beside it in Config.lua) threw
-- out of this function before the fork, silently disabling the build-rate buff,
-- the movement multipliers, midline enforcement and the no-build zones for the
-- whole match. The tuning command is a convenience; the rules are the game mode.
function Start()
    ForkThread(RulesLoop)
    if Config.AcuTuneCommand then
        ChatCommands.Register(Config.AcuTuneCommand, TuneCommand, true)
        Config.Log('ACU movement tuning command "' .. Config.AcuTuneCommand .. '" registered')
    end
end
