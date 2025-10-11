param(
    [switch]$Clean
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Always operate from the script directory (repo root)
Set-Location -Path $PSScriptRoot

# Paths
$modRoot = Join-Path $PSScriptRoot 'concreep-redux'
$infoPath = Join-Path $modRoot 'info.json'

if (-not (Test-Path $infoPath)) {
    throw "info.json not found at $infoPath"
}

# Read name/version from info.json
$info = Get-Content $infoPath -Raw | ConvertFrom-Json
if (-not $info) { throw 'Unable to parse info.json' }
if ($info.factorio_version -ne '2.0') { Write-Warning "factorio_version is $($info.factorio_version); expected 2.0" }

$name    = $info.name
$version = $info.version
$folderName = "$name`_$version"
$zipName    = "$folderName.zip"

# Validate minimal required files exist before packaging
$required = @('info.json', 'control.lua', 'data.lua', 'settings.lua')
$missing  = @()
foreach ($f in $required) {
    if (-not (Test-Path (Join-Path $modRoot $f))) { $missing += $f }
}
if ($missing.Count -gt 0) {
    throw "Missing required files in concreep-redux: $($missing -join ', ')"
}

# Staging directory to ensure correct top-level folder inside the zip
$stagingRoot = Join-Path $PSScriptRoot '.build'
$stagingMod  = Join-Path $stagingRoot $folderName

# Optional clean
if ($Clean) {
    if (Test-Path $stagingRoot) { Remove-Item $stagingRoot -Recurse -Force -ErrorAction SilentlyContinue }
    if (Test-Path $zipName)     { Remove-Item $zipName -Force -ErrorAction SilentlyContinue }
}

# Prepare staging
New-Item -ItemType Directory -Path $stagingRoot -Force | Out-Null
if (Test-Path $stagingMod) { Remove-Item $stagingMod -Recurse -Force }
New-Item -ItemType Directory -Path $stagingMod | Out-Null

# Copy mod contents into name_version staging folder
# This copies all playable mod files; repository extras (like .junie) are outside modRoot and won't be included.
Copy-Item -Path (Join-Path $modRoot '*') -Destination $stagingMod -Recurse -Force

# Remove any pre-existing zip
if (Test-Path $zipName) { Remove-Item $zipName -Force }

# Create the zip with the correct top-level folder name
Compress-Archive -Path $stagingMod -DestinationPath (Join-Path $PSScriptRoot $zipName) -Force

# Basic report and cleanup staging
Write-Host "Created $zipName" -ForegroundColor Green

# Remove staging (keep .build folder for speed if desired)
Remove-Item $stagingMod -Recurse -Force -ErrorAction SilentlyContinue

# Final smoke message
"OK: Packaged $name $version -> $zipName"