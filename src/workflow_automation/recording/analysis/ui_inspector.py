"""
A wrapper for the compiled Swift UI Inspector tool.
This module is responsible for executing the UI inspector, parsing its
output, and returning a structured representation of the UI state.
"""

import subprocess
import json
from pathlib import Path
from typing import Dict, Any, Optional

class UIInspectorError(Exception):
    """Custom exception for UI Inspector errors."""
    pass

def get_ui_inspector_error_message(return_code: int, stderr: str) -> str:
    """Provides a detailed, user-friendly error message based on the return code."""
    if return_code == -5:
        return (
            "UI Inspector failed with permission error (code -5). "
            "This usually means the 'compiled_ui_inspector' executable needs Accessibility permissions.\n"
            "Please go to System Settings > Privacy & Security > Accessibility, "
            "find 'augment' or your terminal, and ensure it's enabled. "
            "You may also need to add and enable 'compiled_ui_inspector' itself if it appears in the list."
        )
    return f"UI inspector failed with code {return_code}: {stderr}"

class UIInspector:
    """A wrapper class for interacting with the UI inspector binary."""

    def __init__(self, inspector_path: Optional[str] = None):
        self.inspector_path = inspector_path or self._get_default_inspector_path()
        if not Path(self.inspector_path).exists():
            raise FileNotFoundError(f"UI Inspector executable not found at: {self.inspector_path}")

    def _get_default_inspector_path(self) -> str:
        """Determines the default path to the UI inspector executable."""
        # Relative to this file: recording/analysis/ui_inspector.py -> src/ui_inspector/compiled_ui_inspector
        base_path = Path(__file__).parent.parent.parent.parent
        return str(base_path / "ui_inspector" / "compiled_ui_inspector")

    def capture_ui_state(self) -> Dict[str, Any]:
        """
        Runs the UI inspector tool and returns the parsed UI state.

        Returns:
            A dictionary containing the structured UI data.

        Raises:
            UIInspectorError: If the inspector fails or returns invalid data.
        """
        try:
            result = subprocess.run(
                [self.inspector_path],
                capture_output=True,
                text=True,
                timeout=15
            )

            if result.returncode != 0:
                error_message = get_ui_inspector_error_message(result.returncode, result.stderr)
                raise UIInspectorError(error_message)

            return self._parse_output(result.stdout)

        except subprocess.TimeoutExpired:
            raise UIInspectorError("UI inspector command timed out.")
        except Exception as e:
            raise UIInspectorError(f"An unexpected error occurred during UI inspection: {e}")

    def _parse_output(self, raw_output: str) -> Dict[str, Any]:
        """
        Parses the raw string output from the UI inspector to extract the JSON data.
        It looks for JSON content between specific markers if they exist.
        """
        try:
            # The Swift tool uses "JSON_OUTPUT_END" to mark the end of the JSON block.
            if "JSON_OUTPUT_END" in raw_output:
                json_part = raw_output.split("JSON_OUTPUT_END")[0]
                # Find the start of the JSON object.
                json_start_index = json_part.find('{')
                if json_start_index != -1:
                    json_str = json_part[json_start_index:]
                    return json.loads(json_str)
            
            # Fallback for older versions or if markers are missing.
            return json.loads(raw_output)

        except json.JSONDecodeError as e:
            raise UIInspectorError(f"Failed to decode JSON from UI inspector output: {e}")
        except Exception as e:
            raise UIInspectorError(f"Failed to parse UI inspector output: {e}") 