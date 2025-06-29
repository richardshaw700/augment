#!/usr/bin/env python3
"""
Smart LLM Actions
Integrates background LLM queries with the existing action system for intelligent task execution
"""

import asyncio
import json
import time
import re
from typing import Dict, List, Any, Optional, Tuple
from dataclasses import dataclass
from urllib.parse import urlparse

from .action_executor import ActionExecutor
from .base_actions import ActionResult
from .background_automation import BackgroundAutomation, BackgroundActionResult
from src.agent_engine.background_llm import BackgroundLLMEngine, QueryResult
from src.agent_engine.task_classifier import TaskClassifier, TaskClassification, TaskType

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
        self.background_automation = BackgroundAutomation(debug=debug)
        
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
        Main entry point for smart task execution
        
        Args:
            task: The user's task description
            ui_state: Current UI state for context
            
        Returns:
            SmartActionResult with execution results
        """
        start_time = time.time()
        
        if self.debug:
            print(f"🚀 Smart task executor starting: '{task}'")
        
        # FIRST: Check if this is a messaging task (before classification)
        # This ensures messaging tasks bypass the classifier entirely
        if self._is_messaging_task(task):
            if self.debug:
                print(f"📱 Detected messaging task, routing to background automation")
            return await self._handle_messaging_task(task, ui_state, start_time)
        
        # SECOND: Only classify non-messaging tasks
        classification = self.task_classifier.classify_task(task)
        
        if self.debug:
            print(f"📊 Task Classification:")
            print(f"   Type: {classification.task_type.value}")
            print(f"   Confidence: {classification.confidence:.2f}")
            print(f"   Reasoning: {classification.reasoning}")
        
        # THIRD: Route based on task type
        if classification.task_type == TaskType.KNOWLEDGE_QUERY:
            return await self._handle_knowledge_query(task, classification, ui_state, start_time)
        
        elif classification.task_type == TaskType.SMART_ACTION:
            return await self._handle_smart_action(task, classification, ui_state, start_time)
        
        elif classification.task_type == TaskType.HYBRID:
            return await self._handle_hybrid_task(task, classification, ui_state, start_time)
        
        else:  # COMPUTER_USE - delegate to regular action executor
            return await self._delegate_to_action_executor(task, ui_state, start_time)
    
    def _is_messaging_task(self, task: str) -> bool:
        """
        Check if task is a messaging task that should use background automation
        
        Args:
            task: The user's task description
            
        Returns:
            True if this is a messaging task (SMS, iMessage, etc.)
        """
        task_lower = task.lower().strip()
        
        # FIRST: Exclude app-based messaging - these should use computer automation
        app_keywords = ["chatgpt", "slack", "discord", "whatsapp", "telegram", "app"]
        if any(keyword in task_lower for keyword in app_keywords):
            return False
        
        # SECOND: Only detect traditional messaging (SMS, iMessage, etc.)
        messaging_patterns = [
            r"send (a )?text",
            r"send (an )?imessage", 
            r"text \w+",  # "text john", "text mom"
            r"message \w+",  # "message sarah"
            r"imessage \w+",
            r"sms \w+",
            r"send (a )?message"  # Generic messaging (only if no app context)
        ]
        
        # Check for traditional messaging patterns
        for pattern in messaging_patterns:
            if re.search(pattern, task_lower):
                return True
        
        return False
    
    async def _handle_messaging_task(self, task: str, ui_state: Optional[Dict], start_time: float) -> SmartActionResult:
        """
        Handle messaging tasks using background automation
        
        Args:
            task: The user's task description
            ui_state: Current UI state for context
            start_time: Start time for execution tracking
            
        Returns:
            SmartActionResult with messaging results
        """
        if self.debug:
            print(f"📱 Processing messaging task: '{task}'")
        
        # Parse the messaging task
        message_info = self._parse_messaging_task(task)
        
        if not message_info:
            return SmartActionResult(
                success=False,
                action_results=[],
                execution_time=time.time() - start_time,
                reasoning="Could not parse recipient and message from task"
            )
        
        recipient = message_info.get("recipient")
        message_text = message_info.get("message")
        is_app_context = message_info.get("app_context", False)
        
        if not recipient or not message_text:
            return SmartActionResult(
                success=False,
                action_results=[],
                execution_time=time.time() - start_time,
                reasoning=f"Missing recipient ({recipient}) or message ({message_text})"
            )
        
        # Handle app-based messaging differently
        if is_app_context:
            if self.debug:
                print(f"🎯 App-based messaging detected: {recipient} -> '{message_text}'")
                print(f"🔄 Delegating to action executor for UI automation")
            
            # Delegate app-based messaging to the action executor for UI automation
            return await self._delegate_to_action_executor(task, ui_state, start_time)
        
        # Use background automation for traditional messaging (SMS, iMessage, etc.)
        try:
            background_result = await self.background_automation.send_message_smart(recipient, message_text)
            
            # Convert to SmartActionResult
            action_result = ActionResult(
                success=background_result.success,
                output=background_result.output or f"Message sent to {recipient}",
                error=background_result.error
            )
            
            return SmartActionResult(
                success=background_result.success,
                action_results=[action_result],
                llm_response=f"Message sent to {recipient}: '{message_text}'",
                execution_time=time.time() - start_time,
                reasoning=f"Background messaging to {recipient} completed"
            )
            
        except Exception as e:
            return SmartActionResult(
                success=False,
                action_results=[],
                execution_time=time.time() - start_time,
                reasoning=f"Background messaging failed: {str(e)}"
            )
    
    def _parse_messaging_task(self, task: str) -> Optional[Dict[str, str]]:
        """
        Parse messaging task to extract recipient and message
        
        Args:
            task: The user's task description
            
        Returns:
            Dict with 'recipient' and 'message' keys, or None if parsing failed
        """
        task_lower = task.lower().strip()
        
        # Pattern 1: "send a text to John saying I'm running late"
        # Pattern 2: "send an iMessage to Mom that I'll be home soon"
        match = re.search(r"send (?:a |an )?(?:text|imessage|message) to (\w+(?:\s+\w+)*) (?:saying|that) (.+)", task_lower)
        if match:
            return {
                "recipient": match.group(1).strip(),
                "message": match.group(2).strip()
            }
        
        # Pattern 3: "text John that I'm running late"
        # Pattern 4: "message Sarah saying dinner is ready"
        match = re.search(r"(?:text|message) (\w+(?:\s+\w+)*) (?:that|saying) (.+)", task_lower)
        if match:
            return {
                "recipient": match.group(1).strip(),
                "message": match.group(2).strip()
            }
        
        # Pattern 5: "text mom I'll be home soon" (without "that" or "saying")
        match = re.search(r"text (\w+(?:\s+\w+)*) (.+)", task_lower)
        if match:
            recipient = match.group(1).strip()
            message = match.group(2).strip()
            # Skip if the "message" looks like it might be another command
            if not any(word in message for word in ["send", "text", "message", "call"]):
                return {
                    "recipient": recipient,
                    "message": message
                }
        
        # Pattern 6: App-based messaging - "Go to ChatGPT app and send a message saying Hello"
        # Pattern 7: "Open WhatsApp and send a message saying I'm here"
        match = re.search(r"(?:go to|open|launch|use) (\w+(?:\s+\w+)*?) (?:app )?.*?send (?:a )?message saying (.+)", task_lower)
        if match:
            app_name = match.group(1).strip()
            message = match.group(2).strip()
            return {
                "recipient": app_name,  # Use app name as recipient context
                "message": message,
                "app_context": True  # Flag to indicate this is app-based messaging
            }
        
        # Pattern 8: Simpler app messaging - "ChatGPT send message Hello"
        match = re.search(r"(\w+(?:\s+\w+)*) send message [\"']?(.+?)[\"']?$", task_lower)
        if match:
            app_name = match.group(1).strip()
            message = match.group(2).strip()
            # Only match if it looks like an app name
            if any(keyword in app_name for keyword in ["gpt", "chat", "whatsapp", "telegram", "slack", "discord"]):
                return {
                    "recipient": app_name,
                    "message": message,
                    "app_context": True
                }
        
        return None
    
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
                
                # Step 3: Check for Mac app launch (priority over other actions)
                if (llm_result.structured_data and 
                    "mac_app_info" in llm_result.structured_data and
                    llm_result.structured_data["mac_app_info"]):
                    
                    if self.debug:
                        print(f"🖥️  Mac app launch detected")
                    
                    # Execute Mac app launch
                    mac_app_action = await self._convert_llm_action_to_ui_action(
                        "launch_mac_app", llm_result.structured_data, ui_state
                    )
                    if mac_app_action:
                        action_results.append(mac_app_action)
                        
                        # If Mac app launch succeeded, continue with computer use for the rest of the task
                        if mac_app_action.success:
                            if self.debug:
                                print(f"✅ Mac app launched successfully, continuing with task automation")
                            
                            continuation_result = await self._continue_with_computer_use(task, action_results)
                            if continuation_result:
                                action_results.extend(continuation_result)
                
                # Step 3: Execute any other suggested actions from LLM  
                elif llm_result.suggested_actions:
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
                
                # Check if this was a Mac app launch failure
                has_mac_app_info = (llm_result.structured_data and 
                                  "mac_app_info" in llm_result.structured_data and
                                  llm_result.structured_data["mac_app_info"])
                
                if has_mac_app_info:
                    app_name = llm_result.structured_data["mac_app_info"].get("app_name", "unknown app")
                    reasoning = f"Mac app launch failed: Could not launch {app_name}. App may not be installed or accessible."
                else:
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
        
        if action == "launch_mac_app" or action == "open_mac_app":
            # Handle Mac app launching
            if structured_data and "mac_app_info" in structured_data:
                app_info = structured_data["mac_app_info"]
                app_name = app_info.get("app_name", "")
                bundle_id = app_info.get("bundle_identifier", "")
                
                if app_name:
                    # Use standard Mac app launching with 'open -a' command
                    launch_command = f"open -a '{app_name}'"
                    if self.debug:
                        print(f"🚀 Launching Mac app: {app_name}")
                        print(f"   Command: {launch_command}")
                    
                    try:
                        result = await self.action_executor.execute_bash(launch_command)
                        
                        if self.debug:
                            print(f"   Launch result: Success={result.success}, Output='{result.output}', Error='{result.error}'")
                        
                        return result
                    except Exception as e:
                        if self.debug:
                            print(f"   Launch exception: {str(e)}")
                        return ActionResult(
                            success=False,
                            output="",
                            error=f"Failed to launch Mac app {app_name}: {str(e)}"
                        )
                elif bundle_id:
                    # Use bundle identifier
                    try:
                        result = await self.action_executor.execute_bash(
                            f'open -b {bundle_id}'
                        )
                        return result
                    except Exception as e:
                        return ActionResult(
                            success=False,
                            output="",
                            error=f"Failed to launch Mac app with bundle ID {bundle_id}: {str(e)}"
                        )
            
            return ActionResult(
                success=False,
                output="",
                error="Mac app launch requested but no app information provided"
            )
        
        elif action == "add_to_cart":
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
            from src.agent_engine.computer_use import AgentOrchestrator
            
            # Create a temporary AgentOrchestrator instance to get UI state
            temp_computer_use = AgentOrchestrator()
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
        
        # Check if we have navigation but task isn't complete
        has_navigation = llm_result and llm_result.urls
        if not has_navigation:
            return False
        
        # Categories of tasks that need continued interaction after navigation
        
        # 1. Shopping and e-commerce tasks
        shopping_keywords = [
            "add to cart", "buy", "purchase", "order", "shop", "find and add",
            "add it to", "put in cart", "checkout", "select", "choose"
        ]
        needs_shopping = any(keyword in task_lower for keyword in shopping_keywords)
        
        # 2. Search and discovery tasks on content platforms
        content_search_keywords = [
            "find", "search for", "look for", "browse", "discover", "show me",
            "get me", "recommend", "suggest", "what's good"
        ]
        content_platforms = [
            "netflix", "youtube", "spotify", "amazon prime", "hulu", "disney+",
            "apple music", "soundcloud", "twitch", "reddit", "pinterest"
        ]
        needs_content_search = (
            any(keyword in task_lower for keyword in content_search_keywords) and
            any(platform in task_lower for platform in content_platforms)
        )
        
        # 3. Social media interaction tasks
        social_keywords = [
            "post", "share", "comment", "like", "follow", "message", "dm",
            "tweet", "upload", "publish", "send"
        ]
        social_platforms = [
            "twitter", "facebook", "instagram", "linkedin", "tiktok", "snapchat",
            "discord", "slack", "whatsapp", "chatgpt", "chat gpt", "openai"
        ]
        needs_social_interaction = (
            any(keyword in task_lower for keyword in social_keywords) and
            any(platform in task_lower for platform in social_platforms)
        )
        
        # 4. Form filling and account management
        form_keywords = [
            "fill out", "complete", "submit", "register", "sign up", "apply",
            "create account", "update profile", "change settings"
        ]
        needs_form_interaction = any(keyword in task_lower for keyword in form_keywords)
        
        # 5. Data extraction and research tasks
        research_keywords = [
            "extract", "copy", "save", "download", "get the", "collect",
            "gather information", "research", "compare", "analyze"
        ]
        needs_research_interaction = any(keyword in task_lower for keyword in research_keywords)
        
        # 6. Navigation with specific goals (beyond just opening a page)
        action_verbs = [
            "click", "select", "choose", "pick", "open", "view", "watch",
            "read", "play", "listen", "start", "begin", "continue"
        ]
        # If task has "go to X and [action]" pattern, it needs continued automation
        has_navigation_plus_action = (
            ("go to" in task_lower or "open" in task_lower or "visit" in task_lower) and
            " and " in task_lower and
            any(verb in task_lower.split(" and ", 1)[1] for verb in action_verbs)
        )
        
        # Determine if continuation is needed
        needs_continuation = (
            needs_shopping or 
            needs_content_search or 
            needs_social_interaction or 
            needs_form_interaction or 
            needs_research_interaction or
            has_navigation_plus_action
        )
        
        if self.debug and needs_continuation:
            reasons = []
            if needs_shopping: reasons.append("shopping")
            if needs_content_search: reasons.append("content search")
            if needs_social_interaction: reasons.append("social interaction")
            if needs_form_interaction: reasons.append("form filling")
            if needs_research_interaction: reasons.append("research/extraction")
            if has_navigation_plus_action: reasons.append("navigation + action")
            
            print(f"🔄 Task needs continued automation - Categories: {', '.join(reasons)}")
        
        return needs_continuation
    
    async def _continue_with_computer_use(self, original_task: str, navigation_results: List[ActionResult]) -> List[ActionResult]:
        """Continue task execution using traditional computer use system after navigation"""
        
        try:
            if self.debug:
                print(f"🤖 Handing off to computer use system for detailed interaction")
            
            # Import here to avoid circular imports
            from src.agent_engine.computer_use import AgentOrchestrator
            
            # Create a GPT Computer Use instance with proper parameters
            computer_use = AgentOrchestrator(llm_provider="openai", llm_model="gpt-4o-mini")
            
            # Create a modified task that acknowledges we've already navigated
            modified_task = f"""
