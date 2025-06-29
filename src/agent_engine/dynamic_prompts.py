"""
Dynamic Prompt Injection System

This module handles dynamic feedback and guidance that gets injected into Agent prompts
based on system state, action results, and context analysis.
"""

from typing import List, Dict, Any, Optional
import logging
from pathlib import Path

logger = logging.getLogger(__name__)

# Try to import the new prompt loader
try:
    from .computer_use.prompts import PromptLoader
    # Initialize prompt loader for dynamic templates
    _prompt_loader = PromptLoader()
except ImportError:
    # Fallback for when refactoring is in progress
    _prompt_loader = None


class DynamicPromptManager:
    """Manages dynamic prompt injections based on system state and action results."""
    
    def __init__(self):
        self.active_injections = []
        self.injection_history = []
    
    def add_injection(self, injection_type: str, content: str, priority: int = 1):
        """Add a dynamic injection to be included in the next prompt."""
        injection = {
            'type': injection_type,
            'content': content,
            'priority': priority,
            'timestamp': None  # Could add timestamp if needed
        }
        self.active_injections.append(injection)
        logger.debug(f"Added dynamic injection: {injection_type}")
    
    def get_injections(self, clear_after: bool = True) -> List[Dict[str, Any]]:
        """Get all active injections and optionally clear them."""
        injections = sorted(self.active_injections, key=lambda x: x['priority'], reverse=True)
        
        if clear_after:
            self.injection_history.extend(self.active_injections)
            self.active_injections.clear()
        
        return injections
    
    def format_injections_for_prompt(self, clear_after: bool = True) -> str:
        """Format all active injections into a string for prompt inclusion."""
        injections = self.get_injections(clear_after)
        
        if not injections:
            return ""
        
        formatted = "\n🎯 DYNAMIC GUIDANCE:\n"
        for injection in injections:
            formatted += f"• {injection['content']}\n"
        
        return formatted + "\n"
    
    def clear_injections(self):
        """Clear all active injections."""
        self.injection_history.extend(self.active_injections)
        self.active_injections.clear()


# Specific injection generators
class ActionResultInjections:
    """Generates injections based on action execution results."""
    
    @staticmethod
    def generate_navigation_success(url: str, action_type: str) -> str:
        """Generate injection for successful navigation."""
        return f"✅ Navigation successful! {action_type} completed and page loaded {url}. Task may be complete - check if goal achieved."
    
    @staticmethod
    def generate_focus_guidance(field_name: str) -> str:
        """Generate injection for focus handling guidance."""
        return f"🎯 Focus handled automatically for '{field_name}' - no need to click first when using 'field' parameter."
    
    @staticmethod
    def generate_completion_detected(task_description: str) -> str:
        """Generate injection when task completion is detected."""
        if _prompt_loader:
            try:
                return _prompt_loader.load_dynamic_prompt("completion", task_description=task_description)
            except Exception:
                pass
        # Fallback
        return f"🎉 TASK COMPLETION DETECTED: {task_description}. Consider if goal is achieved."
    
    @staticmethod
    def generate_strategy_recommendation(strategy: str, confidence: float) -> str:
        """Generate injection for recommended action strategy."""
        confidence_text = "high" if confidence > 0.8 else "medium" if confidence > 0.6 else "low"
        return f"💡 Recommended strategy: {strategy} (confidence: {confidence_text})"


