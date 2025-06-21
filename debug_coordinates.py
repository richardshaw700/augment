#!/usr/bin/env python3

# Debug script to understand coordinate mapping
import sys
import os
sys.path.append(os.path.join(os.path.dirname(__file__), 'src'))

from gpt_engine.gpt_computer_use import GPTComputerUse

def debug_coordinates():
    # Create a GPT instance to access coordinate mapping
    gpt = GPTComputerUse()
    
    # Simulate Safari window frame (from the UI logs: Safari|789x671)
    window_frame = {
        'x': 100,      # Assume Safari is at x=100
        'y': 100,      # Assume Safari is at y=100 (below menu bar)
        'width': 789,  # From the logs
        'height': 671  # From the logs
    }
    
    print("🔍 COORDINATE MAPPING DEBUG")
    print("=" * 50)
    print(f"Window frame: {window_frame}")
    print()
    
    # Test the coordinates we've seen in the logs
    test_coordinates = [
        "M3",     # File menu (what GPT is trying to click)
        "M-M3",   # File menu (new format)
        "U3",     # URL field (old format)
        "A-R3",   # URL field (new format)
        "S3",     # System menu item (old format)
        "M-S3"    # System menu item (new format)
    ]
    
    for coord in test_coordinates:
        try:
            x, y = gpt._grid_to_coordinates(coord, window_frame)
            print(f"{coord:8} -> ({x:4}, {y:3})")
            
            # Analyze where this coordinate lands
            if y <= 24:
                print(f"         -> MENU BAR (y={y} <= 24)")
            elif 100 <= x <= 889 and 100 <= y <= 771:  # Within Safari window
                print(f"         -> SAFARI WINDOW")
            else:
                print(f"         -> OUTSIDE SAFARI WINDOW")
            print()
        except Exception as e:
            print(f"{coord:8} -> ERROR: {e}")
            print()

if __name__ == "__main__":
    debug_coordinates() 