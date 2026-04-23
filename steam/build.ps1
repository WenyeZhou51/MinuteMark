# Steam Build Script for Minute (Windows + macOS)
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
$WinBuildDir  = "E:\godotGames\Minute Mark Steam Build"
$MacBuildDir  = "E:\godotGames\Minute Mark Steam Build Mac"
$MacZipPath   = "$MacBuildDir\minute.zip"
$VdfPath      = "$ProjectPath\steam\app_build.vdf"
$SteamCmdPath = "E:\STEAMCMD\steamcmd.exe"

# 1. Clean and ensure build output directories exist
foreach ($dir in @($WinBuildDir, $MacBuildDir)) {
    if (Test-Path $dir) {
        Remove-Item "$dir\*" -Recurse -Force
    } else {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

# 2. Export Windows build
Write-Host "=== Exporting Minute as Windows Desktop release ===" -ForegroundColor Cyan
& $GodotPath --headless --path $ProjectPath --export-release "Windows Desktop" "$WinBuildDir\minute.exe"
Write-Host "Windows export complete: $WinBuildDir\minute.exe" -ForegroundColor Green

# 3. Export macOS build (Godot outputs a .zip containing the .app bundle on Windows)
Write-Host ""
Write-Host "=== Exporting Minute as macOS release ===" -ForegroundColor Cyan
& $GodotPath --headless --path $ProjectPath --export-release "macOS" $MacZipPath

if (-not (Test-Path $MacZipPath)) {
    Write-Host "macOS export failed — zip not found at $MacZipPath" -ForegroundColor Red
    exit 1
}

# 4. Extract the .app bundle from the zip for SteamCMD
Write-Host "Extracting macOS .app from zip..." -ForegroundColor Cyan
Expand-Archive -Path $MacZipPath -DestinationPath $MacBuildDir -Force
Remove-Item $MacZipPath -Force

$appBundle = Get-ChildItem $MacBuildDir -Filter "*.app" -Directory | Select-Object -First 1
if (-not $appBundle) {
    Write-Host "macOS export failed — no .app bundle found after extraction" -ForegroundColor Red
    exit 1
}
Write-Host "macOS export complete: $($appBundle.FullName)" -ForegroundColor Green

# 5. Upload both depots to Steam
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
