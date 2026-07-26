-- Lane capture points (the "static economy" objective from FACTORY-QUEUE-DESIGN.md).
--
-- Blank markers named LW_L<lane>_Cap<n> (per lane, probed n = 1.. upward, stop
-- at first gap) each define a circular capture zone of fixed radius
-- (Config.CapturePointRadius). Markers are read only for lanes that have a
-- player, so an empty lane's capture points never activate.
--
-- HIGH-VALUE POINTS: up to three '+' may be appended to a marker name to
-- multiply its payout (both mass and energy) — LW_L1_Cap4 pays x1, LW_L1_Cap4+
-- x2, LW_L1_Cap4++ x3, LW_L1_Cap4+++ x4. The suffix is part of the marker name,
-- so each n is probed in all four forms (a renamed Cap4+ must not read as a gap
-- at n = 4). A multiplied point draws its ring with that many concentric lines,
-- so players can tell it apart at a glance.
--
-- INCOME IS LANE-LOCAL: while a side controls a lane's point, only that side's
-- player IN THAT LANE earns the extra mass + energy (the 1v1 duellist), not
-- distant teammates. Presence/control is still side-based, so a reinforcing
-- ally's wave can capture a point — but the payout follows the lane owner.
--
-- CONTROL IS STICKY (Kamikaze's spec):
--   * A point is captured the instant one side has a mobile land unit inside the
--     circle and the other side does not — the unit only has to PASS THROUGH, it
--     does not have to stay.
--   * Once captured, the point stays that side's until it is either CONTESTED
--     (both sides have a land unit inside at once) or taken by the other side.
--   * Contested suspends income and clears control (no owner) until one side is
--     alone in the circle again.
--
-- Detection reuses King of the Hill's pattern (lua-examples/mods/King of the
-- Hill/modules/sim-hill.lua): brain:GetUnitsAroundPoint(cat, centre, radius,
-- 'Ally'). Querying from any one living brain on a side returns every same-side
-- unit (players + their ARMY_WAVE_n armies are all mutually allied), so one call
-- per side answers "is this side present?". Air waves are AIR, not LAND, so they
-- never capture, and the ACU (COMMAND) is excluded too — only marching land waves
-- capture.
--
-- Visual: a debug-draw ring (DrawLine segments, terrain-following) coloured by
-- controller — red for A, blue for B (from Config.SideColors, single source),
-- yellow contested, grey neutral. This is exactly how KotH shows its hill and it
-- renders for all clients in a normal game. There is no per-unit colour override
-- in FA (colour is per-army), so a ring is the low-risk visual; a physical
-- colour-flipping structure would need ChangeUnitArmy on every capture.
local DIR = ScenarioInfo.directory or '/maps/LineWars-2p.v0001/'
local Config = import(DIR .. 'lib/Config.lua')

-- Mobile land units only: excludes air (not LAND), structures (not MOBILE) and
-- the ACU (COMMAND) — capturing is about your marching waves, not parking your
-- commander on a point. Computed lazily because `categories` is a sim global not
-- guaranteed present at module-import time.
local landCategory
local function LandCategory()
    if not landCategory then
        landCategory = categories.LAND * categories.MOBILE - categories.COMMAND
    end
    return landCategory
end

--------------------------------------------------------------------------
-- Ring drawing (terrain-following, one frame — must be redrawn every tick)
--------------------------------------------------------------------------
local CONTESTED_COLOR = 'ffffcc00'   -- yellow
local NEUTRAL_COLOR   = 'ff888888'   -- grey

-- AARRGGBB hex from a Config.SideColors {r,g,b}, so the ring can never drift
-- from the wave-army colours.
local function SideHex(side)
    local rgb = Config.SideColors[side]
    return string.format('ff%02X%02X%02X', rgb[1], rgb[2], rgb[3])
end

local RING_SEGMENTS = 48
local RING_LINE_SPACING = 0.4   -- world units between the lines of a bold ring

local function DrawCircle(center, radius, color)
    local twoPi = 6.2831853
    local prev
    for k = 0, RING_SEGMENTS do
        local a = k / RING_SEGMENTS * twoPi
        local x = center[1] + radius * math.cos(a)
        local z = center[3] + radius * math.sin(a)
        local p = { x, GetSurfaceHeight(x, z), z }
        if prev then
            DrawLine(prev, p, color)
        end
        prev = p
    end
end

-- `lines` concentric circles drawn just inside `radius`, so a x2/x3/x4 point
-- reads as a visibly bolder ring without changing the capture radius itself.
local function DrawRing(center, radius, color, lines)
    for k = 0, (lines or 1) - 1 do
        DrawCircle(center, radius - k * RING_LINE_SPACING, color)
    end
end

local function ColorFor(point)
    if point.contested then
        return CONTESTED_COLOR
    elseif point.owner == 'A' then
        return SideHex('A')
    elseif point.owner == 'B' then
        return SideHex('B')
    end
    return NEUTRAL_COLOR
end

--------------------------------------------------------------------------
-- Control
--------------------------------------------------------------------------

