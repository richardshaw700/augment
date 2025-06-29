"""
OpenRouter LLM Adapter
"""

from typing import Dict, List
import os
from openai import OpenAI
from .base import LLMAdapter


class OpenRouterAdapter(LLMAdapter):
    """Adapter for OpenRouter models (like Liquid LFM-40B, Gemini 2.0 Flash)"""
    
    def __init__(self, model: str = "liquid/lfm-40b"):
        self.model = model
        # Get OPENROUTER_API_KEY from environment
        api_key = os.getenv('OPENROUTER_API_KEY')
        if not api_key:
            raise ValueError("OPENROUTER_API_KEY not found in environment variables")
        
        self.client = OpenAI(
            base_url="https://openrouter.ai/api/v1",
            api_key=api_key,
        )
    
    async def chat_completion(self, messages: List[Dict[str, str]], **kwargs) -> str:
        """Generate a chat completion using OpenRouter"""
        try:
            response = self.client.chat.completions.create(
                extra_headers={
                    "HTTP-Referer": "https://github.com/richardshaw/augment",  # Site URL for rankings
                    "X-Title": "Augment - AI Computer Control",  # Site title for rankings
                },
                extra_body={},
                model=self.model,
                messages=messages,
                max_tokens=kwargs.get('max_tokens', 1000),
                temperature=kwargs.get('temperature', 0.1),
            )
            
            return response.choices[0].message.content
            
        except Exception as e:
            raise Exception(f"OpenRouter API error: {str(e)}")
    
    def get_model_info(self) -> Dict[str, str]:
        return {
            "provider": "OpenRouter",
            "model": self.model,
            "type": "cloud"
        }