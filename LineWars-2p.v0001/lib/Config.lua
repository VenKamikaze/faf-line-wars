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

-- How many lanes the map has. Lanes are numbered from the middle outwards, which
-- is how they read on screen and how they are announced to players.
LaneCount = 3
LaneNames = { 'middle', 'top', 'bottom' }

-- 'L2 (top)' — how a lane is named in any player-facing message.
function LaneLabel(lane)
    return 'L' .. lane .. ' (' .. (LaneNames[lane] or 'unknown') .. ')'
end

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

-- Centre of capture zone n in a lane (fixed radius). `plus` (0..3) is the count
-- of trailing '+' the marker was named with: each one steps the point's mass
-- AND energy payout up a multiple (LW_L1_Cap4 = x1, ...Cap4+ = x2, ...Cap4++ = x3,
-- ...Cap4+++ = x4) and draws the ring one line thicker.
function CaptureMarker(lane, n, plus)
    return 'LW_L' .. lane .. '_Cap' .. n .. string.rep('+', plus or 0)
end

CapturePointMaxPlus = 3         -- most '+' suffixes honoured (x4 at the top)

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

-- Core energy output, scaled by round (lib/CoreStorage.ApplyCoreEnergy).
--
-- The Core is a UEF T3 power generator, and stock ueb1301 produces a flat
-- 2500 e/s from the moment it is spawned — twenty-five times BaseEnergyIncome
-- below, which is why every "energy is the scarce resource" comment in
-- units/LineWars_units.bp reads as optimistic in an actual game. Instead of a
-- blueprint merge (which a unit-overhaul mod would override — see the .bp
-- header) the script calls the live engine setter Unit:SetProductionPerSecondEnergy
-- once per round, so the ramp holds regardless of what mods are loaded.
--
-- Round 1 pays CoreEnergyBase; every round after adds CoreEnergyPerRound, up to
-- CoreEnergyMax.
--
-- THE PER-ROUND RAMP IS DELIBERATELY OFF (CoreEnergyPerRound = 0), so the Core
-- pays a flat CoreEnergyBase all game. Kamikaze's call 2026-07-27: economy growth
-- belongs in one place, and that place is now the "Income growth interval" /
-- "Income growth step" lobby options below, which scale every player's base mass
-- AND energy income together. The ramp machinery is kept intact rather than
-- deleted — set CoreEnergyPerRound back to a non-zero figure and the Core scales
-- again with no other change.
--
-- Note the Core is not the only energy source: each player also gets
-- BaseEnergyIncome (100/s), the ACU's stock 20/s, and any capture points held —
-- so round-1 income is ~620/s, not 500.
CoreEnergyBase = 500            -- e/s the Core produces (flat, see above)
CoreEnergyPerRound = 0          -- added per round thereafter; 0 disables the ramp
CoreEnergyMax = 2500            -- ceiling (the stock T3 pgen output)

function CoreEnergyForRound(round)
    local e = CoreEnergyBase + CoreEnergyPerRound * ((round or 1) - 1)
    if e > CoreEnergyMax then
        e = CoreEnergyMax
    end
    return e
end

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

