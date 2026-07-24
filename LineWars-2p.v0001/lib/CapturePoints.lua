-- Lane capture points (the "static economy" objective from FACTORY-QUEUE-DESIGN.md).
--
-- Blank markers named LW_L<lane>_Cap<n> (per lane, probed n = 1.. upward, stop
-- at first gap) each define a circular capture zone of fixed radius
-- (Config.CapturePointRadius). Markers are read only for lanes that have a
-- player, so an empty lane's capture points never activate.
--
-- INCOME IS LANE-LOCAL: while a side controls a lane's point, only that side's
-- player IN THAT LANE earns the extra mass + energy (the 1v1 duellist), not
-- distant teammates. Presence/control is still side-based, so a reinforcing
-- ally's wave can capture a point — but the payout follows the lane owner.
--
-- CONTROL IS STICKY (Mick's spec):
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
local function DrawRing(center, radius, color)
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

    -- Announce a genuine change of controlling side, to that side only.
    if point.owner and point.owner ~= point.announced then
        Config.PrintTextForSide(point.owner,
            'Captured a lane ' .. point.lane .. ' point!', 14, 'ff44ff44', 4, 'center')
        point.announced = point.owner
    elseif not point.owner then
        point.announced = nil
    end
end

-- Pay a controlled point's income to the controlling side's player IN THIS LANE
-- (lane-local), if that player is alive. A point held by a reinforcing ally when
-- the lane's own player is dead pays nobody.
local function GrantIncome(point, tick)
    if not point.owner or point.contested then
        return
    end
    local armyName = Config.ArmyInLane(point.lane, point.owner)
    if armyName and not ScenarioInfo.LW.Dead[armyName] then
        local brain = GetArmyBrain(armyName)
        brain:GiveResource('Mass', Config.CapturePointMass * tick)
        brain:GiveResource('Energy', Config.CapturePointEnergy * tick)
    end
end

--------------------------------------------------------------------------
-- Discovery + loop
--------------------------------------------------------------------------
-- Lanes are 1..3 (Config.PlayerArmies). A lane's capture markers are read only
-- if that lane has a player, so unoccupied lanes contribute no active points.
local LANE_COUNT = 3
local function DiscoverPoints()
    local points = {}
    for lane = 1, LANE_COUNT do
        if Config.ArmyInLane(lane, 'A') or Config.ArmyInLane(lane, 'B') then
            local n = 1
            while true do
                local marker = Config.GetMarker(Config.CaptureMarker(lane, n))
                if not marker then
                    break
                end
                table.insert(points, {
                    center = marker.position,
                    lane = lane,
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
    while not LW.GameOver do
        for i, point in LW.CapturePoints do
            UpdatePoint(point, radius)
            GrantIncome(point, tick)
            DrawRing(point.center, radius, ColorFor(point))
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
        ', +' .. Config.CapturePointMass .. ' mass/s each)')
    ForkThread(CaptureLoop)
end
