"""
Manages the state of a single workflow recording session.
"""

import time
from datetime import datetime
from typing import List, Optional

from .models import RecordingSession, WorkflowStep, SystemEvent

class SessionManager:
    """
    Handles the lifecycle of a RecordingSession object.
    """
    def __init__(self, workflow_name: str = "Unnamed Workflow"):
        self.session: Optional[RecordingSession] = None
        self.workflow_name = workflow_name
        self.raw_events: List[SystemEvent] = []

    def start_session(self):
        """Initializes a new recording session."""
        session_id = f"session_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        self.session = RecordingSession(
            session_id=session_id,
            start_time=time.time(),
            metadata={"workflow_name": self.workflow_name}
        )
        self.raw_events = []
        print(f"🚀 SessionManager: Started new session '{session_id}'.")

    def stop_session(self):
        """Finalizes the current recording session."""
        if self.session:
            self.session.end_time = time.time()
            print(f"🏁 SessionManager: Stopped session '{self.session.session_id}'.")

    def add_step(self, step: WorkflowStep):
        """Adds a new workflow step to the current session."""
        if self.session:
            step.step_id = len(self.session.steps) + 1
            self.session.steps.append(step)

    def add_raw_event(self, event: SystemEvent):
        """Adds a raw system event to the session's event list for summary generation."""
        if self.session:
            # We add the raw event here, but it will be enriched later.
            self.raw_events.append(event)

    def enrich_last_event_with_step(self, step: WorkflowStep):
        """Updates the last raw event with details from the processed workflow step."""
        if self.raw_events:
            # The workflow step contains richer info, like the target element.
            # We can store this alongside the raw event for a better summary.
            last_event = self.raw_events[-1]
            # Use a special key to avoid overwriting original event data
            last_event.data['processed_info'] = {
                "description": step.description,
                "target_element": step.data.get("target_element")
            }

    def get_session(self) -> Optional[RecordingSession]:
        """Returns the current session object."""
        return self.session

    def get_raw_events_for_summary(self) -> List[dict]:
        """
        Returns a list of simplified event dictionaries suitable for the
        summary generator.
        """
        summary_events = []
        for event in self.raw_events:
            # Create a base dictionary with event type and timestamp
            summary_event = {
                "type": event.event_type.value,
                "timestamp": event.timestamp,
            }

            # Copy all keys from the event's data dictionary to the summary event
            # This is more robust and will include app_name, coordinates, key_char, 
            # scroll_delta, and our new 'compressed_ui' without having to name them.
            summary_event.update(event.data)

            # Handle the processed_info separately for enrichment
            processed_info = event.data.get("processed_info", {})
            summary_event["description"] = processed_info.get("description", event.description)
            summary_event["element_info"] = processed_info.get("target_element", {})

            summary_events.append(summary_event)
            
        return summary_events 