"""
Generates a human-readable summary of a recorded workflow session.
"""

import time
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
    
    return summary

def _generate_human_readable_timeline(events: List[Dict]) -> str:
    """Creates a user-friendly timeline of events."""
    timeline = "EVENT TIMELINE\n" + "-" * 80 + "\n"
    
    # Group consecutive keyboard events before formatting
    grouped_events = _group_consecutive_keys(events)
    
    for i, group in enumerate(grouped_events):
        timeline += _format_event_group(group, i + 1)
        
    return timeline

def _group_consecutive_keys(events: List[Dict]) -> List[List[Dict]]:
    """Groups consecutive keyboard events into a single 'typing' event."""
    if not events:
        return []

    grouped = []
    current_group = []

    for event in events:
        # Check for the 'keyboard' event type (use 'type' field from session manager)
        is_key_event = event.get("type") == "keyboard"
        
        # If the current event is a key event and the group is empty or the last event was also a key event...
        if is_key_event and (not current_group or current_group[-1].get("type") == "keyboard"):
            # Add it to the current group
            current_group.append(event)
        else:
            # If the group has events, finalize it
            if current_group:
                grouped.append(current_group)
            # Start a new group with the current event
            current_group = [event]
            
    # Add the last group if it's not empty
    if current_group:
        grouped.append(current_group)
        
    return grouped

def _format_event_group(event_group: List[Dict], group_number: int) -> str:
    """Formats a group of events into a readable string."""
    first_event = event_group[0]
    event_type = first_event.get("type")  # Use 'type' from session manager
    
    start_time = datetime.fromtimestamp(first_event.get("timestamp", 0)).strftime('%H:%M:%S')
    app_name = first_event.get("app_name", "Unknown App")  # Direct access from session manager

    line = f"[{start_time}] Step {group_number}: "

    if event_type == "mouse_click":
        coords = first_event.get("coordinates", (0, 0))
        # Try to get element description from element_info
        element_info = first_event.get("element_info", {})
        if element_info and element_info.get("text"):
            description = element_info.get("text")
        else:
            description = "an unnamed element"
        
        line += f"Clicked on {description} in {app_name} at {coords}"
        
    elif event_type == "keyboard":
        # For grouped keyboard events, check if we have typed_text directly
        if len(event_group) == 1:
            # Single grouped keyboard event - use typed_text if available
            first_event = event_group[0]
            typed_text = first_event.get("typed_text")
            if not typed_text:
                # Fallback to individual key_char
                key_char = first_event.get("key_char", "")
                if key_char == "space":
                    typed_text = " "
                elif key_char == "return":
                    typed_text = "⏎"
                elif key_char == "tab":
                    typed_text = "⇥"
                elif key_char == "delete":
                    typed_text = "⌫"
                elif key_char == "escape":
                    typed_text = "⎋"
                else:
                    typed_text = key_char
        else:
            # Multiple events - join individual characters (legacy behavior)
            typed_chars = []
            for e in event_group:
                key_char = e.get("key_char", "")
                if key_char == "space":
                    typed_chars.append(" ")
                elif key_char == "return":
                    typed_chars.append("⏎")
                elif key_char == "tab":
                    typed_chars.append("⇥")
                elif key_char == "delete":
                    typed_chars.append("⌫")
                elif key_char == "escape":
                    typed_chars.append("⎋")
                else:
                    typed_chars.append(key_char)
            typed_text = "".join(typed_chars)
        
        line += f"Typed '{typed_text}' in {app_name}"
        
    elif event_type == "mouse_scroll":
        delta = first_event.get("scroll_delta", (0, 0))
        line += f"Scrolled in {app_name} by {delta}"
        
    else:
        line += f"Performed an unknown action in {app_name}"
        
    return line + "\n" 