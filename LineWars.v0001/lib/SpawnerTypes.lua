-- Spawner definitions: which structures players can build, and what each one
-- adds to the wave every round. This is the balance heart of the map — add a
-- DefSpawner block per unit type and everything else (build restrictions,
-- wave spawning, spawner income) picks it up automatically.
--
-- v1 uses stock structures as proxies so no custom blueprints are needed:
-- each faction builds its own variant and spawns its own faction's units.
-- Longer term these become custom blueprints in a units/ folder.

Spawners = {}   -- flat map: structure blueprint id -> definition

-- def = {
--   name       display name for announcements/UI
--   income     mass/second added to owner's income (income model 1 only)
--   structures per-faction structure blueprint (the thing you build)
--   spawns     per-faction list of { unitBlueprint, count } produced each round
-- }
local function DefSpawner(def)
    for faction, structureBp in def.structures do
        Spawners[structureBp] = {
            name = def.name,
            income = def.income,
            spawns = def.spawns[faction],
        }
    end
end

-- T1 Power Generator -> 2x Light Assault Bots (cheap swarm chaff)
DefSpawner {
    name = 'Assault Bots',
    income = 0.4,
    structures = { UEF = 'ueb1101', Aeon = 'uab1101', Cybran = 'urb1101', Seraphim = 'xsb1101' },
    spawns = {
        UEF      = { { 'uel0106', 2 } },
        Aeon     = { { 'ual0106', 2 } },
        Cybran   = { { 'url0106', 2 } },
        Seraphim = { { 'xsl0106', 2 } },
    },
}

-- T1 Land Factory -> 1x T1 Tank (durable line unit)
DefSpawner {
    name = 'Tanks',
    income = 0.8,
    structures = { UEF = 'ueb0101', Aeon = 'uab0101', Cybran = 'urb0101', Seraphim = 'xsb0101' },
    spawns = {
        UEF      = { { 'uel0201', 1 } },
        Aeon     = { { 'ual0201', 1 } },
        Cybran   = { { 'url0107', 1 } },
        Seraphim = { { 'xsl0201', 1 } },
    },
}

-- T1 Point Defense -> 1x Mobile Artillery (counters massed chaff)
-- NOTE: the structure itself can still shoot; keep build zones out of weapon
-- range of the lane, or swap this proxy for something unarmed.
DefSpawner {
    name = 'Artillery',
    income = 0.6,
    structures = { UEF = 'ueb2101', Aeon = 'uab2101', Cybran = 'urb2101', Seraphim = 'xsb2101' },
    spawns = {
        UEF      = { { 'uel0103', 1 } },
        Aeon     = { { 'ual0103', 1 } },
        Cybran   = { { 'url0103', 1 } },
        Seraphim = { { 'xsl0103', 1 } },
    },
}

-- TODO: more types — anti-air, shields-in-wave, tanky T2, experimentals as a
-- late-game mass sink. Follow the same DefSpawner pattern.

-- Category union of everything players are allowed to build; used to restrict
-- the ACU's build menu to exactly the spawner set.
function AllowedCategories()
    local allowed = categories.COMMAND
    for bp, def in Spawners do
        allowed = allowed + categories[string.upper(bp)]
    end
    return allowed
end
