local mod = get_mod("PiShock")
local ScriptUnit = mod:original_require("scripts/foundation/utilities/script_unit")

function mod:clock()
    local tm = Managers.time
    if tm then
        if tm:has_timer("main")     then return tm:time("main")     end
        if tm:has_timer("gameplay") then return tm:time("gameplay") end
    end
    return 0
end

-- ===== Helper Functions =====

local function local_player_unit()
    local player = Managers.player and Managers.player:local_player_safe(1)
    return player and player.player_unit
end

local function is_local_player(unit)
    local player = Managers.player and Managers.player:local_player_safe(1)
    return player and unit == player.player_unit
end

local function local_health_fraction()
    local unit = local_player_unit()
    if not unit then return nil end
    local ok, frac = pcall(function()
        local ext = ScriptUnit.has_extension(unit, "health_system")
        return ext and ext:current_health_percent()
    end)
    if ok and frac then return frac end
    return nil
end

local function local_stamina_fraction()
    local unit = local_player_unit()
    if not unit then return nil end
    local ok, frac = pcall(function()
        local unit_data_ext = ScriptUnit.has_extension(unit, "unit_data_system")
        if unit_data_ext then
            local stamina_comp = unit_data_ext:read_component("stamina")
            if stamina_comp then
                return stamina_comp.current_fraction
            end
        end
    end)
    if ok and frac then return frac end
    return nil
end

local function local_toughness_fraction()
    local unit = local_player_unit()
    if not unit then return nil end
    local ok, frac = pcall(function()
        local ext = ScriptUnit.has_extension(unit, "toughness_system")
        return ext and ext:current_toughness_percent()
    end)
    if ok and frac then return frac end
    return nil
end

local function local_corruption_fraction()
    local unit = local_player_unit()
    if not unit then return nil end
    local ok, frac = pcall(function()
        local ext = ScriptUnit.has_extension(unit, "health_system")
        return ext and ext:permanent_damage_taken_percent()
    end)
    if ok and frac then return frac end
    return nil
end

local function local_is_suppressed()
    local unit = local_player_unit()
    if not unit then return false end
    local ok, suppressed = pcall(function()
        local supp_ext = ScriptUnit.has_extension(unit, "suppression_system")
        if supp_ext then
            return supp_ext:has_high_suppression()
        end
    end)
    return ok and suppressed or false
end

local function get_player_disabled_state(unit)
    if not unit then return nil end
    local ok, state = pcall(function()
        local unit_data_ext = ScriptUnit.has_extension(unit, "unit_data_system")
        if unit_data_ext then
            local character_state_component = unit_data_ext:read_component("character_state")
            if character_state_component then
                return character_state_component.state_name
            end
        end
    end)
    if ok and state then
        return state
    end
    return nil
end

local function is_player_downed_or_disabled(unit)
    local state = get_player_disabled_state(unit)
    if state then
        local disabled_states = {
            knocked_down = true,
            dead = true,
            pounced = true,
            netted = true,
            mutant_charged = true,
            consumed = true,
            grabbed = true
        }
        return disabled_states[state] == true
    end
    return false
end

-- ===== Game Event Hooks =====

local TRIGGER_NAMES = {
    on_damage_taken = "Health Damage Taken",
    on_grimoire_damage = "Grimoire Corruption Tick",
    on_corruption_damage = "Corruption Taken",
    on_health_threshold = "Health Drops Below Percent",
    on_toughness_broken = "Toughness Broken",
    on_stamina_depleted = "Stamina Depleted",
    on_guard_broken = "Guard Broken",
    on_tired_dodge = "Tired Dodge",
    on_suppressed = "High Suppression",
    on_knocked_down = "Knocked Down",
    on_death = "Player Death",
    on_friendly_fire_taken = "Friendly Fire (Taken)",
    on_friendly_fire_dealt = "Friendly Fire (Dealt)",
    on_minigame_fail = "Minigame Failure",
    on_explode = "Plasma / Psyker Explosion",
    on_cheer = "For the Emperor",
    on_boss_spawn = "Boss Spawned",
    on_pounced = "Pounced by Hound",
    on_netted = "Trapped by Trapper",
    on_grabbed_mutant = "Grabbed by Mutant",
    on_consumed = "Eaten by Beast of Nurgle",
    on_grabbed_spawn = "Grabbed by Chaos Spawn",
}

