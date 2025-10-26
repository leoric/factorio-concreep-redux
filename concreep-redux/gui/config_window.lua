function gui_init()
	-- Set up GUI event handlers for roboport sidebar info
	-- Initialize per-player GUI state
	if not storage.player_guis then
		storage.player_guis = {}
	end

	-- Initialize per-surface settings overrides
	if not storage.surface_settings then
		storage.surface_settings = {}
	end
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

-- Get per-surface setting value (returns override if set, otherwise global default)
local function get_surface_setting(surface_name, setting_name)
	if not storage.surface_settings then
		storage.surface_settings = {}
	end
	if storage.surface_settings[surface_name] and storage.surface_settings[surface_name][setting_name] ~= nil then
		return storage.surface_settings[surface_name][setting_name]
	end
	return settings.global[setting_name].value
end

-- Set per-surface setting override
local function set_surface_setting(surface_name, setting_name, value)
	if not storage.surface_settings then
		storage.surface_settings = {}
	end
	if not storage.surface_settings[surface_name] then
		storage.surface_settings[surface_name] = {}
	end
	storage.surface_settings[surface_name][setting_name] = value
end

-- Clear per-surface setting override (revert to global)
local function clear_surface_setting(surface_name, setting_name)
	if not storage.surface_settings then
		storage.surface_settings = {}
	end
	if storage.surface_settings[surface_name] then
		storage.surface_settings[surface_name][setting_name] = nil
	end
end

-- Check if a surface has an override for a specific setting
local function has_surface_override(surface_name, setting_name)
	if not storage.surface_settings then
		storage.surface_settings = {}
	end
	return storage.surface_settings[surface_name] and storage.surface_settings[surface_name][setting_name] ~= nil
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

-- Helper to update surface tab when global settings change
local function update_surface_tab_for_global_change(player, setting_name)
	local main_frame = player.gui.screen.ccr_config_window
	if not main_frame then return end

	local tabbed_pane = main_frame.ccr_tabbed_pane
	if not tabbed_pane then return end

	local surfaces_content = tabbed_pane.ccr_surfaces_content
	if not surfaces_content then return end

	-- Get current surface from dropdown
	local surface_frame = surfaces_content.children[1]
	if not surface_frame then return end

	local dropdown = surface_frame.ccr_surface_dropdown
	if not dropdown then return end

	local surface_name = dropdown.items[dropdown.selected_index]
	if not surface_name then return end

	-- Rebuild the surface details to reflect new global values
	local details_frame = surface_frame.ccr_surface_details
	if details_frame then
		build_surface_details(details_frame, surface_name, player)
	end
end

-- Toggle the main settings window
local function toggle_interface(player)
	local main_frame = player.gui.screen.ccr_config_window

	if main_frame == nil then
		build_interface(player)
	else
		main_frame.destroy()
		storage.player_guis[player.index] = nil
	end
end

-- Build the main settings interface
function build_interface(player)
	local screen_element = player.gui.screen

	-- Create main frame
	local main_frame = screen_element.add{
		type = "frame",
		name = "ccr_config_window",
		caption = {"ccr.config_window_caption"},
		direction = "vertical"
	}
	main_frame.style.size = {900, 700}
	main_frame.auto_center = true

	-- Create tabbed pane
	local tabbed_pane = main_frame.add{
		type = "tabbed-pane",
		name = "ccr_tabbed_pane"
	}

	-- Tab 1: Global Settings
	local global_tab = tabbed_pane.add{type = "tab", caption = {"ccr.tab_global_settings"}}
	local global_content = tabbed_pane.add{
		type = "scroll-pane",
		name = "ccr_global_content",
		direction = "vertical"
	}
	global_content.style.maximal_height = 600
	tabbed_pane.add_tab(global_tab, global_content)
	build_global_settings_tab(global_content, player)

	-- Tab 2: Surfaces
	local surfaces_tab = tabbed_pane.add{type = "tab", caption = {"ccr.tab_surfaces"}}
	local surfaces_content = tabbed_pane.add{
		type = "scroll-pane",
		name = "ccr_surfaces_content",
		direction = "vertical"
	}
	surfaces_content.style.maximal_height = 600
	tabbed_pane.add_tab(surfaces_tab, surfaces_content)
	build_surfaces_tab(surfaces_content, player)

	-- Tab 3: Tile Placement
	local tiles_tab = tabbed_pane.add{type = "tab", caption = {"ccr.tab_tile_placement"}}
	local tiles_content = tabbed_pane.add{
		type = "scroll-pane",
		name = "ccr_tiles_content",
		direction = "vertical"
	}
	tiles_content.style.maximal_height = 600
	tabbed_pane.add_tab(tiles_tab, tiles_content)
	build_tile_placement_tab(tiles_content, player)

	-- Tab 4: System Status
	local status_tab = tabbed_pane.add{type = "tab", caption = {"ccr.tab_system_status"}}
	local status_content = tabbed_pane.add{
		type = "scroll-pane",
		name = "ccr_status_content",
		direction = "vertical"
	}
	status_content.style.maximal_height = 600
	tabbed_pane.add_tab(status_tab, status_content)
	build_system_status_tab(status_content, player)

	-- Button flow at bottom
	local button_flow = main_frame.add{
		type = "flow",
		name = "ccr_button_flow",
		direction = "horizontal"
	}
	button_flow.style.horizontal_spacing = 8
	button_flow.style.horizontally_stretchable = true
	button_flow.style.horizontal_align = "right"

	button_flow.add{
		type = "button",
		name = "ccr_close_button",
		caption = {"ccr.close"},
		style = "back_button"
	}

	-- Initialize player GUI state
	storage.player_guis[player.index] = {
		selected_tab = 1
	}

	player.opened = main_frame
