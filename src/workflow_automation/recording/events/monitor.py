"""
System Event Monitor for macOS using Quartz Event Taps.
Captures mouse clicks, keyboard input, and scroll events.
"""

import time
import threading
from typing import Callable, Optional

try:
    import Quartz
    from Cocoa import NSApplication, NSRunLoop, NSDefaultRunLoopMode
    QUARTZ_AVAILABLE = True
except ImportError:
    QUARTZ_AVAILABLE = False

from ..models import SystemEvent, EventType
from .permissions import get_frontmost_app_name

class EventMonitor:
    """
    Monitors system-level events (mouse, keyboard) on macOS.
    This class is responsible only for capturing raw event data.
    """
    
    def __init__(self, callback: Callable[[SystemEvent], None]):
        if not QUARTZ_AVAILABLE:
            raise ImportError("The 'pyobjc' library is not installed. Please run 'pip install pyobjc'.")
            
        self.callback = callback
        self.is_monitoring = False
        self.event_tap = None
        self.run_loop_source = None
        self.monitor_thread = None
        self.run_loop_ref = None
        self.modifier_flags = 0  # Track current modifier key state
        
        # Sticky app detection to fix keyboard/scroll attribution
        self.last_clicked_app = None

    def start(self):
        """Starts monitoring system events in a separate thread."""
        if self.is_monitoring:
            return

        self.monitor_thread = threading.Thread(target=self._run_event_loop, daemon=True)
        self.monitor_thread.start()
        self.is_monitoring = True
        print("👁️ EventMonitor: Started monitoring system events.")

    def stop(self):
        """Stops monitoring system events."""
        if not self.is_monitoring:
            return
            
        self.is_monitoring = False
        if self.run_loop_ref:
            Quartz.CFRunLoopStop(self.run_loop_ref)
        
        print("🛑 EventMonitor: Stopped monitoring.")

    def _run_event_loop(self):
        """The main run loop for the event tap, executed in a thread."""
        self.event_tap = Quartz.CGEventTapCreate(
            Quartz.kCGSessionEventTap,
            Quartz.kCGHeadInsertEventTap,
            Quartz.kCGEventTapOptionListenOnly,
            Quartz.CGEventMaskBit(Quartz.kCGEventLeftMouseDown) |
            Quartz.CGEventMaskBit(Quartz.kCGEventRightMouseDown) |
            Quartz.CGEventMaskBit(Quartz.kCGEventKeyDown) |
            Quartz.CGEventMaskBit(Quartz.kCGEventScrollWheel) |
            Quartz.CGEventMaskBit(Quartz.kCGEventFlagsChanged),
            self._event_callback,
            None
        )

        if not self.event_tap:
            raise RuntimeError("Failed to create event tap. Check macOS permissions.")

        self.run_loop_source = Quartz.CFMachPortCreateRunLoopSource(None, self.event_tap, 0)
        Quartz.CFRunLoopAddSource(Quartz.CFRunLoopGetCurrent(), self.run_loop_source, Quartz.kCFRunLoopDefaultMode)
        Quartz.CGEventTapEnable(self.event_tap, True)

        # Store a reference to this thread's run loop and run it until explicitly stopped.
        self.run_loop_ref = Quartz.CFRunLoopGetCurrent()
        Quartz.CFRunLoopRun()

    def _event_callback(self, proxy, event_type_code, event, user_info):
        """
        The callback that receives events from the OS.
        It converts the raw CGEvent into a structured SystemEvent.
        """
        # If monitoring has been stopped, this callback's job is to stop the run loop.
        if not self.is_monitoring:
            if self.run_loop_ref:
                Quartz.CFRunLoopStop(self.run_loop_ref)
            return None # Do not process this final event

        try:
            system_event = self._convert_cg_event(event_type_code, event)
            if system_event:
                self.callback(system_event)
        except Exception as e:
            print(f"❌ EventMonitor: Error processing event: {e}")
        
        return event  # Pass the event along

    def _convert_cg_event(self, event_type_code, event) -> Optional[SystemEvent]:
        """Converts a raw CGEvent into our internal SystemEvent model."""
        timestamp = time.time()
        
        if event_type_code in [Quartz.kCGEventLeftMouseDown, Quartz.kCGEventRightMouseDown]:
            event_type = EventType.MOUSE_CLICK
            location = Quartz.CGEventGetLocation(event)
            button = "left" if event_type_code == Quartz.kCGEventLeftMouseDown else "right"
            
            # For clicks, try coordinate-based detection first, fallback to frontmost app
            click_app_name = self._get_app_at_coordinates(int(location.x), int(location.y))
            frontmost_app = get_frontmost_app_name()  # Get frontmost for comparison
            
            if click_app_name and click_app_name not in ['Window Server', 'Dock', 'SystemUIServer']:
                app_name = click_app_name
                print(f"🖱️ CLICK EVENT DEBUG: Using coordinate detection: {app_name} | Frontmost app was: {frontmost_app}")
            else:
                # Fallback: add delay and check frontmost app
                time.sleep(0.1)
                app_name = get_frontmost_app_name()
                print(f"🖱️ CLICK EVENT DEBUG: Coordinate detection failed, using frontmost app: {app_name}")
                print(f"   Failed coordinate detection result: {click_app_name}")
            
            # Update sticky app tracking for subsequent keyboard/scroll events
            self.last_clicked_app = app_name
            print(f"📌 STICKY APP: Updated last clicked app to {app_name}")
            
            data = {
                "app_name": app_name,
                "coordinates": (int(location.x), int(location.y)),
                "button": button
            }
            description = f"Mouse {button} click at {data['coordinates']}"

        elif event_type_code == Quartz.kCGEventKeyDown:
            event_type = EventType.KEYBOARD
            key_code = Quartz.CGEventGetIntegerValueField(event, Quartz.kCGKeyboardEventKeycode)
            key_char = self._key_code_to_char(key_code, self.modifier_flags)
            
            # For keyboard events, use sticky app detection
            frontmost_app = get_frontmost_app_name()
            if self.last_clicked_app:
                app_name = self.last_clicked_app
                print(f"⌨️ KEYBOARD EVENT DEBUG: Key '{key_char}' -> Using sticky app: {app_name} | Frontmost was: {frontmost_app}")
            else:
                app_name = frontmost_app
                print(f"⌨️ KEYBOARD EVENT DEBUG: Key '{key_char}' -> No sticky app, using frontmost: {app_name}")
            
            data = {
                "app_name": app_name,
                "key_code": key_code,
                "key_char": key_char
            }
            description = f"Key press: '{key_char}'"

        elif event_type_code == Quartz.kCGEventFlagsChanged:
            # Update modifier flags but don't create a SystemEvent for modifier-only changes
            self.modifier_flags = Quartz.CGEventGetFlags(event)
            return None

        elif event_type_code == Quartz.kCGEventScrollWheel:
            event_type = EventType.MOUSE_SCROLL
            delta_y = Quartz.CGEventGetIntegerValueField(event, Quartz.kCGScrollWheelEventDeltaAxis1)
            delta_x = Quartz.CGEventGetIntegerValueField(event, Quartz.kCGScrollWheelEventDeltaAxis2)
            
            # Filter out very small scroll events (noise/accidental)
            if abs(delta_x) < 2 and abs(delta_y) < 2:
                return None  # Skip noise scroll events
            
            # For scroll events, use sticky app detection
            frontmost_app = get_frontmost_app_name()
            if self.last_clicked_app:
                app_name = self.last_clicked_app
                print(f"🖱️ SCROLL EVENT DEBUG: Delta ({delta_x}, {delta_y}) -> Using sticky app: {app_name} | Frontmost was: {frontmost_app}")
            else:
                app_name = frontmost_app
                print(f"🖱️ SCROLL EVENT DEBUG: Delta ({delta_x}, {delta_y}) -> No sticky app, using frontmost: {app_name}")
            
            data = {
                "app_name": app_name,
                "scroll_delta": (delta_x, delta_y)
            }
            description = f"Scroll with delta {data['scroll_delta']}"
            
        else:
            return None # Ignore other event types

        return SystemEvent(
            event_type=event_type,
            timestamp=timestamp,
            data=data,
            description=description
        )

    def _get_app_at_coordinates(self, x: int, y: int) -> Optional[str]:
        """
        Determines which application window is at the given screen coordinates.
        This helps avoid race conditions when app focus changes immediately after a click.
        """
        try:
            # Get the window info at the specified coordinates
            window_info = Quartz.CGWindowListCopyWindowInfo(
                Quartz.kCGWindowListOptionOnScreenOnly | Quartz.kCGWindowListExcludeDesktopElements,
                Quartz.kCGNullWindowID
            )
            
            print(f"🎯 Checking coordinates ({x}, {y}) for app...")  # Debug
            
            # Debug: Show all windows at these coordinates
            windows_at_point = []
            
            # Find the topmost window at the coordinates, skip system windows
            for window in window_info:
                owner_name = window.get('kCGWindowOwnerName')
                
                window_bounds = window.get('kCGWindowBounds', {})
                if not window_bounds:
                    continue
                
                window_x = window_bounds.get('X', 0)
                window_y = window_bounds.get('Y', 0) 
                window_width = window_bounds.get('Width', 0)
                window_height = window_bounds.get('Height', 0)
                
                # Check if coordinates are within this window
                if (window_x <= x <= window_x + window_width and 
                    window_y <= y <= window_y + window_height):
                    
                    layer = window.get('kCGWindowLayer', 0)
                    windows_at_point.append((owner_name, layer))
            
            # Enhanced debug output showing full window stack
            print(f"📱 Windows at ({x}, {y}): {windows_at_point}")
            print(f"🔍 Full window stack analysis:")
            for i, (owner_name, layer) in enumerate(windows_at_point):
                status = "SELECTED" if i == 0 and owner_name not in ['Window Server', 'Dock', 'SystemUIServer', 'Screenshot'] else "SKIPPED"
                print(f"   {i+1}. {owner_name} (layer {layer}) - {status}")
            
            # Filter and return the best app, skipping system windows
            for owner_name, layer in windows_at_point:
                if not owner_name:
                    continue
                    
                # Skip system windows and screenshot overlays
                if owner_name in ['Window Server', 'Dock', 'SystemUIServer']:
                    continue
                    
                # If it's Screenshot, skip to the next one (the real app underneath)
                if owner_name == 'Screenshot':
                    continue
                    
                print(f"✅ Found app at coordinates: {owner_name} (layer {layer})")  # Debug
                return owner_name
            
            print(f"⚠️ No suitable app found at coordinates ({x}, {y})")  # Debug
            return None
            
        except Exception as e:
            print(f"❌ Error getting app at coordinates ({x}, {y}): {e}")
            return None

    def _key_code_to_char(self, key_code: int, modifier_flags: int = 0) -> str:
        """Converts a key code to a character using a simple mapping for US keyboards."""
        
        # Check if shift key is pressed
        shift_pressed = bool(modifier_flags & Quartz.kCGEventFlagMaskShift)
        
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