"""
OpenAI LLM Adapter
"""

from typing import Dict, List
from openai import OpenAI
from .base import LLMAdapter


class OpenAIAdapter(LLMAdapter):
    """Adapter for OpenAI models"""
    
    def __init__(self, model: str = "gpt-4o-mini"):
        self.client = OpenAI()
        self.model = model
    
    async def chat_completion(self, messages: List[Dict[str, str]], **kwargs) -> str:
        """Generate a chat completion using OpenAI"""
        try:
            response = self.client.chat.completions.create(
                model=self.model,
                messages=messages,
                max_tokens=kwargs.get('max_tokens', 1000),
                temperature=kwargs.get('temperature', 0.1)
            )
            return response.choices[0].message.content
        except Exception as e:
            raise Exception(f"OpenAI API error: {str(e)}")
    
    def get_model_info(self) -> Dict[str, str]:
        return {
            "provider": "OpenAI",
            "model": self.model,
            "type": "cloud"
        }