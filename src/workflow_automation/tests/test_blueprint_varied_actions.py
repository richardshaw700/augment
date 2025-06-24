#!/usr/bin/env python3
"""
Test script to verify blueprint saving with varied action types.
"""

import sys
from pathlib import Path

# Add the project root to the path
project_root = Path(__file__).parent.parent.parent.parent
sys.path.append(str(project_root))

from src.workflow_automation.recording.analysis.summary_generator import generate_action_blueprint_only

def test_varied_actions():
    """Test blueprint generation with different types of actions."""
    
    print("🧪 TESTING BLUEPRINT WITH VARIED ACTIONS")
    print("=" * 50)
    
    # Mock events with various action types
    mock_events = [
        {
            "type": "mouse_click",
            "description": "Clicked on btn:Compose@A-16:2 in Messages",
            "app_name": "Messages",
            "timestamp": 1234567890
        },
        {
            "type": "keyboard",
            "key_char": "T",
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
            "key_char": "s",
            "app_name": "Messages",
            "timestamp": 1234567893
        },
        {
            "type": "keyboard",
            "key_char": "t",
            "app_name": "Messages",
            "timestamp": 1234567894
        },
        {
            "type": "keyboard",
            "key_char": "space",
            "app_name": "Messages",
            "timestamp": 1234567895
        },
        {
            "type": "keyboard",
            "key_char": "m",
            "app_name": "Messages",
            "timestamp": 1234567896
        },
        {
            "type": "keyboard",
            "key_char": "e",
            "app_name": "Messages",
            "timestamp": 1234567897
        },
        {
            "type": "keyboard",
            "key_char": "s",
            "app_name": "Messages",
            "timestamp": 1234567898
        },
        {
            "type": "keyboard",
            "key_char": "s",
            "app_name": "Messages",
            "timestamp": 1234567899
        },
        {
            "type": "keyboard",
            "key_char": "a",
            "app_name": "Messages",
            "timestamp": 1234567900
        },
        {
            "type": "keyboard",
            "key_char": "g",
            "app_name": "Messages",
            "timestamp": 1234567901
        },
        {
            "type": "keyboard",
            "key_char": "e",
            "app_name": "Messages",
            "timestamp": 1234567902
        },
        {
            "type": "keyboard",
            "key_char": "return",
            "app_name": "Messages",
            "timestamp": 1234567903
        },
        {
            "type": "mouse_click",
            "description": "Clicked on txt:Q Search@A-4:6 in Messages",
            "app_name": "Messages",
            "timestamp": 1234567904
        },
        {
            "type": "ui_inspected",
            "app_name": "Messages",
            "timestamp": 1234567905
        }
    ]
    
    print("📝 Input events represent:")
    print("   - Click Compose button")
    print("   - Type 'Test message'")
    print("   - Press Enter")
    print("   - Click Search field")
    print("   - UI Inspection (should be filtered out)")
    
    # Generate blueprint
    blueprint_steps = generate_action_blueprint_only(mock_events)
    
    print("\n📤 Generated blueprint steps:")
    for i, step in enumerate(blueprint_steps, 1):
        print(f"   {i}. {step}")
    
    print(f"\n📊 Summary:")
    print(f"   - Input events: {len(mock_events)}")
    print(f"   - Output actions: {len(blueprint_steps)}")
    print(f"   - UI inspections filtered: {'✅' if len(blueprint_steps) < len(mock_events) else '❌'}")
    
    # Expected actions
    expected_actions = [
        "btn:Compose",  # Compose button click
        "Test message", # Typed text
        "PRESS_ENTER",  # Enter key
        "txt:Q Search"  # Search field click
    ]
    
    print("\n✅ Expected action types found:")
    for expected in expected_actions:
        found = any(expected in step for step in blueprint_steps)
        print(f"   - {expected}: {'✅' if found else '❌'}")

if __name__ == "__main__":
    test_varied_actions()