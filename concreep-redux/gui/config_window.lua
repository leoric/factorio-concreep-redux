function gui_init()
	-- Set up GUI event handlers for roboport sidebar info
end

-- Helper function to find a creeper by roboport entity
local function find_creeper_for_roboport(roboport)
	if not storage.creepers then return nil end

	for _, creeper in pairs(storage.creepers) do
		if creeper.roboport and creeper.roboport.valid and creeper.roboport == roboport then
			return creeper
		end
	end
	return nil
end

-- Create or update the roboport info GUI
local function update_roboport_gui(player, entity)
	if not entity or not entity.valid or entity.type ~= "roboport" then
		return
	end

	-- Remove any existing concreep GUI for this player
	local existing = player.gui.relative["concreep_roboport_info"]
	if existing then
		existing.destroy()
	end

	-- Find the creeper data for this roboport
	local creeper = find_creeper_for_roboport(entity)
	if not creeper then
		return
	end

	-- Create the GUI frame anchored to the roboport GUI
	local frame = player.gui.relative.add{
		type = "frame",
		name = "concreep_roboport_info",
		direction = "vertical",
		anchor = {
			gui = defines.relative_gui_type.roboport_gui,
			position = defines.relative_gui_position.right
		}
	}

	-- Add title
	local title_flow = frame.add{
		type = "flow",
		direction = "horizontal"
	}
	title_flow.style.horizontal_spacing = 8

	title_flow.add{
		type = "label",
		caption = "Concreep Status",
		style = "frame_title"
	}

	-- Add content frame
	local content_frame = frame.add{
		type = "frame",
		direction = "vertical",
		style = "inside_shallow_frame"
	}
	content_frame.style.padding = 8

	-- Add a flow inside the frame for proper spacing
	local content = content_frame.add{
		type = "flow",
		direction = "vertical"
	}
	content.style.vertical_spacing = 4

	-- Status line
	local status_text
	if creeper.ready_tick and game.tick < creeper.ready_tick then
		-- Roboport is waiting for pattern setup
		local seconds_remaining = math.ceil((creeper.ready_tick - game.tick) / 60)
		status_text = string.format("[color=cyan]Waiting for pattern (%ds)[/color]", seconds_remaining)
	elseif creeper.off then
		status_text = "[color=gray]Sleeping[/color]"
	elseif creeper.upgrade then
		status_text = "[color=yellow]Upgrading tiles[/color]"
	else
		status_text = "[color=green]Active[/color]"
	end

	content.add{
		type = "label",
		caption = {"", "Status: ", status_text}
	}

	-- Radius line
	local base_radius = entity.logistic_cell.construction_radius
	if settings.global["concreep-logistics-limit"].value then
		base_radius = entity.logistic_cell.logistic_radius
	end
	local concreep_range_setting = settings.global["concreep-range"].value / 100
	local target_radius = base_radius * concreep_range_setting

	content.add{
		type = "label",
		caption = {"", "Radius: ", string.format("%.1f / %.1f", creeper.radius, target_radius)}
	}

	-- Mode line
	local mode_text = "Standard"
	if settings.global["concreep-tile-mode"].value == "pattern" then
		mode_text = "Pattern"
	elseif settings.global["concreep-tile-mode"].value == "coverage-type" then
		mode_text = "Coverage Type"
	end

	-- Check if in space (Space Exploration)
	if remote.interfaces["space-exploration"] then
		local surface = entity.surface
		local surface_type = remote.call("space-exploration", "get_surface_type", { surface_index = surface.index })
		if surface_type == "orbit" then
			mode_text = "Space Platform"
		end
	end

	content.add{
		type = "label",
		caption = {"", "Mode: ", mode_text}
	}

	-- Show surface if it's disabled
	if is_surface_disabled and is_surface_disabled(creeper.surface) then
		content.add{
			type = "label",
			caption = "[color=red]Surface disabled in settings[/color]"
		}
	end
end

-- Event handler for when a GUI is opened
script.on_event(defines.events.on_gui_opened, function(event)
	local player = game.get_player(event.player_index)
	if not player then return end

	local entity = event.entity
	if entity and entity.valid and entity.type == "roboport" then
		update_roboport_gui(player, entity)
	end
end)

