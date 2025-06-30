"""
Agent Orchestrator - Pure pseudocode orchestration

This file reads like executable pseudocode. No implementation details.
Each method is a single line that delegates to specialized modules.

Think of this as a conductor's score - it tells each musician when to play.
"""

import asyncio
from typing import Dict, List, Any, Optional
import time

from .core import AgentCore
from .execution import TaskExecutor
from .communication import LLMCommunicator
from .monitoring import SessionMonitor


class AgentOrchestrator:
    """
    Workflow:
    1. Initialize all modules  
    2. Execute task: ask → act → check → repeat
    3. Provide summary
    """
    
    def __init__(self, llm_provider: str = "openai", llm_model: str = "gpt-4o-mini", debug: bool = False):
        """Initialize all modules"""
        self.core = AgentCore.initialize(llm_provider, llm_model, debug)
        self.executor = TaskExecutor.initialize(self.core)
        self.communicator = LLMCommunicator.initialize(self.core)
        self.monitor = SessionMonitor.initialize(self.core)
        self.core.print_initialization_summary()
    
    def refresh_applications_list(self):
        """Available applications on computer (stored in system_inspector)"""
        self.core.refresh_applications()
    
    def show_available_applications(self):
        """Show applications"""
        self.core.show_applications()
    
    @property
    def llm_adapter(self):
        """Provide access to LLM adapter for backward compatibility"""
        return self.core.llm_adapter
    
    async def execute_single_action(self, action_data: Dict[str, Any]) -> Any:
        """Execute action"""
        return await self.executor.execute_action(action_data)
    
    async def get_llm_decision(self, user_message: str, ui_state: Optional[Dict] = None) -> str:
        """Get LLM decision"""
        return await self.communicator.get_decision(user_message, ui_state)
    
    async def execute_task(self, task: str, max_iterations: int = 100) -> List[Dict]:

        # === SETUP PHASE ===
        print("🚀 Starting Agent Computer Use")
        print(f"📝 Task: {task}")
        print("=" * 60)
        
        session = self.monitor.setup_task(task, max_iterations)
        
        # ==========================
        # ==========================
        # === MAIN EXECUTION LOOP ===
        # ==========================
        # ==========================
        while not session.is_complete():
            print(f"\n🔄 Iteration {session.iteration + 1}/{max_iterations}")
            
            # 1. Inject Context-Specific Guidance
            self.communicator.context_manager.inject_messages_guidance_for_task(task, session.current_ui_state)
            
            # 2. Get LLM Decision (task context now injected into system prompt)
            llm_response = await self.communicator.get_decision(task, session.iteration, session.current_ui_state)
            
            # Format response for Swift frontend consumption
            timestamp = f"[{time.strftime('%H:%M:%S.%f')[:-3]}]"
            print(f"⬇️ {timestamp} RESPONSE FROM LLM:")
            
            # Parse the JSON to get the action/reasoning
            try:
                parsed_decision = self._parse_llm_response(llm_response)
                
                # Create enhanced JSON with raw response included
                enhanced_response = parsed_decision.copy()
                enhanced_response["raw_llm_response"] = llm_response
                
                # Output the enhanced JSON for Swift frontend
                import json
                print(json.dumps(enhanced_response, indent=2))
                print("=" * 50)
                
            except Exception as e:
                # If parsing fails, still output the raw response
                print(f'{{"action": "error", "parameters": {{}}, "reasoning": "Failed to parse LLM response", "raw_llm_response": {json.dumps(llm_response)}}}')
                print("=" * 50)
                print(f"❌ Failed to parse Agent response: {e}")
                session.consecutive_failures += 1
                if session.consecutive_failures >= 3:
                    session.completion_reason = "json_parse_failures"
                    break
                continue
            
            # 5. Validate Task Compliance
            self.communicator.context_manager.validate_task_compliance(task, parsed_decision, session.current_ui_state)
            
            # 6. Execute Action
            execution_result = await self.executor.execute_action(parsed_decision)
            
            # 7. Process Result and Update Session
            session = self.monitor.process_result(session, parsed_decision, execution_result, llm_response)
            
            # 8. Check Completion Status
            if session.completion_reason != "max_iterations_reached":
                break
                
        # === FINALIZATION PHASE ===
        final_results = self.monitor.finalize_task(session)
        return final_results
    

    
    def _parse_llm_response(self, llm_response: str) -> Dict[str, Any]:
        """Parse LLM response JSON"""
        import json
        json_start = llm_response.find('{')
        json_end = llm_response.rfind('}') + 1
        if json_start != -1 and json_end > json_start:
            json_str = llm_response[json_start:json_end]
            return json.loads(json_str)
        else:
            raise ValueError("No JSON found in LLM response")


