-- The "queue-as-wave-list" economy loop (FACTORY-QUEUE-DESIGN.md).
--
-- Players build their own factories with the ACU (nothing is placed for them).
-- Every factory is pinned to NEVER build (SetBuildRate 0); its build queue is
-- purely a visual of the standing wave it contributes. Because the engine has no
-- "add to queue" event and no affordability gate, we:
--   * poll GetCommandQueue() every FactoryQueueTickSeconds and diff it against
--     the last snapshot, per factory,
--   * TakeResource on each unit added ONLY if the player can fully afford it —
--     an unaffordable add is rejected (see ReconcileFactory), which kills the
--     "build for 1 mass" exploit (TakeResource silently floors stored at 0).
--     Because a single factory order can't be surgically removed (no re-issue
--     callback in sim/commands/shared.lua), a rejected add is undone by
--     rebuilding that factory's queue from its paid set (IssueClearCommands +
--     IssueBuildFactory),
--   * GiveResource on each unit cancelled, and on every unit still paid for in a
--     factory that dies,
--   * verify on the following tick that a rebuild actually landed, because a
--     rebuild that silently fails is indistinguishable from "the player cancelled
--     the whole queue" and would refund the entire standing wave.
--
-- The queue is PERSISTENT: you pay once when you queue a unit and it spawns
-- every round until you cancel it. WaveSpawner reads WavesForArmy() at round end
-- and does NOT clear it.
--
-- LANE ASSIGNMENT: each factory is bound, at the moment it finishes building, to
-- the friendly lane whose axis it sits closest to (see LaneForPosition). Its
-- queue spawns at THAT lane's spawn marker and marches THAT lane. So a player
-- can walk into a teammate's lane, build a factory there, and reinforce them —
-- the units still belong to the builder's own ARMY_WAVE_n, which is allied to
-- everyone on that side, so nothing else has to change.
--
-- Multiple factories per player are fully supported and are the point: each is
-- its own independent queue (this is design open question 5, now answered).
local DIR = ScenarioInfo.directory or '/maps/LineWars-2p.v0001/'
local Config = import(DIR .. 'lib/Config.lua')
local UnitTypes = import(DIR .. 'lib/UnitTypes.lua')

-- Mass/energy cost of a unit blueprint by id. Queued units don't exist yet, so
-- we read the blueprint table directly rather than a live unit.
local function UnitCost(bp)
    local blueprint = __blueprints[bp]
    local eco = blueprint and blueprint.Economy
    if not eco then
        WARN('LineWars: no blueprint/economy for wave unit ' .. tostring(bp))
        return 0, 0
    end
    return eco.BuildCostMass or 0, eco.BuildCostEnergy or 0
end

-- NB: we deliberately do NOT use SetBlockCommandQueue as an "you're broke"
-- early-out any more. It blocks our OWN IssueBuildFactory as well as the
-- player's clicks, so the queue rebuild below silently vanished and the next
-- tick refunded the whole queue — and FactoryUnit's IdleState/RolloffBody drive
-- that same flag themselves (FactoryUnit.lua:263, 386, 424), so setting it per
-- tick fought the factory's own state machine. Affordability is enforced purely
-- per unit in ReconcileFactory.

-- Category union players are allowed to build: ACU + the factories + the wave
-- units. Used by the script's AddRestriction so the ACU menu shows just the
-- factories and each factory menu shows just the units of its own kind (all
-- other units of that domain are restricted away).
function AllowedCategories()
    local allowed = categories.COMMAND
    local function add(list, what)
        for i, bp in list do
            if categories[bp] then
                allowed = allowed + categories[bp]
            else
                WARN('LineWars: no category for ' .. what .. ' ' .. bp)
            end
        end
    end
    add(UnitTypes.AllFactoryIds(), 'factory')
    add(UnitTypes.AllUnitIds(), 'wave unit')
    return allowed
end

-- Category union of just the wave units, for the stray-unit sweep below.
local waveCategory
local function WaveCategory()
    if not waveCategory then
        for i, bp in UnitTypes.AllUnitIds() do
            if categories[bp] then
                waveCategory = waveCategory and (waveCategory + categories[bp]) or categories[bp]
            end
        end
    end
    return waveCategory
end

--------------------------------------------------------------------------
-- Lane assignment
--------------------------------------------------------------------------

