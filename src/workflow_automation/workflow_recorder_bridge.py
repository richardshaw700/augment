#!/usr/bin/env python3
"""
Bridge script for Swift to communicate with the Python workflow recording system.
This script provides a simple interface for the Swift app to start/stop recording.
"""

import sys
import os
import signal
import time
import json
from pathlib import Path
from datetime import datetime

# --- Debug Logging Setup ---
DEBUG_LOG_DIR = Path(__file__).parent.parent / "debug_output_workflow"
DEBUG_LOG_DIR.mkdir(exist_ok=True)
TIMESTAMP = datetime.now().strftime("%Y%m%d_%H%M%S")
DEBUG_LOG_FILE = DEBUG_LOG_DIR / f"workflow_debug_{TIMESTAMP}.log"

class DebugLogger:
    def __init__(self, filepath):
        self.terminal = sys.stdout
        self.log = open(filepath, "w")

    def write(self, message):
        self.terminal.write(message)
        self.log.write(message)
        self.flush()

    def flush(self):
        self.terminal.flush()
        self.log.flush()

    def __getattr__(self, attr):
        return getattr(self.terminal, attr)

sys.stdout = DebugLogger(DEBUG_LOG_FILE)
sys.stderr = sys.stdout
# --- End Debug Logging Setup ---

# Add the project's src directory to the Python path
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

# Now we can use an absolute import from the project root
try:
    from workflow_automation.recording.recorder import WorkflowRecorder
    from workflow_automation.recording.models import RecorderState
except ImportError as e:
    print(f"❌ Import error: {str(e)}")
    sys.exit(1)

class RecorderBridge:
    """Bridge between Swift app and Python workflow recorder"""
    
    def __init__(self):
        self.recorder = None
        self.is_running = False
    
    def start_recording(self):
        """Start workflow recording"""
        try:
            print("🎬 Bridge: Starting workflow recording...")
            
            # Initialize recorder
            self.recorder = WorkflowRecorder()
            
            # Start recording
            success = self.recorder.start_recording()
            
            if success:
                self.is_running = True
                print("✅ Bridge: Recording started successfully")
                return True
            else:
                print("❌ Bridge: Failed to start recording")
                return False
                
        except Exception as e:
            print(f"❌ Bridge: Error starting recording: {str(e)}")
            return False
    
    def stop_recording(self):
        """Stop workflow recording"""
        try:
            if not self.recorder or not self.is_running:
                print("⚠️ Bridge: No active recording to stop")
                return False
            
            print("🛑 Bridge: Stopping workflow recording...")
            
            # Stop recording
            success = self.recorder.stop_recording()
            
            if success:
                self.is_running = False
                print("✅ Bridge: Recording stopped successfully")
                return True
            else:
                print("❌ Bridge: Failed to stop recording")
                return False
                
        except Exception as e:
            print(f"❌ Bridge: Error stopping recording: {str(e)}")
            return False
    
    def get_status(self):
        """Get current recording status"""
        if self.recorder and self.is_running:
            return {
                "status": "recording",
                "state": self.recorder.state.value if hasattr(self.recorder.state, 'value') else str(self.recorder.state)
            }
        else:
            return {
                "status": "stopped",
                "state": "idle"
            }
    
    def cleanup(self):
        """Clean up resources"""
        if self.recorder and self.is_running:
            print("🧹 Bridge: Cleaning up...")
            self.stop_recording()

def signal_handler(signum, frame):
    """Handle shutdown signals"""
    print(f"\n🛑 Bridge: Received signal {signum}, shutting down...")
    if 'bridge' in globals():
        bridge.cleanup()
    sys.exit(0)

def main():
    """Main bridge function"""
    global bridge
    
    print(f"--- Workflow Recorder Bridge Initialized: {TIMESTAMP} ---")
    print(f"Python executable: {sys.executable}")
    print(f"Python version: {sys.version}")
    print(f"Arguments: {sys.argv}")
    print(f"Current Directory: {os.getcwd()}")
    print("----------------------------------------------------")
    
    # Set up signal handlers
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    # Initialize bridge
    bridge = RecorderBridge()
    
    if len(sys.argv) < 2:
        print("❌ Bridge: No command provided")
        print("Usage: python workflow_recorder_bridge.py [start|stop|status]")
        sys.exit(1)
    
    command = sys.argv[1].lower()
    
    try:
        if command == "start":
            success = bridge.start_recording()
            if success:
                print("📡 Bridge: Recording active, waiting for stop signal...")
                # Keep the script running
                while bridge.is_running:
                    time.sleep(1)
            else:
                sys.exit(1)
                
        elif command == "stop":
            success = bridge.stop_recording()
            sys.exit(0 if success else 1)
            
        elif command == "status":
            status = bridge.get_status()
            print(json.dumps(status))
            sys.exit(0)
            
        else:
            print(f"❌ Bridge: Unknown command: {command}")
            print("Usage: python workflow_recorder_bridge.py [start|stop|status]")
            sys.exit(1)
            
    except KeyboardInterrupt:
        print("\n🛑 Bridge: Interrupted by user")
        bridge.cleanup()
        sys.exit(0)
    except Exception as e:
        print(f"❌ Bridge: Unexpected error: {str(e)}")
        bridge.cleanup()
        sys.exit(1)

if __name__ == "__main__":
    main() 