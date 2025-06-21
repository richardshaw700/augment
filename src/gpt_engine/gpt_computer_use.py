#!/usr/bin/env python3
"""
GPT Computer Use Simulation
Simulates Claude's Computer Use API using GPT-4o-mini with structured prompting
"""

import json
import os
import subprocess
import asyncio
import pyautogui
import time
from datetime import datetime
from typing import Dict, List, Any, Optional
from dataclasses import dataclass
from openai import OpenAI
from dotenv import load_dotenv
import sys
from pathlib import Path
import pyperclip

# Add the project root to the path
project_root = Path(__file__).parent.parent.parent
sys.path.append(str(project_root))

# Load environment variables
load_dotenv()

@dataclass
class ActionResult:
    """Result of executing an action"""
    success: bool
    output: str
    error: Optional[str] = None
    ui_state: Optional[Dict] = None

class SessionLogger:
    """Handles session logging and summary generation"""
    
    def __init__(self, session_id: str = None):
        # Use consistent filenames instead of timestamped ones
        project_root = Path(__file__).parent.parent.parent
        self.log_file = project_root / "src" / "debug_output" / "gpt_session.json"
        self.readable_file = project_root / "src" / "debug_output" / "gpt_session_summary.txt"
        self.session_id = session_id or f"session_{int(time.time())}"
        self.iterations = []
        self.task = ""
        self.start_time = time.time()
    
    def set_task(self, task: str):
        """Set the main task for this session"""
        self.task = task
    
    def log_iteration(self, iteration: int, user_message: str, system_prompt: str, 
                     gpt_response: str, action_data: Dict, action_result: ActionResult, 
                     ui_state: Optional[Dict] = None):
        """Log a complete iteration with all details"""
        iteration_data = {
            "iteration": iteration,
            "timestamp": datetime.now().isoformat(),
            "user_message": user_message,
            "system_prompt": system_prompt,
            "gpt_response": gpt_response,
            "parsed_action": action_data,
            "action_result": {
                "success": action_result.success,
                "output": action_result.output,
                "error": action_result.error
            },
            "ui_state_summary": self._summarize_ui_state(ui_state) if ui_state else None
        }
        
        self.iterations.append(iteration_data)
    
    def log_summary(self, total_iterations: int, successful_actions: int, completion_reason: str):
        """Log session summary"""
        self.session_data = {
            "session_id": self.session_id,
            "start_time": self.start_time,
            "task": self.task,
            "iterations": self.iterations,
            "summary": {
                "end_time": datetime.now().isoformat(),
                "total_iterations": total_iterations,
                "successful_actions": successful_actions,
                "success_rate": f"{(successful_actions/total_iterations*100):.1f}%" if total_iterations > 0 else "0%",
                "completion_reason": completion_reason
            }
        }
        
        # Also create a human-readable summary
        self._write_readable_summary()
    
    def _summarize_ui_state(self, ui_state: Dict) -> Dict:
        """Create a concise summary of UI state for logging"""
        if not ui_state or "error" in ui_state:
            return {"error": ui_state.get("error", "Unknown error")}
        
        summary = {}
        if "summary" in ui_state and "clickableElements" in ui_state["summary"]:
            clickable = ui_state["summary"]["clickableElements"]
            summary["clickable_elements_count"] = len(clickable)
            summary["clickable_elements"] = [
                {
                    "type": elem.get("type", "unknown"),
                    "text": elem.get("visualText", elem.get("semanticMeaning", ""))[:50],
                    "position": elem.get("position", {})
                }
                for elem in clickable[:5]  # First 5 elements
            ]
        
        if "elements" in ui_state:
            summary["total_elements"] = len(ui_state["elements"])
        
        return summary
    
    def _write_log(self):
        """Write current session data to JSON file"""
        try:
            with open(self.log_file, 'w') as f:
                json.dump(self.session_data, f, indent=2)
        except Exception as e:
            print(f"⚠️ Failed to write log: {e}")
    
    def _write_readable_summary(self):
        """Write a human-readable summary file"""
        try:
            with open(self.readable_file, 'w') as f:
                f.write(f"GPT Computer Use Session Summary\n")
                f.write(f"================================\n\n")
                f.write(f"Session ID: {self.session_id}\n")
                f.write(f"Task: {self.task}\n")
                f.write(f"Start Time: {self.start_time}\n")
                f.write(f"End Time: {self.session_data['summary'].get('end_time', 'N/A')}\n")
                f.write(f"Total Iterations: {self.session_data['summary'].get('total_iterations', 0)}\n")
                f.write(f"Successful Actions: {self.session_data['summary'].get('successful_actions', 0)}\n")
                f.write(f"Success Rate: {self.session_data['summary'].get('success_rate', '0%')}\n")
                f.write(f"Completion Reason: {self.session_data['summary'].get('completion_reason', 'Unknown')}\n\n")
                
                f.write("Iteration Details:\n")
                f.write("-" * 50 + "\n")
                
                for iteration in self.iterations:
                    f.write(f"\n🔄 Iteration {iteration['iteration']}\n")
                    f.write(f"Time: {iteration['timestamp']}\n")
                    f.write(f"User: {iteration['user_message']}\n")
                    
                    if "reasoning" in iteration['parsed_action']:
                        f.write(f"🤖 Reasoning: {iteration['parsed_action']['reasoning']}\n")
                    
                    if "action" in iteration['parsed_action']:
                        f.write(f"🔧 Action: {iteration['parsed_action']['action']}\n")
                        if "parameters" in iteration['parsed_action']:
                            f.write(f"📋 Parameters: {iteration['parsed_action']['parameters']}\n")
                    
                    result = iteration['action_result']
                    status = "✅" if result['success'] else "❌"
                    f.write(f"{status} Result: {result['output']}\n")
                    if result['error']:
                        f.write(f"❌ Error: {result['error']}\n")
                    
                    f.write("-" * 30 + "\n")
                
        except Exception as e:
            print(f"⚠️ Failed to write readable summary: {e}")

