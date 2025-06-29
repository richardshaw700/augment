"""
Session Monitor - Handles session tracking and monitoring

This module handles:
- Session state management
- Progress tracking
- Completion detection
- Performance monitoring
- Result summarization
"""

import asyncio
import time
import json
from typing import Dict, List, Any
from dataclasses import dataclass
from ..dynamic_prompts import inject_completion_detected, inject_efficiency_tip, inject_loop_detection


@dataclass
class TaskSession:
    """Represents a task execution session"""
    task: str
    max_iterations: int
    iteration: int = 0
    results: List[Dict] = None
    current_ui_state: Dict = None
    consecutive_failures: int = 0
    completion_reason: str = "max_iterations_reached"
    start_time: float = 0
    
    def __post_init__(self):
        if self.results is None:
            self.results = []
        if self.start_time == 0:
            self.start_time = time.time()
    
    def is_complete(self) -> bool:
        """Check if session is complete"""
        return (self.iteration >= self.max_iterations or 
                self.completion_reason != "max_iterations_reached" or
                self.consecutive_failures >= 3)


class SessionMonitor:
    """Handles session tracking and monitoring"""
    
    @classmethod
    def initialize(cls, core) -> 'SessionMonitor':
        """Initialize monitor with core dependencies"""
        monitor = cls()
        monitor.core = core
        monitor.logger = core.logger
        monitor.conversation = core.conversation
        monitor.completion_detector = core.completion_detector
        monitor.context_manager = core.context_manager
        monitor.prompt_orchestrator = core.prompt_orchestrator
        return monitor
    
    def setup_task(self, task: str, max_iterations: int) -> TaskSession:
        """Setup new task session"""
        print("🚀 Starting Agent Orchestrator")
        print(f"📝 Task: {task}")
        print("=" * 60)
        
        self.logger.set_task(task)
        self.conversation.clear_history()
        
        return TaskSession(task=task, max_iterations=max_iterations)
    
    def process_result(self, session: TaskSession, decision: Dict[str, Any], result: Any) -> TaskSession:
        """Process action result and update session"""
        # Update session
        session.iteration += 1
        session.results.append({
            "iteration": session.iteration,
            "action": decision,
            "result": result
        })
        
        # Build task message for logging using centralized orchestrator
        task_message = self.prompt_orchestrator.build_task_message(session.task, session.iteration)
        
        # Log iteration
        self.logger.log_iteration(
            iteration=session.iteration,
            user_message=task_message,
            system_prompt="[Dynamic System Prompt - See prompt_history.txt for full content]",
            llm_response=json.dumps(decision),
            action_data=decision,
            action_result=result,
            ui_state=session.current_ui_state
        )
        
        # Handle result
        if result.success:
            print(f"✅ Success: {result.output}")
            session.consecutive_failures = 0
            if result.ui_state:
                session.current_ui_state = result.ui_state
                print("🔄 Updated current UI state with fresh data")
        else:
            print(f"❌ Error: {result.error}")
            session.consecutive_failures += 1
            if session.consecutive_failures >= 3:
                print(f"❌ Too many consecutive failures ({session.consecutive_failures}). Stopping task.")
                session.completion_reason = "action_execution_failures"
                return session
        
        # Update conversation using centralized orchestrator
        self.conversation.add_user_message(task_message)
        self.conversation.add_assistant_message(json.dumps(decision))
        
        # Build context message using centralized orchestrator
        context_message = self.prompt_orchestrator.build_context_message(result.output, result.success)
        self.conversation.add_system_message(context_message)
        
        # Check completion
        if self.completion_detector.is_task_completed(decision):
            print("🎉 Task completed successfully! (Explicit completion detected)")
            inject_completion_detected(f"Task completed: {session.task}")
            session.completion_reason = "explicit_completion_detected"
            return session
        
        # Check performance warnings
        if session.iteration > 5:
            efficiency_check = self.completion_detector.check_efficiency_warnings(
                session.iteration, time.time() - session.start_time
            )
            if efficiency_check["should_warn"]:
                for warning in efficiency_check["warnings"]:
                    inject_efficiency_tip(session.iteration, time.time() - session.start_time)
        
        # Check loops
        loop_check = self.completion_detector.detect_loops(session.results)
        if loop_check["loop_detected"]:
            inject_loop_detection(loop_check["action"], loop_check["count"])
            print(f"⚠️ Warning: {loop_check['type']} detected - consider different approach")
        
        return session
    
    def finalize_task(self, session: TaskSession) -> List[Dict]:
        """Finalize task and provide summary"""
        successful_actions = sum(1 for r in session.results if r["result"].success)
        
        self.logger.log_summary(
            total_iterations=len(session.results),
            successful_actions=successful_actions,
            completion_reason=session.completion_reason
        )
        
        self.logger.write_log()
        
        print(f"\n📊 Task Summary: {len(session.results)} iterations, {successful_actions} successful actions")
        print(f"📝 Session logs saved to: {self.logger.log_file}")
        print(f"📄 Summary saved to: {self.logger.readable_file}")
        
        return session.results
    
 