end

-- Build Global Settings tab content
function build_global_settings_tab(container, player)
	-- Performance Section
	local perf_frame = container.add{
		type = "frame",
		direction = "vertical",
		caption = {"ccr.section_performance"}
	}
	perf_frame.style.horizontally_stretchable = true
	perf_frame.style.padding = 8

	local perf_table = perf_frame.add{
		type = "table",
		name = "ccr_perf_table",
		column_count = 3
	}
	perf_table.style.horizontally_stretchable = true
	perf_table.style.column_alignments[1] = "left"
	perf_table.style.column_alignments[2] = "right"
	perf_table.style.column_alignments[3] = "left"

	-- Update Frequency (startup setting, read-only)
	perf_table.add{type = "label", caption = {"mod-setting-name.concreep-update-frequency"}}
	perf_table.add{type = "label", caption = tostring(settings.startup["concreep-update-frequency"].value)}
	perf_table.add{type = "label", caption = {"ccr.seconds_readonly"}}

	-- Update Count
	perf_table.add{type = "label", caption = {"mod-setting-name.concreep-update-count"}}
	local update_count_slider = perf_table.add{
		type = "slider",
		name = "ccr_update_count_slider",
		minimum_value = 1,
		maximum_value = 50,
		value = settings.global["concreep-update-count"].value
	}
	update_count_slider.style.width = 200
	local update_count_textfield = perf_table.add{
		type = "textfield",
		name = "ccr_update_count_textfield",
		text = tostring(settings.global["concreep-update-count"].value),
		numeric = true
	}
	update_count_textfield.style.width = 60

	-- Idle Bot Percentage
	perf_table.add{type = "label", caption = {"mod-setting-name.concreep-idle-bot-percentage"}}
	local idle_bot_slider = perf_table.add{
		type = "slider",
		name = "ccr_idle_bot_slider",
		minimum_value = 0,
		maximum_value = 100,
		value = settings.global["concreep-idle-bot-percentage"].value
	}
	idle_bot_slider.style.width = 200
	local idle_bot_textfield = perf_table.add{
		type = "textfield",
		name = "ccr_idle_bot_textfield",
		text = tostring(settings.global["concreep-idle-bot-percentage"].value) .. "%",
		numeric = false
	}
	idle_bot_textfield.style.width = 60

	-- Minimum Item Count
	perf_table.add{type = "label", caption = {"mod-setting-name.concreep-minimum-item-count"}}
	local min_items_slider = perf_table.add{
		type = "slider",
		name = "ccr_min_items_slider",
		minimum_value = 0,
		maximum_value = 1000,
		value = settings.global["concreep-minimum-item-count"].value
	}
	min_items_slider.style.width = 200
	local min_items_textfield = perf_table.add{
		type = "textfield",
		name = "ccr_min_items_textfield",
		text = tostring(settings.global["concreep-minimum-item-count"].value),
		numeric = true
	}
	min_items_textfield.style.width = 60

	-- Range Section
	local range_frame = container.add{
		type = "frame",
		direction = "vertical",
		caption = {"ccr.section_range"}
	}
	range_frame.style.horizontally_stretchable = true
	range_frame.style.padding = 8
	range_frame.style.top_margin = 8

	local range_table = range_frame.add{
		type = "table",
		name = "ccr_range_table",
		column_count = 3
	}
	range_table.style.horizontally_stretchable = true
	range_table.style.column_alignments[1] = "left"
	range_table.style.column_alignments[2] = "right"
	range_table.style.column_alignments[3] = "left"

	-- Concreep Range
	range_table.add{type = "label", caption = {"mod-setting-name.concreep-range"}}
	local range_slider = range_table.add{
		type = "slider",
		name = "ccr_range_slider",
		minimum_value = 0,
		maximum_value = 100,
		value = settings.global["concreep-range"].value
	}
	range_slider.style.width = 200
	local range_textfield = range_table.add{
		type = "textfield",
		name = "ccr_range_textfield",
		text = tostring(settings.global["concreep-range"].value) .. "%",
		numeric = false
	}
	range_textfield.style.width = 60

	-- Circular Creep (checkbox row)
	range_table.add{type = "label", caption = {"mod-setting-name.concreep-circular-creep"}}
	local circular_checkbox = range_table.add{
		type = "checkbox",
		name = "ccr_circular_checkbox",
		state = settings.global["concreep-circular-creep"].value
	}
	range_table.add{type = "empty-widget"}

	-- Logistics Limit (checkbox row)
	range_table.add{type = "label", caption = {"mod-setting-name.concreep-logistics-limit"}}
	local logistics_checkbox = range_table.add{
		type = "checkbox",
		name = "ccr_logistics_checkbox",
		state = settings.global["concreep-logistics-limit"].value
	}
	range_table.add{type = "empty-widget"}

	-- Agricultural Tower Radius
	range_table.add{type = "label", caption = {"mod-setting-name.concreep-agricultural-tower-radius"}}
	local ag_tower_slider = range_table.add{
		type = "slider",
		name = "ccr_ag_tower_slider",
		minimum_value = 11,
		maximum_value = 30,
		value = settings.global["concreep-agricultural-tower-radius"].value
	}
	ag_tower_slider.style.width = 200
	local ag_tower_textfield = range_table.add{
		type = "textfield",
		name = "ccr_ag_tower_textfield",
		text = tostring(settings.global["concreep-agricultural-tower-radius"].value),
		numeric = true
	}
	ag_tower_textfield.style.width = 60

	-- Pump Radius
	range_table.add{type = "label", caption = {"mod-setting-name.concreep-pump-radius"}}
	local pump_slider = range_table.add{
		type = "slider",
		name = "ccr_pump_slider",
		minimum_value = 0,
		maximum_value = 10,
		value = settings.global["concreep-pump-radius"].value
	}
	pump_slider.style.width = 200
	local pump_textfield = range_table.add{
		type = "textfield",
		name = "ccr_pump_textfield",
		text = tostring(settings.global["concreep-pump-radius"].value),
		numeric = true
	}
	pump_textfield.style.width = 60

	-- Clearing Section
	local clearing_frame = container.add{
		type = "frame",
		direction = "vertical",
		caption = {"ccr.section_clearing"}
	}
	clearing_frame.style.horizontally_stretchable = true
	clearing_frame.style.padding = 8
	clearing_frame.style.top_margin = 8

	local clearing_table = clearing_frame.add{
		type = "table",
		name = "ccr_clearing_table",
		column_count = 2
	}
	clearing_table.style.horizontally_stretchable = true

	-- Clear Cliffs
	clearing_table.add{type = "label", caption = {"mod-setting-name.concreep-clear-cliffs"}}
	clearing_table.add{
		type = "checkbox",
		name = "ccr_clear_cliffs_checkbox",
		state = settings.global["concreep-clear-cliffs"].value
	}

	-- Clear Rocks
	clearing_table.add{type = "label", caption = {"mod-setting-name.concreep-clear-rocks"}}
	clearing_table.add{
		type = "checkbox",
		name = "ccr_clear_rocks_checkbox",
		state = settings.global["concreep-clear-rocks"].value
	}

	-- Clear Trees
	clearing_table.add{type = "label", caption = {"mod-setting-name.concreep-clear-trees"}}
	clearing_table.add{
		type = "checkbox",
		name = "ccr_clear_trees_checkbox",
		state = settings.global["concreep-clear-trees"].value
	}
