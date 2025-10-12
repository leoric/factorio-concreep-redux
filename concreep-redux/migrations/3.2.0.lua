-- Migration for Concreep Redux 3.2.0
-- Rebuilds the roboport list to fix saves affected by the bug where sleeping roboports were deleted

log("Concreep Redux: Running 3.2.0 migration")

if not storage.creepers then
	log("Concreep Redux: No creeper data found, skipping migration")
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
		if port and port.valid and port.logistic_cell and port.logistic_cell.construction_radius > 0 then
			-- Check if this roboport is already in the list (shouldn't be, but just in case)
			local found = false
			for _, creeper in pairs(storage.creepers) do
				if creeper.roboport == port then
					found = true
					break
				end
			end

			if not found then
				-- Add roboport with pattern capture
				local surface_obj = port.surface
				local pattern_size = settings.global["concreep-pattern-size"].value
				local half_size = pattern_size / 2
				local pos = port.position
				local left = math.floor(pos.x - half_size)
				local top = math.floor(pos.y - half_size)
				local right = math.floor(pos.x + half_size)
				local bottom = math.floor(pos.y + half_size)

				local pattern = {}
				local it = {}

				local idx = 1
				for xx = left, right - 1, 1 do
					pattern[idx] = {}
					it[idx] = {}
					local idy = 1
					for yy = top, bottom - 1, 1 do
						local tile = surface_obj.get_tile(xx, yy)
						if tile.hidden_tile and tile.prototype.items_to_place_this then
							it[idx][idy] = tile.prototype.items_to_place_this[1] and prototypes.item[tile.prototype.items_to_place_this[1].name] and tile.prototype.items_to_place_this[1].name
							pattern[idx][idy] = tile.name
						end
						idy = idy + 1
					end
					idx = idx + 1
				end

				table.insert(storage.creepers, {
					roboport = port,
					surface = surface_obj.name,
					radius = 3,
					pattern = pattern,
					item = it,
					pattern_size = pattern_size,
					pattern_offset = {left, top},
					off = false,
					removal_counter = 0
				})

				added = added + 1
			end
		end
	end
end

-- Recount active creepers
storage.active_creepers = 0
for i = #storage.creepers, 1, -1 do
	if storage.creepers[i].off == false then
		storage.active_creepers = storage.active_creepers + 1
	end
end

log(string.format(
	"Concreep Redux: Migration complete - %d old roboports, %d new roboports found, %d total (%d active)",
	old_count, added, #storage.creepers, storage.active_creepers
))

game.print(string.format(
	"[Concreep Redux] Migrated to v3.2.0: Rebuilt roboport list (%d -> %d roboports, %d active)",
	old_count, #storage.creepers, storage.active_creepers
))