-- 2D distance from a point to a line segment (all in world x/z).
local function DistToSegment(px, pz, ax, az, bx, bz)
    local dx, dz = bx - ax, bz - az
    local len2 = dx * dx + dz * dz
    if len2 < 1 then
        return VDist2(px, pz, ax, az)
    end
    local t = ((px - ax) * dx + (pz - az) * dz) / len2
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
    return VDist2(px, pz, ax + t * dx, az + t * dz)
end

-- Which lane a factory at this position feeds. Candidates are the lanes held by
-- a living player on the builder's own side (so their own lane always qualifies,
-- and you can only reinforce a lane a teammate actually holds). A lane is
-- measured by its AXIS — the segment from the near Core marker to the far one —
-- not by its Core, so a factory pushed forward in a lane still reads as that
-- lane rather than snapping to whichever Core happens to be nearest.
-- (Exported: WaveSpawner's idle watchdog uses it to re-path stray wave units
-- down the lane they are actually standing in.)
function LaneForPosition(armyName, pos)
    local LW = ScenarioInfo.LW
    local mine = Config.PlayerArmies[armyName]
    local far = Config.OppositeSide[mine.side]
    local best, bestDist = mine.lane, nil
    for i, other in LW.ActivePlayers do
        local info = Config.PlayerArmies[other]
        if info.side == mine.side and not LW.Dead[other] then
            local a = Config.GetMarker(Config.CoreMarker(info.lane, mine.side))
            local b = Config.GetMarker(Config.CoreMarker(info.lane, far))
                   or Config.GetMarker(Config.SpawnMarker(info.lane, mine.side))
            if a and b then
                local d = DistToSegment(pos[1], pos[3],
                    a.position[1], a.position[3], b.position[1], b.position[3])
                if not bestDist or d < bestDist then
                    best, bestDist = info.lane, d
                end
            end
        end
    end
    return best
end

--------------------------------------------------------------------------
-- Per-factory queue bookkeeping
--------------------------------------------------------------------------

-- LW.Factories[armyName] is keyed by the factory unit itself:
--   { factory = unit, lane = n, kind = 'LAND'|'AIR', committed = { bp -> count } }
-- committed is the paid standing wave and matches that factory's visible queue
-- after every tick.

local function Refund(brain, committed, why)
    for bp, n in committed do
        local m, e = UnitCost(bp)
        brain:GiveResource('Mass', m * n)
        brain:GiveResource('Energy', e * n)
        Config.Log(why .. ': refunded ' .. n .. 'x ' .. bp .. ' (m=' .. (m * n) .. ')')
    end
end

-- Two independent locks, because the queue must never actually produce anything:
-- build rate 0, and paused. Belt and braces is warranted — a player can hit the
-- unpause button, and build rate alone was not visibly holding under a fast
-- spam-click. Re-applied every tick rather than once at adoption, so neither can
-- be undone for longer than one tick.
local function Pin(factory)
    factory:SetBuildRate(0)
    factory:SetPaused(true)
end

-- Take ownership of a factory the moment it finishes building: pin it to never
-- build and bind it to a lane.
local function Adopt(armyName, records, factory)
    local lane = LaneForPosition(armyName, factory:GetPosition())
    Pin(factory)
    records[factory] = {
        factory = factory,
        lane = lane,
        kind = UnitTypes.KindOfFactory(factory:GetUnitId()),
        committed = {},
    }
    Config.Log(armyName .. ' ' .. tostring(records[factory].kind) .. ' factory ' ..
        factory:GetUnitId() .. ' feeds lane ' .. lane)
    -- Team news, not an announcement to the enemy: only the builder's own side
    -- is told that a lane is being reinforced.
    if lane ~= Config.PlayerArmies[armyName].lane then
        Config.PrintTextForSide(Config.PlayerArmies[armyName].side,
            GetArmyBrain(armyName).Nickname .. ' is reinforcing lane ' .. lane .. '!',
            14, 'ff44ff44', 4, 'center')
    end
end

-- Command-queue order types we care about (sim/commands/shared.lua): a unit
-- queued in a factory is a BuildFactory order; the native upgrade button issues
-- an Upgrade order carrying the target building as its blueprintId.
local BUILD_FACTORY_COMMAND = 7
local UPGRADE_COMMAND       = 27

-- This factory's visible queue of UNITS as { blueprintId -> count }. Upgrade
-- orders are deliberately excluded (see UpgradeTargetInQueue) so the unit diff
-- never mistakes an upgrade for a wave unit.
local function SnapshotOf(factory)
    local counts = {}
    local queue = factory:GetCommandQueue()
    if queue then
        for i, order in queue do
            local bp = order.blueprintId
            if bp and order.commandType == BUILD_FACTORY_COMMAND then
                counts[bp] = (counts[bp] or 0) + (order.count or 1)
            end
        end
    end
    return counts