class PerformanceTracker:
    """Tracks and logs performance metrics for operations"""
    
    def __init__(self):
        self.operations = []
        self.session_start = time.time()
        project_root = Path(__file__).parent.parent.parent
        self.log_file = project_root / "src" / "debug_output" / "performance_debug.txt"
        
    def start_operation(self, operation_name: str) -> float:
        """Start timing an operation and return the start time"""
        start_time = time.time()
        return start_time
    
    def end_operation(self, operation_name: str, start_time: float, details: str = "", ui_breakdown: Dict = {}):
        """End timing an operation and log the result"""
        end_time = time.time()
        elapsed = end_time - start_time
        
        self.operations.append({
            "operation": operation_name,
            "elapsed": elapsed,
            "details": details,
            "timestamp": datetime.now().strftime("%H:%M:%S.%f")[:-3],
            "ui_breakdown": ui_breakdown
        })
        
        # Write updated performance log
        self._write_performance_log()
    
    def _write_performance_log(self):
        """Write performance data to debug file"""
        if not self.operations:
            return
            
        total_time = self.get_total_time()
        
        # Group operations by type for summary
        operation_groups = {}
        for op in self.operations:
            op_type = op["operation"]
            if op_type not in operation_groups:
                operation_groups[op_type] = []
            operation_groups[op_type].append(op)
        
        with open("src/debug_output/performance_debug.txt", "w") as f:
            f.write("🚀 PERFORMANCE ANALYSIS\n")
            f.write("=" * 50 + "\n")
            f.write(f"📊 Total Session Time: {total_time:.3f}s\n")
            f.write(f"🔄 Total Operations: {len(self.operations)}\n\n")
            
            # Summary by operation type
            f.write("📈 OPERATION SUMMARY:\n")
            f.write("-" * 30 + "\n")
            for op_type, ops in operation_groups.items():
                avg_time = sum(op["elapsed"] for op in ops) / len(ops)
                total_type_time = sum(op["elapsed"] for op in ops)
                f.write(f"   {op_type}: {avg_time:.3f}s avg ({len(ops)} calls, {total_type_time:.3f}s total)\n")
            
            f.write("\n🔍 DETAILED BREAKDOWN:\n")
            f.write("-" * 30 + "\n")
            
            for i, op in enumerate(self.operations, 1):
                f.write(f"   {i}. [{op['timestamp']}] {op['operation']}: {op['elapsed']:.3f}s - {op['details']}\n")
                
                # Add UI inspection breakdown if available
                if op.get('ui_breakdown') and op['operation'] == 'ui_inspect action':
                    f.write("       UI INSPECTION BREAKDOWN:\n")
                    f.write("    " + "=" * 46 + "\n")
                    
                    # Sort breakdown by time (descending)
                    breakdown_items = sorted(
                        op['ui_breakdown'].items(),
                        key=lambda x: x[1].get('time', 0) if isinstance(x[1], dict) else 0,
                        reverse=True
                    )
                    
                    for name, data in breakdown_items:
                        if isinstance(data, dict) and 'time' in data:
                            time_val = data['time']
                            percent_val = data.get('percentage', 0)
                            
                            # Format parallel detection sub-items with indentation
                            if name.startswith('  '):
                                f.write(f"        ├─ {name.strip()}: {time_val:.3f}s ({percent_val:.1f}%)\n")
                            else:
                                f.write(f"      • {name}: {time_val:.3f}s ({percent_val:.1f}%)\n")
                    
                    # Add total time if available
                    if 'TOTAL TIME' in op['ui_breakdown']:
                        total_ui_time = op['ui_breakdown']['TOTAL TIME']['time']
                        f.write("    " + "-" * 46 + "\n")
                        f.write(f"      ⚡ Total UI Inspection: {total_ui_time:.3f}s\n")
                    
                    f.write("\n")
            
            f.write("\n" + "=" * 50 + "\n")
            f.write(f"🎯 Session completed at {datetime.now().strftime('%H:%M:%S')}\n")
    
    def get_total_time(self) -> float:
        """Get total elapsed time since session start"""
        return time.time() - self.session_start

