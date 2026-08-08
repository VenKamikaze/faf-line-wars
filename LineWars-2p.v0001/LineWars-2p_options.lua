-- Lobby options for Line Wars.
-- The intended default is listed first in each `values` table AND given as
-- `default`, so the right thing happens whether the lobby treats `default`
-- as a value key or an index.
--
-- PERCENT SIGNS: the lobby runs each option `label`, each value `text` and each
-- value `help` through LOCF, i.e. string.format (mapselect.lua:903/905 and
-- lobby.lua:3648/3650). A bare `%` there throws "invalid option to `format'",
-- which aborts CalcVisible mid-list: the offending option renders with an empty
-- combo box and every option below it keeps stale text. Write `%%` in those
-- three fields. The option-level `help` is NOT formatted (tooltip body, LOC
-- only) — leave a bare `%` there, or it displays literally as `%%`.
options =
{
    {
        default = 1,
        label = "Income model",
        help = "How players earn the mass used to build spawner structures",
        key = 'opt_lw_income_model',
        pref = 'opt_lw_income_model',
        values = {
            { text = "Spawner income", help = "Base income, plus each spawner you build permanently increases your mass income", key = 1, },
            { text = "Flat, scales per round", help = "Everyone gets the same income, which grows every round", key = 2, },
        },
    },
    {
        default = 1,
        label = "Round length",
        help = "Length of the build phase before each wave launches",
        key = 'opt_lw_round_time',
        pref = 'opt_lw_round_time',
        values = {
            { text = "60 seconds", help = "Standard pace", key = 60, },
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
            { text = "Normal", help = "Standard Core health", key = 1, },
            { text = "x2", help = "Longer games", key = 2, },
            { text = "x4", help = "Very long games", key = 4, },
        },
    },
    {
        default = 1,
        label = "Allow air units from round",
        help = "Air factories and air units are build-locked until this round. Land-only until then.",
        key = 'opt_lw_air_from_round',
        pref = 'opt_lw_air_from_round',
        values = {
            { text = "Round 3", help = "Air unlocks at the start of round 3", key = 3, },
            { text = "Immediate", help = "Air available from the very start", key = 0, },
            { text = "Round 2", help = "Air unlocks at the start of round 2", key = 2, },
            { text = "Round 4", help = "Air unlocks at the start of round 4", key = 4, },
            { text = "Round 5", help = "Air unlocks at the start of round 5", key = 5, },
            { text = "Round 10", help = "Air unlocks at the start of round 10", key = 10, },
            { text = "Never", help = "Land-only game — air is never buildable", key = 9999, },
        },
    },
    {
        default = 1,
        label = "Map start delay",
        help = "Grace period after the game loads before the first build round begins",
        key = 'opt_lw_start_delay',
        pref = 'opt_lw_start_delay',
        values = {
            { text = "10 seconds", help = "Short settle-in before round 1", key = 10, },
            { text = "None", help = "First build round starts immediately", key = 0, },
            { text = "5 seconds", help = "Brief pause", key = 5, },
            { text = "15 seconds", help = "A little longer to position", key = 15, },
            { text = "30 seconds", help = "Half a minute", key = 30, },
            { text = "1 minute", help = "Long settle-in", key = 60, },
            { text = "2 minutes", help = "Very long settle-in", key = 120, },
        },
    },
    {
        default = 1,
        label = "Income growth interval",
        help = "How often every player's base mass and energy income steps up. Pairs with 'Income growth step' below.",
        key = 'opt_lw_income_growth_rounds',
        pref = 'opt_lw_income_growth_rounds',
        values = {
            { text = "Every 4 rounds", help = "Income steps up at rounds 4, 8, 12, 16 ...", key = 4, },
            { text = "Never", help = "Flat income for the whole game - no growth", key = 9999, },
            { text = "Every round", help = "Income steps up every round, round 1 included", key = 1, },
            { text = "Every 2 rounds", help = "Income steps up at rounds 2, 4, 6, 8 ...", key = 2, },
            { text = "Every 3 rounds", help = "Income steps up at rounds 3, 6, 9, 12 ...", key = 3, },
            { text = "Every 5 rounds", help = "Income steps up at rounds 5, 10, 15, 20 ...", key = 5, },
            { text = "Every 6 rounds", help = "Income steps up at rounds 6, 12, 18, 24 ...", key = 6, },
            { text = "Every 7 rounds", help = "Income steps up at rounds 7, 14, 21, 28 ...", key = 7, },
            { text = "Every 8 rounds", help = "Income steps up at rounds 8, 16, 24, 32 ...", key = 8, },
            { text = "Every 9 rounds", help = "Income steps up at rounds 9, 18, 27, 36 ...", key = 9, },
            { text = "Every 10 rounds", help = "Income steps up at rounds 10, 20, 30, 40 ...", key = 10, },
        },
    },
    {
        default = 1,
        label = "Income growth step",
        help = "How much is added at each growth interval, as a share of the BASE income. Steps are additive, not compounding: at 50% every 4 rounds you earn 100% of base to round 3, 150% from round 4, 200% from round 8.",
        key = 'opt_lw_income_growth_pct',
        pref = 'opt_lw_income_growth_pct',
        values = {
            -- NOTE: `text` (and value `help`) are passed through LOCF -> string.format
            -- by the lobby, so a literal percent sign MUST be escaped as `%%` or the
            -- whole options panel errors out. See the header comment above.
            { text = "50%%", help = "Half the base income added per interval", key = 50, },
            { text = "25%%", help = "A quarter of the base income added per interval - slow burn", key = 25, },
            { text = "75%%", help = "Three quarters of the base income added per interval", key = 75, },
            { text = "100%%", help = "A full base income added per interval - doubles at the first step", key = 100, },
            { text = "150%%", help = "One and a half base incomes added per interval", key = 150, },
            { text = "200%%", help = "Two base incomes added per interval - very fast escalation", key = 200, },
        },
    },
    {
        default = 1,
        label = "Capture point income",
        help = "Mass and energy each captured lane point pays the side holding it",
        key = 'opt_lw_capture_income',
        pref = 'opt_lw_capture_income',
        values = {
            { text = "Average", help = "1 mass/s and 12.5 energy/s per point", key = 3, },
            { text = "Very low", help = "0.25 mass/s and 3.1 energy/s per point", key = 1, },
            { text = "Low", help = "0.5 mass/s and 6.3 energy/s per point", key = 2, },
            { text = "High", help = "2 mass/s and 25 energy/s per point", key = 4, },
            { text = "Very high", help = "4 mass/s and 50 energy/s per point", key = 5, },
        },
    },
    {
        default = 1,
        label = "SOS uses per player",
        help = "How many times each player may type /sos to clear the mobile units out of their lane",
        key = 'opt_lw_sos_charges',
        pref = 'opt_lw_sos_charges',
        values = {
            { text = "1", help = "One SOS per player for the whole game", key = 1, },
            { text = "None", help = "The /sos command is disabled", key = 0, },
            { text = "2", help = "Two SOS per player", key = 2, },
            { text = "3", help = "Three SOS per player", key = 3, },
        },
    },
    {
        default = 1,
        label = "Allow T2 power generators",
        help = "Lets every faction's ACU build a Tech 2 power generator (+500 energy/s) once it has the Advanced Engineering upgrade. Off means the Core and capture points are your only energy.",
        key = 'opt_lw_t2_power',
        pref = 'opt_lw_t2_power',
        values = {
            { text = "Allow", help = "T2 power generators buildable by every faction - energy becomes a build decision, and shields stop being UEF-only in practice", key = 1, },
            { text = "Disallow", help = "No power generators at all - energy income is fixed by the Core, base income and capture points", key = 0, },
        },
    },
    {
        default = 2,
        label = "SOS destroys",
        help = "Which mobile units an SOS detonates in the caller's lane. Structures are never touched.",
        key = 'opt_lw_sos_targets',
        pref = 'opt_lw_sos_targets',
        values = {
            { text = "Enemy units only", help = "Clears the enemy push and leaves your own wave standing", key = 1, },
            { text = "Every unit in the lane", help = "Wipes both sides, including your own units and your allies' - fairer, and it costs you too", key = 2, },
        },
    },
};
