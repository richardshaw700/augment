"""
Prompt loading and template system for GPT Computer Use
"""

from pathlib import Path
from typing import Dict, Any, Optional
import logging

logger = logging.getLogger(__name__)


class PromptLoader:
    """Loads and formats prompts from files with template variable support"""
    
    def __init__(self, prompts_dir: Optional[Path] = None):
        if prompts_dir is None:
            prompts_dir = Path(__file__).parent
        self.prompts_dir = Path(prompts_dir)
        self.dynamic_dir = self.prompts_dir / "dynamic"
        self._cache = {}
    
    def _load_file(self, filename: str) -> str:
        """Load a prompt file with caching"""
        file_path = self.prompts_dir / filename
        
        # Use cache if available
        if str(file_path) in self._cache:
            return self._cache[str(file_path)]
        
        try:
            if file_path.exists():
                content = file_path.read_text(encoding='utf-8').strip()
                self._cache[str(file_path)] = content
                return content
            else:
                logger.warning(f"Prompt file not found: {file_path}")
                return f"[MISSING PROMPT: {filename}]"
        except Exception as e:
            logger.error(f"Error loading prompt file {file_path}: {e}")
            return f"[ERROR LOADING: {filename}]"
    
    def _load_dynamic_file(self, template_name: str) -> str:
        """Load a dynamic prompt template"""
        file_path = self.dynamic_dir / f"{template_name}.txt"
        
        if str(file_path) in self._cache:
            return self._cache[str(file_path)]
        
        try:
            if file_path.exists():
                content = file_path.read_text(encoding='utf-8').strip()
                self._cache[str(file_path)] = content
                return content
            else:
                logger.warning(f"Dynamic prompt template not found: {file_path}")
                return f"[MISSING TEMPLATE: {template_name}]"
        except Exception as e:
            logger.error(f"Error loading dynamic template {file_path}: {e}")
            return f"[ERROR LOADING: {template_name}]"
    
    def load_system_prompt(self, available_applications: str = "") -> str:
        """Load and format the main system prompt"""
        system_template = self._load_file("system.txt")
        action_guide = self._load_file("action_guide.txt")
        coordinate_guide = self._load_file("coordinate_guide.txt")
        goal_evaluation = self._load_file("goal_evaluation.txt")
        response_format = self._load_file("response_format.txt")
        
        # Format the system prompt with components
        return system_template.format(
            available_applications=available_applications,
            action_guide=action_guide,
            coordinate_guide=coordinate_guide,
            goal_evaluation=goal_evaluation,
            response_format=response_format
        )
    
    def load_dynamic_prompt(self, template_name: str, **variables) -> str:
        """Load and format a dynamic prompt template with variables"""
        template = self._load_dynamic_file(template_name)
        
        try:
            return template.format(**variables)
        except KeyError as e:
            logger.warning(f"Missing variable {e} in template {template_name}")
            return template
        except Exception as e:
            logger.error(f"Error formatting template {template_name}: {e}")
            return template
    
    def clear_cache(self):
        """Clear the prompt cache (useful for development)"""
        self._cache.clear()