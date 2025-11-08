# 3D Background Setup Guide

## Overview
Your 2D platformer now has a 3D background system that displays your Blender model (`background.glb`) behind the gameplay with a parallax effect.

## What Was Implemented

### 1. SubViewport System
- **Location**: `level.tscn` → `Background3D/SubViewport`
- The 3D scene renders in a separate viewport at 2560x1600 resolution
- The viewport is displayed behind all 2D elements (z_index: -10)

### 2. 3D Background Camera (`background_camera_3d.gd`)
- Automatically follows the player with a parallax effect
- Makes the 3D background move relative to player position
- Creates depth perception in your 2D game

### 3. Scene Structure
```
Level (Node2D)
├── Background3D (SubViewportContainer)
│   └── SubViewport
│       ├── Camera3D (with parallax script)
│       ├── WorldEnvironment (sky/ambient lighting)
│       ├── DirectionalLight3D (main light source)
│       └── BackgroundModel (your background.glb)
├── Player
├── Enemies
└── Platforms
```

## Customization Options

### Adjusting Parallax Effect
In the `background_camera_3d.gd` script, you can modify these exported variables in the Godot editor:

- **`parallax_strength`** (default: 0.08): How much the background moves horizontally
  - Higher value = more movement
  - Lower value = less movement
  
- **`vertical_parallax_strength`** (default: 0.05): How much the background moves vertically
  
- **`base_distance`** (default: 15.0): Camera distance from the background
  - Higher = zoomed out view
  - Lower = closer view
  
- **`smooth_speed`** (default: 5.0): How smoothly the camera follows the player

### Adjusting 3D Background Position/Scale
In `level.tscn`, select the `BackgroundModel` node and adjust:
- **Transform**: Move/rotate/scale your 3D model
- Current position: (0, -5, 0) - lowered by 5 units

### Lighting Adjustments
Select the `DirectionalLight3D` node in the scene to adjust:
- **Light Energy**: Brightness (currently 1.2)
- **Shadow**: Enable/disable shadows
- **Transform**: Change light direction

### Environment Settings
Select the `WorldEnvironment` node to modify:
- **Background Color**: Sky color (currently light blue)
- **Ambient Light**: Overall scene illumination
- **Add fog, sky, or other effects**

## Performance Tips

1. **Viewport Resolution**: If performance is an issue, reduce the SubViewport size in `level.tscn`
2. **Shadow Quality**: Disable shadows on DirectionalLight3D if not needed
3. **Model Complexity**: Use LOD (Level of Detail) for your background model
4. **Update Mode**: Currently set to "Always" - change if background is static

## Troubleshooting

### Background Not Visible
- Check that `z_index` is negative on Background3D
- Verify background.glb imported correctly in Models/ folder
- Check Camera3D position (should be at z: 15)

### Background Not Moving
- Ensure Player is in the "player" group
- Check `player_path` in Camera3D script properties
- Verify parallax values are not zero

### Performance Issues
- Reduce SubViewport size
- Disable shadows
- Simplify the 3D model
- Reduce texture resolution

## Adding More 3D Elements

To add more 3D objects to your background:
1. Open `level.tscn` in Godot
2. Navigate to `Background3D/SubViewport`
3. Add new Node3D or MeshInstance3D nodes
4. Import and instance additional .glb/.gltf files

## Notes
- The 3D background renders independently of the 2D gameplay
- Input events don't affect the 3D viewport (handle_input_locally: false)
- The viewport always updates (render_target_update_mode: 4)
- Player group ensures camera script finds the player automatically

