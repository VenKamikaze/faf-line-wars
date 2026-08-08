-- DEAD CODE, kept as the record of the abandoned spawner-structure design.
-- Nothing imports this file: the factory queue replaced spawners, the blueprint
-- file that would create these units is `.bp.disabled`, and the last consumer
-- (Economy.lua's income model 1) went away with the "Income model" lobby option.
--
-- Spawner definitions: which structures players can build, and what each one
-- adds to the wave every round. This is the balance heart of the map — add a
-- DefSpawner block per unit type and everything else (build restrictions,
-- wave spawning, spawner income, build-menu text and icons) picks it up
-- automatically.
--
-- Spawners are *clones* of the T1 Power Generator rather than stock structures
-- reused as-is: units/LineWars_spawners_unit.bp reads this file at
-- blueprint-load time, copies that faction's power-gen blueprint, and stamps
-- our own id, cost, health and description onto it. That means a spawner type
-- costs nothing but a block here — we are no longer limited to the supply of
-- inert stock structures, and each type prices independently.
--
-- The visible trade-off: the 48x48 build-button art is looked up by blueprint
-- id, so our clones fall back to the generic button background. The glyph that
-- distinguishes them is `icon` below, drawn as an overlay. See the .bp file.
--
-- That file runs in the blueprint loader, long before the sim exists — keep
-- this module free of imports and of anything that touches sim globals at
-- load time (`categories` is only read inside AllowedCategories, which the
-- blueprint loader never calls).

Spawners = {}   -- flat map: structure blueprint id -> definition

local FACTIONS = { 'UEF', 'Aeon', 'Cybran', 'Seraphim' }

-- Every spawner is built from that faction's T1 Power Generator: same mesh,
-- same footprint, same faction styling, so no custom art is needed and all
-- spawners read as one uniform chassis.
local CHASSIS = {
    UEF = 'ueb1101', Aeon = 'uab1101', Cybran = 'urb1101', Seraphim = 'xsb1101',
}

-- def = {
--   key        short slug, used to build the per-faction blueprint ids
--   name       display name; shown in the unit-info panel and as the tooltip lead
--   blurb      short note on the unit's role, appended to the tooltip
--   cost       mass cost to build (energy and build time derive from it)
--   health     structure hit points
--   income     mass/second added to owner's income (no longer read by anything)
--   icon       strategic icon, drawn on the build button and on the battlefield.
--              Names come from /textures/ui/common/game/strategicicons — use the
--              icon of the unit produced, since the button art cannot change.
--   spawns     list of groups produced each round:
--              { count, label, units = { <faction> = unit blueprint } }
-- }
local function DefSpawner(def)
    -- Build the tooltip text from the same numbers the wave spawner reads, so
    -- the build menu can never drift from the balance table.
    local parts = {}
    for i, group in def.spawns do
        table.insert(parts, group.count .. 'x ' .. group.label)
    end
    local description = def.name .. ': ' .. table.concat(parts, ' + ')
        .. ' per round, +' .. def.income .. ' mass/s. ' .. def.blurb .. '.'

    for i, faction in FACTIONS do
        -- flatten to the { blueprint, count } pairs WaveSpawner iterates
        local spawns = {}
        for j, group in def.spawns do
            table.insert(spawns, { group.units[faction], group.count })
        end
        -- blueprint ids are lowercased by the loader; keep ours lowercase so
        -- the `categories.<id>` lookup in AllowedCategories matches.
        local id = 'lwb_' .. def.key .. '_' .. string.lower(faction)
        Spawners[id] = {
            name = def.name,
            description = description,
            icon = def.icon,
            income = def.income,
            spawns = spawns,
            -- consumed by units/LineWars_spawners_unit.bp only
            chassis = CHASSIS[faction],
            cost = def.cost,
            health = def.health,
        }
    end
end

-- 2x Light Assault Bots
DefSpawner {
    key = 'bot',
    name = 'Assault Bot Spawner',
    blurb = 'Cheap swarm chaff',
    cost = 75,
    health = 600,
    income = 0.4,
    icon = 'icon_bot1_directfire',
    spawns = {
        { count = 2, label = 'Light Assault Bot',
          units = { UEF = 'uel0106', Aeon = 'ual0106', Cybran = 'url0106', Seraphim = 'xsl0106' } },
    },
}

-- 1x T1 Tank
DefSpawner {
    key = 'tank',
    name = 'Tank Spawner',
    blurb = 'Durable line unit',
    cost = 120,
    health = 900,
    income = 0.8,
    icon = 'icon_land1_directfire',
    spawns = {
        { count = 1, label = 'Tank',
          units = { UEF = 'uel0201', Aeon = 'ual0201', Cybran = 'url0107', Seraphim = 'xsl0201' } },
    },
}

-- 1x Mobile Light Artillery
DefSpawner {
    key = 'arty',
    name = 'Artillery Spawner',
    blurb = 'Outranges massed chaff',
    cost = 100,
    health = 600,
    income = 0.6,
    icon = 'icon_land1_artillery',
    spawns = {
        { count = 1, label = 'Mobile Artillery',
          units = { UEF = 'uel0103', Aeon = 'ual0103', Cybran = 'url0103', Seraphim = 'xsl0103' } },
    },
}

-- 1x T1 Mobile AA. NOTE: these units are anti-air only (their weapon is
-- RangeCategory UWRC_AntiAir), so they cannot engage anything on the ground.
-- Until a spawner produces air units this is a dead purchase — see README.
DefSpawner {
    key = 'aa',
    name = 'Anti-Air Spawner',
    blurb = 'Escort cover; cannot hit ground targets',
    cost = 110,
    health = 600,
    income = 0.5,
    icon = 'icon_land1_antiair',
    spawns = {
        { count = 1, label = 'Mobile AA',
          units = { UEF = 'uel0104', Aeon = 'ual0104', Cybran = 'url0104', Seraphim = 'xsl0104' } },
    },
}

-- TODO: more types — air, shields-in-wave, tanky T2, experimentals as a
-- late-game mass sink. Follow the same DefSpawner pattern.

-- Category union of everything players are allowed to build; used to restrict
-- the ACU's build menu to exactly the spawner set.
function AllowedCategories()
    local allowed = categories.COMMAND
    for bp, def in Spawners do
        -- blueprint-id categories are lowercase in FAF (categories.ueb1101)
        if categories[bp] then
            allowed = allowed + categories[bp]
        else
            WARN('LineWars: no category for spawner blueprint ' .. bp)
        end
    end
    return allowed
end
