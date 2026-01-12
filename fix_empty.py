import os

def fix_empty_blocks(filepath):
    if not filepath.endswith('.gd'):
        return
    
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    new_lines = []
    i = 0
    while i < len(lines):
        line = lines[i]
        new_lines.append(line)
        stripped = line.strip()
        
        if stripped.endswith(':') and not stripped.startswith('#'):
            # Check if next non-empty line is indented
            found_indented = False
            current_indent = len(line) - len(line.lstrip())
            
            insert_pos = -1
            for j in range(i + 1, len(lines)):
                next_line = lines[j]
                if next_line.strip() == '':
                    continue
                
                next_indent = len(next_line) - len(next_line.lstrip())
                if next_indent > current_indent:
                    found_indented = True
                else:
                    insert_pos = j
                break
            else:
                # End of file
                insert_pos = len(lines)
            
            if not found_indented:
                # Add a pass line
                indent_str = line[:len(line) - len(line.lstrip())]
                # If the line itself was indented, we need to indent pass more
                # GDScript uses tabs or spaces, we should match.
                if '\t' in line:
                    indent_str += '\t'
                else:
                    indent_str += '    '
                new_lines.append(f"{indent_str}pass\n")
        i += 1

    with open(filepath, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)

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
        fix_empty_blocks(f)

