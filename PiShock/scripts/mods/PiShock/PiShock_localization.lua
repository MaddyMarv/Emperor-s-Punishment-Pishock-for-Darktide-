local localizations = {
    mod_description = {
        en = "Connects Darktide to a PiShock device to trigger shocks, vibrations, or beeps on specific game events.",
    },
    pishock_username = {
        en = "PiShock Username",
    },
    pishock_apikey = {
        en = "PiShock API Key",
    },
    op_disabled = {
        en = "Disabled",
    },
    op_shock = {
        en = "Shock",
    },
    op_vibrate = {
        en = "Vibrate",
    },
    op_beep = {
        en = "Beep",
    },
    op_random = {
        en = "Random",
    },
    trigger_on_health_threshold_value = {
        en = "Health Threshold Percent (1-99)",
    },
    general_group = {
        en = "General Settings",
    },
    chat_feedback = {
        en = "Chat Feedback",
    },
    disable_random_beeps = {
        en = "Disable Beeps in Randomization",
    },
    pulse_while_disabled = {
        en = "Continuous Pulse While Disabled",
    },
    command_cooldown = {
        en = "Command Cooldown (Seconds)",
    },
}

local hooks = {
    { id = "on_damage_taken",     name = "Health Damage Taken" },
    { id = "on_grimoire_damage",  name = "Grimoire Corruption Tick" },
    { id = "on_corruption_damage",name = "Corruption Taken" },
    { id = "on_health_threshold", name = "Health Drops Below Percent" },
    { id = "on_toughness_broken", name = "Toughness Broken" },
    { id = "on_stamina_depleted", name = "Stamina Depleted" },
    { id = "on_guard_broken",     name = "Guard Broken" },
    { id = "on_tired_dodge",      name = "Tired Dodge" },
    { id = "on_suppressed",       name = "High Suppression" },
    { id = "on_knocked_down",     name = "Knocked Down" },
    { id = "on_death",            name = "Player Death" },

    { id = "on_minigame_fail",    name = "Minigame Failure" },
    { id = "on_explode",          name = "Plasma / Psyker Explosion" },
    { id = "on_cheer",            name = "For the Emperor" },
    { id = "on_friendly_fire_taken", name = "Friendly Fire (Taken)" },
    { id = "on_friendly_fire_dealt", name = "Friendly Fire (Dealt)" },

    { id = "on_boss_spawn",       name = "Boss Spawned" },
    { id = "on_pounced",          name = "Pounced by Hound" },
    { id = "on_netted",           name = "Trapped by Trapper" },
    { id = "on_grabbed_mutant",   name = "Grabbed by Mutant" },
    { id = "on_consumed",         name = "Eaten by Beast of Nurgle" },
    { id = "on_grabbed_spawn",    name = "Grabbed by Chaos Spawn" },
}

local editor_prefixes = { "vitals", "mechanics", "enemies" }
local group_names = {
    vitals = "Vitals Triggers Settings",
    mechanics = "Mechanics Triggers Settings",
    enemies = "Enemy Triggers Settings"
}

for _, prefix in ipairs(editor_prefixes) do
    localizations["editor_" .. prefix .. "_group"] = { en = group_names[prefix] }
    localizations["editor_" .. prefix .. "_target"] = { en = "Select Trigger to Edit" }
    localizations["editor_" .. prefix .. "_op"] = { en = "Operation Type" }
    localizations["editor_" .. prefix .. "_duration"] = { en = "Duration (Seconds)" }
    localizations["editor_" .. prefix .. "_intensity"] = { en = "Intensity (1-100)" }
    localizations["editor_" .. prefix .. "_enable_random_duration"] = { en = "Randomize Duration" }
    localizations["editor_" .. prefix .. "_duration_min"] = { en = "└─ Random Min (Seconds)" }
    localizations["editor_" .. prefix .. "_duration_max"] = { en = "└─ Random Max (Seconds)" }
    localizations["editor_" .. prefix .. "_enable_random_intensity"] = { en = "Randomize Intensity" }
    localizations["editor_" .. prefix .. "_intensity_min"] = { en = "└─ Random Min (1-100)" }
    localizations["editor_" .. prefix .. "_intensity_max"] = { en = "└─ Random Max (1-100)" }
end

for _, hook in ipairs(hooks) do
    localizations["target_" .. hook.id] = {
        en = hook.name,
    }
end

return localizations
