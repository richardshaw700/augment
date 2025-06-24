"""
Generates a human-readable summary of a recorded workflow session.
"""

import time
import re
from datetime import datetime
from typing import List, Dict

def generate_summary(session_id: str, workflow_name: str, start_time: float, events: List[Dict], steps: int, errors: int) -> str:
    """
    Generates a comprehensive summary report for a recording session.

    Args:
        session_id: The ID of the session.
        workflow_name: The name of the workflow.
        start_time: The timestamp when the session started.
        events: A list of all system events recorded.
        steps: Total number of workflow steps recorded.
        errors: Total number of errors encountered.

    Returns:
        A formatted string containing the session summary.
    """
    duration = time.time() - start_time
    success_rate = ((steps - errors) / max(steps, 1) * 100)

    summary = f"""
================================================================================
SESSION SUMMARY
================================================================================
Workflow Name: {workflow_name}
Session ID: {session_id}
Session Duration: {duration:.2f} seconds
Total System Events: {len(events)}
Total Workflow Steps: {steps}
Total Errors: {errors}
Success Rate: {success_rate:.1f}%
End Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
================================================================================
"""
    if events:
        summary += "\n" + _generate_human_readable_timeline(events)
        summary += "\n" + _generate_action_blueprint(events)
    
    return summary

def _generate_human_readable_timeline(events: List[Dict]) -> str:
    """Creates a user-friendly timeline of events."""
    timeline = "EVENT TIMELINE\n" + "-" * 80 + "\n"
    
    # Group consecutive keyboard events before formatting
    grouped_events = _group_consecutive_keys(events)
    
    step_number = 1
    for group in grouped_events:
        formatted_event = _format_event_group(group, step_number)
        if formatted_event:  # Only add non-empty events and increment step number
            timeline += formatted_event
            step_number += 1
        
    return timeline

def _group_consecutive_keys(events: List[Dict]) -> List[List[Dict]]:
    """Groups consecutive keyboard events intelligently - group all typing until interrupted by clicks or app changes."""
    if not events:
        return []

    grouped = []
    current_group = []

    for i, event in enumerate(events):
        is_key_event = event.get("type") == "keyboard"
        
        if is_key_event:
            key_char = event.get("key_char", "")
            current_app = event.get("app_name", "")
            
            # Check if we should break the current typing group
            should_break_group = False
            
            # Break group if app changed from previous keyboard event
            if current_group:
                last_app = current_group[-1].get("app_name", "")
                if current_app != last_app:
                    should_break_group = True
            
            # Return, tab, and escape should be separate groups
            if key_char in ["return", "tab", "escape"]:
                if current_group:
                    grouped.append(current_group)
                    current_group = []
                grouped.append([event])
                continue
            
            # If we need to break the group due to app change
            if should_break_group:
                if current_group:
                    grouped.append(current_group)
                    current_group = []
            
            # Add to current typing group
            current_group.append(event)
            
        else:
            # Non-keyboard event - check if it should break typing groups
            event_type = event.get("type")
            
            # UI inspections should NOT break typing groups
            if event_type == "ui_inspected":
                grouped.append([event])  # Add as separate event but don't break typing
                continue
            
            # Other events (click, scroll, etc.) break typing groups
            if current_group:
                grouped.append(current_group)
                current_group = []
            grouped.append([event])
            
    # Add the last group if it's not empty
    if current_group:
        grouped.append(current_group)
    
    # Now coalesce consecutive scroll events
    return _coalesce_scroll_events(grouped)

def _coalesce_scroll_events(grouped_events: List[List[Dict]]) -> List[List[Dict]]:
    """Coalesce consecutive scroll events into single scroll actions."""
    if not grouped_events:
        return []
    
    coalesced = []
    i = 0
    
    while i < len(grouped_events):
        current_group = grouped_events[i]
        
        # Check if this is a scroll event
        if (len(current_group) == 1 and 
            current_group[0].get("type") == "mouse_scroll"):
            
            # Collect consecutive scroll events in the same app
            scroll_sequence = [current_group[0]]
            app_name = current_group[0].get("app_name")
            j = i + 1
            
            # Look ahead for more scroll events in the same app within 2 seconds
            while j < len(grouped_events):
                next_group = grouped_events[j]
                if (len(next_group) == 1 and 
                    next_group[0].get("type") == "mouse_scroll" and
                    next_group[0].get("app_name") == app_name):
                    
                    # Check time gap (within 2 seconds)
                    time_gap = next_group[0].get("timestamp", 0) - scroll_sequence[-1].get("timestamp", 0)
                    if time_gap <= 2.0:
                        scroll_sequence.append(next_group[0])
                        j += 1
                    else:
                        break
                else:
                    break
            
            # If we have multiple scroll events, coalesce them
            if len(scroll_sequence) > 1:
                coalesced_event = _create_coalesced_scroll_event(scroll_sequence)
                coalesced.append([coalesced_event])
                i = j  # Skip all the consumed scroll events
            else:
                # Single scroll event, keep as is
                coalesced.append(current_group)
                i += 1
        else:
            # Not a scroll event, keep as is
            coalesced.append(current_group)
            i += 1
    
    return coalesced

