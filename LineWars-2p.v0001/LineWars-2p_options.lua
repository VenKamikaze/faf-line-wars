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
    {
        default = 3,
        label = "Allow air units from round",
        help = "Air factories and air units are build-locked until this round. Land-only until then.",
        key = 'opt_lw_air_from_round',
        pref = 'opt_lw_air_from_round',
        values = {
            { text = "Round 3 (default)", help = "Air unlocks at the start of round 3", key = 3, },
            { text = "Immediate", help = "Air available from the very start", key = 0, },
            { text = "Round 1", help = "Air unlocks at the start of round 1", key = 1, },
            { text = "Round 2", help = "Air unlocks at the start of round 2", key = 2, },
            { text = "Round 4", help = "Air unlocks at the start of round 4", key = 4, },
            { text = "Round 5", help = "Air unlocks at the start of round 5", key = 5, },
            { text = "Round 10", help = "Air unlocks at the start of round 10", key = 10, },
            { text = "Never", help = "Land-only game — air is never buildable", key = 9999, },
        },
    },
    {
        default = 10,
        label = "Map start delay",
        help = "Grace period after the game loads before the first build round begins",
        key = 'opt_lw_start_delay',
        pref = 'opt_lw_start_delay',
        values = {
            { text = "10 seconds (default)", help = "Short settle-in before round 1", key = 10, },
            { text = "None", help = "First build round starts immediately", key = 0, },
            { text = "5 seconds", help = "Brief pause", key = 5, },
            { text = "15 seconds", help = "A little longer to position", key = 15, },
            { text = "30 seconds", help = "Half a minute", key = 30, },
            { text = "1 minute", help = "Long settle-in", key = 60, },
            { text = "2 minutes", help = "Very long settle-in", key = 120, },
        },
    },
};
