"""
Task Router - Routes tasks to appropriate execution systems
"""

import time
from typing import Dict, Any

from .strategy_selector import ExecutionStrategy, ExecutionType
from .task_tracker import TaskSession

# Import execution systems
from src.agent_engine.computer_use import AgentOrchestrator
from src.actions.smart_llm_actions import SmartLLMActions
from src.agent_engine.blueprint_loader import load_blueprint
from src.agent_engine.dynamic_prompts import inject_action_blueprint_guidance


class TaskRouter:
    """Routes tasks to appropriate execution systems"""
    
    def __init__(self, debug: bool = True, max_iterations: int = 100):
        # Initialize execution systems
        from src.config.llm_config import LLMConfig
        from src.actions.action_executor import ActionExecutor
        
        llm_provider, llm_model = LLMConfig.get_selected_provider()
        
        self.agent_orchestrator = AgentOrchestrator(
            llm_provider=llm_provider,
            llm_model=llm_model,
            debug=debug
        )
        
        # Initialize SmartLLMActions with required dependencies
        action_executor = ActionExecutor()
        llm_adapter = self.agent_orchestrator.llm_adapter
        self.smart_llm_actions = SmartLLMActions(action_executor, llm_adapter, debug=debug)
        
        self.max_iterations = max_iterations
    
    async def execute_with_strategy(self, session: TaskSession) -> Dict[str, Any]:
        """Route task to the appropriate execution system based on strategy"""
        strategy = session.strategy
        
        if strategy.strategy_type == ExecutionType.MESSAGING:
            return await self._execute_messaging_task(session)
        elif strategy.strategy_type == ExecutionType.ACTION_BLUEPRINT:
            return await self._execute_blueprint_task(session)
        elif strategy.strategy_type == ExecutionType.SMART_LLM:
            return await self._execute_smart_llm_task(session)
        elif strategy.strategy_type == ExecutionType.HYBRID:
            return await self._execute_hybrid_task(session)
        elif strategy.strategy_type == ExecutionType.COMPUTER_USE:
            return await self._execute_computer_use_task(session)
        else:
            return {
                "task_id": session.task_id,
                "success": False,
                "error": f"Unknown execution strategy: {strategy.strategy_type}",
                "execution_time": 0.0
            }
    
    async def _execute_messaging_task(self, session: TaskSession) -> Dict[str, Any]:
        """Execute messaging task via Smart LLM Actions"""
        try:
            result = await self.smart_llm_actions.execute_task(session.task)
            
            return {
                "task_id": session.task_id,
                "success": result.success,
                "error": result.error if not result.success else None,
                "output": result.output,
                "task_type": "MESSAGING",
                "total_actions": 1,
                "successful_actions": 1 if result.success else 0
            }
            
        except Exception as e:
            return {
                "task_id": session.task_id,
                "success": False,
                "error": str(e),
                "task_type": "MESSAGING"
            }
    
    async def _execute_blueprint_task(self, session: TaskSession) -> Dict[str, Any]:
        """Execute action blueprint workflow"""
        try:
            blueprint_number = session.strategy.blueprint_number
            if blueprint_number is None:
                return {
                    "task_id": session.task_id,
                    "success": False,
                    "error": "Invalid blueprint number in task"
                }
            
            # Load the blueprint
            blueprint_steps = load_blueprint(blueprint_number)
            if not blueprint_steps:
                return {
                    "task_id": session.task_id,
                    "success": False,
                    "error": f"Blueprint {blueprint_number} not found"
                }
            
            # Inject blueprint guidance into dynamic prompts
            inject_action_blueprint_guidance(blueprint_steps, priority=5)
            
            # Create a task for Agent Orchestrator that includes the blueprint
            blueprint_task = f"Execute this ACTION BLUEPRINT step by step:\n" + "\n".join(
                f"{i}. {step}" for i, step in enumerate(blueprint_steps, 1)
            )
            
            # Execute using Agent Orchestrator with blueprint guidance
            results = await self.agent_orchestrator.execute_task(
                blueprint_task, 
                max_iterations=len(blueprint_steps) + 5
            )
            
            # Process results
            successful_actions = sum(1 for r in results if r["result"].success)
            
            return {
                "task_id": session.task_id,
                "success": successful_actions > 0,
                "blueprint_number": blueprint_number,
                "blueprint_steps": blueprint_steps,
                "results": results,
                "successful_actions": successful_actions,
                "total_actions": len(results),
                "task_type": "ACTION_BLUEPRINT"
            }
            
        except Exception as e:
            return {
                "task_id": session.task_id,
                "success": False,
                "error": str(e),
                "task_type": "ACTION_BLUEPRINT"
            }
    
    async def _execute_smart_llm_task(self, session: TaskSession) -> Dict[str, Any]:
        """Execute task via Smart LLM Actions"""
        try:
            result = await self.smart_llm_actions.execute_task(session.task)
            
            return {
                "task_id": session.task_id,
                "success": result.success,
                "error": result.error if not result.success else None,
                "output": result.output,
                "reasoning": result.reasoning if hasattr(result, 'reasoning') else None,
                "task_type": "SMART_LLM",
                "total_actions": 1,
                "successful_actions": 1 if result.success else 0
            }
            
        except Exception as e:
            return {
                "task_id": session.task_id,
                "success": False,
                "error": str(e),
                "task_type": "SMART_LLM"
            }
    
    async def _execute_hybrid_task(self, session: TaskSession) -> Dict[str, Any]:
        """Execute task via hybrid LLM+Computer Use approach"""
        try:
            # Try Smart LLM first
            smart_result = await self.smart_llm_actions.execute_task(session.task)
            
            if smart_result.success:
                return {
                    "task_id": session.task_id,
                    "success": True,
                    "output": smart_result.output,
                    "approach": "smart_llm",
                    "task_type": "HYBRID",
                    "total_actions": 1,
                    "successful_actions": 1
                }
            else:
                # Fall back to computer use
                results = await self.agent_orchestrator.execute_task(session.task, self.max_iterations)
                successful_actions = sum(1 for r in results if r["result"].success)
                
                return {
                    "task_id": session.task_id,
                    "success": successful_actions > 0,
                    "results": results,
                    "successful_actions": successful_actions,
                    "total_actions": len(results),
                    "approach": "computer_use_fallback",
                    "smart_llm_error": smart_result.error,
                    "task_type": "HYBRID"
                }
                
        except Exception as e:
            return {
                "task_id": session.task_id,
                "success": False,
                "error": str(e),
                "task_type": "HYBRID"
            }
    
    async def _execute_computer_use_task(self, session: TaskSession) -> Dict[str, Any]:
        """Execute task via traditional computer use"""
        try:
            results = await self.agent_orchestrator.execute_task(session.task, self.max_iterations)
            successful_actions = sum(1 for r in results if r["result"].success)
            
            return {
                "task_id": session.task_id,
                "success": successful_actions > 0,
                "results": results,
                "successful_actions": successful_actions,
                "total_actions": len(results),
                "task_type": "COMPUTER_USE"
            }
            
        except Exception as e:
            return {
                "task_id": session.task_id,
                "success": False,
                "error": str(e),
                "task_type": "COMPUTER_USE"
            } 