class GPTComputerUse:
    """
    Simulates computer use API functionality using GPT-4o-mini
    """
    
    def __init__(self):
        self.client = OpenAI()
        self.ui_inspector_path = project_root / "src" / "ui_inspector" / "compiled_ui_inspector"
        self.conversation_history = []
        
        # Load available applications first (needed for system prompt)
        self.available_apps = self._load_available_applications()
        
        # Generate system prompt after loading apps
        self.system_prompt = self._generate_system_prompt()
        
        # Create session logger with consistent filename
        self.logger = SessionLogger()
        
        # Initialize performance tracker
        self.performance = PerformanceTracker()
        
        print("🤖 GPT Computer Use initialized")
        print(f"📁 UI Inspector: {self.ui_inspector_path}")
        print(f"📝 Session logs: {self.logger.log_file}")
        print(f"📄 Summary: {self.logger.readable_file}")
        print(f"⏱️  Performance logs: {self.performance.log_file}")
        
        # Initialize pyautogui settings
        pyautogui.FAILSAFE = True
        pyautogui.PAUSE = 0.5
    
    def _generate_system_prompt(self) -> str:
        """Generate the system prompt with current applications list"""
        return f"""You are an AI assistant that can control a computer by generating structured action commands.

AVAILABLE APPLICATIONS:
{self.available_apps}

You have access to these actions:
- "ui_inspect": Get current UI structure as JSON for the CURRENTLY ACTIVE application only
- "click": Click at a grid position - use the exact grid positions from ui_inspect data
- "type": Type text
- "key": Press keyboard keys (e.g., "Return", "cmd+c", "Tab")
- "bash": Execute terminal commands
- "wait": Wait for specified seconds

COORDINATE SYSTEMS:
- Menu Bar: M1-M10 (app menus like Apple, Safari, File) and S1-S10 (system items like WiFi, Battery)
- Application Window: Standard grid positions (A1-AN50) for window content

🎯 MASTER GOAL EVALUATION RULE:
BEFORE EVERY ACTION, you MUST evaluate: "Is the original task already completed?"

Examples of task completion:
- "Open Safari" → COMPLETED when Safari is open and visible
- "Go to apple.com" → COMPLETED when Apple website is loaded and visible
- "Open Safari and go to apple.com" → COMPLETED when both Safari is open AND Apple website is loaded
- "Take a screenshot" → COMPLETED after ui_inspect shows current state
- "Show me what's on screen" → COMPLETED after ui_inspect reveals current content

If the task IS COMPLETED, respond with: {{"action": "ui_inspect", "parameters": {{}}, "reasoning": "Task completed successfully - [brief description of what was accomplished]"}}

CRITICAL INSTRUCTIONS:
1. ALWAYS start with "ui_inspect" to see current UI state
2. Use EXACT grid positions from ui_inspect output (e.g., "M2", "A5", "S3")
3. Menu bar coordinates (M1-M10, S1-S10) are for menu bar items only
4. Window coordinates (A1-AN50) are for application content only
5. Apps must be opened first before you can inspect their UI
6. For application launching, use "bash" with commands like: open -a 'AppName'
7. Always provide reasoning for each action
8. EVALUATE GOAL COMPLETION BEFORE EVERY ACTION - Don't continue if task is done!

RESPONSE FORMAT:
Always respond with valid JSON containing:
{{"action": "action_name", "parameters": {{"param": "value"}}, "reasoning": "explanation"}}

Example responses:
{{"action": "ui_inspect", "parameters": {{}}, "reasoning": "Getting current UI state to understand available elements"}}
{{"action": "click", "parameters": {{"grid_position": "M3"}}, "reasoning": "Clicking File menu in menu bar"}}
{{"action": "click", "parameters": {{"grid_position": "B15"}}, "reasoning": "Clicking button in application window"}}
{{"action": "type", "parameters": {{"text": "hello world"}}, "reasoning": "Typing text into active field"}}
{{"action": "bash", "parameters": {{"command": "open -a 'Safari'"}}, "reasoning": "Opening Safari application"}}
{{"action": "ui_inspect", "parameters": {{}}, "reasoning": "Task completed successfully - Safari is open and Apple website is loaded"}}
"""
    
    def _load_available_applications(self) -> str:
        """Load the compressed applications list for GPT context"""
        try:
            apps_file = project_root / "src" / "ui_inspector" / "system_inspector" / "available_applications_compressed.txt"
            if apps_file.exists():
                with open(apps_file, 'r') as f:
                    return f.read().strip()
            else:
                return "apps(0)|No applications catalog available"
        except Exception as e:
            return f"apps(0)|Error loading applications: {str(e)}"
    
    def _grid_to_coordinates(self, grid_position: str, window_frame: Dict) -> tuple[int, int]:
        """
        Convert grid position (e.g., "E5", "M2", "S3") to screen coordinates
        Handles both menu bar coordinates (M1-M10, S1-S10) and window coordinates (A1-AN50)
        """
        grid_position = grid_position.strip().upper()
        
        # Handle menu bar coordinates
        if grid_position.startswith('M') and len(grid_position) <= 3:  # M1-M10
            try:
                menu_index = int(grid_position[1:]) - 1  # Convert M1->0, M2->1, etc.
                if 0 <= menu_index <= 9:
                    # Menu bar coordinates - approximate positions based on standard menu layout
                    menu_bar_y = 12  # Middle of 24px menu bar
                    menu_width = 80  # Approximate width per menu item
                    menu_x = 20 + (menu_index * menu_width)  # Start at x=20, space items 80px apart
                    return (menu_x, menu_bar_y)
            except ValueError:
                pass
                
        elif grid_position.startswith('S') and len(grid_position) <= 3:  # S1-S10
            try:
                system_index = int(grid_position[1:]) - 1  # Convert S1->0, S2->1, etc.
                if 0 <= system_index <= 9:
                    # System menu coordinates - right side of menu bar
                    menu_bar_y = 12  # Middle of 24px menu bar
                    screen_width = 1440  # Assume standard screen width
                    system_width = 30  # Approximate width per system item
                    system_x = screen_width - 20 - (system_index * system_width)  # Right-aligned
                    return (system_x, menu_bar_y)
            except ValueError:
                pass
        
        # Handle standard window grid coordinates (A1-AN50)
        else:
            # Parse column (A-AN) and row (1-50)
            if len(grid_position) >= 2:
                # Find where numbers start
                col_end = 0
                for i, char in enumerate(grid_position):
                    if char.isdigit():
                        col_end = i
                        break
                
                if col_end > 0:
                    try:
                        col_str = grid_position[:col_end]
                        row_num = int(grid_position[col_end:])
                        
                        # Convert column string to index (A=0, B=1, ..., Z=25, AA=26, AB=27, etc.)
                        col_index = 0
                        for char in col_str:
                            col_index = col_index * 26 + (ord(char) - ord('A') + 1)
                        col_index -= 1  # Convert to 0-based index
                        
                        # Convert row to 0-based index
                        row_index = row_num - 1
                        
                        # Calculate screen coordinates using window frame
                        window_x = window_frame.get('x', 0)
                        window_y = window_frame.get('y', 0)
                        window_width = window_frame.get('width', 1000)
                        window_height = window_frame.get('height', 800)
                        
                        # Grid dimensions (40 columns x 50 rows)
                        grid_cols = 40
                        grid_rows = 50
                        
                        # Calculate cell size
                        cell_width = window_width / grid_cols
                        cell_height = window_height / grid_rows
                        
                        # Calculate center of grid cell
                        x = window_x + (col_index * cell_width) + (cell_width / 2)
                        y = window_y + (row_index * cell_height) + (cell_height / 2)
                        
                        return (int(x), int(y))
                        
                    except (ValueError, IndexError):
                        pass
        
        # Fallback - return center of window
        window_x = window_frame.get('x', 0)
        window_y = window_frame.get('y', 0)
        window_width = window_frame.get('width', 1000)
        window_height = window_frame.get('height', 800)
        
        center_x = window_x + (window_width / 2)
        center_y = window_y + (window_height / 2)
        
        return (int(center_x), int(center_y))
    
    def refresh_applications_list(self):
        """Refresh the available applications list and update system prompt"""
        self.available_apps = self._load_available_applications()
        
        # Update the system prompt with new applications list
        self.system_prompt = self._generate_system_prompt()
        
        print(f"🔄 Applications list refreshed: {len(self.available_apps)} characters loaded")
    
    def show_available_applications(self):
        """Display available applications in a user-friendly format"""
        if self.available_apps.startswith("apps("):
            # Parse the compressed format
            parts = self.available_apps.split("|", 1)
            if len(parts) == 2:
                count_part = parts[0]  # e.g., "apps(29)"
                apps_part = parts[1]   # e.g., "App1(bundle1),App2(bundle2)..."
                
                app_count = count_part[5:-1]  # Extract number from "apps(29)"
                app_entries = apps_part.split(",")
                
                print(f"📱 Available Applications ({app_count} total):")
                print("=" * 50)
                
                for i, entry in enumerate(app_entries, 1):
                    if "(" in entry and entry.endswith(")"):
                        app_name = entry.split("(")[0]
                        bundle_id = entry.split("(")[1][:-1]
                        print(f"{i:2d}. {app_name} ({bundle_id})")
                    else:
                        print(f"{i:2d}. {entry}")
            else:
                print("📱 Available Applications:")
                print(self.available_apps)
        else:
            print("📱 Available Applications:")
            print(self.available_apps)
    
    async def get_ui_state(self) -> Dict[str, Any]:
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
                    return ui_data
                else:
                    return {"error": "No JSON data found in UI inspector output"}
            else:
                return {"error": f"UI inspector failed: {result.stderr}"}
                
        except subprocess.TimeoutExpired:
            return {"error": "UI inspector timed out"}
        except Exception as e:
            return {"error": f"UI inspector error: {str(e)}"}

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
    
    async def execute_action(self, action_data: Dict[str, Any]) -> ActionResult:
        """Execute a single action based on GPT's command"""
        action = action_data.get("action")
        parameters = action_data.get("parameters", {})
        reasoning = action_data.get("reasoning", "")
        
        timestamp = datetime.now().strftime("%H:%M:%S.%f")[:-3]
        print(f"[{timestamp}] 🤖 Executing: {action} - {reasoning}")
        
        # Start performance tracking for this action
        start_time = self.performance.start_operation(f"{action} action")
        
        try:
            if action == "ui_inspect":
                ui_state = await self.get_ui_state()
                
                # Extract UI performance breakdown if available
                ui_breakdown = ui_state.get('_ui_performance_breakdown', {})
                details = "UI state captured"
                if ui_breakdown:
                    details += " with performance breakdown"
                
                self.performance.end_operation(f"{action} action", start_time, details, ui_breakdown)
                return ActionResult(
                    success=True,
                    output="UI state captured",
                    ui_state=ui_state
                )
            
            elif action == "click":
                grid_position = parameters.get("grid_position", "")
                if not grid_position:
                    self.performance.end_operation(f"{action} action", start_time, "Missing grid_position")
                    return ActionResult(
                        success=False,
                        output="",
                        error="Click action requires grid_position parameter"
                    )
                
                # Get current UI state to get window frame
                ui_state = await self.get_ui_state()
                if "error" in ui_state:
                    self.performance.end_operation(f"{action} action", start_time, f"UI state error: {ui_state['error']}")
                    return ActionResult(
                        success=False,
                        output="",
                        error=f"Failed to get UI state for coordinate translation: {ui_state['error']}"
                    )
                
                # Extract window frame
                window_frame = ui_state.get("window", {}).get("frame", {})
                if not window_frame:
                    self.performance.end_operation(f"{action} action", start_time, "No window frame data")
                    return ActionResult(
                        success=False,
                        output="",
                        error="No window frame data available for coordinate translation"
                    )
                
                # Translate grid position to screen coordinates
                x, y = self._grid_to_coordinates(grid_position, window_frame)
                
                # Perform click
                pyautogui.click(x, y)
                await asyncio.sleep(0.5)  # Wait for click to register
                self.performance.end_operation(f"{action} action", start_time, f"Clicked {grid_position} -> ({x}, {y})")
                return ActionResult(
                    success=True,
                    output=f"Clicked at grid position {grid_position} -> ({x}, {y})"
                )
            
            elif action == "type":
                text = parameters.get("text", "")
                
                # Use optimal typing speed for maximum performance
                await asyncio.to_thread(pyautogui.write, text, interval=0.001)  # Optimal fast interval
                
                self.performance.end_operation(f"{action} action", start_time, f"Typed: {len(text)} chars")
                return ActionResult(
                    success=True,
                    output=f"Typed: {text}"
                )
            
            elif action == "key":
                keys = parameters.get("keys", "")
                # Handle key combinations
                if "+" in keys:
                    key_combo = keys.split("+")
                    pyautogui.hotkey(*key_combo)
                else:
                    pyautogui.press(keys)
                self.performance.end_operation(f"{action} action", start_time, f"Keys: {keys}")
                return ActionResult(
                    success=True,
                    output=f"Pressed keys: {keys}"
                )
            
            elif action == "bash":
                command = parameters.get("command", "")
                result = subprocess.run(
                    command,
                    shell=True,
                    capture_output=True,
                    text=True,
                    timeout=30
                )
                success = result.returncode == 0
                self.performance.end_operation(f"{action} action", start_time, f"Command: {command} (exit: {result.returncode})")
                return ActionResult(
                    success=success,
                    output=result.stdout,
                    error=result.stderr if result.returncode != 0 else None
                )
            
            elif action == "wait":
                seconds = parameters.get("seconds", 1)
                await asyncio.sleep(seconds)
                self.performance.end_operation(f"{action} action", start_time, f"Waited: {seconds}s")
                return ActionResult(
                    success=True,
                    output=f"Waited {seconds} seconds"
                )
            
            else:
                self.performance.end_operation(f"{action} action", start_time, f"Unknown action: {action}")
                return ActionResult(
                    success=False,
                    output="",
                    error=f"Unknown action: {action}"
                )
                
        except Exception as e:
            self.performance.end_operation(f"{action} action", start_time, f"Exception: {str(e)}")
            return ActionResult(
                success=False,
                output="",
                error=f"Action execution failed: {str(e)}"
            )
    
    def format_ui_state_for_gpt(self, ui_state: Dict[str, Any]) -> str:
        """Format UI state data for GPT consumption"""
        if "error" in ui_state:
            return f"UI Inspector Error: {ui_state['error']}"
        
        # Extract key information for GPT
        summary = []
        
        # Get window frame for grid coordinate calculation
        window_frame = ui_state.get("window", {}).get("frame", {})
        window_width = window_frame.get("width", 1000)
        window_height = window_frame.get("height", 800)
        window_x = window_frame.get("x", 0)
        window_y = window_frame.get("y", 0)
        
        if "summary" in ui_state:
            summary_data = ui_state["summary"]
            if "clickableElements" in summary_data:
                clickable = summary_data["clickableElements"]
                summary.append(f"Found {len(clickable)} clickable elements:")
                for i, element in enumerate(clickable[:15]):  # Show more elements for better targeting
                    pos = element.get("position", {})
                    x, y = pos.get("x", 0), pos.get("y", 0)
                    text = element.get("visualText", element.get("semanticMeaning", ""))
                    element_type = element.get("type", "unknown")
                    
                    # Calculate grid position from pixel coordinates
                    grid_position = self._pixel_to_grid(x, y, window_frame)
                    
                    # Format element with grid coordinate
                    if text and text.strip():
                        summary.append(f"  {i+1}. {element_type}@{grid_position}: {text[:50]}")
                    else:
                        summary.append(f"  {i+1}. {element_type}@{grid_position}")
        
        # Add non-clickable text elements for context
        if "elements" in ui_state:
            elements = ui_state["elements"]
            text_elements = [e for e in elements if not e.get("isClickable", False) and e.get("visualText")]
            if text_elements:
                summary.append(f"\nText content (for context):")
                for i, element in enumerate(text_elements[:10]):  # Limit to 10 text elements
                    pos = element.get("position", {})
                    x, y = pos.get("x", 0), pos.get("y", 0)
                    text = element.get("visualText", "")
                    
                    # Calculate grid position
                    grid_position = self._pixel_to_grid(x, y, window_frame)
                    
                    if text and text.strip():
                        summary.append(f"  {i+1}. text@{grid_position}: {text[:30]}")
        
        if "elements" in ui_state:
            elements = ui_state["elements"]
            summary.append(f"\nTotal UI elements detected: {len(elements)}")
            summary.append(f"Window size: {int(window_width)}x{int(window_height)}")
        
        return "\n".join(summary) if summary else json.dumps(ui_state, indent=2)
    
    def _pixel_to_grid(self, x: float, y: float, window_frame: Dict) -> str:
        """Convert pixel coordinates to grid position (A1-AN50)"""
        window_x = window_frame.get("x", 0)
        window_y = window_frame.get("y", 0)
        window_width = window_frame.get("width", 1000)
        window_height = window_frame.get("height", 800)
        
        # Convert to window-relative coordinates
        rel_x = x - window_x
        rel_y = y - window_y
        
        # Calculate grid position (40 columns x 50 rows)
        grid_cols = 40
        grid_rows = 50
        
        col_index = min(39, max(0, int(rel_x / window_width * grid_cols)))
        row_index = min(49, max(0, int(rel_y / window_height * grid_rows)))
        
        # Convert to grid coordinate string
        if col_index < 26:
            # A-Z (0-25)
            col_str = chr(ord('A') + col_index)
        else:
            # AA-AN (26-39)
            col_str = 'A' + chr(ord('A') + (col_index - 26))
        
        row_str = str(row_index + 1)  # 1-based row numbering
        
        return f"{col_str}{row_str}"
    
    async def chat_with_gpt(self, user_message: str, ui_state: Optional[Dict] = None) -> str:
        """Send message to GPT and get response"""
        start_time = self.performance.start_operation("GPT API call")
        
        try:
            # Build messages for the conversation
            messages = [{"role": "system", "content": self.system_prompt}]
            
            # Add conversation history
            messages.extend(self.conversation_history)
            
            # Add current UI state if available
            if ui_state:
                formatted_ui = self.format_ui_state_for_gpt(ui_state)
                messages.append({"role": "system", "content": f"Current UI State:\n{formatted_ui}"})
            
            # Add user message
            messages.append({"role": "user", "content": user_message})
            
            # Call GPT API
            response = self.client.chat.completions.create(
                model="gpt-4o-mini",
                messages=messages,
                temperature=0.1,
                max_tokens=1000
            )
            
            gpt_response = response.choices[0].message.content
            
            # Track token usage and response time
            usage = response.usage
            tokens_used = usage.total_tokens if usage else 0
            self.performance.end_operation("GPT API call", start_time, f"Tokens: {tokens_used}")
            
            return gpt_response
            
        except Exception as e:
            self.performance.end_operation("GPT API call", start_time, f"Error: {str(e)}")
            return f'{{"action": "wait", "parameters": {{"seconds": 1}}, "reasoning": "GPT API error: {str(e)}"}}'
    
    async def execute_task(self, task: str, max_iterations: int = 20) -> List[Dict]:
        """Execute a complete task using GPT computer use simulation"""
        # Output formatted messages for Swift app chat parsing
        print("🚀 Starting GPT Computer Use")
        print(f"📝 Task: {task}")
        print("=" * 60)
        
        # Log the task
        self.logger.set_task(task)
        
        results = []
        current_ui_state = None
        consecutive_failures = 0
        max_consecutive_failures = 3
        completion_reason = "max_iterations_reached"
        
        # Reset conversation history for new task
        self.conversation_history = []
        
        for iteration in range(max_iterations):
            print(f"\n🔄 Iteration {iteration + 1}/{max_iterations}")
            
            # Prepare the task context for this iteration
            if iteration == 0:
                task_message = f"Task: {task}\n\nPlease start by inspecting the current UI state to understand what's on screen."
            else:
                task_message = "Continue with the task. What should be the next action?"
            
            # Get GPT's next action
            gpt_response = await self.chat_with_gpt(task_message, current_ui_state)
            print(f"🤖 GPT Response: {gpt_response}")
            
            # Parse JSON response
            try:
                # Extract JSON from response (in case there's extra text)
                json_start = gpt_response.find('{')
                json_end = gpt_response.rfind('}') + 1
                if json_start != -1 and json_end > json_start:
                    json_str = gpt_response[json_start:json_end]
                    action_data = json.loads(json_str)
                else:
                    raise json.JSONDecodeError("No JSON found", gpt_response, 0)
                    
            except json.JSONDecodeError as e:
                print(f"❌ Failed to parse GPT response as JSON: {gpt_response}")
                consecutive_failures += 1
                if consecutive_failures >= max_consecutive_failures:
                    print(f"❌ Too many consecutive failures ({consecutive_failures}). Stopping task.")
                    completion_reason = "json_parse_failures"
                    break
                continue
            
            # Execute the action
            result = await self.execute_action(action_data)
            results.append({
                "iteration": iteration + 1,
                "action": action_data,
                "result": result
            })
            
            # Log this iteration with all details
            self.logger.log_iteration(
                iteration=iteration + 1,
                user_message=task_message,
                system_prompt=self.system_prompt,
                gpt_response=gpt_response,
                action_data=action_data,
                action_result=result,
                ui_state=current_ui_state
            )
            
            if result.success:
                print(f"✅ Success: {result.output}")
                consecutive_failures = 0  # Reset failure counter
                if result.ui_state:
                    current_ui_state = result.ui_state
            else:
                print(f"❌ Error: {result.error}")
                consecutive_failures += 1
                if consecutive_failures >= max_consecutive_failures:
                    print(f"❌ Too many consecutive failures ({consecutive_failures}). Stopping task.")
                    completion_reason = "action_execution_failures"
                    break
            
            # Update conversation history (keep it limited to prevent infinite growth)
            self.conversation_history.append({"role": "user", "content": task_message})
            self.conversation_history.append({"role": "assistant", "content": gpt_response})
            
            # Add result context
            if result.success:
                context = f"Action succeeded: {result.output}"
            else:
                context = f"Action failed: {result.error}. Try a different approach."
            
            self.conversation_history.append({"role": "system", "content": context})
            
            # Keep conversation history manageable (last 10 messages)
            if len(self.conversation_history) > 10:
                self.conversation_history = self.conversation_history[-10:]
            
            # Enhanced completion detection
            action_type = action_data.get("action", "")
            reasoning = action_data.get("reasoning", "").lower()
            
            # Check for explicit completion keywords in reasoning
            completion_keywords = [
                "task completed successfully", "task is completed", "task completed", 
                "successfully completed", "finished the task", "accomplished", 
                "done", "completed", "finished"
            ]
            
            if any(keyword in reasoning for keyword in completion_keywords):
                print("🎉 Task completed successfully! (Explicit completion detected)")
                completion_reason = "explicit_completion_detected"
                break
            
            # Enhanced website navigation completion detection
            if (action_type == "ui_inspect" and iteration > 3 and 
                current_ui_state and "window" in current_ui_state):
                
                window_info = current_ui_state.get("window", {})
                window_title = window_info.get("title", "").lower()
                
                # Check if task involves going to a specific website
                task_lower = task.lower()
                website_indicators = ["apple", "google", "facebook", "youtube", "github", "microsoft"]
                
                # Check for specific website completion
                for site in website_indicators:
                    if site in task_lower and site in window_title:
                        print(f"🎉 Successfully navigated to {site} website!")
                        completion_reason = f"website_navigation_completed_{site}"
                        break
                else:
                    # Generic website navigation check
                    if any(word in task_lower for word in ["website", "go to", "visit", "navigate to"]):
                        # Check if we have a proper webpage loaded (many elements)
                        elements = current_ui_state.get("elements", [])
                        if len(elements) > 15:  # Indicates a full webpage is loaded
                            print("🎉 Website navigation completed successfully!")
                            completion_reason = "generic_website_navigation_completed"
                            break
            
            # Application opening completion detection
            if (action_type == "ui_inspect" and iteration > 1 and 
                any(word in task.lower() for word in ["open", "launch", "start"]) and
                not any(word in task.lower() for word in ["website", "go to", "visit"])):
                
                # Check if the requested app is now active
                if current_ui_state and "window" in current_ui_state:
                    window_title = current_ui_state.get("window", {}).get("title", "").lower()
                    task_words = task.lower().split()
                    
                    # Check if any app name from task appears in window title
                    app_names = ["safari", "chrome", "firefox", "finder", "terminal", "cursor", "vscode", "xcode"]
                    for app_name in app_names:
                        if app_name in task_words and app_name in window_title:
                            print(f"🎉 Successfully opened {app_name}!")
                            completion_reason = f"app_opening_completed_{app_name}"
                            break
            
            # Screenshot/inspection task completion
            if (action_type == "ui_inspect" and iteration > 0 and 
                any(word in task.lower() for word in ["screenshot", "describe", "see", "screen", "show me"])):
                print("🎉 Task completed successfully! (UI inspection completed)")
                completion_reason = "ui_inspection_completed"
                break
            
            # Prevent infinite loops - if we've done many ui_inspects recently, probably done
            recent_ui_inspects = sum(1 for r in results[-5:] if r["action"]["action"] == "ui_inspect")
            if recent_ui_inspects >= 3 and iteration > 8:
                print("🎉 Task appears to be completed (multiple UI inspections suggest exploration is done)")
                completion_reason = "exploration_completed"
                break
            
            # Brief pause between actions
            await asyncio.sleep(1)
        
        # Log session summary
        successful_actions = sum(1 for r in results if r["result"].success)
        self.logger.log_summary(
            total_iterations=len(results),
            successful_actions=successful_actions,
            completion_reason=completion_reason
        )
        
        # Write logs to files
        self.logger._write_log()
        self.logger._write_readable_summary()
        
        print(f"\n📊 Task Summary: {len(results)} iterations, {successful_actions} successful actions")
        print(f"📝 Session logs saved to: {self.logger.log_file}")
        print(f"📄 Summary saved to: {self.logger.readable_file}")
        return results