end

-- The target building of an upgrade order sitting in this factory's queue, or
-- nil. On a pinned factory the order never progresses (build rate 0 + paused),
-- so it waits here until we fulfil or reject it.
local function UpgradeTargetInQueue(factory)
    local queue = factory:GetCommandQueue()
    if queue then
        for i, order in queue do
            if order.commandType == UPGRADE_COMMAND and order.blueprintId then
                return order.blueprintId
            end
        end
    end
    return nil
end

local function SameCounts(a, b)
    for bp, n in a do
        if (b[bp] or 0) ~= n then return false end
    end
    for bp, n in b do
        if (a[bp] or 0) ~= n then return false end
    end
    return true
end

-- Replace a factory's visible queue with exactly `committed`. There is no way to
-- remove a single factory order (no re-issue callback in sim/commands/shared.lua),
-- so this is the engine's own clear-and-reissue pattern (SimUtils.lua:54).
local function RebuildQueue(factory, committed)
    IssueClearCommands({ factory })
    for bp, n in committed do
        IssueBuildFactory({ factory }, bp, n)
    end
end

-- A player clicked the native upgrade button on a factory. The order sits at the
-- front of the pinned queue and never builds on its own, so we fulfil it: charge
-- the tier cost (read from the target building's blueprint, same UnitCost path as
-- everything else) and swap the building for its next tier IN PLACE, carrying the
-- lane binding and the paid wave across. Instant — there is no cancel window, so
-- no upgrade-specific refund path is needed.
--
-- `records` is this army's factory table; we retire the old record and add the
-- new building's, so the caller must iterate a captured key list (see Reconcile),
-- not the live table.
local function TryUpgrade(armyName, brain, records, rec, targetBp)
    local f = rec.factory

    -- Only honour the exact next-tier upgrade for this building. Anything else
    -- (a stale or unexpected order) is dropped, leaving the paid unit queue as-is.
    if targetBp ~= UnitTypes.UpgradeTargetFor(f:GetUnitId()) then
        RebuildQueue(f, rec.committed)
        rec.rebuildPending = true
        return
    end

    local m, e = UnitCost(targetBp)
    local shortOf
    if brain:GetEconomyStored('MASS') < m then
        shortOf = 'mass'
    elseif brain:GetEconomyStored('ENERGY') < e then
        shortOf = 'energy'
    end
    if shortOf then
        Config.PrintTextFor(armyName, 'Not enough ' .. shortOf .. ' to upgrade',
            14, 'ffff2222', 2, 'center')
        RebuildQueue(f, rec.committed)   -- drop the unaffordable upgrade order
        rec.rebuildPending = true
        return
    end

    local pos = f:GetPosition()
    local newF = CreateUnitHPR(targetBp, armyName, pos[1], pos[2], pos[3], 0, 0, 0)
    if not newF then
        WARN('LineWars: upgrade CreateUnitHPR failed for ' .. tostring(targetBp))
        RebuildQueue(f, rec.committed)
        rec.rebuildPending = true
        return
    end

    brain:TakeResource('Mass', m)
    brain:TakeResource('Energy', e)
    Pin(newF)

    local moved = {
        factory = newF,
        lane = rec.lane,
        kind = UnitTypes.KindOfFactory(targetBp),
        committed = rec.committed,
        rebuildPending = true,   -- verify the re-issued wave landed next tick
    }
    records[newF] = moved
    RebuildQueue(newF, rec.committed)   -- re-issue the paid wave onto the new building

    records[f] = nil
    f:Destroy()

    Config.Log(armyName .. ' upgraded a lane ' .. rec.lane .. ' factory to ' ..
        targetBp .. ' (charged m=' .. m .. ' e=' .. e .. ')')
    Config.PrintTextFor(armyName, 'Factory upgraded!', 14, 'ff44ff44', 2, 'center')
end

