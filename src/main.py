#!/usr/bin/env python3
"""
Augment - Main Coordinating Application
Orchestrates UI inspection, GPT reasoning, and action execution for AI computer control
"""

import asyncio
import json
import os
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Any, Optional
import argparse
from dotenv import load_dotenv
import logging

# =============================================================================
# 🚀 MASTER DEBUG CONFIGURATION
# =============================================================================
DEBUG = True          # Clean, readable output for main operations
VERBOSE = False       # Detailed drilling down for deep debugging

# Add project paths
project_root = Path(__file__).parent.parent
sys.path.append(str(project_root))
sys.path.append(str(project_root / "src"))

from gpt_engine.gpt_computer_use import GPTComputerUse, ActionResult

# Load environment
load_dotenv()

# =============================================================================
# 📝 LOGGING CONFIGURATION
# =============================================================================
class AugmentLogger:
    """Enhanced logging system for Augment with debug and verbose modes"""
    
    def __init__(self, debug: bool = DEBUG, verbose: bool = VERBOSE):
        self.debug_enabled = debug
        self.verbose_enabled = verbose
        self.log_file = project_root / "src" / "debug_output" / "latest_run_logs.txt"
        self.session_start = datetime.now()
        
        # Initialize log file
        self._initialize_log_file()
        
        # Setup logging
        self._setup_logging()
    
    def _initialize_log_file(self):
        """Initialize the log file with session header"""
        with open(self.log_file, 'w') as f:
            f.write("🚀 AUGMENT SYSTEM - DEBUG LOG\n")
            f.write("=" * 60 + "\n")
            f.write(f"Session Started: {self.session_start.strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"Debug Mode: {'ON' if self.debug_enabled else 'OFF'}\n")
            f.write(f"Verbose Mode: {'ON' if self.verbose_enabled else 'OFF'}\n")
            f.write("=" * 60 + "\n\n")
    
    def _setup_logging(self):
        """Setup Python logging configuration"""
        logging.basicConfig(
            level=logging.DEBUG if self.verbose_enabled else logging.INFO,
            format='%(asctime)s [%(levelname)s] %(message)s',
            handlers=[
                logging.FileHandler(self.log_file, mode='a'),
                logging.StreamHandler(sys.stdout) if self.debug_enabled else logging.NullHandler()
            ]
        )
        self.logger = logging.getLogger('augment')
    
    def debug(self, message: str, component: str = "MAIN"):
        """Log debug message (only if DEBUG is True)"""
        if self.debug_enabled:
            timestamp = datetime.now().strftime("%H:%M:%S.%f")[:-3]
            formatted_message = f"[{timestamp}] [{component}] {message}"
            print(formatted_message)
            self._write_to_file(formatted_message)
    
    def verbose(self, message: str, component: str = "VERBOSE"):
        """Log verbose message (only if VERBOSE is True)"""
        if self.verbose_enabled:
            timestamp = datetime.now().strftime("%H:%M:%S.%f")[:-3]
            formatted_message = f"[{timestamp}] [VERBOSE] [{component}] {message}"
            print(formatted_message)
            self._write_to_file(formatted_message)
    
    def info(self, message: str, component: str = "INFO"):
        """Log info message (always shown)"""
        timestamp = datetime.now().strftime("%H:%M:%S.%f")[:-3]
        formatted_message = f"[{timestamp}] [{component}] {message}"
        print(formatted_message)
        self._write_to_file(formatted_message)
    
    def error(self, message: str, component: str = "ERROR"):
        """Log error message (always shown)"""
        timestamp = datetime.now().strftime("%H:%M:%S.%f")[:-3]
        formatted_message = f"[{timestamp}] [❌ {component}] {message}"
        print(formatted_message)
        self._write_to_file(formatted_message)
    
    def success(self, message: str, component: str = "SUCCESS"):
        """Log success message (always shown)"""
        timestamp = datetime.now().strftime("%H:%M:%S.%f")[:-3]
        formatted_message = f"[{timestamp}] [✅ {component}] {message}"
        print(formatted_message)
        self._write_to_file(formatted_message)
    
    def section(self, title: str):
        """Log section header"""
        separator = "=" * 60
        section_msg = f"\n{separator}\n🎯 {title.upper()}\n{separator}"
        print(section_msg)
        self._write_to_file(section_msg)
    
    def subsection(self, title: str):
        """Log subsection header"""
        separator = "-" * 40
        subsection_msg = f"\n{separator}\n📋 {title}\n{separator}"
        if self.debug_enabled:
            print(subsection_msg)
        self._write_to_file(subsection_msg)
    
    def _write_to_file(self, message: str):
        """Write message to log file"""
        try:
            with open(self.log_file, 'a') as f:
                f.write(message + "\n")
        except Exception as e:
            print(f"Warning: Failed to write to log file: {e}")
    
    def get_log_file_path(self) -> str:
        """Get the path to the log file"""
        return str(self.log_file)

# Global logger instance
logger = AugmentLogger(debug=DEBUG, verbose=VERBOSE)

class AugmentController:
    """
    Main controller that coordinates between UI inspection, GPT reasoning, and action execution
    """
    
    def __init__(self, debug: bool = DEBUG, max_iterations: int = 20):
        self.debug = debug
        self.max_iterations = max_iterations
        self.gpt_engine = GPTComputerUse()
        self.session_history = []
        self.start_time = datetime.now()
        
        # Performance tracking
        self.stats = {
            "tasks_completed": 0,
            "actions_executed": 0,
            "ui_inspections": 0,
            "errors": 0,
            "total_cost_estimate": 0.0
        }
        
        logger.section("AUGMENT CONTROLLER INITIALIZATION")
        logger.success("Augment Controller Initialized", "INIT")
        logger.debug(f"Debug Mode: {'ON' if debug else 'OFF'}", "INIT")
        logger.debug(f"Max Iterations: {max_iterations}", "INIT")
        logger.debug(f"Log File: {logger.get_log_file_path()}", "INIT")
    
    async def execute_task(self, task: str, task_id: Optional[str] = None) -> Dict[str, Any]:
        """
        Execute a task with full coordination between all components
        """
        if not task_id:
            task_id = f"task_{len(self.session_history) + 1}_{int(datetime.now().timestamp())}"
        
        task_start = datetime.now()
        
        logger.section(f"TASK EXECUTION [{task_id}]")
        logger.info(f"Task: {task}", "TASK")
        logger.debug(f"Started at: {task_start.strftime('%H:%M:%S')}", "TASK")
        logger.verbose(f"Max iterations: {self.max_iterations}", "TASK")
        
        # Initialize task tracking
        task_record = {
            "task_id": task_id,
            "task": task,
            "start_time": task_start.isoformat(),
            "actions": [],
            "status": "running",
            "error": None,
            "performance": {}
        }
        
        try:
            logger.debug("Initializing GPT engine for task execution", "GPT")
            
            # Execute task using GPT engine
            logger.verbose("Calling GPT engine execute_task method", "GPT")
            results = await self.gpt_engine.execute_task(task, self.max_iterations)
            
            logger.debug(f"GPT engine returned {len(results) if results else 0} actions", "GPT")
            
            # Process results
            task_record["actions"] = results
            task_record["status"] = "completed" if results else "failed"
            
            # Update statistics
            self.stats["tasks_completed"] += 1
            self.stats["actions_executed"] += len(results) if results else 0
            self.stats["ui_inspections"] += sum(1 for r in results if r["action"]["action"] == "ui_inspect") if results else 0
            
            logger.verbose(f"Updated stats - tasks: {self.stats['tasks_completed']}, actions: {self.stats['actions_executed']}", "STATS")
            
            # Calculate performance metrics
            task_end = datetime.now()
            task_duration = (task_end - task_start).total_seconds()
            
            task_record["end_time"] = task_end.isoformat()
            task_record["duration"] = task_duration
            task_record["performance"] = {
                "duration_seconds": task_duration,
                "actions_per_second": len(results) / task_duration if task_duration > 0 and results else 0,
                "success_rate": sum(1 for r in results if r["result"].success) / len(results) if results else 0
            }
            
            logger.debug(f"Task completed in {task_duration:.2f} seconds", "TASK")
            
            # Display results
            self._display_task_results(task_record)
            
        except Exception as e:
            task_record["status"] = "error"
            task_record["error"] = str(e)
            self.stats["errors"] += 1
            logger.error(f"Task failed with error: {str(e)}", "TASK")
            logger.verbose(f"Full error traceback: {e}", "ERROR")
        
        # Add to session history
        self.session_history.append(task_record)
        logger.debug(f"Task record added to session history (total: {len(self.session_history)})", "SESSION")
        
        return task_record
    
    def _display_task_results(self, task_record: Dict[str, Any]):
        """Display formatted task results"""
        logger.subsection("TASK RESULTS")
        
        task_id = task_record['task_id']
        status = task_record['status'].upper()
        duration = task_record.get('duration', 0)
        
        logger.info(f"Task ID: {task_id}", "RESULTS")
        
        if status == "COMPLETED":
            logger.success(f"Status: {status}", "RESULTS")
        elif status == "ERROR":
            logger.error(f"Status: {status}", "RESULTS")
        else:
            logger.info(f"Status: {status}", "RESULTS")
            
        logger.debug(f"Duration: {duration:.2f} seconds", "RESULTS")
        
        actions = task_record.get("actions", [])
        if actions:
            logger.debug(f"Actions Executed: {len(actions)}", "RESULTS")
            
            # Show action summary
            action_types = {}
            for action in actions:
                action_type = action["action"]["action"]
                action_types[action_type] = action_types.get(action_type, 0) + 1
            
            logger.debug("Action Breakdown:", "RESULTS")
            for action_type, count in action_types.items():
                logger.debug(f"  - {action_type}: {count}", "RESULTS")
            
            # Show success rate
            successful = sum(1 for a in actions if a["result"].success)
            success_rate = (successful / len(actions)) * 100
            
            if success_rate == 100:
                logger.success(f"Success Rate: {success_rate:.1f}% ({successful}/{len(actions)})", "RESULTS")
            elif success_rate >= 80:
                logger.info(f"Success Rate: {success_rate:.1f}% ({successful}/{len(actions)})", "RESULTS")
            else:
                logger.error(f"Success Rate: {success_rate:.1f}% ({successful}/{len(actions)})", "RESULTS")
            
            # Detailed action log
            logger.verbose("Detailed Action Log:", "ACTIONS")
            for i, action in enumerate(actions, 1):
                status_icon = "✅" if action["result"].success else "❌"
                action_name = action["action"]["action"]
                reasoning = action["action"].get("reasoning", "")
                logger.verbose(f"  {i}. {status_icon} {action_name} - {reasoning}", "ACTIONS")
                
                # Extra verbose details
                if VERBOSE:
                    if hasattr(action["result"], 'output') and action["result"].output:
                        logger.verbose(f"     Output: {action['result'].output[:100]}...", "ACTIONS")
                    if hasattr(action["result"], 'error') and action["result"].error:
                        logger.verbose(f"     Error: {action['result'].error}", "ACTIONS")
        else:
            logger.error("No actions were executed", "RESULTS")
    
    def display_session_stats(self):
        """Display overall session statistics"""
        session_duration = (datetime.now() - self.start_time).total_seconds()
        
        logger.section("SESSION STATISTICS")
        logger.info(f"Session Duration: {session_duration:.1f} seconds", "STATS")
        logger.info(f"Tasks Completed: {self.stats['tasks_completed']}", "STATS")
        logger.info(f"Total Actions: {self.stats['actions_executed']}", "STATS")
        logger.info(f"UI Inspections: {self.stats['ui_inspections']}", "STATS")
        
        if self.stats['errors'] > 0:
            logger.error(f"Errors: {self.stats['errors']}", "STATS")
        else:
            logger.success(f"Errors: {self.stats['errors']}", "STATS")
        
        if self.stats['tasks_completed'] > 0:
            avg_actions = self.stats['actions_executed'] / self.stats['tasks_completed']
            logger.debug(f"Average Actions per Task: {avg_actions:.1f}", "STATS")
        
        # Cost estimation (rough)
        estimated_cost = (self.stats['actions_executed'] * 0.01) + (self.stats['ui_inspections'] * 0.005)
        logger.debug(f"Estimated API Cost: ${estimated_cost:.3f}", "STATS")
        
        # Performance insights
        if session_duration > 0:
            actions_per_second = self.stats['actions_executed'] / session_duration
            logger.verbose(f"Actions per Second: {actions_per_second:.2f}", "PERFORMANCE")
            
        if self.stats['actions_executed'] > 0:
            ui_inspection_ratio = (self.stats['ui_inspections'] / self.stats['actions_executed']) * 100
            logger.verbose(f"UI Inspection Ratio: {ui_inspection_ratio:.1f}%", "PERFORMANCE")
    
    async def interactive_mode(self):
        """Run in interactive mode for testing and demonstration"""
        logger.section("INTERACTIVE MODE")
        logger.info("Type tasks in natural language, or use these commands:", "INTERACTIVE")
        logger.info("  'stats' - Show session statistics", "INTERACTIVE")
        logger.info("  'history' - Show task history", "INTERACTIVE")
        logger.info("  'debug on/off' - Toggle debug mode", "INTERACTIVE")
        logger.info("  'verbose on/off' - Toggle verbose mode", "INTERACTIVE")
        logger.info("  'quit' - Exit the application", "INTERACTIVE")
        
        while True:
            try:
                timestamp = datetime.now().strftime('%H:%M:%S')
                print(f"\n[{timestamp}] Enter task or command: ", end="")
                user_input = input().strip()
                
                if not user_input:
                    continue
                
                logger.debug(f"User input: '{user_input}'", "INPUT")
                
                # Handle commands
                if user_input.lower() in ['quit', 'exit', 'q']:
                    logger.info("Goodbye!", "INTERACTIVE")
                    break
                elif user_input.lower() == 'stats':
                    self.display_session_stats()
                elif user_input.lower() == 'history':
                    self._display_history()
                elif user_input.lower().startswith('debug'):
                    if 'on' in user_input.lower():
                        global DEBUG
                        DEBUG = True
                        self.debug = True
                        logger.debug_enabled = True
                        logger.success("Debug mode enabled", "CONFIG")
                    elif 'off' in user_input.lower():
                        DEBUG = False
                        self.debug = False
                        logger.debug_enabled = False
                        logger.info("Debug mode disabled", "CONFIG")
                    else:
                        logger.info(f"Debug mode: {'ON' if self.debug else 'OFF'}", "CONFIG")
                elif user_input.lower().startswith('verbose'):
                    if 'on' in user_input.lower():
                        global VERBOSE
                        VERBOSE = True
                        logger.verbose_enabled = True
                        logger.success("Verbose mode enabled", "CONFIG")
                    elif 'off' in user_input.lower():
                        VERBOSE = False
                        logger.verbose_enabled = False
                        logger.info("Verbose mode disabled", "CONFIG")
                    else:
                        logger.info(f"Verbose mode: {'ON' if VERBOSE else 'OFF'}", "CONFIG")
                else:
                    # Execute as task
                    logger.debug(f"Executing task: {user_input}", "TASK")
                    await self.execute_task(user_input)
                    
            except KeyboardInterrupt:
                logger.info("Task interrupted by user", "INTERRUPT")
            except EOFError:
                logger.info("Goodbye!", "INTERACTIVE")
                break
            except Exception as e:
                logger.error(f"Unexpected error: {str(e)}", "ERROR")
                if self.debug:
                    import traceback
                    logger.verbose(f"Full traceback: {traceback.format_exc()}", "ERROR")
    
    def _display_history(self):
        """Display task history"""
        if not self.session_history:
            logger.info("No tasks executed in this session.", "HISTORY")
            return
        
        logger.subsection(f"TASK HISTORY ({len(self.session_history)} tasks)")
        
        for i, task in enumerate(self.session_history, 1):
            status_icon = "✅" if task["status"] == "completed" else "❌" if task["status"] == "error" else "⏳"
            duration = task.get("duration", 0)
            actions_count = len(task.get("actions", []))
            
            task_display = task['task'][:50] + ('...' if len(task['task']) > 50 else '')
            logger.info(f"{i}. {status_icon} {task_display}", "HISTORY")
            logger.debug(f"   Duration: {duration:.1f}s | Actions: {actions_count} | ID: {task['task_id']}", "HISTORY")
            
            # Show verbose details if enabled
            if VERBOSE and task.get("error"):
                logger.verbose(f"   Error: {task['error']}", "HISTORY")

async def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description="Augment - AI Computer Control System")
    parser.add_argument("--debug", action="store_true", help="Enable debug mode")
    parser.add_argument("--verbose", action="store_true", help="Enable verbose mode")
    parser.add_argument("--max-iterations", type=int, default=20, help="Maximum iterations per task")
    parser.add_argument("--task", type=str, help="Execute a single task and exit")
    parser.add_argument("--batch", type=str, help="Execute tasks from JSON file")
    
    args = parser.parse_args()
    
    # Update global debug flags if specified via command line
    global DEBUG, VERBOSE
    if args.debug:
        DEBUG = True
    if args.verbose:
        VERBOSE = True
    
    # Reinitialize logger with updated flags
    global logger
    logger = AugmentLogger(debug=DEBUG, verbose=VERBOSE)
    
    # Check environment
    if not os.getenv('OPENAI_API_KEY'):
        logger.error("OPENAI_API_KEY not found in environment", "SETUP")
        logger.info("Create a .env file with your OpenAI API key", "SETUP")
        logger.info("Example: echo 'OPENAI_API_KEY=your_key_here' > .env", "SETUP")
        return
    
    logger.success("OpenAI API key found", "SETUP")
    
    # Initialize controller
    controller = AugmentController(debug=DEBUG, max_iterations=args.max_iterations)
    
    try:
        if args.task:
            # Single task mode
            logger.section("SINGLE TASK MODE")
            await controller.execute_task(args.task)
            controller.display_session_stats()
        
        elif args.batch:
            # Batch mode
            logger.section("BATCH MODE")
            with open(args.batch, 'r') as f:
                batch_tasks = json.load(f)
            
            logger.info(f"Executing {len(batch_tasks)} batch tasks...", "BATCH")
            for i, task in enumerate(batch_tasks, 1):
                logger.subsection(f"Batch Task {i}/{len(batch_tasks)}")
                await controller.execute_task(task, f"batch_{i}")
            
            controller.display_session_stats()
        
        else:
            # Interactive mode
            await controller.interactive_mode()
    
    except KeyboardInterrupt:
        logger.info("Application terminated by user", "MAIN")
    except Exception as e:
        logger.error(f"Application error: {str(e)}", "MAIN")
        if DEBUG:
            import traceback
            logger.verbose(f"Full traceback: {traceback.format_exc()}", "ERROR")
    finally:
        logger.section("SESSION SUMMARY")
        controller.display_session_stats()
        logger.info(f"Log file saved to: {logger.get_log_file_path()}", "MAIN")

if __name__ == "__main__":
    asyncio.run(main()) 