def _create_coalesced_scroll_event(scroll_events: List[Dict]) -> Dict:
    """Create a single coalesced scroll event from a sequence of scroll events."""
    first_event = scroll_events[0]
    last_event = scroll_events[-1]
    
    # Calculate total delta
    total_x = sum(event.get("scroll_delta", (0, 0))[0] for event in scroll_events)
    total_y = sum(event.get("scroll_delta", (0, 0))[1] for event in scroll_events)
    
    # Determine scroll direction
    direction = _determine_scroll_direction(total_x, total_y)
    
    # Create the coalesced event
    coalesced_event = {
        "type": "mouse_scroll",
        "timestamp": first_event.get("timestamp"),
        "app_name": first_event.get("app_name"),
        "scroll_delta": (total_x, total_y),
        "description": f"Scrolled {direction} in {first_event.get('app_name', 'Unknown App')}",
        "scroll_count": len(scroll_events),
        "duration": last_event.get("timestamp", 0) - first_event.get("timestamp", 0)
    }
    
    return coalesced_event

def _determine_scroll_direction(total_x: int, total_y: int) -> str:
    """Determine the primary scroll direction from total deltas."""
    abs_x = abs(total_x)
    abs_y = abs(total_y)
    
    # Determine primary direction
    if abs_y > abs_x:
        # Vertical scrolling is dominant
        if total_y > 0:
            return "up"
        else:
            return "down"
    elif abs_x > abs_y:
        # Horizontal scrolling is dominant
        if total_x > 0:
            return "right"
        else:
            return "left"
    else:
        # Mixed or no significant scrolling
        if total_y != 0 and total_x != 0:
            y_dir = "up" if total_y > 0 else "down"
            x_dir = "right" if total_x > 0 else "left"
            return f"{y_dir} and {x_dir}"
        elif total_y != 0:
            return "up" if total_y > 0 else "down"
        elif total_x != 0:
            return "right" if total_x > 0 else "left"
        else:
            return "minimally"

def _calculate_scroll_magnitude(total_x: int, total_y: int) -> int:
    """Calculate the total magnitude of scrolling for display in actions."""
    # Use the dominant direction's magnitude
    abs_x = abs(total_x)
    abs_y = abs(total_y)
    
    # Return the larger magnitude (dominant direction)
    return max(abs_x, abs_y)

def _format_event_group(event_group: List[Dict], group_number: int) -> str:
    """Formats a group of events into a readable string."""
    first_event = event_group[0]
    event_type = first_event.get("type")  # Use 'type' from session manager
    
    # Skip UI inspection events entirely
    if event_type == "ui_inspected":
        return ""
    
    start_time = datetime.fromtimestamp(first_event.get("timestamp", 0)).strftime('%H:%M:%S')
    app_name = first_event.get("app_name", "Unknown App")  # Direct access from session manager

    line = f"[{start_time}] Step {group_number}: "

    if event_type == "mouse_click":
        coords = first_event.get("coordinates", (0, 0))
        
        # Use the enriched description if available, otherwise fall back to element_info
        enriched_description = first_event.get("description", "")
        if enriched_description and "Clicked on" in enriched_description:
            # Use the enriched description directly (it already includes "Clicked on X in Y")
            line += enriched_description.replace(f" at {coords}", "") + f" at {coords}"
        else:
            # Fallback to element_info for backwards compatibility
            element_info = first_event.get("element_info", {})
            if element_info and element_info.get("text"):
                description = element_info.get("text")
            else:
                description = "an unnamed element"
            line += f"Clicked on {description} in {app_name} at {coords}"
        
    elif event_type == "keyboard":
        # Handle keyboard events with proper backspace tracking
        if len(event_group) == 1:
            # Single keyboard event
            first_event = event_group[0]
            key_char = first_event.get("key_char", "")
            
            if key_char == "return":
                line += f"Pressed Enter in {app_name}"
            elif key_char == "tab":
                line += f"Pressed Tab in {app_name}"
            elif key_char == "escape":
                line += f"Pressed Escape in {app_name}"
            elif key_char == "space":
                line += f"Typed ' ' in {app_name}"
            else:
                line += f"Typed '{key_char}' in {app_name}"
        else:
            # Multiple events - process with backspace handling
            typed_text = _process_typing_with_backspace(event_group)
            if typed_text:  # Only show if there's actual text after processing backspaces
                line += f"Typed '{typed_text}' in {app_name}"
            else:
                # If all text was deleted, don't show anything
                return ""
        
    elif event_type == "mouse_scroll":
        # Check if this is a coalesced scroll event
        if first_event.get("scroll_count", 0) > 1:
            # This is a coalesced scroll event with a nice description
            direction = first_event.get("description", "")
            if "Scrolled" in direction:
                line += direction  # Use the pre-formatted description
            else:
                delta = first_event.get("scroll_delta", (0, 0))
                line += f"Scrolled in {app_name} by {delta}"
        else:
            # Single scroll event
            delta = first_event.get("scroll_delta", (0, 0))
            line += f"Scrolled in {app_name} by {delta}"
        
    elif event_type == "ui_inspected":
        # Show UI inspection events in timeline for debugging
        app_name = first_event.get("app_name", "Unknown App")
        line += f"UI inspection performed on {app_name}"
        
    else:
        line += f"Performed an unknown action in {app_name}"
        
    return line + "\n"