class ContextInjections:
    """Generates injections based on UI context analysis."""
    
    @staticmethod
    def generate_form_warning(form_type: str) -> str:
        """Generate warning for sensitive form contexts."""
        warnings = {
            'login': "⚠️ Login form detected - avoid pressing Enter after password input",
            'security': "🔒 Security context detected - use caution with automatic actions",
            'captcha': "🤖 CAPTCHA detected - manual intervention may be required",
            'complex': "📝 Complex form detected - consider individual field completion"
        }
        return warnings.get(form_type, f"⚠️ {form_type} context detected - proceed carefully")
    
    @staticmethod
    def generate_browser_context(browser_info: Dict[str, Any]) -> str:
        """Generate injection for browser-specific context."""
        if browser_info.get('is_loading'):
            return "🔄 Page is loading - wait for completion before next action"
        elif browser_info.get('has_errors'):
            return "❌ Page load errors detected - verify URL or try refresh"
        elif browser_info.get('url_changed'):
            return f"🔗 URL changed to {browser_info.get('current_url')} - verify if this is expected"
        return ""
    
    @staticmethod
    def generate_messages_app_guidance(active_chat: str = None, target_recipient: str = None, available_contacts: list = None) -> str:
        """Generate Messages app specific guidance."""
        base_guidance = """🔍 CRITICAL: MESSAGES APP CONTEXT AWARENESS
When working with Messages app, ALWAYS check the window header for active chat context:
- Look for "To: [Name]" in the UI elements (e.g., "txt:To: Cara Davidson@24:3")
- This tells you WHO you are currently chatting with
- Contact names in the sidebar/search are NOT the active chat - they are just search results or contact lists
- NEVER assume you're in the right chat just because you see a name in the UI
- If you need to message someone different, you MUST first click on their name in the contacts list to switch chats
- Only send messages when the active chat matches your target recipient

⚠️ CRITICAL MISTAKE TO AVOID:
- Searching for a contact shows results but DOES NOT switch to that chat
- You MUST click the contact button/name after searching to actually enter their chat
- Seeing "btn:Mom's Kiddos@2:11" means it's a clickable button - CLICK IT to switch chats
- Do NOT type messages until you've clicked the contact and verified "To: [Name]" changed

MESSAGES WORKFLOW:
1. Check "To: [Name]" in UI elements to see current recipient
2. If wrong recipient, search for correct contact 
3. CLICK the contact's button/name from search results (e.g., "btn:Mom's Kiddos@2:11")
4. Verify "To: [Name]" changed to correct recipient  
5. Only then type and send your message"""
        
        # Add specific context if we have active chat info
        if active_chat and target_recipient:
            if active_chat.lower() == target_recipient.lower():
                return f"{base_guidance}\n\n✅ CURRENT STATUS: Correctly chatting with {active_chat} - ready to send message"
            else:
                guidance = f"{base_guidance}\n\n⚠️ CURRENT STATUS: Active chat is '{active_chat}' but need to message '{target_recipient}' - MUST switch chats first!"
                
                # Add specific button guidance if available
                if available_contacts:
                    guidance += f"\n\n🎯 ACTION NEEDED: Click the '{target_recipient}' button to switch to the correct chat before sending message"
                
                return guidance
        elif active_chat:
            return f"{base_guidance}\n\n📍 CURRENT STATUS: Active chat is '{active_chat}'"
        elif available_contacts:
            return f"{base_guidance}\n\n🔍 SEARCH RESULTS: Found contacts: {', '.join(available_contacts)} - Click the correct one to start chatting"
        
        return base_guidance


class PerformanceInjections:
    """Generates injections based on performance and efficiency metrics."""
    
    @staticmethod
    def generate_efficiency_tip(action_count: int, time_elapsed: float) -> str:
        """Generate efficiency tips based on performance metrics."""
        if action_count > 10:
            tip = "⚡ Consider using action sequences (field parameter) to reduce action count"
        elif time_elapsed > 30:
            tip = "⏱️ Task taking longer than expected - verify if goal is already achieved"
        else:
            return ""
        
        if _prompt_loader:
            try:
                return _prompt_loader.load_dynamic_prompt("efficiency", efficiency_tip=tip)
            except Exception:
                pass
        # Fallback
        return tip
    
    @staticmethod
    def generate_loop_detection(repeated_action: str, count: int) -> str:
        """Generate injection when action loops are detected."""
        if count >= 3:
            return f"🔄 LOOP DETECTED: '{repeated_action}' repeated {count} times. Try different approach or check if goal achieved."
        return ""


# Global instance for easy access
dynamic_prompt_manager = DynamicPromptManager()


# Convenience functions for common injection patterns
def inject_navigation_success(url: str, action_type: str, priority: int = 3):
    """Quick function to inject navigation success feedback."""
    content = ActionResultInjections.generate_navigation_success(url, action_type)
    dynamic_prompt_manager.add_injection('navigation_success', content, priority)


def inject_focus_guidance(field_name: str, priority: int = 2):
    """Quick function to inject focus handling guidance."""
    content = ActionResultInjections.generate_focus_guidance(field_name)
    dynamic_prompt_manager.add_injection('focus_guidance', content, priority)


def inject_completion_detected(task_description: str, priority: int = 5):
    """Quick function to inject task completion detection."""
    content = ActionResultInjections.generate_completion_detected(task_description)
    dynamic_prompt_manager.add_injection('completion_detected', content, priority)


