"""
UI-related action executors (click, type, ui_inspect)
"""

import asyncio
import pyautogui
import re
from typing import Dict, Any, Optional
from pathlib import Path
import subprocess
import json
from datetime import datetime

from .base import ActionResult
from .coordinate_utils import CoordinateUtils


class UIActionExecutor:
    """Handles UI-related actions like clicking, typing, and UI inspection"""
    
    def __init__(self, ui_inspector_path: Path):
        self.ui_inspector_path = ui_inspector_path
        self._last_ui_state = None
        
        # Initialize pyautogui settings
        pyautogui.FAILSAFE = True
        pyautogui.PAUSE = 0.5
    
    async def execute_ui_inspect(self) -> ActionResult:
        """Get current UI state using the Swift UI inspector"""
        try:
            result = subprocess.run(
                [str(self.ui_inspector_path)],
                capture_output=True,
                text=True,
                timeout=10
            )
            
            if result.returncode == 0:
                # Parse the UI inspector output looking for JSON between markers
                lines = result.stdout.strip().split('\n')
                json_started = False
                json_lines = []
                
                # Also capture performance breakdown
                ui_performance_breakdown = self._parse_ui_performance_breakdown(result.stdout)
                
                for line in lines:
                    if line.strip() == "JSON_OUTPUT_START":
                        json_started = True
                        continue
                    elif line.strip() == "JSON_OUTPUT_END":
                        break
                    elif json_started:
                        json_lines.append(line)
                
                if json_lines:
                    json_content = '\n'.join(json_lines)
                    ui_data = json.loads(json_content)
                    # Store the performance breakdown for later use
                    ui_data['_ui_performance_breakdown'] = ui_performance_breakdown
                    
                    # Store UI state for smart focus detection
                    self._last_ui_state = ui_data
                    
                    return ActionResult(
                        success=True,
                        output="UI state captured",
                        ui_state=ui_data
                    )
                else:
                    return ActionResult(
                        success=False,
                        output="",
                        error="No JSON data found in UI inspector output"
                    )
            else:
                return ActionResult(
                    success=False,
                    output="",
                    error=f"UI inspector failed: {result.stderr}"
                )
                
        except subprocess.TimeoutExpired:
            return ActionResult(
                success=False,
                output="",
                error="UI inspector timed out"
            )
        except Exception as e:
            return ActionResult(
                success=False,
                output="",
                error=f"UI inspector error: {str(e)}"
            )
    
    async def execute_click(self, grid_position: str) -> ActionResult:
        """Execute a click action at the specified grid position"""
        if not grid_position:
            return ActionResult(
                success=False,
                output="",
                error="Click action requires grid_position parameter"
            )
        
        # Get current UI state to get window frame and validate coordinates
        ui_result = await self.execute_ui_inspect()
        if not ui_result.success:
            return ActionResult(
                success=False,
                output="",
                error=f"Failed to get UI state for coordinate translation: {ui_result.error}"
            )
        
        ui_state = ui_result.ui_state
        
        # Extract window frame
        window_frame = ui_state.get("window", {}).get("frame", {})
        if not window_frame:
            return ActionResult(
                success=False,
                output="",
                error="No window frame data available for coordinate translation"
            )
        
        # Validate that the target grid position still contains a clickable element
        if "compressedOutput" in ui_state:
            compressed = ui_state["compressedOutput"]
            # Check if the grid position still exists in current UI state
            if f"@{grid_position}" not in compressed:
                print(f"⚠️  Warning: Grid position {grid_position} not found in current UI state")
                print(f"📍 Current UI elements: {compressed[:200]}...")
                # Still proceed with click but warn about potential coordinate drift
        
        # Translate grid position to screen coordinates
        x, y = CoordinateUtils.grid_to_coordinates(grid_position, window_frame)
        
        # Perform click
        pyautogui.click(x, y)
        await asyncio.sleep(1.0)  # Wait for click and focus state to update
        
        return ActionResult(
            success=True,
            output=f"Clicked at grid position {grid_position} -> ({x}, {y})"
        )
    
    async def execute_type(self, text: str, target_field: Optional[str] = None, action_executor=None) -> ActionResult:
        """Execute a type action with smart focus handling"""
        # Use the intelligent ActionExecutor for type actions if available
        if target_field and action_executor and hasattr(action_executor, 'execute_intelligent_type') and self._last_ui_state:
            # Get current UI state and window frame for coordinate translation
            window_frame = self._last_ui_state.get("window", {}).get("frame", {})
            if window_frame:
                try:
                    # Translate grid position to screen coordinates
                    x, y = CoordinateUtils.grid_to_coordinates(target_field, window_frame)
                    
                    # Create UI context for ActionExecutor
                    ui_context = {
                        "compressedOutput": self._last_ui_state.get("compressedOutput", ""),
                        "elements": self._last_ui_state.get("elements", []),
                        "window": self._last_ui_state.get("window", {})
                    }
                    
                    # Use intelligent ActionExecutor to determine best strategy
                    print(f"🧠 Using ActionExecutor for intelligent typing strategy")
                    result = await action_executor.execute_intelligent_type(
                        text=text,
                        target_field=target_field,
                        coordinates=(x, y),
                        ui_state=ui_context
                    )
                    
                    # If ActionExecutor performed navigation, refresh UI state
                    fresh_ui_state = None
                    if result.success and "Navigation initiated" in result.output:
                        print("🔄 ActionExecutor performed navigation - refreshing UI state...")
                        await asyncio.sleep(2.0)  # Wait for navigation to complete
                        fresh_ui_result = await self.execute_ui_inspect()
                        if fresh_ui_result.success:
                            fresh_ui_state = fresh_ui_result.ui_state
                            self._last_ui_state = fresh_ui_state
                        print("✅ UI state refreshed after navigation")
                    
                    # Convert ActionExecutor result to standard result format
                    return ActionResult(
                        success=result.success,
                        output=result.output,
                        error=result.error,
                        ui_state=fresh_ui_state  # Include fresh UI state if navigation occurred
                    )
                    
                except Exception as e:
                    print(f"⚠️ ActionExecutor failed, falling back to legacy: {e}")
                    # Fall through to legacy implementation
        
        # Legacy fallback implementation
        auto_clicked = False
        clicked_coordinate = None
        
        # Smart focus handling: Check if target field needs to be focused first
        if target_field and self._last_ui_state:
            compressed_output = self._last_ui_state.get("compressedOutput", "")
            is_focused = self._check_field_focus_state(compressed_output, target_field)
            
            if not is_focused:
                print(f"🎯 Target field {target_field} is unfocused, clicking to focus before typing")
                
                # Get window frame for coordinate translation
                window_frame = self._last_ui_state.get("window", {}).get("frame", {})
                if window_frame:
                    try:
                        # Translate grid position to screen coordinates and click
                        x, y = CoordinateUtils.grid_to_coordinates(target_field, window_frame)
                        pyautogui.click(x, y)
                        await asyncio.sleep(0.2)  # Brief pause for focus to take effect
                        auto_clicked = True
                        clicked_coordinate = target_field
                        print(f"✅ Auto-clicked {target_field} -> ({x}, {y}) to focus text field")
                    except Exception as e:
                        print(f"⚠️ Auto-click failed: {e}")
            else:
                print(f"✅ Target field {target_field} is already focused, typing directly")
        
        elif not target_field and self._last_ui_state:
            # Fallback: Auto-detect unfocused fields (legacy behavior)
            compressed_output = self._last_ui_state.get("compressedOutput", "")
            unfocused_field_coordinate = self._find_unfocused_text_field(compressed_output)
            
            if unfocused_field_coordinate:
                print(f"🎯 Auto-detected unfocused text field at {unfocused_field_coordinate}, clicking before typing")
                
                # Get window frame for coordinate translation
                window_frame = self._last_ui_state.get("window", {}).get("frame", {})
                if window_frame:
                    try:
                        # Translate grid position to screen coordinates and click
                        x, y = CoordinateUtils.grid_to_coordinates(unfocused_field_coordinate, window_frame)
                        pyautogui.click(x, y)
                        await asyncio.sleep(0.2)  # Brief pause for focus to take effect
                        auto_clicked = True
                        clicked_coordinate = unfocused_field_coordinate
                        print(f"✅ Auto-clicked {unfocused_field_coordinate} -> ({x}, {y}) to focus text field")
                    except Exception as e:
                        print(f"⚠️ Auto-click failed: {e}")
        
        # Use optimal typing speed for maximum performance
        await asyncio.to_thread(pyautogui.write, text, interval=0.001)  # Optimal fast interval
        
        # Prepare output message
        if auto_clicked and clicked_coordinate:
            output_msg = f"Auto-clicked {clicked_coordinate} then typed: {text}"
        else:
            output_msg = f"Typed: {text}"
            if target_field:
                output_msg += f" (into {target_field})"
        
        return ActionResult(
            success=True,
            output=output_msg
        )
    
    def _find_unfocused_text_field(self, compressed_output: str) -> Optional[str]:
        """
        Find the coordinate of an unfocused text field in the compressed output.
        Returns the coordinate (e.g., "24:11") if found, None otherwise.
        """
        if not compressed_output:
            return None
            
        # Look for text input fields marked as [UNFOCUSED]
        # Pattern: txtinp:TextField (context)|300x30@24:11[UNFOCUSED]
        
        # Match text input fields that are unfocused
        pattern = r'txtinp:[^@]*@(\d+:\d+)\[UNFOCUSED\]'
        matches = re.findall(pattern, compressed_output)
        
        if matches:
            # Return the first unfocused text field coordinate
            coordinate = matches[0]
            print(f"🔍 Found unfocused text field at: {coordinate}")
            return coordinate
        
        # Also check for other input field types
        pattern = r'(TextField|TextArea|SearchField)[^@]*@(\d+:\d+)\[UNFOCUSED\]'
        matches = re.findall(pattern, compressed_output)
        
        if matches:
            coordinate = matches[0][1]  # Second group is the coordinate
            print(f"🔍 Found unfocused input field at: {coordinate}")
            return coordinate
            
        return None
    
    def _check_field_focus_state(self, compressed_output: str, target_coordinate: str) -> bool:
        """
        Check if a specific field coordinate is focused or unfocused.
        Returns True if focused, False if unfocused.
        """
        if not compressed_output or not target_coordinate:
            return False
            
        # Look for the specific coordinate in the compressed output
        # Check for both [FOCUSED] and [UNFOCUSED] states
        if f"@{target_coordinate}[FOCUSED]" in compressed_output:
            print(f"🔍 Field {target_coordinate} is FOCUSED")
            return True
        elif f"@{target_coordinate}[UNFOCUSED]" in compressed_output:
            print(f"🔍 Field {target_coordinate} is UNFOCUSED")
            return False
        else:
            # Field not found or no focus indicator - assume needs focus
            print(f"🔍 Field {target_coordinate} focus state unknown, assuming unfocused")
            return False
    
    def _parse_ui_performance_breakdown(self, output: str) -> Dict[str, Any]:
        """Parse the performance breakdown from UI inspector output"""
        breakdown = {}
        lines = output.split('\n')
        
        # Look for the performance breakdown section
        in_performance_section = False
        in_parallel_section = False
        
        for line in lines:
            if "⏱️  PERFORMANCE BREAKDOWN:" in line:
                in_performance_section = True
                continue
            elif "🚀 RESULTS:" in line:
                in_performance_section = False
                break
            elif not in_performance_section:
                continue
                
            # Parse individual performance items
            if "• " in line and ":" in line:
                parts = line.split("• ")[1].split(": ")
                if len(parts) == 2:
                    name = parts[0].strip()
                    time_and_percent = parts[1].strip()
                    # Extract time (e.g., "0.077s (11.4%)")
                    if "s (" in time_and_percent:
                        time_str = time_and_percent.split("s (")[0]
                        percent_str = time_and_percent.split("(")[1].split("%")[0] if "(" in time_and_percent else "0"
                        try:
                            breakdown[name] = {
                                "time": float(time_str),
                                "percentage": float(percent_str)
                            }
                        except ValueError:
                            pass
            
            # Parse parallel detection details
            elif "⚡ Parallel Detection Group:" in line:
                in_parallel_section = True
                # Extract parallel group time
                if ":" in line:
                    time_part = line.split(": ")[1]
                    if "s (" in time_part:
                        time_str = time_part.split("s (")[0]
                        percent_str = time_part.split("(")[1].split("%")[0] if "(" in time_part else "0"
                        try:
                            breakdown["Parallel Detection Group"] = {
                                "time": float(time_str),
                                "percentage": float(percent_str)
                            }
                        except ValueError:
                            pass
            elif in_parallel_section and ("├─" in line or "└─" in line):
                # Parse individual parallel tasks
                if ": " in line:
                    parts = line.split(": ")
                    if len(parts) == 2:
                        name = parts[0].split("─ ")[1].strip()
                        time_and_percent = parts[1].strip()
                        if "s (" in time_and_percent:
                            time_str = time_and_percent.split("s (")[0]
                            percent_str = time_and_percent.split("(")[1].split("%")[0] if "(" in time_and_percent else "0"
                            try:
                                breakdown[f"  {name}"] = {
                                    "time": float(time_str),
                                    "percentage": float(percent_str)
                                }
                            except ValueError:
                                pass
            elif "🏁 TOTAL TIME:" in line:
                # Extract total time
                if ": " in line:
                    time_str = line.split(": ")[1].replace("s", "")
                    try:
                        breakdown["TOTAL TIME"] = {
                            "time": float(time_str),
                            "percentage": 100.0
                        }
                    except ValueError:
                        pass
        
        return breakdown