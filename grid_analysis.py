#!/usr/bin/env python3
"""
Analyze grid coordinates from Messages app compressed UI output
"""

import re
from collections import defaultdict

# Compressed UI output
compressed_output = """Messages|690x690|menu:Apple@M-M1,menu:Messages@M-M2,menu:File@M-M3,menu:Edit@M-M4,menu:View@M-M5,menu:Conversa@M-M6,menu:Format@M-M7,menu:Window@M-M8,menu:Help@M-M9,btn:Compose@A-17:3,btn:Notify Anyway@A-30:45,btn:Apps@A-21:48,btn:Record audio@A-36:48,btn:Send failure (action)@A-39:1,btn:Conversation Details@A-39:3,btn:Emoji picker@A-39:48,dropdown:PopUpButton (menu)@A-22:2,txtinp:Search (search)@A-14:5[UNFOCUSED],txtinp:Message (text)@A-27:48[FOCUSED],txt:TextContent@A-14:39,txt:TextContent@A-12:38,txt:TextContent@A-15:28,txt:TextContent@A-16:34,txt:TextContent@A-34:44,txt:TextContent@A-10:19,txt:TextContent@A-11:35,txt:You unsent a message@A-11:48,txt:TextContent@A-18:14,txt:Jen loved an image@A-10:29,txt:Julia Shaw@A-10:32,txt:Richard Shaw@A-10:9,txt:Sorry, butt call A@A-12:43,txt:To: Richard Shaw@A-28:3,txt:Notify Anyway@A-33:45,txt:es@A-35:8,txt:el@A-38:18,txt:el@A-38:26,txt:Hello!@A-39:32,txt:Hello@A-39:40,txt:Delivered Quietly@A-39:42,txt:message@A-39:8,txt:Cara Davidson@A-8:13,txt:Parker Place@A-8:37,txt:Cara & Mom@A-9:18,txt:Hitzel Cruz@A-9:42,txt:Yesterday@A-17:47,txt:Yesterday@A-18:42,txt:iMessage@A-26:49,txt:ello@A-39:11,txt:ello@A-39:13,txt:ello@A-39:34,txt:earC@A-5:6,txt:Hello@A-6:10,txt:Sent@A-6:24,txt:Mom@A-7:46"""

def extract_grid_coordinates():
    """Extract all A- grid coordinates from the compressed output"""
    # Find all A-row:col patterns
    pattern = r'A-(\d+):(\d+)'
    matches = re.findall(pattern, compressed_output)
    
    coordinates = []
    for row, col in matches:
        coordinates.append((int(row), int(col)))
    
    return coordinates

def analyze_grid_pattern(coordinates):
    """Analyze the grid coordinate pattern"""
    rows = [coord[0] for coord in coordinates]
    cols = [coord[1] for coord in coordinates]
    
    min_row, max_row = min(rows), max(rows)
    min_col, max_col = min(cols), max(cols)
    
    print(f"Grid Analysis:")
    print(f"Row range: {min_row} to {max_row} (span: {max_row - min_row + 1})")
    print(f"Col range: {min_col} to {max_col} (span: {max_col - min_col + 1})")
    print(f"Total unique coordinates: {len(set(coordinates))}")
    
    # Group by rows and columns to see distribution
    row_counts = defaultdict(int)
    col_counts = defaultdict(int)
    
    for row, col in coordinates:
        row_counts[row] += 1
        col_counts[col] += 1
    
    print(f"\nRow distribution (top 10):")
    for row in sorted(row_counts.keys())[:10]:
        print(f"  Row {row}: {row_counts[row]} elements")
    
    print(f"\nColumn distribution (top 10):")
    for col in sorted(col_counts.keys())[:10]:
        print(f"  Col {col}: {col_counts[col]} elements")
    
    return min_row, max_row, min_col, max_col

def analyze_click_mapping():
    """Analyze the click coordinate mapping issue"""
    window_frame = {'x': 1012, 'width': 690, 'y': 47, 'height': 690}
    
    # Click data from logs
    clicks = [
        {'screen': (1686, 635), 'mapped': (40, 43), 'nearby': (39, 42)},
        {'screen': (1509, 707), 'mapped': (29, 48), 'nearby': None},
        {'screen': (1657, 581), 'mapped': (38, 39), 'nearby': (39, 40)}
    ]
    
    print(f"\nClick Mapping Analysis:")
    print(f"Window: {window_frame}")
    
    for i, click in enumerate(clicks, 1):
        screen_x, screen_y = click['screen']
        mapped_row, mapped_col = click['mapped']
        
        # Calculate relative position within window
        rel_x = screen_x - window_frame['x']
        rel_y = screen_y - window_frame['y']
        
        # Calculate expected grid position (assuming 50x50 grid)
        expected_col = int(rel_x * 50 / window_frame['width'])
        expected_row = int(rel_y * 50 / window_frame['height'])
        
        print(f"\nClick {i}:")
        print(f"  Screen: ({screen_x}, {screen_y})")
        print(f"  Relative: ({rel_x}, {rel_y})")
        print(f"  Mapped: A-{mapped_row}:{mapped_col}")
        print(f"  Expected (50x50): A-{expected_row}:{expected_col}")
        print(f"  Nearby element: {click['nearby']}")
        
        # Check if coordinates are within window
        if rel_x < 0 or rel_x > window_frame['width'] or rel_y < 0 or rel_y > window_frame['height']:
            print(f"  ⚠️  Click is OUTSIDE window bounds!")

def main():
    print("Messages App Grid Coordinate Analysis")
    print("=" * 50)
    
    # Extract coordinates
    coordinates = extract_grid_coordinates()
    print(f"Found {len(coordinates)} grid coordinates")
    
    # Analyze pattern
    min_row, max_row, min_col, max_col = analyze_grid_pattern(coordinates)
    
    # Analyze click mapping
    analyze_click_mapping()
    
    # Identify potential issues
    print(f"\nPotential Issues:")
    
    # Check if grid size assumptions are correct
    print(f"1. Grid size assumptions:")
    print(f"   - Actual max row: {max_row}, max col: {max_col}")
    print(f"   - If using 50x50 grid, we'd expect max ~49:49")
    print(f"   - Grid appears to be at least {max_row+1}x{max_col+1}")
    
    # Check coordinate system
    print(f"\n2. Coordinate system:")
    print(f"   - UI coordinates start from A-{min_row}:{min_col}")
    print(f"   - This suggests grid might not be 0-indexed or has different origin")
    
    # Show some example coordinates for comparison
    print(f"\n3. Sample coordinates from UI:")
    sample_coords = sorted(coordinates)[:10]
    for row, col in sample_coords:
        print(f"   A-{row}:{col}")

if __name__ == "__main__":
    main()