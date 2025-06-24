#!/usr/bin/env python3
"""
Test script to verify action blueprint saving functionality.
"""

import sys
from pathlib import Path

# Add the project root to the path
project_root = Path(__file__).parent.parent.parent.parent
sys.path.append(str(project_root))

from src.workflow_automation.recording.analysis.summary_generator import generate_action_blueprint_only

def test_blueprint_saving():
    """Test the action blueprint generation and verify output format."""
    
    print("🧪 TESTING ACTION BLUEPRINT SAVING")
    print("=" * 50)
    
    # Mock events similar to a real workflow
    mock_events = [
        {
            "type": "mouse_click",
            "description": "Clicked on txt:iMessage@A-23:49 in Messages",
            "app_name": "Messages",
            "timestamp": 1234567890
        },
        {
            "type": "keyboard",
            "key_char": "H",
            "app_name": "Messages",
            "timestamp": 1234567891
        },
        {
            "type": "keyboard", 
            "key_char": "e",
            "app_name": "Messages",
            "timestamp": 1234567892
        },
        {
            "type": "keyboard",
            "key_char": "l",
            "app_name": "Messages", 
            "timestamp": 1234567893
        },
        {
            "type": "keyboard",
            "key_char": "l",
            "app_name": "Messages",
            "timestamp": 1234567894
        },
        {
            "type": "keyboard",
            "key_char": "o",
            "app_name": "Messages",
            "timestamp": 1234567895
        },
        {
            "type": "keyboard",
            "key_char": "return",
            "app_name": "Messages",
            "timestamp": 1234567896
        }
    ]
    
    print("📝 Input events:")
    print("   - Click iMessage text field")
    print("   - Type 'Hello'")
    print("   - Press Enter")
    
    # Generate blueprint
    blueprint_steps = generate_action_blueprint_only(mock_events)
    
    print("\n📤 Generated blueprint steps:")
    for i, step in enumerate(blueprint_steps, 1):
        print(f"   {i}. {step}")
    
    print("\n✅ Expected blueprint format:")
    print("   1. ACTION: CLICK | target=txt:iMessage | app=Messages")
    print("   2. ACTION: TYPE | text=Hello | app=Messages")
    print("   3. ACTION: PRESS_ENTER | app=Messages")
    
    # Verify format
    if len(blueprint_steps) == 3:
        step1_correct = "ACTION: CLICK | target=txt:iMessage | app=Messages" in blueprint_steps[0]
        step2_correct = "ACTION: TYPE | text=Hello | app=Messages" in blueprint_steps[1]
        step3_correct = "ACTION: PRESS_ENTER | app=Messages" in blueprint_steps[2]
        
        if step1_correct and step2_correct and step3_correct:
            print("\n🎉 SUCCESS: Blueprint generation working correctly!")
        else:
            print("\n❌ FAILED: Blueprint format doesn't match expected")
    else:
        print(f"\n❌ FAILED: Expected 3 steps, got {len(blueprint_steps)}")
    
    # Show what would be saved to file
    print("\n📁 File content that would be saved:")
    print("-" * 40)
    for i, step in enumerate(blueprint_steps, 1):
        print(f"{i}. {step}")
    print("-" * 40)

if __name__ == "__main__":
    test_blueprint_saving()