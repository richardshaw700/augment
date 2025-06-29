"""
Task Session Tracking - Manages task sessions and statistics
"""

import time
from typing import Dict, List, Any, Optional
from dataclasses import dataclass, field

from .strategy_selector import ExecutionStrategy


@dataclass
class TaskSession:
    """Represents a task execution session"""
    task: str
    task_id: str
    strategy: ExecutionStrategy
    start_time: float = field(default_factory=time.time)
    
    # Results
    success: bool = False
    error: Optional[str] = None
    results: List[Dict] = field(default_factory=list)
    execution_time: float = 0.0
    
    # Additional metadata
    actions_executed: int = 0
    successful_actions: int = 0
    
    def finalize(self):
        """Finalize the session with execution time"""
        self.execution_time = time.time() - self.start_time


class TaskTracker:
    """Manages task sessions and execution statistics"""
    
    def __init__(self):
        self.session_history: List[TaskSession] = []
        self.stats = {
            "tasks_completed": 0,
            "tasks_failed": 0,
            "actions_executed": 0,
            "errors": 0,
            "total_execution_time": 0.0
        }
    
    def initialize_task(self, task: str, task_id: Optional[str], strategy: ExecutionStrategy) -> TaskSession:
        """Initialize a new task session"""
        if task_id is None:
            task_id = f"task_{len(self.session_history) + 1}_{int(time.time())}"
        
        session = TaskSession(
            task=task,
            task_id=task_id,
            strategy=strategy
        )
        
        return session
    
    def finalize_task(self, session: TaskSession, results: Dict[str, Any]) -> TaskSession:
        """Finalize a task session with results"""
        session.finalize()
        session.success = results.get("success", False)
        session.error = results.get("error")
        session.results = results.get("results", [])
        session.actions_executed = results.get("total_actions", 0)
        session.successful_actions = results.get("successful_actions", 0)
        
        # Add to history
        self.session_history.append(session)
        
        # Update stats
        if session.success:
            self.stats["tasks_completed"] += 1
        else:
            self.stats["tasks_failed"] += 1
            if session.error:
                self.stats["errors"] += 1
        
        self.stats["actions_executed"] += session.actions_executed
        self.stats["total_execution_time"] += session.execution_time
        
        return session
    
    def get_session_history(self) -> List[TaskSession]:
        """Get the complete session history"""
        return self.session_history.copy()
    
    def get_stats(self) -> Dict[str, Any]:
        """Get current execution statistics"""
        return self.stats.copy()
    
    def get_formatted_stats(self) -> Dict[str, str]:
        """Get formatted statistics for display"""
        total_tasks = self.stats["tasks_completed"] + self.stats["tasks_failed"]
        success_rate = (self.stats["tasks_completed"] / total_tasks * 100) if total_tasks > 0 else 0
        
        avg_execution_time = (self.stats["total_execution_time"] / total_tasks) if total_tasks > 0 else 0
        
        return {
            "total_tasks": str(total_tasks),
            "tasks_completed": str(self.stats["tasks_completed"]),
            "tasks_failed": str(self.stats["tasks_failed"]),
            "success_rate": f"{success_rate:.1f}%",
            "actions_executed": str(self.stats["actions_executed"]),
            "errors": str(self.stats["errors"]),
            "avg_execution_time": f"{avg_execution_time:.1f}s",
            "total_execution_time": f"{self.stats['total_execution_time']:.1f}s"
        } 