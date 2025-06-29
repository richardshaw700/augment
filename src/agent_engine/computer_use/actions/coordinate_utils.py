"""
Coordinate conversion utilities
"""

from typing import Dict, Tuple


class CoordinateUtils:
    """Utilities for coordinate conversions between grid and screen positions"""
    
    @staticmethod
    def grid_to_coordinates(grid_position: str, window_frame: Dict) -> Tuple[int, int]:
        """
        Convert coordinate position (e.g., "66:21", "15:29") to screen coordinates (CENTER POINTS)
        
        COORDINATE SYSTEM: X:Y where X and Y are percentages
        - X = percentage along width (66 = 66% from left edge)  
        - Y = percentage along height (21 = 21% from top edge)
        
        Returns center point coordinates for optimal clicking accuracy.
        """
        grid_position = grid_position.strip()
        
        # Handle the coordinate format: X:Y where X and Y are percentages
        if ":" in grid_position:
            try:
                x_percent, y_percent = map(int, grid_position.split(":"))
                
                # Get window dimensions
                window_x = window_frame.get('x', 0)
                window_y = window_frame.get('y', 0)
                window_width = window_frame.get('width', 1440)
                window_height = window_frame.get('height', 900)
                
                # Convert percentage coordinates to screen coordinates
                # X and Y are percentages of the window dimensions
                x = window_x + (x_percent * window_width / 100)
                y = window_y + (y_percent * window_height / 100)
                
                print(f"🎯 Coordinate conversion: {grid_position} -> window({window_x},{window_y},{window_width}x{window_height}) -> screen({int(x)},{int(y)})")
                
                return (int(x), int(y))
            except ValueError:
                pass
        
        # Fallback - return center of window
        window_x = window_frame.get('x', 0)
        window_y = window_frame.get('y', 0)
        window_width = window_frame.get('width', 1440)
        window_height = window_frame.get('height', 900)
        
        center_x = window_x + (window_width / 2)
        center_y = window_y + (window_height / 2)
        
        return (int(center_x), int(center_y))
    
    @staticmethod
    def pixel_to_grid(x: float, y: float, window_frame: Dict) -> str:
        """Convert pixel coordinates (CENTER POINTS) to percentage coordinates (X:Y)"""
        window_x = window_frame.get("x", 0)
        window_y = window_frame.get("y", 0)
        window_width = window_frame.get("width", 1440)
        window_height = window_frame.get("height", 900)
        
        # Convert to window-relative coordinates
        rel_x = x - window_x
        rel_y = y - window_y
        
        # Convert to percentages (0-100)
        x_percent = min(100, max(0, int(rel_x / window_width * 100)))
        y_percent = min(100, max(0, int(rel_y / window_height * 100)))
        
        return f"{x_percent}:{y_percent}"