end

-- Build Surfaces tab content
function build_surfaces_tab(container, player)
	local surfaces_frame = container.add{
		type = "frame",
		direction = "vertical",
		caption = {"ccr.section_surface_control"}
	}
	surfaces_frame.style.horizontally_stretchable = true
	surfaces_frame.style.padding = 8

	-- Surface selection dropdown
	local selector_flow = surfaces_frame.add{
		type = "flow",
		direction = "horizontal"
	}
	selector_flow.style.vertical_align = "center"
	selector_flow.style.horizontal_spacing = 8

	selector_flow.add{
		type = "label",
		caption = {"ccr.select_surface"}
	}

	-- Build list of all surfaces
	local surface_items = {}
	for _, surface in pairs(game.surfaces) do
		table.insert(surface_items, surface.name)
	end
	table.sort(surface_items)

	local surface_dropdown = selector_flow.add{
		type = "drop-down",
		name = "ccr_surface_dropdown",
		items = surface_items,
		selected_index = 1
	}
	surface_dropdown.style.width = 300

	-- Details frame for selected surface
	local details_frame = surfaces_frame.add{
		type = "frame",
		direction = "vertical",
		name = "ccr_surface_details"
	}
	details_frame.style.horizontally_stretchable = true
	details_frame.style.padding = 8
	details_frame.style.top_margin = 8

	-- Build initial surface details
	if #surface_items > 0 then
		build_surface_details(details_frame, surface_items[1], player)
	end
