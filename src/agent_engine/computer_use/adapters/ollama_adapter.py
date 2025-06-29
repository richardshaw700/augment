"""
Ollama LLM Adapter
"""

from typing import Dict, List
import requests
from .base import LLMAdapter


class OllamaAdapter(LLMAdapter):
    """Adapter for Ollama local models"""
    
    def __init__(self, model: str = "phi3:mini", base_url: str = "http://localhost:11434"):
        self.model = model
        self.base_url = base_url
    
    async def chat_completion(self, messages: List[Dict[str, str]], **kwargs) -> str:
        """Generate a chat completion using Ollama"""
        try:
            # Convert messages to Ollama format
            prompt = self._convert_messages_to_prompt(messages)
            
            # Make request to Ollama
            response = requests.post(
                f"{self.base_url}/api/generate",
                json={
                    "model": self.model,
                    "prompt": prompt,
                    "stream": False,
                    "options": {
                        "temperature": kwargs.get('temperature', 0.1),
                        "num_predict": kwargs.get('max_tokens', 1000)
                    }
                },
                timeout=60  # Increased timeout for local model
            )
            
            if response.status_code != 200:
                raise Exception(f"Ollama API error: {response.status_code} - {response.text}")
            
            result = response.json()
            ollama_response = result.get('response', '')
            
            # Clean up the response if it has markdown formatting
            if ollama_response.startswith('```json') and ollama_response.endswith('```'):
                # Extract JSON from markdown code block
                lines = ollama_response.split('\n')
                json_lines = []
                in_json = False
                for line in lines:
                    if line.strip() == '```json':
                        in_json = True
                        continue
                    elif line.strip() == '```':
                        break
                    elif in_json:
                        json_lines.append(line)
                ollama_response = '\n'.join(json_lines)
            
            return ollama_response.strip()
            
        except requests.exceptions.RequestException as e:
            raise Exception(f"Ollama connection error: {str(e)}")
        except Exception as e:
            raise Exception(f"Ollama API error: {str(e)}")
    
    def _convert_messages_to_prompt(self, messages: List[Dict[str, str]]) -> str:
        """Convert OpenAI-style messages to a single prompt for Ollama"""
        prompt_parts = []
        
        for message in messages:
            role = message["role"]
            content = message["content"]
            
            if role == "system":
                prompt_parts.append(f"System: {content}")
            elif role == "user":
                prompt_parts.append(f"User: {content}")
            elif role == "assistant":
                prompt_parts.append(f"Assistant: {content}")
        
        prompt_parts.append("Assistant:")  # Prompt for response
        
        return "\n\n".join(prompt_parts)
    
    def get_model_info(self) -> Dict[str, str]:
        return {
            "provider": "Ollama",
            "model": self.model,
            "type": "local"
        }