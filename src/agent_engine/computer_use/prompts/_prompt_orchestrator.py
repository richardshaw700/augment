"""
Prompt Orchestrator - Centralized prompt assembly and management

This module handles ALL prompt assembly logic in one place:
- System prompt building with dynamic content
- Task message formatting
- Conversation formatting
- Context injection
- Message list assembly
"""

import json
from typing import Dict, List, Any, Optional
from .loader import PromptLoader
from src.agent_engine.dynamic_prompts import get_dynamic_prompt_injections


class PromptOrchestrator:
    """Centralized orchestrator for all prompt assembly operations"""
    
    def __init__(self, prompt_loader: PromptLoader):
        self.prompt_loader = prompt_loader
        
    def build_complete_messages(self, 
                              task_message: str,
                              conversation_history: List[Dict[str, str]],
                              ui_state: Optional[Dict] = None,
                              available_apps: str = "",
                              ui_formatter=None,
                              context_manager=None) -> List[Dict[str, str]]:
        """
        Build complete message list for LLM - SINGLE SOURCE OF TRUTH
        
        This is the ONLY method that should assemble final messages for the LLM.
        All other components should route through here.
        """
        # 1. Build dynamic content
        dynamic_content = self._build_dynamic_content(
            ui_state=ui_state,
            ui_formatter=ui_formatter,
            context_manager=context_manager
        )
        
        # 2. Build complete system prompt
        system_prompt = self.prompt_loader.load_system_prompt(
            available_applications=available_apps,
            dynamic_prompt=dynamic_content
        )
        
        # 3. Assemble final message list
        messages = [{"role": "system", "content": system_prompt}]
        messages.extend(conversation_history)
        messages.append({"role": "user", "content": task_message})
        
        return messages
    
    def build_task_message(self, task: str, iteration: int = 0) -> str:
        """
        Build task messages - centralized task message formatting
        
        Args:
            task: The main task description
            iteration: Current iteration (0 = first iteration)
        """
        if iteration == 0:
            return f"Task: {task}\n\nPlease start by inspecting the current UI state to understand what's on screen."
        else:
            return f"Continue with the task: {task}\n\nWhat should be the next action?"
    
    def build_context_message(self, action_result, success: bool) -> str:
        """
        Build context messages for conversation history
        
        Args:
            action_result: Result from action execution
            success: Whether the action was successful
        """
        if success:
            return f"Action succeeded: {action_result}"
        else:
            return f"Action failed: {action_result}. Try a different approach."
    
    def _build_dynamic_content(self, 
                             ui_state: Optional[Dict] = None,
                             ui_formatter=None,
                             context_manager=None) -> str:
        """Build all dynamic content for injection into system prompt"""
        dynamic_parts = []
        
        # Add UI state if available
        if ui_state and ui_formatter:
            formatted_ui = ui_formatter.format_ui_state_for_llm(ui_state)
            dynamic_parts.append(f"Current UI State:\n{formatted_ui}")
            
            # Inject app-specific guidance
            if context_manager:
                context_manager.inject_app_specific_guidance(ui_state)
        
        # Add dynamic guidance from global injection system
        dynamic_guidance = get_dynamic_prompt_injections(clear_after=True)
        if dynamic_guidance:
            dynamic_parts.append(dynamic_guidance)
        
        # Join all dynamic content with separators
        if dynamic_parts:
            return "\n\n" + "\n\n".join(dynamic_parts)
        else:
            return ""
    
    def format_conversation_for_logging(self, messages: List[Dict[str, str]]) -> str:
        """Format conversation messages for logging/debugging"""
        formatted_parts = []
        
        for message in messages:
            role = message.get("role", "unknown").upper()
            content = message.get("content", "")
            formatted_parts.append(f"[{role}]: {content}")
        
        return "\n\n".join(formatted_parts)
    
    def extract_llm_response_json(self, llm_response: str) -> Dict[str, Any]:
        """Extract and parse JSON from LLM response"""
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