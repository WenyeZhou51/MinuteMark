import os

def check_indentation_jumps(filepath):
    if not filepath.endswith('.gd'):
        return
    
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    last_indent = 0
    for i, line in enumerate(lines):
        stripped = line.strip()
        if stripped == '' or stripped.startswith('#'):
            continue
        
        current_indent = 0
        for char in line:
            if char == '\t':
                current_indent += 1
            elif char == ' ':
                # Mix of tabs and spaces? Let's just count 4 spaces as 1 indent for check
                # but GDScript really prefers one or the other.
                pass 
            else:
                break
        
        if current_indent > last_indent + 1:
            print(f"Indentation jump at {filepath}:{i+1}: {last_indent} -> {current_indent}")
            print(f"  Line: {line.rstrip()}")
        
        # After a colon, the next line MUST be indented exactly last_indent + 1
        # But for now, let's just track the "allowed" indent.
        if stripped.endswith(':'):
            last_indent = current_indent
        else:
            # If it doesn't end in a colon, the next line can be same or less.
            # Except for multiline statements, but those are complex.
            last_indent = current_indent

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
    ]
    for f in files:
        if os.path.exists(f):
            check_indentation_jumps(f)