-- Reconcile one factory's visible queue with what its owner has actually paid
-- for.
--
--   * a pending upgrade order is fulfilled first (TryUpgrade);
--   * cancellations (queue now has fewer of a unit than we've charged for) are
--     refunded;
--   * additions are charged one unit at a time, and only if the player can fully
--     afford that unit right now. A unit they can't afford is REJECTED, not
--     charged-and-floored — this is the fix for the "build for 1 mass" exploit
--     (TakeResource silently floors stored at 0, so charging an unaffordable
--     unit used to cost only whatever you happened to have).
--
-- A rejection is undone by rebuilding this factory's queue from its own paid set,
-- scoped to the single offending factory so other factories — and their lanes —
-- are untouched.
local function ReconcileFactory(armyName, brain, records, rec)
    local f = rec.factory
    Pin(f)

    -- Fulfil a pending upgrade before touching the unit queue: the swap re-issues
    -- the paid wave onto the new building and retires this record.
    local upgradeTo = UpgradeTargetInQueue(f)
    if upgradeTo then
        TryUpgrade(armyName, brain, records, rec, upgradeTo)
        return
    end

    local snapshot = SnapshotOf(f)

    -- If we rebuilt this queue last tick, verify it actually landed before
    -- diffing. Otherwise a rebuild that failed to take reads as "the player
    -- cancelled everything" and refunds the entire standing wave — which is
    -- exactly what the SetBlockCommandQueue bug did to every air factory.
    if rec.rebuildPending then
        rec.rebuildPending = nil
        if not SameCounts(snapshot, rec.committed) then
            rec.rebuildTries = (rec.rebuildTries or 0) + 1
            if rec.rebuildTries <= 3 then
                RebuildQueue(f, rec.committed)
                rec.rebuildPending = true
                return   -- queue is mid-repair; do not diff it this tick
            end
            WARN('LineWars: queue rebuild for ' .. armyName ..
                ' never landed after 3 tries; falling back to refund')
        end
        rec.rebuildTries = nil
    end

    local keys = {}
    for bp in snapshot do keys[bp] = true end
    for bp in rec.committed do keys[bp] = true end

    local newCommitted = {}
    local rejected = false
    local shortOf = 'mass'   -- which resource ran out, for the player's message
    for bp in keys do
        local now = snapshot[bp] or 0
        local had = rec.committed[bp] or 0
        local m, e = UnitCost(bp)
        if now <= had then
            -- Same, or the player cancelled some: refund the removed ones.
            if now < had then
                brain:GiveResource('Mass', m * (had - now))
                brain:GiveResource('Energy', e * (had - now))
                Config.Log(armyName .. ' lane ' .. rec.lane .. ' queue ' .. bp .. ' -' ..
                    (had - now) .. ' (refunded m=' .. (m * (had - now)) .. ')')
            end
            if now > 0 then newCommitted[bp] = now end
        else
            -- Player queued more: pay for each added unit only if affordable.
            local keep = had
            for k = had + 1, now do
                if brain:GetEconomyStored('MASS') < m then
                    rejected, shortOf = true, 'mass'   -- and every later one too
                    break
                elseif brain:GetEconomyStored('ENERGY') < e then
                    rejected, shortOf = true, 'energy'
                    break
                end
                brain:TakeResource('Mass', m)
                brain:TakeResource('Energy', e)
                keep = keep + 1
            end
            if keep > had then
                Config.Log(armyName .. ' lane ' .. rec.lane .. ' queue ' .. bp .. ' +' ..
                    (keep - had) .. ' (charged m=' .. (m * (keep - had)) .. ')')
            end
            if keep > 0 then newCommitted[bp] = keep end
        end
    end

    -- A rejection means the visible queue holds units we didn't charge for.
    -- Rebuild it to exactly the paid set so nothing free ever spawns, and check
    -- next tick that the rebuild actually landed before trusting the queue again.
    if rejected then
        RebuildQueue(f, newCommitted)
        rec.rebuildPending = true
        Config.PrintTextFor(armyName, 'Not enough ' .. shortOf .. ' — unit not queued',
            14, 'ffff2222', 2, 'center')
    end

    rec.committed = newCommitted
end

-- Nothing should ever finish building in a player army: the factories are pinned
-- to build rate 0 AND paused. This is the last line of defence — an assisting
-- ACU, or any engine path that gets an order to completion anyway, would both
-- refund the queue slot (the diff sees the queue shrink) and hand the player a
-- real unit outside the wave. Sweeping any wave-type unit out of the player army
-- makes that self-defeating instead of exploitable.
local function PurgeStrayUnits(brain)
    local category = WaveCategory()
    if not category then
        return
    end
    for i, u in brain:GetListOfUnits(category, false) do
        if not u.Dead then
            u:Destroy()
        end
    end
end

-- `records` is keyed by the factory unit itself, and iteration order over a
-- table keyed by unit userdata follows the hash of the engine handle — which
-- differs per client, so `for f in records` is NOT deterministic across
-- machines. Any code that turns that order into sim state (the round's wave
-- spawn list, or the order factories are charged in when the economy is tight)
-- would therefore diverge between clients and desync. The entity id is a synced
-- per-unit number (identical on every client — the engine round-trips it UI->sim
-- through GetEntityById), so sorting on it gives every client the same factory
-- order to iterate.
--
-- Read `.EntityId`, the field Unit:OnPreCreate caches (sim/Unit.lua:277), NOT
-- f:GetEntityId(). `records` can hold a factory that has already been Destroy()d
-- — AcuRules' no-build sweep destroys factories, and records is only pruned on
-- the next QueueLoop tick — and a moho call on a released entity throws, which
-- would abort the caller (dropping a whole round's waves from WavesForArmy). The
-- cached field survives destruction, and costs no engine call per comparison.
local function SortedFactories(records)
    local flist = {}
    for f, rec in records do
        table.insert(flist, f)
    end
    table.sort(flist, function(a, b) return a.EntityId < b.EntityId end)
    return flist
end

local function Reconcile(armyName)
    local LW = ScenarioInfo.LW
    local brain = GetArmyBrain(armyName)
    local records = LW.Factories[armyName]

    -- Adopt factories that have just finished building.
    for i, f in brain:GetListOfUnits(categories.FACTORY, false) do
        if not f.Dead and f:GetFractionComplete() == 1 and not records[f] then
            Adopt(armyName, records, f)
        end
    end

    -- Drop factories that died (enemy fire, or the no-build-zone sweep) and give
    -- back everything still paid for in them.
    --
    -- Deliberately NOT SortedFactories: this is the one raw traversal of `records`
    -- that is safe, because nothing here depends on order. GiveResource is clamped
    -- addition, which is order-invariant (min(cap, min(cap, s+a)+b) is min(cap,
    -- s+a+b) either way), the costs are small integers that sum exactly in doubles,
    -- and Config.Log touches no sim state. If you add anything order-sensitive
    -- here, sort it — see SortedFactories for why.
    for f, rec in records do
        if f.Dead then
            Refund(brain, rec.committed, armyName .. ' lost a lane ' .. rec.lane .. ' factory')
            records[f] = nil
        end
    end

    -- Capture the current factories before reconciling: an upgrade swap mutates
    -- `records` (retires the old building, adds the new tier), and adding keys to
    -- a table mid-traversal is unsafe. The new building isn't reconciled until
    -- next tick, which is fine — it's freshly pinned with its wave re-issued.
    -- Sorted, not raw-iterated, so a tight-economy tick charges factories in the
    -- same order on every client (see SortedFactories).
    for i, f in SortedFactories(records) do
        local rec = records[f]
        if rec then
            ReconcileFactory(armyName, brain, records, rec)
        end
    end

    PurgeStrayUnits(brain)
end

local function QueueLoop()
    local LW = ScenarioInfo.LW
    while not LW.GameOver do
        for i, armyName in LW.ActivePlayers do
            if not LW.Dead[armyName] then
                Reconcile(armyName)
            end
        end
        WaitSeconds(Config.FactoryQueueTickSeconds)
    end
end

-- This army's standing wave, grouped by the lane it marches down:
--   { { lane = n, units = { blueprintId, ... } }, ... }
-- Persistent — not cleared here.
function WavesForArmy(armyName)
    local records = ScenarioInfo.LW.Factories[armyName] or {}
    -- Build each lane's unit list in a synced factory order. WaveSpawner spawns
    -- these with a Random() position offset per unit, so a client-dependent order
    -- would give the same wave different positions (and entity ids) on each
    -- client — the desync. Sorting the factories by entity id fixes the order;
    -- lanes and each factory's committed set (integer/string keys) already
    -- iterate deterministically.
    local byLane = {}
    local laneOrder = {}
    for i, f in SortedFactories(records) do
        local rec = records[f]
        local units = byLane[rec.lane]
        if not units then
            units = {}
            byLane[rec.lane] = units
            table.insert(laneOrder, rec.lane)
        end
        for bp, n in rec.committed do
            for k = 1, n do
                table.insert(units, bp)
            end
        end
    end
    local waves = {}
    for i, lane in laneOrder do
        table.insert(waves, { lane = lane, units = byLane[lane] })
    end
    return waves
end

function Start()
    local LW = ScenarioInfo.LW
    LW.Factories = {}   -- armyName -> { factory unit -> record }
    for i, armyName in LW.ActivePlayers do
        LW.Factories[armyName] = {}
    end
    ForkThread(QueueLoop)
end
