"""
Prompt History Logger - Comprehensive conversation logging

This module logs the complete conversation history between the system and LLM,
including full prompts sent and complete responses received.
"""

import json
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Any


class PromptHistoryLogger:
    """Logs complete conversation history with LLM for debugging and analysis"""
    
    def __init__(self):
        # Set up prompt history file path
        project_root = Path(__file__).parent.parent.parent.parent.parent
        self.prompt_history_file = project_root / "src" / "debug_output" / "prompt_history.txt"
        
        # Ensure debug output directory exists
        self.prompt_history_file.parent.mkdir(parents=True, exist_ok=True)
        
        # Initialize the file with session header
        self._initialize_session()
    
    def _initialize_session(self):
        """Initialize the prompt history file with session header"""
        session_start = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        
        with open(self.prompt_history_file, 'w') as f:
            f.write("🤖 AGENT COMPUTER USE - COMPLETE PROMPT HISTORY\n")
            f.write("=" * 80 + "\n")
            f.write(f"Session Started: {session_start}\n")
            f.write("=" * 80 + "\n")
            f.write("\nThis file contains the complete conversation history with the LLM.\n")
            f.write("Format: PROMPT → RESPONSE pairs with timestamps for debugging.\n")
            f.write("\n" + "=" * 80 + "\n\n")
    
    def log_prompt_and_response(self, messages: List[Dict[str, str]], llm_response: str):
        """
        Log the complete prompt sent to LLM and the response received.
        
        Args:
            messages: List of message dictionaries sent to LLM
            llm_response: Complete response received from LLM
        """
        try:
            timestamp = datetime.now().strftime("%H:%M:%S.%f")[:-3]
            
            with open(self.prompt_history_file, "a") as f:
                # Log the prompt (messages)
                f.write("=" * 50 + "\n")
                f.write(f"⬆️ [{timestamp}] PROMPT TO LLM:\n")
                f.write("=" * 50 + "\n")
                
                # Format messages in a readable way
                for i, message in enumerate(messages, 1):
                    role = message.get("role", "unknown")
                    content = message.get("content", "")
                    
                    f.write(f"\n[Message {i} - {role.upper()}]:\n")
                    f.write("-" * 30 + "\n")
                    f.write(content)
                    f.write("\n" + "-" * 30 + "\n")
                
                # Log the response
                f.write("\n" + "=" * 50 + "\n")
                f.write(f"⬇️ [{timestamp}] RESPONSE FROM LLM:\n")
                f.write("=" * 50 + "\n")
                f.write(llm_response)
                f.write("\n" + "=" * 50 + "\n\n")
                
        except Exception as e:
            print(f"⚠️ Failed to log prompt history: {e}")
    
    def log_api_error(self, messages: List[Dict[str, str]], error: str):
        """Log when an API error occurs"""
        try:
            timestamp = datetime.now().strftime("%H:%M:%S.%f")[:-3]
            
            with open(self.prompt_history_file, "a") as f:
                # Log the prompt that caused the error
                f.write("=" * 50 + "\n")
                f.write(f"⬆️ [{timestamp}] PROMPT TO LLM (ERROR):\n")
                f.write("=" * 50 + "\n")
                
                for i, message in enumerate(messages, 1):
                    role = message.get("role", "unknown")
                    content = message.get("content", "")
                    
                    f.write(f"\n[Message {i} - {role.upper()}]:\n")
                    f.write("-" * 30 + "\n")
                    f.write(content)
                    f.write("\n" + "-" * 30 + "\n")
                
                # Log the error
                f.write("\n" + "=" * 50 + "\n")
                f.write(f"❌ [{timestamp}] LLM API ERROR:\n")
                f.write("=" * 50 + "\n")
                f.write(f"Error: {error}")
                f.write("\n" + "=" * 50 + "\n\n")
                
        except Exception as e:
            print(f"⚠️ Failed to log API error: {e}")
    
    def get_log_file_path(self) -> str:
        """Get the path to the prompt history file"""
        return str(self.prompt_history_file)