#!/usr/bin/env python3
"""
Convert GIF to individual PNG frames for use in Godot AnimatedSprite2D

Usage:
    python convert_gif_to_frames.py
    
This will convert "Bg pocket watch.gif" to individual frames in a "pocket_watch_frames" folder
"""

import os
from PIL import Image

def convert_gif_to_frames(gif_path, output_folder):
    """Convert a GIF file to individual PNG frames"""
    
    # Create output folder if it doesn't exist
    if not os.path.exists(output_folder):
        os.makedirs(output_folder)
    
    # Open the GIF
    try:
        gif = Image.open(gif_path)
    except FileNotFoundError:
        print(f"Error: Could not find {gif_path}")
        return
    except Exception as e:
        print(f"Error opening GIF: {e}")
        return
    
    frame_count = 0
    
    try:
        while True:
            # Convert to RGBA if necessary
            frame = gif.convert('RGBA')
            
            # Save frame as PNG
            frame_path = os.path.join(output_folder, f"frame_{frame_count:04d}.png")
            frame.save(frame_path, 'PNG')
            print(f"Saved frame {frame_count}: {frame_path}")
            
            frame_count += 1
            
            # Move to next frame
            gif.seek(gif.tell() + 1)
            
    except EOFError:
        # End of GIF
        pass
    
    print(f"\nConversion complete! Extracted {frame_count} frames to {output_folder}")
    print(f"\nNext steps:")
    print(f"1. Import the {output_folder} folder into your Godot project")
    print(f"2. Open the pause_menu.tscn scene")
    print(f"3. Select the PocketWatch node")
    print(f"4. Create a new SpriteFrames resource")
    print(f"5. Add all the frames to the animation")
    print(f"6. Set the FPS to match your desired animation speed")
    
    return frame_count


if __name__ == "__main__":
    script_dir = os.path.dirname(os.path.abspath(__file__))
    gif_path = os.path.join(script_dir, "Sprites", "Bg pocket watch.gif")
    output_folder = os.path.join(script_dir, "Sprites", "pocket_watch_frames")
    
    print("=" * 60)
    print("GIF to Frames Converter for Godot")
    print("=" * 60)
    print(f"Input GIF: {gif_path}")
    print(f"Output folder: {output_folder}")
    print("=" * 60)
    print()
    
    if not os.path.exists(gif_path):
        print(f"Error: GIF file not found at {gif_path}")
        print("Please make sure 'Bg pocket watch.gif' is in the Sprites folder")
    else:
        convert_gif_to_frames(gif_path, output_folder)