end

-- Build details for a specific surface
function build_surface_details(container, surface_name, player)
	container.clear()

	-- Surface info header
	local header_flow = container.add{
		type = "flow",
		direction = "horizontal"
	}
	header_flow.style.vertical_align = "center"
	header_flow.style.horizontal_spacing = 8

	header_flow.add{
		type = "label",
		caption = surface_name,
		style = "heading_2_label"
	}

	-- Check if this is a space platform surface
	local surface = game.surfaces[surface_name]
	if surface and surface.platform then
		header_flow.add{
			type = "label",
			caption = {"ccr.space_platform_label"},
			style = "bold_label"
		}
	end

	-- Separator
	container.add{
		type = "line",
		direction = "horizontal"
	}

	-- Surface statistics
	local stats_table = container.add{
		type = "table",
		column_count = 2
	}
	stats_table.style.horizontally_stretchable = true
	stats_table.style.top_margin = 8

	-- Count roboports on this surface
	local roboport_count = 0
	local active_count = 0
	local sleeping_count = 0
	if storage.creepers then
		for _, creeper in pairs(storage.creepers) do
			if creeper.surface == surface_name then
				roboport_count = roboport_count + 1
				if creeper.off then
					sleeping_count = sleeping_count + 1
				else
					active_count = active_count + 1
				end
			end
		end
	end

	stats_table.add{type = "label", caption = {"ccr.roboports_on_surface"}}
	stats_table.add{type = "label", caption = tostring(roboport_count)}

	stats_table.add{type = "label", caption = {"ccr.active_roboports"}}
	stats_table.add{type = "label", caption = tostring(active_count)}

	stats_table.add{type = "label", caption = {"ccr.sleeping_roboports"}}
	stats_table.add{type = "label", caption = tostring(sleeping_count)}

	-- Check if this surface is a space platform (don't show settings)
	if surface and surface.platform then
		container.add{type = "line", direction = "horizontal"}
		container.add{
			type = "label",
			caption = {"ccr.space_platform_disabled_explanation"}
		}
		return
	end

	-- Surface Enable/Disable (for Space Age planets only)
	if script.active_mods["space-age"] then
		local planet_settings = {
			["nauvis"] = "concreep-nauvis-enable",
			["gleba"] = "concreep-gleba-enable",
			["fulgora"] = "concreep-fulgora-enable",
			["vulcanus"] = "concreep-vulcanus-enable",
			["aquilo"] = "concreep-aquilo-enable"
		}

		if planet_settings[surface_name] then
			container.add{type = "line", direction = "horizontal"}
			local enable_flow = container.add{
				type = "flow",
				direction = "horizontal"
			}
			enable_flow.style.vertical_align = "center"
			enable_flow.style.top_margin = 8

			enable_flow.add{
				type = "checkbox",
				name = "ccr_surface_enable_checkbox",
				state = settings.global[planet_settings[surface_name]].value,
				tags = {surface_name = surface_name, setting_name = planet_settings[surface_name]}
			}

			enable_flow.add{
				type = "label",
				caption = {"ccr.enable_concreep_on_surface"}
			}
		end
	end

	-- Per-Surface Settings Overrides Section
	container.add{type = "line", direction = "horizontal"}

	local settings_header = container.add{
		type = "flow",
		direction = "horizontal"
	}
	settings_header.style.vertical_align = "center"
	settings_header.style.top_margin = 8

	settings_header.add{
		type = "label",
		caption = {"ccr.surface_overrides_header"},
		style = "bold_label"
	}

	local help_label = settings_header.add{
		type = "label",
		caption = {"ccr.surface_overrides_help"}
	}
	help_label.style.left_margin = 8
	help_label.style.font_color = {r=0.6, g=0.6, b=0.6}

	-- Build per-surface settings
	build_surface_settings_overrides(container, surface_name, player)
end

-- Build per-surface settings override controls
function build_surface_settings_overrides(container, surface_name, player)
	-- Range & Coverage Settings
	local range_frame = container.add{
		type = "frame",
		direction = "vertical",
		caption = {"ccr.section_range"}
	}
	range_frame.style.horizontally_stretchable = true
	range_frame.style.padding = 8
	range_frame.style.top_margin = 8

	-- We'll use a 4-column table: [Override Checkbox] [Label] [Control] [Value Display / Reset]
	local range_table = range_frame.add{
		type = "table",
		name = "ccr_surface_range_table",
		column_count = 4
	}
	range_table.style.horizontally_stretchable = true

	-- Helper to add a setting row
	local function add_setting_row(setting_name, label_key, min_val, max_val, suffix)
		suffix = suffix or ""
		local has_override = has_surface_override(surface_name, setting_name)
		local current_value = get_surface_setting(surface_name, setting_name)
		local global_value = settings.global[setting_name].value

		-- Override checkbox
		range_table.add{
			type = "checkbox",
			name = "ccr_surf_override_" .. setting_name,
			state = has_override and true or false,
			tooltip = {"ccr.override_tooltip"},
			tags = {surface_name = surface_name, setting_name = setting_name, action = "toggle_override"}
		}

		-- Label
		range_table.add{type = "label", caption = {label_key}}

		-- Slider
		local slider = range_table.add{
			type = "slider",
			name = "ccr_surf_slider_" .. setting_name,
			minimum_value = min_val,
			maximum_value = max_val,
			value = current_value,
			enabled = has_override and true or false,
			tags = {surface_name = surface_name, setting_name = setting_name}
		}
		slider.style.width = 200

		-- Value display
		local value_caption
		if not has_override then
			value_caption = {"", tostring(current_value) .. suffix, " ", {"ccr.global_default"}}
		else
			value_caption = tostring(current_value) .. suffix
		end
		local value_label = range_table.add{
			type = "label",
			name = "ccr_surf_value_" .. setting_name,
			caption = value_caption
		}
		value_label.style.width = 120
	end

	-- Concreep Range
	add_setting_row("concreep-range", "mod-setting-name.concreep-range", 0, 100, "%")

	-- Agricultural Tower Radius
	add_setting_row("concreep-agricultural-tower-radius", "mod-setting-name.concreep-agricultural-tower-radius", 11, 30, "")

	-- Pump Radius
	add_setting_row("concreep-pump-radius", "mod-setting-name.concreep-pump-radius", 0, 10, "")

	-- Helper to add checkbox setting row
	local function add_checkbox_row(setting_name, label_key)
		local has_override = has_surface_override(surface_name, setting_name)
		local current_value = get_surface_setting(surface_name, setting_name)

		-- Override checkbox
		range_table.add{
			type = "checkbox",
			name = "ccr_surf_override_" .. setting_name,
			state = has_override and true or false,
			tooltip = {"ccr.override_tooltip"},
			tags = {surface_name = surface_name, setting_name = setting_name, action = "toggle_override"}
		}

		-- Label
		range_table.add{type = "label", caption = {label_key}}

		-- Setting checkbox
		range_table.add{
			type = "checkbox",
			name = "ccr_surf_checkbox_" .. setting_name,
			state = current_value and true or false,
			enabled = has_override and true or false,
			tags = {surface_name = surface_name, setting_name = setting_name}
		}

		-- Status label
		local status_caption
		if not has_override then
			if current_value then
				status_caption = {"", {"ccr.enabled"}, " ", {"ccr.global_default"}}
			else
				status_caption = {"", {"ccr.disabled"}, " ", {"ccr.global_default"}}
			end
		else
			status_caption = current_value and {"ccr.enabled"} or {"ccr.disabled"}
		end
		range_table.add{
			type = "label",
			name = "ccr_surf_value_" .. setting_name,
			caption = status_caption
		}
	end

	-- Circular Creep
	add_checkbox_row("concreep-circular-creep", "mod-setting-name.concreep-circular-creep")

	-- Logistics Limit
	add_checkbox_row("concreep-logistics-limit", "mod-setting-name.concreep-logistics-limit")

	-- Tile Types & Clearing Section
	local tile_frame = container.add{
		type = "frame",
		direction = "vertical",
		caption = {"ccr.section_tile_types"}
	}
	tile_frame.style.horizontally_stretchable = true
	tile_frame.style.padding = 8
	tile_frame.style.top_margin = 8

	local tile_table = tile_frame.add{
		type = "table",
		name = "ccr_surface_tile_table",
		column_count = 4
	}
	tile_table.style.horizontally_stretchable = true

	-- Helper to add checkbox setting row to tile table
	local function add_tile_checkbox_row(setting_name, label_key)
		local has_override = has_surface_override(surface_name, setting_name)
		local current_value = get_surface_setting(surface_name, setting_name)

		-- Override checkbox
		tile_table.add{
			type = "checkbox",
			name = "ccr_surf_override_" .. setting_name,
			state = has_override and true or false,
			tooltip = {"ccr.override_tooltip"},
			tags = {surface_name = surface_name, setting_name = setting_name, action = "toggle_override"}
		}

		-- Label
		tile_table.add{type = "label", caption = {label_key}}

		-- Setting checkbox
		tile_table.add{
			type = "checkbox",
			name = "ccr_surf_checkbox_" .. setting_name,
			state = current_value and true or false,
			enabled = has_override and true or false,
			tags = {surface_name = surface_name, setting_name = setting_name}
		}

		-- Status label
		local status_caption
		if not has_override then
			if current_value then
				status_caption = {"", {"ccr.enabled"}, " ", {"ccr.global_default"}}
			else
				status_caption = {"", {"ccr.disabled"}, " ", {"ccr.global_default"}}
			end
		else
			status_caption = current_value and {"ccr.enabled"} or {"ccr.disabled"}
		end
		tile_table.add{
			type = "label",
			name = "ccr_surf_value_" .. setting_name,
			caption = status_caption
		}
	end

	-- Brick
	add_tile_checkbox_row("creep-brick", "mod-setting-name.creep-brick")

	-- Upgrade Brick
	add_tile_checkbox_row("upgrade-brick", "mod-setting-name.upgrade-brick")

	-- Upgrade Concrete
	add_tile_checkbox_row("upgrade-concrete", "mod-setting-name.upgrade-concrete")

	-- Landfill
	add_tile_checkbox_row("creep-landfill", "mod-setting-name.creep-landfill")

	-- Foundation (if Space Age)
	if script.active_mods["space-age"] then
		add_tile_checkbox_row("creep-foundation", "mod-setting-name.creep-foundation")

		-- Ice Platform
		add_tile_checkbox_row("creep-ice-platform", "mod-setting-name.creep-ice-platform")

		-- Replace Artificial Soils
		add_tile_checkbox_row("concreep-replace-artificial-soils", "mod-setting-name.concreep-replace-artificial-soils")

		-- Replace Overgrowth Soils
		add_tile_checkbox_row("concreep-replace-overgrowth-soils", "mod-setting-name.concreep-replace-overgrowth-soils")
	end

	-- Clearing Section
	local clearing_frame = container.add{
		type = "frame",
		direction = "vertical",
		caption = {"ccr.section_clearing"}
	}
	clearing_frame.style.horizontally_stretchable = true
	clearing_frame.style.padding = 8
	clearing_frame.style.top_margin = 8

	local clearing_table = clearing_frame.add{
		type = "table",
		name = "ccr_surface_clearing_table",
		column_count = 4
	}
	clearing_table.style.horizontally_stretchable = true

	-- Helper to add checkbox setting row to clearing table
	local function add_clearing_checkbox_row(setting_name, label_key)
		local has_override = has_surface_override(surface_name, setting_name)
		local current_value = get_surface_setting(surface_name, setting_name)

		-- Override checkbox
		clearing_table.add{
			type = "checkbox",
			name = "ccr_surf_override_" .. setting_name,
			state = has_override and true or false,
			tooltip = {"ccr.override_tooltip"},
			tags = {surface_name = surface_name, setting_name = setting_name, action = "toggle_override"}
		}

		-- Label
		clearing_table.add{type = "label", caption = {label_key}}

		-- Setting checkbox
		clearing_table.add{
			type = "checkbox",
			name = "ccr_surf_checkbox_" .. setting_name,
			state = current_value and true or false,
			enabled = has_override and true or false,
			tags = {surface_name = surface_name, setting_name = setting_name}
		}

		-- Status label
		local status_caption
		if not has_override then
			if current_value then
				status_caption = {"", {"ccr.enabled"}, " ", {"ccr.global_default"}}
			else
				status_caption = {"", {"ccr.disabled"}, " ", {"ccr.global_default"}}
			end
		else
			status_caption = current_value and {"ccr.enabled"} or {"ccr.disabled"}
		end
		clearing_table.add{
			type = "label",
			name = "ccr_surf_value_" .. setting_name,
			caption = status_caption
		}
	end

	-- Clear Cliffs
	add_clearing_checkbox_row("concreep-clear-cliffs", "mod-setting-name.concreep-clear-cliffs")

	-- Clear Rocks
	add_clearing_checkbox_row("concreep-clear-rocks", "mod-setting-name.concreep-clear-rocks")

	-- Clear Trees
	add_clearing_checkbox_row("concreep-clear-trees", "mod-setting-name.concreep-clear-trees")
end

-- Build Tile Placement tab content
function build_tile_placement_tab(container, player)
	-- Tile Mode Section
	local mode_frame = container.add{
		type = "frame",
		direction = "vertical",
		caption = {"ccr.section_tile_mode"}
	}
	mode_frame.style.horizontally_stretchable = true
	mode_frame.style.padding = 8

	-- TODO: Add tile mode, pattern settings, coverage type settings

	-- Tile Types Section
	local types_frame = container.add{
		type = "frame",
		direction = "vertical",
		caption = {"ccr.section_tile_types"}
	}
	types_frame.style.horizontally_stretchable = true
	types_frame.style.padding = 8
	types_frame.style.top_margin = 8

	-- TODO: Add landfill, foundation, ice-platform, brick enable/disable
	-- TODO: Add upgrade settings
end

-- Build System Status tab content
function build_system_status_tab(container, player)
	local status_frame = container.add{
		type = "frame",
		direction = "vertical",
		caption = {"ccr.section_system_overview"}
	}
	status_frame.style.horizontally_stretchable = true
	status_frame.style.padding = 8

	-- TODO: Add roboport statistics, active/sleeping counts, per-surface breakdown
end

-- Handle GUI click events
script.on_event(defines.events.on_gui_click, function (event)
	if not event.element or not event.element.valid then return end

	local player = game.get_player(event.player_index)
	if not player then return end

	-- Close button
	if event.element.name == "ccr_close_button" then
		toggle_interface(player)
	end

	-- TODO: Add handlers for other buttons (apply, refresh, wake all, etc.)
end)

-- Handle GUI value changes (sliders)
script.on_event(defines.events.on_gui_value_changed, function(event)
	if not event.element or not event.element.valid then return end

	local player = game.get_player(event.player_index)
	if not player then return end

	-- Update Count
	if event.element.name == "ccr_update_count_slider" then
		local value = math.floor(event.element.slider_value)
		settings.global["concreep-update-count"] = {value = value}
		local textfield = event.element.parent["ccr_update_count_textfield"]
		if textfield then
			textfield.text = tostring(value)
		end

	-- Idle Bot Percentage
	elseif event.element.name == "ccr_idle_bot_slider" then
		local value = math.floor(event.element.slider_value)
		settings.global["concreep-idle-bot-percentage"] = {value = value}
		local textfield = event.element.parent["ccr_idle_bot_textfield"]
		if textfield then
			textfield.text = tostring(value) .. "%"
		end

	-- Minimum Item Count
	elseif event.element.name == "ccr_min_items_slider" then
		local value = math.floor(event.element.slider_value)
		settings.global["concreep-minimum-item-count"] = {value = value}
		local textfield = event.element.parent["ccr_min_items_textfield"]
		if textfield then
			textfield.text = tostring(value)
		end

	-- Concreep Range
	elseif event.element.name == "ccr_range_slider" then
		local value = math.floor(event.element.slider_value)
		settings.global["concreep-range"] = {value = value}
		local textfield = event.element.parent["ccr_range_textfield"]
		if textfield then
			textfield.text = tostring(value) .. "%"
		end
		update_surface_tab_for_global_change(player, "concreep-range")

	-- Agricultural Tower Radius
	elseif event.element.name == "ccr_ag_tower_slider" then
		local value = math.floor(event.element.slider_value)
		settings.global["concreep-agricultural-tower-radius"] = {value = value}
		local textfield = event.element.parent["ccr_ag_tower_textfield"]
		if textfield then
			textfield.text = tostring(value)
		end
		update_surface_tab_for_global_change(player, "concreep-agricultural-tower-radius")

	-- Pump Radius
	elseif event.element.name == "ccr_pump_slider" then
		local value = math.floor(event.element.slider_value)
		settings.global["concreep-pump-radius"] = {value = value}
		local textfield = event.element.parent["ccr_pump_textfield"]
		if textfield then
			textfield.text = tostring(value)
		end
		update_surface_tab_for_global_change(player, "concreep-pump-radius")

	-- Surface Override Sliders
	elseif event.element.name and event.element.name:match("^ccr_surf_slider_") and event.element.tags then
		local surface_name = event.element.tags.surface_name
		local setting_name = event.element.tags.setting_name
		local value = math.floor(event.element.slider_value)

		-- Update the per-surface override
		set_surface_setting(surface_name, setting_name, value)

		-- Update the value label
		local value_label = event.element.parent["ccr_surf_value_" .. setting_name]
		if value_label then
			local suffix = ""
			if setting_name == "concreep-range" then
				suffix = "%"
			end
			value_label.caption = tostring(value) .. suffix
		end
	end
end)

-- Handle GUI checked state changes (checkboxes)
script.on_event(defines.events.on_gui_checked_state_changed, function(event)
	if not event.element or not event.element.valid then return end

	local player = game.get_player(event.player_index)
	if not player then return end

	-- Circular Creep
	if event.element.name == "ccr_circular_checkbox" then
		settings.global["concreep-circular-creep"] = {value = event.element.state}
		update_surface_tab_for_global_change(player, "concreep-circular-creep")

	-- Logistics Limit
	elseif event.element.name == "ccr_logistics_checkbox" then
		settings.global["concreep-logistics-limit"] = {value = event.element.state}
		update_surface_tab_for_global_change(player, "concreep-logistics-limit")

	-- Clear Cliffs
	elseif event.element.name == "ccr_clear_cliffs_checkbox" then
		settings.global["concreep-clear-cliffs"] = {value = event.element.state}
		update_surface_tab_for_global_change(player, "concreep-clear-cliffs")

	-- Clear Rocks
	elseif event.element.name == "ccr_clear_rocks_checkbox" then
		settings.global["concreep-clear-rocks"] = {value = event.element.state}
		update_surface_tab_for_global_change(player, "concreep-clear-rocks")

	-- Clear Trees
	elseif event.element.name == "ccr_clear_trees_checkbox" then
		settings.global["concreep-clear-trees"] = {value = event.element.state}
		update_surface_tab_for_global_change(player, "concreep-clear-trees")

	-- Surface Enable/Disable
	elseif event.element.name == "ccr_surface_enable_checkbox" then
		if event.element.tags and event.element.tags.setting_name then
			settings.global[event.element.tags.setting_name] = {value = event.element.state}
		end

	-- Surface Override Toggle
	elseif event.element.name and event.element.name:match("^ccr_surf_override_") and event.element.tags then
		local surface_name = event.element.tags.surface_name
		local setting_name = event.element.tags.setting_name

		if event.element.state then
			-- Enable override - set to current global value
			set_surface_setting(surface_name, setting_name, settings.global[setting_name].value)
		else
			-- Disable override - clear it
			clear_surface_setting(surface_name, setting_name)
		end

		-- Rebuild the surface details to update UI
		local player = game.get_player(event.player_index)
		if player then
			local main_frame = player.gui.screen.ccr_config_window
			if main_frame then
				local tabbed_pane = main_frame.ccr_tabbed_pane
				if tabbed_pane then
					local surfaces_content = tabbed_pane.ccr_surfaces_content
					if surfaces_content then
						local details_frame = surfaces_content.children[1].ccr_surface_details
						if details_frame then
							build_surface_details(details_frame, surface_name, player)
						end
					end
				end
			end
		end

	-- Surface Setting Checkboxes
	elseif event.element.name and event.element.name:match("^ccr_surf_checkbox_") and event.element.tags then
		local surface_name = event.element.tags.surface_name
		local setting_name = event.element.tags.setting_name

		-- Update the per-surface override
		set_surface_setting(surface_name, setting_name, event.element.state)

		-- Update the value label
		local value_label = event.element.parent["ccr_surf_value_" .. setting_name]
		if value_label then
			local status_text = event.element.state and {"ccr.enabled"} or {"ccr.disabled"}
			value_label.caption = status_text
		end
	end
end)

-- Handle dropdown selection changes
script.on_event(defines.events.on_gui_selection_state_changed, function(event)
	if not event.element or not event.element.valid then return end

	local player = game.get_player(event.player_index)
	if not player then return end

	-- Surface dropdown
	if event.element.name == "ccr_surface_dropdown" then
		local selected_surface = event.element.items[event.element.selected_index]
		if selected_surface then
			-- Find the details frame and rebuild it
			local main_frame = player.gui.screen.ccr_config_window
			if main_frame then
				local tabbed_pane = main_frame.ccr_tabbed_pane
				if tabbed_pane then
					local surfaces_content = tabbed_pane.ccr_surfaces_content
					if surfaces_content then
						local details_frame = surfaces_content.children[1].ccr_surface_details
						if details_frame then
							build_surface_details(details_frame, selected_surface, player)
						end
					end
				end
			end
		end
	end
end)

-- Handle GUI closed event
script.on_event(defines.events.on_gui_closed, function(event)
	if event.element and event.element.name == "ccr_config_window" then
		local player = game.get_player(event.player_index)
		if player then
			toggle_interface(player)
		end
	end
end)

-- Handle keyboard shortcut to toggle interface
script.on_event("concreep_toggle_interface", function(event)
	local player = game.get_player(event.player_index)
	if player then
		toggle_interface(player)
	end
end)