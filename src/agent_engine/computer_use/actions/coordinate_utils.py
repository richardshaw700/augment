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
        import pyautogui
        from datetime import datetime
        
        grid_position = grid_position.strip()
        
        # Get screen dimensions for aspect ratio calculation
        screen_width, screen_height = pyautogui.size()
        screen_aspect = screen_width / screen_height
        
        # Handle the coordinate format: X:Y where X and Y are percentages
        if ":" in grid_position:
            try:
                x_percent, y_percent = map(int, grid_position.split(":"))
                
                # Get window dimensions
                window_x = window_frame.get('x', 0)
                window_y = window_frame.get('y', 0)
                window_width = window_frame.get('width', 1440)
                window_height = window_frame.get('height', 900)
                
                # Calculate window aspect ratio
                window_aspect = window_width / window_height
                
                # Convert percentage coordinates to screen coordinates
                # X and Y are percentages of the window dimensions
                x_pixels = x_percent * window_width / 100
                y_pixels = y_percent * window_height / 100
                x = window_x + x_pixels
                y = window_y + y_pixels
                
                # Comprehensive debug logging
                debug_info = f"""
🎯 COORDINATE CONVERSION DEBUG - {datetime.now().strftime('%H:%M:%S.%f')[:-3]}
==================================================================
Input Grid Position: {grid_position} ({x_percent}% width, {y_percent}% height)
Window Frame: x={window_x}, y={window_y}, width={window_width}, height={window_height}
Window Offset: ({window_x}, {window_y})
Window Aspect Ratio: {window_aspect:.3f} ({window_width}x{window_height})
Screen Dimensions: {screen_width}x{screen_height}
Screen Aspect Ratio: {screen_aspect:.3f}
Calculations:
  x_pixels = {x_percent}% * {window_width} / 100 = {x_pixels:.1f}px
  y_pixels = {y_percent}% * {window_height} / 100 = {y_pixels:.1f}px
  final_x = {window_x} + {x_pixels:.1f} = {x:.1f}
  final_y = {window_y} + {y_pixels:.1f} = {y:.1f}
Final Screen Coordinates: ({int(x)}, {int(y)})
Window Bounds Check: x in [{window_x}, {window_x + window_width}], y in [{window_y}, {window_y + window_height}]
Click Inside Window: {window_x <= x <= window_x + window_width and window_y <= y <= window_y + window_height}
==================================================================
"""
                print(debug_info)
                
                # Also write to debug file
                try:
                    with open("src/debug_output/swift_frontend.txt", "a") as f:
                        f.write(debug_info + "\n")
                except Exception as e:
                    print(f"⚠️ Failed to write coordinate debug to file: {e}")
                
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