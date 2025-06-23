"""
Main Workflow Recorder
This module contains the central orchestrator, the WorkflowRecorder,
which connects all the components of the recording system.
"""

import time
from .models import RecorderState, SystemEvent, EventType
from .session import SessionManager
from .events.monitor import EventMonitor
from .events.permissions import check_accessibility_permissions
from .analysis.ui_inspector import UIInspector, UIInspectorError
from .analysis.event_processor import EventProcessor, ProcessedEventResult
from .analysis.summary_generator import generate_summary
from .utilities.logger import WorkflowLogger

class WorkflowRecorder:
    """
    The main orchestrator for the workflow recording process.
    It coordinates the event monitor, UI inspector, event processor,
    session manager, and logger.
    """
    def __init__(self, workflow_name: str = "DefaultWorkflow"):
        self.state = RecorderState.STOPPED
        self.workflow_name = workflow_name
        
        # Initialize components
        self.session_manager = SessionManager(workflow_name)
        self.event_monitor = EventMonitor(self._handle_system_event)
        self.ui_inspector = UIInspector()
        self.event_processor = EventProcessor()
        self.logger = None
        
        # Keyboard event buffering for grouping
        self.keyboard_buffer = []
        self.last_keyboard_time = 0
        self.keyboard_timeout = 1.0  # Group keystrokes within 1 second

    def start_recording(self) -> bool:
        """
        Starts the workflow recording session.
        Returns True on success, False on failure.
        """
        if self.state == RecorderState.RECORDING:
            print("⚠️ WorkflowRecorder: Already recording.")
            return False

        print("🎬 WorkflowRecorder: Attempting to start recording...")
        
        # 1. Check for necessary permissions
        if not check_accessibility_permissions():
            print("❌ WorkflowRecorder: Accessibility permissions are not granted.")
            print("   Please grant permissions in System Settings > Privacy & Security > Accessibility.")
            return False
        
        # 2. Start a new session and initialize logger
        self.session_manager.start_session()
        session = self.session_manager.get_session()
        self.logger = WorkflowLogger(session.session_id, self.workflow_name)
        self.logger.log("SESSION_START", "Recording session started", session.to_dict())

        # 3. Start monitoring for events
        self.event_monitor.start()
        
        self.state = RecorderState.RECORDING
        print("✅ WorkflowRecorder: Recording has started.")
        return True

    def stop_recording(self) -> bool:
        """
        Stops the workflow recording session.
        Returns True on success, False on failure.
        """
        if self.state != RecorderState.RECORDING:
            print("⚠️ WorkflowRecorder: No active recording to stop.")
            return False
            
        print("🛑 WorkflowRecorder: Stopping recording...")
        
        # 1. Flush any remaining keyboard buffer
        self._flush_keyboard_buffer()
        
        # 2. Stop the event monitor to prevent new events from coming in
        self.event_monitor.stop()

        # 3. Finalize the session and log the end
        self.session_manager.stop_session()
        session = self.session_manager.get_session()
        self.logger.log("SESSION_END", "Recording session ended", session.to_dict())

        # 3. Generate and write summary with all the now-processed steps
        summary = generate_summary(
            session_id=session.session_id,
            workflow_name=self.workflow_name,
            start_time=session.start_time,
            events=self.session_manager.get_raw_events_for_summary(),
            steps=self.logger.step_count,
            errors=self.logger.error_count
        )
        self.logger.write_summary(summary)

        # 4. Clean up
        self.logger.close()
        self.logger = None
        self.state = RecorderState.STOPPED
        print("✅ WorkflowRecorder: Recording stopped and summary generated.")
        return True

    def _handle_system_event(self, event: SystemEvent):
        """
        The callback method passed to the EventMonitor. This is the heart
        of the recording loop.
        """
        if self.state != RecorderState.RECORDING:
            return

        # Log the raw event with its initial, basic description
        self.logger.log("SYSTEM_EVENT", event.description, event.to_dict())
        self.session_manager.add_raw_event(event)

        try:
            # Handle keyboard events with buffering for grouping
            if event.event_type == EventType.KEYBOARD:
                self._handle_keyboard_event(event)
                return
            
            # For non-keyboard events, flush any pending keyboard buffer first
            self._flush_keyboard_buffer()
            
            # Filter out spurious scroll events (delta = 0)
            if event.event_type == EventType.MOUSE_SCROLL:
                scroll_delta = event.data.get("scroll_delta", (0, 0))
                if scroll_delta == (0, 0):
                    return  # Skip empty scroll events
            
            # 1. Determine if we need fresh UI state (only for clicks and app changes)
            ui_state = {}
            # TEMPORARILY DISABLED UI INSPECTION - focus on input logging only
            # if self._should_capture_ui_state(event):
            #     ui_state = self.ui_inspector.capture_ui_state()
            #     self.logger.log("UI_STATE", "UI state captured", {"element_count": len(ui_state.get("elements", []))})

            # 2. Process the event. This now handles one event at a time.
            processed_result = self.event_processor.process_event(event, ui_state)
            
            if processed_result:
                # 3. Add the step to the session and log it
                step = processed_result.workflow_step
                self.session_manager.add_step(step)
                self.session_manager.enrich_last_event_with_step(step)
                self.logger.log("WORKFLOW_STEP", processed_result.enriched_description, step.to_dict())

        except UIInspectorError as e:
            error_message = f"Failed to inspect UI: {e}"
            print(f"❌ {error_message}")
            self.logger.log("ERROR", "UI_INSPECTION_FAILED", {"error": error_message})
        except Exception as e:
            error_message = f"An unexpected error occurred in event handler: {e}"
            print(f"❌ {error_message}")
            self.logger.log("ERROR", "UNHANDLED_EXCEPTION", {"error": error_message})

    def _should_capture_ui_state(self, event: SystemEvent) -> bool:
        """
        Determines if UI state should be captured for this event.
        Only capture UI state when it's likely to have changed:
        - Mouse clicks (might change UI)
        - App focus changes
        - NOT for keyboard events (typing doesn't change UI structure)
        """
        # Always capture for mouse clicks as they can change UI state
        if event.event_type in [EventType.MOUSE_CLICK, EventType.MOUSE_SCROLL]:
            return True
        
        # For keyboard events, check if app changed
        if event.event_type == EventType.KEYBOARD:
            current_app = event.data.get("app_name")
            if hasattr(self, '_last_app') and self._last_app != current_app:
                self._last_app = current_app
                return True  # App changed, capture new UI state
            elif not hasattr(self, '_last_app'):
                self._last_app = current_app
                return True  # First keyboard event, capture initial UI state
            return False  # Same app, no UI capture needed for typing
        
        return False  # Unknown event type, skip UI capture

    def _handle_keyboard_event(self, event: SystemEvent):
        """Handle keyboard events with buffering for grouping consecutive keystrokes."""
        current_time = time.time()
        
        # Check if this continues a typing sequence
        if (self.keyboard_buffer and 
            current_time - self.last_keyboard_time < self.keyboard_timeout and
            self.keyboard_buffer[-1].data.get("app_name") == event.data.get("app_name")):
            # Add to existing buffer
            self.keyboard_buffer.append(event)
        else:
            # Flush existing buffer if it exists
            self._flush_keyboard_buffer()
            # Start new buffer
            self.keyboard_buffer = [event]
        
        self.last_keyboard_time = current_time
        
        # Set up a timer to flush the buffer if no more keys come
        import threading
        threading.Timer(self.keyboard_timeout, self._flush_keyboard_buffer_if_old).start()
    
    def _flush_keyboard_buffer_if_old(self):
        """Flush keyboard buffer if the last keystroke was longer than timeout ago."""
        if self.keyboard_buffer and time.time() - self.last_keyboard_time >= self.keyboard_timeout:
            self._flush_keyboard_buffer()
    
    def _flush_keyboard_buffer(self):
        """Process buffered keyboard events as a single grouped workflow step."""
        if not self.keyboard_buffer:
            return
        
        try:
            # Create grouped keyboard step
            first_event = self.keyboard_buffer[0]
            app_name = first_event.data.get("app_name", "Unknown App")
            
            # Collect all characters
            typed_chars = []
            for event in self.keyboard_buffer:
                key_char = event.data.get("key_char", "")
                # Convert special keys to display characters
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
            
            # Create grouped workflow step
            from .models import WorkflowStep
            step = WorkflowStep(
                step_id=0,  # Will be set by session manager
                event_type=EventType.KEYBOARD,
                timestamp=first_event.timestamp,
                description=f"Typed '{typed_text}' in {app_name}",
                data={
                    "event_data": {
                        "app_name": app_name,
                        "typed_text": typed_text,
                        "key_count": len(self.keyboard_buffer)
                    },
                    "target_element": None,
                    "window_info": {}
                },
                action_type="keyboard_type"
            )
            
            # Add the step to session and log it
            self.session_manager.add_step(step)
            self.session_manager.enrich_last_event_with_step(step)
            self.logger.log("WORKFLOW_STEP", step.description, step.to_dict())
            
            # Clear the buffer
            self.keyboard_buffer = []
            
        except Exception as e:
            print(f"❌ Error processing keyboard buffer: {e}")
            self.keyboard_buffer = [] 