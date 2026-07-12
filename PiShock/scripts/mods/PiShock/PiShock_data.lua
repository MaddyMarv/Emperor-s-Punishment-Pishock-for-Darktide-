local mod = get_mod("PiShock")

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

local widgets = {
    {
        setting_id = "chat_feedback",
        type = "checkbox",
        default_value = true,
    },
    {
        setting_id = "command_cooldown",
        type = "numeric",
        default_value = 0,
        range = { 0, 10 },
    },
}

for _, hook in ipairs(hooks) do
    widgets[#widgets + 1] = {
        setting_id = "trigger_" .. hook.id .. "_group",
        type = "group",
        sub_widgets = {
            {
                setting_id = "trigger_" .. hook.id .. "_op",
                type = "dropdown",
                default_value = "disabled",
                options = {
                    { text = "op_disabled", value = "disabled" },
                    { text = "op_shock",    value = "0" },
                    { text = "op_vibrate",  value = "1" },
                    { text = "op_beep",     value = "2" },
                },
            },
            {
                setting_id = "trigger_" .. hook.id .. "_duration",
                type = "numeric",
                default_value = 1,
                range = { 1, 15 },
            },
            {
                setting_id = "trigger_" .. hook.id .. "_intensity",
                type = "numeric",
                default_value = 10,
                range = { 1, 100 },
            }
        }
    }

    if hook.id == "on_health_threshold" then
        local sub = widgets[#widgets].sub_widgets
        sub[#sub + 1] = {
            setting_id = "trigger_on_health_threshold_value",
            type = "numeric",
            default_value = 30,
            range = { 1, 99 },
        }
    end
end

return {
    name = "PiShock",
    description = mod:localize("mod_description"),
    is_togglable = true,
    options = {
        widgets = widgets
    }
}
