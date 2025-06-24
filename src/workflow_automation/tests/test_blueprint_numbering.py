#!/usr/bin/env python3
"""
Test script to verify the improved blueprint numbering logic handles edge cases.
"""

import sys
from pathlib import Path

# Add the project root to the path
project_root = Path(__file__).parent.parent.parent.parent
sys.path.append(str(project_root))

def save_action_blueprint_improved(action_steps: list):
    """Improved version of the blueprint saving method with proper numbering."""
    try:
        # Create the action_blueprints directory
        project_root = Path(__file__).parent.parent.parent.parent
        blueprints_dir = project_root / "src" / "workflow_automation" / "action_blueprints"
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
        
        # Create the blueprint file
        blueprint_file = blueprints_dir / f"blueprint_{next_number}.txt"
        
        # Write the action steps
        with open(blueprint_file, 'w') as f:
            for i, action in enumerate(action_steps, 1):
                f.write(f"{i}. {action}\n")
        
        print(f"📋 Action blueprint saved: {blueprint_file}")
        return blueprint_file, next_number
        
    except Exception as e:
        print(f"⚠️ Failed to save action blueprint: {e}")
        return None, None

def test_blueprint_numbering():
    """Test the improved numbering logic with various edge cases."""
    
    print("🧪 TESTING IMPROVED BLUEPRINT NUMBERING")
    print("=" * 50)
    
    blueprints_dir = project_root / "src" / "workflow_automation" / "action_blueprints"
    
    # Test action steps
    test_action_steps = [
        "ACTION: CLICK | target=btn:Test | app=TestApp",
        "ACTION: TYPE | text=Test numbering | app=TestApp"
    ]
    
    # Test 1: Current state
    existing_files = list(blueprints_dir.glob("blueprint_*.txt"))
    print(f"📁 Current files: {[f.name for f in sorted(existing_files)]}")
    
    # Test 2: Save new blueprint
    print("\n🧪 Test 2: Save new blueprint with current logic")
    saved_file, number = save_action_blueprint_improved(test_action_steps)
    if saved_file:
        print(f"✅ Saved as blueprint_{number}.txt")
    
    # Test 3: Simulate deleting blueprint_1.txt
    blueprint_1 = blueprints_dir / "blueprint_1.txt"
    if blueprint_1.exists():
        print(f"\n🧪 Test 3: Deleting {blueprint_1.name} to test gap handling")
        blueprint_1.unlink()
        print(f"🗑️ Deleted {blueprint_1.name}")
    
    # Test 4: Save another blueprint (should handle the gap correctly)
    print("\n🧪 Test 4: Save blueprint after deletion")
    saved_file, number = save_action_blueprint_improved(test_action_steps)
    if saved_file:
        print(f"✅ Saved as blueprint_{number}.txt (should be higher than existing)")
    
    # Test 5: Show final state
    final_files = list(blueprints_dir.glob("blueprint_*.txt"))
    final_numbers = []
    for file in final_files:
        try:
            filename = file.stem
            if filename.startswith("blueprint_"):
                number_str = filename[10:]
                number = int(number_str)
                final_numbers.append(number)
        except (ValueError, IndexError):
            continue
    
    print(f"\n📊 Final state:")
    print(f"   Files: {[f.name for f in sorted(final_files)]}")
    print(f"   Numbers: {sorted(final_numbers)}")
    print(f"   Highest number: {max(final_numbers) if final_numbers else 'None'}")
    
    # Test 6: Create some invalid files to test robustness
    print(f"\n🧪 Test 6: Create invalid files to test robustness")
    (blueprints_dir / "blueprint_invalid.txt").touch()
    (blueprints_dir / "not_blueprint.txt").touch()
    (blueprints_dir / "blueprint_.txt").touch()
    
    print("🧪 Test 7: Save blueprint with invalid files present")
    saved_file, number = save_action_blueprint_improved(test_action_steps)
    if saved_file:
        print(f"✅ Saved as blueprint_{number}.txt (should ignore invalid files)")
    
    # Cleanup invalid files
    (blueprints_dir / "blueprint_invalid.txt").unlink(missing_ok=True)
    (blueprints_dir / "not_blueprint.txt").unlink(missing_ok=True)
    (blueprints_dir / "blueprint_.txt").unlink(missing_ok=True)
    
    print("\n🎉 All tests completed!")

if __name__ == "__main__":
    test_blueprint_numbering()