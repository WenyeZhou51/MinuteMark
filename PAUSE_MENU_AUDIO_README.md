# Pause Menu Audio System

## Overview
The pause menu now includes audio feedback for all interactions.

## Audio Files Required

Place your audio files in an `Audio/` folder in your project root:

### Menu Transition Sound
**File Name:** `menu_transition.wav`, `menu_transition.ogg`, or `menu_transition.mp3`

**When it plays:**
- Entering the pause menu (pressing ESC)
- Entering an inner menu (VIDEO, AUDIO, ASSIST)
- Returning from inner menu to pause menu (pressing ESC or BACK)

### Menu Select Sound
**File Name:** `menu_select.wav`, `menu_select.ogg`, or `menu_select.mp3`

**When it plays:**
- Hovering over a button (mouse)
- Focusing on a button (keyboard/controller navigation)
- Moving a slider
- Toggling a checkbox/toggle button
- Any interactive control change

## Audio File Formats

Supported formats (in order of preference):
1. `.wav` - Uncompressed, best quality
2. `.ogg` - Compressed, good quality, recommended
3. `.mp3` - Compressed, widely compatible

## Implementation Details

### Audio Players
- **MenuTransitionPlayer**: AudioStreamPlayer for transition sounds
- **MenuSelectPlayer**: AudioStreamPlayer for UI interaction sounds

### Automatic Connection
The system automatically connects to:
- All buttons (Button, CheckButton)
- All sliders (HSlider)
- All toggles (CheckBox, CheckButton)

Both in main pause menu and all inner menus (Video, Audio, Assist).

### Audio Buses
Both audio players use the "Master" bus by default, but this respects any audio volume settings you configure in the Audio menu.

## Adding Custom Audio

To add your own audio files:

1. Create an `Audio/` folder in your project root
2. Add your sound files:
   - `menu_transition.wav` (or .ogg/.mp3)
   - `menu_select.wav` (or .ogg/.mp3)
3. The system will automatically detect and load them

## No Audio Files?

If no audio files are found, the system will:
- Still work normally
- Not play any sounds
- Not show any errors

The menu will function silently until you add audio files.

## Customization

To change audio file paths, edit `pause_menu.gd` in the `setup_audio_players()` function:

```gdscript
func setup_audio_players():
    # Change these paths to your audio files
    if ResourceLoader.exists("res://YourPath/transition.wav"):
        menu_transition_player.stream = load("res://YourPath/transition.wav")
```

## Testing Audio

1. Add audio files to `res://Audio/`
2. Run the game
3. Press ESC to open pause menu (transition sound plays)
4. Hover over buttons (select sound plays)
5. Click VIDEO/AUDIO/ASSIST (transition sound plays)
6. Move sliders or toggle options (select sound plays)
7. Press ESC to go back (transition sound plays)

