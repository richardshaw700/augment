"""
Execution Strategy Selection - Determines which execution path to use
"""

import re
from enum import Enum
from typing import Optional
from dataclasses import dataclass

from src.agent_engine.task_classifier import TaskClassifier, TaskType
from src.config.app_config import AppConfig


class ExecutionType(Enum):
    """Types of execution strategies"""
    MESSAGING = "messaging"
    ACTION_BLUEPRINT = "action_blueprint"
    SMART_LLM = "smart_llm"
    HYBRID = "hybrid"
    COMPUTER_USE = "computer_use"


@dataclass
class ExecutionStrategy:
    """Represents an execution strategy for a task"""
    strategy_type: ExecutionType
    confidence: float
    reasoning: str
    blueprint_number: Optional[int] = None


class StrategySelector:
    """Determines which execution path to use for a given task"""
    
    def __init__(self):
        self.task_classifier = TaskClassifier()
    
    def select_strategy(self, task: str) -> ExecutionStrategy:
        """
        Select execution strategy based on task analysis
        
        Strategy selection flow:
        1. Check for messaging tasks (bypass classifier)
        2. Classify non-messaging tasks
        3. Route based on task type, confidence, and enabled modes
        """
        # 1. Check for messaging tasks first
        if self.is_messaging_task(task):
            return ExecutionStrategy(
                strategy_type=ExecutionType.MESSAGING,
                confidence=1.0,
                reasoning="Detected traditional messaging task (SMS, iMessage)"
            )
        
        # 2. Classify non-messaging tasks
        classification = self.task_classifier.classify_task(task)
        
        # 3. Route based on task type and confidence
        if classification.task_type == TaskType.ACTION_BLUEPRINT:
            blueprint_number = self._extract_blueprint_number(task)
            return ExecutionStrategy(
                strategy_type=ExecutionType.ACTION_BLUEPRINT,
                confidence=classification.confidence,
                reasoning=f"Action blueprint execution: {classification.reasoning}",
                blueprint_number=blueprint_number
            )
        
        elif (classification.task_type == TaskType.KNOWLEDGE_QUERY and 
              AppConfig.is_mode_enabled('knowledge_query') and 
              classification.confidence > 0.6):
            return ExecutionStrategy(
                strategy_type=ExecutionType.SMART_LLM,
                confidence=classification.confidence,
                reasoning=f"Knowledge query via Smart LLM: {classification.reasoning}"
            )
        
        elif (classification.task_type == TaskType.SMART_ACTION and 
              AppConfig.is_mode_enabled('smart_action') and 
              classification.confidence > 0.6):
            return ExecutionStrategy(
                strategy_type=ExecutionType.SMART_LLM,
                confidence=classification.confidence,
                reasoning=f"Smart action via Smart LLM: {classification.reasoning}"
            )
        
        elif (classification.task_type == TaskType.HYBRID and 
              AppConfig.is_mode_enabled('hybrid') and 
              classification.confidence > 0.7):
            return ExecutionStrategy(
                strategy_type=ExecutionType.HYBRID,
                confidence=classification.confidence,
                reasoning=f"Hybrid LLM+Computer Use: {classification.reasoning}"
            )
        
        else:
            # Use traditional computer use approach (fallback)
            disabled_modes = self._get_disabled_modes(classification.task_type)
            if disabled_modes:
                reasoning = f"Disabled mode(s) {disabled_modes} - falling back to Traditional Computer Use"
            else:
                reasoning = "Traditional Computer Use (low confidence or unmatched type)"
            
            return ExecutionStrategy(
                strategy_type=ExecutionType.COMPUTER_USE,
                confidence=classification.confidence,
                reasoning=reasoning
            )
    
    def is_messaging_task(self, task: str) -> bool:
        """
        Check if task is a messaging task that should use background automation
        
        Args:
            task: The user's task description
            
        Returns:
            True if this is a messaging task (SMS, iMessage, etc.)
        """
        task_lower = task.lower().strip()
        
        # FIRST: Exclude app-based messaging - these should use computer automation
        app_keywords = ["chatgpt", "slack", "discord", "whatsapp", "telegram", "app"]
        if any(keyword in task_lower for keyword in app_keywords):
            return False
        
        # SECOND: Only detect traditional messaging (SMS, iMessage, etc.)
        messaging_patterns = [
            r"send (a )?text",
            r"send (an )?imessage",
            r"text \w+",  # "text john", "text mom"
            r"message \w+",  # "message sarah"
            r"imessage \w+",
            r"sms \w+",
            r"send (a )?message"  # Generic messaging (only if no app context)
        ]
        
        # Check for traditional messaging patterns
        for pattern in messaging_patterns:
            if re.search(pattern, task_lower):
                return True
        
        return False
    
    def _extract_blueprint_number(self, task: str) -> Optional[int]:
        """Extract blueprint number from task string"""
        # Look for patterns like "blueprint 2", "run blueprint 5", "execute workflow 3"
        patterns = [
            r"blueprint\s+(\d+)",
            r"workflow\s+(\d+)",
            r"run\s+(\d+)",
            r"execute\s+(\d+)",
            r"#(\d+)"
        ]
        
        task_lower = task.lower()
        for pattern in patterns:
            match = re.search(pattern, task_lower)
            if match:
                return int(match.group(1))
        
        return None
    
    def _get_disabled_modes(self, task_type: TaskType) -> list:
        """Get list of disabled modes for a given task type"""
        disabled_modes = []
        
        if not AppConfig.is_mode_enabled('knowledge_query') and task_type == TaskType.KNOWLEDGE_QUERY:
            disabled_modes.append("KNOWLEDGE_QUERY")
        if not AppConfig.is_mode_enabled('smart_action') and task_type == TaskType.SMART_ACTION:
            disabled_modes.append("SMART_ACTION")
        if not AppConfig.is_mode_enabled('hybrid') and task_type == TaskType.HYBRID:
            disabled_modes.append("HYBRID")
        
        return disabled_modes 