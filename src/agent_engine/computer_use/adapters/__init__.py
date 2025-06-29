"""
LLM Adapter system for Agent Computer Use
"""

from .base import LLMAdapter
from .openai_adapter import OpenAIAdapter
from .ollama_adapter import OllamaAdapter
from .openrouter_adapter import OpenRouterAdapter


def create_llm_adapter(provider: str, model: str) -> LLMAdapter:
    """Factory function to create LLM adapters"""
    if provider.startswith("openai"):
        return OpenAIAdapter(model)
    elif provider.startswith("ollama"):
        return OllamaAdapter(model)
    elif provider.startswith("liquid") or provider.startswith("gemini"):
        return OpenRouterAdapter(model)
    else:
        raise ValueError(f"Unknown LLM provider: {provider}")


__all__ = ['LLMAdapter', 'OpenAIAdapter', 'OllamaAdapter', 'OpenRouterAdapter', 'create_llm_adapter']