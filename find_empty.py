import re
import os

def find_empty_blocks(filepath):
    if not filepath.endswith('.gd'):
        return
    
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    for i in range(len(lines)):
        line = lines[i]
        stripped = line.strip()
        if stripped.endswith(':') and not stripped.startswith('#'):
            # Check if next non-empty line is indented
            found_indented = False
            current_indent = len(line) - len(line.lstrip())
            
            for j in range(i + 1, len(lines)):
                next_line = lines[j]
                if next_line.strip() == '':
                    continue
                
                next_indent = len(next_line) - len(next_line.lstrip())
                if next_indent > current_indent:
                    found_indented = True
                break
            
            if not found_indented:
                print(f"Empty block detected at {filepath}:{i+1}: {line.strip()}")

if __name__ == "__main__":
    files = [
        "player.gd",
        "pendulum_story.gd",
        "kickable_object.gd",
        "enemy_bullet.gd",
        "audio_manager.gd",
        "enemy.gd",
        "pause_menu.gd",
        "shader_test.gd",
        "base_inner_menu.gd",
        "addons/juicy-effect/UI/Wiggle_polygon.gd",
        "addons/juicy-effect/UI/Juicy_button.gd",
        "addons/juicy-effect/Effects/juicy_set_active.gd",
    ]
    for f in files:
        find_empty_blocks(f)

