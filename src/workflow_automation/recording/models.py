"""
Data models for workflow recording
"""

import time
from dataclasses import dataclass, field
from enum import Enum
from typing import Dict, List, Any, Optional, Tuple

class RecorderState(Enum):
    """States of the workflow recorder"""
    STOPPED = "stopped"
    RECORDING = "recording"
    IDLE = "idle"
    READY = "ready"
    ANALYZING = "analyzing" 
    PAUSED = "paused"
    ERROR = "error"

class EventType(Enum):
    """Types of system events we can capture"""
    CLICK = "click"
    MOUSE_CLICK = "mouse_click"
    MOUSE_SCROLL = "mouse_scroll"
    KEY_PRESS = "key_press"
    KEYBOARD = "keyboard"
    APP_SWITCH = "app_switch"
    UNKNOWN = "unknown"

@dataclass
class SystemEvent:
    """Represents a system-level event (click, key, scroll, etc.)"""
    event_type: EventType
    timestamp: float
    data: Dict[str, Any]
    description: str
    action_type: Optional[str] = None
    
    # Legacy compatibility fields
    @property
    def type(self):
        return self.event_type
    
    @property
    def coordinates(self):
        return self.data.get('coordinates')
    
    @property
    def app_name(self):
        return self.data.get('app_name')
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for logging"""
        return {
            "event_type": self.event_type.value,
            "timestamp": self.timestamp,
            "description": self.description,
            "action_type": self.action_type,
            "data": self.data
        }

@dataclass
class UIElement:
    """Represents a UI element that was interacted with"""
    role: str
    text: Optional[str] = None
    coordinates: Optional[Tuple[int, int]] = None
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for logging"""
        return {
            "role": self.role,
            "text": self.text,
            "coordinates": self.coordinates,
        }

@dataclass
class WorkflowStep:
    """Represents a single step in a recorded workflow"""
    step_id: int
    event_type: EventType
    timestamp: float
    description: str
    data: Dict[str, Any]
    action_type: Optional[str] = None
    
    # Analysis results
    intent: Optional[str] = None
    confidence: float = 0.0
    success: bool = True
    error_message: Optional[str] = None
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for logging"""
        return {
            "step_id": self.step_id,
            "event_type": self.event_type.value,
            "timestamp": self.timestamp,
            "description": self.description,
            "action_type": self.action_type,
            "data": self.data,
            "intent": self.intent,
            "confidence": self.confidence,
            "success": self.success,
            "error_message": self.error_message
        }

@dataclass
class RecordingSession:
    """Represents an active recording session"""
    session_id: str
    start_time: float
    steps: List[WorkflowStep] = field(default_factory=list)
    
    # Metadata
    end_time: Optional[float] = None
    metadata: Dict[str, Any] = field(default_factory=dict)
    
    @property
    def duration(self) -> float:
        """Get session duration in seconds"""
        end = self.end_time or time.time()
        return end - self.start_time
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for logging"""
        return {
            "session_id": self.session_id,
            "start_time": self.start_time,
            "end_time": self.end_time,
            "duration": self.duration,
            "steps": [step.to_dict() for step in self.steps],
            "metadata": self.metadata
        } 