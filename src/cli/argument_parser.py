"""
Command Line Argument Parser - Handles CLI arguments and configuration
"""

import argparse
from typing import Optional
from dataclasses import dataclass


@dataclass
class AppConfiguration:
    """Application configuration from command line arguments"""
    debug: bool
    verbose: bool
    max_iterations: int
    task: Optional[str]
    list_blueprints: bool
    
    def is_list_blueprints_mode(self) -> bool:
        """Check if running in list blueprints mode"""
        return self.list_blueprints
    
    def is_prompt_mode(self) -> bool:
        """Check if running in prompt mode (default)"""
        return not self.is_list_blueprints_mode()


class ArgumentParser:
    """Handles command line argument parsing"""
    
    @staticmethod
    def parse_arguments() -> AppConfiguration:
        """Parse command line arguments and return configuration"""
        parser = argparse.ArgumentParser(description="Augment - AI Computer Control System")
        parser.add_argument("--debug", action="store_true", help="Enable debug mode")
        parser.add_argument("--verbose", action="store_true", help="Enable verbose mode")
        parser.add_argument("--max-iterations", type=int, default=100, help="Maximum iterations per task")
        parser.add_argument("--task", type=str, help="Task to execute via computer use")
        parser.add_argument("--list-blueprints", action="store_true", help="List available action blueprints and exit")
        
        args = parser.parse_args()
        
        return AppConfiguration(
            debug=args.debug,
            verbose=args.verbose,
            max_iterations=args.max_iterations,
            task=args.task,
            list_blueprints=args.list_blueprints
        ) 