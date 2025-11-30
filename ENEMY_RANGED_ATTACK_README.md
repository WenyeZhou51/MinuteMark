# Enemy Ranged Attack & Bullet Parry System

## Overview
This document describes the enemy ranged attack system with bullet parrying mechanics implemented in the game.

## Features Implemented

### 1. Enemy Ranged Attack System
Enemies now shoot bullets at the player at regular intervals with visual warning indicators.

#### Configuration Parameters (in `enemy.gd`)
All parameters are exposed as @export variables for easy tuning:

- **`shooting_enabled`** (bool, default: true) - Enable/disable ranged attacks
- **`shoot_interval`** (float, default: 1.0) - Time between shots in seconds
- **`warning_duration`** (float, default: 0.3) - Duration of warning indicator before shooting
- **`bullet_speed`** (float, default: 800.0) - Speed of fired bullets
- **`detection_range`** (float, default: 800.0) - Range to detect and shoot at player
- **`warning_shake_intensity`** (float, default: 3.0) - Intensity of exclamation mark shake

#### Behavior
1. Enemy detects player within `detection_range`
2. After `shoot_interval` seconds, a vibrating yellow exclamation mark (!) appears above the enemy
3. The exclamation mark shakes for `warning_duration` seconds
4. Enemy shoots a bullet towards the player's current position
5. Cycle repeats

### 2. Bullet System
Bullets are highly visible with particle trail effects.

#### Configuration Parameters (in `enemy_bullet.gd`)
- **`speed`** (float, default: 2500.0) - Speed of the bullet
- **`lifetime`** (float, default: 5.0) - Auto-destroy after this many seconds

#### Visual Features
- **Bright orange color** for high visibility
- **Particle trail system** with:
  - 50 particles
  - Gradual fade from bright orange to transparent
  - Scale curve for natural dissipation
  - Damping for realistic motion
- **Cyan color when parried** to indicate redirected state

#### Behavior
- Travels in a straight line towards initial target
- Hits player: triggers stun/hitstun effect
- Hits wall/platform: destroys
- Can be parried by player kick

### 3. Player Bullet Parry System
Players can deflect enemy bullets back at the enemy using their kick attack.

#### Configuration Parameters (in `player.gd`)
- **`parry_enabled`** (bool, default: true) - Enable/disable bullet parrying
- **`parry_detection_range`** (float, default: 100.0) - Range to detect bullets for parrying
- **`parry_angle_cone`** (float, default: 120.0) - Cone angle in front of player for bullet detection (degrees)

#### Behavior
1. Player detects nearby bullets within `parry_detection_range`
2. Bullets must be in a cone in front of the player (defined by `parry_angle_cone`)
3. **Bright cyan indicator line** shows the closest parryable bullet
4. Press kick button (default: 'J') to parry the bullet
5. Parried bullet:
   - Changes to cyan color
   - Redirects towards the enemy that shot it
   - Trail changes to cyan
   - Can hit and destroy the shooter enemy
6. Player gets brief cyan flash feedback on successful parry

#### Priority System
When player presses kick, actions are prioritized as follows:
1. **Bullet Parry** (highest priority) - if a bullet is in range
2. **Kick Object** - if a kickable object is nearby
3. **Kick Enemy** (lowest priority) - if an enemy is nearby

### 4. Parried Bullet Interaction
When a parried bullet hits the enemy that shot it:
- Enemy is converted to a **physics object**
- Enemy flies backward with the bullet's momentum
- Enemy starts falling with gravity
- Enemy fades out and despawns

## Implementation Details

### Enemy Shooting Logic (`enemy.gd`)
```gdscript
func _update_shooting(delta: float):
    - Updates shoot_timer
    - When timer expires: starts warning
    - During warning: vibrates exclamation mark
    - After warning_duration: shoots bullet

func _shoot_at_player():
    - Calculates direction to player
    - Instantiates bullet
    - Initializes with direction, speed, and shooter reference
```

### Bullet Parry Logic (`player.gd`)
```gdscript
func _update_bullet_detection():
    - Finds all bullets in "enemy_projectiles" group
    - Checks distance and cone angle
    - Populates nearby_bullets array

func _parry_bullet(bullet):
    - Calls bullet.parry() method
    - Redirects bullet towards shooter
    - Visual feedback (cyan flash)
```

### Bullet Redirection (`enemy_bullet.gd`)
```gdscript
func parry(parry_direction):
    - Changes bullet color to cyan
    - Reverses velocity towards shooter enemy
    - Updates collision mask to hit enemies
    - Changes particle trail to cyan
```

## Visual Indicators

### 1. Warning Indicator (Enemy)
- **Yellow exclamation mark (!)**
- Positioned above enemy (-60 pixels Y offset)
- Vibrates with configurable intensity
- Font size: 48
- Red outline for visibility

### 2. Parry Indicator (Player)
- **Cyan line** from player to nearest parryable bullet
- Width: 4.0 pixels
- Only shows when bullet is in parry range and cone

### 3. Bullet Trail
- **Normal bullets**: Orange gradient trail
- **Parried bullets**: Cyan gradient trail
- 50 particles with fade effect
- 0.4 second lifetime per particle

## Testing the System

1. **Start the game** in the Godot editor
2. **Get within 800 units** of an enemy
3. **Observe**:
   - Yellow exclamation mark appears above enemy
   - Exclamation mark vibrates for 0.3 seconds
   - Bullet fires towards player
4. **To parry**:
   - Wait for bullet to approach
   - Watch for cyan indicator line
   - Press kick button ('J') when indicator shows
   - Bullet should change to cyan and redirect
5. **Parried bullet** should hit the enemy and convert it to a physics object

## Tuning Guide

### Make enemies shoot faster
- Reduce `shoot_interval` (e.g., 0.5 for twice as fast)

### Make bullets faster
- Increase `bullet_speed` in enemy (affects initial speed)
- Increase `speed` in bullet (affects parried speed)

### Make parrying easier
- Increase `parry_detection_range` (more range)
- Increase `parry_angle_cone` (wider cone, easier to catch bullets from sides)

### Make parrying harder
- Reduce `parry_detection_range` (requires closer timing)
- Reduce `parry_angle_cone` (must face bullet directly)

### Adjust warning time
- Increase `warning_duration` for more reaction time
- Decrease for less reaction time (harder)

## Collision Layers

- **Layer 1**: Player and platforms
- **Layer 3**: Enemy areas
- **Layer 5 (16)**: Enemy bullets

Parried bullets change their collision mask to hit enemies on Layer 3.

