# Steam Build Script for Minute
# Run from anywhere — all paths are absolute.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File "E:\godotGames\minute\steam\build.ps1"
#
# Prerequisites:
#   - Godot 4.3 installed at E:\godot\Godot_v4.3-stable_win64.exe
#   - SteamCMD installed at E:\STEAMCMD\steamcmd.exe
#   - Export templates installed for Godot 4.3

$ErrorActionPreference = "Stop"

$GodotPath    = "E:\godot\Godot_v4.3-stable_win64.exe"
$ProjectPath  = "E:\godotGames\minute"
$BuildDir     = "E:\godotGames\Minute Mark Steam Build"
$VdfPath      = "$ProjectPath\steam\app_build.vdf"
$SteamCmdPath = "E:\STEAMCMD\steamcmd.exe"
$PresetName   = "Windows Desktop"
$ExeName      = "minute.exe"

# 1. Ensure build output directory exists
if (-not (Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Path $BuildDir -Force | Out-Null
}

# 2. Export the game
Write-Host "=== Exporting Minute as Windows Desktop release ===" -ForegroundColor Cyan
& $GodotPath --headless --path $ProjectPath --export-release $PresetName "$BuildDir\$ExeName"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Export failed!" -ForegroundColor Red
    exit 1
}
Write-Host "Export complete: $BuildDir\$ExeName" -ForegroundColor Green

# 3. Upload to Steam
Write-Host ""
Write-Host "=== Uploading to Steam via SteamCMD ===" -ForegroundColor Cyan
Write-Host "You will be prompted for your Steam password and Steam Guard code." -ForegroundColor Yellow
& $SteamCmdPath +login purplehairedkingkong +run_app_build $VdfPath +quit
if ($LASTEXITCODE -ne 0) {
    Write-Host "SteamCMD upload failed!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=== Done! ===" -ForegroundColor Green
Write-Host "Go to https://partner.steamgames.com/ > App 4387950 > SteamPipe > Builds"
Write-Host "Set the new build live on the 'default' branch, then Publish."
