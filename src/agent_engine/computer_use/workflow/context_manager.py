"""
App-specific context management and guidance
"""

import re
from typing import Dict, Any, Optional
from pathlib import Path

# Import dynamic prompts system
project_root = Path(__file__).parent.parent.parent.parent
import sys
sys.path.append(str(project_root))

try:
    from src.agent_engine.dynamic_prompts import (
        inject_app_context_guidance,
        inject_messages_app_guidance
    )
except ImportError:
    # Fallback for when refactoring is in progress
    def inject_app_context_guidance(*args, **kwargs):
        pass
    def inject_messages_app_guidance(*args, **kwargs):
        pass


class ContextManager:
    """Manages app-specific context and provides intelligent guidance"""
    
    def __init__(self, debug: bool = False):
        self.debug = debug
    
    def inject_app_specific_guidance(self, ui_state: Dict[str, Any]):
        """Inject app-specific guidance based on current UI state."""
        try:
            # Get window information
            window_info = ui_state.get("window", {})
            window_title = window_info.get("title", "").lower()
            compressed_output = ui_state.get("compressedOutput", "")
            
            # Detect Messages app
            if "messages" in window_title or compressed_output.startswith("Messages|"):
                self._handle_messages_app_context(compressed_output)
            
            # Can add other app detections here
            # elif "safari" in window_title:
            #     self._handle_safari_context(compressed_output)
            
        except Exception as e:
            # Don't let app detection errors break the main flow
            if self.debug:
                print(f"Warning: App-specific guidance injection failed: {e}")
    
    def _handle_messages_app_context(self, compressed_output: str):
        """Handle Messages app specific context and guidance"""
        # Extract active chat from compressed output
        active_chat = None
        
        # Parse the actual format: "txt:To: Cara Davidson@24:3"
        if "txt:To: " in compressed_output:
            # Find the "To: " pattern and extract the name
            to_match = re.search(r'txt:To: ([^@]+)@', compressed_output)
            if to_match:
                active_chat = to_match.group(1).strip()
        
        # Try to determine target recipient from task context or UI
        # Look for button patterns that might indicate search results
        search_buttons = re.findall(r'btn:([^@]+)@\d+:\d+', compressed_output)
        available_contacts = [btn for btn in search_buttons if "Mom" in btn or "Kiddos" in btn or "'" in btn]
        
        # Create context info
        context_info = {
            "active_chat": active_chat,
            "available_contacts": available_contacts
        }
        
        # Add target recipient if we can infer it from available contacts
        if available_contacts:
            context_info["target_recipient"] = available_contacts[0]
        
        # Inject Messages app guidance with enhanced context
        inject_app_context_guidance("messages", context_info)
    
    def inject_messages_guidance_for_task(self, task: str, ui_state: Dict[str, Any]):
        """Inject specific Messages app guidance based on task requirements"""
        if "messages" not in task.lower() or not ui_state or "compressedOutput" not in ui_state:
            return
        
        compressed_output = ui_state["compressedOutput"]
        
        # Extract target chat name from task
        if "to " in task.lower():
            task_words = task.lower().split()
            to_index = task_words.index("to")
            if to_index + 1 < len(task_words):
                # Get chat name from task (handle "Mom's Kiddos" format)
                target_chat = ""
                for i in range(to_index + 1, len(task_words)):
                    word = task_words[i]
                    if word in ["in", "that", "says"]:
                        break
                    target_chat += word + " "
                target_chat = target_chat.strip().replace("'s", "'s")
                
                # Extract active chat from "To: [Name]" pattern
                active_chat = None
                if "txt:To: " in compressed_output:
                    to_match = re.search(r'txt:To: ([^@]+)@', compressed_output)
                    if to_match:
                        active_chat = to_match.group(1).strip()
                
                # Extract available contacts from button patterns
                available_contacts = []
                if "btn:" in compressed_output:
                    btn_matches = re.findall(r'btn:([^@]+)@\d+:\d+', compressed_output)
                    for btn_text in btn_matches:
                        btn_text = btn_text.strip()
                        if btn_text not in ["Button", "Compose", "Record audio", "info", "Emoji picker", "Apps"] and len(btn_text) > 2:
                            available_contacts.append(btn_text)
                
                # Inject Messages app guidance with context BEFORE Agent makes decision
                inject_messages_app_guidance(
                    active_chat=active_chat,
                    target_recipient=target_chat,
                    available_contacts=available_contacts,
                    priority=5  # High priority for this critical issue
                )
                
                # Debug logging
                if self.debug:
                    print(f"🔍 MESSAGES CONTEXT: Active='{active_chat}', Target='{target_chat}', Available={available_contacts}")
    
    def validate_task_compliance(self, task: str, action_data: Dict[str, Any], ui_state: Optional[Dict[str, Any]] = None):
        """Validate that actions comply with the original task requirements"""
        if action_data.get("action") != "type":
            return
        
        typed_text = action_data.get("parameters", {}).get("text", "")
        print(f"🔍 Task Compliance Check:")
        print(f"   Original Task: {task}")
        print(f"   Agent Typed: {typed_text}")
        
        # Check if the typed text matches task requirements
        if "message" in task.lower() and "says" in task.lower():
            # Extract expected message from task
            task_lower = task.lower()
            if "says \"" in task_lower:
                start = task_lower.find("says \"") + 6
                end = task_lower.find("\"", start)
                if end > start:
                    expected_message = task[start:end]
                    if expected_message.lower() not in typed_text.lower():
                        print(f"⚠️  TASK COMPLIANCE WARNING: Expected message '{expected_message}' not found in typed text '{typed_text}'")
                    else:
                        print(f"✅ TASK COMPLIANCE: Message matches expected content")
        
        # Simple task compliance check for Messages tasks
        if "messages" in task.lower() and ui_state and "compressedOutput" in ui_state:
            compressed_output = ui_state["compressedOutput"]
            
            # Extract active chat from "To: [Name]" pattern for logging
            active_chat = None
            if "txt:To: " in compressed_output:
                to_match = re.search(r'txt:To: ([^@]+)@', compressed_output)
                if to_match:
                    active_chat = to_match.group(1).strip()
            
            # Simple warning if typing to wrong chat
            if "to " in task.lower():
                task_words = task.lower().split()
                to_index = task_words.index("to")
                if to_index + 1 < len(task_words):
                    target_chat = ""
                    for i in range(to_index + 1, len(task_words)):
                        word = task_words[i]
                        if word in ["in", "that", "says"]:
                            break
                        target_chat += word + " "
                    target_chat = target_chat.strip().replace("'s", "'s")
                    
                    if target_chat and active_chat and active_chat.lower() != target_chat.lower():
                        print(f"⚠️  CHAT SELECTION WARNING: Typing to '{active_chat}' but task requires '{target_chat}'")
                    elif target_chat and active_chat:
                        print(f"✅ CHAT SELECTION: Correctly typing to '{target_chat}' chat")