-- Periodic income growth, on top of whichever income model is chosen and applied
-- to mass AND energy alike (lobby: "Income growth interval" + "Income growth
-- step"). Growth is a share of the BASE income and steps are ADDITIVE, not
-- compounding: at the 50% default you earn 100% / 150% / 200% / 250% ... of base,
-- so it never runs away the way a compounding curve does.
--
-- "Every X rounds" means the step lands ON each multiple of X — at the default
-- of 4 that is rounds 4, 8, 12, 16 (Kamikaze, 2026-07-27), NOT X+1. So the divisor
-- takes the round number as-is; do not "fix" it to (round - 1).
--
-- Corner case that falls out of that: at "every 1 round" the very first round is
-- already one step above base, since floor(1/1) = 1. That is the consistent
-- reading of "steps up at every multiple of X" and the option's help text says
-- so; special-casing it would make 1 the odd rung out.
--
-- This sentinel must match the 'Never' value key in LineWars-2p_options.lua.
IncomeGrowthNever = 9999

-- The multiplier to apply to base income this round: 1 + step x intervals passed.
function IncomeGrowthMultiplier(round)
    local every = GetIncomeGrowthRounds()
    if every >= IncomeGrowthNever or every < 1 then
        return 1
    end
    local steps = math.floor((round or 1) / every)
    return 1 + steps * (GetIncomeGrowthPercent() / 100)
end

-- Lane capture points (lib/CapturePoints.lua). LW_Cap<i> blank markers define
-- fixed-radius circular zones; holding one pays the controlling side extra
-- income (split to every living player on that side). Control is sticky: a land
-- unit only has to pass through to capture, and the point stays yours until it
-- is contested (both sides present) or the enemy takes it.
CapturePointRadius = 7         -- world units; the circle every LW_Cap marker gets
CapturePointMass = 2            -- mass/second per controlled point at 'High'
CapturePointEnergy = 25         -- energy/second per controlled point at 'High'

-- Multiplier on the two rates above, chosen by the "Capture point income" lobby
-- option. Each rung is HALF the one above it, so every step is the "50% either
-- way" Kamikaze asked for; 'High' is the flat rate the map used before this became
-- an option, and 'Average' (the default) is half of it. To rebalance, edit this
-- one table — the option's help text quotes the resulting mass/s.
CaptureIncomeScales = { 0.125, 0.25, 0.5, 1.0, 2.0 }   -- Very low .. Very high
CaptureIncomeDefault = 3                               -- Average
CapturePointTickSeconds = 0.1   -- control/income poll AND ring redraw cadence
                                -- (rings are one-frame draws, so keep this fast)

--------------------------------------------------------------------------
-- Waves
--------------------------------------------------------------------------
SpawnSpreadRadius = 4           -- units appear within this radius of the spawn marker
-- The pause before round 1 is now the "Map start delay" lobby option
-- (GetStartDelaySeconds, default 10s).

-- "Allow air units from round" sentinel: this key means air is never buildable.
-- Must match the 'Never' value key in LineWars-2p_options.lua.
AirNeverRound = 9999

--------------------------------------------------------------------------
-- Factory-queue economy (see lib/FactoryQueue.lua and FACTORY-QUEUE-DESIGN.md).
-- Prototype of the "queue-as-wave-list" model: a factory pinned to never build,
-- whose build queue is the player's standing wave. Charged on add, refunded on
-- cancel. Poll fast so the charge lands on the same tick the unit is queued and
-- a burst can over-commit by at most one tick's worth.
--------------------------------------------------------------------------
FactoryQueueTickSeconds = 0.1

--------------------------------------------------------------------------
-- Chat commands and the SOS panic button (lib/ChatCommands.lua, lib/Sos.lua)
--------------------------------------------------------------------------
SosCommand = '/sos'             -- typed in chat; matched exactly, lowercased
SosKillsCommander = false       -- true also detonates the ACU (brutal: it takes
                                -- a whole economy with it)
-- Uses per player, and whose units die, are lobby options — see
-- GetSosCharges() / GetSosTargets() below.
SosTargetsEnemy = 1             -- opt_lw_sos_targets: enemy mobile units only
SosTargetsAll = 2               -- opt_lw_sos_targets: every mobile unit in the
                                -- lane, the caller's and their allies' included
ChatCommandDedupeSeconds = 0.5  -- the same message may reach the sim once per
                                -- receiving client; ignore repeats inside this
                                -- window (see lib/ChatCommands.lua)

--------------------------------------------------------------------------
-- On-screen furniture (lib/Hud.lua). PrintText is the only display channel a
-- map has, and its control pool imposes one hard rule:
--     ScoreboardPeriodSeconds > ScoreboardLineDuration + 1
-- Break it and the board appends a fresh set of rows every cycle forever. The
-- gap it forces is why the board fades out and back once per cycle; raise both
-- together for less flicker and staler numbers.
--------------------------------------------------------------------------
IntroDurationSeconds = 30       -- how long the how-to-play card stays up
IntroLocation = 'leftcenter'
IntroTextSize = 14

ScoreboardLocation = 'lefttop'  -- must be a location nothing else prints to
ScoreboardPeriodSeconds = 12
ScoreboardLineDuration = 10
ScoreboardTextSize = 12
ScoreboardPollSeconds = 0.5     -- how often the loop checks whether a repaint is
                                -- due; the due-check itself is in REAL seconds

-- A PrintText location is a fixed screen anchor with no offset parameter, so the
-- only way to move text away from an edge is to pad it. Leading spaces shift it
-- right (about two letter widths at four spaces), and blank spacer lines printed
-- above the board push it down — one spacer per line, since spacers use the same
-- font size. Eight of them clear the resource bars that sit at the top left.
HudLeftPad = '    '
ScoreboardTopSpacerLines = 8

--------------------------------------------------------------------------
-- ACU rules (see lib/AcuRules.lua)
--------------------------------------------------------------------------
AcuBuildRateMult = 4            -- ACU build rate multiplier vs stock
AcuMoveSpeedMult = 4            -- ACU movement speed multiplier vs stock
AcuRulesTickSeconds = 1         -- how often ACU/no-build rules are enforced
ExperimentalTickSeconds = 1     -- how often lib/Experimentals.lua checks for the
                                -- tech-3 upgrade and for a finished experimental
                                -- to hand to the wave army

-- The engine ALREADY hides T3 items from a pre-upgrade ACU's build menu (Kamikaze,
-- observed in game 2026-07-27), so the script's own tech-3 restriction is
-- belt-and-braces, not the mechanism. Set false to drop it and rely on the
-- engine alone — worth doing if the unlock ever fails to fire, since the failure
-- mode of a stuck script gate is "experimentals never buildable at all".
-- lib/Experimentals.lua's completion sweep runs either way.
ExperimentalsScriptTierGate = true
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

