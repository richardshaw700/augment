#!/usr/bin/env python3
"""
Blueprint Loader - Loads action blueprints from workflow_automation/action_blueprints
"""

from pathlib import Path
from typing import List, Optional, Dict
import re

class BlueprintLoader:
    """Loads and manages action blueprints from the workflow automation system"""
    
    def __init__(self):
        # Get the project root and blueprints directory
        self.project_root = Path(__file__).parent.parent.parent
        self.blueprints_dir = self.project_root / "src" / "workflow_automation" / "action_blueprints"
    
    def get_available_blueprints(self) -> Dict[int, str]:
        """Get dictionary of available blueprint numbers and their file paths"""
        available = {}
        
        if not self.blueprints_dir.exists():
            return available
        
        # Find all blueprint files
        blueprint_files = list(self.blueprints_dir.glob("blueprint_*.txt"))
        
        for file in blueprint_files:
            try:
                # Extract number from filename like "blueprint_5.txt"
                filename = file.stem  # Gets "blueprint_5" from "blueprint_5.txt"
                if filename.startswith("blueprint_"):
                    number_str = filename[10:]  # Remove "blueprint_" prefix
                    number = int(number_str)
                    available[number] = str(file)
            except (ValueError, IndexError):
                # Skip files that don't match the expected pattern
                continue
        
        return available
    
    def load_blueprint(self, blueprint_number: int) -> Optional[List[str]]:
        """Load a specific blueprint by number and return list of action steps"""
        available = self.get_available_blueprints()
        
        if blueprint_number not in available:
            return None
        
        blueprint_file = Path(available[blueprint_number])
        
        try:
            with open(blueprint_file, 'r') as f:
                content = f.read().strip()
            
            # Parse the numbered steps
            lines = content.split('\n')
            action_steps = []
            
            for line in lines:
                line = line.strip()
                if not line:
                    continue
                
                # Remove the numbering (e.g., "1. ACTION: CLICK..." -> "ACTION: CLICK...")
                if re.match(r'^\d+\.\s*', line):
                    action_step = re.sub(r'^\d+\.\s*', '', line)
                    action_steps.append(action_step)
                else:
                    # Line without numbering, add as-is
                    action_steps.append(line)
            
            return action_steps if action_steps else None
            
        except Exception as e:
            print(f"⚠️ Failed to load blueprint {blueprint_number}: {e}")
            return None
    
    def get_blueprint_summary(self, blueprint_number: int) -> Optional[str]:
        """Get a brief summary of what a blueprint does"""
        action_steps = self.load_blueprint(blueprint_number)
        
        if not action_steps:
            return None
        
        # Create a brief summary from the first few actions
        summary_parts = []
        
        for i, step in enumerate(action_steps[:3]):  # First 3 steps
            if "ACTION: CLICK" in step:
                # Extract target from CLICK action
                target_match = re.search(r'target=([^|]+)', step)
                if target_match:
                    target = target_match.group(1).strip()
                    summary_parts.append(f"Click {target}")
            elif "ACTION: TYPE" in step:
                # Extract text from TYPE action
                text_match = re.search(r'text=([^|]+)', step)
                if text_match:
                    text = text_match.group(1).strip()
                    text_preview = text[:20] + "..." if len(text) > 20 else text
                    summary_parts.append(f"Type '{text_preview}'")
            elif "ACTION: PRESS_ENTER" in step:
                summary_parts.append("Press Enter")
        
        if len(action_steps) > 3:
            summary_parts.append(f"...+{len(action_steps)-3} more steps")
        
        return " → ".join(summary_parts) if summary_parts else "Unknown workflow"
    
    def list_all_blueprints(self) -> Dict[int, Dict[str, str]]:
        """Get all blueprints with their numbers, summaries, and file paths"""
        available = self.get_available_blueprints()
        result = {}
        
        for number, file_path in available.items():
            summary = self.get_blueprint_summary(number)
            result[number] = {
                "file_path": file_path,
                "summary": summary or "Unknown workflow",
                "exists": True
            }
        
        return result

# Convenience functions
_blueprint_loader = BlueprintLoader()

def load_blueprint(blueprint_number: int) -> Optional[List[str]]:
    """Load a blueprint by number - convenience function"""
    return _blueprint_loader.load_blueprint(blueprint_number)

def get_available_blueprints() -> Dict[int, str]:
    """Get available blueprints - convenience function"""
    return _blueprint_loader.get_available_blueprints()

def get_blueprint_summary(blueprint_number: int) -> Optional[str]:
    """Get blueprint summary - convenience function"""
    return _blueprint_loader.get_blueprint_summary(blueprint_number)