"""
UI Inspector Tool for Claude Computer Use
Captures UI structure as JSON instead of expensive screenshots
"""
import asyncio
import json
import subprocess
from datetime import datetime
from typing import Literal, Dict, List, Any
from .base import BaseAnthropicTool, ToolResult, ToolError

class UIInspectorTool(BaseAnthropicTool):
    """
    Captures UI structure as structured JSON data.
    Much more cost-effective than screenshots and provides precise element information.
    """
    
    name: Literal["ui_inspector"] = "ui_inspector"
    
    def to_params(self):
        return {
            "name": self.name,
            "description": (
                "Capture the current screen's UI structure as JSON data including all clickable elements, "
                "their positions, states, labels, and properties. More cost-effective and precise than screenshots. "
                "Use this to understand what UI elements are available for interaction."
            ),
            "input_schema": {
                "type": "object",
                "properties": {
                    "app_name": {
                        "type": "string",
                        "description": "Optional: Focus on specific application (e.g. 'Safari', 'Finder')"
                    },
                    "include_system_ui": {
                        "type": "boolean", 
                        "description": "Include menu bar, dock, and system UI elements",
                        "default": False
                    }
                },
                "additionalProperties": False,
            }
        }
    
    async def __call__(self, *, app_name: str | None = None, include_system_ui: bool = False, **kwargs):
        timestamp = datetime.now().strftime("%H:%M:%S.%f")[:-3]
        print(f"[{timestamp}] ### Inspecting UI structure{f' for {app_name}' if app_name else ''}")
        
        try:
            # Method 1: Use macOS Accessibility Inspector via command line
            ui_data = await self._get_accessibility_tree(app_name, include_system_ui)
            
            # Method 2: Fallback to system_profiler for basic window info
            if not ui_data.get("elements"):
                ui_data = await self._get_window_info()
            
            return ToolResult(
                output=json.dumps(ui_data, indent=2),
                system="UI structure captured as JSON - no image tokens used"
            )
            
        except Exception as e:
            return ToolResult(error=f"UI inspection failed: {str(e)}")
    
    async def _get_accessibility_tree(self, app_name: str | None, include_system_ui: bool) -> Dict[str, Any]:
        """Get UI structure using macOS Accessibility APIs"""
        try:
            # Use accessibility-dump tool (need to install: npm install -g accessibility-dump)
            cmd = ["accessibility-dump"]
            
            if app_name:
                cmd.extend(["--app", app_name])
            
            if not include_system_ui:
                cmd.append("--no-system")
            
            result = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            stdout, stderr = await result.communicate()
            
            if result.returncode == 0:
                ui_data = json.loads(stdout.decode('utf-8'))
                return self._process_accessibility_data(ui_data)
            else:
                # Fallback to AppleScript method
                return await self._get_ui_applescript(app_name)
                
        except Exception:
            # Fallback method
            return await self._get_ui_applescript(app_name)
    
    async def _get_ui_applescript(self, app_name: str | None) -> Dict[str, Any]:
        """Fallback method using AppleScript to get UI information"""
        applescript = f'''
        tell application "System Events"
            set uiElements to {{}}
            
            {'tell application "' + app_name + '" to activate' if app_name else ''}
            
            set frontApp to first application process whose frontmost is true
            set appName to name of frontApp
            
            tell frontApp
                set windowList to windows
                set windowData to {{}}
                
                repeat with w in windowList
                    try
                        set windowInfo to {{}}
                        set windowInfo to windowInfo & {{"title": (title of w)}}
                        set windowInfo to windowInfo & {{"position": (position of w)}}
                        set windowInfo to windowInfo & {{"size": (size of w)}}
                        
                        -- Get buttons
                        set buttonList to buttons of w
                        set buttonData to {{}}
                        repeat with b in buttonList
                            try
                                set buttonInfo to {{}}
                                set buttonInfo to buttonInfo & {{"title": (title of b)}}
                                set buttonInfo to buttonInfo & {{"position": (position of b)}}
                                set buttonInfo to buttonInfo & {{"size": (size of b)}}
                                set buttonInfo to buttonInfo & {{"enabled": (enabled of b)}}
                                set end of buttonData to buttonInfo
                            end try
                        end repeat
                        set windowInfo to windowInfo & {{"buttons": buttonData}}
                        
                        -- Get text fields
                        set textFieldList to text fields of w
                        set textFieldData to {{}}
                        repeat with t in textFieldList
                            try
                                set textInfo to {{}}
                                set textInfo to textInfo & {{"value": (value of t)}}
                                set textInfo to textInfo & {{"position": (position of t)}}
                                set textInfo to textInfo & {{"size": (size of t)}}
                                set end of textFieldData to textInfo
                            end try
                        end repeat
                        set windowInfo to windowInfo & {{"textFields": textFieldData}}
                        
                        set end of windowData to windowInfo
                    end try
                end repeat
                
                return {{"app": appName, "windows": windowData}}
            end tell
        end tell
        '''
        
        try:
            result = await asyncio.create_subprocess_exec(
                "osascript", "-e", applescript,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            stdout, stderr = await result.communicate()
            
            if result.returncode == 0:
                output = stdout.decode('utf-8').strip()
                # Parse AppleScript output (this is simplified - real parsing would be more complex)
                return {
                    "method": "applescript",
                    "timestamp": datetime.now().isoformat(),
                    "raw_output": output
                }
            else:
                return await self._get_window_info()
                
        except Exception:
            return await self._get_window_info()
    
    async def _get_window_info(self) -> Dict[str, Any]:
        """Basic window information using system commands"""
        try:
            # Get window list using yabai or similar (if installed)
            result = await asyncio.create_subprocess_exec(
                "yabai", "-m", "query", "--windows",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            stdout, stderr = await result.communicate()
            
            if result.returncode == 0:
                windows = json.loads(stdout.decode('utf-8'))
                return {
                    "method": "yabai",
                    "timestamp": datetime.now().isoformat(),
                    "windows": windows
                }
            else:
                # Final fallback - basic system info
                return await self._get_basic_system_info()
                
        except Exception:
            return await self._get_basic_system_info()
    
    async def _get_basic_system_info(self) -> Dict[str, Any]:
        """Most basic system information"""
        try:
            # Get frontmost app
            applescript = '''
            tell application "System Events"
                set frontApp to first application process whose frontmost is true
                return name of frontApp
            end tell
            '''
            
            result = await asyncio.create_subprocess_exec(
                "osascript", "-e", applescript,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            stdout, stderr = await result.communicate()
            
            frontmost_app = stdout.decode('utf-8').strip() if result.returncode == 0 else "Unknown"
            
            return {
                "method": "basic",
                "timestamp": datetime.now().isoformat(),
                "frontmost_app": frontmost_app,
                "message": "Limited UI information available. Install accessibility tools for better data.",
                "suggestions": [
                    "Install yabai: brew install koekeishiya/formulae/yabai",
                    "Install accessibility-dump: npm install -g accessibility-dump",
                    "Enable accessibility permissions in System Preferences"
                ]
            }
            
        except Exception as e:
            return {
                "method": "error",
                "timestamp": datetime.now().isoformat(),
                "error": str(e)
            }
    
    def _process_accessibility_data(self, raw_data: Dict[str, Any]) -> Dict[str, Any]:
        """Process and structure accessibility data for Claude"""
        processed = {
            "timestamp": datetime.now().isoformat(),
            "method": "accessibility_api",
            "ui_elements": []
        }
        
        # This would process the raw accessibility data into a structured format
        # Extract clickable elements, their positions, states, etc.
        
        return processed 