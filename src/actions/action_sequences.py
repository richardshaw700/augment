"""
Action sequences that combine multiple base actions into intelligent workflows.
These sequences understand context and can adapt their behavior accordingly.
"""

import asyncio
from typing import Dict, Any, Optional, List, Tuple
from .base_actions import BaseActions, ActionResult


class ActionSequences:
    """High-level action sequences for common UI interaction patterns"""
    
    def __init__(self, base_actions: BaseActions):
        self.base_actions = base_actions
    
    async def click_type_enter(
        self, 
        coordinates: Tuple[int, int], 
        text: str, 
        field_description: str = "",
        enter_delay: float = 0.2
    ) -> ActionResult:
        """
        Click a field, type text, and press Enter in one fluid sequence.
        Perfect for URL bars, search fields, and simple form inputs.
        """
        import time
        start_time = time.time()
        
        try:
            results = []
            
            # Step 1: Click to focus the field
            click_result = await self.base_actions.click(
                coordinates, 
                f"text field{' (' + field_description + ')' if field_description else ''}"
            )
            results.append(click_result)
            
            if not click_result.success:
                return ActionResult(
                    success=False,
                    output="",
                    error=f"Click failed in sequence: {click_result.error}",
                    execution_time=time.time() - start_time
                )
            
            # Step 2: Type the text
            type_result = await self.base_actions.type_text(text)
            results.append(type_result)
            
            if not type_result.success:
                return ActionResult(
                    success=False,
                    output="",
                    error=f"Type failed in sequence: {type_result.error}",
                    execution_time=time.time() - start_time
                )
            
            # Step 3: Brief pause before Enter (allows UI to process)
            if enter_delay > 0:
                await asyncio.sleep(enter_delay)
            
            # Step 4: Press Enter
            enter_result = await self.base_actions.press_key("Return")
            results.append(enter_result)
            
            if not enter_result.success:
                return ActionResult(
                    success=False,
                    output="",
                    error=f"Enter failed in sequence: {enter_result.error}",
                    execution_time=time.time() - start_time
                )
            
            # Success - combine all outputs
            total_time = time.time() - start_time
            combined_output = " → ".join([r.output for r in results])
            
            return ActionResult(
                success=True,
                output=f"COMPLETE SEQUENCE EXECUTED: {combined_output} - Navigation initiated, no further action needed",
                execution_time=total_time
            )
            
        except Exception as e:
            return ActionResult(
                success=False,
                output="",
                error=f"Sequence failed: {str(e)}",
                execution_time=time.time() - start_time
            )
    
    async def click_type_only(
        self, 
        coordinates: Tuple[int, int], 
        text: str, 
        field_description: str = ""
    ) -> ActionResult:
        """
        Click a field and type text without pressing Enter.
        Useful for forms where Enter might cause premature submission.
        """
        import time
        start_time = time.time()
        
        try:
            results = []
            
            # Step 1: Click to focus the field
            click_result = await self.base_actions.click(
                coordinates, 
                f"text field{' (' + field_description + ')' if field_description else ''}"
            )
            results.append(click_result)
            
            if not click_result.success:
                return ActionResult(
                    success=False,
                    output="",
                    error=f"Click failed in sequence: {click_result.error}",
                    execution_time=time.time() - start_time
                )
            
            # Step 2: Type the text
            type_result = await self.base_actions.type_text(text)
            results.append(type_result)
            
            if not type_result.success:
                return ActionResult(
                    success=False,
                    output="",
                    error=f"Type failed in sequence: {type_result.error}",
                    execution_time=time.time() - start_time
                )
            
            # Success - combine outputs
            total_time = time.time() - start_time
            combined_output = " → ".join([r.output for r in results])
            
            return ActionResult(
                success=True,
                output=f"Sequence completed: {combined_output}",
                execution_time=total_time
            )
            
        except Exception as e:
            return ActionResult(
                success=False,
                output="",
                error=f"Sequence failed: {str(e)}",
                execution_time=time.time() - start_time
            )
    
    async def smart_form_fill(
        self, 
        field_coordinates: Tuple[int, int], 
        text: str, 
        context: Dict[str, Any],
        field_description: str = ""
    ) -> ActionResult:
        """
        Intelligently fill a form field based on context.
        Decides whether to press Enter or not based on form type and field position.
        """
        # Analyze context to determine if Enter should be pressed
        should_press_enter = self._should_press_enter_for_field(context, field_description)
        
        if should_press_enter:
            return await self.click_type_enter(
                field_coordinates, 
                text, 
                field_description
            )
        else:
            return await self.click_type_only(
                field_coordinates, 
                text, 
                field_description
            )
    
    def _should_press_enter_for_field(self, context: Dict[str, Any], field_description: str) -> bool:
        """
        Determine if Enter should be pressed after typing in a field.
        Returns True for navigation/search fields, False for complex forms.
        """
        field_desc_lower = field_description.lower()
        
        # Always press Enter for these field types
        navigation_fields = [
            "url", "address", "search", "query", "go to", "navigate"
        ]
        
        if any(keyword in field_desc_lower for keyword in navigation_fields):
            return True
        
        # Check context for form complexity indicators
        form_indicators = context.get("form_indicators", {})
        
        # Don't press Enter if form has multiple required fields
        if form_indicators.get("multiple_required_fields", False):
            return False
        
        # Don't press Enter if form has security indicators
        security_indicators = ["password", "login", "signin", "2fa", "captcha", "verification"]
        if any(indicator in str(context).lower() for indicator in security_indicators):
            return False
        
        # Don't press Enter if there are other input fields nearby
        if form_indicators.get("nearby_input_fields", 0) > 0:
            return False
        
        # Default: press Enter for simple single-field scenarios
        return True 