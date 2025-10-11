if script.active_mods["gvv"] then
	require("__gvv__.gvv")()
end

require('logic.creep_logic')
require('gui.config_window')

function init()
	gui_init()
	creep_init()
	storage.pattern_renders = storage.pattern_renders or {}
end

script.on_init(init)
script.on_configuration_changed(function()
	init()
end)

-- Show pattern capture area when holding a roboport
script.on_event(defines.events.on_player_cursor_stack_changed, function(event)
	local player = game.get_player(event.player_index)
	if not player then return end

	-- Initialize if needed
	if not storage.pattern_renders then
		storage.pattern_renders = {}
	end

	-- Clear any existing renders for this player
	if storage.pattern_renders[event.player_index] then
		for _, render_id in pairs(storage.pattern_renders[event.player_index]) do
			rendering.destroy(render_id)
		end
		storage.pattern_renders[event.player_index] = nil
	end

	-- Check if player is holding a roboport
	local cursor_stack = player.cursor_stack
	if cursor_stack and cursor_stack.valid_for_read then
		local entity_prototype = cursor_stack.prototype.place_result
		if entity_prototype and entity_prototype.type == "roboport" then
			-- Pattern mode must be enabled
			if settings.global["concreep-tile-mode"].value == "pattern" then
				storage.pattern_renders[event.player_index] = {}
			end
		end
	end
end)

-- Show pattern visualization when selecting a roboport
script.on_event(defines.events.on_selected_entity_changed, function(event)
	local player = game.get_player(event.player_index)
	if not player then return end

	-- Initialize if needed
	if not storage.pattern_renders then
		storage.pattern_renders = {}
	end

	-- Clear previous renders for this player
	if storage.pattern_renders[event.player_index] then
		for _, render_id in pairs(storage.pattern_renders[event.player_index]) do
			if render_id and render_id.valid then
				render_id.destroy()
			end
		end
		storage.pattern_renders[event.player_index] = nil
	end

	-- Check if pattern preview is enabled for this player
	local player_settings = settings.get_player_settings(player)["concreep-show-pattern-preview"]
	if not player_settings or not player_settings.value then
		return
	end

	-- Check if pattern mode is enabled
	if settings.global["concreep-tile-mode"].value ~= "pattern" then
		return
	end

	-- Check if selected entity is a roboport
	local selected = player.selected
	if not selected or not selected.valid or selected.type ~= "roboport" then
		return
	end

	local pattern_size = settings.global["concreep-pattern-size"].value
	local half_size = pattern_size / 2
	local pos = selected.position

	-- Calculate pattern bounds to align with tile grid
	-- For the pattern capture, we use floor(pos + offset) to get tile positions
	local left = math.floor(pos.x - half_size)
	local top = math.floor(pos.y - half_size)
	local right = math.floor(pos.x + half_size)
	local bottom = math.floor(pos.y + half_size)

	-- Draw a rectangle showing the pattern capture area (aligned to tile grid)
	local render_id = rendering.draw_rectangle{
		color = {r = 0, g = 1, b = 1, a = 0.5},
		width = 3,
		filled = false,
		left_top = {left, top},
		right_bottom = {right, bottom},
		surface = player.surface,
		players = {player},
		time_to_live = 0  -- Persist until entity is deselected
	}

	storage.pattern_renders[event.player_index] = {render_id}
end)