local pishock_command_queue = {}
local last_event_time = 0
local last_request_time = 0

local send_pishock_command

mod.on_setting_changed = function(setting_id)
    local target_match = setting_id:match("^editor_(%w+)_target$")
    if target_match then
        local prefix = target_match
        local target = mod:get(setting_id)
        if not target then return end
        
        mod:set("editor_" .. prefix .. "_op", mod:get("trigger_" .. target .. "_op") or "disabled", false)
        mod:set("editor_" .. prefix .. "_duration", mod:get("trigger_" .. target .. "_duration") or 1, false)
        mod:set("editor_" .. prefix .. "_intensity", mod:get("trigger_" .. target .. "_intensity") or 10, false)
        mod:set("editor_" .. prefix .. "_enable_random_duration", mod:get("trigger_" .. target .. "_enable_random_duration") or false, false)
        mod:set("editor_" .. prefix .. "_duration_min", mod:get("trigger_" .. target .. "_duration_min") or 1, false)
        mod:set("editor_" .. prefix .. "_duration_max", mod:get("trigger_" .. target .. "_duration_max") or 1, false)
        mod:set("editor_" .. prefix .. "_enable_random_intensity", mod:get("trigger_" .. target .. "_enable_random_intensity") or false, false)
        mod:set("editor_" .. prefix .. "_intensity_min", mod:get("trigger_" .. target .. "_intensity_min") or 10, false)
        mod:set("editor_" .. prefix .. "_intensity_max", mod:get("trigger_" .. target .. "_intensity_max") or 10, false)
        return
    end
    
    local prefix, property = setting_id:match("^editor_(%w+)_(.+)$")
    if prefix and property and property ~= "target" and property ~= "group" then
        local target = mod:get("editor_" .. prefix .. "_target")
        if target then
            local value = mod:get(setting_id)
            mod:set("trigger_" .. target .. "_" .. property, value, false)
        end
    end
end

mod.on_all_mods_loaded = function()
    mod.on_setting_changed("editor_vitals_target")
    mod.on_setting_changed("editor_mechanics_target")
    mod.on_setting_changed("editor_enemies_target")
end

local continuous_trigger_timer = 0
local is_currently_continuous_disabled = false
local has_printed_continuous_start = false

