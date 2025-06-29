"""
LLM Configuration - Manages LLM provider settings and selection
"""

from typing import Dict, Tuple
import os
from dotenv import load_dotenv


class LLMConfig:
    """LLM provider configuration and selection"""
    
    # Available LLM providers with performance metrics
    _PROVIDERS = {
        # OpenAI Models
        "openai_mini": "gpt-4o-mini",          # ✅ Success rate: 100%(1/1) Speed: 1.073s avg
        "openai_nano": "gpt-4.1-nano",         # ❌ Success rate: 0%(0/3) Speed: 0.679s avg
        "openai_4o": "gpt-4o",                 # untested
        "openai_4": "gpt-4",                   # untested
        "openai_3_5": "gpt-3.5-turbo",        # untested
        
        # OpenRouter Models (via OpenAI-compatible API)
        "liquid_lfm": "liquid/lfm-40b",        # ❌ Success rate: 0%(0/1) Speed: 1.749s avg
        "gemini_flash": "google/gemini-2.0-flash-001",  # untested
        "gemini_25_flash": "google/gemini-2.5-flash-preview-05-20",  # ✅ Success rate: 100%(3/3) Speed: 0.930s avg
        
        # Local Ollama Models  
        "ollama": "phi3:mini",                 # untested
        "ollama_small": "smollm2:1.7b",        # untested
        "ollama_tiny": "smollm2:360m",         # untested
    }
    
    # Default selected LLM
    _DEFAULT_SELECTED = "gemini_25_flash"
    
    @classmethod
    def get_available_providers(cls) -> Dict[str, str]:
        """Get all available LLM providers with performance metrics"""
        return cls._PROVIDERS.copy()
    
    @classmethod
    def get_selected_provider(cls) -> Tuple[str, str]:
        """Get the currently selected LLM provider and model"""
        selected_key = cls._DEFAULT_SELECTED
        model = cls._PROVIDERS[selected_key]
        
        # Determine the correct provider type from the selected LLM
        # Note: The provider name should match what create_llm_adapter() expects
        if selected_key.startswith("openai"):
            provider = "openai"
        elif selected_key.startswith(("liquid", "gemini")):
            provider = "gemini"  # This will be caught by the "liquid" or "gemini" check in create_llm_adapter
        elif selected_key.startswith("ollama"):
            provider = "ollama"
        else:
            provider = "openai"  # fallback
            
        return provider, model
    
    @classmethod
    def get_selected_key(cls) -> str:
        """Get the selected LLM key"""
        return cls._DEFAULT_SELECTED
    
    @classmethod
    def validate_environment(cls) -> bool:
        """Validate required environment variables are set"""
        load_dotenv()
        
        provider, _ = cls.get_selected_provider()
        selected_key = cls.get_selected_key()
        
        if provider == "openai":
            return bool(os.getenv('OPENAI_API_KEY'))
        elif selected_key.startswith(("liquid", "gemini")):
            return bool(os.getenv('OPENROUTER_API_KEY'))
        elif provider == "ollama":
            return True  # Local model, no API key needed
        
        return False
    
    @classmethod
    def get_required_env_vars(cls) -> Dict[str, str]:
        """Get required environment variables for the selected provider"""
        provider, _ = cls.get_selected_provider()
        selected_key = cls.get_selected_key()
        
        env_vars = {}
        if provider == "openai":
            env_vars["OPENAI_API_KEY"] = "OpenAI API key"
        elif selected_key.startswith(("liquid", "gemini")):
            env_vars["OPENROUTER_API_KEY"] = "OpenRouter API key"
        
        return env_vars 