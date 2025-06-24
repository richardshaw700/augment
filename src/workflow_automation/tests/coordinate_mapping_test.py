#!/usr/bin/env python3
"""
Test script to debug coordinate mapping using real data from workflow recording.
This helps us understand why the coordinate-to-grid conversion isn't working correctly.
"""

import sys
from pathlib import Path

# Add the project root to the path
project_root = Path(__file__).parent.parent.parent.parent
sys.path.append(str(project_root))

from src.workflow_automation.recording.context.contextualizer import Contextualizer


def test_coordinate_mapping():
    """Test coordinate mapping with real data from workflow recording."""
    
    # Test data from actual workflow recording
    window_frame = {'x': 1012, 'width': 690, 'y': 47, 'height': 690}
    
    compressed_output = """Messages|690x690|menu:Apple@M-M1,menu:Messages@M-M2,menu:File@M-M3,menu:Edit@M-M4,menu:View@M-M5,menu:Conversa@M-M6,menu:Format@M-M7,menu:Window@M-M8,menu:Help@M-M9,btn:Compose@A-17:3,btn:Notify Anyway@A-30:45,btn:Apps@A-21:48,btn:Record audio@A-36:48,btn:Send failure (action)@A-39:1,btn:Conversation Details@A-39:3,btn:Emoji picker@A-39:48,dropdown:PopUpButton (menu)@A-22:2,txtinp:Search (search)@A-14:5[UNFOCUSED],txtinp:Message (text)@A-27:48[FOCUSED],txt:TextContent@A-14:39,txt:TextContent@A-12:38,txt:TextContent@A-15:28,txt:TextContent@A-16:34,txt:TextContent@A-34:44,txt:TextContent@A-10:19,txt:TextContent@A-11:35,txt:You unsent a message@A-11:48,txt:TextContent@A-18:14,txt:Jen loved an image@A-10:29,txt:Julia Shaw@A-10:32,txt:Richard Shaw@A-10:9,txt:Sorry, butt call A@A-12:43,txt:To: Richard Shaw@A-28:3,txt:Notify Anyway@A-33:45,txt:es@A-35:8,txt:el@A-38:18,txt:el@A-38:26,txt:Hello!@A-39:32,txt:Hello@A-39:40,txt:Delivered Quietly@A-39:42,txt:message@A-39:8,txt:Cara Davidson@A-8:13,txt:Parker Place@A-8:37,txt:Cara & Mom@A-9:18,txt:Hitzel Cruz@A-9:42,txt:Yesterday@A-17:47,txt:Yesterday@A-18:42,txt:iMessage@A-26:49,txt:ello@A-39:11,txt:ello@A-39:13,txt:ello@A-39:34,txt:earC@A-5:6,txt:Hello@A-6:10,txt:Sent@A-6:24,txt:Mom@A-7:46"""
    
    # Coordinates from actual clicks
    test_coordinates = [
        (1509, 707, "Text input area - probably A-27:48"),
        (1203, 111, "Search area - probably A-14:5"),
        (1304, 115, "Unknown area"),
        (1657, 581, "Right side of window"),
        (1496, 705, "Near text input area"),
    ]
    
    print("🧪 COORDINATE MAPPING TEST")
    print("=" * 60)
    print(f"Window frame: {window_frame}")
    print(f"Grid dimensions: 40 columns × 50 rows")
    print(f"Cell size: {window_frame['width']/40:.2f} × {window_frame['height']/50:.2f}")
    print()
    
    # Create test UI map
    ui_map = {
        "window": {"frame": window_frame},
        "compressedOutput": compressed_output
    }
    
    # Initialize contextualizer
    contextualizer = Contextualizer()
    contextualizer.update_ui_map(ui_map)
    
    print("📊 ANALYSIS OF ACTUAL UI ELEMENTS")
    print("-" * 40)
    
    # Analyze the actual grid coordinates in the compressed output
    a_elements = []
    for element in compressed_output.split(','):
        if '@A-' in element:
            grid_id = element.split('@A-')[1].split('[')[0]  # Remove focus indicators
            a_elements.append(grid_id)
    
    print(f"Found {len(a_elements)} A- grid elements:")
    
    # Find min/max coordinates
    cols, rows = [], []
    for grid_id in a_elements:
        try:
            col, row = grid_id.split(':')
            cols.append(int(col))
            rows.append(int(row))
        except:
            continue
    
    if cols and rows:
        print(f"Column range: {min(cols)} to {max(cols)} (max possible: 40)")
        print(f"Row range: {min(rows)} to {max(rows)} (max possible: 50)")
        print()
    
    # Show some key elements for reference
    key_elements = ['txtinp:Message (text)@A-27:48[FOCUSED]', 'txtinp:Search (search)@A-14:5[UNFOCUSED]', 'btn:Emoji picker@A-39:48']
    print("Key UI elements:")
    for element in key_elements:
        if any(element.split('@')[0] in comp_elem for comp_elem in compressed_output.split(',')):
            print(f"  {element}")
    print()
    
    print("🎯 TESTING COORDINATE MAPPINGS")
    print("-" * 40)
    
    for i, (x, y, description) in enumerate(test_coordinates, 1):
        print(f"\nTest {i}: {description}")
        print(f"Screen coordinates: ({x}, {y})")
        
        # Calculate window-relative coordinates manually
        rel_x = x - window_frame['x']
        rel_y = y - window_frame['y']
        print(f"Window-relative: ({rel_x}, {rel_y})")
        
        # Calculate grid position manually
        cell_width = window_frame['width'] / 40
        cell_height = window_frame['height'] / 50
        col_index = int(rel_x / cell_width)
        row_index = int(rel_y / cell_height)
        grid_id = f"A-{col_index + 1}:{row_index + 1}"
        print(f"Calculated grid: {grid_id}")
        
        # Test the contextualizer
        element = contextualizer.find_element_at_coordinates(x, y)
        if element:
            print(f"✅ Found element: {element}")
        else:
            print(f"❌ No element found")
            
            # Find closest actual elements
            closest_elements = []
            target_col, target_row = col_index + 1, row_index + 1
            
            for actual_grid in a_elements:
                try:
                    actual_col, actual_row = actual_grid.split(':')
                    actual_col, actual_row = int(actual_col), int(actual_row)
                    distance = abs(actual_col - target_col) + abs(actual_row - target_row)
                    if distance <= 3:
                        closest_elements.append((actual_grid, distance))
                except:
                    continue
            
            if closest_elements:
                closest_elements.sort(key=lambda x: x[1])
                print(f"🔍 Closest elements: {closest_elements[:3]}")
        
        print("-" * 30)
    
    print("\n🔍 COORDINATE OFFSET ANALYSIS")
    print("-" * 50)
    
    # Analyze the consistent offset pattern
    print("Analyzing coordinate discrepancies:")
    offset_data = [
        ((1509, 707), 'A-29:48', 'A-27:48'),  # Off by 2 columns
        ((1203, 111), 'A-12:5', 'A-14:5'),   # Off by 2 columns  
        ((1304, 115), 'A-17:5', 'A-17:3'),   # Same column, off by 2 rows
    ]
    
    col_offsets = []
    row_offsets = []
    
    for (x, y), calculated, actual in offset_data:
        calc_col, calc_row = calculated.split('-')[1].split(':')
        actual_col, actual_row = actual.split('-')[1].split(':')
        calc_col, calc_row = int(calc_col), int(calc_row)
        actual_col, actual_row = int(actual_col), int(actual_row)
        
        col_offset = actual_col - calc_col
        row_offset = actual_row - calc_row
        col_offsets.append(col_offset)
        row_offsets.append(row_offset)
        
        print(f"  {calculated} → {actual}: col offset {col_offset:+d}, row offset {row_offset:+d}")
    
    avg_col_offset = sum(col_offsets) / len(col_offsets)
    avg_row_offset = sum(row_offsets) / len(row_offsets)
    
    print(f"\nAverage offsets: columns {avg_col_offset:+.1f}, rows {avg_row_offset:+.1f}")
    print("This suggests we need to adjust our coordinate calculation!")

    print("\n🔍 REVERSE ANALYSIS - FIND ACTUAL COORDINATES")
    print("-" * 50)
    
    # Test reverse: given known grid positions, what are their pixel coordinates?
    known_elements = [
        ('A-27:48', 'txtinp:Message (text) - should be near (1509, 707)'),
        ('A-14:5', 'txtinp:Search - should be near (1203, 111)'),
        ('A-39:48', 'btn:Emoji picker - should be near bottom right'),
    ]
    
    for grid_id, description in known_elements:
        print(f"\n{description}")
        print(f"Grid ID: {grid_id}")
        
        # Calculate expected pixel coordinates
        try:
            col, row = grid_id.split('-')[1].split(':')
            col, row = int(col), int(row)
            
            # Convert to 0-based indices
            col_index = col - 1
            row_index = row - 1
            
            # Calculate center of grid cell
            cell_width = window_frame['width'] / 40
            cell_height = window_frame['height'] / 50
            
            # Window-relative coordinates
            rel_x = (col_index * cell_width) + (cell_width / 2)
            rel_y = (row_index * cell_height) + (cell_height / 2)
            
            # Screen coordinates
            screen_x = window_frame['x'] + rel_x
            screen_y = window_frame['y'] + rel_y
            
            print(f"Expected screen coordinates: ({screen_x:.1f}, {screen_y:.1f})")
            print(f"Grid cell center (relative): ({rel_x:.1f}, {rel_y:.1f})")
            
        except Exception as e:
            print(f"Error calculating coordinates: {e}")


if __name__ == "__main__":
    test_coordinate_mapping()