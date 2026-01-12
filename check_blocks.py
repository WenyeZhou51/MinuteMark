import os

def find_malformed_blocks(filepath):
    if not filepath.endswith('.gd'):
        return
    
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    for i in range(len(lines)):
        line = lines[i]
        stripped = line.strip()
        
        # Look for control flow lines (if, else, for, while, func, elif)
        if stripped.endswith(':') and not stripped.startswith('#'):
            # Found a colon. Now check all following lines until we find a non-empty, non-comment line.
            current_indent = len(line) - len(line.lstrip())
            
            found_indented = False
            for j in range(i + 1, len(lines)):
                next_line = lines[j]
                next_stripped = next_line.strip()
                
                # Skip truly empty lines
                if next_stripped == '':
                    continue
                
                # Skip comments (UNLESS the comment itself is indented, but in GDScript 
                # a block MUST have a statement, a comment is not enough)
                # Actually, in GDScript, a comment DOES NOT count as a statement in a block.
                if next_stripped.startswith('#'):
                    continue
                
                next_indent = len(next_line) - len(next_line.lstrip())
                if next_indent > current_indent:
                    found_indented = True
                    break
                else:
                    # Found a line that is NOT indented more, but it's not a comment or empty.
                    # This is an error.
                    print(f"ERROR at {filepath}:{i+1}: {stripped}")
                    print(f"  Next line {j+1}: {next_line.strip()}")
                    break
            else:
                # Reached end of file without finding an indented line
                print(f"ERROR at {filepath}:{i+1}: {stripped} (End of file reached)")

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
        if os.path.exists(f):
            find_malformed_blocks(f)

