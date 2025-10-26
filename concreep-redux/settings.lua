data:extend({
    {
        type = "int-setting",
        name = "concreep-update-frequency",
        setting_type = "startup",
        default_value = 10,
        minimum_value = 1,
        order = "001"
    },
    {
        type = "int-setting",
        name = "concreep-update-count",
        setting_type = "runtime-global",
        default_value = 10,
        minimum_value = 1,
        order = "002"
    },
    {
        type = "int-setting",
        name = "concreep-range",
        setting_type = "runtime-global",
        default_value = 100,
        minimum_value = 0,
        maximum_value = 100,
        order = "010"
    },
    {
        type = "bool-setting",
        name = "concreep-circular-creep",
        setting_type = "runtime-global",
        default_value = false,
        order = "015"
    },
    {
        type = "bool-setting",
        name = "concreep-logistics-limit",
        setting_type = "runtime-global",
        default_value = false,
        order = "020"
    },
    {
        type = "int-setting",
        name = "concreep-idle-bot-percentage",
        setting_type = "runtime-global",
        default_value = 50,
        minimum_value = 0,
        maximum_value = 100,
        order = "030"
    },
    {
        type = "int-setting",
        name = "concreep-minimum-item-count",
        setting_type = "runtime-global",
        default_value = 100,
        minimum_value = 0,
        order = "033"
    },
    {
        type = "bool-setting",
        name = "creep-landfill",
        setting_type = "runtime-global",
        default_value = false,
        order = "035"
    },
    {
        type = "int-setting",
        name = "concreep-pump-radius",
        setting_type = "runtime-global",
        default_value = 3,
        minimum_value = 0,
        order = "037"
    },
    {
        type = "bool-setting",
        name = "creep-foundation",
        setting_type = "runtime-global",
        default_value = false,
        order = "037a"
    },
    {
        type = "bool-setting",
        name = "creep-ice-platform",
        setting_type = "runtime-global",
        default_value = false,
        order = "037b"
    },
    {
        type = "bool-setting",
        name = "creep-space-scaffold",
        setting_type = "runtime-global",
        default_value = true,
        order = "037c"
    },
    {
        type = "int-setting",
        name = "concreep-agricultural-tower-radius",
        setting_type = "runtime-global",
        default_value = 11,
        minimum_value = 11,
        order = "038"
    },
    {
        type = "string-setting",
        name = "concreep-tile-mode",
        setting_type = "runtime-global",
        default_value = "standard",
        allowed_values = {"standard", "pattern", "coverage-type"},
        order = "039"
    },
    {
        type = "bool-setting",
        name = "concreep-use-pattern-mode",
        setting_type = "runtime-global",
        default_value = false,
        hidden = true,
        order = "039a"
    },
    {
        type = "int-setting",
        name = "concreep-pattern-size",
        setting_type = "runtime-global",
        default_value = 4,
        minimum_value = 3,
        maximum_value = 16,
        order = "040"
    },
    {
        type = "bool-setting",
        name = "concreep-show-pattern-preview",
        setting_type = "runtime-per-user",
        default_value = true,
        order = "041"
    },
    {
        type = "bool-setting",
        name = "creep-brick",
        setting_type = "runtime-global",
        default_value = true,
        order = "040"
    },
    {
        type = "bool-setting",
        name = "upgrade-brick",
        setting_type = "runtime-global",
        default_value = true,
        order = "050"
    },
    {
        type = "bool-setting",
        name = "upgrade-concrete",
        setting_type = "runtime-global",
        default_value = true,
        order = "060"
    },
    {
        type = "bool-setting",
        name = "upgrade-space-scaffold",
        setting_type = "runtime-global",
        default_value = true,
        order = "070"
    },
    {
        type = "bool-setting",
        name = "concreep-tiles-per-area",
        setting_type = "runtime-global",
        default_value = false,
        hidden = true,
        order = "080"
    },
    {
        type = "string-setting",
        name = "concreep-logistic-area-tile",
        setting_type = "runtime-global",
        default_value = "refined-concrete",
        auto_trim = true,
        allowed_values = {"stone-brick", "concrete", "refined-concrete"},
        order = "090"
    },
    {
        type = "string-setting",
        name = "concreep-construction-area-tile",
        setting_type = "runtime-global",
        default_value = "concrete",
        auto_trim = true,
        allowed_values = {"stone-brick", "concrete", "refined-concrete"},
        order = "100"
    },
    {
        type = "bool-setting",
        name = "concreep-clear-cliffs",
        setting_type = "runtime-global",
        default_value = true,
        order = "110"
    },
    {
        type = "bool-setting",
        name = "concreep-clear-rocks",
        setting_type = "runtime-global",
        default_value = true,
        order = "120"
    },
    {
        type = "bool-setting",
        name = "concreep-clear-trees",
        setting_type = "runtime-global",
        default_value = true,
        order = "130"
    },

    -- Space Age related Settings
    {
        type = "bool-setting",
        name = "concreep-nauvis-enable",
        setting_type = "runtime-global",
        default_value = true,
        order = "140"
    },
    {
        type = "bool-setting",
        name = "concreep-gleba-enable",
        setting_type = "runtime-global",
        default_value = true,
        order = "141"
    },
    {
        type = "bool-setting",
        name = "concreep-fulgora-enable",
        setting_type = "runtime-global",
        default_value = true,
        order = "142"
    },
    {
        type = "bool-setting",
        name = "concreep-vulcanus-enable",
        setting_type = "runtime-global",
        default_value = true,
        order = "143"
    },
    {
        type = "bool-setting",
        name = "concreep-aquilo-enable",
        setting_type = "runtime-global",
        default_value = true,
        order = "144"
    },
    {
        type = "bool-setting",
        name = "concreep-replace-artificial-soils",
        setting_type = "runtime-global",
        default_value = true,
        order = "145"
    },
    {
        type = "bool-setting",
        name = "concreep-replace-overgrowth-soils",
        setting_type = "runtime-global",
        default_value = true,
        order = "146"
    }
})