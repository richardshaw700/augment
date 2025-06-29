"""
Provides context for UI events by mapping coordinates to UI elements from a snapshot.
"""
import re
from typing import Optional, Dict, Tuple

class Contextualizer:
    """
    Parses a compressed UI snapshot and provides methods to find UI elements
    based on screen coordinates.
    """
    def __init__(self):
        self.window_frame: Optional[Dict[str, int]] = None
        self.element_map: Dict[str, str] = {}
        print("✅ Contextualizer initialized.")

    def update_ui_map(self, ui_map: dict):
        """
        Parses the full UI map dictionary to build an internal map of elements.
        """
        print("\n[CTX-TRACE] ----------------------------------------------------")
        print(f"[CTX-TRACE] Updating UI map with new dictionary data...")
        self.element_map = {}
        self.window_frame = None

        # Extract window frame and compressed output from the dictionary
        # Handle both legacy format (windowFrame) and new format (window.frame)
        if "windowFrame" in ui_map:
            self.window_frame = ui_map["windowFrame"]
        elif "window" in ui_map and "frame" in ui_map["window"]:
            self.window_frame = ui_map["window"]["frame"]
        
        compressed_ui = ui_map.get("compressedOutput", "")

        if not self.window_frame or not compressed_ui:
            print(f"  [CTX-ERROR] UI map dictionary is missing window frame or compressedOutput.")
            print(f"  [CTX-DEBUG] Available keys: {list(ui_map.keys())}")
            if "window" in ui_map:
                print(f"  [CTX-DEBUG] Window keys: {list(ui_map['window'].keys())}")
            print("[CTX-TRACE] ----------------------------------------------------\n")
            return
            
        print(f"  [CTX-TRACE] Parsed window frame: {self.window_frame}")

        # Parse elements from the compressed string
        element_string = compressed_ui.split('|')[-1]
        elements = element_string.split(',')
        
        for element in elements:
            if '@' in element:
                try:
                    desc, grid_id = element.rsplit('@', 1)
                    self.element_map[grid_id.strip()] = element.strip()
                except ValueError:
                    continue # Skip malformed element strings

        print(f"  [CTX-TRACE] UI map updated. Total elements parsed: {len(self.element_map)}")
        if self.element_map:
            first_key = next(iter(self.element_map))
            print(f"  [CTX-TRACE] Sanity check, first element: '{self.element_map[first_key]}'")
        print("[CTX-TRACE] ----------------------------------------------------\n")

    def _coordinates_to_grid(self, x: int, y: int) -> Optional[str]:
        """
        Converts absolute screen coordinates to percentage coordinates (e.g., "24:11").
        This is the reverse of the logic in gpt_computer_use.py.
        """
        if not self.window_frame:
            print("  [CTX-ERROR] No window frame data available. Cannot map coordinates.")
            return None
            
        print(f"  [CTX-TRACE] Attempting to map coordinates ({x}, {y})")
        print(f"  [CTX-TRACE] Using window frame: {self.window_frame}")

        # The coordinates from the event monitor are for the entire screen.
        # We need to convert screen coordinates to window-relative coordinates.
        window_x, window_y = self.window_frame['x'], self.window_frame['y']
        window_width, window_height = self.window_frame['width'], self.window_frame['height']

        # Check if coordinates are within the window bounds
        if not (window_x <= x < window_x + window_width and
                window_y <= y < window_y + window_height):
            print(f"  [CTX-WARN] Click coordinates ({x}, {y}) are outside the window bounds.")
            print(f"  [CTX-WARN] Window bounds: x={window_x}, y={window_y}, width={window_width}, height={window_height}")
            # Continue with calculation but warn about potential inaccuracy
            pass

        # Calculate window-relative coordinates
        relative_x = x - window_x
        relative_y = y - window_y
        print(f"  [CTX-TRACE] Window-relative coordinates: ({relative_x}, {relative_y})")
        
        # Handle edge cases where window dimensions might be zero
        if window_width <= 0 or window_height <= 0:
            print(f"  [CTX-ERROR] Invalid window dimensions: width={window_width}, height={window_height}")
            return None
            
        if relative_x < 0 or relative_y < 0:
            print(f"  [CTX-WARN] Negative relative coordinates: ({relative_x}, {relative_y})")
        
        # Convert to percentages (0-100)
        x_percent = int((relative_x / window_width) * 100)
        y_percent = int((relative_y / window_height) * 100)
        
        # Clamp values to be within 0-100 range
        original_x_percent, original_y_percent = x_percent, y_percent
        x_percent = max(0, min(x_percent, 100))
        y_percent = max(0, min(y_percent, 100))
        
        if original_x_percent != x_percent or original_y_percent != y_percent:
            print(f"  [CTX-TRACE] Clamped percentages: ({original_x_percent}, {original_y_percent}) -> ({x_percent}, {y_percent})")

        # Convert to percentage coordinate string
        coord_id = f"{x_percent}:{y_percent}"
        print(f"  [CTX-TRACE] Final Coordinate ID: {coord_id}")
        return coord_id

    def find_element_at_coordinates(self, x: int, y: int) -> Optional[str]:
        """
        Finds the full element description for a given (x, y) coordinate.
        """
        print(f"\n[CTX-TRACE] Finding element at ({x}, {y})...")
        coord_id = self._coordinates_to_grid(x, y)
        if coord_id:
            print(f"  [CTX-TRACE] Lookup using Coordinate ID: '{coord_id}'. Map size: {len(self.element_map)} elements.")
            
            # Debug: Show some sample coordinate IDs from the map
            if self.element_map:
                sample_keys = list(self.element_map.keys())[:5]
                print(f"  [CTX-DEBUG] Sample coordinate IDs in map: {sample_keys}")
            
            element = self.element_map.get(coord_id)
            if element:
                print(f"  [CTX-SUCCESS] Found exact element: '{element}'")
                return element
            else:
                print(f"  [CTX-INFO] No exact element found for Coordinate ID '{coord_id}' - trying nearest neighbor...")
                print(f"  [CTX-INFO] Note: Element might have been deduplicated by compression - this is normal behavior")
                
                # Try to find nearby elements and return the closest one
                target_x, target_y = coord_id.split(':')
                target_x, target_y = int(target_x), int(target_y)
                nearby_elements = []
                
                for key in self.element_map.keys():
                    if ':' in key:
                        try:
                            x_percent, y_percent = key.split(':')
                            x_percent, y_percent = int(x_percent), int(y_percent)
                            distance = abs(x_percent - target_x) + abs(y_percent - target_y)
                            if distance <= 10:  # Search within 10% radius
                                nearby_elements.append((key, distance, self.element_map[key]))
                        except:
                            continue
                
                if nearby_elements:
                    nearby_elements.sort(key=lambda x: x[1])
                    closest_key, closest_distance, closest_element = nearby_elements[0]
                    
                    # Be more lenient with distance due to compression
                    if closest_distance <= 8:
                        print(f"  [CTX-SUCCESS] Found nearest element (compression-aware): '{closest_element}' at {closest_key} (distance: {closest_distance}%)")
                        return closest_element
                    else:
                        print(f"  [CTX-DEBUG] Closest element: {closest_key} (distance: {closest_distance}%) - potentially compressed")
                        closest = nearby_elements[:3]
                        print(f"  [CTX-DEBUG] Nearby elements: {[f'{key} (dist={dist}%)' for key, dist, _ in closest]}")
                else:
                    print(f"  [CTX-DEBUG] No nearby elements found within 10% radius")
                    print(f"  [CTX-DEBUG] This may indicate the element was compressed or deduplicated")
        
        return None 