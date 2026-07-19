version = 3 -- Lua Version. Dont touch this
ScenarioInfo = {
    name = "Survival The Great Pass",
    description = "4 Player Survival, enemies come from the bottom right and follow the path. Uses the Genesis Survival script, with mod support!",
    preview = '',
    map_version = 5,
    type = 'skirmish',
    starts = true,
    size = {512, 512},
    reclaim = {0, 0},
    map = '/maps/survival_the_great_pass.v0005/Survival_The_Great_Pass.scmap',
    save = '/maps/survival_the_great_pass.v0005/Survival_The_Great_Pass_save.lua',
    script = '/maps/survival_the_great_pass.v0005/Survival_The_Great_Pass_script.lua',
    directory = '/maps/survival_the_great_pass.v0005/',
    norushradius = 40,
    Configurations = {
        ['standard'] = {
            teams = {
                {
                    name = 'FFA',
                    armies = {'ARMY_1', 'ARMY_2', 'ARMY_3', 'ARMY_4'}
                },
            },
            customprops = {
                ['ExtraArmies'] = STRING( 'ARMY_17 NEUTRAL_CIVILIAN ARMY_SURVIVAL_ALLY ARMY_SURVIVAL_ENEMY' ),
            },
        },
    },
}