-- How many rounds between income growth steps; IncomeGrowthNever = flat all game.
function GetIncomeGrowthRounds()
    return ScenarioInfo.Options.opt_lw_income_growth_rounds or 4
end

-- Percent of BASE income added at each growth step (25..200). See
-- IncomeGrowthMultiplier above for how the two combine.
function GetIncomeGrowthPercent()
    return ScenarioInfo.Options.opt_lw_income_growth_pct or 50
end

function GetCoreHealthMultiplier()
    return CoreBaseHealthMultiplier * (ScenarioInfo.Options.opt_lw_core_health or 1)
end

-- The round at which air factories/units unlock. 0 or 1 = available immediately;
-- AirNeverRound = never. See lib/AirGate.lua.
function GetAirFromRound()
    return ScenarioInfo.Options.opt_lw_air_from_round or 3
end

-- Grace period (seconds) after the game loads before the first build round.
function GetStartDelaySeconds()
    return ScenarioInfo.Options.opt_lw_start_delay or 10
end

-- How many times each player may use /sos. 0 disables the command. (0 is truthy
-- in Lua, so the `or` fallback cannot swallow the "None" setting.)
function GetSosCharges()
    return ScenarioInfo.Options.opt_lw_sos_charges or 1
end

-- Multiplier on CapturePointMass/CapturePointEnergy — see CaptureIncomeScales.
function GetCaptureIncomeScale()
    local key = ScenarioInfo.Options.opt_lw_capture_income or CaptureIncomeDefault
    return CaptureIncomeScales[key] or CaptureIncomeScales[CaptureIncomeDefault]
end

-- SosTargetsEnemy = only the other side's mobile units die; SosTargetsAll =
-- every mobile unit in the lane dies, the caller's own wave included. The
-- fallback matches the lobby default so an offline/sandbox start behaves the
-- same as a real game.
function GetSosTargets()
    return ScenarioInfo.Options.opt_lw_sos_targets or SosTargetsAll
end

