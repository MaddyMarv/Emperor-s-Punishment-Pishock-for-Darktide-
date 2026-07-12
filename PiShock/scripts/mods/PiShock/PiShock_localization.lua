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
    trigger_on_health_threshold_value = {
        en = "Health Threshold Percent (1-99)",
    },
    chat_feedback = {
        en = "Chat Feedback",
    },
    command_cooldown = {
        en = "Command Cooldown (Seconds)",
    },
}

local hooks = {
    -- General Health & Vitals
    { id = "on_damage_taken",     name = "Health Damage Taken" },
    { id = "on_health_threshold", name = "Health Drops Below Percent" },
    { id = "on_toughness_broken", name = "Toughness Broken" },
    { id = "on_knocked_down",     name = "Knocked Down" },
    { id = "on_death",            name = "Player Death" },
    
    -- Specific Mechanics
    { id = "on_overload",         name = "Peril Overload" },
    
    -- Bosses & Disablers
    { id = "on_boss_spawn",       name = "Boss Spawned" },
    { id = "on_pounced",          name = "Pounced by Hound" },
    { id = "on_netted",           name = "Trapped by Trapper" },
    { id = "on_grabbed_mutant",   name = "Grabbed by Mutant" },
    { id = "on_consumed",         name = "Eaten by Beast of Nurgle" },
    { id = "on_grabbed_spawn",    name = "Grabbed by Chaos Spawn" },
}

for _, hook in ipairs(hooks) do
    localizations["trigger_" .. hook.id .. "_group"] = {
        en = hook.name,
    }
    localizations["trigger_" .. hook.id .. "_op"] = {
        en = "Operation Type",
    }
    localizations["trigger_" .. hook.id .. "_duration"] = {
        en = "Duration (Seconds)",
    }
    localizations["trigger_" .. hook.id .. "_intensity"] = {
        en = "Intensity (1-100)",
    }
end

return localizations
