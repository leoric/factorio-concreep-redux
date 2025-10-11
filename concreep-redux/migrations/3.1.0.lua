-- Migration for 3.1.0: Convert old tile mode settings to new unified setting

for _, force in pairs(game.forces) do
    local old_pattern_mode = settings.global["concreep-use-pattern-mode"]
    local old_coverage_mode = settings.global["concreep-tiles-per-area"]

    -- Determine which mode was active
    if old_coverage_mode and old_coverage_mode.value then
        settings.global["concreep-tile-mode"] = {value = "coverage-type"}
    elseif old_pattern_mode and old_pattern_mode.value then
        settings.global["concreep-tile-mode"] = {value = "pattern"}
    else
        settings.global["concreep-tile-mode"] = {value = "standard"}
    end
end

game.print("Concreep Redux: Migrated tile mode settings to version 3.1.0")
