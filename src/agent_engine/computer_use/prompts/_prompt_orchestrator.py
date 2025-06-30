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
                              task: str,
                              iteration: int,
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
        # 1. Build task context for system prompt
        task_context = self.build_task_context(task, iteration)
        
        # 2. Format conversation history for system prompt injection
        formatted_conversation = self.format_conversation_history(conversation_history)
        
        # 3. Build dynamic content
        dynamic_content = self._build_dynamic_content(
            ui_state=ui_state,
            ui_formatter=ui_formatter,
            context_manager=context_manager
        )
        
        # 4. Format UI state for system prompt
        formatted_ui_state = ""
        window_height_calc = "600"  # Default fallback
        if ui_state and ui_formatter:
            formatted_ui_state = ui_formatter.format_ui_state_for_llm(ui_state)
            
            # Calculate 75% of window height for scroll guidance
            window_height_calc = self._calculate_window_height_75(ui_state)
            
            # Inject app-specific guidance
            if context_manager:
                context_manager.inject_app_specific_guidance(ui_state)
        
        # 5. Build complete system prompt with all components
        system_prompt = self.prompt_loader.load_system_prompt(
            task_context=task_context,
            available_applications=available_apps,
            ui_state=formatted_ui_state,
            conversation_history=formatted_conversation,
            dynamic_prompt=dynamic_content,
            window_height_calc=window_height_calc
        )
        
        # 6. Assemble final message list (conversation history now in system prompt)
        messages = [{"role": "system", "content": system_prompt}]
        
        # 7. Add simple user prompt to proceed
        # user_message = "Please proceed with the next action." if iteration > 0 else "Please start by inspecting the current UI state."
        # messages.append({"role": "user", "content": user_message})
        
        return messages
    
    def build_task_context(self, task: str, iteration: int = 0) -> str:
        """
        Build task context for injection into system prompt
        
        Args:
            task: The main task description
            iteration: Current iteration (0 = first iteration)
        """
        if iteration == 0:
            return f"YOUR GOAL IS: {task}"
        else:
            return f"YOUR GOAL IS: {task}"
    
    def build_context_message(self, action_result, success: bool) -> str:
        """
        Build context messages for conversation history
        
        Args:
            action_result: Result from action execution
            success: Whether the action was successful
        """
        if success:
            return f"Action executed: {action_result}"
        else:
            return f"Action failed: {action_result}. Try again or try a different approach."
    
    def _build_dynamic_content(self, 
                             ui_state: Optional[Dict] = None,
                             ui_formatter=None,
                             context_manager=None) -> str:
        """Build dynamic content for injection into system prompt (excluding UI state)"""
        dynamic_parts = []
        
        # Add dynamic guidance from global injection system
        dynamic_guidance = get_dynamic_prompt_injections(clear_after=True)
        if dynamic_guidance:
            dynamic_parts.append(dynamic_guidance)
        
        # Join all dynamic content with separators
        if dynamic_parts:
            return "\n\n" + "\n\n".join(dynamic_parts)
        else:
            return ""
    
    def format_conversation_history(self, conversation_history: List[Dict[str, str]]) -> str:
        """Format conversation history for injection into system prompt"""
        if not conversation_history:
            return ""
        
        formatted_parts = ["CONVERSATION HISTORY:"]
        
        for message in conversation_history:
            role = message.get("role", "unknown")
            content = message.get("content", "")
            
            if role == "user":
                formatted_parts.append(f"USER: {content}")
            elif role == "assistant":
                formatted_parts.append(f"ASSISTANT: {content}")
            elif role == "system":
                formatted_parts.append(f"SYSTEM: {content}")
        
        return "\n".join(formatted_parts)
    
    def format_conversation_for_logging(self, messages: List[Dict[str, str]]) -> str:
        """Format conversation messages for logging/debugging"""
        formatted_parts = []
        
        for message in messages:
            role = message.get("role", "unknown").upper()
            content = message.get("content", "")
            formatted_parts.append(f"[{role}]: {content}")
        
        return "\n\n".join(formatted_parts)
    
    def _calculate_window_height_75(self, ui_state: Dict[str, Any]) -> str:
        """Calculate 75% of window height for scroll guidance"""
        try:
            # Extract window height from UI state
            window_frame = ui_state.get("window", {}).get("frame", {})
            window_height = window_frame.get("height", 800)  # Default to 800 if not found
            
            # Calculate 75% and convert to integer
            height_75_percent = int(window_height * 0.75)
            
            return str(height_75_percent)
        except Exception as e:
            # Fallback to safe default if calculation fails
            return "600"
    
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