-- Is any living player on `side` fielding a mobile land unit inside the circle?
local function SidePresent(side, center, radius)
    local LW = ScenarioInfo.LW
    for i, armyName in LW.ActivePlayers do
        if not LW.Dead[armyName] and Config.PlayerArmies[armyName].side == side then
            local brain = GetArmyBrain(armyName)
            -- 'Ally' returns this side's units across all same-side players and
            -- their wave armies, so the first living brain answers for the side.
            local units = brain:GetUnitsAroundPoint(LandCategory(), center, radius, 'Ally')
            return units and table.getn(units) > 0
        end
    end
    return false
end

-- Advance one point's control state for this tick. Latches (sticky) when the
-- circle empties; clears on contest.
local function UpdatePoint(point, radius)
    local aPresent = SidePresent('A', point.center, radius)
    local bPresent = SidePresent('B', point.center, radius)

    if aPresent and bPresent then
        point.owner = nil
        point.contested = true
    elseif aPresent then
        point.owner = 'A'
        point.contested = false
    elseif bPresent then
        point.owner = 'B'
        point.contested = false
    else
        point.contested = false   -- owner latched unchanged
    end

    -- Announce a genuine change of controlling side, to that side only. Skipped
    -- entirely while the PrintText gate is shut: the lane towers stand on the map
    -- from tick 0, so with a dozen markers the opening seconds would otherwise
    -- queue a pile of capture messages that all flush onto 'center' in one tick.
    -- Control and income below are unaffected — only the message is dropped.
    if point.owner and point.owner ~= point.announced then
        if Config.HudIsOpen() then
            local worth = ''
            if point.multiplier > 1 then
                worth = ' (x' .. point.multiplier .. ' income)'
            end
            Config.PrintTextForSide(point.owner,
                'Captured a lane ' .. point.lane .. ' point!' .. worth, 14, 'ff44ff44', 4, 'center')
        end
        point.announced = point.owner
    elseif not point.owner then
        point.announced = nil
    end
end

-- Pay a controlled point's income to the controlling side's player IN THIS LANE
-- (lane-local), if that player is alive. A point held by a reinforcing ally when
-- the lane's own player is dead pays nobody.
-- `scale` is the "Capture point income" lobby option's multiplier, read once per
-- loop rather than per point.
local function GrantIncome(point, tick, scale)
    if not point.owner or point.contested then
        return
    end
    local armyName = Config.ArmyInLane(point.lane, point.owner)
    if armyName and not ScenarioInfo.LW.Dead[armyName] then
        local brain = GetArmyBrain(armyName)
        brain:GiveResource('Mass', Config.CapturePointMass * point.multiplier * scale * tick)
        brain:GiveResource('Energy', Config.CapturePointEnergy * point.multiplier * scale * tick)
    end
end

--------------------------------------------------------------------------
-- Discovery + loop
--------------------------------------------------------------------------
-- Lanes are 1..3 (Config.PlayerArmies). A lane's capture markers are read only
-- if that lane has a player, so unoccupied lanes contribute no active points.
local function DiscoverPoints()
    local points = {}
    for lane = 1, Config.LaneCount do
        if Config.ArmyInLane(lane, 'A') or Config.ArmyInLane(lane, 'B') then
            local n = 1
            while true do
                -- Each n exists in exactly one of its '+' forms; probe them all
                -- so a high-value point isn't mistaken for the end of the lane's
                -- run. First match wins (a duplicated n takes the plainest).
                local marker, plus
                for p = 0, Config.CapturePointMaxPlus do
                    marker = Config.GetMarker(Config.CaptureMarker(lane, n, p))
                    if marker then
                        plus = p
                        break
                    end
                end
                if not marker then
                    break
                end
                table.insert(points, {
                    center = marker.position,
                    lane = lane,
                    -- x1 plain, x2 for '+', x3 '++', x4 '+++'
                    multiplier = plus + 1,
                    owner = nil,
                    contested = false,
                })
                n = n + 1
            end
        end
    end
    return points
end

local function CaptureLoop()
    local LW = ScenarioInfo.LW
    local tick = Config.CapturePointTickSeconds
    local radius = Config.CapturePointRadius
    local scale = Config.GetCaptureIncomeScale()
    while not LW.GameOver do
        for i, point in LW.CapturePoints do
            UpdatePoint(point, radius)
            GrantIncome(point, tick, scale)
            DrawRing(point.center, radius, ColorFor(point), point.multiplier)
        end
        WaitSeconds(tick)
    end
end

function Start()
    local LW = ScenarioInfo.LW
    LW.CapturePoints = DiscoverPoints()
    local n = table.getn(LW.CapturePoints)
    if n == 0 then
        Config.Log('no LW_Cap markers found; capture points disabled')
        return
    end
    Config.Log('capture points: ' .. n .. ' (radius ' .. Config.CapturePointRadius ..
        ', +' .. (Config.CapturePointMass * Config.GetCaptureIncomeScale()) ..
        ' mass/s each at x1, income scale ' .. Config.GetCaptureIncomeScale() .. ')')
    for i, point in LW.CapturePoints do
        if point.multiplier > 1 then
            Config.Log('  lane ' .. point.lane .. ' high-value point: x' .. point.multiplier ..
                ' (+' .. (Config.CapturePointMass * point.multiplier *
                Config.GetCaptureIncomeScale()) .. ' mass/s, +' ..
                (Config.CapturePointEnergy * point.multiplier *
                Config.GetCaptureIncomeScale()) .. ' energy/s)')
        end
    end
    ForkThread(CaptureLoop)
end
