import os

def check_gdscript_blocks(filepath):
    if not filepath.endswith('.gd'):
        return
    
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    for i, line in enumerate(lines):
        stripped = line.strip()
        
        # Check if the line ends with a colon and is NOT a comment
        if stripped.endswith(':') and not stripped.startswith('#'):
            # Also ignore lines ending in '\' which are continuations
            # Wait, the colon is at the END of the whole statement.
            
            # Find the indentation of the START of this statement
            # This is tricky because of multiline statements.
            # But for simplicity, let's just look at the line itself.
            current_indent = len(line) - len(line.lstrip())
            
            # Find the next non-empty, non-comment line
            j = i + 1
            while j < len(lines):
                next_line = lines[j]
                next_stripped = next_line.strip()
                if next_stripped == '' or next_stripped.startswith('#'):
                    j += 1
                    continue
                
                next_indent = len(next_line) - len(next_line.lstrip())
                if next_indent <= current_indent:
                    # Potential error. But wait, what if it's a one-liner like `if x: return`?
                    # Stripped line already ends in ':', so it's not a one-liner.
                    
                    # BUT! Check if it's a multiline condition that just happens to end here.
                    # e.g.
                    # if (a or
                    #     b):
                    #     pass
                    # In this case, 'b):' indentation is more than 'if'.
                    # We should find the REAL start of the statement.
                    
                    # For our purposes, usually empty blocks happen after 'if something:'
                    # where 'if' is at the start of the line.
                    print(f"ERROR: malformed block at {filepath}:{i+1}")
                    print(f"  Line {i+1}: {line.rstrip()}")
                    print(f"  Line {j+1}: {next_line.rstrip()}")
                break
            else:
                # End of file
                print(f"ERROR: colon at end of file in {filepath}:{i+1}")

if __name__ == "__main__":
    for root, dirs, files in os.walk('.'):
        for file in files:
            if file.endswith('.gd'):
                check_gdscript_blocks(os.path.join(root, file))