I have already navigated to the relevant website for this task: {original_task}

The browser should now be showing the website. Please continue from here to complete the original task:

IMPORTANT: The task is NOT complete just because the website loaded. You must:
1. Look at the current page content carefully
2. Navigate through the site as needed (select profiles, search, browse, etc.)
3. Complete ALL parts of the original task
4. Only declare completion when the FULL original task is accomplished

Original task: {original_task}

Do not stop until the original task is fully completed!
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

    async def execute_background_action(self, task: str, ui_state: Optional[Dict] = None) -> SmartActionResult:
        """
        Execute background actions like sending messages, emails without UI interaction
        
        Args:
            task: The user's task description (e.g., "Send a text to John saying I'm running late")
            ui_state: Current UI state for context
            
        Returns:
            SmartActionResult with background action results
        """
        start_time = time.time()
        
        if self.debug:
            print(f"🔄 Executing background action: '{task}'")
        
        # Parse the task to extract action type and parameters
        action_info = self._parse_background_task(task)
        
        if not action_info:
            return SmartActionResult(
                success=False,
                action_results=[],
                execution_time=time.time() - start_time,
                reasoning="Could not parse background action from task"
            )
        
        action_type = action_info.get("type")
        params = action_info.get("params", {})
        
        # Execute the background action
        background_result = None
        
        try:
            if action_type == "send_message":
                background_result = await self.background_automation.send_imessage(
                    recipient=params.get("recipient"),
                    message=params.get("message")
                )
            elif action_type == "send_email":
                background_result = await self.background_automation.send_email(
                    recipient=params.get("recipient"),
                    subject=params.get("subject", ""),
                    body=params.get("body", "")
                )
            elif action_type == "add_reminder":
                background_result = await self.background_automation.add_reminder(
                    title=params.get("title"),
                    due_date=params.get("due_date")
                )
            elif action_type == "add_calendar_event":
                background_result = await self.background_automation.add_calendar_event(
                    title=params.get("title"),
                    start_date=params.get("start_date"),
                    end_date=params.get("end_date")
                )
            elif action_type == "create_note":
                background_result = await self.background_automation.create_note(
                    title=params.get("title"),
                    content=params.get("content")
                )
            else:
                return SmartActionResult(
                    success=False,
                    action_results=[],
                    execution_time=time.time() - start_time,
                    reasoning=f"Unknown background action type: {action_type}"
                )
            
            # Convert background result to action result
            action_result = ActionResult(
                success=background_result.success,
                output=background_result.output,
                error=background_result.error
            )
            
            return SmartActionResult(
                success=background_result.success,
                action_results=[action_result],
                execution_time=time.time() - start_time,
                reasoning=f"Background {action_type} executed"
            )
            
        except Exception as e:
            error_result = ActionResult(
                success=False,
                output="",
                error=f"Background action failed: {str(e)}"
            )
            
            return SmartActionResult(
                success=False,
                action_results=[error_result],
                execution_time=time.time() - start_time,
                reasoning=f"Exception during background action: {str(e)}"
            )
    
    def _parse_background_task(self, task: str) -> Optional[Dict[str, Any]]:
        """
        Parse a natural language task into background action parameters
        
        Args:
            task: Natural language task description
            
        Returns:
            Dictionary with action type and parameters, or None if unparseable
        """
        task_lower = task.lower()
        
        # Message sending patterns
        if any(word in task_lower for word in ["send", "text", "message"]):
            # Extract recipient and message
            # Patterns like "send a text to John saying I'm running late"
            # or "text mom that I'll be home soon"
            
            recipient = None
            message = None
            
            # Look for recipient patterns
            if " to " in task_lower:
                # "send a text to John saying..."
                parts = task_lower.split(" to ", 1)
                if len(parts) > 1:
                    after_to = parts[1]
                    if " saying " in after_to:
                        recipient_part, message_part = after_to.split(" saying ", 1)
                        recipient = recipient_part.strip()
                        message = message_part.strip()
                    elif " that " in after_to:
                        recipient_part, message_part = after_to.split(" that ", 1)
                        recipient = recipient_part.strip()
                        message = message_part.strip()
            
            elif "text " in task_lower:
                # "text mom that..."
                parts = task_lower.split("text ", 1)
                if len(parts) > 1:
                    after_text = parts[1]
                    if " that " in after_text:
                        recipient_part, message_part = after_text.split(" that ", 1)
                        recipient = recipient_part.strip()
                        message = message_part.strip()
                    elif " saying " in after_text:
                        recipient_part, message_part = after_text.split(" saying ", 1)
                        recipient = recipient_part.strip()
                        message = message_part.strip()
            
            if recipient and message:
                return {
                    "type": "send_message",
                    "params": {
                        "recipient": recipient,
                        "message": message
                    }
                }
        
        # Email patterns
        elif any(word in task_lower for word in ["email", "send email"]):
            # Similar parsing for emails
            if " to " in task_lower and (" about " in task_lower or " saying " in task_lower):
                parts = task_lower.split(" to ", 1)
                if len(parts) > 1:
                    after_to = parts[1]
                    if " about " in after_to:
                        recipient_part, subject_part = after_to.split(" about ", 1)
                        return {
                            "type": "send_email",
                            "params": {
                                "recipient": recipient_part.strip(),
                                "subject": subject_part.strip(),
                                "body": subject_part.strip()
                            }
                        }
        
        # Reminder patterns
        elif any(word in task_lower for word in ["remind", "reminder"]):
            # "remind me to call john tomorrow"
            if " to " in task_lower:
                parts = task_lower.split(" to ", 1)
                if len(parts) > 1:
                    reminder_text = parts[1].strip()
                    return {
                        "type": "add_reminder",
                        "params": {
                            "title": reminder_text
                        }
                    }
        
        # Calendar event patterns
        elif any(word in task_lower for word in ["schedule", "calendar", "meeting"]):
            # Basic calendar event parsing
            if " at " in task_lower:
                parts = task_lower.split(" at ", 1)
                if len(parts) > 1:
                    title = parts[0].replace("schedule", "").strip()
                    time_info = parts[1].strip()
                    return {
                        "type": "add_calendar_event",
                        "params": {
                            "title": title,
                            "start_date": time_info  # Would need better date parsing
                        }
                    }
        
        # Note creation patterns
        elif any(word in task_lower for word in ["note", "write down", "save"]):
            # "create a note about meeting notes"
            if " about " in task_lower:
                parts = task_lower.split(" about ", 1)
                if len(parts) > 1:
                    content = parts[1].strip()
                    return {
                        "type": "create_note",
                        "params": {
                            "title": f"Note: {content[:50]}...",
                            "content": content
                        }
                    }
        
        return None 