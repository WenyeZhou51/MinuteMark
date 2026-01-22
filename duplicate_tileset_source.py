import re

with open('Sprites/tileset.tres', 'r') as f:
    content = f.read()

pattern = '[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_new_tile_map"]'
start_idx = content.find(pattern)
if start_idx != -1:
    # Find the end of this sub_resource (next [sub_resource or [resource])
    next_sub = content.find('[sub_resource', start_idx + 1)
    next_res = content.find('[resource]', start_idx + 1)
    
    end_idx = next_sub if next_sub != -1 and (next_res == -1 or next_sub < next_res) else next_res
    
    block = content[start_idx:end_idx]
    new_block = block.replace('TileSetAtlasSource_new_tile_map', 'TileSetAtlasSource_tilemap1')
    new_block = new_block.replace('ExtResource("3_new_tile_map")', 'ExtResource("4_tilemap1")')
    
    # Insert before [resource]
    insertion_point = content.find('[resource]')
    new_content = content[:insertion_point] + new_block + '\n' + content[insertion_point:]
    
    with open('Sprites/tileset.tres', 'w') as f:
        f.write(new_content)
    print('Successfully added TileSetAtlasSource_tilemap1')
else:
    print('Could not find TileSetAtlasSource_new_tile_map')

