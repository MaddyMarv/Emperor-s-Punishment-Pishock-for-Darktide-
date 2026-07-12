return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`PiShock` encountered an error loading the Darktide Mod Framework.")

		new_mod("PiShock", {
			mod_script       = "PiShock/scripts/mods/PiShock/PiShock",
			mod_data         = "PiShock/scripts/mods/PiShock/PiShock_data",
			mod_localization = "PiShock/scripts/mods/PiShock/PiShock_localization",
		})
	end,
	packages = {},
}
