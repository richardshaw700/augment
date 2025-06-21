"""
Base atomic actions that can be composed into sequences.
These are the fundamental building blocks for all UI interactions.
"""

import asyncio
import pyautogui
from typing import Dict, Any, Optional, Tuple
from dataclasses import dataclass


@dataclass
class ActionResult:
    """Result of executing an action"""
    success: bool
    output: str
    error: Optional[str] = None
    ui_state: Optional[Dict] = None
    execution_time: float = 0.0


class BaseActions:
    """Atomic actions that can be combined into sequences"""
    
    def __init__(self):
        # Initialize pyautogui settings
        pyautogui.FAILSAFE = True
        pyautogui.PAUSE = 0.01  # Minimal pause for sequences
    
    async def click(self, coordinates: Tuple[int, int], description: str = "") -> ActionResult:
        """Execute a click action at specific coordinates"""
        import time
        start_time = time.time()
        
        try:
            x, y = coordinates
            await asyncio.to_thread(pyautogui.click, x, y)
            
            execution_time = time.time() - start_time
            return ActionResult(
                success=True,
                output=f"Clicked at ({x}, {y})" + (f" - {description}" if description else ""),
                execution_time=execution_time
            )
        except Exception as e:
            execution_time = time.time() - start_time
            return ActionResult(
                success=False,
                output="",
                error=f"Click failed: {str(e)}",
                execution_time=execution_time
            )
    
    async def type_text(self, text: str, interval: float = 0.001) -> ActionResult:
        """Execute a type action with specified text"""
        import time
        start_time = time.time()
        
        try:
            await asyncio.to_thread(pyautogui.write, text, interval=interval)
            
            execution_time = time.time() - start_time
            return ActionResult(
                success=True,
                output=f"Typed: {text}",
                execution_time=execution_time
            )
        except Exception as e:
            execution_time = time.time() - start_time
            return ActionResult(
                success=False,
                output="",
                error=f"Type failed: {str(e)}",
                execution_time=execution_time
            )
    
    async def press_key(self, keys: str) -> ActionResult:
        """Execute a key press action"""
        import time
        start_time = time.time()
        
        try:
            if "+" in keys:
                # Handle key combinations (e.g., "cmd+c")
                key_parts = keys.split("+")
                await asyncio.to_thread(pyautogui.hotkey, *key_parts)
            else:
                # Handle single keys
                key_map = {
                    "Return": "enter",
                    "Enter": "enter",
                    "Escape": "escape",
                    "Tab": "tab",
                    "Space": "space",
                    "Backspace": "backspace",
                    "Delete": "delete"
                }
                mapped_key = key_map.get(keys, keys.lower())
                await asyncio.to_thread(pyautogui.press, mapped_key)
            
            execution_time = time.time() - start_time
            return ActionResult(
                success=True,
                output=f"Pressed keys: {keys}",
                execution_time=execution_time
            )
        except Exception as e:
            execution_time = time.time() - start_time
            return ActionResult(
                success=False,
                output="",
                error=f"Key press failed: {str(e)}",
                execution_time=execution_time
            )
    
    async def wait(self, seconds: float) -> ActionResult:
        """Execute a wait action"""
        import time
        start_time = time.time()
        
        try:
            await asyncio.sleep(seconds)
            
            execution_time = time.time() - start_time
            return ActionResult(
                success=True,
                output=f"Waited {seconds}s",
                execution_time=execution_time
            )
        except Exception as e:
            execution_time = time.time() - start_time
            return ActionResult(
                success=False,
                output="",
                error=f"Wait failed: {str(e)}",
                execution_time=execution_time
            ) 