"""
Processes raw system events and UI state to generate workflow steps.
This module is the "brains" of the recording analysis, responsible for
correlating user actions with UI elements and inferring intent.
"""

from typing import Dict, Any, Optional, List, NamedTuple
import time

from ..models import SystemEvent, EventType, UIElement, WorkflowStep

class ProcessedEventResult(NamedTuple):
    """The result of processing a single event."""
    workflow_step: WorkflowStep
    enriched_description: str

class EventProcessor:
    """
    Analyzes system events in the context of a UI state to create
    high-level workflow steps.
    """
    def process_event(self, event: SystemEvent, ui_state: Dict[str, Any]) -> Optional[ProcessedEventResult]:
        """
        Processes a single event, generating a workflow step and description.
        This processor is now stateless and handles one event at a time.
        """
        analysis = self._analyze_single_event(event, ui_state)
        
        if not analysis:
            return None

        step = WorkflowStep(
            step_id=0,
            event_type=event.event_type,
            timestamp=event.timestamp,
            description=analysis["description"],
            data={
                "event_data": event.data,
                "target_element": analysis.get("target_element"),
                "window_info": ui_state.get("window_info", {})
            },
            action_type=analysis.get("action_type"),
        )
        
        return ProcessedEventResult(
            workflow_step=step,
            enriched_description=analysis["description"]
        )

    def _analyze_single_event(self, event: SystemEvent, ui_state: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Analyzes a single event against the given UI state."""
        if event.event_type == EventType.MOUSE_CLICK:
            return self._analyze_click_event(event, ui_state)
        elif event.event_type == EventType.KEYBOARD:
            return self._analyze_key_event(event, ui_state)
        elif event.event_type == EventType.MOUSE_SCROLL:
            return self._analyze_scroll_event(event, ui_state)
        return None

    def _analyze_click_event(self, event: SystemEvent, ui_state: Dict[str, Any]) -> Dict[str, Any]:
        """Analyzes a mouse click event."""
        coords = event.data.get("coordinates")
        element_data = self._find_element_at_coordinates(coords, ui_state)
        
        description = f"Clicked at coordinates {coords}"
        target_element_dict = None

        if element_data:
            role = element_data.get("accessibility", {}).get("role", "element")
            text = element_data.get("visualText") or element_data.get("text") or element_data.get("accessibility", {}).get("title", "")
            
            description = f"Clicked on {role}"
            if text:
                description += f" with text '{text}'"

            target_element_dict = {
                "role": role,
                "text": text,
                "coordinates": coords
            }

        return {
            "action_type": "ui_click",
            "description": description,
            "target_element": target_element_dict,
        }

    def _analyze_key_event(self, event: SystemEvent, ui_state: Dict[str, Any]) -> Dict[str, Any]:
        """Analyzes a keyboard event."""
        key_char = event.data.get("key_char", "")
        
        # Convert special key names to actual characters
        display_char = self._convert_key_to_display_char(key_char)
        description = f"Typed key '{display_char}'"

        return {
            "action_type": "keyboard_type",
            "description": description,
            "target_element": None, # TODO: Add focused element
        }
    
    def _convert_key_to_display_char(self, key_char: str) -> str:
        """Convert key names to display characters."""
        key_conversions = {
            'space': ' ',
            'return': '⏎',
            'tab': '⇥',
            'delete': '⌫',
            'escape': '⎋'
        }
        return key_conversions.get(key_char, key_char)
        
    def _analyze_scroll_event(self, event: SystemEvent, ui_state: Dict[str, Any]) -> Dict[str, Any]:
        """Analyzes a mouse scroll event."""
        delta = event.data.get("scroll_delta")
        description = f"Scrolled with delta {delta}"

        return {
            "action_type": "ui_scroll",
            "description": description,
            "target_element": None,
        }

    def _find_element_at_coordinates(self, coords: tuple, ui_state: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Finds the most likely UI element at the given screen coordinates."""
        if not coords: return None
        x, y = coords
        elements = ui_state.get("elements", [])
        
        candidate = None
        smallest_area = float('inf')

        for el in elements:
            frame = el.get("frame", {})
            ex, ey = frame.get("x", 0), frame.get("y", 0)
            ew, eh = frame.get("width", 0), frame.get("height", 0)

            if ex <= x <= ex + ew and ey <= y <= ey + eh:
                area = ew * eh
                if area < smallest_area:
                    smallest_area = area
                    candidate = el
        
        return candidate 