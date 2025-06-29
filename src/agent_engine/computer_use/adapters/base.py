"""
Base LLM Adapter interface
"""

from typing import Dict, List
from abc import ABC, abstractmethod


class LLMAdapter(ABC):
    """Base class for LLM adapters"""
    
    @abstractmethod
    async def chat_completion(self, messages: List[Dict[str, str]], **kwargs) -> str:
        """Generate a chat completion"""
        raise NotImplementedError
    
    @abstractmethod
    def get_model_info(self) -> Dict[str, str]:
        """Get information about the current model"""
        raise NotImplementedError