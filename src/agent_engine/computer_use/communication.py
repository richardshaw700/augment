"""
LLM Communicator - Handles all LLM communication

This module handles:
- Message building
- LLM API calls
- Response processing
- Context management
"""

import json
from typing import Dict, List, Any, Optional
from ..dynamic_prompts import get_dynamic_prompt_injections


class LLMCommunicator:
    """Handles all LLM communication and message building"""
    
    @classmethod
    def initialize(cls, core) -> 'LLMCommunicator':
        """Initialize communicator with core dependencies"""
        communicator = cls()
        communicator.core = core
        communicator.llm_adapter = core.llm_adapter
        communicator.llm_info = core.llm_info
        communicator.system_prompt = core.system_prompt
        communicator.conversation = core.conversation
        communicator.ui_formatter = core.ui_formatter
        communicator.context_manager = core.context_manager
        communicator.performance = core.performance
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
            
            # Log performance
            tokens_used = len(llm_response.split()) * 1.3
            self.performance.end_operation(model_display_name, start_time, f"Tokens: {int(tokens_used)}")
            
            return llm_response
            
        except Exception as e:
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
        """Build message list for LLM"""
        messages = [{"role": "system", "content": self.system_prompt}]
        messages.extend(self.conversation.get_history())
        
        # Add UI state
        if ui_state:
            formatted_ui = self.ui_formatter.format_ui_state_for_llm(ui_state)
            messages.append({"role": "system", "content": f"Current UI State:\n{formatted_ui}"})
            self.context_manager.inject_app_specific_guidance(ui_state)
        
        # Add dynamic guidance
        dynamic_guidance = get_dynamic_prompt_injections(clear_after=True)
        if dynamic_guidance:
            messages.append({"role": "system", "content": dynamic_guidance})
        
        messages.append({"role": "user", "content": user_message})
        return messages
    
    def _build_task_message(self, session) -> str:
        """Build task message based on session state"""
        if session.iteration == 0:
            return f"Task: {session.task}\n\nPlease start by inspecting the current UI state to understand what's on screen."
        else:
            return f"Continue with the task: {session.task}\n\nWhat should be the next action?"
    
    def _parse_llm_response(self, llm_response: str) -> Dict[str, Any]:
        """Parse LLM response into action data"""
        try:
            json_start = llm_response.find('{')
            json_end = llm_response.rfind('}') + 1
            if json_start != -1 and json_end > json_start:
                json_str = llm_response[json_start:json_end]
                return json.loads(json_str)
            else:
                raise json.JSONDecodeError("No JSON found", llm_response, 0)
        except json.JSONDecodeError as e:
            print(f"❌ Failed to parse Agent response as JSON: {llm_response}")
            raise e 