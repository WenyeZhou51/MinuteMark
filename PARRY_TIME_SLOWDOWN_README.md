# Parry Time Slowdown & Vertical Boost

## Overview
Successfully parrying a bullet now triggers dramatic slow-motion and launches the player upward, creating epic, stylish combat moments!

## Features

### 1. Time Slowdown Effect ⏱️
When you parry a bullet, time slows dramatically:
- **80% slower** (runs at 20% speed by default)
- Lasts for **0.3 seconds** (real-time)
- Gives you time to admire your perfect parry
- Creates a "Matrix bullet-time" effect

### 2. Vertical Boost 🚀
Successful parry launches the player upward:
- **300 pixels/second** upward velocity (default)
- Maintains air control after boost
- Can chain into other aerial moves
- Allows for stylish aerial combat

## Configuration

All parameters are exposed in the Inspector under **"Bullet Parry"** group:

### Time Slowdown Parameters
- **`parry_time_scale`** (float, default: 0.2)
  - Time speed during parry slow-motion
  - 0.2 = 20% speed (80% slower)
  - 0.1 = 10% speed (90% slower, more dramatic)
  - 1.0 = normal speed (no slowdown)

- **`parry_time_duration`** (float, default: 0.3)
  - How long slow-motion lasts (in real-time seconds)
  - Increase for longer dramatic effect
  - Decrease for quicker gameplay

### Vertical Boost Parameter
- **`parry_vertical_boost`** (float, default: 300.0)
  - Upward velocity applied on parry
  - Higher = bigger launch
  - Lower = subtle boost
  - 0.0 = no vertical boost

## Gameplay Experience

### Before Parry
```
Enemy shoots bullet → Bullet approaches player
```

### During Parry
```
Player presses kick → Bullet deflected
    ↓
⏱️ TIME SLOWS TO 20% SPEED
🚀 PLAYER LAUNCHES UPWARD
💫 Cyan flash effect
    ↓
Slow-motion lasts 0.3 seconds
    ↓
⏱️ TIME RETURNS TO NORMAL
```

### Result
- Player in the air with full control
- Bullet redirected at enemy
- Epic slow-motion moment
- Stylish and satisfying!

## Technical Implementation

### Modified Files

#### `player.gd`

**New Configuration Parameters:**
```gdscript
@export var parry_time_scale: float = 0.2  # 80% slower
@export var parry_time_duration: float = 0.3  # 0.3s real-time
@export var parry_vertical_boost: float = 300.0  # Upward force
```

**New State Variables:**
```gdscript
var parry_time_slowdown_active: bool = false
var parry_time_slowdown_timer: float = 0.0
```

**New Methods:**
- `_start_parry_time_slowdown()` - Activates slow-motion
- `_restore_normal_time()` - Returns to normal speed

**Modified Methods:**
- `_parry_bullet()` - Now applies vertical boost and time slowdown
- `_physics_process()` - Updates time slowdown timer (uses real delta)
- `_ready()` - Ensures time scale starts at 1.0
- `_exit_tree()` - Resets time scale when player is removed

### Time Scale System

Uses `Engine.time_scale` to affect the entire game:
```gdscript
Engine.time_scale = 0.2  # Slow to 20% speed
# ... wait 0.3 real seconds ...
Engine.time_scale = 1.0  # Back to normal
```

**Real-Time Timer:**
```gdscript
var real_delta = delta / Engine.time_scale
parry_time_slowdown_timer -= real_delta
```
This ensures the timer counts down in real-time even when the game is slowed.

### Safety Features

1. **Reset on scene load** - `_ready()` sets time scale to 1.0
2. **Reset on player removal** - `_exit_tree()` sets time scale to 1.0
3. **Automatic restoration** - Timer automatically restores normal speed

## Tuning Guide

### More Dramatic Slow-Motion
- **Decrease `parry_time_scale`** (e.g., 0.1 for 90% slower)
- **Increase `parry_time_duration`** (e.g., 0.5 for longer effect)
- Creates more cinematic, stylish gameplay

### Faster-Paced Gameplay
- **Increase `parry_time_scale`** (e.g., 0.4 for 60% slower)
- **Decrease `parry_time_duration`** (e.g., 0.2 for shorter effect)
- Keeps action moving quickly

### Bigger Launch
- **Increase `parry_vertical_boost`** (e.g., 500 for high jump)
- Great for aerial combos and platforming

### Subtle Launch
- **Decrease `parry_vertical_boost`** (e.g., 150 for small hop)
- More grounded combat feel

### No Time Slowdown (disable feature)
- **Set `parry_time_scale` to 1.0**
- Time will not slow down on parry
- Vertical boost still works

### No Vertical Boost (disable feature)
- **Set `parry_vertical_boost` to 0.0**
- Player won't launch upward
- Time slowdown still works

## Combo Possibilities

The vertical boost and air control open up new combo opportunities:

1. **Parry → Air Dash** - Parry, get launched, then air dash
2. **Parry → Dive Attack** - Parry upward, then dive down on enemies
3. **Parry → Wall Run** - Parry near wall, land on wall running
4. **Multi-Parry** - Parry multiple bullets in sequence (if available)

## Visual & Audio Cues

### Current Visual Feedback
- **Cyan flash** on successful parry
- **Time appears to slow** (everything moves slower)
- **Player launches upward** visibly
- **Bullet changes to cyan** and redirects

### Suggested Enhancements (Future)
- Screen shake during slow-motion
- Chromatic aberration effect
- Vignette during slow-motion
- Slow-motion sound effect (pitch shift)
- "Whoosh" sound for vertical boost
- Particle effects during launch

## Performance Notes

- Time scale affects the **entire game**, not just the player
- This includes enemies, bullets, physics, and animations
- Timer uses real-time delta to countdown properly
- Very low performance impact

## Balance Considerations

**Advantages of Current Settings:**
- 0.3s slow-motion is long enough to appreciate but not break flow
- 300 vertical boost is useful but not overpowered
- 80% slowdown is dramatic but doesn't feel too sluggish

**If Players Find It:**
- **Too easy** - Reduce `parry_time_duration` or `parry_time_scale`
- **Too hard** - Increase both for more reaction time
- **Too floaty** - Reduce `parry_vertical_boost`
- **Not rewarding enough** - Increase slowdown duration or boost height

## Testing Checklist

- [x] Time slows to 20% on parry
- [x] Player launches upward with 300 velocity
- [x] Time restores after 0.3 real seconds
- [x] Time scale resets on scene load
- [x] Time scale resets when player is removed
- [x] Player has air control after boost
- [x] Can chain parry into other moves
- [x] All parameters exposed to inspector
- [x] No compilation errors

Enjoy the epic, stylish parry system! 🎯⏱️🚀

