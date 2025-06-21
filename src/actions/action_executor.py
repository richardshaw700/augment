"""
Base Action Executor for Augment
Handles execution of different types of actions with error handling and logging
"""

import asyncio
import subprocess
import pyautogui
import pyperclip
from datetime import datetime
from typing import Dict, Any, Optional
from dataclasses import dataclass
from abc import ABC, abstractmethod

@dataclass
class ActionResult:
    """Result of executing an action"""
    success: bool
    output: str
    error: Optional[str] = None
    execution_time: float = 0.0
    metadata: Optional[Dict[str, Any]] = None

class BaseActionExecutor(ABC):
    """Base class for action executors"""
    
    def __init__(self, debug: bool = False):
        self.debug = debug
        self.execution_count = 0
    
    @abstractmethod
    async def execute(self, action_data: Dict[str, Any]) -> ActionResult:
        """Execute an action and return result"""
        pass
    
    def log(self, message: str, level: str = "INFO"):
        """Log a message with timestamp"""
        if self.debug or level in ["ERROR", "WARNING"]:
            timestamp = datetime.now().strftime("%H:%M:%S.%f")[:-3]
            print(f"[{timestamp}] [{level}] {message}")

class ActionExecutor(BaseActionExecutor):
    """
    Main action executor that handles all supported actions
    """
    
    def __init__(self, debug: bool = False):
        super().__init__(debug)
        
        # Configure pyautogui
        pyautogui.FAILSAFE = True
        pyautogui.PAUSE = 0.3  # Slightly faster than GPT engine default
        
        # Action handlers
        self.handlers = {
            "click": self._handle_click,
            "type": self._handle_type,
            "key": self._handle_key,
            "bash": self._handle_bash,
            "wait": self._handle_wait,
            "scroll": self._handle_scroll,
            "drag": self._handle_drag
        }
        
        self.log("Action Executor initialized")
    
    async def execute(self, action_data: Dict[str, Any]) -> ActionResult:
        """Execute an action based on the action data"""
        start_time = datetime.now()
        action = action_data.get("action", "")
        
        self.execution_count += 1
        self.log(f"Executing action #{self.execution_count}: {action}")
        
        try:
            if action in self.handlers:
                result = await self.handlers[action](action_data)
            else:
                result = ActionResult(
                    success=False,
                    output="",
                    error=f"Unknown action: {action}"
                )
            
            # Add execution time
            execution_time = (datetime.now() - start_time).total_seconds()
            result.execution_time = execution_time
            
            self.log(f"Action {action} completed in {execution_time:.3f}s")
            return result
            
        except Exception as e:
            execution_time = (datetime.now() - start_time).total_seconds()
            self.log(f"Action {action} failed: {str(e)}", "ERROR")
            
            return ActionResult(
                success=False,
                output="",
                error=f"Action execution failed: {str(e)}",
                execution_time=execution_time
            )
    
    async def _handle_click(self, action_data: Dict[str, Any]) -> ActionResult:
        """Handle click actions"""
        parameters = action_data.get("parameters", {})
        coordinate = parameters.get("coordinate", [0, 0])
        
        if len(coordinate) != 2:
            return ActionResult(
                success=False,
                output="",
                error="Click requires coordinate [x, y]"
            )
        
        x, y = int(coordinate[0]), int(coordinate[1])
        
        # Validate coordinates are within screen bounds
        screen_width, screen_height = pyautogui.size()
        if not (0 <= x <= screen_width and 0 <= y <= screen_height):
            return ActionResult(
                success=False,
                output="",
                error=f"Coordinates ({x}, {y}) outside screen bounds ({screen_width}x{screen_height})"
            )
        
        # Perform click
        await asyncio.to_thread(pyautogui.click, x, y)
        
        return ActionResult(
            success=True,
            output=f"Clicked at ({x}, {y})",
            metadata={"coordinate": [x, y]}
        )
    
    async def _handle_type(self, action_data: Dict[str, Any]) -> ActionResult:
        """Handle typing actions using clipboard paste for speed"""
        parameters = action_data.get("parameters", {})
        text = parameters.get("text", "")
        
        if not text:
            return ActionResult(
                success=False,
                output="",
                error="Type action requires text parameter"
            )
        
        # First try clipboard paste for speed
        try:
            # Store current clipboard content to restore later
            original_clipboard = pyperclip.paste()
            self.log(f"Original clipboard content: '{original_clipboard[:50]}...'", "INFO")
            
            # Set text to clipboard and paste
            pyperclip.copy(text)
            self.log(f"Copied to clipboard: '{text}'", "INFO")
            
            # Verify clipboard content
            clipboard_content = pyperclip.paste()
            if clipboard_content != text:
                raise Exception(f"Clipboard verification failed. Expected: '{text}', Got: '{clipboard_content}'")
            
            self.log("Executing paste command (cmd+v)", "INFO")
            await asyncio.to_thread(pyautogui.hotkey, 'command', 'v')
            
            # Small delay to ensure paste completes
            await asyncio.sleep(0.1)
            
            # Restore original clipboard content
            pyperclip.copy(original_clipboard)
            self.log("Clipboard restored", "INFO")
            
            return ActionResult(
                success=True,
                output=f"Pasted: {text[:50]}{'...' if len(text) > 50 else ''}",
                metadata={"text_length": len(text), "method": "clipboard_paste"}
            )
            
        except Exception as clipboard_error:
            self.log(f"Clipboard paste failed: {clipboard_error}", "INFO")
            # Fallback to character-by-character typing if clipboard fails
            try:
                self.log("Falling back to typing method", "INFO")
                # Use faster interval for fallback typing
                await asyncio.to_thread(pyautogui.write, text, interval=0.01)
                return ActionResult(
                    success=True,
                    output=f"Typed (fallback): {text[:50]}{'...' if len(text) > 50 else ''}",
                    metadata={
                        "text_length": len(text), 
                        "method": "fallback_typing",
                        "clipboard_error": str(clipboard_error)
                    }
                )
            except Exception as typing_error:
                # If both methods fail, return error
                return ActionResult(
                    success=False,
                    output="",
                    error=f"Both clipboard paste and typing failed. Clipboard: {str(clipboard_error)}, Typing: {str(typing_error)}"
                )
    
    async def _handle_key(self, action_data: Dict[str, Any]) -> ActionResult:
        """Handle keyboard key actions"""
        parameters = action_data.get("parameters", {})
        keys = parameters.get("keys", "")
        
        if not keys:
            return ActionResult(
                success=False,
                output="",
                error="Key action requires keys parameter"
            )
        
        # Handle key combinations
        if "+" in keys:
            key_combo = [k.strip() for k in keys.split("+")]
            # Map common key names
            key_mapping = {
                "cmd": "command",
                "ctrl": "ctrl", 
                "alt": "alt",
                "shift": "shift"
            }
            mapped_keys = [key_mapping.get(k.lower(), k) for k in key_combo]
            await asyncio.to_thread(pyautogui.hotkey, *mapped_keys)
        else:
            await asyncio.to_thread(pyautogui.press, keys)
        
        return ActionResult(
            success=True,
            output=f"Pressed keys: {keys}",
            metadata={"keys": keys}
        )
    
    async def _handle_bash(self, action_data: Dict[str, Any]) -> ActionResult:
        """Handle bash command execution"""
        parameters = action_data.get("parameters", {})
        command = parameters.get("command", "")
        
        if not command:
            return ActionResult(
                success=False,
                output="",
                error="Bash action requires command parameter"
            )
        
        try:
            result = await asyncio.create_subprocess_shell(
                command,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            stdout, stderr = await result.communicate()
            
            return ActionResult(
                success=result.returncode == 0,
                output=stdout.decode('utf-8') if stdout else "",
                error=stderr.decode('utf-8') if stderr and result.returncode != 0 else None,
                metadata={"return_code": result.returncode, "command": command}
            )
            
        except Exception as e:
            return ActionResult(
                success=False,
                output="",
                error=f"Failed to execute command: {str(e)}"
            )
    
    async def _handle_wait(self, action_data: Dict[str, Any]) -> ActionResult:
        """Handle wait actions"""
        parameters = action_data.get("parameters", {})
        seconds = parameters.get("seconds", 1)
        
        try:
            seconds = float(seconds)
            if seconds < 0 or seconds > 60:  # Reasonable bounds
                return ActionResult(
                    success=False,
                    output="",
                    error="Wait time must be between 0 and 60 seconds"
                )
            
            await asyncio.sleep(seconds)
            
            return ActionResult(
                success=True,
                output=f"Waited {seconds} seconds",
                metadata={"wait_time": seconds}
            )
            
        except (ValueError, TypeError):
            return ActionResult(
                success=False,
                output="",
                error="Wait time must be a valid number"
            )
    
    async def _handle_scroll(self, action_data: Dict[str, Any]) -> ActionResult:
        """Handle scroll actions"""
        parameters = action_data.get("parameters", {})
        clicks = parameters.get("clicks", 3)
        direction = parameters.get("direction", "down")
        
        try:
            clicks = int(clicks)
            if direction.lower() == "up":
                clicks = -clicks
            
            await asyncio.to_thread(pyautogui.scroll, clicks)
            
            return ActionResult(
                success=True,
                output=f"Scrolled {abs(clicks)} clicks {direction}",
                metadata={"clicks": clicks, "direction": direction}
            )
            
        except (ValueError, TypeError):
            return ActionResult(
                success=False,
                output="",
                error="Scroll clicks must be a valid number"
            )
    
    async def _handle_drag(self, action_data: Dict[str, Any]) -> ActionResult:
        """Handle drag actions"""
        parameters = action_data.get("parameters", {})
        start_coord = parameters.get("start_coordinate", [])
        end_coord = parameters.get("end_coordinate", [])
        
        if len(start_coord) != 2 or len(end_coord) != 2:
            return ActionResult(
                success=False,
                output="",
                error="Drag requires start_coordinate and end_coordinate [x, y]"
            )
        
        x1, y1 = int(start_coord[0]), int(start_coord[1])
        x2, y2 = int(end_coord[0]), int(end_coord[1])
        
        # Validate coordinates
        screen_width, screen_height = pyautogui.size()
        if not all(0 <= x <= screen_width and 0 <= y <= screen_height 
                  for x, y in [(x1, y1), (x2, y2)]):
            return ActionResult(
                success=False,
                output="",
                error="Drag coordinates outside screen bounds"
            )
        
        # Perform drag
        await asyncio.to_thread(pyautogui.drag, x2-x1, y2-y1, 0.5, pyautogui.easeInOutQuad)
        
        return ActionResult(
            success=True,
            output=f"Dragged from ({x1}, {y1}) to ({x2}, {y2})",
            metadata={"start": [x1, y1], "end": [x2, y2]}
        ) 