def inject_strategy_recommendation(strategy: str, confidence: float, priority: int = 2):
    """Quick function to inject strategy recommendations."""
    content = ActionResultInjections.generate_strategy_recommendation(strategy, confidence)
    dynamic_prompt_manager.add_injection('strategy_recommendation', content, priority)


def inject_form_warning(form_type: str, priority: int = 4):
    """Quick function to inject form context warnings."""
    content = ContextInjections.generate_form_warning(form_type)
    dynamic_prompt_manager.add_injection('form_warning', content, priority)


def inject_browser_context(browser_info: Dict[str, Any], priority: int = 3):
    """Quick function to inject browser context information."""
    content = ContextInjections.generate_browser_context(browser_info)
    if content:  # Only inject if there's actual content
        dynamic_prompt_manager.add_injection('browser_context', content, priority)


def inject_efficiency_tip(action_count: int, time_elapsed: float, priority: int = 1):
    """Quick function to inject efficiency tips."""
    content = PerformanceInjections.generate_efficiency_tip(action_count, time_elapsed)
    if content:  # Only inject if there's actual content
        dynamic_prompt_manager.add_injection('efficiency_tip', content, priority)


def inject_loop_detection(repeated_action: str, count: int, priority: int = 4):
    """Quick function to inject loop detection warnings."""
    content = PerformanceInjections.generate_loop_detection(repeated_action, count)
    if content:  # Only inject if there's actual content
        dynamic_prompt_manager.add_injection('loop_detection', content, priority)


def inject_messages_app_guidance(active_chat: str = None, target_recipient: str = None, available_contacts: list = None, priority: int = 4):
    """Quick function to inject Messages app specific guidance."""
    content = ContextInjections.generate_messages_app_guidance(active_chat, target_recipient, available_contacts)
    dynamic_prompt_manager.add_injection('messages_app_guidance', content, priority)


def inject_action_blueprint_guidance(blueprint_steps: list, priority: int = 5):
    """Quick function to inject ACTION_BLUEPRINT execution guidance."""
    content = f"""🎯 ACTION BLUEPRINT EXECUTION MODE:
Execute the following recorded workflow steps one by one by finding the relevant targets in the current UI state.

BLUEPRINT STEPS:
{chr(10).join(f"{i}. {step}" for i, step in enumerate(blueprint_steps, 1))}

EXECUTION STRATEGY:
When given ACTION BLUEPRINT steps, execute them by finding the relevant targets in the current UI state.

Example: ACTION: CLICK | target=txt:iMessage | app=Messages
LLM Reasoning: "I see txt:iMessage@23:49 in the UI, so I'll click 23:49"

If there are no direct matches, figure out what to do next by semantically understanding what the step is supposed to accomplish.

Example: ACTION: CLICK | target=Cara | app=Messages  
LLM Reasoning: "No direct match for 'Cara' in the current Messages UI. This is likely a contact name, so I should search for 'Cara' in the search bar first."

IMPORTANT: 
- Find exact targets in compressed UI when possible (e.g., txt:iMessage@23:49)
- If exact target not found, use semantic reasoning to accomplish the goal
- Execute steps sequentially - complete each step before moving to the next
- Use ui_inspect first to understand current state
- Adapt to UI changes while maintaining the workflow intent"""
    
    dynamic_prompt_manager.add_injection('action_blueprint_guidance', content, priority)

def inject_app_context_guidance(app_name: str, context_info: Dict[str, Any] = None, priority: int = 3):
    """Quick function to inject app-specific context guidance."""
    if app_name.lower() == "messages":
        active_chat = context_info.get('active_chat') if context_info else None
        target_recipient = context_info.get('target_recipient') if context_info else None
        available_contacts = context_info.get('available_contacts') if context_info else None
        inject_messages_app_guidance(active_chat, target_recipient, available_contacts, priority)
    # Can add other app-specific guidance here in the future
    # elif app_name.lower() == "safari":
    #     inject_browser_context(context_info or {}, priority)


# Helper function to get formatted injections for prompt inclusion
def get_dynamic_prompt_injections(clear_after: bool = True) -> str:
    """Get all formatted dynamic injections for inclusion in prompts."""
    return dynamic_prompt_manager.format_injections_for_prompt(clear_after) 