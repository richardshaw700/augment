"""
Intelligent Action System for Augment

This module provides a comprehensive action execution system with:
- Base atomic actions (click, type, key)
- Smart action sequences (click+type+enter, etc.)
- Context-aware strategy selection
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
"""

from .base_actions import BaseActions, ActionResult
from .action_sequences import ActionSequences
from .context_detector import ContextDetector, ContextType, ActionStrategy
from .action_executor import ActionExecutor

__all__ = [
    'BaseActions',
    'ActionResult', 
    'ActionSequences',
    'ContextDetector',
    'ContextType',
    'ActionStrategy',
    'ActionExecutor'
] 