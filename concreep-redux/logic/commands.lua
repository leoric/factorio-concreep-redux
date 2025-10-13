-- Console command: Help
commands.add_command("concreep-help", "Show available Concreep Redux commands", function(event)
	local help_text = {
		"[Concreep Redux Commands]",
		"/concreep-help - Show this help message",
		"/concreep-wake - Wake up all sleeping roboports",
		"/concreep-rebuild - Rebuild the roboport list (fixes saves with missing roboports)",
		"/concreep-status - Show current status (roboports tracked, active, sleeping)"
	}

	local output = table.concat(help_text, "\n")
	if event.player_index then
		game.get_player(event.player_index).print(output)
	else
		game.print(output)
	end
end)

-- Console command: Wake up all sleeping roboports
commands.add_command("concreep-wake", "Wake up all sleeping roboports", function(event)
	if not storage.creepers then
		game.print("Concreep not initialized yet.")
		return
	end

	local woken = 0
	for i = 1, #storage.creepers do
		if storage.creepers[i].off then
			storage.creepers[i].off = false
			storage.creepers[i].removal_counter = 0
			storage.creepers[i].radius = 3  -- Reset radius to start scanning from the beginning
			storage.creepers[i].upgrade = false  -- Clear upgrade mode
			storage.creepers[i].sleep_reason = nil  -- Clear sleep reason
			woken = woken + 1
		end
	end

	count_active_creepers()

	if event.player_index then
		game.get_player(event.player_index).print("Woke up " .. woken .. " sleeping roboports. Active: " .. storage.active_creepers)
	else
		game.print("Woke up " .. woken .. " sleeping roboports. Active: " .. storage.active_creepers)
	end
end)

-- Console command: Rebuild the creeper list
commands.add_command("concreep-rebuild", "Rebuild the roboport list from scratch", function(event)
	if not storage.creepers then
		game.print("Concreep not initialized yet.")
		return
	end

	local old_count = #storage.creepers

	-- Clear the existing list
	storage.creepers = {}
	storage.index = 1
	storage.active_creepers = 0

	-- Rebuild by scanning all surfaces for roboports
	local added = 0
	for _, surface in pairs(game.surfaces) do
		for _, port in pairs(surface.find_entities_filtered { type = "roboport" }) do
			if validate(port) then
				-- Check if this roboport is already in the list (shouldn't be, but just in case)
				local found = false
				for _, creeper in pairs(storage.creepers) do
					if creeper.roboport == port then
						found = true
						break
					end
				end

				if not found then
					addPort(port)
					added = added + 1
				end
			end
		end
	end

	count_active_creepers()

	local message = string.format(
		"Rebuilt roboport list: %d old, %d new, %d total (%d active, %d sleeping)",
		old_count, added, #storage.creepers, storage.active_creepers, #storage.creepers - storage.active_creepers
	)

	if event.player_index then
		game.get_player(event.player_index).print(message)
	else
		game.print(message)
	end
end)

-- Console command: Show status
commands.add_command("concreep-status", "Show current Concreep Redux status", function(event)
	if not storage.creepers then
		game.print("Concreep not initialized yet.")
		return
	end

	local sleeping = 0
	local active = 0
	local by_surface = {}

	for _, creeper in pairs(storage.creepers) do
		if creeper.off then
			sleeping = sleeping + 1
		else
			active = active + 1
		end

		if not by_surface[creeper.surface] then
			by_surface[creeper.surface] = { active = 0, sleeping = 0 }
		end

		if creeper.off then
			by_surface[creeper.surface].sleeping = by_surface[creeper.surface].sleeping + 1
		else
			by_surface[creeper.surface].active = by_surface[creeper.surface].active + 1
		end
	end

	local status_lines = {
		"[Concreep Redux Status]",
		string.format("Total roboports: %d", #storage.creepers),
		string.format("Active: %d | Sleeping: %d", active, sleeping),
		"",
		"By Surface:"
	}

	for surface_name, counts in pairs(by_surface) do
		local disabled = is_surface_disabled(surface_name) and " [DISABLED]" or ""
		table.insert(status_lines, string.format("  %s: %d active, %d sleeping%s", surface_name, counts.active, counts.sleeping, disabled))
	end

	local output = table.concat(status_lines, "\n")
	if event.player_index then
		game.get_player(event.player_index).print(output)
	else
		game.print(output)
	end
end)
