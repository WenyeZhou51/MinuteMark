# Bullet Hit Grace Period System

## Overview
Players now have a 0.1 second grace period when hit by a bullet, allowing them to press kick to cancel hitstun and parry the bullet instead.

## How It Works

### 1. Bullet Hits Player
When a bullet hits the player:
- Instead of immediate hitstun, a **grace period** starts
- Player flashes **bright cyan** rapidly to indicate the grace period
- Player has **0.1 seconds** (configurable) to react

### 2. During Grace Period
The player has two outcomes:

#### A. Press Kick → Parry and Cancel Hitstun ✅
- Pressing kick during grace period **cancels the hitstun completely**
- System automatically detects and parries the nearest bullet
- If no bullets nearby, player gets brief invulnerability (0.3s) as a reward
- Player gets cyan flash feedback on successful parry

#### B. Grace Period Expires → Take Hitstun ❌
- If player doesn't press kick within 0.1 seconds
- Normal hitstun is applied (same as enemy touch)
- Player is stunned and must wait for stun to end

## Configuration

### Inspector Parameters
All parameters exposed in the Inspector under **"Bullet Parry"** group:

- **`bullet_hit_grace_period`** (float, default: 0.1)
  - Time window in seconds to press kick after being hit
  - Increase for easier parrying (more reaction time)
  - Decrease for harder gameplay (less reaction time)

## Visual Feedback

### Grace Period Indicators
1. **Bright cyan flashing** - Player flashes cyan/white rapidly during bullet grace period
2. **Cyan parry indicator** - Line shows nearest parryable bullet
3. **Cyan flash on parry** - Brief cyan flash when successfully parrying

### Different from Enemy Grace Period
- **Bullet grace period**: Bright cyan flash (faster, 50 Hz)
- **Enemy grace period**: Orange flash (40 Hz)
- Different colors help distinguish the two grace period types

## Gameplay Flow Example

```
1. Enemy fires bullet at player
2. Bullet hits player
3. [GRACE PERIOD STARTS - 0.1s window]
   - Player flashes bright cyan
   - Can press kick to parry
4a. Player presses kick within 0.1s
   - Hitstun cancelled!
   - Bullet parried back at enemy
   - Success!
4b. Player doesn't press kick in time
   - Grace period expires
   - Hitstun applied
   - Player is stunned
```

## Technical Implementation

### Modified Files

#### `enemy_bullet.gd`
- Changed `_on_body_entered()` to call `_on_bullet_hit()` instead of `_on_enemy_touched()`
- Provides bullet reference and shooter for grace period handling

#### `player.gd`
**New Configuration:**
- `bullet_hit_grace_period` (0.1s default) - Grace period duration

**New State Variables:**
- `bullet_grace_period_active` - Is grace period active
- `bullet_grace_period_timer` - Time remaining in grace period
- `bullet_that_hit` - Reference to bullet that hit player

**New Methods:**
- `_on_bullet_hit()` - Starts grace period when bullet hits
- `_apply_bullet_hitstun()` - Applies hitstun after grace period expires
- `_cancel_bullet_grace_period_with_parry()` - Cancels hitstun and performs parry

### Grace Period Timer
Updated in `_physics_process()`:
```gdscript
if bullet_grace_period_active:
    bullet_grace_period_timer -= delta
    if bullet_grace_period_timer <= 0:
        _apply_bullet_hitstun()  # Time expired
    else:
        if Input.is_action_just_pressed("melee_attack"):
            _cancel_bullet_grace_period_with_parry()  # Success!
```

## Tuning Guide

### Make Parrying Easier
- **Increase `bullet_hit_grace_period`** (e.g., 0.15 or 0.2)
- More reaction time for players
- More forgiving gameplay

### Make Parrying Harder
- **Decrease `bullet_hit_grace_period`** (e.g., 0.05)
- Requires faster reflexes
- More challenging gameplay

### Combine with Other Parameters
For a balanced experience, tune together with:
- `parry_detection_range` - How far bullets can be detected
- `bullet_speed` - How fast bullets travel
- `warning_duration` - How long enemy warning shows before shooting

## Benefits

1. **Skill-based Defense** - Rewards quick reactions
2. **No Instant Death** - Always a chance to recover
3. **Risk/Reward** - Miss the parry window = guaranteed hitstun
4. **Visual Clarity** - Cyan flash clearly indicates parry opportunity
5. **Fair Gameplay** - Gives players agency even when hit

## Testing

To test the system:
1. Start game near an enemy
2. Let the enemy shoot you
3. When bullet hits, watch for cyan flash
4. Press kick immediately (within 0.1s)
5. Bullet should be parried back at enemy
6. Try waiting too long - should get hitstun instead