function mod.update(dt)
    local tm = mod:clock()
    
    local unit = local_player_unit()
    local state = get_player_disabled_state(unit)
    local hook_id_for_state = nil
    if state then
        local state_to_hook = {
            pounced = "on_pounced",
            netted = "on_netted",
            mutant_charged = "on_grabbed_mutant",
            consumed = "on_consumed",
            grabbed = "on_grabbed_spawn"
        }
        hook_id_for_state = state_to_hook[state]
    end
    
    local is_disabled_now = (hook_id_for_state ~= nil)

    if is_disabled_now and mod:get("pulse_while_disabled") then
        is_currently_continuous_disabled = true
    else
        if is_currently_continuous_disabled then
            is_currently_continuous_disabled = false
            has_printed_continuous_start = false
            if mod:get("chat_feedback") then
                mod:echo("Done!")
            end
        end
    end
    
    if tm >= continuous_trigger_timer then
        if is_disabled_now and mod:get("pulse_while_disabled") then
            send_pishock_command(hook_id_for_state)
        end
        local cooldown = tonumber(mod:get("command_cooldown")) or 0
        continuous_trigger_timer = tm + math.max(1.0, cooldown)
    end

    if #pishock_command_queue == 0 then return end
    
    local hook_id = table.remove(pishock_command_queue, 1)

    local op = mod:get("trigger_" .. hook_id .. "_op")
    if not op or op == "disabled" then return end

    if op == "random" then
        local ops = {"0", "1", "2"}
        if mod:get("disable_random_beeps") then
            ops = {"0", "1"}
        end
        op = ops[math.random(1, #ops)]
    end

    local duration = tonumber(mod:get("trigger_" .. hook_id .. "_duration")) or 1
    if mod:get("trigger_" .. hook_id .. "_enable_random_duration") then
        local dur_min = tonumber(mod:get("trigger_" .. hook_id .. "_duration_min")) or 1
        local dur_max = tonumber(mod:get("trigger_" .. hook_id .. "_duration_max")) or 1
        duration = (dur_max > dur_min) and math.random(dur_min, dur_max) or dur_min
    end

    local intensity = tonumber(mod:get("trigger_" .. hook_id .. "_intensity")) or 10
    if mod:get("trigger_" .. hook_id .. "_enable_random_intensity") then
        local int_min = tonumber(mod:get("trigger_" .. hook_id .. "_intensity_min")) or 10
        local int_max = tonumber(mod:get("trigger_" .. hook_id .. "_intensity_max")) or 10
        intensity = (int_max > int_min) and math.random(int_min, int_max) or int_min
    end

    local continuous_disablers = {
        on_pounced = true,
        on_netted = true,
        on_grabbed_mutant = true,
        on_consumed = true,
        on_grabbed_spawn = true
    }
    if continuous_disablers[hook_id] and mod:get("pulse_while_disabled") then
        duration = 1
    end
    
    local username = mod:get("pishock_username") or ""
    local apikey = mod:get("pishock_apikey") or ""

    if username == "" or apikey == "" then
        mod:echo("PiShock credentials not set. Please use the following chat commands:")
        mod:echo("/pishock_username <username>")
        mod:echo("/pishock_apikey <apikey>")
        return
    end

    local payload = {
        op = op,
        duration = duration,
        intensity = intensity,
        username = username,
        apikey = apikey,
        shocker_names = mod:get("pishock_shocker") or ""
    }
    
    Managers.backend:url_request("http://127.0.0.1:20010/shock", {
        method = "POST",
        body = payload
    }):next(function(response)
    end):catch(function(error)
        mod:echo("Warning: Failed to communicate with PiShock. Did you start the server.py?")
    end)

    last_request_time = tm

    if mod:get("chat_feedback") then
        local trigger_name = TRIGGER_NAMES[hook_id] or hook_id
        
        local is_continuous = continuous_disablers[hook_id] and mod:get("pulse_while_disabled")
        
        if is_continuous then
            if not has_printed_continuous_start then
                has_printed_continuous_start = true
                if op == "0" then
                    mod:echo("SHOCKING... (" .. trigger_name .. ")")
                elseif op == "1" then
                    mod:echo("VIBRATING... (" .. trigger_name .. ")")
                elseif op == "2" then
                    mod:echo("BEEPING... (" .. trigger_name .. ")")
                end
            end
        else
            if op == "0" then
                mod:echo("SHOCK! " .. tostring(duration) .. "s Intensity: " .. tostring(intensity) .. " (" .. trigger_name .. ")")
            elseif op == "1" then
                mod:echo("VIBRATE! " .. tostring(duration) .. "s Intensity: " .. tostring(intensity) .. " (" .. trigger_name .. ")")
            elseif op == "2" then
                mod:echo("BEEP! (" .. trigger_name .. ")")
            end
        end
    end
end

local last_grimoire_time = 0

function send_pishock_command(hook_id)
    local tm = mod:clock()
    
    if hook_id == "on_grimoire_damage" then
        if tm < last_grimoire_time + 10 then
            return
        end
        last_grimoire_time = tm
    end
    
    local cooldown = tonumber(mod:get("command_cooldown")) or 0
    
    local bypass_cooldown = false
    if hook_id == "on_death" or hook_id == "on_knocked_down" or hook_id == "on_explode" then
        bypass_cooldown = true
    end
    
    if hook_id ~= "on_grimoire_damage" then
        if not bypass_cooldown and tm < last_event_time + cooldown then
            return 
        end
        last_event_time = tm
    end
    
    table.insert(pishock_command_queue, hook_id)
end

local function state_event(state_class, my_hook_id)
    mod:hook_safe(state_class, "on_enter", function(self, unit, ...)
        local ok, is_me = pcall(is_local_player, unit)
        if ok and is_me then
            send_pishock_command(my_hook_id)
        end
    end)
end

state_event(CLASS.PlayerCharacterStateKnockedDown,   "on_knocked_down")
state_event(CLASS.PlayerCharacterStateDead,          "on_death")
state_event(CLASS.PlayerCharacterStateMutantCharged, "on_grabbed_mutant")
state_event(CLASS.PlayerCharacterStateNetted,        "on_netted")
state_event(CLASS.PlayerCharacterStatePounced,       "on_pounced")
state_event(CLASS.PlayerCharacterStateConsumed,      "on_consumed")
state_event(CLASS.PlayerCharacterStateGrabbed,       "on_grabbed_spawn")
state_event(CLASS.PlayerCharacterStateExploding,     "on_explode")

mod:hook_safe(CLASS.PlayerCharacterStateDodging, "on_enter", function(self, unit, ...)
    local ok_me, is_me = pcall(is_local_player, unit)
    if not ok_me or not is_me then return end
    
    local ok_tired, is_tired = pcall(function()
        local dodge_state = self._dodge_character_state_component
        local weapon_ext = self._weapon_extension
        local buff_ext = self._buff_extension
        if not dodge_state or not weapon_ext or not buff_ext then return false end
        
        local weapon_dodge_template = weapon_ext:dodge_template()
        local stat_buffs = buff_ext:stat_buffs()
        local extra_consecutive_dodges = math.round(stat_buffs.extra_consecutive_dodges or 0)
        local dr_start = (weapon_dodge_template and weapon_dodge_template.diminishing_return_start or 2) + extra_consecutive_dodges
        
        return dodge_state.consecutive_dodges > dr_start
    end)
    
    if ok_tired and is_tired then
        send_pishock_command("on_tired_dodge")
    end
end)

mod:hook_safe(CLASS.PlayerUnitWeaponExtension, "blocked_attack", function(self, attacking_unit, hit_world_position, block_broken, weapon_template, attack_type, block_cost, is_perfect_block)
    if not self._unit or not is_local_player(self._unit) then return end
    
    if block_broken then
        send_pishock_command("on_guard_broken")
    end
end)

mod:hook_safe(CLASS.BossExtension, "extensions_ready", function(self)
    local breed = self._breed
    if breed and breed.tags and breed.tags.monster then
        send_pishock_command("on_boss_spawn")
    end
end)

mod:hook_safe(CLASS.AttackReportManager, "add_attack_result", function(self, damage_profile, attacked_unit, attacking_unit, attack_direction, hit_world_position, hit_weakspot, damage, attack_result, attack_type, damage_efficiency, is_critical_strike, ...)
    if attack_result == "friendly_fire" then
        local target_is_me = false
        local attacker_is_me = false
        
        local ok1, is_me1 = pcall(is_local_player, attacked_unit)
        if ok1 and is_me1 then target_is_me = true end
        
        local ok2, is_me2 = pcall(is_local_player, attacking_unit)
        if ok2 and is_me2 then attacker_is_me = true end
        
        if target_is_me then
            send_pishock_command("on_friendly_fire_taken")
        elseif attacker_is_me then
            send_pishock_command("on_friendly_fire_dealt")
        end
    end
end)

mod:hook_safe(CLASS.MinigameBase, "play_sound", function(self, alias)
    if alias == "sfx_minigame_fail" or alias == "sfx_minigame_bio_fail" then
        local player = Managers.player and Managers.player:player_from_session_id(self._player_session_id)
        if player and is_local_player(player.player_unit) then
            send_pishock_command("on_minigame_fail")
        end
    end
end)

local last_health_frac  = nil
local last_corr_frac    = nil
local last_stamina_frac = nil
local last_toughness_frac = nil
local last_grimoire_time = 0
local was_suppressed    = false

mod:hook_safe(CLASS.HudElementPlayerBuffs, "_update_buffs", function(self)
    if self.__class_name ~= "HudElementPlayerBuffs" or self._filter then return end

    local player_extensions = self._parent and self._parent:player_extensions()
    local unit_data = player_extensions and player_extensions.unit_data
    if not unit_data then return end

    local health_frac = local_health_fraction()
    if health_frac then
        if last_health_frac then
            local is_disabled = is_player_downed_or_disabled(local_player_unit())
            
            if health_frac < last_health_frac - 0.001 then
                if not is_disabled then
                    send_pishock_command("on_damage_taken")
                end
            end
            
            local threshold = (mod:get("trigger_on_health_threshold_value") or 30) / 100.0
            if health_frac <= threshold and last_health_frac > threshold then
                if not is_disabled then
                    send_pishock_command("on_health_threshold")
                end
            end
        end
        last_health_frac = health_frac
    else
        last_health_frac = nil
    end

    local corr_frac = local_corruption_fraction()
    if corr_frac then
        if last_corr_frac then
            local is_disabled = is_player_downed_or_disabled(local_player_unit())
            if corr_frac > last_corr_frac + 0.001 then
                if not is_disabled then
                    send_pishock_command("on_corruption_damage")
                end
            end
        end
        last_corr_frac = corr_frac
    else
        last_corr_frac = nil
    end

    local toughness_frac = local_toughness_fraction()
    if toughness_frac then
        if last_toughness_frac then
            local is_disabled = is_player_downed_or_disabled(local_player_unit())
            if last_toughness_frac > 0 and toughness_frac <= 0 then
                if not is_disabled then
                    send_pishock_command("on_toughness_broken")
                end
            end
        end
        last_toughness_frac = toughness_frac
    else
        last_toughness_frac = nil
    end

    local stamina_frac = local_stamina_fraction()
    if stamina_frac then
        if last_stamina_frac then
            if last_stamina_frac > 0 and stamina_frac <= 0 then
                local is_disabled = is_player_downed_or_disabled(local_player_unit())
                if not is_disabled then
                    send_pishock_command("on_stamina_depleted")
                end
            end
        end
        last_stamina_frac = stamina_frac
    else
        last_stamina_frac = nil
    end

    local is_suppressed = local_is_suppressed()
    if is_suppressed and not was_suppressed then
        local is_disabled = is_player_downed_or_disabled(local_player_unit())
        if not is_disabled then
            send_pishock_command("on_suppressed")
        end
    end
    was_suppressed = is_suppressed
end)

mod:hook_safe(CLASS.DialogueSystem, "_play_dialogue_event_implementation", function(self, go_id, is_level_unit, level_name_hash, dialogue_id, ...)
    local ok, is_cheer = pcall(function()
        return NetworkLookup.dialogue_names[dialogue_id] == "com_wheel_vo_for_the_emperor"
    end)
    if not ok or not is_cheer then return end

    local ok_unit, unit = pcall(function()
        return Managers.state.unit_spawner:unit(go_id, is_level_unit, level_name_hash)
    end)
    if not ok_unit or not unit then return end

    send_pishock_command("on_cheer")
end)

-- ===== Commands =====

mod:command("pishock_username", "Set PiShock Username", function(...)
    local args = {...}
    if #args > 0 then
        local username = table.concat(args, " ")
        mod:set("pishock_username", username)
        mod:echo("PiShock Username set to: " .. username)
    else
        mod:echo("Usage: /pishock_username <username>")
    end
end)

mod:command("pishock_apikey", "Set PiShock API Key", function(...)
    local args = {...}
    if #args > 0 then
        local apikey = table.concat(args, " ")
        mod:set("pishock_apikey", apikey)
        mod:echo("PiShock API Key set to: " .. apikey)
    else
        mod:echo("Usage: /pishock_apikey <apikey>")
    end
end)

mod:command("pishock_shocker", "Set targeted PiShock Shocker names or IDs (comma separated)", function(...)
    local args = {...}
    if #args > 0 then
        local shockers = table.concat(args, " ")
        mod:set("pishock_shocker", shockers)
        mod:echo("PiShock Shocker(s) set to: " .. shockers)
    else
        mod:set("pishock_shocker", "")
        mod:echo("Cleared targeted shockers. All active shockers will be triggered.")
    end
end)

mod:command("pishock_info", "Show PiShock Account Info", function()
    local username = mod:get("pishock_username") or ""
    local apikey = mod:get("pishock_apikey") or ""
    local shocker_names = mod:get("pishock_shocker") or ""

    local display_username = username ~= "" and username or "[Not Set]"
    local display_shockers = shocker_names ~= "" and shocker_names or "[All Devices]"
    
    local display_apikey = "[Not Set]"
    if apikey ~= "" then
        if string.len(apikey) > 4 then
            display_apikey = string.sub(apikey, 1, 4) .. string.rep("*", string.len(apikey) - 4)
        else
            display_apikey = string.rep("*", string.len(apikey))
        end
    end

    mod:echo("=== PiShock Account Info ===")
    mod:echo("Username: " .. display_username)
    mod:echo("API Key: " .. display_apikey)
    mod:echo("Target Shockers: " .. display_shockers)
end)
