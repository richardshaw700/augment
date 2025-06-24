#!/usr/bin/env python3
"""
Test script to verify action blueprint cleanup.
"""

import sys
from pathlib import Path

# Add the project root to the path
project_root = Path(__file__).parent.parent.parent.parent
sys.path.append(str(project_root))

from src.workflow_automation.recording.analysis.summary_generator import _generate_action_blueprint

def test_blueprint_cleanup():
    """Test that action blueprint properly filters and cleans up events."""
    
    print("🧪 TESTING ACTION BLUEPRINT CLEANUP")
    print("=" * 50)
    
    # Mock events based on the problematic timeline
    mock_events = [
        {
            "type": "mouse_click",
            "description": "Clicked on an unnamed element in Messages",
            "app_name": "Messages",
            "timestamp": 1234567890
        },
        {
            "type": "mouse_click", 
            "description": "Clicked on iMessage@A-24:49 in Messages",
            "app_name": "Messages",
            "timestamp": 1234567892
        },
        {
            "type": "keyboard",
            "key_char": "H",
            "app_name": "Messages",
            "timestamp": 1234567894
        },
        {
            "type": "keyboard",
            "key_char": "e",
            "app_name": "Messages",
            "timestamp": 1234567895
        },
        {
            "type": "keyboard",
            "key_char": "l",
            "app_name": "Messages",
            "timestamp": 1234567896
        },
        {
            "type": "keyboard",
            "key_char": "l",
            "app_name": "Messages",
            "timestamp": 1234567897
        },
        {
            "type": "keyboard",
            "key_char": "o",
            "app_name": "Messages",
            "timestamp": 1234567898
        },
        {
            "type": "keyboard",
            "key_char": "!",
            "app_name": "Messages",
            "timestamp": 1234567899
        },
        {
            "type": "keyboard",
            "key_char": "space",
            "app_name": "Messages",
            "timestamp": 1234567900
        },
        {
            "type": "keyboard",
            "key_char": "T",
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
            "key_char": "s",
            "app_name": "Messages",
            "timestamp": 1234567903
        },
        {
            "type": "keyboard",
            "key_char": "t",
            "app_name": "Messages",
            "timestamp": 1234567904
        },
        {
            "type": "keyboard",
            "key_char": "return",
            "app_name": "Messages",
            "timestamp": 1234567905
        },
        {
            "type": "mouse_click",
            "description": "Clicked on txt:Q Search@A-4:6 in Messages",
            "app_name": "Messages", 
            "timestamp": 1234567906
        },
        {
            "type": "mouse_click",
            "description": "Clicked on iMessage@A-24:49 in Messages",
            "app_name": "Messages",
            "timestamp": 1234567907
        },
        {
            "type": "mouse_click",
            "description": "Clicked on an unnamed element in augment",
            "app_name": "augment",
            "timestamp": 1234567908
        }
    ]
    
    print("📝 Input events:")
    print("   - Click unnamed element")
    print("   - Click iMessage")
    print("   - Type 'Hello! Test'")
    print("   - Press Enter")
    print("   - Click Q Search")
    print("   - Click iMessage")
    print("   - Click unnamed element")
    
    blueprint = _generate_action_blueprint(mock_events)
    print("\n📤 Generated blueprint:")
    print(blueprint)
    
    print("✅ Expected improvements:")
    print("   - Unnamed elements should be filtered out")
    print("   - Enter key should be skipped")
    print("   - Typing should be clean without backspace artifacts")
    print("   - 'txt:Q' should be 'txt:Q Search'")

if __name__ == "__main__":
    test_blueprint_cleanup()