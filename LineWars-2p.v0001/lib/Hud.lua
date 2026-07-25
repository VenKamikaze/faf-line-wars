-- On-screen furniture: the how-to-play card shown at map start, and the live
-- scoreboard.
--
-- WHY PrintText AND NOT A REAL PANEL. A map cannot ship UI lua, and the
-- objectives panel is not an option either: gamemain.lua:305 only calls
-- objectives2.CreateUI when campaignMode is set, so in a skirmish the panel is
-- never created and Sync.ObjectivesTable goes nowhere. PrintText (sim ->
-- Sync.PrintText -> textdisplay.PrintToScreen) is the whole toolbox a map has,
-- and it is what published maps use for exactly this (see The Great Pass in
-- lua-examples/).
--
-- THE REFRESH RULE THAT MAKES A LIVE BOARD POSSIBLE. textdisplay.PrintToScreen
-- keeps a pool of text controls per screen location and reuses the first
-- INACTIVE one; if every control at that location is still active it appends a
-- NEW one below. A control goes inactive `duration` seconds after it was
-- printed, plus about one more second of alpha fade. So a repeating board must
-- leave a gap:
--
--     ScoreboardPeriodSeconds > ScoreboardLineDuration + 1
--
-- or the board grows by a full set of rows every cycle, forever. The cost of
-- obeying it is that the rows fade out and back in once per cycle; both are
-- Config tunables because how much flicker is worth how much freshness is a
-- taste call best made looking at it in-game.
--
-- Each location has its own control pool, so the scoreboard uses one nothing
-- else writes to. Do NOT move it to 'center' — RoundManager and CapturePoints
-- print there, and interleaved prints would scramble the row order.
local DIR = ScenarioInfo.directory or '/maps/LineWars-2p.v0001/'
local Config = import(DIR .. 'lib/Config.lua')
local Sos = import(DIR .. 'lib/Sos.lua')

-- Deliberately ASCII-only: the in-game font renders a plain hyphen reliably and
-- anything fancier is a gamble. Blank lines are a single space, not '', because
-- an empty text control has no height to stack the next line below.
local INTRO = {
    'LINE WARS - how to play',
    ' ',
    'Build factories with your ACU. Units you queue are NOT built: the queue',
    'IS your standing wave. Pay once, and it respawns every round.',
    'Each wave marches down your lane alone, attacking everything in its way.',
    ' ',
    'Hold the ringed capture points for extra income. Your ACU can also build',
    'point defence and AA on your own half of the lane.',
    'Protect your Core: lose it and you are out. Kill their Core to win.',
    ' ',
}

-- The SOS line depends on two lobby options, so it is built rather than fixed.
local function SosIntroLine()
    local charges = Config.GetSosCharges()
    if charges <= 0 then
        return 'The /sos emergency command is switched off in this game.'
    end
    local what = 'every enemy unit'
    if Config.GetSosTargets() == Config.SosTargetsAll then
        what = 'every unit, yours included,'
    end
    local times = 'once per game'
    if charges > 1 then
        times = charges .. ' times per game'
    end
    return 'Type  /sos  in chat ' .. times .. ' to destroy ' .. what .. ' in your lane.'
end

local function ShowIntro()
    local function Line(text)
        -- Padded, not offset: 'leftcenter' is a fixed anchor flush to the screen
        -- edge, so leading spaces are the only way to inset the card.
        Config.Announce(Config.HudLeftPad .. text, Config.IntroTextSize, 'ffE8E8E8',
            Config.IntroDurationSeconds, Config.IntroLocation)
    end
    for i, line in INTRO do
        Line(line)
    end
    Line(SosIntroLine())
end

--------------------------------------------------------------------------
-- Scoreboard
--------------------------------------------------------------------------

-- Capture points this player's side currently holds in this player's own lane,
-- and how many that lane has in total. Contested points count for nobody. Reads
-- 0/0 until the LW_L<lane>_Cap<n> markers exist in the map (see
-- lib/CapturePoints.lua) — that is "no capture points placed", not a fault.
local function PointsFor(armyName)
    local info = Config.PlayerArmies[armyName]
    local held, total = 0, 0
    local points = ScenarioInfo.LW.CapturePoints
    if points then
        for i, point in points do
            if point.lane == info.lane then
                total = total + 1
                if point.owner == info.side and not point.contested then
                    held = held + 1
                end
            end
        end
    end
    return held, total
end

-- The font is proportional, so columns cannot be aligned by padding; separators
-- are used instead.
local function RowFor(armyName)
    local LW = ScenarioInfo.LW
    local brain = GetArmyBrain(armyName)
    local held, total = PointsFor(armyName)
    local row = ((brain and brain.Nickname) or armyName) ..
        '  |  lane ' .. Config.LaneLabel(Config.PlayerArmies[armyName].lane) ..
        '  |  points ' .. held .. '/' .. total ..
        '  |  SOS ' .. Sos.ChargesFor(armyName)
    if LW.Dead[armyName] then
        row = row .. '  (out)'
    end
    return row
end

local function DrawScoreboard()
    local LW = ScenarioInfo.LW
    local d = Config.ScoreboardLineDuration
    local size = Config.ScoreboardTextSize
    local where = Config.ScoreboardLocation
    -- 'lefttop' anchors flush to the top-left corner, straight under the mass and
    -- energy bars, so the board is pushed clear with blank spacer lines and inset
    -- from the edge with leading spaces. Both are Config values.
    for i = 1, Config.ScoreboardTopSpacerLines do
        Config.Announce(' ', size, 'ffffffff', d, where)
    end
    Config.Announce(Config.HudLeftPad .. 'LINE WARS - round ' .. LW.Round,
        size, 'ffFFD700', d, where)
    -- ActivePlayers is an array built from ListArmies, so every client prints
    -- the same rows in the same order.
    for i, armyName in LW.ActivePlayers do
        local side = Config.PlayerArmies[armyName].side
        local rgb = Config.SideColors[side]
        Config.Announce(Config.HudLeftPad .. RowFor(armyName), size,
            string.format('ff%02X%02X%02X', rgb[1], rgb[2], rgb[3]), d, where)
    end
end

-- Paced in REAL seconds, not with WaitSeconds. WaitSeconds counts game time, so
-- at 10x sim speed a 12-second period elapses in 1.2 real seconds while
-- textdisplay's fade still takes the full ScoreboardLineDuration + 1 — which
-- breaks "period > duration + 1" and makes PrintToScreen append a whole new set
-- of rows every cycle. That is exactly the repeated-scoreboard symptom seen when
-- the sim speed is raised. The wait below only sets how often the loop *checks*;
-- whether a repaint is due is decided against the wall clock.
local function ScoreboardLoop()
    local LW = ScenarioInfo.LW
    -- Wait for the gate rather than letting the first cycles queue: a queued
    -- batch flushes at the moment the gate opens, which would land on top of
    -- the cycle that follows it and break the same rule.
    Config.WaitForHud()
    local lastDrawn = nil
    while not LW.GameOver do
        local now = Config.RealSeconds()
        if not lastDrawn or (now - lastDrawn) >= Config.ScoreboardPeriodSeconds then
            DrawScoreboard()
            lastDrawn = now
        end
        WaitSeconds(Config.ScoreboardPollSeconds)
    end
end

function Start()
    ShowIntro()          -- queued by the gate; the 30s starts when it is drawn
    ForkThread(ScoreboardLoop)
end
