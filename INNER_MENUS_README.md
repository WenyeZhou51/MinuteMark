# Inner Menus Implementation

## Overview
This implementation adds three inner menus (Video, Audio, and Assist) to the pause menu system with custom transition animations.

## Features Implemented

### Transition System

**Entering Inner Menu:**
- **Last frame disappears**: When transitioning from the main pause menu, the pocket watch GIF's last frame disappears
- **Inner menu GIF plays**: A new GIF animation (converted to frames in `Sprites/inner_menu_frames/`) plays when entering each inner menu
- **Last frame stays**: The inner menu GIF stays on its last frame after the animation completes
- **Fade in all at once**: All menu options fade in simultaneously

**Exiting Inner Menu (Reverse Animation at 2x Speed):**
- **Menu options disappear instantly**: UI text vanishes immediately (no fade animation)
- **White overlay slides out**: The white overlay slides back out
- **Inner menu GIF plays backwards at 2x speed**: The animation plays in reverse from last frame to first at double speed
- **Inner menu fades out**: The first frame fades out
- **Pocket watch reappears**: The pocket watch last frame fades back in, returning to the main pause menu

### Video Menu (`video_menu.gd`, `video_menu.tscn`)
- **Screen Brightness Slider**: Adjusts brightness from 30% to 200% (default 100%)
- **Fullscreen Toggle**: Switches between fullscreen and windowed mode
- Settings are applied in real-time

### Audio Menu (`audio_menu.gd`, `audio_menu.tscn`)
- **Master Volume Slider**: Controls overall game volume (0-100%)
- **Music Level Slider**: Controls music volume (0-100%)
- **Game Sound Slider**: Controls sound effects volume (0-100%)
- Audio buses are created automatically if they don't exist
- Settings are applied in real-time

### Assist Menu (`assist_menu.gd`, `assist_menu.tscn`)
- **God Mode Toggle**: Makes the player invulnerable to damage and prevents stun
- **Infinite Jumps Toggle**: Allows the player to jump infinitely in mid-air
- **Time Slow Slider**: Adjusts game time from 0% (normal) to 100% (90% slower)
  - **Important**: Time slow only affects in-game physics and gameplay
  - Menus, animations, and UI are NOT affected by time slow
  - Time scale is properly restored when exiting pause menu

## Usage

### Opening Inner Menus
1. Press ESC to open the pause menu
2. Click on VIDEO, AUDIO, or ASSIST buttons
3. The main menu elements will hide and the inner menu will appear with the transition animation

### Returning to Main Menu
- Press **ESC** while in any inner menu (goes back to pause menu, not game)
- Click the **"< BACK"** button
- The reverse animation will play at 2x speed (text disappears instantly, GIF plays backwards faster, pocket watch reappears)
- The main pause menu will be fully visible after the transition completes
- ESC in inner menu is handled separately and won't unpause the game

## Technical Details

### Base Class (`base_inner_menu.gd`)
- Shared animation logic for all inner menus
- Handles GIF frame loading and playback
- Manages fade-in animations with stagger effect
- Implements back button functionality

### Animation Settings (Configurable in Inspector)
- `inner_menu_fade_duration`: How fast the inner menu GIF fades in (default: 0.2s)
- `inner_menu_fps`: Playback speed of inner menu animation (default: 60 FPS)
- `white_overlay_slide_duration`: How fast the white overlay slides in (default: 0.3s)
- `white_overlay_slide_distance`: Distance the overlay travels (default: 50px)
- `menu_fade_duration`: How fast each option fades in (default: 0.3s)
- `option_stagger_delay`: Delay between each option appearing (default: 0.1s)

### Player Integration
- **Infinite Jumps**: Modified `player.gd` `_handle_jump_input()` to check for `infinite_jumps_enabled` metadata
- **God Mode**: Sets `is_invulnerable` property on the player
- **Time Slow**: Stores desired time scale in scene root metadata to persist across menu transitions

### Pause Menu Integration
- Modified `pause_menu.gd` to manage inner menus
- Added `show_inner_menu()` and `show_main_menu()` methods
- Inner menus are children of the PauseMenu node
- Time scale is properly restored when exiting pause menu

## Files Created/Modified

### New Files
- `base_inner_menu.gd` - Base class for all inner menus
- `video_menu.gd` - Video settings logic
- `video_menu.tscn` - Video menu scene
- `audio_menu.gd` - Audio settings logic
- `audio_menu.tscn` - Audio menu scene
- `assist_menu.gd` - Assist settings logic
- `assist_menu.tscn` - Assist menu scene
- `Sprites/inner_menu_frames/` - 11 frames extracted from "New inner menu.gif"

### Modified Files
- `pause_menu.gd` - Added inner menu management
- `pause_menu.tscn` - Added inner menu scene references
- `player.gd` - Added infinite jumps support

## Testing

To test the implementation:
1. Run the game and press ESC to open the pause menu
2. Click on each menu button (VIDEO, AUDIO, ASSIST)
3. Verify the transition animation plays correctly
4. Test each setting to ensure it works
5. Press ESC or click BACK to return to the main menu
6. Resume the game and verify time scale is properly restored

## Notes

- All settings are currently applied in real-time but not saved to disk
- To add persistent settings, implement config file saving in each menu's `save_settings()` method
- The brightness control creates a CanvasLayer if it doesn't exist
- Audio buses (Music, Game) are created automatically if they don't exist
- Time slow only affects game physics; menus and UI remain at normal speed


