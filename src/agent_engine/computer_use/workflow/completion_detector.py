"""
Task completion detection logic
"""

import time
from typing import List, Dict, Any


class CompletionDetector:
    """Detects when tasks are completed and provides feedback"""
    
    def __init__(self):
        pass
    
    def is_task_completed(self, action_data: Dict[str, Any]) -> bool:
        """
        Check if a task has been explicitly completed based on action reasoning.
        
        Returns True if the action indicates task completion.
        """
        action_type = action_data.get("action", "")
        reasoning = action_data.get("reasoning", "").lower()
        
        # Check for explicit completion keywords in reasoning (more specific)
        # Only trigger on the exact completion format from system prompt
        completion_patterns = [
            "task completed successfully -",  # Exact format from system prompt
            "task is completed -",
            "task has been completed -"
        ]
        
        return any(pattern in reasoning for pattern in completion_patterns)
    
    def detect_loops(self, results: List[Dict]) -> Dict[str, Any]:
        """
        Detect if the agent is stuck in a loop of repeated actions.
        
        Returns a dictionary with loop detection info.
        """
        if len(results) < 3:
            return {"loop_detected": False}
        
        # Check for repeated actions
        recent_actions = [r["action"]["action"] for r in results[-3:]]
        if len(set(recent_actions)) == 1:  # Same action repeated
            return {
                "loop_detected": True,
                "action": recent_actions[0],
                "count": 3,
                "type": "action_repeat"
            }
        
        # Check for excessive UI inspections
        recent_ui_inspects = sum(1 for r in results[-5:] if r["action"]["action"] == "ui_inspect")
        if recent_ui_inspects >= 4 and len(results) > 8:
            return {
                "loop_detected": True,
                "action": "ui_inspect",
                "count": recent_ui_inspects,
                "type": "ui_inspection_loop"
            }
        
        return {"loop_detected": False}
    
    def check_efficiency_warnings(self, iteration_count: int, elapsed_time: float) -> Dict[str, Any]:
        """
        Check if efficiency warnings should be triggered.
        
        Returns a dictionary with efficiency warning info.
        """
        warnings = []
        
        if iteration_count > 10:
            warnings.append({
                "type": "high_iteration_count",
                "message": "Consider using action sequences (field parameter) to reduce action count"
            })
        
        if elapsed_time > 30:
            warnings.append({
                "type": "long_execution_time",
                "message": "Task taking longer than expected - verify if goal is already achieved"
            })
        
        return {
            "warnings": warnings,
            "should_warn": len(warnings) > 0
        }