function Log(msg)
    if DebugMode then
        LOG('LineWars: ' .. msg)
    end
end

--------------------------------------------------------------------------
-- THE PRINTTEXT GATE — read this before adding any on-screen message.
--
-- `lua/ui/game/textdisplay.lua` captures its parent control ONCE, at module
-- load time:
--
--     local worldView = import('/lua/ui/game/borders.lua').GetMapGroup()
--
-- and `GetMapGroup()` returns **false** until the UI has built its border
-- controls (`gamemain.CreateUI` -> `borders.SetupBorderControl`). The sim can
-- start before that happens, so the FIRST PrintText a map sends may load
-- textdisplay with a dead parent — after which EVERY PrintText for the whole
-- session throws
--
--     maui/text.lua(19): Expected a game object
--
-- and nothing is ever drawn again. It cannot be recovered: the module is cached
-- with its bad upvalue, and a map cannot reach UI code to repair it.
--
-- Seen for real in game_27479823.log (2026-07-25): the intro card printed at
-- tick 0, produced 138 of those errors, and no on-screen text appeared at any
-- point in the game.
--
-- So every message this map sends goes through Announce() below, which holds
-- anything printed in the first HudStartDelaySeconds and flushes it when the
-- gate opens. **If on-screen text is missing and the log carries that error,
-- this number is the dial to turn up.**
--------------------------------------------------------------------------
HudStartDelaySeconds = 8

-- Wall-clock seconds. `WaitSeconds` counts GAME time, which runs faster or
-- slower as players press +/- on the sim speed, while textdisplay's fade timer
-- counts REAL time (its OnFrame accumulates frame deltas). So anything paced
-- against that fade — or against the arrival of the UI, which is also a
-- real-world event — must be timed with this and not with WaitSeconds.
--
-- This is a profiling clock and its value differs per client, so like
-- GetFocusArmy() it may only ever drive UI output, never sim state.
function RealSeconds()
    if GetSystemTimeSecondsOnlyForProfileUse then
        return GetSystemTimeSecondsOnlyForProfileUse()
    end
    return GetGameTimeSeconds()   -- headless/sandbox fallback
end

local hudOpen = false
local pending = {}

local function Emit(m)
    PrintText(m.text, m.size, m.color, m.duration, m.location)
end

-- Every on-screen message in this map goes through here instead of calling
-- PrintText directly.
function Announce(text, size, color, duration, location)
    local m = { text = text, size = size, color = color,
                duration = duration, location = location }
    if hudOpen then
        Emit(m)
    else
        table.insert(pending, m)
    end
end

function HudIsOpen()
    return hudOpen
end

-- Blocks the calling thread until the gate opens. Used by anything that repaints
-- on a cycle: a queued batch flushing late would land on top of the next batch
-- and break the "period > duration + 1" pooling rule (see lib/Hud.lua).
-- Bounded, so that a gate which somehow never opens degrades to a display that
-- runs anyway rather than a thread that spins for the rest of the game.
function WaitForHud()
    local deadline = RealSeconds() + HudStartDelaySeconds * 3
    while not hudOpen and RealSeconds() < deadline do
        WaitSeconds(0.5)
    end
end

-- Called once from OnStart, before anything prints. The delay is measured in real
-- seconds: what we are waiting for is the UI to finish building, so a game
-- started at high sim speed must not open the gate proportionally early.
function StartHudGate()
    ForkThread(function()
        local openAt = RealSeconds() + HudStartDelaySeconds
        while RealSeconds() < openAt do
            WaitSeconds(0.5)
        end
        hudOpen = true
        for i, m in pending do
            Emit(m)
        end
        pending = {}
    end)
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
        Announce(text, size, color, duration, location)
    end
end

-- For team announcements: shown to everyone playing on `side`, nobody else.
function PrintTextForSide(side, text, size, color, duration, location)
    for i, name in ScenarioInfo.LW.ActivePlayers do
        if PlayerArmies[name].side == side and IsFocus(name) then
            Announce(text, size, color, duration, location)
            return
        end
    end
end
