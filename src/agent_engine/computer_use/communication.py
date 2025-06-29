"""
LLM Communicator - Handles all LLM communication

This module handles:
- Message building
- LLM API calls
- Response processing
- Context management
"""

from typing import Dict, List, Any, Optional


class LLMCommunicator:
    """Handles all LLM communication and message building"""
    
    @classmethod
    def initialize(cls, core) -> 'LLMCommunicator':
        """Initialize communicator with core dependencies"""
        communicator = cls()
        communicator.core = core
        communicator.llm_adapter = core.llm_adapter
        communicator.llm_info = core.llm_info
        communicator.prompt_orchestrator = core.prompt_orchestrator
        communicator.conversation = core.conversation
        communicator.ui_formatter = core.ui_formatter
        communicator.context_manager = core.context_manager
        communicator.performance = core.performance
        communicator.prompt_history = core.prompt_history
        return communicator
    
    async def get_decision(self, user_message: str, ui_state: Optional[Dict] = None) -> str:
        """Get LLM decision with message building and context injection"""
        model_display_name = f"{self.llm_info['provider']} {self.llm_info['model']}"
        start_time = self.performance.start_operation(model_display_name)
        
        try:
            # Build messages
            messages = self._build_messages(user_message, ui_state)
            
            # Get LLM response
            llm_response = await self.llm_adapter.chat_completion(
                messages=messages,
                temperature=0.1,
                max_tokens=1000
            )
            
            # Log the complete conversation to prompt history
            self.prompt_history.log_prompt_and_response(messages, llm_response)
            
            # Log performance
            tokens_used = len(llm_response.split()) * 1.3
            self.performance.end_operation(model_display_name, start_time, f"Tokens: {int(tokens_used)}")
            
            return llm_response
            
        except Exception as e:
            # Log the API error with the prompt that caused it
            messages = self._build_messages(user_message, ui_state)
            self.prompt_history.log_api_error(messages, str(e))
            
            self.performance.end_operation(model_display_name, start_time, f"Error: {str(e)}")
            return f'{{"action": "wait", "parameters": {{"seconds": 1}}, "reasoning": "LLM API error: {str(e)}"}}'
    
    async def get_next_decision(self, session) -> Dict[str, Any]:
        """Get next decision for a session"""
        task_message = self._build_task_message(session)
        
        # Inject context guidance
        self.context_manager.inject_messages_guidance_for_task(session.task, session.current_ui_state)
        
        # Get LLM response
        llm_response = await self.get_decision(task_message, session.current_ui_state)
        print(f"🤖 Agent Response: {llm_response}")
        
        # Parse response
        return self._parse_llm_response(llm_response)
    
    def _build_messages(self, user_message: str, ui_state: Optional[Dict] = None) -> List[Dict[str, str]]:
        """Build message list for LLM using centralized orchestrator"""
        return self.prompt_orchestrator.build_complete_messages(
            task_message=user_message,
            conversation_history=self.conversation.get_history(),
            ui_state=ui_state,
            available_apps=self.core.available_apps,
            ui_formatter=self.ui_formatter,
            context_manager=self.context_manager
        )
    
    def _build_task_message(self, session) -> str:
        """Build task message using centralized orchestrator"""
        return self.prompt_orchestrator.build_task_message(session.task, session.iteration)
    
    def _parse_llm_response(self, llm_response: str) -> Dict[str, Any]:
        """Parse LLM response using centralized orchestrator"""
        return self.prompt_orchestrator.extract_llm_response_json(llm_response) 