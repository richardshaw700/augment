"""
Main Application - High-level orchestration in pseudocode style
"""

import os
from pathlib import Path
from typing import Dict, Any, Optional

from .logging import AugmentLogger
from src.config.llm_config import LLMConfig
from src.config.app_config import AppConfig
from src.execution.task_router import TaskRouter
from src.execution.task_tracker import TaskTracker, TaskSession
from src.execution.result_processor import ResultProcessor
from src.cli.argument_parser import AppConfiguration
from src.agent_engine.blueprint_loader import get_available_blueprints


class Application:
    """
    Main application orchestrator - reads like pseudocode
    
    High-level workflow:
    1. Parse configuration
    2. Initialize all subsystems  
    3. Execute based on mode (single/batch/interactive/list)
    4. Display results
    """
    
    def __init__(self):
        # Will be initialized later via initialize()
        self.logger: Optional[AugmentLogger] = None
        self.task_router: Optional[TaskRouter] = None
        self.task_tracker: Optional[TaskTracker] = None
        self.result_processor: Optional[ResultProcessor] = None
    
    @classmethod
    def initialize(cls, config: AppConfiguration) -> 'Application':
        """
        Initialize application with configuration - pseudocode style:
        
        1. Setup configuration
        2. Initialize logging
        3. Validate environment
        4. Initialize subsystems
        5. Display initialization summary
        """
        app = cls()
        
        # 1. Setup configuration
        app._configure_system(config)
        
        # 2. Initialize logging
        app.logger = AugmentLogger(debug=config.debug, verbose=config.verbose)
        
        # 3. Clean up previous debug files
        app._cleanup_debug_files()
        
        # 4. Validate environment
        if not app._validate_environment():
            raise RuntimeError("Environment validation failed")
        
        # 5. Initialize subsystems
        app._initialize_subsystems(config)
        
        # 6. Display initialization summary
        app._display_initialization_summary()
        
        return app
    
    async def execute_prompt_task(self, task: str) -> TaskSession:
        """Execute a task via computer use - pseudocode style"""
        self.logger.section("PROMPT MODE")
        
        # 1. Create computer use strategy (no strategy selection needed)
        from src.execution.strategy_selector import ExecutionStrategy, ExecutionType
        strategy = ExecutionStrategy(
            strategy_type=ExecutionType.COMPUTER_USE,
            confidence=1.0,
            reasoning="Direct computer use execution from prompt"
        )
        
        self.logger.debug(f"Strategy: Computer Use (direct execution)")
        
        # 2. Initialize task session
        session = self.task_tracker.initialize_task(task, None, strategy)
        
        # 3. Execute via computer use (no routing needed)
        raw_results = await self.task_router._execute_computer_use_task(session)
        
        # 4. Process and finalize results
        final_results = self.result_processor.finalize_results(session, raw_results)
        completed_session = self.task_tracker.finalize_task(session, final_results)
        
        # 5. Display results
        self._display_task_results(completed_session)
        
        return completed_session
    
    def display_available_blueprints(self):
        """Display available action blueprints - pseudocode style"""
        self.logger.section("AVAILABLE ACTION BLUEPRINTS")
        
        # 1. Get available blueprints
        available_blueprints = get_available_blueprints()
        
        # 2. Display results
        if not available_blueprints:
            self.logger.info("No action blueprints found.")
            self.logger.info("Create blueprints in src/workflow_automation/action_blueprints/")
            return
        
        # 3. Format and display
        self.logger.info(f"Found {len(available_blueprints)} blueprint(s):")
        for number in sorted(available_blueprints.keys()):
            summary = available_blueprints[number]
            self.logger.info(f"  {number}. {summary}")
        
        # 4. Show usage examples
        self._display_blueprint_usage_examples()
    

    
    def display_final_summary(self):
        """Display final session summary"""
        self.logger.section("SESSION SUMMARY")
        
        # 1. Get formatted stats
        stats = self.task_tracker.get_formatted_stats()
        
        # 2. Display stats
        self.logger.info(f"Total Tasks: {stats['total_tasks']}")
        self.logger.info(f"Completed: {stats['tasks_completed']} | Failed: {stats['tasks_failed']}")
        self.logger.info(f"Success Rate: {stats['success_rate']}")
        self.logger.info(f"Actions Executed: {stats['actions_executed']}")
        self.logger.info(f"Total Execution Time: {stats['total_execution_time']}")
        
        # 3. Display log file location
        self.logger.info(f"Log file saved to: {self.logger.get_log_file_path()}")
    
    # Private helper methods (implementation details)
    def _configure_system(self, config: AppConfiguration):
        """Configure system settings"""
        AppConfig.set_debug_mode(config.debug)
        AppConfig.set_verbose_mode(config.verbose)
    
    def _cleanup_debug_files(self):
        """Clean up all debug output files before starting a new session"""
        project_root = Path(__file__).parent.parent.parent
        debug_dir = project_root / "src" / "debug_output"
        
        if debug_dir.exists():
            for file in debug_dir.glob("*"):
                if file.is_file() and file.name != ".gitkeep":
                    try:
                        file.unlink()
                        if self.logger:
                            self.logger.debug(f"Deleted: {file.name}", "CLEANUP")
                    except Exception:
                        pass  # Silently ignore cleanup failures
    
    def _validate_environment(self) -> bool:
        """Validate environment setup"""
        if not LLMConfig.validate_environment():
            required_vars = LLMConfig.get_required_env_vars()
            for var, desc in required_vars.items():
                print(f"❌ {var} not found in environment ({desc})")
            print("Create a .env file with required API keys")
            return False
        
        print("✅ Environment validation successful")
        return True
    
    def _initialize_subsystems(self, config: AppConfiguration):
        """Initialize all subsystems"""
        self.task_router = TaskRouter(debug=config.debug, max_iterations=config.max_iterations)
        self.task_tracker = TaskTracker()
        self.result_processor = ResultProcessor()
    
    def _display_initialization_summary(self):
        """Display initialization summary"""
        llm_key = LLMConfig.get_selected_key()
        provider, model = LLMConfig.get_selected_provider()
        debug_settings = AppConfig.get_debug_settings()
        
        self.logger.success("🤖 Augment System Initialized")
        self.logger.info(f"🧠 LLM: {provider} - {model} ({llm_key})")
        self.logger.info(f"🔧 Debug: {'ON' if debug_settings['debug'] else 'OFF'} | Verbose: {'ON' if debug_settings['verbose'] else 'OFF'}")
    

    
    def _display_task_results(self, session):
        """Display task execution results"""
        formatted_display = self.result_processor.format_task_display(session)
        self.logger.subsection("TASK RESULTS")
        for line in formatted_display.split('\n'):
            self.logger.info(line)
    
    def _display_blueprint_usage_examples(self):
        """Display blueprint usage examples"""
        self.logger.info("")
        self.logger.info("Usage examples:")
        self.logger.info("  python3 src/main.py --task 'Execute blueprint 2'")
        self.logger.info("  python3 src/main.py --task 'Run workflow 3'")
    
 