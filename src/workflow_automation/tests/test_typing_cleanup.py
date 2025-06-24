#!/usr/bin/env python3
"""
Test script to verify typing cleanup with backspace handling.
"""

import sys
from pathlib import Path

# Add the project root to the path
project_root = Path(__file__).parent.parent.parent.parent
sys.path.append(str(project_root))

from src.workflow_automation.recording.analysis.summary_generator import _process_typing_with_backspace, _group_consecutive_keys

def test_backspace_handling():
    """Test that backspaces properly remove previous characters."""
    
    print("🧪 TESTING TYPING CLEANUP WITH BACKSPACE")
    print("=" * 50)
    
    # Test case 1: "Hi! This is a test messagt⌫e"
    mock_events = [
        {"type": "keyboard", "key_char": "H"},
        {"type": "keyboard", "key_char": "i"},
        {"type": "keyboard", "key_char": "!"},
        {"type": "keyboard", "key_char": "space"},
        {"type": "keyboard", "key_char": "T"},
        {"type": "keyboard", "key_char": "h"},
        {"type": "keyboard", "key_char": "i"},
        {"type": "keyboard", "key_char": "s"},
        {"type": "keyboard", "key_char": "space"},
        {"type": "keyboard", "key_char": "i"},
        {"type": "keyboard", "key_char": "s"},
        {"type": "keyboard", "key_char": "space"},
        {"type": "keyboard", "key_char": "a"},
        {"type": "keyboard", "key_char": "space"},
        {"type": "keyboard", "key_char": "t"},
        {"type": "keyboard", "key_char": "e"},
        {"type": "keyboard", "key_char": "s"},
        {"type": "keyboard", "key_char": "t"},
        {"type": "keyboard", "key_char": "space"},
        {"type": "keyboard", "key_char": "m"},
        {"type": "keyboard", "key_char": "e"},
        {"type": "keyboard", "key_char": "s"},
        {"type": "keyboard", "key_char": "s"},
        {"type": "keyboard", "key_char": "a"},
        {"type": "keyboard", "key_char": "g"},
        {"type": "keyboard", "key_char": "t"},
        {"type": "keyboard", "key_char": "delete"},  # Remove 't'
        {"type": "keyboard", "key_char": "e"},
    ]
    
    result = _process_typing_with_backspace(mock_events)
    expected = "Hi! This is a test message"
    
    print(f"📝 Input: 'Hi! This is a test messagt⌫e'")
    print(f"📤 Result: '{result}'")
    print(f"✅ Expected: '{expected}'")
    print(f"🎉 Match: {result == expected}")
    
    print("\n" + "=" * 50)
    
    # Test case 2: All text deleted
    print("📝 Testing complete deletion:")
    delete_all_events = [
        {"type": "keyboard", "key_char": "H"},
        {"type": "keyboard", "key_char": "i"},
        {"type": "keyboard", "key_char": "delete"},  # Remove 'i'
        {"type": "keyboard", "key_char": "delete"},  # Remove 'H'
    ]
    
    delete_result = _process_typing_with_backspace(delete_all_events)
    print(f"📤 Result of 'Hi⌫⌫': '{delete_result}' (should be empty)")
    print(f"🎉 Empty result: {delete_result == ''}")
    
    print("\n" + "=" * 50)
    
    # Test case 2: Test grouping behavior
    print("📝 Testing event grouping:")
    
    # Mix of typing and special keys
    mixed_events = [
        {"type": "keyboard", "key_char": "H"},
        {"type": "keyboard", "key_char": "e"},
        {"type": "keyboard", "key_char": "l"},
        {"type": "keyboard", "key_char": "l"},
        {"type": "keyboard", "key_char": "o"},
        {"type": "keyboard", "key_char": "return"},  # Should be separate
        {"type": "keyboard", "key_char": "W"},
        {"type": "keyboard", "key_char": "o"},
        {"type": "keyboard", "key_char": "r"},
        {"type": "keyboard", "key_char": "l"},
        {"type": "keyboard", "key_char": "d"},
        {"type": "keyboard", "key_char": "delete"},  # Should be separate
        {"type": "keyboard", "key_char": "!"},
    ]
    
    grouped = _group_consecutive_keys(mixed_events)
    
    print(f"📊 Total groups: {len(grouped)}")
    for i, group in enumerate(grouped):
        if len(group) == 1:
            key_char = group[0].get("key_char", "")
            if key_char in ["return", "delete"]:
                print(f"   Group {i+1}: Special key '{key_char}'")
            else:
                print(f"   Group {i+1}: Single char '{key_char}'")
        else:
            chars = [e.get("key_char", "") for e in group]
            processed = _process_typing_with_backspace(group)
            print(f"   Group {i+1}: Typing '{processed}' (from {chars})")
    
    print("\n✅ Events should be grouped as:")
    print("   1. Typing: 'Hello'")
    print("   2. Special: 'return' (Enter)")
    print("   3. Typing: 'World'")
    print("   4. Special: 'delete' (Backspace)")
    print("   5. Typing: '!'")

if __name__ == "__main__":
    test_backspace_handling()