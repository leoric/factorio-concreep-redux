function creep_init()
	storage.creepers        = {}
	storage.active_creepers = 0
	storage.space_age_active = false
	wake_up_creepers()
end

function wake_up_creepers()
	storage.index           = 1
	storage.active_creepers = 0

	for _, surface in pairs(game.surfaces) do
		for _, port in pairs(surface.find_entities_filtered { type = "roboport" }) do
			if validate(port) then
				addPort(port)
			end
		end
	end

	count_active_creepers()
end

function check_roboports()
	if not storage.active_creepers then
		init()
		return
	end

	if #storage.creepers == 0 then
		wake_up_creepers()
		return
	end

	-- If very few roboports are active, randomly wake up some sleeping ones to recheck
	-- This handles cases where upgrades become available or new tiles are added
	local total_creepers = #storage.creepers
	if total_creepers > 0 and storage.active_creepers < math.max(5, total_creepers * 0.05) then
		-- Wake up 1-3 random sleeping roboports
		local sleeping_indices = {}
		for i = 1, total_creepers do
			if storage.creepers[i].off then
				table.insert(sleeping_indices, i)
			end
		end

		if #sleeping_indices > 0 then
			local to_wake = math.min(3, #sleeping_indices)
			for i = 1, to_wake do
				local random_index = math.random(1, #sleeping_indices)
				local creeper_index = sleeping_indices[random_index]
				storage.creepers[creeper_index].off = false
				storage.creepers[creeper_index].removal_counter = 0
				table.remove(sleeping_indices, random_index)
			end
			count_active_creepers()
		end
	end

	local max_creepers = settings.global["concreep-update-count"].value

	for i = 1, max_creepers do
		if i > #storage.creepers then return end

		local creeper = get_creeper()
		if not creeper then goto continue end

		local roboport = creeper.roboport
		if roboport.logistic_network and roboport.logistic_network.valid then
			if is_roboport_fully_powered(roboport) then
				creep(creeper)
			end
		end

		:: continue ::
	end
end

function is_roboport_fully_powered(roboport)
	if roboport.prototype.electric_energy_source_prototype then
		return roboport.prototype.electric_energy_source_prototype.buffer_capacity == roboport.energy
	end
	return true -- Assume fully powered if not electric
end

function is_valid_creeper(creeper)
	return creeper and creeper.roboport and creeper.roboport.valid and creeper.surface
end

function remove_creeper(index)
	table.remove(storage.creepers, index)
	count_active_creepers()
end

function is_surface_disabled(surface_name)
	if script.active_mods["space-age"] then
		local disabled_surfaces = {
			["nauvis"] = not settings.global["concreep-nauvis-enable"].value,
			["gleba"] = not settings.global["concreep-gleba-enable"].value,
			["fulgora"] = not settings.global["concreep-fulgora-enable"].value,
			["vulcanus"] = not settings.global["concreep-vulcanus-enable"].value,
			["aquilo"] = not settings.global["concreep-aquilo-enable"].value
		}
		return disabled_surfaces[surface_name]
	end
	return false
end

function get_creeper()
	-- Handle empty list
	if #storage.creepers == 0 then
		return nil
	end

	-- Loop through creepers to find the next active one
	-- Prevent infinite loops by tracking where we started
	local start_index = storage.index
	local iterations = 0
	local max_iterations = #storage.creepers + 1  -- Allow one full pass plus one

	while iterations < max_iterations do
		iterations = iterations + 1

		if storage.index > #storage.creepers then
			storage.index = 1
		end

		-- Safety check for empty list (could become empty during iteration)
		if #storage.creepers == 0 then
			return nil
		end

		local creeper = storage.creepers[storage.index]

		-- Remove invalid creepers (deleted roboports)
		if not is_valid_creeper(creeper) then
			remove_creeper(storage.index)
			-- Don't increment index - removal shifts array
			-- Adjust start_index if we removed before it
			if storage.index < start_index then
				start_index = start_index - 1
			end
		else
			storage.index = storage.index + 1

			-- Skip sleeping roboports and disabled surfaces
			if not creeper.off and not is_surface_disabled(creeper.surface) then
				return creeper
			end

			-- If we've looped back to where we started, nothing is active
			if storage.index == start_index or (storage.index == 1 and start_index > #storage.creepers) then
				return nil
			end
		end
	end

	-- Safety: should never reach here, but return nil if we do
	return nil
end

function creep(creeper)
	local roboport                    = creeper.roboport

	-- Check if roboport is ready to work (pattern delay in pattern mode)
	if creeper.ready_tick and game.tick < creeper.ready_tick then
		-- Check if it's time to re-capture the pattern (5 seconds before ready)
		if game.tick >= creeper.ready_tick - 300 and not creeper.pattern_recaptured then
			-- Re-capture pattern now that player has had time to place tiles
			local pattern_size = settings.global["concreep-pattern-size"].value
			local pattern, it, pattern_offset = capture_pattern(roboport, pattern_size)
			creeper.pattern = pattern
			creeper.item = it
			creeper.pattern_offset = pattern_offset
			creeper.pattern_recaptured = true
		end
		return  -- Not ready yet
	end

	local idle_bot_percentage_setting = settings.global["concreep-idle-bot-percentage"].value / 100

	local available_bots              = roboport.logistic_network.available_construction_robots
	local total_bots                  = roboport.logistic_network.all_construction_robots
	local available_bot_percentage    = available_bots / total_bots

	-- If we don't have enough idle bots, break out of this roboport here
	if (available_bot_percentage < idle_bot_percentage_setting) then return end

	local base_radius = roboport.logistic_cell.construction_radius
	if (settings.global["concreep-logistics-limit"].value) then
		base_radius = roboport.logistic_cell.logistic_radius
	end

	local target_creep_radius        = base_radius  -- Store unadjusted target

	local surface                    = roboport.surface
	local force                      = roboport.force
	local active_port_factor         = math.min(10, storage.active_creepers or 1)

	local minimum_item_count_setting = settings.global["concreep-minimum-item-count"].value
	local concreep_range_setting     = settings.global["concreep-range"].value / 100
	local tile_mode                  = settings.global["concreep-tile-mode"].value
	local is_circular                = settings.global["concreep-circular-creep"].value

	-- Switch to square mode if radius gets too large (to avoid 2000 tile search limit)
	if is_circular and creeper.radius >= 43 then
		creeper.force_square_mode = true
	end

	-- Use square mode if forced, otherwise use global setting
	if creeper.force_square_mode then
		is_circular = false
	end

	local current_radius  = math.min(creeper.radius, concreep_range_setting * target_creep_radius)

	-- For circular mode, adjust the search radius to reach corners of the square area
	if is_circular then
		current_radius = get_adjusted_radius(current_radius)
	end

	-- Figure out how many bots to use for this creep. This is limited to no more than the number allowed to be working, and is further divided by the number of roboports in the network.
	-- This keeps any individual port from pulling too much of the network's bots towards it all at once, reducing bot travel/migration.

	local working_bots    = total_bots - available_bots
	local usable_robots   = math.max(0, math.ceil((((1 - idle_bot_percentage_setting) * total_bots) - working_bots) / active_port_factor))

	creeper.usable_robots = usable_robots
	if force.max_successful_attempts_per_tick_per_construction_queue * 60 < usable_robots then
		force.max_successful_attempts_per_tick_per_construction_queue = math.floor(usable_robots / 60)
	end

	local area     = {
		{ roboport.position.x - current_radius, roboport.position.y - current_radius },
		{ roboport.position.x + current_radius, roboport.position.y + current_radius }
	}

	-- Calculate the actual roboport construction area (for constraining tile placement)
	local max_construction_radius = base_radius * concreep_range_setting
	local construction_area = {
		{ roboport.position.x - max_construction_radius, roboport.position.y - max_construction_radius },
		{ roboport.position.x + max_construction_radius, roboport.position.y + max_construction_radius }
	}

	local in_space = false
	if remote.interfaces["space-exploration"] then
		in_space = "orbit" == remote.call("space-exploration", "get_surface_type", { surface_index = surface.index })
	end

	local creep_data = {
		position                   = roboport.position,
		current_radius             = current_radius,
		unadjusted_radius          = creeper.radius,  -- Store unadjusted for comparison
		target_creep_radius        = target_creep_radius * concreep_range_setting,
		usable_robots              = usable_robots,
		area                       = area,
		construction_area          = construction_area,
		minimum_item_count_setting = minimum_item_count_setting,
		is_circular                = is_circular
	}

	if in_space then
		space_creep(creeper, creep_data)
	elseif tile_mode == "coverage-type" then
		area_tile_creep(creeper, creep_data)
	else
		standard_creep(creeper, creep_data)
	end
end

function landfill_creep(creeper, creep_data)
	local roboport     = creeper.roboport
	local surface      = roboport.surface
	local force        = roboport.force

	local ghosts       = surface.count_entities_filtered { area = creep_data["area"], name = "tile-ghost", force = force }

	local virgin_tile_filter = get_virgin_tile_filter(creep_data)
	virgin_tile_filter.collision_mask = {"water_tile"}

	local water_tiles  = surface.find_tiles_filtered(virgin_tile_filter)

	-- If circular mode, filter to construction area
	if creep_data.is_circular then
		water_tiles = filter_tiles_to_construction_area(water_tiles, creep_data["construction_area"])
	end

	-- Wait for ghosts to finish building first.
	if ghosts >= #water_tiles and ghosts > 0 then
		return
	end

	local count          = 0
	local landfill_count = math.max(0,
									roboport.logistic_network.get_item_count("landfill") - creep_data["minimum_item_count_setting"])

	local pump_radius = settings.global["concreep-pump-radius"].value

	for i = #water_tiles, 1, -1 do
		if count < landfill_count then
			local pump_count = 0
			if pump_radius > 0 then
				pump_count = surface.count_entities_filtered { position = water_tiles[i].position, radius = pump_radius, name = "offshore-pump"}
				pump_count = pump_count + surface.count_entities_filtered { position = water_tiles[i].position, radius = pump_radius, type = "entity-ghost", ghost_name = "offshore-pump"}
			end

			if pump_count == 0 then
				count = count + build_tile(roboport, "landfill", water_tiles[i].position, creep_data["construction_area"])
				creeper.removal_counter = 0
			end
		end
	end
end

function standard_creep(creeper, creep_data)
	local roboport     = creeper.roboport
	local surface      = roboport.surface
	local force        = roboport.force

	if settings.global["creep-landfill"].value then
		landfill_creep(creeper, creep_data)
	end

	local ghosts       = surface.count_entities_filtered { area = creep_data["area"], name = "tile-ghost", force = force }
	local virgin_tiles = get_landfill_and_virgin_tiles(surface, creep_data)

	-- Filter out tiles near agricultural towers
	local agricultural_tower_radius = settings.global["concreep-agricultural-tower-radius"].value
	virgin_tiles = filter_agricultural_tower_tiles(surface, virgin_tiles, agricultural_tower_radius)

	-- Wait for ghosts to finish building first.
	if #virgin_tiles > 0 and ghosts >= #virgin_tiles and ghosts > 0 then
		return
	end

	local count                  = 0
	local creep_brick_setting    = settings.global["creep-brick"].value
	local tile_mode              = settings.global["concreep-tile-mode"].value

	local refined_concrete_count = math.max(0,
											roboport.logistic_network.get_item_count("refined-concrete") - creep_data["minimum_item_count_setting"])
	local refined_hazard_concrete_count = math.max(0,
												   roboport.logistic_network.get_item_count("refined-hazard-concrete") - creep_data["minimum_item_count_setting"])
	local concrete_count         = math.max(0,
											roboport.logistic_network.get_item_count("concrete") - creep_data["minimum_item_count_setting"])
	local brick_count            = math.max(0,
											roboport.logistic_network.get_item_count("stone-brick") - creep_data["minimum_item_count_setting"])

	for i = #virgin_tiles, 1, -1 do
		local ghost_type

		-- Check if pattern mode is enabled and pattern exists
		if tile_mode == "pattern" and creeper.pattern then
			local pattern_size = creeper.pattern_size or 4  -- Default to 4 for backwards compatibility

			-- Use stored offset for new roboports, or calculate for old ones
			local offset_x, offset_y
			if creeper.pattern_offset then
				offset_x = creeper.pattern_offset[1]
				offset_y = creeper.pattern_offset[2]
			else
				-- Backwards compatibility: calculate offset from roboport position
				local half_size = pattern_size / 2
				offset_x = math.floor(roboport.position.x - half_size)
				offset_y = math.floor(roboport.position.y - half_size)
			end

			-- Calculate pattern indices based on tile position, wrapping around pattern size
			local tile_x = math.floor(virgin_tiles[i].position.x)
			local tile_y = math.floor(virgin_tiles[i].position.y)
			local pattern_x = ((tile_x - offset_x) % pattern_size) + 1
			local pattern_y = ((tile_y - offset_y) % pattern_size) + 1

			if creeper.pattern[pattern_x] and creeper.pattern[pattern_x][pattern_y] then
				if creeper.item[pattern_x] and creeper.item[pattern_x][pattern_y] and roboport.logistic_network.get_item_count(creeper.item[pattern_x][pattern_y]) > creep_data["minimum_item_count_setting"] then
					ghost_type = creeper.pattern[pattern_x][pattern_y]
				end
			end
		end

		-- If pattern mode is disabled or no pattern tile found, use standard mode
		if not ghost_type then
			if count < refined_concrete_count then
				ghost_type = "refined-concrete"
			elseif count < concrete_count then
				ghost_type = "concrete"
			elseif creep_brick_setting and count < brick_count then
				ghost_type = "stone-path"
			end
		end

		if ghost_type then
			count = count + build_tile(roboport, ghost_type, virgin_tiles[i].position, creep_data["construction_area"])
		end

		creeper.removal_counter = 0
	end

	if count >= creep_data["usable_robots"] then
		return true
	end

	creep_data["usable_robots"] = creep_data["usable_robots"] - count
	count                       = 0

	--Still here?  Look for upgrades that need done
	local upgrade_target_types  = {}

	if settings.global["upgrade-brick"].value and (refined_concrete_count > 0 or concrete_count > 0) then
		table.insert(upgrade_target_types, "stone-path")
	end

	if settings.global["upgrade-concrete"].value and refined_concrete_count > 0 then
		table.insert(upgrade_target_types, "concrete")
	end

	if settings.global["upgrade-concrete"].value and refined_hazard_concrete_count > 0 then
		table.insert(upgrade_target_types, "hazard-concrete-left")
		table.insert(upgrade_target_types, "hazard-concrete-right")
	end

	if creeper.upgrade then
		if #upgrade_target_types > 0 then
			local upgradable_tiles_filter = get_upgrade_tile_filter(creep_data)

			upgradable_tiles_filter.name = upgrade_target_types
			upgradable_tiles_filter.limit = math.min(math.max(concrete_count, refined_concrete_count, 0), creep_data["usable_robots"])

			local upgradable_tiles = surface.find_tiles_filtered(upgradable_tiles_filter)

			-- If circular mode, filter to construction area
			if creep_data.is_circular then
				upgradable_tiles = filter_tiles_to_construction_area(upgradable_tiles, creep_data["construction_area"])
			end

			for _, target_tile in pairs(upgradable_tiles) do
				local tile_type = "refined-concrete"

				if target_tile.name == "hazard-concrete-left" then
					tile_type = "refined-hazard-concrete-left"
				elseif target_tile.name == "hazard-concrete-right" then
					tile_type = "refined-hazard-concrete-right"
				elseif count >= refined_concrete_count then
					tile_type = "concrete"
				end

				count                   = count + build_tile(roboport, tile_type, target_tile.position, creep_data["construction_area"])
				creeper.removal_counter = 0
			end

			if count >= creep_data["usable_robots"] then
				return true
			end
		end
	end

	standard_sleep_check(creeper, creep_data, upgrade_target_types)
	return false
end

function is_tile_in_area(tile_pos, area)
	-- Tile positions are at the center of the tile.
	-- Use >= for min bounds (top/left) and < for max bounds (bottom/right) to prevent off-by-one
	return tile_pos.x >= area[1][1] and tile_pos.x < area[2][1] and
	       tile_pos.y >= area[1][2] and tile_pos.y < area[2][2]
end

function filter_tiles_to_construction_area(tiles, construction_area)
	if not construction_area then
		return tiles
	end

	local filtered = {}
	for _, tile in pairs(tiles) do
		if is_tile_in_area(tile.position, construction_area) then
			table.insert(filtered, tile)
		end
	end
	return filtered
end

function get_landfill_and_virgin_tiles(surface, creep_data)
	local is_circular = creep_data.is_circular  -- Cache the circular mode check

	-- First, look for landfill tiles that need concreting
	local landfill_filter = {
		name = "landfill",
		limit = creep_data["usable_robots"],
		area = creep_data["area"]
	}

	if is_circular then
		landfill_filter.position = creep_data.position
		landfill_filter.radius = creep_data["current_radius"]
		landfill_filter.area = nil  -- Remove area constraint from filter, we'll filter manually
	end

	local virgin_tiles = surface.find_tiles_filtered(landfill_filter)

	-- If circular mode, filter to only tiles within construction area
	if is_circular then
		virgin_tiles = filter_tiles_to_construction_area(virgin_tiles, creep_data["construction_area"])
	end

	-- If no landfill tiles found, look for regular virgin tiles
	if #virgin_tiles == 0 then
		virgin_tiles = surface.find_tiles_filtered(get_virgin_tile_filter(creep_data))

		-- If circular mode, filter those too
		if is_circular then
			virgin_tiles = filter_tiles_to_construction_area(virgin_tiles, creep_data["construction_area"])
		end
	end

	return virgin_tiles
end

function get_tile_filter(creep_data, include_hidden_tile_check)
	local filter = {
		limit = creep_data["usable_robots"],
		collision_mask = "ground_tile",
		area = creep_data["area"]
	}

	if include_hidden_tile_check then
		filter.has_hidden_tile = false
	end

	if creep_data.is_circular then
		filter.position = creep_data.position
		filter.radius = creep_data["current_radius"]
		filter.area = nil  -- Remove area, we'll filter manually
	end

	return filter
end

function get_virgin_tile_filter(creep_data)
	return get_tile_filter(creep_data, true)
end

function get_upgrade_tile_filter(creep_data)
	return get_tile_filter(creep_data, false)
end

function area_tile_creep(creeper, creep_data)
	local roboport     = creeper.roboport
	local surface      = roboport.surface
	local force        = roboport.force

	if settings.global["creep-landfill"].value then
		landfill_creep(creeper, creep_data)
	end

	local ghosts       = surface.count_entities_filtered({ area = creep_data["area"], name = "tile-ghost", force = force })
	local virgin_tiles = get_landfill_and_virgin_tiles(surface, creep_data)

	-- Filter out tiles near agricultural towers
	local agricultural_tower_radius = settings.global["concreep-agricultural-tower-radius"].value
	virgin_tiles = filter_agricultural_tower_tiles(surface, virgin_tiles, agricultural_tower_radius)

	-- Wait for ghosts to finish building first.
	if #virgin_tiles > 0 and ghosts >= #virgin_tiles and ghosts > 0 then
		return
	end

	local logistic_area_item          = settings.global["concreep-logistic-area-tile"].value
	local construction_area_item      = settings.global["concreep-construction-area-tile"].value

	local logistic_area_tile          = settings.global["concreep-logistic-area-tile"].value
	local construction_area_tile      = settings.global["concreep-construction-area-tile"].value

	if logistic_area_tile == 'stone-brick' then
		logistic_area_tile          = "stone-path"
	end

	if construction_area_tile == 'stone-brick' then
		construction_area_tile      = "stone-path"
	end

	local minimum_item_count_setting  = settings.global["concreep-minimum-item-count"].value

	local count                       = 0

	local logistic_radius             = roboport.logistic_cell.logistic_radius
	local available_logistic_tile     = math.max(0,
												 roboport.logistic_network.get_item_count(logistic_area_item) - minimum_item_count_setting)
	local available_construction_tile = math.max(0,
												 roboport.logistic_network.get_item_count(construction_area_item) - minimum_item_count_setting)

	local roboport_x                  = roboport.position.x
	local roboport_y                  = roboport.position.y

	for i = #virgin_tiles, 1, -1 do
		local ghost_type
		local tile_x = virgin_tiles[i].position.x
		local tile_y = virgin_tiles[i].position.y

		if tile_x > roboport_x then
			tile_x = tile_x + 1
		end

		if tile_y > roboport_y then
			tile_y = tile_y + 1
		end

		if (math.abs(tile_x - roboport_x) > logistic_radius or math.abs(tile_y - roboport_y) > logistic_radius) and available_construction_tile > 0 then
			available_construction_tile = available_construction_tile - 1
			ghost_type                  = construction_area_tile
		elseif (math.abs(tile_x - roboport_x) <= logistic_radius and math.abs(tile_y - roboport_y) <= logistic_radius) and available_logistic_tile > 0 then
			available_logistic_tile = available_logistic_tile - 1
			ghost_type              = logistic_area_tile
		end

		if ghost_type then
			count = count + build_tile(roboport, ghost_type, virgin_tiles[i].position, creep_data["construction_area"])
		end

		creeper.removal_counter = 0
	end

	if count >= creep_data["usable_robots"] then
		return true
	end

	area_tile_sleep_check(creeper, creep_data)
	return false
end

function space_creep(creeper, creep_data)
	local roboport     = creeper.roboport
	local surface      = roboport.surface
	local force        = roboport.force

	local ghosts       = surface.count_entities_filtered { area = creep_data["area"], name = "tile-ghost", force = force }

	local virgin_tile_filter = get_virgin_tile_filter(creep_data)
	virgin_tile_filter.name = "se-space"
	local virgin_tiles = surface.find_tiles_filtered(virgin_tile_filter)

	-- Wait for ghosts to finish building first.
	if ghosts >= #virgin_tiles and ghosts > 0 then
		return
	end

	local count                = 0

	local space_scaffold_count = math.max(0,
										  roboport.logistic_network.get_item_count("se-space-platform-scaffold") - creep_data["minimum_item_count_setting"])
	local space_tile_count     = math.max(0,
										  roboport.logistic_network.get_item_count("se-space-platform-plating") - creep_data["minimum_item_count_setting"])

	for i = #virgin_tiles, 1, -1 do
		local ghost_type

		if count < space_tile_count then
			ghost_type = "se-space-platform-plating"
		elseif count < space_scaffold_count then
			ghost_type = "se-space-platform-scaffold"
		end

		if ghost_type then
			count = count + build_tile(roboport, ghost_type, virgin_tiles[i].position, creep_data["construction_area"])
		end

		creeper.removal_counter = 0
	end

	if count >= creep_data["usable_robots"] then
		return true
	end

	creep_data["usable_robots"] = creep_data["usable_robots"] - count
	count                       = 0

	--Still here?  Look for upgrades that need done
	local upgrade_target_types  = {}

	if creeper.upgrade then
		if settings.global["upgrade-space-scaffold"].value and space_tile_count > 0 then
			table.insert(upgrade_target_types, "se-space-platform-scaffold")
			table.insert(upgrade_target_types, "se-asteroid")

			if #upgrade_target_types > 0 then
				local upgradable_tiles_filter = get_upgrade_tile_filter(creep_data)
				upgradable_tiles_filter.name = upgrade_target_types
				upgradable_tiles_filter.limit = math.min(math.max(space_tile_count, 0), creep_data["usable_robots"])

				local upgradable_tiles = surface.find_tiles_filtered(upgradable_tiles_filter)

				-- If circular mode, filter to construction area
				if creep_data.is_circular then
					upgradable_tiles = filter_tiles_to_construction_area(upgradable_tiles, creep_data["construction_area"])
				end

				for _, target_tile in pairs(upgradable_tiles) do
					local tile_type         = "se-space-platform-plating"
					count                   = count + build_tile(roboport, tile_type, target_tile.position, creep_data["construction_area"])
					creeper.removal_counter = 0
				end

				if count >= creep_data["usable_robots"] then
					return true
				end
			end
		end
	end

	space_sleep_check(creeper, creep_data, upgrade_target_types)
	return false
end

function sleep_check(creeper, creep_data, upgrade_target_types, virgin_tile_check_filter)
	local roboport = creeper.roboport
	local surface  = roboport.surface

	-- Check if there are any virgin tiles left using provided filter (or default)
	local virgin_count
	if virgin_tile_check_filter then
		virgin_count = surface.count_tiles_filtered(virgin_tile_check_filter)
	else
		local virgin_tiles = surface.find_tiles_filtered(get_virgin_tile_filter(creep_data))
		-- If circular mode, filter to construction area
		if creep_data.is_circular and creep_data["construction_area"] then
			virgin_tiles = filter_tiles_to_construction_area(virgin_tiles, creep_data["construction_area"])
		end
		-- Exclude tiles protected by agricultural towers to avoid getting stuck when only blocked tiles remain
		local agricultural_tower_radius = settings.global["concreep-agricultural-tower-radius"].value
		virgin_tiles = filter_agricultural_tower_tiles(surface, virgin_tiles, agricultural_tower_radius)
		virgin_count = #virgin_tiles
	end

	if virgin_count == 0 then
		-- Compare unadjusted radius against target (both are square radii)
		local radius_to_compare = creep_data.unadjusted_radius or creep_data["current_radius"]
		if radius_to_compare < creep_data["target_creep_radius"] then
			-- Expand radius (but don't exceed the target)
			creeper.radius = math.min(creeper.radius + 1, creep_data["target_creep_radius"])
		else
			-- Check if there are upgrades to do
			local switch = true
			if upgrade_target_types and #upgrade_target_types > 0 then
				local upgrade_tiles = surface.find_tiles_filtered { name = upgrade_target_types, area = creep_data["area"], limit = 1 }
				-- If circular mode, filter to construction area
				if creep_data.is_circular and creep_data["construction_area"] then
					upgrade_tiles = filter_tiles_to_construction_area(upgrade_tiles, creep_data["construction_area"])
				end
				if #upgrade_tiles > 0 then
					switch = false
				end
			end

			if switch then
				-- No more work, put creeper to sleep
				creeper.off             = true
				creeper.removal_counter = 1
				storage.active_creepers = storage.active_creepers - 1
			else
				-- Switch to upgrade mode
				creeper.radius  = 3
				creeper.upgrade = true
			end
		end
	end
end

function area_tile_sleep_check(creeper, creep_data)
	sleep_check(creeper, creep_data, nil, nil)
end

function standard_sleep_check(creeper, creep_data, upgrade_target_types)
	sleep_check(creeper, creep_data, upgrade_target_types, nil)
end

function space_sleep_check(creeper, creep_data, upgrade_target_types)
	sleep_check(creeper, creep_data, upgrade_target_types, { area = creep_data["area"], name = "se-space", collision_mask = "empty_space" })
end

function filter_agricultural_tower_tiles(surface, tiles, base_radius)
	-- Fast-paths and guards
	if base_radius == 0 or not (prototypes and prototypes.entity and prototypes.entity["agricultural-tower"]) then
		return tiles
	end
	if not tiles or #tiles == 0 then
		return tiles
	end

	-- Build a bounding box around provided tiles and query nearby towers once
	local min_x, min_y = math.huge, math.huge
	local max_x, max_y = -math.huge, -math.huge
	for i = 1, #tiles do
		local p = tiles[i].position
		if p.x < min_x then min_x = p.x end
		if p.y < min_y then min_y = p.y end
		if p.x > max_x then max_x = p.x end
		if p.y > max_y then max_y = p.y end
	end
	local pad = base_radius * 2 + 1
	local area = { { min_x - pad, min_y - pad }, { max_x + pad, max_y + pad } }

	local towers = surface.find_entities_filtered { area = area, name = "agricultural-tower" }
	local ghost_towers = surface.find_entities_filtered { area = area, type = "entity-ghost", ghost_name = "agricultural-tower" }

	-- If no towers nearby, nothing to filter
	if (#towers == 0) and (#ghost_towers == 0) then
		return tiles
	end

	-- Build a compact list of tower centers with effective square radii
	local all = {}
	for _, t in pairs(towers) do
		local r = base_radius
		if t.quality and t.quality.level then
			r = base_radius + (t.quality.level * 2)
		end
		all[#all + 1] = { x = t.position.x, y = t.position.y, r = r }
	end
	for _, g in pairs(ghost_towers) do
		local r = base_radius
		if g.ghost_quality and g.ghost_quality.level then
			r = base_radius + (g.ghost_quality.level * 2)
		end
		all[#all + 1] = { x = g.position.x, y = g.position.y, r = r }
	end

	local filtered = {}
	for i = 1, #tiles do
		local p = tiles[i].position
		local px = math.floor(p.x) + 0.5
		local py = math.floor(p.y) + 0.5
		local near = false
		for j = 1, #all do
			local dx = px - all[j].x
			local dy = py - all[j].y
			-- Square (Chebyshev) distance check to match is_near_agricultural_tower
			if math.max(math.abs(dx), math.abs(dy)) < all[j].r then
				near = true
				break
			end
		end
		if not near then
			filtered[#filtered + 1] = tiles[i]
		end
	end
	return filtered
end

function is_near_agricultural_tower(surface, position, base_radius)
	if base_radius > 0 and prototypes.entity["agricultural-tower"] then
		-- Use tile center for distance calculations to avoid off-by-one allowing placements too close
		local px = math.floor(position.x) + 0.5
		local py = math.floor(position.y) + 0.5
		-- Check for actual towers first
		local towers = surface.find_entities_filtered { position = position, radius = base_radius * 2, name = "agricultural-tower" }
		for _, tower in pairs(towers) do
			local tower_radius = base_radius
			-- Adjust radius based on quality if available
			if tower.quality and tower.quality.level then
				-- Quality levels: 0=normal, 1=uncommon, 2=rare, 3=epic, 4=legendary
				-- Each quality level increases working area, so increase our clearance
				tower_radius = base_radius + (tower.quality.level * 2)
			end
			-- Check if position is within this tower's square radius (axis-aligned)
			local dx = px - tower.position.x
			local dy = py - tower.position.y
			if math.max(math.abs(dx), math.abs(dy)) < tower_radius then
				return true
			end
		end

		-- Check for ghost towers
		local ghost_towers = surface.find_entities_filtered { position = position, radius = base_radius * 2, type = "entity-ghost", ghost_name = "agricultural-tower" }
		for _, ghost in pairs(ghost_towers) do
			local tower_radius = base_radius
			-- Check ghost quality if available
			if ghost.ghost_quality and ghost.ghost_quality.level then
				tower_radius = base_radius + (ghost.ghost_quality.level * 2)
			end
			-- Use tile center for consistency with real tower check; axis-aligned square radius
			local dx = px - ghost.position.x
			local dy = py - ghost.position.y
			if math.max(math.abs(dx), math.abs(dy)) < tower_radius then
				return true
			end
		end
	end
	return false
end

function build_tile(roboport, type, position, construction_area)
	local count   = 0;
	local surface = roboport.surface
	local force   = roboport.force

	-- can_place_entity checks for conflicts, so we don't need a separate ghost check
	-- This is much faster than doing find_entities_filtered for every tile
	if surface.can_place_entity { name = "tile-ghost", position = position, inner_name = type, force = force } then
		local created = surface.create_entity { name = "tile-ghost", position = position, inner_name = type, force = force, expires = false }
		if created then
			count = count + 1
		else
			return count
		end
	else
		return count
	end

	local tree_area = { { position.x - 0.2, position.y - 0.2 }, { position.x + 0.8, position.y + 0.8 } }

	if settings.global["concreep-clear-trees"].value then
		for _, tree in pairs(surface.find_entities_filtered { type = "tree", area = tree_area }) do
			-- Check if tree center is within construction area
			if not construction_area or is_tile_in_area(tree.position, construction_area) then
				tree.order_deconstruction(roboport.force)
				count = count + 1
			end
		end
	end

	if settings.global["concreep-clear-rocks"].value then
		for _, rock in pairs(surface.find_entities_filtered { type = "simple-entity", area = tree_area }) do
			-- Check if rock center is within construction area
			if not construction_area or is_tile_in_area(rock.position, construction_area) then
				rock.order_deconstruction(roboport.force)
				count = count + 1
			end
		end
	end

	if settings.global["concreep-clear-cliffs"].value then
		for _, cliff in pairs(surface.find_entities_filtered { type = "cliff", limit = 1, area = tree_area }) do
			if roboport.logistic_network.get_item_count("cliff-explosives") > 0 then
				-- Check if cliff center is within construction area
				if not construction_area or is_tile_in_area(cliff.position, construction_area) then
					cliff.order_deconstruction(roboport.force)
					count = count + 1
				end
			end
		end
	end

	return count
end

--Is this a valid roboport?
function validate(entity)
	if entity and entity.valid and (entity.type == "roboport") and entity.logistic_cell and (entity.logistic_cell.construction_radius > 0) then
		return true
	end
	return false
end

function roboports(event)
	local entity = event.created_entity or event.destination or event.entity
	if not storage.creepers then
		init()
	end
	if validate(entity) then
		addPort(entity)
		count_active_creepers()
	end
end

-- Capture the tile pattern around a roboport position
-- Captures both placed tiles and tile ghosts
function capture_pattern(roboport, pattern_size)
	local surface = roboport.surface
	local force = roboport.force
	local half_size = pattern_size / 2

	-- Calculate pattern bounds to match visualization
	local pos = roboport.position
	local left = math.floor(pos.x - half_size)
	local top = math.floor(pos.y - half_size)
	local right = math.floor(pos.x + half_size)
	local bottom = math.floor(pos.y + half_size)

	-- Find all tile ghosts in the pattern area
	local area = {{left, top}, {right, bottom}}
	local tile_ghosts = surface.find_entities_filtered{
		area = area,
		name = "tile-ghost",
		force = force
	}

	-- Build a lookup table for ghosts by position
	local ghost_lookup = {}
	for _, ghost in pairs(tile_ghosts) do
		local gx = math.floor(ghost.position.x)
		local gy = math.floor(ghost.position.y)
		local key = gx .. "," .. gy
		ghost_lookup[key] = ghost
	end

	-- Capture the pattern the roboport sits on
	local pattern = {}
	local it      = {}

	local idx = 1
	for xx = left, right - 1, 1 do
		pattern[idx] = {}
		it[idx] = {}
		local idy = 1
		for yy = top, bottom - 1, 1 do
			-- Check for tile ghost first
			local key = xx .. "," .. yy
			local ghost = ghost_lookup[key]

			if ghost and ghost.valid and ghost.ghost_name then
				-- Use the ghost tile type
				local ghost_tile_name = ghost.ghost_name
				local ghost_prototype = prototypes.tile[ghost_tile_name]
				if ghost_prototype and ghost_prototype.items_to_place_this then
					it[idx][idy] = ghost_prototype.items_to_place_this[1] and prototypes.item[ghost_prototype.items_to_place_this[1].name] and ghost_prototype.items_to_place_this[1].name
					pattern[idx][idy] = ghost_tile_name
				end
			else
				-- No ghost, check actual tile
				local tile = surface.get_tile(xx, yy)
				if tile.hidden_tile and tile.prototype.items_to_place_this then
					it[idx][idy] = tile.prototype.items_to_place_this[1] and prototypes.item[tile.prototype.items_to_place_this[1].name] and tile.prototype.items_to_place_this[1].name
					pattern[idx][idy] = tile.name
				end
			end
			idy = idy + 1
		end
		idx = idx + 1
	end

	return pattern, it, {left, top}
end

function addPort(roboport)
	local surface = roboport.surface
	local pattern_size = settings.global["concreep-pattern-size"].value
	local tile_mode = settings.global["concreep-tile-mode"].value

	local pattern, it, pattern_offset = capture_pattern(roboport, pattern_size)

	-- In pattern mode, delay pattern capture and creeping to give player time to place tiles
	-- Store the tick when this roboport should start working (30 seconds = 1800 ticks)
	local ready_tick = nil
	if tile_mode == "pattern" then
		ready_tick = game.tick + 1800
	end

	table.insert(storage.creepers,
				 { roboport = roboport, surface = surface.name, radius = 3, pattern = pattern, item = it, pattern_size = pattern_size, pattern_offset = pattern_offset, off = false, removal_counter = 0, ready_tick = ready_tick })
end

-- Re-capture patterns for all roboports with the current pattern size
function recapture_all_patterns()
	if not storage.creepers then return end

	local pattern_size = settings.global["concreep-pattern-size"].value
	local recaptured = 0

	for _, creeper in pairs(storage.creepers) do
		if creeper.roboport and creeper.roboport.valid then
			local pattern, it, pattern_offset = capture_pattern(creeper.roboport, pattern_size)
			creeper.pattern = pattern
			creeper.item = it
			creeper.pattern_size = pattern_size
			creeper.pattern_offset = pattern_offset
			recaptured = recaptured + 1
		end
	end

	return recaptured
end

function count_active_creepers()
	storage.active_creepers = 0

	for i = #storage.creepers, 1, -1 do
		if storage.creepers[i].off == false then
			storage.active_creepers = storage.active_creepers + 1
		end
	end
end

function get_adjusted_radius(square_radius)
	if settings.global["concreep-circular-creep"].value then
		return math.ceil(square_radius * math.sqrt(2))
	end

	return square_radius
end

script.on_event(
		{
			defines.events.on_built_entity,
			defines.events.on_robot_built_entity,
			defines.events.on_entity_cloned,
			defines.events.script_raised_revive
		},
		roboports
)

script.on_nth_tick(settings.startup["concreep-update-frequency"].value * 60, check_roboports)
script.on_init(init)
script.on_configuration_changed(init)
