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
-- HOW MANY TIMES IT FIRES. `ReceiveChat` runs on every client that received the
-- message, and each one issues its own SimCallback, so the sim may see the same
-- message once per receiving client (with a different `data.From` each time,
-- but the same Sender/Msg). This is NOT confirmed either way in-game yet, so
-- the dispatcher dedupes on sender + text + game time, and the Config.Log line
-- below prints on EVERY invocation: grep "LineWars: chat command" in the game
-- log and count the lines to settle it.
--
-- DETERMINISM. SimCallbacks arrive through the lockstep command stream, so every
-- client's sim sees the same messages in the same order; the data we read
-- (Sender, text) is identical everywhere. GetFocusArmy() is never consulted.
local DIR = ScenarioInfo.directory or '/maps/LineWars-2p.v0001/'
local Config = import(DIR .. 'lib/Config.lua')
local SimUtils = import('/lua/simutils.lua')

-- command string (lowercase, e.g. '/sos') -> function(armyName)
local handlers = {}
local installed = false
-- dedupe: 'sender|command' -> game time of the last accepted dispatch
local lastAccepted = {}

-- Register a chat command. `command` must be lowercase; the typed text has to
-- match it exactly once trimmed and lowercased, so merely discussing "/sos" in
-- a sentence never fires it.
function Register(command, fn)
    handlers[command] = fn
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
    local command = Trim(string.lower(text))
    local fn = handlers[command]
    if not fn then
        return
    end

    -- Logged before the dedupe so the log shows how many copies really arrive.
    Config.Log('chat command "' .. command .. '" from ' .. tostring(data.Sender))

    local now = GetGameTimeSeconds()
    local key = tostring(data.Sender) .. '|' .. command
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
    ForkThread(fn, armyName)
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
