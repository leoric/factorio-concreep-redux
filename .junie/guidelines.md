Project-specific guidelines for Concreep Redux (Factorio 2.0)

Scope and audience
- This document captures project-specific practices and constraints for Concreep Redux. It assumes familiarity with Factorio modding and Lua. Basic concepts and generic Factorio documentation are not repeated here.

Target platforms and compatibility
- Factorio version: 2.0 (info.json factorio_version is 2.0).
- Space Age expansion: Mod must work with or without the expansion.
  - The code paths that refer to Space Age features (e.g., agricultural-tower entity, quality effects) are guarded by presence checks (e.g., prototypes.entity["agricultural-tower"]) and will no-op when the expansion is absent.
  - When Space Age is present, agricultural towers expand a “no-concreep” radius around them; radius scales with tower quality (0..4) as implemented in logic/creep_logic.lua:is_near_agricultural_tower.
- Other large mods: There is an optional dependency reference to Space Exploration in info.json. Verify whether this is intended. Space Exploration is not the same as the Space Age expansion.

Build and configuration
- Layout: This repository’s playable mod folder is concreep-redux/ (containing info.json, control.lua, data.lua, settings*.lua, logic/, gui/, etc.).
- Local development (unzipped):
  1) Close Factorio.
  2) Copy or symlink the concreep-redux folder into your Factorio mods directory, naming the folder exactly concreep-redux_3.1.0 to match the version in info.json. Factorio expects the folder name to be name_version when loading unzipped mods.
     - Example mods path on Windows: %AppData%\Factorio\mods
  3) Restart Factorio; enable the mod in the Mods menu if needed.
- Building a distributable zip:
  - Zip the contents of the concreep-redux folder into a file named concreep-redux_3.1.0.zip with a top-level folder concreep-redux_3.1.0/ that contains info.json at its root. Do not include this repository root or helper files.
  - Minimal bash/PowerShell outline (PowerShell):
    - $version = (Get-Content .\concreep-redux\info.json | ConvertFrom-Json).version
    - $name = (Get-Content .\concreep-redux\info.json | ConvertFrom-Json).name
    - $dest = "$name`_$version.zip"
    - Compress-Archive -Path .\concreep-redux\* -DestinationPath $dest -Force
    - Note: Factorio expects the internal top-level folder to be name_version. If you built from a working tree folder named concreep-redux, you may need to create a temp folder named "$name`_$version" and copy files into it before zipping if you target the mod portal format.

Runtime configuration (project-specific)
- Settings live in settings.lua and settings-updates.lua. They are exposed as mod settings; after changing defaults here, migrate or communicate to players appropriately.
- Key behavior toggles used in code (global settings names):
  - concreep-clear-trees: If true, trees inside the selected tile area are cleared during concreep placement (logic/creep_logic.lua build_tile branch).
  - Other settings exist—search settings.lua for “setting” entries to see names, ranges, and default values used by the logic.

Code structure highlights
- control.lua: event wiring and top-level runtime logic; delegates to logic/creep_logic.lua.
- logic/creep_logic.lua: core placement logic; heavy use of surface APIs, ghost placement, and environmental filters.
  - Uses surface.can_place_entity with name="tile-ghost" to validate placement efficiently.
  - Tree clearing: constrained to construction area for performance (uses is_tile_in_area).
  - Agricultural towers (Space Age): is_near_agricultural_tower(surface, position, base_radius) protects areas; supports both real and ghost towers and scales radius with quality level.
- data.lua: prototype tweaks if any; keep changes compatible with base 2.0 and avoid hard deps on expansion-only prototypes.
- gui/config_window.lua: configuration GUI; ensure it tolerates missing expansion features.

Testing: configuring, running, and extending tests
Note: The project does not include a full test framework. Below are pragmatic checks you can run locally without the Factorio runtime.

A. Fast structural checks (no external tools required)
1) JSON validity for info.json and basic invariants (name/version/dependencies):
   PowerShell, from repository root:
   - $info = Get-Content .\concreep-redux\info.json | ConvertFrom-Json
   - if (-not $info) { throw "Unable to parse info.json" }
   - if ($info.factorio_version -ne "2.0") { throw "factorio_version must be 2.0" }
   - if (-not ($info.dependencies -is [System.Collections.IEnumerable])) { throw "dependencies must be an array" }
   - "$($info.name) $($info.version) info.json OK"

