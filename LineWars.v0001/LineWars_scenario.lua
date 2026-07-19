version = 3
-- Line Wars scenario file.
-- NOTE: `size` and `map_version` must match the .scmap once it exists.
-- If FAFMapEditor regenerates this file, re-add `customprops.ExtraArmies`
-- and keep script/save/map paths pointing at this folder.
ScenarioInfo = {
  Configurations = {
    standard = {
      customprops = {
        ExtraArmies = "ARMY_WAVE_1 ARMY_WAVE_2 ARMY_WAVE_3 ARMY_WAVE_4 ARMY_WAVE_5 ARMY_WAVE_6"
      },
      teams = {
        {
          armies = {
            "ARMY_1",
            "ARMY_2",
            "ARMY_3",
            "ARMY_4",
            "ARMY_5",
            "ARMY_6"
          },
          name = "FFA"
        }
      }
    }
  },
  description = "<LOC LineWars_Description>Line Wars: build spawner structures during each timed round. When the round ends, every spawner produces its units, which march down your lane and attack everything in their path. Destroy the enemy Core at the end of their lane before they destroy yours. Each lane is a mirrored 1v1: positions 1v2, 3v4, 5v6.",
  map = "/maps/LineWars.v0001/LineWars.scmap",
  map_version = 1,
  name = "Line Wars",
  norushradius = 0,
  preview = "",
  save = "/maps/LineWars.v0001/LineWars_save.lua",
  script = "/maps/LineWars.v0001/LineWars_script.lua",
  size = { 1024, 512 },
  starts = true,
  type = "skirmish"
}
