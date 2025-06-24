#!/usr/bin/env python3
"""
Test script to verify the blueprint file saving functionality without importing recorder.
"""

import sys
from pathlib import Path

# Add the project root to the path
project_root = Path(__file__).parent.parent.parent.parent
sys.path.append(str(project_root))

def save_action_blueprint(action_steps: list):
    """Simplified version of the blueprint saving method for testing."""
    try:
        # Create the action_blueprints directory
        project_root = Path(__file__).parent.parent.parent.parent
        blueprints_dir = project_root / "src" / "workflow_automation" / "action_blueprints"
        blueprints_dir.mkdir(parents=True, exist_ok=True)
        
        # Count existing blueprint files to determine next number
        existing_files = list(blueprints_dir.glob("blueprint_*.txt"))
        next_number = len(existing_files) + 1
        
        # Create the blueprint file
        blueprint_file = blueprints_dir / f"blueprint_{next_number}.txt"
        
        # Write the action steps
        with open(blueprint_file, 'w') as f:
            for i, action in enumerate(action_steps, 1):
                f.write(f"{i}. {action}\n")
        
        print(f"📋 Action blueprint saved: {blueprint_file}")
        return blueprint_file
        
    except Exception as e:
        print(f"⚠️ Failed to save action blueprint: {e}")
        return None

def test_blueprint_file_saving():
    """Test the blueprint file saving functionality."""
    
    print("🧪 TESTING BLUEPRINT FILE SAVING")
    print("=" * 50)
    
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
    saved_file = save_action_blueprint(mock_action_steps)
    
    if saved_file and saved_file.exists():
        # Read and verify the saved file
        print(f"\n📄 Contents of {saved_file.name}:")
        print("-" * 40)
        with open(saved_file, 'r') as f:
            content = f.read()
            print(content)
        print("-" * 40)
        
        # Verify content
        lines = content.strip().split('\n')
        if len(lines) == len(mock_action_steps):
            print(f"✅ SUCCESS: Blueprint file saved correctly with {len(lines)} steps")
            
            # Verify each line format
            all_correct = True
            for i, line in enumerate(lines):
                expected_prefix = f"{i+1}. "
                if not line.startswith(expected_prefix):
                    print(f"❌ Line {i+1} format incorrect: {line}")
                    all_correct = False
            
            if all_correct:
                print("✅ All lines formatted correctly with numbering")
        else:
            print(f"❌ FAILED: Expected {len(mock_action_steps)} lines, got {len(lines)}")
    else:
        print("❌ FAILED: Blueprint file was not created")
    
    # Check directory structure
    blueprints_dir = project_root / "src" / "workflow_automation" / "action_blueprints"
    blueprint_files = list(blueprints_dir.glob("blueprint_*.txt"))
    
    print(f"\n📁 Total blueprint files in directory: {len(blueprint_files)}")
    for file in sorted(blueprint_files):
        print(f"   - {file.name}")

if __name__ == "__main__":
    test_blueprint_file_saving()