2) Zip integrity build smoke test (ensures all required top-level files exist before packaging):
   - $root = "concreep-redux"
   - $required = @("info.json","control.lua","data.lua","settings.lua")
   - $missing = $required | Where-Object { -not (Test-Path (Join-Path $root $_)) }
   - if ($missing) { throw "Missing files: $($missing -join ', ')" } else { "Structure OK" }

3) Lua syntax probe (optional, if Lua is on PATH):
   - Get-ChildItem .\concreep-redux -Recurse -Filter *.lua | ForEach-Object { luac -p $_.FullName } 
   - If luac is not available, skip.

B. Minimalistic logic probe via stubbing (expansion-aware)
- Some logic supports Space Age features but is guarded by prototype presence checks. You can quickly exercise the guard logic in a plain Lua interpreter by stubbing just enough API:
  - Create a throwaway Lua snippet (do not commit) that sets: prototypes = { entity = {} } to simulate “no expansion,” then require("concreep-redux/logic/creep_logic.lua") if the module is coded for require; otherwise, loadfile. Ensure any global Factorio APIs referenced are stubbed or the snippet only touches functions that don’t immediately call engine APIs.
  - Prefer in-game tests for behavior; see below.

C. In-game scenario checks (manual but reliable)
- With Space Age installed:
  1) Place an agricultural tower and a roboport with construction bots and concrete in the logistic network.
  2) Verify concrete is not ghosted within the tower’s protected radius; upgrade radius grows with tower quality.
- Without Space Age:
  1) Set up a basic roboport + bots + concrete.
  2) Verify concrete ghosts are placed as expected and that no errors occur due to missing agricultural towers.

Adding and running new tests
- Keep tests as local developer artifacts unless we introduce a formal framework; the mod portal package should not include them.
- For quick checks, add PowerShell scripts under a temporary folder (e.g., .junie/tmp or .scratch), run them locally, and remove afterward.
- Example local-only test (PowerShell) that you can paste into a console from repo root:
  - $info = Get-Content .\concreep-redux\info.json | ConvertFrom-Json
  - if ($info.factorio_version -ne "2.0") { throw "factorio_version mismatch" }
  - if (-not ($info.dependencies -is [System.Collections.IEnumerable])) { throw "dependencies not array" }
  - "OK: $($info.name) $($info.version)"

Notes and caveats for Factorio 2.0 / Space Age
- Agricultural tower entity name is agricultural-tower. Code checks prototypes.entity["agricultural-tower"] before applying protection logic.
- Quality handling: When present, tower.quality.level (0..4) increases the no-concreep radius; ghost towers use ghost.ghost_quality.level similarly. Ensure any future changes to Factorio’s quality API are mirrored here.
- Dependencies:
  - info.json currently contains an optional dependency string for Space Exploration (a mod), not the Space Age expansion. Confirm project intent:
    - If you want optional ordering wrt Space Age expansion, use the standard dependency token for the expansion (e.g., "?space-age") rather than third-party mods. Keep it optional so the mod loads without the expansion.

Release checklist (project-specific)
- Verify settings defaults align with gameplay expectations (tree clearing, upgrade behavior) for both base and expansion.
- Run structural checks (A.1–A.2). If available, run luac syntax checks.
- Test in a clean profile with only this mod enabled (with and without Space Age) to catch hidden hard dependencies.
- Package as name_version.zip with correct internal folder layout.

Troubleshooting quick refs
- Ghost placement denied unexpectedly: Check surface.can_place_entity("tile-ghost", inner_name=tile) constraints—entity collisions, map generation (water), or other mods may block.
- Performance: Avoid scanning large areas with find_entities_filtered per tile; prefer can_place_entity and narrow areas as done in build_tile. If extending logic, maintain O(n) tile operations without nested wide-range queries.
- Agricultural towers appear to block too aggressively: Verify base radius and quality-scaling math; consider exposing the base radius as a mod setting if players request tuning.


Build script (recommended)
- A PowerShell build script is available at the repository root: build.ps1.
- What it does:
  - Reads name and version from concreep-redux/info.json.
  - Verifies required files exist before packaging.
  - Stages files into a name_version folder to ensure the correct top-level folder inside the zip.
  - Produces name_version.zip at the repository root (e.g., concreep-redux_3.1.0.zip).
  - Excludes repository helper files; only the contents of concreep-redux/ are packaged.
- Usage (run from repo root):
  - .\build.ps1
  - .\build.ps1 -Clean  # optional; clears previous artifacts before building
- Requirements: PowerShell 5+ (Windows default is fine). No external tools needed.
- Notes:
  - The script warns if factorio_version in info.json is not 2.0.
  - The packaged zip is suitable for direct upload to the Factorio Mod Portal.
