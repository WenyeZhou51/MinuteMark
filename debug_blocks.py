import os
import re

def check_gdscript_blocks(filepath):
    if not filepath.endswith('.gd'):
        return
    
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    for i, line in enumerate(lines):
        stripped = line.strip()
        if stripped.endswith(':') and not stripped.startswith('#'):
            # Check indentation of next non-empty, non-comment line
            current_indent = len(line) - len(line.lstrip())
            
            j = i + 1
            while j < len(lines):
                next_line = lines[j]
                next_stripped = next_line.strip()
                if next_stripped == '' or next_stripped.startswith('#'):
                    j += 1
                    continue
                
                next_indent = len(next_line) - len(next_line.lstrip())
                if next_indent <= current_indent:
                    print(f"ERROR: malformed block at {filepath}:{i+1}")
                    print(f"  Line {i+1}: {line.rstrip()}")
                    print(f"  Line {j+1}: {next_line.rstrip()}")
                break
            else:
                # End of file reached after colon
                print(f"ERROR: colon at end of file in {filepath}:{i+1}")

if __name__ == "__main__":
    for root, dirs, files in os.walk('.'):
        for file in files:
            if file.endswith('.gd'):
                check_gdscript_blocks(os.path.join(root, file))

