local mod = get_mod("PiShock")

local hook_categories = {
    {
        prefix = "vitals",
        tab_name = "Vitals",
        hooks = {
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
        }
    },
    {
        prefix = "mechanics",
        tab_name = "Mechanics",
        hooks = {
            { id = "on_minigame_fail",    name = "Minigame Failure" },
            { id = "on_explode",          name = "Plasma / Psyker Explosion" },
            { id = "on_cheer",            name = "For the Emperor" },
            { id = "on_friendly_fire_taken", name = "Friendly Fire (Taken)" },
            { id = "on_friendly_fire_dealt", name = "Friendly Fire (Dealt)" },
        }
    },
    {
        prefix = "enemies",
        tab_name = "Enemies",
        hooks = {
            { id = "on_boss_spawn",       name = "Boss Spawned" },
            { id = "on_pounced",          name = "Pounced by Hound" },
            { id = "on_netted",           name = "Trapped by Trapper" },
            { id = "on_grabbed_mutant",   name = "Grabbed by Mutant" },
            { id = "on_consumed",         name = "Eaten by Beast of Nurgle" },
            { id = "on_grabbed_spawn",    name = "Grabbed by Chaos Spawn" },
        }
    }
}

local widgets = {
    {
        setting_id = "general_group",
        type = "group",
        tab = "General",
        sub_widgets = {
            {
                setting_id = "chat_feedback",
                type = "checkbox",
                default_value = true,
            },
            {
                setting_id = "disable_random_beeps",
                type = "checkbox",
                default_value = false,
            },
            {
                setting_id = "pulse_while_disabled",
                type = "checkbox",
                default_value = false,
            },
            {
                setting_id = "command_cooldown",
                type = "numeric",
                default_value = 0,
                range = { 0, 10 },
            },
            {
                setting_id = "trigger_on_health_threshold_value",
                type = "numeric",
                default_value = 30,
                range = { 1, 99 },
            },
        }
    }
}

for _, category in ipairs(hook_categories) do
    local target_options = {}
    for _, hook in ipairs(category.hooks) do
        target_options[#target_options + 1] = {
            text = "target_" .. hook.id,
            value = hook.id
        }
    end

    widgets[#widgets + 1] = {
        setting_id = "editor_" .. category.prefix .. "_group",
        type = "group",
        tab = category.tab_name,
        sub_widgets = {
            {
                setting_id = "editor_" .. category.prefix .. "_target",
                type = "dropdown",
                default_value = target_options[1].value,
                options = target_options
            },
            {
                setting_id = "editor_" .. category.prefix .. "_op",
                type = "dropdown",
                default_value = "disabled",
                options = {
                    { text = "op_disabled", value = "disabled" },
                    { text = "op_shock",    value = "0" },
                    { text = "op_vibrate",  value = "1" },
                    { text = "op_beep",     value = "2" },
                    { text = "op_random",   value = "random" },
                },
            },
            {
                setting_id = "editor_" .. category.prefix .. "_duration",
                type = "numeric",
                default_value = 1,
                range = { 1, 15 },
            },
            {
                setting_id = "editor_" .. category.prefix .. "_intensity",
                type = "numeric",
                default_value = 10,
                range = { 1, 100 },
            },
            {
                setting_id = "editor_" .. category.prefix .. "_enable_random_duration",
                type = "checkbox",
                default_value = false,
            },
            {
                setting_id = "editor_" .. category.prefix .. "_duration_min",
                type = "numeric",
                default_value = 1,
                range = { 1, 15 },
            },
            {
                setting_id = "editor_" .. category.prefix .. "_duration_max",
                type = "numeric",
                default_value = 1,
                range = { 1, 15 },
            },
            {
                setting_id = "editor_" .. category.prefix .. "_enable_random_intensity",
                type = "checkbox",
                default_value = false,
            },
            {
                setting_id = "editor_" .. category.prefix .. "_intensity_min",
                type = "numeric",
                default_value = 10,
                range = { 1, 100 },
            },
            {
                setting_id = "editor_" .. category.prefix .. "_intensity_max",
                type = "numeric",
                default_value = 10,
                range = { 1, 100 },
            }
        }
    }
end

return {
    name = "PiShock",
    description = mod:localize("mod_description"),
    is_togglable = true,
    options = {
        widgets = widgets
    }
}
