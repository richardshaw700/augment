#!/usr/bin/env python3
"""
Test script to verify the complete blueprint file saving functionality.
"""

import sys
from pathlib import Path

# Add the project root to the path
project_root = Path(__file__).parent.parent.parent.parent
sys.path.append(str(project_root))

def test_blueprint_file_saving():
    """Test the blueprint file saving functionality by simulating what the recorder does."""
    
    print("🧪 TESTING BLUEPRINT FILE SAVING")
    print("=" * 50)
    
    # Import the recorder's blueprint saving method
    from src.workflow_automation.recording.recorder import WorkflowRecorder
    
    # Create a mock recorder instance (won't actually start recording)
    recorder = WorkflowRecorder("TestWorkflow")
    
    # Mock action steps that would be generated
    mock_action_steps = [
        "ACTION: CLICK | target=txt:iMessage | app=Messages",
        "ACTION: TYPE | text=Hello! This is a test workflow | app=Messages", 
        "ACTION: PRESS_ENTER | app=Messages",
        "ACTION: CLICK | target=btn:Send | app=Messages"
    ]
    
    print("📝 Mock action steps to save:")
    for i, step in enumerate(mock_action_steps, 1):
        print(f"   {i}. {step}")
    
    # Test the blueprint saving
    print("\n💾 Testing blueprint saving...")
    recorder._save_action_blueprint(mock_action_steps)
    
    # Check what was created
    blueprints_dir = project_root / "src" / "workflow_automation" / "action_blueprints"
    blueprint_files = list(blueprints_dir.glob("blueprint_*.txt"))
    
    print(f"\n📁 Blueprint files found: {len(blueprint_files)}")
    for file in sorted(blueprint_files):
        print(f"   - {file.name}")
    
    if blueprint_files:
        # Read the latest blueprint file
        latest_file = max(blueprint_files, key=lambda x: x.stat().st_mtime)
        print(f"\n📄 Contents of {latest_file.name}:")
        print("-" * 40)
        with open(latest_file, 'r') as f:
            content = f.read()
            print(content)
        print("-" * 40)
        
        # Verify content
        lines = content.strip().split('\n')
        if len(lines) == len(mock_action_steps):
            print(f"✅ SUCCESS: Blueprint file saved correctly with {len(lines)} steps")
        else:
            print(f"❌ FAILED: Expected {len(mock_action_steps)} lines, got {len(lines)}")
    else:
        print("❌ FAILED: No blueprint files found")

if __name__ == "__main__":
    test_blueprint_file_saving()