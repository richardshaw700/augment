"""
Test script for the full workflow recording lifecycle.
Run from the project root: python3 -m src.workflow_automation.tests.test_full_workflow
"""

import sys
import time
from pathlib import Path

# --- Setup Python Path ---
# Add the project's root directory to the path to allow absolute imports
project_root = Path(__file__).parent.parent.parent.parent
if str(project_root) not in sys.path:
    sys.path.insert(0, str(project_root))

print("--- Starting Full Workflow Test ---")
print(f"Project root added to sys.path: {project_root}")

try:
    from src.workflow_automation.recording.recorder import WorkflowRecorder
    print("✅ Successfully imported WorkflowRecorder.")

    # 1. Initialize the recorder
    recorder = WorkflowRecorder(workflow_name="Test_Workflow_From_Script")
    print("✅ Successfully instantiated WorkflowRecorder.")

    # 2. Start the recording
    print("\nAttempting to start recording...")
    success = recorder.start_recording()

    if not success:
        print("\n❌ FAILED: start_recording() returned False.")
        print("   This likely means the script lacks necessary permissions.")
        print("   Please ensure your terminal has 'Accessibility' and 'Input Monitoring' permissions in System Settings.")
    else:
        print("✅ SUCCESS: Recording started.")
        print("   Pausing for 5 seconds to simulate a recording session...")
        print("   (You can move your mouse or type something now)")
        
        # 3. Wait for a few seconds
        time.sleep(5)
        
        # 4. Stop the recording
        print("\nAttempting to stop recording...")
        recorder.stop_recording()
        print("✅ SUCCESS: Recording stopped.")
        print("\nCheck the 'src/workflow_automation/output/' directory for the log files.")

except Exception as e:
    print(f"\n❌ FAILED: An unexpected error occurred during the test.")
    print(f"   Error Type: {type(e).__name__}")
    print(f"   Error Details: {e}")

print("\n--- Full Workflow Test Finished ---") 