def _generate_action_blueprint(events: List[Dict]) -> str:
    """Generate a high-level action blueprint for guided automation."""
    blueprint = "\nACTION BLUEPRINT\n" + "-" * 80 + "\n"
    
    # Group consecutive keyboard events before processing
    grouped_events = _group_consecutive_keys(events)
    
    action_steps = []
    
    for group in grouped_events:
        first_event = group[0]
        event_type = first_event.get("type")
        app_name = first_event.get("app_name", "Unknown")
        
        if event_type == "mouse_click":
            # Extract target element from enriched description
            target = _extract_click_target(first_event)
            # Include all clicks - even unnamed elements can be important for automation
            # The LLM can figure out what to click based on coordinates and context
            if target and target.strip():
                action_steps.append(f"ACTION: CLICK | target={target} | app={app_name}")
            else:
                # Fallback to coordinates for unnamed elements
                coords = first_event.get("coordinates", (0, 0))
                action_steps.append(f"ACTION: CLICK | target=coords:{coords} | app={app_name}")
        
        elif event_type == "keyboard":
            # Handle different keyboard event types
            if len(group) == 1:
                # Single keyboard event
                key_char = first_event.get("key_char", "")
                if key_char == "return":
                    # Include Enter presses in blueprint - they're often intentional actions
                    action_steps.append(f"ACTION: PRESS_ENTER | app={app_name}")
                elif key_char in ["tab", "escape"]:
                    # Skip other special keys in blueprint
                    continue
            else:
                # Multiple events - extract clean typed text
                typed_text = _process_typing_with_backspace(group)
                if typed_text and typed_text.strip():
                    action_steps.append(f"ACTION: TYPE | text={typed_text} | app={app_name}")
        
        elif event_type == "mouse_scroll":
            # Include scroll events - they can be important for navigation
            delta = first_event.get("scroll_delta", (0, 0))
            if delta != (0, 0):  # Only include non-zero scrolls
                # Check if this is a coalesced scroll event
                if first_event.get("scroll_count", 0) > 1:
                    # Use direction-based description for coalesced scrolls with total magnitude
                    direction = _determine_scroll_direction(delta[0], delta[1])
                    total_magnitude = _calculate_scroll_magnitude(delta[0], delta[1])
                    action_steps.append(f"ACTION: SCROLL | direction={direction}({total_magnitude}u) | app={app_name}")
                else:
                    # Single scroll event with delta
                    action_steps.append(f"ACTION: SCROLL | delta={delta} | app={app_name}")
        
        elif event_type == "ui_inspected":
            # Skip UI inspection actions in blueprint - they're internal
            continue
    
    # Add numbered action steps
    for i, action in enumerate(action_steps, 1):
        blueprint += f"{i}. {action}\n"
    
    if not action_steps:
        blueprint += "No actionable steps detected.\n"
    
    return blueprint

