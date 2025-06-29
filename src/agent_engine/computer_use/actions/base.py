"""
Base action classes and data structures
"""

from dataclasses import dataclass
from typing import Optional, Dict, Any


@dataclass
class ActionResult:
    """Result of executing an action"""
    success: bool
    output: str
    error: Optional[str] = None
    ui_state: Optional[Dict] = None