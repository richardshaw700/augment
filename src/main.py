#!/usr/bin/env python3
"""
Augment - Main Entry Point & System Orchestrator

This file orchestrates the entire system through clear workflow phases.
Each step represents a major system operation in pseudocode style.
"""

import asyncio
import sys
from pathlib import Path

# Add project paths
project_root = Path(__file__).parent.parent
sys.path.append(str(project_root))
sys.path.append(str(project_root / "src"))

from src.cli.argument_parser import ArgumentParser, AppConfiguration
from src.core.logging import AugmentLogger
from src.config.llm_config import LLMConfig
from src.config.app_config import AppConfig
from src.execution.task_router import TaskRouter
from src.execution.task_tracker import TaskTracker
from src.execution.result_processor import ResultProcessor
from src.agent_engine.blueprint_loader import get_available_blueprints


async def main():
    """
    System Orchestrator - Complete workflow in pseudocode style:
    
    Phase 1: Startup & Configuration
    Phase 2: Environment Setup  
    Phase 3: Subsystem Initialization
    Phase 4: Execution Orchestration
    Phase 5: Session Finalization
    """
    
    # Initialize variables for cleanup
    logger = None
    task_tracker = None
    
    try:
        print("🚀 Starting Augment System...")
        
        # ============================================================
        # Phase 1: Startup & Configuration
        # ============================================================
        
        # 1. Parse command line arguments
        config = ArgumentParser.parse_arguments()
        
        # 2. Configure system settings (debug, verbose modes)
        AppConfig.set_debug_mode(config.debug)
        AppConfig.set_verbose_mode(config.verbose)
        
        # 3. Initialize logging system with session tracking
        logger = AugmentLogger(debug=config.debug, verbose=config.verbose)
        logger.section("SYSTEM STARTUP")
        
        # 4. Clean up previous session files
        _cleanup_debug_files(logger)
        
        # ============================================================
        # Phase 2: Environment Setup
        # ============================================================
        
        logger.subsection("Environment Validation")
        
        # 5. Validate API keys and environment variables
        if not _validate_environment():
            return 1
            
        # 6. Initialize and validate LLM configuration  
        llm_provider, llm_model = LLMConfig.get_selected_provider()
        llm_key = LLMConfig.get_selected_key()
        
        # 7. Display system status and selected LLM provider
        logger.success("✅ Environment validation successful")
        logger.info(f"🧠 LLM Provider: {llm_provider}")
        logger.info(f"🤖 Model: {llm_model} ({llm_key})")
        
        # ============================================================
        # Phase 3: Subsystem Initialization  
        # ============================================================
        
        logger.subsection("Subsystem Initialization")
        
        # 8. Initialize task execution router
        task_router = TaskRouter(debug=config.debug, max_iterations=config.max_iterations)
        logger.debug("✅ Task Router initialized")
        
        # 9. Initialize session tracking system
        task_tracker = TaskTracker()  
        logger.debug("✅ Task Tracker initialized")
        
        # 10. Initialize result processing pipeline
        result_processor = ResultProcessor()
        logger.debug("✅ Result Processor initialized")
        
        # 11. Initialize UI inspection system (via task router)
        logger.debug("✅ UI Inspector system ready")
        
        # Display system ready status
        debug_settings = AppConfig.get_debug_settings()
        logger.success("🤖 Augment System Initialized")
        logger.info(f"🔧 Debug: {'ON' if debug_settings['debug'] else 'OFF'} | Verbose: {'ON' if debug_settings['verbose'] else 'OFF'}")
        
        # ============================================================
        # Phase 4: Execution Orchestration
        # ============================================================
        
        # 12. Determine execution mode (blueprints vs prompt)
        if config.is_list_blueprints_mode():
            
            # 13a. BLUEPRINTS MODE
            logger.section("BLUEPRINTS MODE")
            
            # Load available action blueprints
            available_blueprints = get_available_blueprints()
            
            # Display blueprint catalog with usage examples
            if not available_blueprints:
                logger.info("No action blueprints found.")
                logger.info("Create blueprints in src/workflow_automation/action_blueprints/")
            else:
                logger.info(f"Found {len(available_blueprints)} blueprint(s):")
                for number in sorted(available_blueprints.keys()):
                    summary = available_blueprints[number] 
                    logger.info(f"  {number}. {summary}")
                
                logger.info("")
                logger.info("Usage examples:")
                logger.info("  python3 src/main.py --task 'Execute blueprint 2'")
                logger.info("  python3 src/main.py --task 'Run workflow 3'")
                
        elif config.task:
            
            # 13b. PROMPT MODE
            logger.section("PROMPT MODE")
            logger.info(f"Task: {config.task}")
            
            # Create new task session
            from src.execution.strategy_selector import ExecutionStrategy, ExecutionType
            strategy = ExecutionStrategy(
                strategy_type=ExecutionType.COMPUTER_USE,
                confidence=1.0,
                reasoning="Direct computer use execution from prompt"
            )
            session = task_tracker.initialize_task(config.task, None, strategy)
            logger.debug("✅ Task session created")
            
            # Execute task via computer use system
            logger.subsection("Task Execution")
            raw_results = await task_router._execute_computer_use_task(session)
            logger.debug("✅ Task execution completed")
            
            # Process execution results
            final_results = result_processor.finalize_results(session, raw_results)
            completed_session = task_tracker.finalize_task(session, final_results)
            logger.debug("✅ Results processed")
            
            # Display formatted results
            logger.subsection("TASK RESULTS")
            formatted_display = result_processor.format_task_display(completed_session)
            for line in formatted_display.split('\n'):
                logger.info(line)
                
        else:
            # Invalid usage
            print("Usage: python3 src/main.py --task 'your task here' or --list-blueprints")
            return 1
            
    except KeyboardInterrupt:
        if logger:
            logger.info("Application terminated by user")
        else:
            print("\n[INFO] Application terminated by user")
            
    except Exception as e:
        if logger:
            logger.error(f"Application error: {str(e)}")
        else:
            print(f"[ERROR] Application error: {str(e)}")
        return 1
        
    finally:
        # ============================================================
        # Phase 5: Session Finalization
        # ============================================================
        
        if logger and task_tracker:
            try:
                # 14. Display session statistics and summary
                logger.section("SESSION SUMMARY")
                stats = task_tracker.get_formatted_stats()
                logger.info(f"Total Tasks: {stats['total_tasks']}")
                logger.info(f"Completed: {stats['tasks_completed']} | Failed: {stats['tasks_failed']}")
                logger.info(f"Success Rate: {stats['success_rate']}")
                logger.info(f"Actions Executed: {stats['actions_executed']}")
                logger.info(f"Total Execution Time: {stats['total_execution_time']}")
                
                # 15. Save logs and session data to files
                logger.info(f"Log file saved to: {logger.get_log_file_path()}")
                
                # 16. Cleanup temporary files and resources (handled automatically)
                logger.debug("✅ Session cleanup completed")
                
            except Exception as cleanup_error:
                if logger:
                    logger.debug(f"Cleanup error (non-critical): {cleanup_error}")
    
    return 0


def _validate_environment() -> bool:
    """Validate environment setup and API keys"""
    if not LLMConfig.validate_environment():
        required_vars = LLMConfig.get_required_env_vars()
        print("❌ Environment validation failed:")
        for var, desc in required_vars.items():
            print(f"   {var} not found in environment ({desc})")
        print("💡 Create a .env file with required API keys")
        return False
    return True


def _cleanup_debug_files(logger: AugmentLogger):
    """Clean up all debug output files before starting a new session"""
    project_root = Path(__file__).parent.parent
    debug_dir = project_root / "src" / "debug_output"
    
    if debug_dir.exists():
        cleanup_count = 0
        for file in debug_dir.glob("*"):
            if file.is_file() and file.name != ".gitkeep":
                try:
                    file.unlink()
                    cleanup_count += 1
                except Exception:
                    pass  # Silently ignore cleanup failures
        
        if cleanup_count > 0:
            logger.debug(f"🧹 Cleaned up {cleanup_count} debug files")


if __name__ == "__main__":
    exit_code = asyncio.run(main())
    sys.exit(exit_code) 