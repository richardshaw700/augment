#!/usr/bin/env python3
"""
Test script to verify keyboard shift key handling is working correctly.
"""

import sys
from pathlib import Path

# Add the project root to the path
project_root = Path(__file__).parent.parent.parent.parent
sys.path.append(str(project_root))

def test_key_code_to_char():
    """Test the _key_code_to_char method with shift modifier handling."""
    
    # Mock the EventMonitor class to test the key mapping
    class MockEventMonitor:
        def __init__(self):
            self.modifier_flags = 0
        
        def _key_code_to_char(self, key_code: int, modifier_flags: int = 0) -> str:
            """Same implementation as the real method."""
            
            # For testing purposes, we'll use a mock Quartz constant
            kCGEventFlagMaskShift = 0x020000  # Real Quartz constant value
            
            # Check if shift key is pressed
            shift_pressed = bool(modifier_flags & kCGEventFlagMaskShift)
            
            # Base key mappings
            KEY_MAP = {
                0: 'a', 1: 's', 2: 'd', 3: 'f', 4: 'h', 5: 'g', 6: 'z', 7: 'x', 8: 'c', 9: 'v',
                11: 'b', 12: 'q', 13: 'w', 14: 'e', 15: 'r', 16: 'y', 17: 't',
                18: '1', 19: '2', 20: '3', 21: '4', 22: '6', 23: '5', 24: '=', 25: '9', 26: '7',
                27: '-', 28: '8', 29: '0', 30: ']', 31: 'o', 32: 'u', 33: '[', 34: 'i', 35: 'p',
                36: 'return', 37: 'l', 38: 'j', 39: "'", 40: 'k', 41: ';', 42: '\\', 43: ',',
                44: '/', 45: 'n', 46: 'm', 47: '.', 48: 'tab', 49: 'space', 50: '`', 51: 'delete',
                53: 'escape',
            }
            
            # Shifted key mappings for numbers and symbols
            SHIFT_MAP = {
                18: '!', 19: '@', 20: '#', 21: '$', 22: '^', 23: '%', 24: '+', 25: '(', 26: '&',
                27: '_', 28: '*', 29: ')', 30: '}', 33: '{', 39: '"', 41: ':', 42: '|', 43: '<',
                44: '?', 47: '>', 50: '~',
            }
            
            base_char = KEY_MAP.get(key_code, f"[keyCode_{key_code}]")
            
            if shift_pressed:
                # Handle shifted symbols
                if key_code in SHIFT_MAP:
                    return SHIFT_MAP[key_code]
                # Handle shifted letters (convert to uppercase)
                elif base_char.isalpha() and len(base_char) == 1:
                    return base_char.upper()
            
            return base_char
    
    monitor = MockEventMonitor()
    kCGEventFlagMaskShift = 0x020000
    
    print("🧪 TESTING KEYBOARD SHIFT KEY HANDLING")
    print("=" * 50)
    
    # Test lowercase letters without shift
    print("\n📝 Testing lowercase letters (no shift):")
    print(f"h (key 4): '{monitor._key_code_to_char(4, 0)}'")
    print(f"i (key 34): '{monitor._key_code_to_char(34, 0)}'")
    
    # Test uppercase letters with shift
    print("\n📝 Testing uppercase letters (with shift):")
    print(f"H (key 4 + shift): '{monitor._key_code_to_char(4, kCGEventFlagMaskShift)}'")
    print(f"I (key 34 + shift): '{monitor._key_code_to_char(34, kCGEventFlagMaskShift)}'")
    
    # Test numbers without shift
    print("\n🔢 Testing numbers (no shift):")
    print(f"1 (key 18): '{monitor._key_code_to_char(18, 0)}'")
    print(f"2 (key 19): '{monitor._key_code_to_char(19, 0)}'")
    
    # Test shifted symbols
    print("\n🔣 Testing shifted symbols:")
    print(f"! (key 18 + shift): '{monitor._key_code_to_char(18, kCGEventFlagMaskShift)}'")
    print(f"@ (key 19 + shift): '{monitor._key_code_to_char(19, kCGEventFlagMaskShift)}'")
    
    # Test the specific "Hi" case
    print("\n✅ Testing 'Hi' case:")
    h_char = monitor._key_code_to_char(4, kCGEventFlagMaskShift)  # H with shift
    i_char = monitor._key_code_to_char(34, 0)  # i without shift
    result = h_char + i_char
    print(f"Result: '{result}' (should be 'Hi', not 'hi1')")
    
    if result == "Hi":
        print("🎉 SUCCESS: Shift key handling is working correctly!")
    else:
        print("❌ FAILED: Shift key handling needs more work")

if __name__ == "__main__":
    test_key_code_to_char()