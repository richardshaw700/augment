"""
Session logging and summary generation
"""

import json
import time
from pathlib import Path
from datetime import datetime
from typing import Dict, Any, Optional, List

from ..actions.base import ActionResult


class SessionLogger:
    """Handles session logging and summary generation"""
    
    def __init__(self, session_id: Optional[str] = None):
        # Use consistent filenames instead of timestamped ones
        project_root = Path(__file__).parent.parent.parent.parent.parent
        self.log_file = project_root / "src" / "debug_output" / "agent_session.json"
        self.readable_file = project_root / "src" / "debug_output" / "agent_session_summary.txt"
        
        # Ensure debug output directory exists
        self.log_file.parent.mkdir(parents=True, exist_ok=True)
        
        self.session_id = session_id or f"session_{int(time.time())}"
        self.iterations = []
        self.task = ""
        self.start_time = time.time()
    
    def set_task(self, task: str):
        """Set the main task for this session"""
        self.task = task
    
    def log_iteration(self, iteration: int, user_message: str, system_prompt: str, 
                     llm_response: str, action_data: Dict, action_result: ActionResult, 
                     ui_state: Optional[Dict] = None):
        """Log a complete iteration with all details"""
        iteration_data = {
            "iteration": iteration,
            "timestamp": datetime.now().isoformat(),
            "user_message": user_message,
            "system_prompt": system_prompt,
            "llm_response": llm_response,
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
        
        # Include the compressed output that Agent actually sees
        if "compressedOutput" in ui_state:
            summary["compressed_ui"] = ui_state["compressedOutput"]
        
        # Legacy summary data for compatibility
        if "summary" in ui_state and "clickableElements" in ui_state["summary"]:
            clickable = ui_state["summary"]["clickableElements"]
            summary["clickable_elements_count"] = len(clickable)
        
        if "elements" in ui_state:
            summary["total_elements"] = len(ui_state["elements"])
        
        return summary
    
    def write_log(self):
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
                f.write(f"Agent Computer Use Session Summary\n")
                f.write(f"=================================\n\n")
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