"""
UI state formatting for LLM consumption
"""

import json
from pathlib import Path
from datetime import datetime
from typing import Dict, Any

from ..actions.coordinate_utils import CoordinateUtils


class UIFormatter:
    """Formats UI state data for LLM consumption"""
    
    def __init__(self):
        # Set up debug logging path
        project_root = Path(__file__).parent.parent.parent.parent.parent
        self.debug_file = project_root / "src" / "debug_output" / "agent_ui_input.txt"
        
        # Ensure debug output directory exists
        self.debug_file.parent.mkdir(parents=True, exist_ok=True)
    
    def format_ui_state_for_llm(self, ui_state: Dict[str, Any]) -> str:
        """Format UI state data for LLM consumption using compressed output only"""
        if "error" in ui_state:
            return f"UI Inspector Error: {ui_state['error']}"
        
        # Use the compressed output which includes focus indicators
        if "compressedOutput" in ui_state:
            compressed = ui_state["compressedOutput"]
            
            # Simply return the compressed output with a brief explanation
            formatted_ui = f"UI Elements (text inputs ending with [FOCUSED] are ready for typing, [UNFOCUSED] must be clicked first):\n{compressed}"
            
            # Debug log: Save what the Agent actually sees
            self._log_llm_ui_input(formatted_ui)
            
            return formatted_ui
        
        # Fallback to old method if no compressed output available
        return self._format_ui_state_legacy(ui_state)
    
    def _format_ui_state_legacy(self, ui_state: Dict[str, Any]) -> str:
        """Legacy UI state formatting (fallback method)"""
        summary = []
        
        # Get window frame for grid coordinate calculation
        window_frame = ui_state.get("window", {}).get("frame", {})
        window_width = window_frame.get("width", 1000)
        window_height = window_frame.get("height", 800)
        
        if "summary" in ui_state:
            summary_data = ui_state["summary"]
            if "clickableElements" in summary_data:
                clickable = summary_data["clickableElements"]
                summary.append(f"Found {len(clickable)} clickable elements:")
                for i, element in enumerate(clickable[:15]):
                    pos = element.get("position", {})
                    x, y = pos.get("x", 0), pos.get("y", 0)
                    text = element.get("visualText", element.get("semanticMeaning", ""))
                    element_type = element.get("type", "unknown")
                    
                    # Calculate grid position from pixel coordinates
                    grid_position = CoordinateUtils.pixel_to_grid(x, y, window_frame)
                    
                    # Format element with grid coordinate
                    if text and text.strip():
                        summary.append(f"  {i+1}. {element_type}@{grid_position}: {text[:50]}")
                    else:
                        summary.append(f"  {i+1}. {element_type}@{grid_position}")
        
        if "elements" in ui_state:
            elements = ui_state["elements"]
            summary.append(f"\nTotal UI elements detected: {len(elements)}")
            summary.append(f"Window size: {int(window_width)}x{int(window_height)}")
        
        return "\n".join(summary) if summary else json.dumps(ui_state, indent=2)
    
    def _log_llm_ui_input(self, formatted_ui: str):
        """Log the exact UI state that gets sent to LLM for debugging"""
        try:
            timestamp = datetime.now().strftime("%H:%M:%S.%f")[:-3]
            with open(self.debug_file, "a") as f:
                f.write(f"\n[{timestamp}] AGENT UI INPUT:\n")
                f.write("=" * 50 + "\n")
                f.write(formatted_ui)
                f.write("\n" + "=" * 50 + "\n")
        except Exception as e:
            print(f"⚠️ Failed to log Agent UI input: {e}")