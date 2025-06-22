#!/usr/bin/env python3
"""
Smart LLM Actions
Integrates background LLM queries with the existing action system for intelligent task execution
"""

import asyncio
import json
import time
from typing import Dict, List, Any, Optional, Tuple
from dataclasses import dataclass
from urllib.parse import urlparse

from .action_executor import ActionExecutor
from .base_actions import ActionResult
from src.gpt_engine.background_llm import BackgroundLLMEngine, QueryResult
from src.gpt_engine.task_classifier import TaskClassifier, TaskClassification, TaskType

@dataclass
class SmartActionResult:
    """Enhanced action result with LLM-generated context"""
    success: bool
    action_results: List[ActionResult]
    llm_response: Optional[str] = None
    structured_data: Optional[Dict] = None
    execution_time: float = 0.0
    reasoning: Optional[str] = None

class SmartLLMActions:
    """
    Intelligent action system that combines LLM knowledge with UI automation.
    Uses background LLM queries to enhance action execution with contextual information.
    """
    
    def __init__(self, action_executor: ActionExecutor, llm_adapter, debug: bool = False):
        self.action_executor = action_executor
        self.debug = debug
        
        # Initialize background systems
        self.task_classifier = TaskClassifier()
        self.background_llm = BackgroundLLMEngine(llm_adapter, max_concurrent_queries=2)
        
        # URL mapping for common sites
        self.site_mappings = {
            "netflix": "https://www.netflix.com",
            "youtube": "https://www.youtube.com",
            "amazon": "https://www.amazon.com",
            "spotify": "https://open.spotify.com",
            "github": "https://github.com",
            "reddit": "https://www.reddit.com",
            "twitter": "https://twitter.com",
            "instagram": "https://www.instagram.com",
            "facebook": "https://www.facebook.com",
            "linkedin": "https://www.linkedin.com"
        }
        
        if self.debug:
            print("🧠 Smart LLM Actions initialized")
    
    async def start(self):
        """Start the background LLM processor"""
        await self.background_llm.start_background_processor()
        if self.debug:
            print("🔄 Background LLM processor started")
    
    async def stop(self):
        """Stop the background LLM processor"""
        await self.background_llm.stop_background_processor()
        if self.debug:
            print("⏹️  Background LLM processor stopped")
    
    async def execute_smart_task(self, task: str, ui_state: Optional[Dict] = None) -> SmartActionResult:
        """
        Execute a task using intelligent routing between LLM queries and UI actions
        
        Args:
            task: The user's task description
            ui_state: Current UI state for context
            
        Returns:
            SmartActionResult with combined LLM and action results
        """
        start_time = time.time()
        
        if self.debug:
            print(f"🎯 Executing smart task: '{task}'")
        
        # Step 1: Classify the task
        classification = self.task_classifier.classify_task(task)
        
        if self.debug:
            print(f"📊 Task Classification:")
            print(f"   Type: {classification.task_type.value}")
            print(f"   Confidence: {classification.confidence:.2f}")
            print(f"   Reasoning: {classification.reasoning}")
        
        # Step 2: Route based on task type
        if classification.task_type == TaskType.KNOWLEDGE_QUERY:
            return await self._handle_knowledge_query(task, classification, ui_state, start_time)
        
        elif classification.task_type == TaskType.SMART_ACTION:
            return await self._handle_smart_action(task, classification, ui_state, start_time)
        
        elif classification.task_type == TaskType.HYBRID:
            return await self._handle_hybrid_task(task, classification, ui_state, start_time)
        
        else:  # COMPUTER_USE - delegate to regular action executor
            return await self._delegate_to_action_executor(task, ui_state, start_time)
    
    async def _handle_knowledge_query(self, task: str, classification: TaskClassification, 
                                    ui_state: Optional[Dict], start_time: float) -> SmartActionResult:
        """Handle pure knowledge-based queries"""
        
        # Submit background LLM query
        query_id = await self.background_llm.submit_query(task, classification)
        
        # Wait for result
        result = await self.background_llm.get_query_result(query_id, timeout=15.0)
        
        if result and result.success:
            if self.debug:
                print(f"✅ Knowledge query completed: {result.response[:100]}...")
            
            return SmartActionResult(
                success=True,
                action_results=[],
                llm_response=result.response,
                structured_data=result.structured_data,
                execution_time=time.time() - start_time,
                reasoning="Pure knowledge query answered by LLM"
            )
        else:
            return SmartActionResult(
                success=False,
                action_results=[],
                execution_time=time.time() - start_time,
                reasoning="LLM query failed or timed out"
            )
    
    async def _handle_smart_action(self, task: str, classification: TaskClassification,
                                 ui_state: Optional[Dict], start_time: float) -> SmartActionResult:
        """Handle tasks that need knowledge + simple action (like opening URLs)"""
        
        # Submit background LLM query to get knowledge component
        query_id = await self.background_llm.submit_query(
            classification.suggested_llm_query or task, 
            classification
        )
        
        # Wait for LLM result
        llm_result = await self.background_llm.get_query_result(query_id, timeout=10.0)
        
        if not llm_result or not llm_result.success:
            return SmartActionResult(
                success=False,
                action_results=[],
                execution_time=time.time() - start_time,
                reasoning="Failed to get LLM guidance for smart action"
            )
        
        # Extract actionable information
        urls = llm_result.urls or []
        structured_data = llm_result.structured_data or {}
        
        # Execute smart actions based on LLM results
        action_results = []
        
        if urls:
            # Navigate to the primary URL
            primary_url = urls[0]
            nav_result = await self._smart_navigate_to_url(primary_url, ui_state)
            action_results.append(nav_result)
        
        elif "primary_recommendation" in structured_data:
            # Handle recommendation-based actions
            recommendation = structured_data["primary_recommendation"]
            
            # Try to find and navigate to related URL
            inferred_url = self._infer_url_from_recommendation(recommendation, task)
            if inferred_url:
                nav_result = await self._smart_navigate_to_url(inferred_url, ui_state)
                action_results.append(nav_result)
        
        return SmartActionResult(
            success=len(action_results) > 0 and all(r.success for r in action_results),
            action_results=action_results,
            llm_response=llm_result.response,
            structured_data=structured_data,
            execution_time=time.time() - start_time,
            reasoning=f"Smart action executed based on LLM guidance"
        )
    
    async def _handle_hybrid_task(self, task: str, classification: TaskClassification,
                                ui_state: Optional[Dict], start_time: float) -> SmartActionResult:
        """Handle complex tasks that need both knowledge and UI automation"""
        
        try:
            if self.debug:
                print(f"🔀 Handling hybrid task: {task}")
            
            # Step 1: Get LLM guidance for the knowledge component
            query_id = await self.background_llm.submit_query(task, classification)
            
            if self.debug:
                print(f"📤 Submitted query {query_id} to background LLM")
            
            llm_result = await self.background_llm.get_query_result(query_id, timeout=15.0)
            
            if self.debug:
                if llm_result:
                    print(f"📥 LLM result received - Success: {llm_result.success}")
                    if llm_result.success:
                        print(f"   Response length: {len(llm_result.response) if llm_result.response else 0}")
                        print(f"   URLs: {llm_result.urls}")
                        print(f"   Suggested actions: {llm_result.suggested_actions}")
                else:
                    print("❌ No LLM result received (timeout or error)")
            
            action_results = []
            failed_urls = []
            
            if llm_result and llm_result.success:
                # Step 2: Use LLM results to inform UI actions
                if llm_result.urls:
                    if self.debug:
                        print(f"🌐 Navigating to {len(llm_result.urls)} URLs")
                    
                    # Navigate to relevant URLs first
                    for url in llm_result.urls[:2]:  # Limit to 2 URLs
                        nav_result = await self._smart_navigate_to_url(url, ui_state)
                        action_results.append(nav_result)
                        
                        # Track failed URLs for recovery
                        if not nav_result.success:
                            failed_urls.append(url)
                            if self.debug:
                                print(f"❌ URL failed: {url} - {nav_result.error}")
                
                # Step 2.5: If significant URLs failed, try to recover with better URLs
                processed_urls = min(len(llm_result.urls), 2)  # We limit to 2 URLs
                if failed_urls and len(failed_urls) >= processed_urls:
                    if self.debug:
                        print(f"🔄 {len(failed_urls)} out of {processed_urls} URLs failed, attempting recovery...")
                    
                    recovery_result = await self._attempt_url_recovery(task, failed_urls, classification)
                    if recovery_result:
                        action_results.extend(recovery_result)
                        if self.debug:
                            print(f"🔧 Recovery added {len(recovery_result)} additional actions")
                
                # Step 3: Execute any suggested actions from LLM
                if llm_result.suggested_actions:
                    if self.debug:
                        print(f"⚡ Executing {len(llm_result.suggested_actions)} suggested actions")
                    
                    for action in llm_result.suggested_actions[:3]:  # Limit actions
                        if action == "navigate_to_url" and llm_result.urls:
                            continue  # Already handled above
                        
                        # Convert LLM suggested action to actual UI action
                        ui_action_result = await self._convert_llm_action_to_ui_action(
                            action, llm_result.structured_data, ui_state
                        )
                        if ui_action_result:
                            action_results.append(ui_action_result)
                
                # Step 4: For complex tasks like shopping, continue with computer use after navigation
                if self._needs_continued_automation(task, llm_result):
                    if self.debug:
                        print(f"🔄 Task requires continued automation beyond navigation")
                    
                    # Hand off to traditional computer use system for detailed interaction
                    continuation_result = await self._continue_with_computer_use(task, action_results)
                    if continuation_result:
                        action_results.extend(continuation_result)
            
            # Calculate success - we succeed if we have LLM guidance AND at least one successful action
            has_llm_guidance = llm_result and llm_result.success
            has_successful_actions = len(action_results) > 0 and any(r.success for r in action_results)
            success = has_llm_guidance and has_successful_actions
            
            # Generate detailed reasoning
            if not llm_result:
                reasoning = "LLM query timed out or failed"
            elif not llm_result.success:
                reasoning = f"LLM query failed: {llm_result.error or 'Unknown error'}"
            elif not action_results:
                reasoning = "No actionable items found in LLM response"
            elif not has_successful_actions:
                failed_count = len([r for r in action_results if not r.success])
                reasoning = f"All {failed_count} navigation attempts failed. URLs may be invalid or pages not found."
            else:
                successful_count = len([r for r in action_results if r.success])
                failed_count = len([r for r in action_results if not r.success])
                if failed_count > 0:
                    reasoning = f"Partial success: {successful_count} actions succeeded, {failed_count} failed. Task may need additional steps."
                else:
                    reasoning = f"Success: {successful_count} actions completed successfully. Ready for next steps."
            
            if self.debug:
                print(f"✅ Hybrid task completed - Success: {success}, Actions: {len(action_results)}")
            
            return SmartActionResult(
                success=success,
                action_results=action_results,
                llm_response=llm_result.response if llm_result else None,
                structured_data=llm_result.structured_data if llm_result else None,
                execution_time=time.time() - start_time,
                reasoning=reasoning
            )
            
        except Exception as e:
            if self.debug:
                print(f"❌ Hybrid task exception: {str(e)}")
            
            return SmartActionResult(
                success=False,
                action_results=[],
                execution_time=time.time() - start_time,
                reasoning=f"Exception during hybrid task execution: {str(e)}"
            )
    
    async def _delegate_to_action_executor(self, task: str, ui_state: Optional[Dict], 
                                         start_time: float) -> SmartActionResult:
        """Delegate pure UI automation tasks to the existing action executor"""
        
        # This would need integration with your main GPT engine
        # For now, return a placeholder indicating this should use the normal flow
        return SmartActionResult(
            success=False,
            action_results=[],
            execution_time=time.time() - start_time,
            reasoning="Task requires computer use automation - should use main GPT engine"
        )
    
    async def _smart_navigate_to_url(self, url: str, ui_state: Optional[Dict]) -> ActionResult:
        """Intelligently navigate to a URL using the best available method"""
        
        if self.debug:
            print(f"🌐 Smart navigating to: {url}")
        
        # Check if browser is already open and has an address bar
        if ui_state and self._has_browser_address_bar(ui_state):
            # Use the existing browser
            result = await self._navigate_in_existing_browser(url, ui_state)
        else:
            # Open a new browser window
            result = await self._open_url_in_new_browser(url)
        
        # After navigation, check if we got a valid page
        if result.success:
            # Wait a moment for page to load
            await asyncio.sleep(2)
            
            # Check current UI state to see if navigation was successful
            validation_result = await self._validate_navigation_success(url)
            
            if not validation_result.success:
                if self.debug:
                    print(f"❌ Navigation validation failed: {validation_result.error}")
                
                # Return the validation failure
                return ActionResult(
                    success=False,
                    output=f"Navigation to {url} failed validation",
                    error=validation_result.error,
                    execution_time=result.execution_time
                )
        
        return result
    
    def _has_browser_address_bar(self, ui_state: Dict) -> bool:
        """Check if UI state indicates an open browser with address bar"""
        compressed_ui = ui_state.get('compressed_ui', '')
        
        # Look for browser indicators
        browser_indicators = ['Safari', 'Chrome', 'Firefox', 'url', 'address', 'search']
        return any(indicator in compressed_ui for indicator in browser_indicators)
    
    async def _navigate_in_existing_browser(self, url: str, ui_state: Dict) -> ActionResult:
        """Navigate to URL in existing browser"""
        
        # Look for address bar coordinates
        # This is a simplified version - would need better UI parsing
        try:
            # Attempt to find and click address bar, then type URL
            # For now, use a basic approach
            result = await self.action_executor.execute_intelligent_type(
                text=url,
                target_field="URL/Address Bar",
                coordinates=(500, 100),  # Generic coordinates - would need UI parsing
                ui_state=ui_state
            )
            
            return ActionResult(
                success=result.success,
                output=f"Navigated to {url} in existing browser",
                error=result.error,
                execution_time=result.execution_time
            )
            
        except Exception as e:
            return ActionResult(
                success=False,
                output="",
                error=f"Failed to navigate in existing browser: {str(e)}"
            )
    
    async def _open_url_in_new_browser(self, url: str) -> ActionResult:
        """Open URL in a new browser window"""
        try:
            # Use the existing bash action to open URL
            return await self.action_executor.execute_bash(f'open "{url}"')
        
        except Exception as e:
            return ActionResult(
                success=False,
                output="",
                error=f"Failed to open URL in new browser: {str(e)}"
            )
    
    def _infer_url_from_recommendation(self, recommendation: str, original_task: str) -> Optional[str]:
        """Try to infer a URL from an LLM recommendation"""
        
        recommendation_lower = recommendation.lower()
        task_lower = original_task.lower()
        
        # Check for direct site mentions
        for site, url in self.site_mappings.items():
            if site in recommendation_lower or site in task_lower:
                return url
        
        # Look for streaming services for movie/TV recommendations
        if any(word in task_lower for word in ["movie", "watch", "film", "tv", "show"]):
            if any(service in recommendation_lower for service in ["netflix", "streaming"]):
                return "https://www.netflix.com"
            elif "youtube" in recommendation_lower:
                return "https://www.youtube.com"
        
        # Look for music-related recommendations
        if any(word in task_lower for word in ["music", "song", "listen", "play"]):
            if "spotify" in recommendation_lower:
                return "https://open.spotify.com"
            elif "youtube" in recommendation_lower:
                return "https://www.youtube.com"
        
        # Look for shopping recommendations
        if any(word in task_lower for word in ["buy", "purchase", "order", "shop"]):
            return "https://www.amazon.com"
        
        return None
    
    async def _convert_llm_action_to_ui_action(self, action: str, structured_data: Optional[Dict], 
                                             ui_state: Optional[Dict]) -> Optional[ActionResult]:
        """Convert an LLM-suggested action into actual UI actions"""
        
        if action == "add_to_cart":
            # This would need UI parsing to find "Add to Cart" buttons
            # For now, return a placeholder
            return ActionResult(
                success=False,
                output="",
                error="Add to cart action not yet implemented"
            )
        
        elif action == "play_media":
            # Could look for play buttons in the UI
            return ActionResult(
                success=False,
                output="",
                error="Play media action not yet implemented"
            )
        
        # Add more action conversions as needed
        return None
    
    def get_classification_history(self) -> List[Dict]:
        """Get task classification history"""
        return self.task_classifier.get_classification_history()
    
    async def _validate_navigation_success(self, attempted_url: str) -> ActionResult:
        """Validate that navigation to a URL was successful"""
        
        try:
            # Import here to avoid circular imports
            from src.gpt_engine.gpt_computer_use import GPTComputerUse
            
            # Create a temporary GPTComputerUse instance to get UI state
            temp_computer_use = GPTComputerUse()
            ui_state = await temp_computer_use.get_ui_state()
            
            if "error" in ui_state:
                return ActionResult(
                    success=False,
                    output="",
                    error=f"Could not inspect UI to validate navigation: {ui_state['error']}"
                )
            
            # Parse the UI state to look for error indicators
            # Check both compressed output and raw elements
            ui_content = ""
            if "compressedOutput" in ui_state:
                ui_content += ui_state["compressedOutput"].lower()
            if "elements" in ui_state:
                for element in ui_state["elements"]:
                    if "text" in element:
                        ui_content += " " + str(element["text"]).lower()
            
            # Common error page indicators
            error_indicators = [
                "page not found",
                "404",
                "sorry",
                "we couldn't find that page",
                "page doesn't exist",
                "error",
                "not available",
                "access denied"
            ]
            
            # Check if any error indicators are present
            for indicator in error_indicators:
                if indicator in ui_content:
                    return ActionResult(
                        success=False,
                        output="",
                        error=f"Page shows error: detected '{indicator}' in page content"
                    )
            
            # If we get here, navigation appears successful
            return ActionResult(
                success=True,
                output="Navigation validation passed",
                error=None
            )
            
        except Exception as e:
            return ActionResult(
                success=False,
                output="",
                error=f"Exception during navigation validation: {str(e)}"
            )

    async def _attempt_url_recovery(self, original_task: str, failed_urls: List[str], 
                                   classification: TaskClassification) -> List[ActionResult]:
        """Attempt to recover from failed URLs by asking LLM for better alternatives"""
        
        if self.debug:
            print(f"🔧 Attempting URL recovery for {len(failed_urls)} failed URLs")
        
        try:
            # Create a recovery prompt
            recovery_task = f"""
The original task was: {original_task}

The following URLs failed to load (showing 404/Page Not Found errors):
{chr(10).join(f"- {url}" for url in failed_urls)}

Please provide working alternative URLs. Use ONLY these safe patterns:
1. General homepage: https://www.amazon.com
2. Pet supplies category: https://www.amazon.com/pet-supplies  
3. Simple search: https://www.amazon.com/s?k=dog+food
4. Alternative sites: https://www.chewy.com, https://www.petco.com

Do NOT create complex search URLs with specific product names.
Focus on getting to a working page first, then we can search from there.
"""
            
            # Submit recovery query
            recovery_query_id = await self.background_llm.submit_query(recovery_task, classification)
            recovery_result = await self.background_llm.get_query_result(recovery_query_id, timeout=10.0)
            
            if recovery_result and recovery_result.success and recovery_result.urls:
                if self.debug:
                    print(f"🔄 Got {len(recovery_result.urls)} recovery URLs")
                
                # Try the recovery URLs
                recovery_actions = []
                for url in recovery_result.urls[:2]:  # Limit recovery attempts
                    if url not in failed_urls:  # Don't retry the same failed URLs
                        nav_result = await self._smart_navigate_to_url(url, None)
                        recovery_actions.append(nav_result)
                        
                        if nav_result.success:
                            if self.debug:
                                print(f"✅ Recovery URL succeeded: {url}")
                            break  # Stop on first success
                        else:
                            if self.debug:
                                print(f"❌ Recovery URL also failed: {url}")
                
                return recovery_actions
            
            else:
                if self.debug:
                    print("❌ Recovery query failed or returned no URLs")
                return []
                
        except Exception as e:
            if self.debug:
                print(f"❌ Exception during URL recovery: {str(e)}")
            return []

    def _needs_continued_automation(self, task: str, llm_result: Optional[QueryResult]) -> bool:
        """Determine if task needs continued computer use automation after initial navigation"""
        
        task_lower = task.lower()
        
        # Shopping and e-commerce tasks that need continued interaction
        shopping_keywords = [
            "add to cart", "buy", "purchase", "order", "shop", "find and add",
            "add it to", "put in cart", "checkout", "select", "choose"
        ]
        
        # Check if task involves shopping/purchasing actions
        needs_shopping = any(keyword in task_lower for keyword in shopping_keywords)
        
        # Check if we have navigation but task isn't complete
        has_navigation = llm_result and llm_result.urls
        
        if self.debug and needs_shopping:
            print(f"🛒 Shopping task detected - will continue with computer use automation")
        
        return needs_shopping and has_navigation
    
    async def _continue_with_computer_use(self, original_task: str, navigation_results: List[ActionResult]) -> List[ActionResult]:
        """Continue task execution using traditional computer use system after navigation"""
        
        try:
            if self.debug:
                print(f"🤖 Handing off to computer use system for detailed interaction")
            
            # Import here to avoid circular imports
            from src.gpt_engine.gpt_computer_use import GPTComputerUse
            
            # Create a GPT Computer Use instance with proper parameters
            computer_use = GPTComputerUse(llm_provider="openai", llm_model="gpt-4o-mini")
            
            # Create a modified task that acknowledges we've already navigated
            modified_task = f"""
I have already navigated to the relevant website(s) for this task: {original_task}

The browser should now be showing search results or product pages. Please continue from here to:
1. Look at the current page content
2. Find the best product that matches the requirements
3. Add the selected item to the cart
4. Complete the shopping task

Original task: {original_task}
"""
            
            if self.debug:
                print(f"🔄 Executing continuation task with computer use")
            
            # Execute the continuation task with limited iterations
            computer_results = await computer_use.execute_task(modified_task, max_iterations=10)
            
            # Convert computer use results to ActionResult format
            continuation_actions = []
            if computer_results:
                for result in computer_results:
                    if result.get('result') and hasattr(result['result'], 'success'):
                        continuation_actions.append(result['result'])
                    else:
                        # Create ActionResult from computer use result
                        success = result.get('result', {}).get('success', False) if isinstance(result.get('result'), dict) else False
                        output = result.get('result', {}).get('output', str(result.get('result', ''))) if isinstance(result.get('result'), dict) else str(result.get('result', ''))
                        
                        continuation_actions.append(ActionResult(
                            success=success,
                            output=output,
                            execution_time=0.0
                        ))
            
            if self.debug:
                print(f"✅ Computer use continuation completed with {len(continuation_actions)} additional actions")
            
            return continuation_actions
            
        except Exception as e:
            if self.debug:
                print(f"❌ Computer use continuation failed: {str(e)}")
            
            # Return a placeholder result indicating the attempt
            return [ActionResult(
                success=False,
                output=f"Continuation with computer use attempted but failed: {str(e)}",
                execution_time=0.0
            )]

    def get_background_status(self) -> Dict[str, Any]:
        """Get status of background LLM engine"""
        return {
            "active_queries": len(self.background_llm.get_active_queries()),
            "queue_size": self.background_llm.get_queue_size(),
            "completed_queries": len(self.background_llm.completed_queries)
        } 