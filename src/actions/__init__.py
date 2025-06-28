"""
Intelligent Action System for Augment

This module provides a comprehensive action execution system with:
- Base atomic actions (click, type, key)
- Smart action sequences (click+type+enter, etc.)
- Context-aware strategy selection
- Smart LLM actions for knowledge-based tasks
- Background LLM query integration
- Performance tracking and analytics

Usage:
    from src.actions import EnhancedActionExecutor
    
    executor = EnhancedActionExecutor(debug=True)
    result = await executor.execute_intelligent_type(
        text="apple.com",
        target_field="TextField (url)",
        coordinates=(1246, 72),
        ui_state=current_ui_state
    )
    
    # For smart LLM tasks
    from src.actions import SmartLLMActions
    
    smart_actions = SmartLLMActions(action_executor, llm_adapter, debug=True)
    await smart_actions.start()
    result = await smart_actions.execute_smart_task("Find me a good movie to watch")
"""

from .base_actions import BaseActions, ActionResult
from .action_sequences import ActionSequences
from .context_detector import ContextDetector, ContextType, ActionStrategy
from .action_executor import ActionExecutor
from .smart_llm_actions import SmartLLMActions, SmartActionResult

__all__ = [
    'BaseActions',
    'ActionResult', 
    'ActionSequences',
    'ContextDetector',
    'ContextType',
    'ActionStrategy',
    'ActionExecutor',
    'SmartLLMActions',
    'SmartActionResult'
] 