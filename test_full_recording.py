#!/usr/bin/env python3
"""
Test the full recording pipeline to ensure keyboard events are captured
"""
import sys
import time
from pathlib import Path

# Add src to path like the bridge
project_root = Path(__file__).parent / "src"
sys.path.insert(0, str(project_root))

from workflow_automation.recording.recorder import WorkflowRecorder

def main():
    print("🧪 Testing full WorkflowRecorder pipeline...")
    print("This will record for 15 seconds - please type and click during this time")
    print("=" * 60)
    
    recorder = WorkflowRecorder("KeyboardTest")
    
    try:
        # Start recording
        success = recorder.start_recording()
        if not success:
            print("❌ Failed to start recording")
            return
        
        print("✅ Recording started. Please type some text and click around...")
        print("   (Recording will stop in 15 seconds)")
        
        # Record for 15 seconds
        time.sleep(15)
        
        # Stop recording
        recorder.stop_recording()
        print("🛑 Recording stopped")
        
    except KeyboardInterrupt:
        print("\n🛑 Recording interrupted by user")
        recorder.stop_recording()
    except Exception as e:
        print(f"❌ Error during recording: {e}")
        if recorder.state.value == "RECORDING":
            recorder.stop_recording()

if __name__ == "__main__":
    main()