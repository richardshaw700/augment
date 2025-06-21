"""
Enhanced Action Executor with intelligent action sequences.
Integrates base actions, action sequences, and context detection for optimal UI interactions.
"""

import asyncio
import time
from typing import Dict, Any, Optional, Tuple
from dataclasses import dataclass

from .base_actions import BaseActions, ActionResult
from .action_sequences import ActionSequences
from .context_detector import ContextDetector, ActionStrategy


class ActionExecutor:
    """
    Enhanced action executor that intelligently chooses between atomic actions
    and action sequences based on UI context analysis.
    """
    
    def __init__(self, debug: bool = False):
        self.debug = debug
        
        # Initialize action system components
        self.base_actions = BaseActions()
        self.action_sequences = ActionSequences(self.base_actions)
        self.context_detector = ContextDetector()
        
        # Performance tracking
        self.execution_count = 0
        self.sequence_usage_stats = {
            "click_type_enter": 0,
            "click_type_only": 0,
            "smart_form_fill": 0,
            "atomic_actions": 0
        }
        
        if self.debug:
            print("🚀 Enhanced Action Executor initialized")
    
    async def execute_intelligent_type(
        self, 
        text: str, 
        target_field: str, 
        coordinates: Tuple[int, int], 
        ui_state: Dict[str, Any]
    ) -> ActionResult:
        """
        Intelligently execute a type action using context analysis to determine
        the best action sequence (atomic actions vs sequences).
        
        Args:
            text: Text to type
            target_field: Description of target field (e.g., "TextField (url)")
            coordinates: Click coordinates for the field
            ui_state: Current UI state for context analysis
            
        Returns:
            ActionResult with execution details
        """
        start_time = time.time()
        self.execution_count += 1
        
        if self.debug:
            print(f"🎯 Executing intelligent type #{self.execution_count}: '{text}' in {target_field}")
        
        try:
            # Analyze context to determine optimal strategy
            context = self.context_detector.analyze_context(ui_state, target_field)
            strategy = context["recommended_strategy"]
            confidence = context["confidence"]
            reasoning = context["reasoning"]
            
            if self.debug:
                print(f"📊 Context Analysis:")
                print(f"   Strategy: {strategy.value}")
                print(f"   Confidence: {confidence:.2f}")
                print(f"   Reasoning: {reasoning}")
            
            # Execute based on recommended strategy
            if strategy == ActionStrategy.CLICK_TYPE_ENTER:
                result = await self._execute_click_type_enter(
                    coordinates, text, target_field, context
                )
                self.sequence_usage_stats["click_type_enter"] += 1
                
            elif strategy == ActionStrategy.CLICK_TYPE_ONLY:
                result = await self._execute_click_type_only(
                    coordinates, text, target_field, context
                )
                self.sequence_usage_stats["click_type_only"] += 1
                
            elif strategy == ActionStrategy.SMART_FORM_FILL:
                result = await self._execute_smart_form_fill(
                    coordinates, text, target_field, context
                )
                self.sequence_usage_stats["smart_form_fill"] += 1
                
            else:  # ATOMIC_ACTIONS
                result = await self._execute_atomic_actions(
                    coordinates, text, target_field
                )
                self.sequence_usage_stats["atomic_actions"] += 1
            
            # Add context metadata to result
            if result.success:
                execution_time = time.time() - start_time
                enhanced_output = f"{result.output} | Strategy: {strategy.value} (confidence: {confidence:.2f})"
                
                return ActionResult(
                    success=True,
                    output=enhanced_output,
                    execution_time=execution_time,
                    ui_state={"context_analysis": context}
                )
            else:
                return result
                
        except Exception as e:
            execution_time = time.time() - start_time
            return ActionResult(
                success=False,
                output="",
                error=f"Intelligent type execution failed: {str(e)}",
                execution_time=execution_time
            )
    
    async def _execute_click_type_enter(
        self, 
        coordinates: Tuple[int, int], 
        text: str, 
        field_description: str,
        context: Dict[str, Any]
    ) -> ActionResult:
        """Execute click+type+enter sequence for navigation/search fields"""
        if self.debug:
            print("⚡ Executing click+type+enter sequence")
        
        return await self.action_sequences.click_type_enter(
            coordinates, text, field_description
        )
    
    async def _execute_click_type_only(
        self, 
        coordinates: Tuple[int, int], 
        text: str, 
        field_description: str,
        context: Dict[str, Any]
    ) -> ActionResult:
        """Execute click+type sequence without enter for complex forms"""
        if self.debug:
            print("⚡ Executing click+type sequence (no enter)")
        
        return await self.action_sequences.click_type_only(
            coordinates, text, field_description
        )
    
    async def _execute_smart_form_fill(
        self, 
        coordinates: Tuple[int, int], 
        text: str, 
        field_description: str,
        context: Dict[str, Any]
    ) -> ActionResult:
        """Execute smart form fill with context-aware enter decision"""
        if self.debug:
            print("⚡ Executing smart form fill sequence")
        
        return await self.action_sequences.smart_form_fill(
            coordinates, text, context, field_description
        )
    
    async def _execute_atomic_actions(
        self, 
        coordinates: Tuple[int, int], 
        text: str, 
        field_description: str
    ) -> ActionResult:
        """Execute individual atomic actions for maximum safety"""
        if self.debug:
            print("⚡ Executing atomic actions (safe mode)")
        
        try:
            # Step 1: Click
            click_result = await self.base_actions.click(coordinates, field_description)
            if not click_result.success:
                return click_result
            
            # Step 2: Type
            type_result = await self.base_actions.type_text(text)
            if not type_result.success:
                return type_result
            
            # Combine results
            combined_output = f"{click_result.output} → {type_result.output}"
            total_time = click_result.execution_time + type_result.execution_time
            
            return ActionResult(
                success=True,
                output=f"Atomic sequence: {combined_output}",
                execution_time=total_time
            )
            
        except Exception as e:
            return ActionResult(
                success=False,
                output="",
                error=f"Atomic actions failed: {str(e)}"
            )
    
    async def execute_click(self, coordinates: Tuple[int, int], description: str = "") -> ActionResult:
        """Execute a simple click action"""
        self.execution_count += 1
        return await self.base_actions.click(coordinates, description)
    
    async def execute_key(self, keys: str) -> ActionResult:
        """Execute a key press action"""
        self.execution_count += 1
        return await self.base_actions.press_key(keys)
    
    async def execute_type(self, text: str) -> ActionResult:
        """Execute a simple type action"""
        self.execution_count += 1
        return await self.base_actions.type_text(text)
    
    async def execute_bash(self, command: str, timeout: float = 30.0) -> ActionResult:
        """Execute a bash command"""
        import subprocess
        import time
        
        start_time = time.time()
        self.execution_count += 1
        
        try:
            result = subprocess.run(
                command,
                shell=True,
                capture_output=True,
                text=True,
                timeout=timeout
            )
            
            execution_time = time.time() - start_time
            
            if result.returncode == 0:
                return ActionResult(
                    success=True,
                    output=result.stdout.strip(),
                    execution_time=execution_time
                )
            else:
                return ActionResult(
                    success=False,
                    output=result.stdout.strip(),
                    error=result.stderr.strip(),
                    execution_time=execution_time
                )
                
        except subprocess.TimeoutExpired:
            execution_time = time.time() - start_time
            return ActionResult(
                success=False,
                output="",
                error=f"Command timed out after {timeout}s",
                execution_time=execution_time
            )
        except Exception as e:
            execution_time = time.time() - start_time
            return ActionResult(
                success=False,
                output="",
                error=f"Bash execution failed: {str(e)}",
                execution_time=execution_time
            )
    
    async def execute_wait(self, seconds: float) -> ActionResult:
        """Execute a wait action"""
        self.execution_count += 1
        return await self.base_actions.wait(seconds)
    
    async def execute_scroll(self, direction: str, amount: int = 3) -> ActionResult:
        """Execute a scroll action"""
        import pyautogui
        import time
        
        start_time = time.time()
        self.execution_count += 1
        
        try:
            if direction.lower() == "up":
                await asyncio.to_thread(pyautogui.scroll, amount)
            elif direction.lower() == "down":
                await asyncio.to_thread(pyautogui.scroll, -amount)
            else:
                return ActionResult(
                    success=False,
                    output="",
                    error=f"Invalid scroll direction: {direction}. Use 'up' or 'down'"
                )
            
            execution_time = time.time() - start_time
            return ActionResult(
                success=True,
                output=f"Scrolled {direction} by {amount}",
                execution_time=execution_time
            )
            
        except Exception as e:
            execution_time = time.time() - start_time
            return ActionResult(
                success=False,
                output="",
                error=f"Scroll failed: {str(e)}",
                execution_time=execution_time
            )
    
    async def execute_drag(self, start_coords: Tuple[int, int], end_coords: Tuple[int, int]) -> ActionResult:
        """Execute a drag action"""
        import pyautogui
        import time
        
        start_time = time.time()
        self.execution_count += 1
        
        try:
            start_x, start_y = start_coords
            end_x, end_y = end_coords
            
            await asyncio.to_thread(pyautogui.drag, end_x - start_x, end_y - start_y, 
                                  duration=0.5, button='left')
            
            execution_time = time.time() - start_time
            return ActionResult(
                success=True,
                output=f"Dragged from ({start_x}, {start_y}) to ({end_x}, {end_y})",
                execution_time=execution_time
            )
            
        except Exception as e:
            execution_time = time.time() - start_time
            return ActionResult(
                success=False,
                output="",
                error=f"Drag failed: {str(e)}",
                execution_time=execution_time
            )
    
    # Backward compatibility method for the original ActionExecutor interface
    async def execute(self, action_data: Dict[str, Any]) -> ActionResult:
        """
        Execute an action using the original ActionExecutor interface.
        Provides backward compatibility while adding intelligence where possible.
        """
        action = action_data.get("action", "")
        parameters = action_data.get("parameters", {})
        
        if self.debug:
            print(f"🔄 Backward compatibility execution: {action}")
        
        # Route to appropriate method based on action type
        if action == "click":
            coordinate = parameters.get("coordinate", [0, 0])
            if len(coordinate) != 2:
                return ActionResult(
                    success=False,
                    output="",
                    error="Click requires coordinate [x, y]"
                )
            return await self.execute_click((coordinate[0], coordinate[1]))
            
        elif action == "type":
            text = parameters.get("text", "")
            field = parameters.get("field", "")
            
            # If field is specified and we have UI state, use intelligent typing
            if field and hasattr(self, '_last_ui_state') and self._last_ui_state:
                # Extract coordinates from field coordinate (e.g., "A-R3")
                # This would need coordinate mapping - for now, fall back to simple type
                return await self.execute_type(text)
            else:
                return await self.execute_type(text)
                
        elif action == "key":
            keys = parameters.get("keys", "")
            return await self.execute_key(keys)
            
        elif action == "bash":
            command = parameters.get("command", "")
            timeout = parameters.get("timeout", 30.0)
            return await self.execute_bash(command, timeout)
            
        elif action == "wait":
            seconds = parameters.get("seconds", 1.0)
            return await self.execute_wait(seconds)
            
        elif action == "scroll":
            direction = parameters.get("direction", "down")
            amount = parameters.get("amount", 3)
            return await self.execute_scroll(direction, amount)
            
        elif action == "drag":
            start = parameters.get("start", [0, 0])
            end = parameters.get("end", [0, 0])
            return await self.execute_drag((start[0], start[1]), (end[0], end[1]))
            
        else:
            return ActionResult(
                success=False,
                output="",
                error=f"Unknown action: {action}"
            )
    
    def get_usage_stats(self) -> Dict[str, Any]:
        """Get statistics about action sequence usage"""
        total_executions = sum(self.sequence_usage_stats.values())
        
        stats = {
            "total_executions": self.execution_count,
            "sequence_executions": total_executions,
            "atomic_executions": self.execution_count - total_executions,
            "sequence_usage": self.sequence_usage_stats.copy()
        }
        
        # Calculate percentages
        if total_executions > 0:
            for strategy, count in self.sequence_usage_stats.items():
                percentage = (count / total_executions) * 100
                stats[f"{strategy}_percentage"] = round(percentage, 1)
        
        return stats
    
    def print_usage_stats(self):
        """Print usage statistics for debugging"""
        stats = self.get_usage_stats()
        
        print("\n📊 Enhanced Action Executor Statistics:")
        print(f"   Total Executions: {stats['total_executions']}")
        print(f"   Sequence Executions: {stats['sequence_executions']}")
        print(f"   Atomic Executions: {stats['atomic_executions']}")
        
        print("\n🎯 Sequence Usage:")
        for strategy, count in stats['sequence_usage'].items():
            percentage = stats.get(f"{strategy}_percentage", 0)
            print(f"   {strategy}: {count} ({percentage}%)") 