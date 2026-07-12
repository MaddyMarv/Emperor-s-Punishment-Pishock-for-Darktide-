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

local function is_player_downed_or_disabled(unit)
    if not unit then return false end
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
    on_health_threshold = "Health Drops Below Percent",
    on_toughness_broken = "Toughness Broken",
    on_knocked_down = "Knocked Down",
    on_death = "Player Death",
    on_overload = "Peril Overload",
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

function mod.update(dt)
    if #pishock_command_queue == 0 then return end
    
    local tm = mod:clock()
    -- Small fixed delay to prevent spamming the local Python server
    if tm < last_request_time + 0.5 then
        return
    end
    
    local hook_id = table.remove(pishock_command_queue, 1)

    local op = mod:get("trigger_" .. hook_id .. "_op")
    if not op or op == "disabled" then return end

    local duration = tonumber(mod:get("trigger_" .. hook_id .. "_duration")) or 1
    local intensity = tonumber(mod:get("trigger_" .. hook_id .. "_intensity")) or 10
    
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
        if op == "0" then
            mod:echo("SHOCK! " .. tostring(duration) .. "s Intensity: " .. tostring(intensity) .. " (" .. trigger_name .. ")")
        elseif op == "1" then
            mod:echo("VIBRATE! " .. tostring(duration) .. "s Intensity: " .. tostring(intensity) .. " (" .. trigger_name .. ")")
        elseif op == "2" then
            mod:echo("BEEP! (" .. trigger_name .. ")")
        end
    end
end

local function send_pishock_command(hook_id)
    local tm = mod:clock()
    local cooldown = tonumber(mod:get("command_cooldown")) or 0
    if tm < last_event_time + cooldown then
        return -- Drop the command (Invincibility window)
    end
    
    last_event_time = tm
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

mod:hook_safe(CLASS.BossExtension, "extensions_ready", function(self)
    local breed = self._breed
    if breed and breed.tags and breed.tags.monster then
        send_pishock_command("on_boss_spawn")
    end
end)

mod:hook_safe(CLASS.PlayerUnitToughnessExtension, "_record_toughness_broken", function(self)
    local ok, is_me = pcall(is_local_player, self._unit)
    if ok and is_me then
        if not is_player_downed_or_disabled(self._unit) then
            send_pishock_command("on_toughness_broken")
        end
    end
end)

local last_action_name  = nil
local last_health_frac  = nil

mod:hook_safe(CLASS.HudElementPlayerBuffs, "_update_buffs", function(self)
    if self.__class_name ~= "HudElementPlayerBuffs" or self._filter then return end

    local player_extensions = self._parent and self._parent:player_extensions()
    local unit_data = player_extensions and player_extensions.unit_data
    if not unit_data then return end

    -- Overload detection
    local ok, current_action = pcall(function()
        return unit_data:read_component("weapon_action").current_action_name
    end)
    if ok and current_action and current_action ~= last_action_name then
        if current_action == "action_warp_charge_explode" then
            send_pishock_command("on_overload")
        end
        last_action_name = current_action
    end

    -- Health-drop detection
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
