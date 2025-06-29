"""
UI state management and caching
"""

import time
from typing import Dict, Any, Optional


class UIStateManager:
    """Manages UI state, caching, and change detection"""
    
    def __init__(self):
        self._last_ui_state = None
        self._last_ui_timestamp = 0
        self._cache_duration = 1.0  # Cache UI state for 1 second
    
    def get_last_ui_state(self) -> Optional[Dict[str, Any]]:
        """Get the last cached UI state"""
        return self._last_ui_state
    
    def set_ui_state(self, ui_state: Dict[str, Any]):
        """Set and cache a new UI state"""
        self._last_ui_state = ui_state
        self._last_ui_timestamp = time.time()
    
    def is_ui_state_fresh(self) -> bool:
        """Check if the cached UI state is still fresh"""
        return (time.time() - self._last_ui_timestamp) < self._cache_duration
    
    def extract_url_from_state(self, ui_state: Dict) -> str:
        """Extract URL from UI state compressed output"""
        compressed = ui_state.get("compressedOutput", "")
        if not compressed:
            return ""
        
        # Extract URL from format: "Safari|width x height|URL|elements..."
        parts = compressed.split("|")
        if len(parts) >= 3:
            return parts[2]
        return ""
    
    def detect_significant_change(self, new_ui_state: Dict[str, Any]) -> bool:
        """Detect if there's been a significant change in UI state"""
        if not self._last_ui_state:
            return True
        
        # Compare URLs for browser apps
        old_url = self.extract_url_from_state(self._last_ui_state)
        new_url = self.extract_url_from_state(new_ui_state)
        
        if old_url != new_url and new_url not in ["page:Safari", "", old_url]:
            return True
        
        # Compare element counts
        old_elements = len(self._last_ui_state.get("elements", []))
        new_elements = len(new_ui_state.get("elements", []))
        
        element_change_ratio = abs(new_elements - old_elements) / max(old_elements, 1)
        if element_change_ratio > 0.3 and new_elements > 20:  # 30% change + meaningful content
            return True
        
        return False
    
    def clear_cache(self):
        """Clear the UI state cache"""
        self._last_ui_state = None
        self._last_ui_timestamp = 0