-- Sim-side chat commands (the "/sos" trigger, and anything added later).
--
-- WHY THIS IS POSSIBLE AT ALL. Chat is a UI feature, and a MAP cannot ship UI
-- lua (only mods can), so there is no direct way to read what a player typed.
-- But the stock UI already forwards every chat message into the sim: for each
-- message it receives, `ReceiveChat` fires a SimCallback
-- (lua/ui/game/chat.lua:810)
--
--     SimCallback({Func="GiveResourcesToPlayer",
--                  Args={From=GetFocusArmy(), To=GetFocusArmy(), Mass=0,
--                        Energy=0, Sender=sender, Msg=msg}}, true)
--
-- whose only purpose is to record chat into the replay. Sim-side that lands in
-- `SimUtils.GiveResourcesToPlayer`, which calls `SendChatToReplay(data)` first
-- (lua/SimUtils.lua:1463-1464) and then returns immediately, because From == To.
-- So `data.Sender` (nickname) and `data.Msg.text` (what was typed) are visible
-- to sim code, and the resource transfer itself is always a no-op.
--
-- THE HOOK. `SendChatToReplay` is called unqualified from inside
-- `GiveResourcesToPlayer`, i.e. it is looked up in SimUtils' module environment
-- at call time, and `import()` returns exactly that environment table. So
-- replacing `SimUtils.SendChatToReplay` intercepts every chat message without
-- touching game files. (`import` lowercases the path before caching, so the
-- casing used here cannot fork a second module instance.) Hooking the callback
-- table itself is NOT possible: `Callbacks` in SimCallbacks.lua is a file-local
-- and captured its function reference at load time.
--
-- HOW MANY TIMES IT FIRES: ONCE PER RECEIVING CLIENT — CONFIRMED, and the
-- dedupe below is load-bearing, not a precaution. `ReceiveChat` runs on every
-- client that received the message and each issues its own SimCallback (same
-- Sender/Msg, different `data.From`). Counting "LineWars: chat command" lines
-- settled it: in the 5-player game 27565454 every single `/sos` logged exactly
-- 5 times (one player's 4 uses produced 20 lines); in solo game 27570392 every
-- `/acu` logged once. Without the dedupe, `/sos` would have fired five times
-- per use in that game. ChatCommandDedupeSeconds = 0.5 was enough: all copies
-- arrive within the same tick, and exactly one dispatch happened per use.
--
-- DETERMINISM. SimCallbacks arrive through the lockstep command stream, so every
-- client's sim sees the same messages in the same order; the data we read
-- (Sender, text) is identical everywhere. GetFocusArmy() is never consulted.
local DIR = ScenarioInfo.directory or '/maps/LineWars-2p.v0001/'
local Config = import(DIR .. 'lib/Config.lua')
local SimUtils = import('/lua/simutils.lua')

-- command string (lowercase, e.g. '/sos') -> { fn = function(armyName, args), args = bool }
local handlers = {}
local installed = false
-- dedupe: 'sender|command|args' -> game time of the last accepted dispatch
local lastAccepted = {}

-- Register a chat command. `command` must be lowercase; the typed text has to
-- match it exactly once trimmed and lowercased, so merely discussing "/sos" in
-- a sentence never fires it.
--
-- `takesArgs` relaxes that to "first word matches", and the rest of the line is
-- passed to the handler as a second string argument (empty when nothing
-- followed). Only pass it for commands that really read arguments: it is what
-- makes "/acu 4 6" reachable, and it is also what would let a sentence STARTING
-- with the command word fire it, which is why it is not the default.
function Register(command, fn, takesArgs)
    handlers[command] = { fn = fn, args = takesArgs }
end

local function Trim(s)
    local trimmed = string.gsub(s, '^%s*(.-)%s*$', '%1')
    return trimmed
end

-- Nicknames are what the chat payload carries; map one back to a player army.
-- Observers and any non-player sender resolve to nil and are ignored.
local function ArmyForNickname(nickname)
    for i, armyName in ScenarioInfo.LW.ActivePlayers do
        local brain = GetArmyBrain(armyName)
        if brain and brain.Nickname == nickname then
            return armyName
        end
    end
    return nil
end

-- Called for every chat message the sim sees. This function must never throw:
-- it runs inside the engine's callback for replay chat logging, and an error
-- here would take that down with it. Hence the nil checks on everything read
-- out of `data`, and the forked dispatch at the end.
local function OnChatMessage(data)
    if not data or not data.Sender or type(data.Msg) ~= 'table' then
        return
    end
    local text = data.Msg.text
    if type(text) ~= 'string' then
        return
    end
    local line = Trim(string.lower(text))
    local command, args = line, ''
    local entry = handlers[command]
    if not entry then
        -- Not an exact match. Try the first word, and accept it only if that
        -- command was registered as taking arguments — an exact-match command
        -- must stay exact.
        local _, _, first, rest = string.find(line, '^(%S+)%s+(.*)$')
        if first then
            local candidate = handlers[first]
            if candidate and candidate.args then
                command, args, entry = first, Trim(rest), candidate
            end
        end
    end
    if not entry then
        return
    end

    -- Logged before the dedupe so the log shows how many copies really arrive.
    Config.Log('chat command "' .. command .. '" args "' .. args .. '" from ' ..
        tostring(data.Sender))

    local now = GetGameTimeSeconds()
    local key = tostring(data.Sender) .. '|' .. command .. '|' .. args
    local seen = lastAccepted[key]
    if seen and now - seen < Config.ChatCommandDedupeSeconds then
        return
    end
    lastAccepted[key] = now

    local armyName = ArmyForNickname(data.Sender)
    if not armyName then
        Config.Log('ignoring chat command from non-player sender ' .. tostring(data.Sender))
        return
    end
    -- Forked, not called: a handler that throws (a moho call on a unit that just
    -- died, say) would otherwise take down the engine's replay-chat logging for
    -- the rest of the game, and a handler that does real work — /sos can kill
    -- hundreds of units — would do it inline inside an engine callback. Forks
    -- are scheduled in the deterministic order the callbacks arrive, so this
    -- costs nothing on the desync side.
    ForkThread(entry.fn, armyName, args)
end

function Start()
    if installed then
        return
    end
    local original = SimUtils.SendChatToReplay
    if type(original) ~= 'function' then
        WARN('LineWars: SimUtils.SendChatToReplay missing; chat commands disabled')
        return
    end
    SimUtils.SendChatToReplay = function(data)
        original(data)
        OnChatMessage(data)
    end
    installed = true
    Config.Log('chat command hook installed')
end
