-- Line Wars static configuration.
-- All gameplay tuning lives here or in SpawnerTypes.lua so balance passes
-- never touch the mechanics code.

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

-- Script-owned armies that hold the marching wave units, one per player so
-- players cannot micro their own waves. These must exist in the map's
-- _save.lua and are listed as ExtraArmies in the _scenario.lua.
function WaveArmyOf(armyName)
    return 'ARMY_WAVE_' .. string.sub(armyName, 6) -- 'ARMY_3' -> 'ARMY_WAVE_3'
end

-- Returns the player army on the other side of this army's lane, or nil if
-- that lobby slot is empty.
function EnemyOf(armyName)
    local info = PlayerArmies[armyName]
    local enemySide = OppositeSide[info.side]
    for name, other in PlayerArmies do
        if other.lane == info.lane and other.side == enemySide then
            for i, listed in ListArmies() do
                if listed == name then
                    return name
                end
            end
        end
    end
    return nil
end

--------------------------------------------------------------------------
-- Marker name contract (see MARKERS.md). All are 'Blank Marker's placed in
-- FAFMapEditor; names must match exactly (case-sensitive).
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
