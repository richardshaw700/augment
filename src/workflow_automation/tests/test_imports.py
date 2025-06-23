"""
Test script for rapidly debugging Python import issues from the terminal.
Run this from the project root directory: python3 -m src.workflow_automation.tests.test_imports
"""

import sys
from pathlib import Path

print("--- Starting Import Test ---")

# This is the key part: Add the project's root directory to the path.
# The project root is two levels up from this test file's parent directory.
# (tests -> workflow_automation -> src -> project_root)
project_root = Path(__file__).parent.parent.parent.parent
sys.path.insert(0, str(project_root))

print(f"Project root added to sys.path: {project_root}")
print("Attempting to import WorkflowRecorder...")

try:
    # This import must be relative to the project root we added to the path.
    from src.workflow_automation.recording.recorder import WorkflowRecorder
    print("\n✅ SUCCESS: Successfully imported WorkflowRecorder.")
    
    # Let's try to instantiate it to be sure.
    recorder = WorkflowRecorder()
    print("✅ SUCCESS: Successfully instantiated WorkflowRecorder.")
    
except ImportError as e:
    print(f"\n❌ FAILED: An ImportError occurred.")
    print(f"Error details: {e}")
except Exception as e:
    print(f"\n❌ FAILED: An unexpected error occurred.")
    print(f"Error details: {e}")

print("\n--- Import Test Finished ---") 