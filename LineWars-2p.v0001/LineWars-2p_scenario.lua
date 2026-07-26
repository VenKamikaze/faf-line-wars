version = 3 -- Lua Version. Dont touch this
ScenarioInfo = {
    name = "Line Wars",
    description = "<LOC LineWars_Description>Line Wars: build spawner structures during each timed round. When the round ends, every spawner produces its units, which march down your lane and attack everything in their path. Destroy the enemy Core at the end of their lane before they destroy yours. Each lane is a mirrored 1v1: positions 1v2, 3v4, 5v6.",
    preview = '',
    map_version = 1,
    type = 'skirmish',
    starts = true,
    size = {512, 512},
    reclaim = {29754, 0},
    map = '/maps/LineWars-2p.v0001/LineWars-2p.scmap',
    save = '/maps/LineWars-2p.v0001/LineWars-2p_save.lua',
    script = '/maps/LineWars-2p.v0001/LineWars-2p_script.lua',
    norushradius = 0,
    Configurations = {
        ['standard'] = {
            teams = {
                {
                    name = 'FFA',
                    armies = {'ARMY_1', 'ARMY_2', 'ARMY_3', 'ARMY_4', 'ARMY_5', 'ARMY_6'}
                },
            },
            customprops = {
                ['ExtraArmies'] = STRING( 'ARMY_WAVE_1 ARMY_WAVE_2 ARMY_WAVE_3 ARMY_WAVE_4 ARMY_WAVE_5 ARMY_WAVE_6' ),
            },
        },
    },
}