# Standalone execution for testing
async def main():
    """Demo of GPT computer use simulation"""
    computer_use = GPTComputerUse()
    
    print("🖥️  GPT Computer Use Simulation")
    print("Simulating Claude's Computer Use API with GPT-4o-mini")
    print("=" * 60)
    
    # Show available applications
    computer_use.show_available_applications()
    
    # Example tasks to try
    example_tasks = [
        "Take a screenshot by inspecting the current UI",
        "Open Safari browser",
        "Open Cursor editor",
        "Open ChatGPT application",
        "Show me what's currently on the screen"
    ]
    
    print(f"\nExample tasks you can try:")
    for i, task in enumerate(example_tasks, 1):
        print(f"  {i}. {task}")
    
    while True:
        print("\n" + "=" * 60)
        task = input("Enter a task (or 'quit' to exit): ").strip()
        
        if task.lower() in ['quit', 'exit', 'q']:
            break
        
        if not task:
            continue
        
        try:
            results = await computer_use.execute_task(task)
            
            print(f"\n📊 Task Summary:")
            print(f"Total iterations: {len(results)}")
            successful_actions = sum(1 for r in results if r["result"].success)
            print(f"Successful actions: {successful_actions}/{len(results)}")
            
        except KeyboardInterrupt:
            print("\n⏹️  Task interrupted by user")
        except Exception as e:
            print(f"\n💥 Unexpected error: {str(e)}")

if __name__ == "__main__":
    import sys
    
    # Check if task was provided as command line argument
    if len(sys.argv) > 1:
        # Non-interactive mode - execute the task from command line
        task_from_args = " ".join(sys.argv[1:])
        
        async def run_single_task():
            computer_use = GPTComputerUse()
            print(f"🚀 Starting GPT Computer Use")
            print(f"📝 Task: {task_from_args}")
            print("=" * 60)
            
            try:
                results = await computer_use.execute_task(task_from_args)
                
                print(f"\n📊 Task Summary:")
                print(f"Total iterations: {len(results)}")
                successful_actions = sum(1 for r in results if r["result"].success)
                print(f"Successful actions: {successful_actions}/{len(results)}")
                
            except KeyboardInterrupt:
                print("\n⏹️  Task interrupted by user")
            except Exception as e:
                print(f"\n💥 Unexpected error: {str(e)}")
        
        asyncio.run(run_single_task())
    else:
        # Interactive mode
        asyncio.run(main()) 