-- Lobby options for Line Wars.
-- The intended default is listed first in each `values` table AND given as
-- `default`, so the right thing happens whether the lobby treats `default`
-- as a value key or an index.
options =
{
    {
        default = 1,
        label = "Income model",
        help = "How players earn the mass used to build spawner structures",
        key = 'opt_lw_income_model',
        pref = 'opt_lw_income_model',
        values = {
            { text = "Spawner income (default)", help = "Base income, plus each spawner you build permanently increases your mass income", key = 1, },
            { text = "Flat, scales per round", help = "Everyone gets the same income, which grows every round", key = 2, },
        },
    },
    {
        default = 60,
        label = "Round length",
        help = "Length of the build phase before each wave launches",
        key = 'opt_lw_round_time',
        pref = 'opt_lw_round_time',
        values = {
            { text = "60 seconds (default)", help = "Standard pace", key = 60, },
            { text = "45 seconds", help = "Fast rounds", key = 45, },
            { text = "90 seconds", help = "Relaxed pace", key = 90, },
            { text = "2 minutes", help = "Slow pace", key = 120, },
        },
    },
    {
        default = 1,
        label = "Core toughness",
        help = "Health multiplier applied to each player's Core structure",
        key = 'opt_lw_core_health',
        pref = 'opt_lw_core_health',
        values = {
            { text = "Normal (default)", help = "Standard Core health", key = 1, },
            { text = "x2", help = "Longer games", key = 2, },
            { text = "x4", help = "Very long games", key = 4, },
        },
    },
};
