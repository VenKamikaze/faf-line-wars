-- Line Wars static configuration.
-- All gameplay tuning lives here, in lib/UnitTypes.lua (which units exist) or in
-- units/LineWars_units.bp (what they cost), so balance passes never touch the
-- mechanics code.

-- Player armies, keyed by army name. Side 'A' is one end of the map, side 'B'
-- the other. Each lane is a mirrored 1v1 duel: ARMY_1 vs ARMY_2 in lane 1, etc.
-- Lobby slots must be filled in pairs (1+2, 3+4, 5+6) for a lane to function.
PlayerArmies = {
    ARMY_1 = { lane = 1, side = 'A' },
    ARMY_2 = { lane = 1, side = 'B' },
    ARMY_3 = { lane = 2, side = 'A' },
    ARMY_4 = { lane = 2, side = 'B' },
    ARMY_5 = { lane = 3, side = 'A' },
    ARMY_6 = { lane = 3, side = 'B' },
}

OppositeSide = { A = 'B', B = 'A' }

-- The ARMY_WAVE_n armies that own the marching units are forced to one colour
-- per side. Players keep their own lobby colours — only the waves are recoloured,
-- so the zoomed-out tactical view shows the push and pull of every lane in two
-- colours while you can still tell teammates apart. RGB 0-255, fed to the sim
-- global SetArmyColor(army, r, g, b).
SideColors = {
    A = { 230, 50, 40 },    -- red
    B = { 40, 90, 240 },    -- blue
}

-- Script-owned armies that hold the marching wave units, one per player so
-- players cannot micro their own waves. These must exist in the map's
-- _save.lua and are listed as ExtraArmies in the _scenario.lua.
function WaveArmyOf(armyName)
    return 'ARMY_WAVE_' .. string.sub(armyName, 6) -- 'ARMY_3' -> 'ARMY_WAVE_3'
end

-- Returns the player army holding this lane/side slot, or nil if that lobby
-- slot is empty.
function ArmyInLane(lane, side)
    for name, other in PlayerArmies do
        if other.lane == lane and other.side == side then
            for i, listed in ListArmies() do
                if listed == name then
                    return name
                end
            end
        end
    end
    return nil
end

-- Returns the player army on the other side of this army's lane, or nil if
-- that lobby slot is empty.
function EnemyOf(armyName)
    local info = PlayerArmies[armyName]
    return ArmyInLane(info.lane, OppositeSide[info.side])
end

--------------------------------------------------------------------------
-- Marker name contract (see "Map contract" in README.md). All are 'Blank
-- Marker's placed in FAFMapEditor; names must match exactly (case-sensitive).
--------------------------------------------------------------------------
function SpawnMarker(lane, side)            -- where a side's wave appears
    return 'LW_L' .. lane .. '_Spawn_' .. side
end

function CoreMarker(lane, side)             -- where a side's Core is placed
    return 'LW_L' .. lane .. '_Core_' .. side
end

function WaypointMarker(lane, side, n)      -- optional path markers, walked in order
    return 'LW_L' .. lane .. '_Wp' .. n .. '_' .. side
end

function NoBuildMarker(i, corner)           -- corners (A/B) of rectangular no-build zone i
    return 'LW_NoBuild' .. i .. '_' .. corner
end

-- Safe lookup: returns the marker table or nil (MarkerToPosition errors on
-- missing markers, which makes optional waypoints impossible to probe).
function GetMarker(name)
    return Scenario.MasterChain._MASTERCHAIN_.Markers[name]
end

--------------------------------------------------------------------------
-- Core (the structure each player must protect; the lane is lost when it dies)
--------------------------------------------------------------------------
CoreBlueprint = 'ueb1301'       -- placeholder: UEF T3 power generator. TODO:
                                -- replace with a custom blueprint in units/
CoreBaseHealthMultiplier = 10   -- multiplied further by the lobby option

