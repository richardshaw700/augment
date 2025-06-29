"""
Application Configuration - Manages debug settings and execution modes
"""

from typing import Dict


class AppConfig:
    """Application configuration and feature toggles"""
    
    # Debug Configuration
    DEBUG = True          # Clean, readable output for main operations
    VERBOSE = False       # Detailed drilling down for deep debugging
    
    # Execution Mode Toggles
    ENABLE_SMART_ACTION = False      # Knowledge + simple actions (navigate to URLs, etc.)
    ENABLE_HYBRID = False            # Knowledge + complex UI automation combined
    ENABLE_KNOWLEDGE_QUERY = False   # Pure information requests via background LLM
    
    @classmethod
    def get_debug_settings(cls) -> Dict[str, bool]:
        """Get current debug settings"""
        return {
            "debug": cls.DEBUG,
            "verbose": cls.VERBOSE,
        }
    
    @classmethod
    def get_execution_modes(cls) -> Dict[str, bool]:
        """Get current execution mode settings"""
        return {
            "smart_action": cls.ENABLE_SMART_ACTION,
            "hybrid": cls.ENABLE_HYBRID,
            "knowledge_query": cls.ENABLE_KNOWLEDGE_QUERY,
        }
    
    @classmethod
    def set_debug_mode(cls, enabled: bool):
        """Enable or disable debug mode"""
        cls.DEBUG = enabled
    
    @classmethod
    def set_verbose_mode(cls, enabled: bool):
        """Enable or disable verbose mode"""
        cls.VERBOSE = enabled
    
    @classmethod
    def enable_execution_mode(cls, mode: str, enabled: bool = True):
        """Enable or disable specific execution modes"""
        if mode == "smart_action":
            cls.ENABLE_SMART_ACTION = enabled
        elif mode == "hybrid":
            cls.ENABLE_HYBRID = enabled
        elif mode == "knowledge_query":
            cls.ENABLE_KNOWLEDGE_QUERY = enabled
    
    @classmethod
    def is_mode_enabled(cls, mode: str) -> bool:
        """Check if a specific execution mode is enabled"""
        modes = cls.get_execution_modes()
        return modes.get(mode, False) 