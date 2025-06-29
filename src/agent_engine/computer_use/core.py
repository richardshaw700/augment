"""
Agent Core - Centralized initialization and core functionality

This module handles:
- System initialization 
- Application management
- Path resolution
- Configuration loading
"""

import time
from typing import Dict, Any
from dotenv import load_dotenv

from .adapters import create_llm_adapter
from .actions import UIActionExecutor, SystemActionExecutor
from .session import SessionLogger, PerformanceTracker, ConversationManager
from .ui import UIFormatter, UIStateManager
from .workflow import CompletionDetector, ContextManager
from .prompts import PromptLoader
from .utils import SystemUtils


class AgentCore:
    """Core agent functionality - initialization and configuration"""
    
    @classmethod
    def initialize(cls, llm_provider: str, llm_model: str, debug: bool = False) -> 'AgentCore':
        """One-line initialization of entire agent system"""
        load_dotenv()
        core = cls()
        core._setup_all_modules(llm_provider, llm_model, debug)
        return core
    
    def _setup_all_modules(self, llm_provider: str, llm_model: str, debug: bool):
        """Initialize all specialized modules"""
        # Get system paths
        self.paths = SystemUtils.get_project_paths()
        
        # Initialize LLM communication
        self.llm_adapter = create_llm_adapter(llm_provider, llm_model)
        self.llm_info = self.llm_adapter.get_model_info()
        
        # Initialize action executors (the "hands")
        self.ui_executor = UIActionExecutor(self.paths["ui_inspector"])
        self.system_executor = SystemActionExecutor()
        
        # Initialize session management (the "memory") 
        self.logger = SessionLogger()
        self.performance = PerformanceTracker()
        self.conversation = ConversationManager()
        
        # Initialize UI management (the "eyes")
        self.ui_formatter = UIFormatter()
        self.ui_state_manager = UIStateManager()
        
        # Initialize workflow management (the "brain")
        self.completion_detector = CompletionDetector()
        self.context_manager = ContextManager(debug=debug)
        
        # Initialize prompt system (the "knowledge")
        self.prompt_loader = PromptLoader()
        
        # Load system configuration
        self.available_apps = SystemUtils.load_available_applications()
        self.system_prompt = self.prompt_loader.load_system_prompt(
            available_applications=self.available_apps
        )
        
        # Store configuration
        self.debug = debug
    
    def refresh_applications(self):
        """Refresh applications list"""
        self.available_apps = SystemUtils.load_available_applications()
        self.system_prompt = self.prompt_loader.load_system_prompt(
            available_applications=self.available_apps
        )
        print(f"🔄 Applications list refreshed: {len(self.available_apps)} characters loaded")
    
    def show_applications(self):
        """Show available applications"""
        SystemUtils.parse_applications_for_display(self.available_apps)
    
    def print_initialization_summary(self):
        """Print initialization summary"""
        print("🤖 Agent Orchestrator initialized")
        print(f"🧠 LLM: {self.llm_info['provider']} - {self.llm_info['model']} ({self.llm_info['type']})")
        print(f"🎯 ActionExecutor: Intelligent action sequences enabled")
        print(f"📁 UI Inspector: {self.paths['ui_inspector']}")
        print(f"📝 Session logs: {self.logger.log_file}")
        print(f"📄 Summary: {self.logger.readable_file}")
        print(f"⏱️  Performance logs: {self.performance.log_file}") 