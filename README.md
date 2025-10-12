# Concreep Redux

**Automated concrete placement and upgrading for Factorio 2.0**

Roboports automatically place and upgrade tiles (stone brick, concrete, refined concrete) within their construction areas. Set it and forget it – your factory floor will tile itself as you expand!

## Features

### 🔧 Three Tile Placement Modes

- **Standard Mode**: Progressive tiling with automatic upgrades (brick → concrete → refined concrete)
- **Pattern Mode**: Capture and replicate custom tile patterns from around roboports
- **Coverage Type Mode**: Different tiles for logistic vs construction areas

### 🎯 Smart Automation

- **Auto-Wake System**: Sleeping roboports randomly wake to check for new upgrade opportunities
- **Pattern Capture**: Detects both placed tiles and tile ghosts for accurate pattern replication
- **Delayed Activation**: 30-second delay when placing roboports in pattern mode, giving you time to set up patterns
- **Agricultural Tower Avoidance**: Automatically avoids tiling near agricultural towers (with quality-aware radius adjustment)
- **Obstacle Clearing**: Optionally marks trees, rocks, and cliffs for deconstruction

### 📊 Roboport Status GUI

Open any roboport to see:
- Current status (Active, Sleeping, Upgrading, Waiting for pattern)
- Progress: current radius vs target radius
- Tile mode and surface status
- Countdown timers for pattern mode delays

### 🛠️ Console Commands

- `/concreep-help` - Show available commands
- `/concreep-status` - Detailed status breakdown by surface
- `/concreep-rebuild` - Rebuild roboport list (fixes corrupted saves)
- `/concreep-wake` - Wake all sleeping roboports

### ⚙️ Highly Configurable

**Performance Settings:**
- Update frequency (how often to check roboports)
- Update count (roboports processed per check)
- Idle bot percentage (reserve bots for other tasks)
- Minimum item reserve (keep materials in stock)

**Behavior Settings:**
- Range percentage (tile within X% of roboport radius)
- Circular vs square tiling
- Construction vs logistic radius limiting
- Per-planet enable/disable (Space Age)

**Tile Options:**
- Enable/disable brick placement
- Auto-upgrade brick to concrete
- Auto-upgrade concrete to refined concrete
- Pattern size (3x3 to 16x16)
- Coverage type mode tile selection

**Clearing Options:**
- Deconstruct cliffs, rocks, trees
- Landfill water tiles
- Pump radius protection (preserve water near pumps)

## Installation

1. Download the latest release from the [Factorio Mod Portal](https://mods.factorio.com/mod/concreep-redux) or [GitHub Releases](https://github.com/utoxin/concreep-redux/releases)
2. Place the zip file in your Factorio mods folder
3. Enable the mod in-game

**Or** subscribe via the in-game mod browser.

## Usage

### Getting Started

1. Build roboports with construction robots and tiles in their logistics network
2. The mod starts working automatically
3. Adjust settings in Options → Mod Settings → Map

### Pattern Mode

1. Enable Pattern Mode in settings
2. Place a roboport where you want to capture a pattern
3. Within 30 seconds, place tile ghosts in the pattern you want (e.g., checkerboard, stripes)
4. After 30 seconds, the pattern is captured and will be replicated across the area
5. Select any roboport to see a cyan preview of its pattern capture area

### Monitoring

- Open any roboport GUI to see its concreep status in the sidebar
- Use `/concreep-status` for a complete overview of all roboports
- Watch for status messages when changing settings

## Compatibility

- **Factorio 2.0+** required
- **Space Age**: Full support with per-planet enable/disable
- **Space Exploration**: Automatic detection of orbital surfaces, special space tile handling
- Optional **GVV** support for debugging

## Version History

See [CHANGELOG.txt](concreep-redux/changelog.txt) for full version history.

### Latest: 3.2.0 (2025-10-12)

- Added roboport sidebar GUI with live status updates
- Pattern mode enhancements: ghost detection, 30-second delays, auto re-capture
- Auto-wake system for sleeping roboports
- Console commands for help, status, rebuild, and wake
- Major bug fixes: sleep mode, surface filtering, deleted roboports, game freezes
- Automatic migration to fix affected saves

## Contributing

Found a bug? Have a feature request? Please open an issue on [GitHub](https://github.com/utoxin/concreep-redux/issues).

## Credits

- **Original Mod**: [Concreep](https://mods.factorio.com/mod/Concreep) by PiggyWhiskey
- **Current Maintainer**: Utoxin
- **Contributors**: See [GitHub Contributors](https://github.com/utoxin/concreep-redux/graphs/contributors)

## License

This mod is released under the MIT License. See LICENSE for details.

---

**Enjoy your self-paving factory floors!** 🏭✨
