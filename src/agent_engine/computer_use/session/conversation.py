"""
Conversation history management
"""

from typing import List, Dict, Any


class ConversationManager:
    """Manages conversation history with the LLM"""
    
    def __init__(self, max_history: int = 10):
        self.history = []
        self.max_history = max_history
    
    def add_user_message(self, content: str):
        """Add a user message to the conversation history"""
        self.history.append({"role": "user", "content": content})
        self._trim_history()
    
    def add_assistant_message(self, content: str):
        """Add an assistant message to the conversation history"""
        self.history.append({"role": "assistant", "content": content})
        self._trim_history()
    
    def add_system_message(self, content: str):
        """Add a system message to the conversation history"""
        self.history.append({"role": "system", "content": content})
        self._trim_history()
    
    def get_history(self) -> List[Dict[str, str]]:
        """Get the current conversation history"""
        return self.history.copy()
    
    def clear_history(self):
        """Clear the conversation history"""
        self.history.clear()
    
    def _trim_history(self):
        """Keep conversation history manageable by limiting to max_history messages"""
        if len(self.history) > self.max_history:
            self.history = self.history[-self.max_history:]