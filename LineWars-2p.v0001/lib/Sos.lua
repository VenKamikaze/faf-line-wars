-- The SOS panic button: typed as "/sos" in chat, a few uses per player per game
-- (the "SOS uses per player" lobby option, default 1; None disables it).
--
-- Triggering it kills the MOBILE units standing in the lane the caller started
-- in (Config.PlayerArmies[army].lane — the lane you were assigned by your lobby
-- slot, not wherever your ACU happens to be). Which units is the "SOS destroys"
-- lobby option:
--   * Enemy units only (default) — clears the push against you and leaves your
--     own wave standing.
--   * Every unit in the lane — both sides die, your own wave and any ally
--     reinforcing your lane included. Fairer, because pressing it costs you the
--     units you already paid for.
-- Structures survive either way: Cores, factories, the pre-placed lane towers
-- and the ACU-built defences are all untouched, so SOS clears a push, it does
-- not break a base.
--
-- Decisions worth knowing (all flagged as assumptions until tested in-game):
--   * No ACU is killed (COMMAND is excluded unless Config.SosKillsCommander is
--     set). It is a mobile unit, but wiping it by chat command would end a lane
--     outright and take that player's whole economy with it.
--   * The charge is spent even if the lane turns out to be empty — no probing.
--     With "Every unit in the lane" that also means you can wipe your own wave
--     and hit nothing else; the option is meant to make SOS a real cost.
--   * Victims are Kill()ed, not Destroy()ed, so they explode and leave wreckage
--     the way a normal death does. That wreckage is reclaimable by whoever gets
--     to it; flip to Destroy() if the mass windfall is unwanted.
--   * "In the lane" is decided by nearest lane AXIS
--     (FactoryQueue.LaneForAnyPosition), the same measure factories are bound
--     by, so it covers a teammate's reinforcing wave marching through your lane
--     as well as the lane owner's own units.
local DIR = ScenarioInfo.directory or '/maps/LineWars-2p.v0001/'
local Config = import(DIR .. 'lib/Config.lua')
local FactoryQueue = import(DIR .. 'lib/FactoryQueue.lua')
local ChatCommands = import(DIR .. 'lib/ChatCommands.lua')

-- Everything that can march: mobile units only, never structures. Computed
-- lazily because `categories` is a sim global that is not guaranteed to exist
-- at module-import time.
local victimCategory
local function VictimCategory()
    if not victimCategory then
        victimCategory = categories.ALLUNITS - categories.STRUCTURE
        if not Config.SosKillsCommander then
            victimCategory = victimCategory - categories.COMMAND
        end
    end
    return victimCategory
end

-- How many charges this player has left (0 if they never had any).
function ChargesFor(armyName)
    local charges = ScenarioInfo.LW.SosCharges
    return (charges and charges[armyName]) or 0
end

local function NicknameOf(armyName)
    local brain = GetArmyBrain(armyName)
    return (brain and brain.Nickname) or armyName
end

-- Everything standing in `lane` that this SOS is allowed to kill, gathered from
-- both the player armies and their ARMY_WAVE_n armies. `side` is the caller's;
-- under the default "Enemy units only" setting their own side is skipped, under
-- "Every unit in the lane" nobody is.
local function UnitsInLane(side, lane)
    local LW = ScenarioInfo.LW
    local enemyOnly = Config.GetSosTargets() == Config.SosTargetsEnemy
    local victims = {}
    for i, armyName in LW.ActivePlayers do
        if not (enemyOnly and Config.PlayerArmies[armyName].side == side) then
            local brains = { GetArmyBrain(armyName), GetArmyBrain(Config.WaveArmyOf(armyName)) }
            for j, brain in brains do
                for k, unit in brain:GetListOfUnits(VictimCategory(), false) do
                    if not unit.Dead and FactoryQueue.LaneForAnyPosition(unit:GetPosition()) == lane then
                        table.insert(victims, unit)
                    end
                end
            end
        end
    end
    return victims
end

-- Kill order reaches sim state — death weapons damage neighbours, so which unit
-- dies first can change what else dies. GetListOfUnits' order is engine-side and
-- not something this script should trust across clients, so sort on the cached
-- .EntityId first (same rule as SortedFactories in lib/FactoryQueue.lua).
local function ByEntityId(a, b)
    return a.EntityId < b.EntityId
end

local function WipeLane(armyName, lane)
    local victims = UnitsInLane(Config.PlayerArmies[armyName].side, lane)
    table.sort(victims, ByEntityId)
    local killed = 0
    for i, unit in victims do
        if not unit.Dead then
            unit:Kill()
            killed = killed + 1
        end
    end
    return killed
end

local function Trigger(armyName)
    local LW = ScenarioInfo.LW
    if LW.GameOver then
        return
    end
    if LW.Dead[armyName] then
        Config.PrintTextFor(armyName, 'SOS unavailable - your lane is already lost',
            14, 'ffff6666', 5, 'center')
        return
    end
    local left = ChargesFor(armyName)
    if left <= 0 then
        local why = 'No SOS left'
        if Config.GetSosCharges() <= 0 then
            why = 'SOS is switched off in this game'
        end
        Config.PrintTextFor(armyName, why, 14, 'ffff6666', 5, 'center')
        return
    end

    -- Spend first: the charge is gone whether or not there was anything to kill,
    -- and spending before the wipe keeps a second copy of the same chat callback
    -- (see lib/ChatCommands.lua) from ever announcing twice.
    LW.SosCharges[armyName] = left - 1
    local lane = Config.PlayerArmies[armyName].lane
    local killed = WipeLane(armyName, lane)

    -- Global on purpose: everyone should see who burned their SOS and where.
    local what = 'enemy units'
    if Config.GetSosTargets() == Config.SosTargetsAll then
        what = 'units, both sides,'
    end
    Config.Announce('SOS! ' .. NicknameOf(armyName) .. ' cleared lane ' .. Config.LaneLabel(lane) ..
        ' - ' .. killed .. ' ' .. what .. ' destroyed', 18, 'ffFF7744', 8, 'center')
    Config.Log('SOS by ' .. armyName .. ' in lane ' .. lane .. ': killed ' .. killed)
end

function Start()
    local LW = ScenarioInfo.LW
    local charges = Config.GetSosCharges()
    LW.SosCharges = {}
    for i, armyName in LW.ActivePlayers do
        LW.SosCharges[armyName] = charges
    end
    -- Registered even at 0 charges, so typing /sos says why nothing happened
    -- rather than looking broken.
    ChatCommands.Register(Config.SosCommand, Trigger)
    Config.Log('SOS ready: ' .. charges .. ' charge(s) each, targets mode ' ..
        Config.GetSosTargets() .. ', command ' .. Config.SosCommand)
end
