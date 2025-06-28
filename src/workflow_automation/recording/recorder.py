"""
Main Workflow Recorder
This module contains the central orchestrator, the WorkflowRecorder,
which connects all the components of the recording system.
"""

import time
import os
from pathlib import Path
from .models import RecorderState, SystemEvent, EventType
from .session import SessionManager
from .events.monitor import EventMonitor
from .events.permissions import check_all_permissions
from .analysis.ui_inspector import UIInspector, UIInspectorError
from .analysis.event_processor import EventProcessor, ProcessedEventResult
from .analysis.summary_generator import generate_summary, generate_action_blueprint_only
from .utilities.logger import WorkflowLogger
from .context.inspector import ContextInspector
from .context.contextualizer import Contextualizer

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
        self.context_inspector = ContextInspector()
        self.logger = None
        self.contextualizer = Contextualizer()
        
        # Context inspection tracking
        self.last_inspected_app: str = ""
        
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
        permissions_ok, error_message = check_all_permissions()
        if not permissions_ok:
            print(f"❌ WorkflowRecorder: {error_message}")
            print("   Please grant permissions in System Settings > Privacy & Security.")
            print("   Required: Accessibility (Input Monitoring) and Screen Recording")
            return False
        
        print("✅ WorkflowRecorder: All permissions verified")
        
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
        events_for_summary = self.session_manager.get_raw_events_for_summary()
        summary = generate_summary(
            session_id=session.session_id,
            workflow_name=self.workflow_name,
            start_time=session.start_time,
            events=events_for_summary,
            steps=self.logger.step_count,
            errors=self.logger.error_count
        )
        self.logger.write_summary(summary)
        
        # 4. Generate and save action blueprint separately
        action_blueprint = generate_action_blueprint_only(events_for_summary)
        if action_blueprint:
            self._save_action_blueprint(action_blueprint, session.session_id)

        # 5. Clean up
        self.logger.close()
        self.logger = None
        self.state = RecorderState.STOPPED
        print("✅ WorkflowRecorder: Recording stopped, summary generated, and blueprint saved.")
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

        # Context-aware UI inspection
        app_name = event.data.get("app_name")
        
        # Handle UI_INSPECTED events first to update the map
        if event.event_type == EventType.UI_INSPECTED:
            compressed_ui = event.data.get("compressed_ui")
            if compressed_ui:
                self.contextualizer.update_ui_map(compressed_ui)
            return # This event is for context only, do not process further

        if app_name and app_name != self.last_inspected_app and app_name.lower() != "augment":
            print(f"🔄 App changed to {app_name}, running UI inspection...")
            
            # Run the inspection - it now returns a dictionary
            ui_map = self.context_inspector.run_inspection()
            
            # Immediately update the contextualizer with the new UI map
            if ui_map:
                self.contextualizer.update_ui_map(ui_map)
                compressed_ui = ui_map.get("compressedOutput", "")
            else:
                # If inspection fails, use an error string for the log
                compressed_ui = "[UI INSPECTION FAILED]"

            # Create a new SystemEvent for the UI inspection
            ui_inspected_event = SystemEvent(
                timestamp=time.time(),
                event_type=EventType.UI_INSPECTED,
                data={"app_name": app_name, "compressed_ui": compressed_ui},
                description=f"UI context captured for {app_name}"
            )
            # Add this event to the session so it appears in the logs/summary
            self.session_manager.add_raw_event(ui_inspected_event)
            self.last_inspected_app = app_name

        try:
            # Always initialize clicked_element to ensure it's defined in all code paths.
            clicked_element = None

            # Handle keyboard events with buffering for grouping
            if event.event_type == EventType.KEYBOARD:
                self._handle_keyboard_event(event)
                return
            
            # For non-keyboard events, flush any pending keyboard buffer first
            self._flush_keyboard_buffer()
            
            # Filter out spurious scroll events
            if event.event_type == EventType.MOUSE_SCROLL:
                scroll_delta = event.data.get("scroll_delta", (0, 0))
                if scroll_delta == (0, 0):
                    return
            
            # Find clicked element if it's a click event
            if event.event_type == EventType.MOUSE_CLICK:
                coords = event.data.get("coordinates")
                if coords:
                    clicked_element = self.contextualizer.find_element_at_coordinates(coords[0], coords[1])

            # 1. Determine if we need fresh UI state
            ui_state = {}

            # 2. Process the event.
            processed_result = self.event_processor.process_event(
                event, ui_state, clicked_element=clicked_element
            )
            
            if processed_result:
                # 3. Add the step to the session and log it
                step = processed_result.workflow_step
                self.session_manager.add_step(step)
                self.session_manager.enrich_last_event_with_step(step)
                self.logger.log("WORKFLOW_STEP", processed_result.enriched_description, step.to_dict())

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
        current_app = event.data.get("app_name")
        key_char = event.data.get("key_char", "")
        
        # Check if this continues a typing sequence (same app, not a special key)
        if (self.keyboard_buffer and 
            self.keyboard_buffer[-1].data.get("app_name") == current_app and
            key_char not in ["return", "tab", "escape"]):
            # Add to existing buffer - no timeout constraint for continuous typing
            self.keyboard_buffer.append(event)
        else:
            # Flush existing buffer if it exists (app change or special key)
            self._flush_keyboard_buffer()
            # Start new buffer
            self.keyboard_buffer = [event]
        
        self.last_keyboard_time = current_time
        
        # Only set up timer for special keys (return, tab, escape) to flush immediately
        if key_char in ["return", "tab", "escape"]:
            import threading
            threading.Timer(0.1, self._flush_keyboard_buffer_if_old).start()
    
    def _flush_keyboard_buffer_if_old(self):
        """Flush keyboard buffer immediately (used for special keys)."""
        if self.keyboard_buffer:
            self._flush_keyboard_buffer()
    
    def _flush_keyboard_buffer(self):
        """Process buffered keyboard events as a single grouped workflow step."""
        if not self.keyboard_buffer:
            return
        
        try:
            # The keyboard buffer should be processed into a single step.
            # We can create a synthetic "processed_result" here for logging.
            first_event = self.keyboard_buffer[0]
            app_name = first_event.data.get("app_name", "Unknown App")
            
            # Collect all characters
            typed_chars = []
            for event in self.keyboard_buffer:
                key_char = event.data.get("key_char", "")
                if key_char == "space": typed_chars.append(" ")
                elif key_char == "return": typed_chars.append("⏎")
                elif key_char == "tab": typed_chars.append("⇥")
                elif key_char == "delete": typed_chars.append("⌫")
                elif key_char == "escape": typed_chars.append("⎋")
                else: typed_chars.append(key_char)
            
            typed_text = "".join(typed_chars)
            
            description = f"Typed '{typed_text}' in {app_name}"
            
            # Create a workflow step directly
            from .models import WorkflowStep
            step = WorkflowStep(
                step_id=0,  # Will be set by session manager
                event_type=EventType.KEYBOARD,
                timestamp=first_event.timestamp,
                description=description,
                data={
                    "app_name": app_name,
                    "typed_text": typed_text,
                    "raw_events": [e.to_dict() for e in self.keyboard_buffer]
                }
            )
            
            # Add step to the session and log it
            self.session_manager.add_step(step)
            # We don't enrich the last event here because there are many events.
            self.logger.log("WORKFLOW_STEP", description, step.to_dict())

        except Exception as e:
            error_message = f"An unexpected error occurred in keyboard buffer flush: {e}"
            print(f"❌ {error_message}")
            self.logger.log("ERROR", "KEYBOARD_FLUSH_ERROR", {"error": error_message})
        finally:
            # Clear buffer regardless of success or failure
            self.keyboard_buffer = []

    def _save_action_blueprint(self, action_steps: list, session_id: str):
        """Save action blueprint to both action_blueprints folder (numbered) and output folder (timestamped)."""
        try:
            project_root = Path(__file__).parent.parent.parent
            
            # 1. Save to action_blueprints directory (numbered)
            blueprints_dir = project_root / "workflow_automation" / "action_blueprints"
            blueprints_dir.mkdir(parents=True, exist_ok=True)
            
            # Find highest existing number and add one
            existing_files = list(blueprints_dir.glob("blueprint_*.txt"))
            existing_numbers = []
            
            for file in existing_files:
                try:
                    # Extract number from filename like "blueprint_5.txt"
                    filename = file.stem  # Gets "blueprint_5" from "blueprint_5.txt"
                    if filename.startswith("blueprint_"):
                        number_str = filename[10:]  # Remove "blueprint_" prefix
                        number = int(number_str)
                        existing_numbers.append(number)
                except (ValueError, IndexError):
                    # Skip files that don't match the expected pattern
                    continue
            
            # Determine next number (highest + 1, or 1 if no valid files exist)
            next_number = max(existing_numbers) + 1 if existing_numbers else 1
            
            # Create the numbered blueprint file
            blueprint_file = blueprints_dir / f"blueprint_{next_number}.txt"
            
            # Write the action steps to numbered file
            with open(blueprint_file, 'w') as f:
                for i, action in enumerate(action_steps, 1):
                    f.write(f"{i}. {action}\n")
            
            print(f"📋 Action blueprint saved: {blueprint_file}")
            
            # 2. Save to output directory (timestamped)
            output_dir = project_root / "workflow_automation" / "output"
            output_dir.mkdir(parents=True, exist_ok=True)
            
            # Create timestamped blueprint file
            timestamped_blueprint_file = output_dir / f"action_blueprint_{session_id}.txt"
            
            # Write the action steps to timestamped file
            with open(timestamped_blueprint_file, 'w') as f:
                for i, action in enumerate(action_steps, 1):
                    f.write(f"{i}. {action}\n")
            
            print(f"📋 Action blueprint also saved: {timestamped_blueprint_file}")
            
        except Exception as e:
            print(f"⚠️ Failed to save action blueprint: {e}")

    def get_state(self):
        """Returns the current state of the recorder."""
        return self.state 