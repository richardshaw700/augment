"""
Result Processor - Handles task result processing and formatting
"""

from typing import Dict, Any
from .task_tracker import TaskSession


class ResultProcessor:
    """Processes and formats task execution results"""
    
    def finalize_results(self, session: TaskSession, raw_results: Dict[str, Any]) -> Dict[str, Any]:
        """Process and format final results"""
        # Add session metadata to results
        final_results = raw_results.copy()
        final_results.update({
            "task": session.task,
            "task_id": session.task_id,
            "strategy_type": session.strategy.strategy_type.value,
            "strategy_confidence": session.strategy.confidence,
            "strategy_reasoning": session.strategy.reasoning,
            "execution_time": session.execution_time
        })
        
        return final_results
    
    def format_task_display(self, session: TaskSession) -> str:
        """Format task information for display"""
        strategy_display = session.strategy.strategy_type.value.replace('_', ' ').title()
        
        display_info = []
        display_info.append(f"Task: {session.task}")
        display_info.append(f"Strategy: {strategy_display}")
        display_info.append(f"Confidence: {session.strategy.confidence:.2f}")
        display_info.append(f"Success: {'✅' if session.success else '❌'}")
        display_info.append(f"Execution Time: {session.execution_time:.1f}s")
        
        if session.actions_executed > 0:
            display_info.append(f"Actions: {session.successful_actions}/{session.actions_executed}")
        
        if session.error:
            display_info.append(f"Error: {session.error}")
        
        return "\n".join(display_info)
    
    def format_history_entry(self, session: TaskSession, index: int) -> str:
        """Format a single history entry for display"""
        status_icon = "✅" if session.success else "❌"
        task_display = session.task[:50] + ('...' if len(session.task) > 50 else '')
        strategy_display = session.strategy.strategy_type.value.replace('_', ' ').title()
        
        main_line = f"{index}. {status_icon} {task_display}"
        detail_line = f"   {strategy_display} | {session.execution_time:.1f}s"
        
        if session.actions_executed > 0:
            detail_line += f" | Actions: {session.actions_executed}"
        
        detail_line += f" | ID: {session.task_id}"
        
        return f"{main_line}\n{detail_line}" 