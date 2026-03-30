# Minute
THIS IS A PLATFORMER ABOUT GOING FAST

A fast-paced 2D platformer set in a collapsing cyberpunk city. The player escapes from an exploding skyscraper using parkour moves like running, jumping, and wall-jumping. The core mechanic is a time-rewind system that freezes past versions of the player in place to use as platforms.

## Setup Instructions

1. Download and install Godot 4.3 or later from the [official Godot Engine website](https://godotengine.org/).
2. Clone this repository to your local machine and import the `project.godot` file into the Godot project manager.
3. Once the project is open in the editor, press F5 or click the "Run Project" button to start the game.

## Steam Build & Upload

### Prerequisites

- **Godot 4.3** with export templates installed (`E:\godot\Godot_v4.3-stable_win64.exe`)
- **SteamCMD** installed at `E:\STEAMCMD\`
- Steamworks account: `purplehairedkingkong`

### Steam IDs

| Item     | ID        |
|----------|-----------|
| App ID   | 4387950   |
| Depot ID | 4387951   |

### One-Command Build & Upload

Run the build script from PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File "E:\godotGames\minute\steam\build.ps1"
```

This will:
1. Export the game as a Windows release build to `E:\godotGames\Minute Mark Steam Build\`
2. Upload it to Steam via SteamCMD (prompts for password + Steam Guard)

### Manual Steps (if you prefer)

**Export only:**
```powershell
& "E:\godot\Godot_v4.3-stable_win64.exe" --headless --path "E:\godotGames\minute" --export-release "Windows Desktop" "E:\godotGames\Minute Mark Steam Build\minute.exe"
```

**Upload only:**
```powershell
& "E:\STEAMCMD\steamcmd.exe" +login purplehairedkingkong +run_app_build "E:\godotGames\minute\steam\app_build.vdf" +quit
```

### After Uploading

1. Go to [Steamworks](https://partner.steamgames.com/) > App 4387950 > **SteamPipe** > **构建 (Builds)**
2. Set the new build live on the **default** branch
3. Click **发布 (Publish)** to push changes

### File Reference

| File | Purpose |
|------|---------|
| `steam/app_build.vdf` | SteamPipe depot/build configuration |
| `steam/build.ps1` | Automated build + upload script |
| `export_presets.cfg` | Godot export presets (Web + Windows Desktop) |
