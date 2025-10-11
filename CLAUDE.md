# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Concreep Redux is a Factorio mod that automates concrete placement and upgrades within roboport construction areas. The mod monitors roboports and progressively places tiles (stone-brick, concrete, refined-concrete) outward from each roboport using construction robots from the logistics network.

## Development Environment

This is a Factorio 2.0 mod with no external build system. Development involves editing Lua files directly.

### Mod Structure
```
concreep-redux/
├── info.json           # Mod metadata (version, dependencies, title)
├── control.lua         # Runtime event handlers and main entry point
├── data.lua            # Prototype stage (custom inputs, commented styles)
├── settings.lua        # Mod settings definitions
├── settings-updates.lua # Conditional settings visibility
├── logic/
│   └── creep_logic.lua # Core tile placement logic
└── gui/
    └── config_window.lua # GUI code (currently commented out/disabled)
```

### Module Architecture

**control.lua** is the entry point that:
- Loads `gvv` debug mod if present
- Requires `logic/creep_logic` and `gui/config_window` modules
- Calls `creep_init()` and `gui_init()` on `script.on_init`

**logic/creep_logic.lua** contains all core functionality:
- `storage.creepers` - Array of tracked roboport "creeper" objects
- `storage.active_creepers` - Count of active (non-sleeping) creepers
- Each creeper object tracks: roboport entity, surface, radius, pattern, upgrade mode, off state
- Main tick handler: `check_roboports()` runs every N ticks (configurable via startup setting)
- Three tile placement modes: `standard_creep()`, `area_tile_creep()`, `space_creep()`

**Creep Logic Flow:**
1. Every N ticks, process up to M roboports (configurable)
2. For each roboport, check if it's powered and has enough idle construction bots
3. Find tiles within current radius that need placement/upgrade
4. Create tile-ghosts for construction bots to build
5. Order deconstruction of trees/rocks/cliffs if enabled
6. When radius is fully tiled, increment radius or put creeper to sleep
7. Sleep mode triggers when reaching target radius with no work remaining

**Three Creep Modes:**
- **standard_creep**: Places concrete in expanding circles/squares; supports custom patterns, upgrades brick→concrete→refined-concrete
- **area_tile_creep**: Uses different tiles for logistic vs construction areas
- **space_creep**: For Space Exploration mod - places space platform scaffold/plating

### Key Concepts

**Creeper State Machine:**
- Active: Placing tiles, expanding radius
- Upgrade mode: All virgin tiles placed, now upgrading existing tiles
- Sleeping (off=true): Reached full radius and no work remains, removed from active count

**Bot Management:**
- Respects `concreep-idle-bot-percentage` setting to avoid using all bots
- Distributes work across multiple roboports using `active_port_factor`
- Sets `force.max_successful_attempts_per_tick_per_construction_queue` dynamically

**Surface Filtering:**
- Space Age surfaces (Nauvis, Gleba, Fulgora, Vulcanus, Aquilo) can be individually enabled/disabled
- Space Exploration orbital surfaces use `space_creep()` mode

**Radius Calculation:**
- Square mode: Uses roboport's construction/logistic radius directly
- Circular mode (`concreep-circular-creep`): Multiplies by √2 and uses radius filter instead of area filter

### Important Settings

**Startup (requires restart):**
- `concreep-update-frequency` - How often (in seconds) to check roboports

**Runtime-global:**
- `concreep-update-count` - How many roboports to process per tick
- `concreep-range` - Percentage (0-100) of roboport radius to tile
- `concreep-circular-creep` - Use circular area instead of square
- `concreep-logistics-limit` - Limit to logistic radius instead of construction radius
- `concreep-idle-bot-percentage` - Minimum percentage of idle bots required
- `concreep-minimum-item-count` - Reserve this many tiles in logistics network
- Bot usage, item counts, tile types, clearing options, per-planet toggles

## Key Functions

**creep_logic.lua:**
- `check_roboports()` - Main tick handler
- `get_creeper()` - Gets next roboport to process, handles validation/removal
- `creep(creeper)` - Orchestrates tile placement for one roboport
- `standard_creep()`, `area_tile_creep()`, `space_creep()` - Three placement modes
- `build_tile(roboport, type, position)` - Creates tile ghost + orders obstacle deconstruction
- `validate(entity)` - Checks if entity is a valid roboport with construction area
- `addPort(roboport)` - Registers new roboport as creeper
- `get_adjusted_radius()` - Converts square to circular radius if needed

## Testing

No automated test suite. Testing is done manually in Factorio:
1. Copy `concreep-redux/` folder to Factorio mods directory
2. Launch Factorio, enable the mod
3. Start/load a game with roboports and construction robots
4. Observe tile placement behavior

To test specific features:
- Enable/disable settings in game settings menu (Options → Mod Settings)
- Use console commands to manipulate storage: `/c storage.creepers`
- Enable the `gvv` mod for advanced debugging

## Mod Compatibility

**Supported optional dependencies:**
- `space-exploration` - Detects orbital surfaces, uses space tile placement mode
- `space-age` - Shows/hides planet-specific settings, handles new tile types
- `gvv` - Debug visualization support

**Settings-updates.lua** conditionally hides settings based on active mods.

## Common Issues

**Agricultural Tower Radius Bug (line 148, 204, 206):**
The code references `concreep-agricultural-tower-radius` setting which doesn't exist in settings.lua. This will cause nil errors. The setting needs to be added or the references removed.

**Commented GUI Code:**
The entire GUI system in `gui/config_window.lua` is commented out. The custom input keybind (CTRL+J) is registered but does nothing.

**Pattern System Unused:**
Lines 652-664 in `addPort()` set up a pattern capture system but the loops are commented out, so patterns are always empty 4x4 tables.

**Virgin Tiles with Landfill (line 232-235):**
The code filters for virgin tiles, and if none found, switches to look for landfill with hidden tiles. The logic for detecting when to place over landfill may not work as intended.
