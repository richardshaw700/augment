"""
System-related action executors (bash, key, wait, scroll)
"""

import asyncio
import pyautogui
import subprocess
from typing import Dict, Any

from .base import ActionResult


class SystemActionExecutor:
    """Handles system-related actions like keyboard, bash commands, and waiting"""
    
    def __init__(self, action_executor=None):
        self.action_executor = action_executor
    
    async def execute_key(self, keys: str) -> ActionResult:
        """Execute a keyboard action"""
        # Handle key combinations
        if "+" in keys:
            key_combo = keys.split("+")
            pyautogui.hotkey(*key_combo)
        else:
            pyautogui.press(keys)
        
        return ActionResult(
            success=True,
            output=f"Pressed keys: {keys}"
        )
    
    async def execute_bash(self, command: str) -> ActionResult:
        """Execute a bash command"""
        try:
            result = subprocess.run(
                command,
                shell=True,
                capture_output=True,
                text=True,
                timeout=30
            )
            success = result.returncode == 0
            return ActionResult(
                success=success,
                output=result.stdout,
                error=result.stderr if result.returncode != 0 else None
            )
        except subprocess.TimeoutExpired:
            return ActionResult(
                success=False,
                output="",
                error="Command timed out after 30 seconds"
            )
        except Exception as e:
            return ActionResult(
                success=False,
                output="",
                error=f"Command execution failed: {str(e)}"
            )
    
    async def execute_wait(self, seconds: float) -> ActionResult:
        """Execute a wait action"""
        await asyncio.sleep(seconds)
        return ActionResult(
            success=True,
            output=f"Waited {seconds} seconds"
        )
    
    async def execute_scroll(self, direction: str, amount) -> ActionResult:
        """Execute a scroll action - handles both int and float amounts"""
        # Use the ActionExecutor's scroll method if available
        if self.action_executor and hasattr(self.action_executor, 'execute_scroll'):
            return await self.action_executor.execute_scroll(direction, amount)
        
        # Fallback basic scroll implementation
        try:
            # Convert amount to int, handling both int and float inputs
            # For pixel-based scrolling, we scale down large values
            if isinstance(amount, (int, float)):
                if amount > 50:  # Large pixel values - scale down for scroll clicks
                    scroll_clicks = max(1, int(amount / 100))  # 1 click per 100 pixels
                else:
                    scroll_clicks = max(1, int(amount))  # Small values - ensure at least 1 click
            else:
                scroll_clicks = 3  # Default fallback
            
            if direction.lower() == "down":
                pyautogui.scroll(-scroll_clicks)
            elif direction.lower() == "up":
                pyautogui.scroll(scroll_clicks)
            elif direction.lower() == "left":
                pyautogui.hscroll(-scroll_clicks)
            elif direction.lower() == "right":
                pyautogui.hscroll(scroll_clicks)
            else:
                return ActionResult(
                    success=False,
                    output="",
                    error=f"Unknown scroll direction: {direction}"
                )
            
            return ActionResult(
                success=True,
                output=f"Scrolled {direction} by {amount} ({scroll_clicks} clicks)"
            )
        except Exception as e:
            return ActionResult(
                success=False,
                output="",
                error=f"Scroll failed: {str(e)}"
            )