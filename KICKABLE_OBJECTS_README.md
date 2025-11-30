# Kickable Objects System

## Overview
Players can kick objects that fly at high speed and interact with walls and enemies.

## How to Use
1. Press the kick button (J key) near a kickable object
2. The object must be in front of the player (within a 90-degree cone)
3. The object will fly horizontally in the direction the player is facing
4. Objects can only be kicked if they're within the detection range (configurable)

## Collision System

### Collision Layers
- **Layer 1**: Walls and platforms (StaticBody2D)
- **Layer 2**: Player (CharacterBody2D)
- **Layer 3**: Enemies (Area2D)
- **Layer 6**: Kickable Objects (Area2D)

### Collision Setup
- **Kickable Objects**:
  - collision_layer = 32 (Layer 6)
  - collision_mask = 5 (Layers 1 and 3 - walls and enemies)
  
- **Enemies**:
  - collision_layer = 4 (Layer 3)
  - collision_mask = 33 (Layers 1 and 6 - walls and kickable objects)

## Behavior

### When Kicked
- Object flies in a straight line at high speed (configurable, default: 2500 units/sec)
- Object rotates while flying
- Green indicator shows kick direction when near an object

### On Collision with Enemy
- Both the object and enemy become physics objects
- They fall with gravity and bounce
- Both fade out and despawn after 0.5 seconds (configurable)

### On Collision with Wall
- Object becomes a physics object
- Falls with gravity and bounces
- Fades out and despawns after 0.5 seconds (configurable)

## Configurable Parameters (in Inspector)

### Player (Kick Object group)
- `kick_object_enabled`: Enable/disable kicking objects
- `kick_object_detection_range`: How far player can detect objects (default: 60)
- `kick_object_speed`: Speed of kicked objects (default: 2500)
- `kick_object_cone_angle`: Detection cone angle in degrees (default: 90)

### Kickable Object
- `kick_speed`: Speed when kicked (default: 2000)
- `rotation_speed_min/max`: Rotation speed range when flying (default: -10 to 10)
- `physics_duration`: Time as physics object before despawn (default: 0.5)
- `bounce_damping`: Velocity retention after bounce (default: 0.4)
- `gravity_strength`: Gravity applied as physics object (default: 2000)
- `object_size`: Visual size of the object (default: 40x40)

## Notes
- Objects prioritize over enemies - if both are in range, kick will target the object
- Can only kick objects in front of player, not behind
- All parameters are exposed to the inspector for easy tweaking
- No hardcoded values - everything is configurable

