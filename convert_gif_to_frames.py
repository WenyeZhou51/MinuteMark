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
        return
    except Exception as e:
        return
    
    frame_count = 0
    
    try:
        while True:
            # Convert to RGBA if necessary
            frame = gif.convert('RGBA')
            
            # Save frame as PNG
            frame_path = os.path.join(output_folder, f"frame_{frame_count:04d}.png")
            frame.save(frame_path, 'PNG')
            
            frame_count += 1
            
            # Move to next frame
            gif.seek(gif.tell() + 1)
            
    except EOFError:
        # End of GIF
        pass
    
    
    return frame_count


if __name__ == "__main__":
    script_dir = os.path.dirname(os.path.abspath(__file__))
    gif_path = os.path.join(script_dir, "Sprites", "Bg pocket watch.gif")
    output_folder = os.path.join(script_dir, "Sprites", "pocket_watch_frames")
    
    
    if os.path.exists(gif_path):
        convert_gif_to_frames(gif_path, output_folder)

