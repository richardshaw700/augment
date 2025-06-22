#!/usr/bin/env python3
"""
Task Classification System
Intelligently routes tasks between background LLM queries and computer use actions
"""

import re
from typing import Dict, List, Tuple, Optional
from enum import Enum
from dataclasses import dataclass

class TaskType(Enum):
    """Types of tasks the system can handle"""
    KNOWLEDGE_QUERY = "knowledge_query"          # Pure information requests
    SMART_ACTION = "smart_action"                # Knowledge + simple action
    HYBRID = "hybrid"                           # Knowledge + complex UI actions
    COMPUTER_USE = "computer_use"               # Pure UI automation
    
class TaskPriority(Enum):
    """Priority levels for task execution"""
    IMMEDIATE = "immediate"     # Execute right away
    BACKGROUND = "background"   # Can be done in background
    SEQUENTIAL = "sequential"   # Must be done in order

@dataclass
class TaskClassification:
    """Result of task classification"""
    task_type: TaskType
    priority: TaskPriority
    confidence: float
    reasoning: str
    suggested_llm_query: Optional[str] = None
    suggested_actions: Optional[List[str]] = None
    keywords: Optional[List[str]] = None

class TaskClassifier:
    """Classifies tasks to determine optimal execution strategy"""
    
    # Keywords that indicate knowledge-based tasks
    KNOWLEDGE_KEYWORDS = [
        "recommend", "suggest", "find me", "what is", "who is", "how to",
        "best", "good", "popular", "top", "list of", "compare", "explain",
        "weather", "news", "movie", "restaurant", "recipe", "definition",
        "meaning", "price", "cost", "review", "rating", "fact", "information"
    ]
    
    # Keywords that indicate actions that can be automated
    SMART_ACTION_KEYWORDS = [
        "open", "navigate to", "go to", "visit", "play", "watch", "listen",
        "download", "install", "send email", "message", "call", "dial",
        "set reminder", "add calendar", "create note", "save", "bookmark"
    ]
    
    # Keywords that require complex UI interaction
    COMPUTER_USE_KEYWORDS = [
        "click", "scroll", "drag", "select", "copy", "paste", "edit",
        "form", "login", "sign in", "upload", "attach", "settings",
        "configure", "screenshot", "record", "multiple steps", "navigate menu"
    ]
    
    # Hybrid patterns (knowledge + UI actions)
    HYBRID_PATTERNS = [
        r"find .* and (add|order|buy|purchase|cart)",
        r"research .* and (create|write|save|email)",
        r"look up .* and (share|send|post)",
        r"get .* and (compare|analyze|calculate)",
        # Navigation + knowledge patterns
        r"(go to|open|visit) .* and (find|get|search|look)",
        r"(open|go to|visit) .* (find me|get me|search for)",
        r"(navigate to|go to) .* and (find|locate|search)"
    ]
    
    def __init__(self):
        self.classification_history = []
    
    def classify_task(self, task: str) -> TaskClassification:
        """Main classification method"""
        task_lower = task.lower().strip()
        
        # Check for hybrid patterns first
        hybrid_match = self._check_hybrid_patterns(task_lower)
        if hybrid_match:
            return self._create_hybrid_classification(task, hybrid_match)
        
        # Score different task types
        knowledge_score = self._score_knowledge_task(task_lower)
        smart_action_score = self._score_smart_action(task_lower)
        computer_use_score = self._score_computer_use(task_lower)
        
        # Determine primary task type
        scores = {
            TaskType.KNOWLEDGE_QUERY: knowledge_score,
            TaskType.SMART_ACTION: smart_action_score,
            TaskType.COMPUTER_USE: computer_use_score
        }
        
        primary_type = max(scores, key=scores.get)
        confidence = scores[primary_type]
        
        # Generate classification
        classification = self._create_classification(
            task, primary_type, confidence, task_lower
        )
        
        # Store in history
        self.classification_history.append({
            "task": task,
            "classification": classification,
            "scores": scores
        })
        
        return classification
    
    def _check_hybrid_patterns(self, task_lower: str) -> Optional[str]:
        """Check if task matches hybrid patterns"""
        for pattern in self.HYBRID_PATTERNS:
            if re.search(pattern, task_lower):
                return pattern
        return None
    
    def _score_knowledge_task(self, task_lower: str) -> float:
        """Score how likely this is a knowledge-based task"""
        score = 0.0
        
        # Check for knowledge keywords
        for keyword in self.KNOWLEDGE_KEYWORDS:
            if keyword in task_lower:
                score += 0.3
        
        # Question patterns
        if task_lower.startswith(("what", "who", "when", "where", "why", "how")):
            score += 0.4
        
        # Recommendation patterns
        if re.search(r"(recommend|suggest|find me) .* (movie|book|restaurant|music)", task_lower):
            score += 0.5
        
        # Information seeking patterns
        if re.search(r"(tell me about|information about|details about)", task_lower):
            score += 0.4
        
        return min(score, 1.0)
    
    def _score_smart_action(self, task_lower: str) -> float:
        """Score how likely this needs a smart action (knowledge + simple action)"""
        score = 0.0
        
        # Check for smart action keywords
        for keyword in self.SMART_ACTION_KEYWORDS:
            if keyword in task_lower:
                score += 0.3
        
        # Navigation patterns - HIGHEST PRIORITY (matching background_llm.py)
        # These should not be drowned out by knowledge keywords
        navigation_keywords = ["open", "go to", "visit", "navigate"]
        if any(keyword in task_lower for keyword in navigation_keywords):
            score += 0.8  # Increased from 0.6 to ensure priority
        
        # URL/Website patterns - also high priority
        if re.search(r"(open|go to|visit) .* (website|url|\.com|netflix|youtube)", task_lower):
            score += 0.4  # Additional boost for specific sites
        
        # Direct service patterns (e.g., "go to netflix")
        if re.search(r"(open|go to|visit) (netflix|youtube|amazon|spotify|github|reddit)", task_lower):
            score += 0.4  # Additional boost for direct service navigation
        
        # Media patterns
        if re.search(r"(play|watch|listen to) .* (on|from)", task_lower):
            score += 0.5
        
        # Direct action patterns
        if re.search(r"(open|launch) [a-zA-Z]+ (app|application|program)", task_lower):
            score += 0.7
        
        return min(score, 1.0)
    
    def _score_computer_use(self, task_lower: str) -> float:
        """Score how likely this needs complex UI automation"""
        score = 0.0
        
        # Check for computer use keywords
        for keyword in self.COMPUTER_USE_KEYWORDS:
            if keyword in task_lower:
                score += 0.4
        
        # Complex UI patterns
        if re.search(r"(navigate to|go to) .* (menu|settings|preferences)", task_lower):
            score += 0.5
        
        # Multi-step patterns
        if re.search(r"(then|next|after|and then)", task_lower):
            score += 0.3
        
        # Form/Input patterns
        if re.search(r"(fill|enter|input|type) .* (form|field|text)", task_lower):
            score += 0.6
        
        return min(score, 1.0)
    
    def _create_hybrid_classification(self, task: str, pattern: str) -> TaskClassification:
        """Create classification for hybrid tasks"""
        return TaskClassification(
            task_type=TaskType.HYBRID,
            priority=TaskPriority.SEQUENTIAL,
            confidence=0.8,
            reasoning=f"Task matches hybrid pattern: {pattern}. Needs both knowledge and UI actions.",
            suggested_llm_query=self._extract_knowledge_component(task),
            suggested_actions=self._extract_action_component(task)
        )
    
    def _create_classification(self, task: str, task_type: TaskType, confidence: float, task_lower: str) -> TaskClassification:
        """Create classification based on scoring"""
        
        if task_type == TaskType.KNOWLEDGE_QUERY:
            return TaskClassification(
                task_type=task_type,
                priority=TaskPriority.IMMEDIATE,
                confidence=confidence,
                reasoning="Task is primarily information-seeking and can be answered directly by LLM",
                suggested_llm_query=task,
                keywords=self._extract_keywords(task_lower, self.KNOWLEDGE_KEYWORDS)
            )
        
        elif task_type == TaskType.SMART_ACTION:
            return TaskClassification(
                task_type=task_type,
                priority=TaskPriority.IMMEDIATE,
                confidence=confidence,
                reasoning="Task needs knowledge + simple action (like opening URL)",
                suggested_llm_query=self._extract_knowledge_component(task),
                suggested_actions=[self._extract_action_component(task)],
                keywords=self._extract_keywords(task_lower, self.SMART_ACTION_KEYWORDS)
            )
        
        else:  # COMPUTER_USE
            return TaskClassification(
                task_type=task_type,
                priority=TaskPriority.SEQUENTIAL,
                confidence=confidence,
                reasoning="Task requires complex UI automation",
                keywords=self._extract_keywords(task_lower, self.COMPUTER_USE_KEYWORDS)
            )
    
    def _extract_knowledge_component(self, task: str) -> str:
        """Extract the knowledge-seeking part of a task"""
        # Remove action words to focus on knowledge component
        knowledge_task = task
        action_words = ["open", "go to", "navigate to", "visit", "add to cart", "order", "buy"]
        
        for word in action_words:
            if word in knowledge_task.lower():
                # Try to extract just the knowledge part
                parts = knowledge_task.lower().split(word)
                if len(parts) > 1:
                    knowledge_task = parts[0].strip()
                    break
        
        return knowledge_task
    
    def _extract_action_component(self, task: str) -> str:
        """Extract the action part of a task"""
        # Look for action indicators
        if "open" in task.lower() or "go to" in task.lower():
            return "navigate_to_url"
        elif "add to cart" in task.lower() or "order" in task.lower():
            return "add_to_cart"
        elif "play" in task.lower() or "watch" in task.lower():
            return "play_media"
        else:
            return "generic_action"
    
    def _extract_keywords(self, task_lower: str, keyword_list: List[str]) -> List[str]:
        """Extract matching keywords from task"""
        found_keywords = []
        for keyword in keyword_list:
            if keyword in task_lower:
                found_keywords.append(keyword)
        return found_keywords
    
    def get_classification_history(self) -> List[Dict]:
        """Get history of all task classifications"""
        return self.classification_history
    
    def should_use_background_llm(self, classification: TaskClassification) -> bool:
        """Determine if task should use background LLM query"""
        return classification.task_type in [
            TaskType.KNOWLEDGE_QUERY,
            TaskType.SMART_ACTION,
            TaskType.HYBRID
        ] and classification.confidence > 0.5 