#!/usr/bin/env python3
"""
Background LLM Query Engine
Handles knowledge-based queries separate from computer use automation
"""

import asyncio
import json
import time
from datetime import datetime
from typing import Dict, List, Any, Optional, Union, Callable
from dataclasses import dataclass
from enum import Enum

from src.gpt_engine.task_classifier import TaskClassification, TaskType

class QueryType(Enum):
    """Types of background queries"""
    RECOMMENDATION = "recommendation"
    INFORMATION = "information"
    URL_GENERATION = "url_generation"
    ACTION_PLANNING = "action_planning"
    FACT_CHECKING = "fact_checking"

@dataclass
class BackgroundQuery:
    """A background LLM query request"""
    query_id: str
    task: str
    query_type: QueryType
    classification: TaskClassification
    created_at: datetime
    priority: int = 1
    context: Optional[Dict] = None
    callback: Optional[Callable] = None

@dataclass
class QueryResult:
    """Result of a background LLM query"""
    query_id: str
    success: bool
    response: str
    structured_data: Optional[Dict] = None
    suggested_actions: Optional[List[str]] = None
    urls: Optional[List[str]] = None
    execution_time: float = 0.0
    error: Optional[str] = None

class BackgroundLLMEngine:
    """Manages background LLM queries for knowledge-based tasks"""
    
    def __init__(self, llm_adapter, max_concurrent_queries: int = 3):
        self.llm_adapter = llm_adapter
        self.max_concurrent_queries = max_concurrent_queries
        
        # Query management
        self.query_queue = asyncio.Queue()
        self.active_queries = {}
        self.completed_queries = {}
        self.query_counter = 0
        
        # Background task management
        self.background_tasks = set()
        self.is_running = False
        
        # Specialized prompt templates
        self.prompt_templates = self._initialize_prompt_templates()
    
    def _initialize_prompt_templates(self) -> Dict[str, str]:
        """Initialize specialized prompt templates for different query types"""
        return {
            QueryType.RECOMMENDATION: """
You are a helpful AI assistant providing personalized recommendations.

User Request: {task}

Please provide a concise, helpful recommendation with the following structure:
1. **Primary Recommendation**: Your top suggestion
2. **Why**: Brief reasoning (1-2 sentences)
3. **Alternatives**: 2-3 other good options
4. **Direct Action**: ONLY provide URLs if you are absolutely certain they exist and work

CRITICAL: Do NOT invent or guess specific product URLs. Only provide:
- General website URLs you know exist (like "https://www.amazon.com")
- Search URLs with query parameters (like "https://www.amazon.com/s?k=search+terms")
- Never provide specific product URLs unless you obtained them from a real web search

Format your response as JSON:
{{
    "primary_recommendation": "...",
    "reasoning": "...",
    "alternatives": ["...", "...", "..."],
    "direct_actions": {{
        "urls": ["https://www.amazon.com/s?k=search+terms"],
        "actions": ["search_on_site"]
    }}
}}
""",
            
            QueryType.INFORMATION: """
You are a knowledgeable AI assistant providing accurate information.

User Query: {task}

Please provide a comprehensive but concise answer with:
1. **Main Answer**: Direct response to the question
2. **Key Details**: Important additional context
3. **Related Info**: Relevant supplementary information
4. **Sources**: If helpful, suggest where to find more info

Format as JSON:
{{
    "main_answer": "...",
    "key_details": ["...", "...", "..."],
    "related_info": "...",
    "suggested_sources": ["...", "..."]
}}
""",
            
            QueryType.URL_GENERATION: """
You are an AI assistant that helps users navigate to the right websites and services.

User Request: {task}

CRITICAL: Only provide URLs that you KNOW exist. Do not invent specific product or page URLs.

Please identify the best website/service for this request and provide:
1. **Primary URL**: The main website homepage or search page
2. **Alternative URLs**: Other verified websites  
3. **Search Terms**: What to search for on the site
4. **Instructions**: How to navigate once on the site

Safe URL patterns to use:
- Homepage URLs: "https://www.amazon.com"
- Search URLs: "https://www.amazon.com/s?k=search+terms"
- Category URLs: "https://www.amazon.com/pet-supplies"

Format as JSON:
{{
    "primary_url": "https://www.amazon.com/s?k=search+terms",
    "alternative_urls": ["https://www.chewy.com", "https://www.petco.com"],
    "search_terms": ["specific", "search", "terms"],
    "instructions": "Navigate to the search results and look for..."
}}
""",
            
            QueryType.ACTION_PLANNING: """
You are an AI assistant that helps break down complex tasks into actionable steps.

User Task: {task}

CRITICAL MAC APP DETECTION: If the user mentions "on my mac" or requests a specific app, this is a MAC APPLICATION request, NOT a web browser task.

For example:
- "Open ChatGPT on my mac" = ChatGPT Mac app (NOT Safari to chatgpt.com)
- "Open Spotify on my mac" = Spotify Mac app (NOT Safari to spotify.com) 
- "Launch Discord on my mac" = Discord Mac app (NOT web version)

For Mac apps, provide:
- The actual Mac application name (e.g., "ChatGPT", "Spotify", "Discord")
- Bundle identifier if known (e.g., com.openai.chat, com.spotify.client)
- Use AppleScript to launch: tell application "AppName" to activate

Please create an action plan with:
1. **Step-by-step Plan**: Ordered list of actions
2. **Prerequisites**: What needs to be ready first  
3. **Tools/Apps Needed**: Software or services required
4. **Estimated Time**: How long each step takes
5. **Mac App Instructions**: If applicable, specific Mac app launch commands

For Mac apps, include these fields:
- **app_name**: The exact name of the Mac application
- **bundle_identifier**: App bundle ID if known (e.g., com.openai.chat)
- **launch_method**: How to launch (applescript, system command, etc.)

Format as JSON:
{{
    "steps": [
        {{"step": 1, "action": "...", "details": "...", "estimated_time": "..."}},
        {{"step": 2, "action": "...", "details": "...", "estimated_time": "..."}}
    ],
    "prerequisites": ["...", "..."],
    "tools_needed": ["...", "..."],
    "total_estimated_time": "...",
    "mac_app_info": {{
        "app_name": "...",
        "bundle_identifier": "...",
        "launch_method": "applescript"
    }}
}}
""",
            
            QueryType.FACT_CHECKING: """
You are a fact-checking AI assistant providing accurate, up-to-date information.

User Query: {task}

Please provide:
1. **Verification**: Is the information correct?
2. **Accurate Information**: What are the correct facts?
3. **Sources**: Where this information comes from
4. **Last Updated**: When this information was current

Format as JSON:
{{
    "verification_status": "...",
    "accurate_information": "...",
    "key_facts": ["...", "...", "..."],
    "confidence_level": "...",
    "caveats": "..."
}}
"""
        }
    
    async def start_background_processor(self):
        """Start the background query processor"""
        if self.is_running:
            return
        
        self.is_running = True
        
        # Start worker tasks
        for i in range(self.max_concurrent_queries):
            task = asyncio.create_task(self._query_worker(f"worker_{i}"))
            self.background_tasks.add(task)
            task.add_done_callback(self.background_tasks.discard)
    
    async def stop_background_processor(self):
        """Stop the background query processor"""
        self.is_running = False
        
        # Cancel all background tasks
        for task in self.background_tasks:
            task.cancel()
        
        # Wait for tasks to complete
        await asyncio.gather(*self.background_tasks, return_exceptions=True)
        self.background_tasks.clear()
    
    async def submit_query(self, 
                          task: str, 
                          classification: TaskClassification,
                          context: Optional[Dict] = None,
                          callback: Optional[Callable] = None) -> str:
        """Submit a query for background processing"""
        
        # Generate query ID
        self.query_counter += 1
        query_id = f"bg_query_{self.query_counter}_{int(time.time())}"
        
        # Determine query type
        query_type = self._determine_query_type(task, classification)
        
        # Create query object
        query = BackgroundQuery(
            query_id=query_id,
            task=task,
            query_type=query_type,
            classification=classification,
            created_at=datetime.now(),
            context=context,
            callback=callback
        )
        
        # Add to queue
        await self.query_queue.put(query)
        
        return query_id
    
    async def get_query_result(self, query_id: str, timeout: float = 30.0) -> Optional[QueryResult]:
        """Get the result of a query (blocking until complete or timeout)"""
        start_time = time.time()
        
        while time.time() - start_time < timeout:
            if query_id in self.completed_queries:
                return self.completed_queries[query_id]
            
            await asyncio.sleep(0.1)
        
        return None  # Timeout
    
    def get_query_result_sync(self, query_id: str) -> Optional[QueryResult]:
        """Get query result if already completed (non-blocking)"""
        return self.completed_queries.get(query_id)
    
    async def _query_worker(self, worker_id: str):
        """Background worker that processes queries"""
        while self.is_running:
            try:
                # Get next query from queue
                query = await asyncio.wait_for(self.query_queue.get(), timeout=1.0)
                
                # Process the query
                await self._process_query(query)
                
                # Mark queue task as done
                self.query_queue.task_done()
                
            except asyncio.TimeoutError:
                # No queries in queue, continue
                continue
            except Exception as e:
                print(f"Background LLM worker {worker_id} error: {e}")
                continue
    
    async def _process_query(self, query: BackgroundQuery):
        """Process a single background query"""
        start_time = time.time()
        
        try:
            # Track active query
            self.active_queries[query.query_id] = query
            
            # Generate specialized prompt
            prompt = self._generate_prompt(query)
            
            # Query the LLM
            response = await self.llm_adapter.chat_completion([
                {"role": "user", "content": prompt}
            ], max_tokens=1500, temperature=0.3)
            
            # Parse response
            structured_data, urls, actions = self._parse_response(response, query.query_type)
            
            # Debug: Print raw response for Mac app queries
            if query.query_type == QueryType.ACTION_PLANNING:
                print(f"🔍 DEBUG - ACTION_PLANNING Response:")
                print(f"   Raw response: {response}")
                print(f"   Structured data: {structured_data}")
                print(f"   URLs: {urls}")
                print(f"   Actions: {actions}")
            
            # Create result
            result = QueryResult(
                query_id=query.query_id,
                success=True,
                response=response,
                structured_data=structured_data,
                suggested_actions=actions,
                urls=urls,
                execution_time=time.time() - start_time
            )
            
            # Store result
            self.completed_queries[query.query_id] = result
            
            # Call callback if provided
            if query.callback:
                try:
                    await query.callback(result)
                except Exception as e:
                    print(f"Callback error for query {query.query_id}: {e}")
            
        except Exception as e:
            # Create error result
            result = QueryResult(
                query_id=query.query_id,
                success=False,
                response="",
                error=str(e),
                execution_time=time.time() - start_time
            )
            
            self.completed_queries[query.query_id] = result
        
        finally:
            # Remove from active queries
            self.active_queries.pop(query.query_id, None)
    
    def _determine_query_type(self, task: str, classification: TaskClassification) -> QueryType:
        """Determine the type of background query needed"""
        task_lower = task.lower()
        
        # Mac app detection (highest priority - before URL generation)
        mac_app_indicators = ["on my mac", "mac app", "application", "app on", "open the", "launch the"]
        if any(indicator in task_lower for indicator in mac_app_indicators):
            # Check if this is explicitly requesting a Mac app vs web
            if "on my mac" in task_lower or "mac app" in task_lower:
                return QueryType.ACTION_PLANNING
        
        # URL/Navigation tasks (high priority - but after Mac app detection)
        if any(word in task_lower for word in ["open", "go to", "visit", "navigate", "website"]):
            return QueryType.URL_GENERATION
        
        # Recommendation tasks (high priority - should come before action planning)
        if any(word in task_lower for word in ["recommend", "suggest", "best", "good", "find me", "healthiest", "top", "great"]):
            return QueryType.RECOMMENDATION
        
        # Information seeking (before action planning)
        if task_lower.startswith(("what", "who", "when", "where", "why", "how")):
            return QueryType.INFORMATION
        
        # Action planning tasks (lower priority - only if no other patterns match)
        if classification.task_type == TaskType.HYBRID:
            return QueryType.ACTION_PLANNING
        
        # Default to recommendation for hybrid tasks that don't match other patterns
        return QueryType.RECOMMENDATION
    
    def _generate_prompt(self, query: BackgroundQuery) -> str:
        """Generate a specialized prompt for the query"""
        template = self.prompt_templates.get(query.query_type, self.prompt_templates[QueryType.INFORMATION])
        
        # Add context if available
        context_info = ""
        if query.context:
            context_info = f"\nContext: {json.dumps(query.context, indent=2)}\n"
        
        return template.format(task=query.task) + context_info
    
    def _parse_response(self, response: str, query_type: QueryType) -> tuple[Optional[Dict], Optional[List[str]], Optional[List[str]]]:
        """Parse LLM response and extract structured data"""
        try:
            # Try to parse as JSON first - handle markdown code blocks
            json_text = response.strip()
            if json_text.startswith('```json'):
                # Extract JSON from markdown code block
                json_start = json_text.find('{')
                json_end = json_text.rfind('}') + 1
                if json_start != -1 and json_end > json_start:
                    json_text = json_text[json_start:json_end]
            elif json_text.startswith('```'):
                # Handle generic code blocks
                lines = json_text.split('\n')
                json_lines = []
                in_json = False
                for line in lines:
                    if line.strip().startswith('{') or in_json:
                        in_json = True
                        json_lines.append(line)
                        if line.strip().endswith('}') and line.strip().count('}') >= line.strip().count('{'):
                            break
                json_text = '\n'.join(json_lines)
            
            if json_text.strip().startswith('{'):
                data = json.loads(json_text)
                
                # Extract URLs and clean them
                urls = []
                if 'urls' in data:
                    urls.extend(data['urls'])
                if 'primary_url' in data:
                    urls.append(data['primary_url'])
                if 'alternative_urls' in data:
                    urls.extend(data['alternative_urls'])
                if 'direct_actions' in data and 'urls' in data['direct_actions']:
                    urls.extend(data['direct_actions']['urls'])
                
                # Clean URLs - remove quotes, commas, and other trailing characters
                cleaned_urls = []
                for url in urls:
                    if isinstance(url, str):
                        # Remove trailing quotes, commas, and whitespace
                        cleaned_url = url.strip().rstrip('",\'').rstrip()
                        if cleaned_url.startswith(('http://', 'https://')):
                            cleaned_urls.append(cleaned_url)
                urls = cleaned_urls
                
                # Extract actions
                actions = []
                if 'actions' in data:
                    actions.extend(data['actions'])
                if 'direct_actions' in data and 'actions' in data['direct_actions']:
                    actions.extend(data['direct_actions']['actions'])
                if 'steps' in data:
                    actions.extend([step['action'] for step in data['steps']])
                
                # For ACTION_PLANNING with Mac app info, add launch action
                if query_type == QueryType.ACTION_PLANNING and 'mac_app_info' in data:
                    actions.append('launch_mac_app')
                
                return data, urls, actions
                
        except json.JSONDecodeError:
            pass
        
        # Fallback: extract URLs from text
        import re
        raw_urls = re.findall(r'https?://[^\s]+', response)
        
        # Clean the extracted URLs
        cleaned_urls = []
        for url in raw_urls:
            # Remove trailing quotes, commas, and other punctuation
            cleaned_url = url.strip().rstrip('",\'').rstrip()
            if cleaned_url.startswith(('http://', 'https://')):
                cleaned_urls.append(cleaned_url)
        
        return None, cleaned_urls, None
    
    def get_active_queries(self) -> Dict[str, BackgroundQuery]:
        """Get currently active queries"""
        return self.active_queries.copy()
    
    def get_queue_size(self) -> int:
        """Get current queue size"""
        return self.query_queue.qsize()
    
    def clear_completed_queries(self, keep_recent: int = 10):
        """Clear old completed queries, keeping only recent ones"""
        if len(self.completed_queries) <= keep_recent:
            return
        
        # Sort by completion time and keep only recent ones
        sorted_queries = sorted(
            self.completed_queries.items(),
            key=lambda x: x[1].query_id,  # Use query_id as proxy for time
            reverse=True
        )
        
        self.completed_queries = dict(sorted_queries[:keep_recent]) 