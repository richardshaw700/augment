"""
Task Executor - Handles all action execution

This module contains all the action routing and execution logic
that was previously embedded in the orchestrator.
"""

import time
from typing import Dict, Any
from .actions.base import ActionResult


class TaskExecutor:
    """Handles action execution with routing and performance tracking"""
    
    @classmethod
    def initialize(cls, core) -> 'TaskExecutor':
        """Initialize executor with core dependencies"""
        executor = cls()
        executor.core = core
        executor.ui_executor = core.ui_executor
        executor.system_executor = core.system_executor
        executor.performance = core.performance
        executor.ui_state_manager = core.ui_state_manager
        return executor
    
    async def execute_action(self, action_data: Dict[str, Any]) -> ActionResult:
        """
        Execute single action with routing, logging, and performance tracking
        """
        action = action_data.get("action")
        parameters = action_data.get("parameters", {})
        reasoning = action_data.get("reasoning", "")
        
        # Log action start
        timestamp = time.strftime("%H:%M:%S.%f")[:-3]
        print(f"[{timestamp}] 🤖 Executing: {action} - {reasoning}")
        start_time = self.performance.start_operation(f"{action} action")
        
        try:
            # Route to appropriate executor
            result = await self._route_action(action, parameters, start_time)
            return result
                
        except Exception as e:
            result = ActionResult(success=False, output="", error=f"Action execution failed: {str(e)}")
            self.performance.end_operation(f"{action} action", start_time, f"Exception: {str(e)}")
            return result
    
    async def _route_action(self, action: str, parameters: Dict, start_time: float) -> ActionResult:
        """Route action to appropriate executor"""
        
        if action == "ui_inspect":
            result = await self.ui_executor.execute_ui_inspect()
            if result.success and result.ui_state:
                self.ui_state_manager.set_ui_state(result.ui_state)
                ui_breakdown = result.ui_state.get('_ui_performance_breakdown', {})
                details = "UI state captured" + (" with performance breakdown" if ui_breakdown else "")
                self.performance.end_operation(f"{action} action", start_time, details, ui_breakdown)
            else:
                self.performance.end_operation(f"{action} action", start_time, f"Failed: {result.error}")
            return result
        
        elif action == "click":
            result = await self.ui_executor.execute_click(parameters.get("grid_position", ""))
            self.performance.end_operation(f"{action} action", start_time, f"Clicked {parameters.get('grid_position', '')}")
            return result
        
        elif action == "type":
            # Get ActionExecutor if available
            try:
                from src.actions import ActionExecutor
                action_executor = ActionExecutor()
            except ImportError:
                action_executor = None
            
            result = await self.ui_executor.execute_type(
                text=parameters.get("text", ""),
                target_field=parameters.get("field"),
                action_executor=action_executor
            )
            self.performance.end_operation(f"{action} action", start_time, f"Typed: {len(parameters.get('text', ''))} chars")
            return result
        
        elif action == "key":
            result = await self.system_executor.execute_key(parameters.get("keys", ""))
            self.performance.end_operation(f"{action} action", start_time, f"Keys: {parameters.get('keys', '')}")
            return result
        
        elif action == "bash":
            result = await self.system_executor.execute_bash(parameters.get("command", ""))
            self.performance.end_operation(f"{action} action", start_time, f"Command: {parameters.get('command', '')}")
            return result
        
        elif action == "wait":
            result = await self.system_executor.execute_wait(parameters.get("seconds", 1))
            self.performance.end_operation(f"{action} action", start_time, f"Waited: {parameters.get('seconds', 1)}s")
            return result
        
        elif action == "scroll":
            result = await self.system_executor.execute_scroll(
                direction=parameters.get("direction", "down"),
                amount=parameters.get("amount", 3)
            )
            self.performance.end_operation(f"{action} action", start_time, f"Scrolled {parameters.get('direction', 'down')}")
            return result
        
        else:
            result = ActionResult(success=False, output="", error=f"Unknown action: {action}")
            self.performance.end_operation(f"{action} action", start_time, f"Unknown action: {action}")
            return result 