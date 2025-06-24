"""
Processes raw system events and UI state to generate workflow steps.
This module is the "brains" of the recording analysis, responsible for
correlating user actions with UI elements and inferring intent.
"""

from typing import Dict, Any, Optional, List, NamedTuple
import time
from dataclasses import dataclass

from ..models import SystemEvent, EventType, UIElement, WorkflowStep
from ..context.contextualizer import Contextualizer

@dataclass
class ProcessedEventResult:
    """The result of processing a single event."""
    workflow_step: WorkflowStep
    enriched_description: str

class EventProcessor:
    """
    Analyzes system events in the context of a UI state to create
    high-level workflow steps.
    """
    
    def __init__(self):
        self.contextualizer = Contextualizer()
    def process_event(
        self, event: SystemEvent, ui_state: Dict[str, Any], clicked_element: Optional[str] = None
    ) -> Optional[ProcessedEventResult]:
        """
        Processes a single event, generating a workflow step and description.
        This processor is now stateless and handles one event at a time.
        """
        analysis = self._analyze_single_event(event, ui_state, clicked_element)
        
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

    def _analyze_single_event(
        self, event: SystemEvent, ui_state: Dict[str, Any], clicked_element: Optional[str] = None
    ) -> Optional[Dict[str, Any]]:
        """Analyzes a single event against the given UI state."""
        if event.event_type == EventType.MOUSE_CLICK:
            return self._analyze_click_event(event, ui_state, clicked_element)
        elif event.event_type == EventType.KEYBOARD:
            return self._analyze_key_event(event, ui_state)
        elif event.event_type == EventType.MOUSE_SCROLL:
            return self._analyze_scroll_event(event, ui_state)
        return None

    def _analyze_click_event(
        self, event: SystemEvent, ui_state: Dict[str, Any], clicked_element: Optional[str] = None
    ) -> Dict[str, Any]:
        """Analyzes a mouse click event."""
        coords = event.data.get("coordinates")
        element_data = self._find_element_at_coordinates(coords, ui_state)
        
        app_name = event.data.get("app_name", "Unknown App")
        description = ""
        target_element_dict = None

        if clicked_element:
            description = f"Clicked on {clicked_element} in {app_name}"
            target_element_dict = {"description": clicked_element}
        elif element_data:
            role = element_data.get("accessibility", {}).get("role", "element")
            text = element_data.get("visualText") or element_data.get("text") or element_data.get("accessibility", {}).get("title", "")
            description = f"Clicked on {role}"
            if text:
                description += f" with text '{text}'"
            target_element_dict = {"role": role, "text": text, "coordinates": coords}
        else:
            # Try using the contextualizer for enhanced element identification
            contextual_element = self._find_element_with_contextualizer(coords, ui_state)
            if contextual_element:
                description = f"Clicked on {contextual_element} in {app_name}"
                target_element_dict = {"description": contextual_element, "coordinates": coords}
            else:
                description = f"Clicked on an unnamed element in {app_name} at {coords}"
        
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
    
    def _find_element_with_contextualizer(self, coords: tuple, ui_state: Dict[str, Any]) -> Optional[str]:
        """Uses the contextualizer to find and describe an element at the given coordinates."""
        if not coords:
            return None
            
        x, y = coords
        
        # Check if we have UI inspection data to update the contextualizer
        if "compressedOutput" in ui_state and "window" in ui_state:
            try:
                # Update the contextualizer with the current UI state
                self.contextualizer.update_ui_map(ui_state)
                
                # Find the element at the coordinates
                element_description = self.contextualizer.find_element_at_coordinates(x, y)
                
                if element_description:
                    # Return the raw element description directly
                    return element_description
                    
            except Exception as e:
                print(f"[CTX-ERROR] Contextualizer failed: {e}")
                return None
        
        # If contextualizer fails, try to infer element based on app and coordinate patterns
        return self._infer_element_from_context(coords, ui_state)

    def _infer_element_from_context(self, coords: tuple, ui_state: Dict[str, Any]) -> Optional[str]:
        """Infer element type based on app context and coordinate patterns."""
        if not coords:
            return None
            
        x, y = coords
        window_info = ui_state.get("window_info", {})
        app_name = window_info.get("app_name", "")
        
        # Safari-specific element inference
        if app_name.lower() == "safari":
            window_frame = ui_state.get("window", {}).get("frame", {})
            if window_frame:
                window_y = window_frame.get("y", 0)
                window_height = window_frame.get("height", 0)
                
                # Address bar is typically in the top 15% of Safari window
                address_bar_threshold = window_y + (window_height * 0.15)
                if y <= address_bar_threshold:
                    return "address_bar"
                
                # Search suggestions area (below address bar)
                suggestions_threshold = window_y + (window_height * 0.25)
                if y <= suggestions_threshold:
                    return "search_suggestion"
        
        # Messages app inference
        elif app_name.lower() == "messages":
            window_frame = ui_state.get("window", {}).get("frame", {})
            if window_frame:
                window_y = window_frame.get("y", 0)
                window_height = window_frame.get("height", 0)
                
                # Text input area is typically in bottom 20% of Messages window
                input_threshold = window_y + (window_height * 0.8)
                if y >= input_threshold:
                    return "text_input"
        
        return None 