-- Event handler for when a GUI is closed
script.on_event(defines.events.on_gui_closed, function(event)
	local player = game.get_player(event.player_index)
	if not player then return end

	-- Clean up the concreep GUI when roboport is closed
	local gui = player.gui.relative["concreep_roboport_info"]
	if gui then
		gui.destroy()
	end
end)

-- Update GUI periodically for open roboports
script.on_nth_tick(60, function()
	-- Safety: pcall to prevent freezes from GUI errors
	local success, err = pcall(function()
		if not storage.creepers then return end

		for _, player in pairs(game.players) do
			if player.opened_gui_type == defines.gui_type.entity then
				local entity = player.opened
				if entity and entity.valid and entity.type == "roboport" then
					update_roboport_gui(player, entity)
				end
			end
		end
	end)

	if not success then
		game.print("[Concreep Redux] GUI update error: " .. tostring(err))
	end
end)

local function toggle_interface(player)
	--local main_frame = player.gui.screen.ccr_config_window
	--
	--if main_frame == nil then
	--	build_interface(player)
	--else
	--	main_frame.destroy()
	--end
end

function build_interface(player)
	--local screen_element = player.gui.screen
	--local main_frame = screen_element.add{type="frame", name="ccr_config_window", caption={"ccr.config_window_caption"}}
	--
	--local outer_frame_1 = main_frame.add{type="frame", name="outer_frame_1", direction="horizontal", style="ccr_content_frame"}
	--local tile_list_frame = outer_frame_1.add{type="frame", name="tile_list_frame", direction="vertical", style="ccr_content_frame", caption="Tile Priority"}
	--local settings_frame = outer_frame_1.add{type="frame", name="settings_frame", direction="vertical", style="ccr_content_frame", caption="Settings"}
	--
	--main_frame.style.size = {800, 600}
	--main_frame.auto_center = true
	--
	--build_tile_list_frame(tile_list_frame)
	--
	--player.opened = main_frame
end

function build_tile_list_frame(tile_list_frame)
--	tile_list_frame.clear()
--
--	local main_vertical_flow = tile_list_frame.add{type="flow", direction="vertical"}
--
----	local horizontal_flow = main_vertical_flow.add{type="frame", style="tile_list_row"}
----	horizontal_flow.add{type="choose-elem-button", elem_type="item", elem_filters={{filter="place-as-tile"}}}
--
--	build_tile_list_row(tile_list_frame)
--	build_tile_list_row(tile_list_frame)
--	build_tile_list_row(tile_list_frame)
--	build_tile_list_row(tile_list_frame)
--	build_tile_list_row(tile_list_frame)
--	build_tile_list_row(tile_list_frame)
--	build_tile_list_row(tile_list_frame)
--	build_tile_list_row(tile_list_frame)
end

function build_tile_list_row(tile_list_frame)
	--local row_frame = tile_list_frame.add{type="frame", direction="horizontal", style="ccr_tile_list_row"}
	--
	--row_frame.add{type="choose-elem-button", elem_type="item", elem_filters={{filter="place-as-tile"}}}
	--row_frame.add{type="empty-widget", elem_type="filler", style="ccr_tile_list_draghandle"}
end

script.on_event(defines.events.on_gui_click, function (event)
	--if event.element.name == "ccr_controls_toggle" then
	--	local player_global = global.players[event.player_index]
	--	player_global.controls_active = not player_global.controls_active
	--
	--	local control_toggle = event.element
	--	control_toggle.caption = (player_global.controls_active) and {"ccr.deactivate"} or {"ccr.activate"}
	--end
end)

script.on_event(defines.events.on_gui_closed, function(event)
	--if event.element and event.element.name == "ccr_config_window" then
	--	local player = game.get_player(event.player_index)
	--	toggle_interface(player)
	--end
end)

script.on_event("concreep_toggle_interface", function(event)
	--local player = game.get_player(event.player_index)
	--toggle_interface(player)
end)