--------------------------------------------------------------------------
-- Economy
--------------------------------------------------------------------------
StartingMass = 150
StartingEnergy = 500

-- Storage-capacity overrides live in units/LineWars_units.bp (a LOAD-time .bp
-- merge — the only kind that reaches the engine's storage; a runtime __blueprints
-- edit does not). ACU base storage 650->216, per-round Core storage unit = 100.
-- NB those merges lose to unit-overhaul mods (see the .bp header).
BaseMassIncome = 2.0            -- mass/second, both income models
BaseEnergyIncome = 100          -- energy/second, both models (energy is not
                                -- meant to be a constraint in v1)
FlatIncomeGrowthPerRound = 0.25 -- income model 2: +25% of base per round
EconomyTickSeconds = 1

--------------------------------------------------------------------------
-- Waves
--------------------------------------------------------------------------
SpawnSpreadRadius = 4           -- units appear within this radius of the spawn marker
InitialGraceSeconds = 5         -- pause after game start before round 1 begins

--------------------------------------------------------------------------
-- Factory-queue economy (see lib/FactoryQueue.lua and FACTORY-QUEUE-DESIGN.md).
-- Prototype of the "queue-as-wave-list" model: a factory pinned to never build,
-- whose build queue is the player's standing wave. Charged on add, refunded on
-- cancel. Poll fast so the charge lands on the same tick the unit is queued and
-- a burst can over-commit by at most one tick's worth.
--------------------------------------------------------------------------
FactoryQueueTickSeconds = 0.1

--------------------------------------------------------------------------
-- ACU rules (see lib/AcuRules.lua)
--------------------------------------------------------------------------
AcuBuildRateMult = 4            -- ACU build rate multiplier vs stock
AcuMoveSpeedMult = 4            -- ACU movement speed multiplier vs stock
AcuRulesTickSeconds = 1         -- how often ACU/no-build rules are enforced
MidlineReturnOffset = 10        -- warped-back ACUs land this far in front of their Core

DebugMode = true                -- extra LOG() output while developing

--------------------------------------------------------------------------
-- Lobby option accessors (with defaults for offline/sandbox starts where
-- ScenarioInfo.Options may be missing keys)
--------------------------------------------------------------------------
function GetRoundSeconds()
    return ScenarioInfo.Options.opt_lw_round_time or 60
end

function GetIncomeModel()
    return ScenarioInfo.Options.opt_lw_income_model or 1
end

function GetCoreHealthMultiplier()
    return CoreBaseHealthMultiplier * (ScenarioInfo.Options.opt_lw_core_health or 1)
end

function Log(msg)
    if DebugMode then
        LOG('LineWars: ' .. msg)
    end
end

--------------------------------------------------------------------------
-- On-screen messages addressed to ONE player (or one side).
--
-- Sim code runs identically on every client, so a bare PrintText shows the
-- message on everybody's screen — which is why another player's (or an AI's)
-- "not enough mass" used to pop up in front of you. GetFocusArmy() is the LOCAL
-- client's army, so its value differs per client: safe for UI-only effects like
-- this, and never for anything that touches sim state. The engine itself uses
-- exactly this trick in SimSync.lua (see CancelCountdown).
--------------------------------------------------------------------------
local function IsFocus(armyName)
    if not GetFocusArmy then
        return true   -- no focus concept (sandbox/headless): better shown than lost
    end
    return GetFocusArmy() == GetArmyBrain(armyName):GetArmyIndex()
end

function PrintTextFor(armyName, text, size, color, duration, location)
    if IsFocus(armyName) then
        PrintText(text, size, color, duration, location)
    end
end

-- For team announcements: shown to everyone playing on `side`, nobody else.
function PrintTextForSide(side, text, size, color, duration, location)
    for i, name in ScenarioInfo.LW.ActivePlayers do
        if PlayerArmies[name].side == side and IsFocus(name) then
            PrintText(text, size, color, duration, location)
            return
        end
    end
end
