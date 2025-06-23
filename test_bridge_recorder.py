#!/usr/bin/env python3
"""
Test which recorder the bridge is actually using
"""
import sys
from pathlib import Path

# Add src to path exactly like the bridge does
project_root = Path(__file__).parent / "src"
sys.path.insert(0, str(project_root))

print(f"Python path: {sys.path[0]}")
print("Testing imports...")

try:
    from workflow_automation.recording.recorder import WorkflowRecorder
    from workflow_automation.recording.models import RecorderState
    print("✅ Successfully imported new recorder system")
    
    # Test instantiation
    recorder = WorkflowRecorder("test")
    print(f"✅ WorkflowRecorder instantiated: {type(recorder)}")
    print(f"   - Has EventMonitor: {hasattr(recorder, 'event_monitor')}")
    print(f"   - Has EventProcessor: {hasattr(recorder, 'event_processor')}")
    print(f"   - Initial state: {recorder.state}")
    
    # Check the event monitor
    if hasattr(recorder, 'event_monitor'):
        print(f"   - EventMonitor type: {type(recorder.event_monitor)}")
    
except ImportError as e:
    print(f"❌ Import failed: {e}")
    print("Checking what's available...")
    
    # Try to import old system
    try:
        sys.path.insert(0, "src/workflow_automation")
        from recording.workflow_recorder import WorkflowRecorder as OldRecorder
        print("⚠️ Found OLD recording system!")
    except ImportError:
        print("No old recording system found")