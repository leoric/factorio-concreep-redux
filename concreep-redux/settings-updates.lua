if not mods["space-exploration"] then
    data.raw["bool-setting"]["upgrade-space-scaffold"].hidden = true
end

if not mods["space-age"] then
    data.raw["bool-setting"]["concreep-nauvis-enable"].hidden = true
    data.raw["bool-setting"]["concreep-gleba-enable"].hidden = true
    data.raw["bool-setting"]["concreep-fulgora-enable"].hidden = true
    data.raw["bool-setting"]["concreep-vulcanus-enable"].hidden = true
    data.raw["bool-setting"]["concreep-aquilo-enable"].hidden = true
    data.raw["bool-setting"]["creep-foundation"].hidden = true
    data.raw["bool-setting"]["creep-ice-platform"].hidden = true
end

data.raw["bool-setting"]["concreep-replace-artificial-soils"].hidden = true
data.raw["bool-setting"]["concreep-replace-overgrowth-soils"].hidden = true