"""
Context detector that analyzes UI state to determine the most appropriate
action sequence for a given task and environment.
"""

import re
from typing import Dict, Any, Optional, List, Tuple
from enum import Enum


class ContextType(Enum):
    """Types of UI contexts that require different action strategies"""
    BROWSER_NAVIGATION = "browser_navigation"
    SEARCH_FIELD = "search_field"
    SIMPLE_FORM = "simple_form"
    COMPLEX_FORM = "complex_form"
    LOGIN_FORM = "login_form"
    SECURE_FORM = "secure_form"
    TEXT_EDITOR = "text_editor"
    UNKNOWN = "unknown"


class ActionStrategy(Enum):
    """Action strategies for different contexts"""
    CLICK_TYPE_ENTER = "click_type_enter"      # For navigation, search
    CLICK_TYPE_ONLY = "click_type_only"        # For complex forms
    SMART_FORM_FILL = "smart_form_fill"        # Context-aware form filling
    ATOMIC_ACTIONS = "atomic_actions"          # Individual actions only


class ContextDetector:
    """Analyzes UI state and determines optimal action strategy"""
    
    def __init__(self):
        self.browser_apps = ["safari", "chrome", "firefox", "edge", "opera"]
        self.security_keywords = [
            "password", "login", "signin", "sign in", "2fa", "captcha", 
            "verification", "authenticate", "security", "otp", "token"
        ]
        self.navigation_keywords = [
            "url", "address", "search", "go to", "navigate", "visit"
        ]
    
    def analyze_context(self, ui_state: Dict[str, Any], target_field: str = "") -> Dict[str, Any]:
        """
        Analyze the current UI context and return strategy recommendations.
        
        Args:
            ui_state: Current UI state from the inspector
            target_field: Description of the target field (e.g., "TextField (url)")
            
        Returns:
            Dict containing context type, recommended strategy, and analysis details
        """
        context = {
            "context_type": ContextType.UNKNOWN,
            "recommended_strategy": ActionStrategy.ATOMIC_ACTIONS,
            "confidence": 0.0,
            "form_indicators": {},
            "security_indicators": [],
            "reasoning": ""
        }
        
        # Extract basic information
        app_name = self._extract_app_name(ui_state)
        compressed_output = ui_state.get("compressedOutput", "")
        elements = ui_state.get("elements", [])
        
        # Analyze application context
        is_browser = any(browser in app_name.lower() for browser in self.browser_apps)
        
        # Analyze field context
        field_analysis = self._analyze_target_field(target_field, compressed_output)
        
        # Analyze form complexity
        form_analysis = self._analyze_form_complexity(elements, compressed_output)
        
        # Analyze security context
        security_analysis = self._analyze_security_context(elements, compressed_output)
        
        # Determine context type and strategy
        context_type, strategy, confidence, reasoning = self._determine_strategy(
            is_browser, field_analysis, form_analysis, security_analysis
        )
        
        context.update({
            "context_type": context_type,
            "recommended_strategy": strategy,
            "confidence": confidence,
            "form_indicators": form_analysis,
            "security_indicators": security_analysis,
            "reasoning": reasoning,
            "app_name": app_name,
            "is_browser": is_browser,
            "field_analysis": field_analysis
        })
        
        return context
    
    def _extract_app_name(self, ui_state: Dict[str, Any]) -> str:
        """Extract application name from UI state"""
        window_info = ui_state.get("window", {})
        title = window_info.get("title", "")
        
        # Extract app name from window title
        if "activwndw: " in title:
            app_part = title.split("activwndw: ")[1].split(" - ")[0]
            return app_part.strip()
        
        return title.split(" - ")[0] if " - " in title else title
    
    def _analyze_target_field(self, target_field: str, compressed_output: str) -> Dict[str, Any]:
        """Analyze the target field to understand its purpose"""
        field_lower = target_field.lower()
        
        analysis = {
            "is_url_field": False,
            "is_search_field": False,
            "is_password_field": False,
            "field_type": "unknown",
            "purpose": "unknown"
        }
        
        # Check for URL/address field
        if any(keyword in field_lower for keyword in ["url", "address", "location"]):
            analysis.update({
                "is_url_field": True,
                "field_type": "navigation",
                "purpose": "url_navigation"
            })
        
        # Check for search field
        elif any(keyword in field_lower for keyword in ["search", "query", "find"]):
            analysis.update({
                "is_search_field": True,
                "field_type": "search",
                "purpose": "search_query"
            })
        
        # Check for password field
        elif "password" in field_lower:
            analysis.update({
                "is_password_field": True,
                "field_type": "security",
                "purpose": "authentication"
            })
        
        return analysis
    
    def _analyze_form_complexity(self, elements: List[Dict], compressed_output: str) -> Dict[str, Any]:
        """Analyze form complexity to determine interaction strategy"""
        text_fields = []
        buttons = []
        required_fields = 0
        
        # Count different element types
        for element in elements:
            element_type = element.get("type", "").lower()
            visual_text = element.get("visualText", "")
            
            if "textfield" in element_type or "input" in element_type:
                text_fields.append(element)
                if "required" in str(element).lower() or "*" in visual_text:
                    required_fields += 1
            
            elif "button" in element_type:
                buttons.append(element)
        
        # Analyze compressed output for additional context
        submit_buttons = len(re.findall(r'btn:.*(?:submit|send|save|create|register)', compressed_output, re.IGNORECASE))
        
        return {
            "total_text_fields": len(text_fields),
            "total_buttons": len(buttons),
            "required_fields": required_fields,
            "submit_buttons": submit_buttons,
            "multiple_required_fields": required_fields > 1,
            "nearby_input_fields": max(0, len(text_fields) - 1),  # Other fields besides target
            "is_complex_form": len(text_fields) > 2 or required_fields > 1
        }
    
    def _analyze_security_context(self, elements: List[Dict], compressed_output: str) -> List[str]:
        """Detect security-related context that affects interaction strategy"""
        security_indicators = []
        
        # Check for security keywords in elements
        all_text = compressed_output.lower()
        
        for keyword in self.security_keywords:
            if keyword in all_text:
                security_indicators.append(keyword)
        
        # Check for specific security patterns
        if re.search(r'2fa|two.factor|verification.code', all_text, re.IGNORECASE):
            security_indicators.append("2fa_detected")
        
        if re.search(r'captcha|recaptcha|verify.human', all_text, re.IGNORECASE):
            security_indicators.append("captcha_detected")
        
        return security_indicators
    
    def _determine_strategy(
        self, 
        is_browser: bool, 
        field_analysis: Dict, 
        form_analysis: Dict, 
        security_indicators: List[str]
    ) -> Tuple[ContextType, ActionStrategy, float, str]:
        """Determine the optimal strategy based on context analysis"""
        
        # High confidence: Browser URL navigation
        if is_browser and field_analysis.get("is_url_field", False):
            return (
                ContextType.BROWSER_NAVIGATION,
                ActionStrategy.CLICK_TYPE_ENTER,
                0.95,
                "Browser URL field detected - use click+type+enter for navigation"
            )
        
        # High confidence: Search field
        if field_analysis.get("is_search_field", False):
            return (
                ContextType.SEARCH_FIELD,
                ActionStrategy.CLICK_TYPE_ENTER,
                0.90,
                "Search field detected - use click+type+enter for search"
            )
        
        # High confidence: Security context
        if security_indicators or field_analysis.get("is_password_field", False):
            return (
                ContextType.SECURE_FORM,
                ActionStrategy.CLICK_TYPE_ONLY,
                0.85,
                f"Security context detected: {security_indicators} - avoid auto-enter"
            )
        
        # Medium confidence: Complex form
        if form_analysis.get("is_complex_form", False):
            return (
                ContextType.COMPLEX_FORM,
                ActionStrategy.SMART_FORM_FILL,
                0.75,
                f"Complex form detected ({form_analysis['total_text_fields']} fields) - use smart filling"
            )
        
        # Medium confidence: Simple form
        if form_analysis.get("total_text_fields", 0) <= 2:
            return (
                ContextType.SIMPLE_FORM,
                ActionStrategy.CLICK_TYPE_ENTER,
                0.70,
                "Simple form detected - safe to use click+type+enter"
            )
        
        # Low confidence: Unknown context
        return (
            ContextType.UNKNOWN,
            ActionStrategy.ATOMIC_ACTIONS,
            0.30,
            "Unknown context - use individual atomic actions for safety"
        ) 