def generate_action_blueprint_only(events: List[Dict]) -> List[str]:
    """Generate just the action steps list for separate blueprint saving."""
    # Group consecutive keyboard events before processing
    grouped_events = _group_consecutive_keys(events)
    
    action_steps = []
    
    for group in grouped_events:
        first_event = group[0]
        event_type = first_event.get("type")
        app_name = first_event.get("app_name", "Unknown")
        
        if event_type == "mouse_click":
            # Extract target element from enriched description
            target = _extract_click_target(first_event)
            # Include all clicks - even unnamed elements can be important for automation
            # The LLM can figure out what to click based on coordinates and context
            if target and target.strip():
                action_steps.append(f"ACTION: CLICK | target={target} | app={app_name}")
            else:
                # Fallback to coordinates for unnamed elements
                coords = first_event.get("coordinates", (0, 0))
                action_steps.append(f"ACTION: CLICK | target=coords:{coords} | app={app_name}")
        
        elif event_type == "keyboard":
            # Handle different keyboard event types
            if len(group) == 1:
                # Single keyboard event
                key_char = first_event.get("key_char", "")
                if key_char == "return":
                    # Include Enter presses in blueprint - they're often intentional actions
                    action_steps.append(f"ACTION: PRESS_ENTER | app={app_name}")
                elif key_char in ["tab", "escape"]:
                    # Skip other special keys in blueprint
                    continue
            else:
                # Multiple events - extract clean typed text
                typed_text = _process_typing_with_backspace(group)
                if typed_text and typed_text.strip():
                    action_steps.append(f"ACTION: TYPE | text={typed_text} | app={app_name}")
        
        elif event_type == "mouse_scroll":
            # Include scroll events - they can be important for navigation
            delta = first_event.get("scroll_delta", (0, 0))
            if delta != (0, 0):  # Only include non-zero scrolls
                # Check if this is a coalesced scroll event
                if first_event.get("scroll_count", 0) > 1:
                    # Use direction-based description for coalesced scrolls with total magnitude
                    direction = _determine_scroll_direction(delta[0], delta[1])
                    total_magnitude = _calculate_scroll_magnitude(delta[0], delta[1])
                    action_steps.append(f"ACTION: SCROLL | direction={direction}({total_magnitude}u) | app={app_name}")
                else:
                    # Single scroll event with delta
                    action_steps.append(f"ACTION: SCROLL | delta={delta} | app={app_name}")
        
        elif event_type == "ui_inspected":
            # Skip UI inspection actions in blueprint - they're internal
            continue
    
    return action_steps

def _extract_click_target(event: Dict) -> str:
    """Extract the target element from a click event."""
    # Try enriched description first
    enriched_description = event.get("description", "")
    if enriched_description and "Clicked on" in enriched_description:
        # Parse format: "Clicked on txt:iMessage@A-23:49 in Messages"
        target_match = re.search(r'Clicked on ([^@\s]+(?::[^@\s]*)?)', enriched_description)
        if target_match:
            target = target_match.group(1)
            # Clean up target (remove grid coordinates and focus states)
            target = re.sub(r'@.*$', '', target)  # Remove @A-23:49
            target = re.sub(r'\[.*\]', '', target)  # Remove [FOCUSED]
            
            # Handle specific problematic cases
            if target == "txt:Q":
                return "txt:Q Search"  # More descriptive
            elif target and target != "an unnamed element" and target != "an":
                return target
    
    # Fallback to element_info
    element_info = event.get("element_info", {})
    if element_info and element_info.get("text"):
        return element_info.get("text")
    
    # For unnamed elements, try to extract more context from the description
    if enriched_description:
        # Look for patterns like "Clicked on an unnamed element in Safari at (598, 259)"
        app_match = re.search(r'in (\w+)', enriched_description)
        coords_match = re.search(r'at \((\d+, \d+)\)', enriched_description)
        if app_match and coords_match:
            app = app_match.group(1)
            coords = coords_match.group(1)
            return f"element_in_{app}_at_{coords}"
    
    return "unnamed_element"

def _extract_typed_text(event_group: List[Dict]) -> str:
    """Extract typed text from a group of keyboard events."""
    if len(event_group) == 1:
        # Single event - use typed_text if available
        first_event = event_group[0]
        typed_text = first_event.get("typed_text")
        if typed_text:
            return typed_text
        
        # Fallback to key_char
        key_char = first_event.get("key_char", "")
        key_map = {
            "space": " ",
            "return": "⏎",
            "tab": "⇥", 
            "delete": "⌫",
            "escape": "⎋"
        }
        return key_map.get(key_char, key_char)
    else:
        # Multiple events - join characters
        typed_chars = []
        for event in event_group:
            key_char = event.get("key_char", "")
            key_map = {
                "space": " ",
                "return": "⏎",
                "tab": "⇥",
                "delete": "⌫", 
                "escape": "⎋"
            }
            typed_chars.append(key_map.get(key_char, key_char))
        return "".join(typed_chars)

def _process_typing_with_backspace(event_group: List[Dict]) -> str:
    """Process typing events and handle backspaces properly by removing previous characters."""
    result = []
    
    for event in event_group:
        key_char = event.get("key_char", "")
        
        if key_char == "delete":
            # Remove the last character if it exists
            if result:
                result.pop()
        elif key_char == "space":
            result.append(" ")
        elif key_char and key_char not in ["return", "tab", "escape"]:
            # Regular character
            result.append(key_char)
    
    return "".join(result) 