#!/usr/bin/env python3
"""
Simple test script to debug keyboard event capture
"""
import sys
import time
from pathlib import Path

# Add src to path
src_path = Path(__file__).parent / "src"
sys.path.insert(0, str(src_path))

from workflow_automation.recording.events.monitor import EventMonitor
from workflow_automation.recording.models import SystemEvent, EventType

class TestCallback:
    def __init__(self):
        self.events = []
    
    def __call__(self, event: SystemEvent):
        self.events.append(event)
        print(f"🎯 Captured event: {event.event_type.value} - {event.description}")
        if event.event_type == EventType.KEYBOARD:
            print(f"   Key details: {event.data}")

def main():
    print("🧪 Testing keyboard event capture...")
    print("Type some keys and then press Ctrl+C to stop")
    print("=" * 50)
    
    callback = TestCallback()
    monitor = EventMonitor(callback)
    
    try:
        monitor.start()
        print("✅ Monitor started. Waiting for events...")
        
        # Wait for events
        time.sleep(10)  # Monitor for 10 seconds
        
    except KeyboardInterrupt:
        print("\n🛑 Stopping monitor...")
    finally:
        monitor.stop()
        
    print(f"\n📊 Results: Captured {len(callback.events)} events")
    
    # Count event types
    keyboard_events = [e for e in callback.events if e.event_type == EventType.KEYBOARD]
    mouse_events = [e for e in callback.events if e.event_type == EventType.MOUSE_CLICK]
    scroll_events = [e for e in callback.events if e.event_type == EventType.MOUSE_SCROLL]
    
    print(f"   Keyboard events: {len(keyboard_events)}")
    print(f"   Mouse events: {len(mouse_events)}")
    print(f"   Scroll events: {len(scroll_events)}")
    
    if keyboard_events:
        print("\n🎹 Keyboard events captured:")
        for event in keyboard_events[:5]:  # Show first 5
            print(f"   {event.description}")
    else:
        print("\n❌ No keyboard events captured!")

if __name__ == "__main__":
    main()