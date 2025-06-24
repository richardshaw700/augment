import subprocess
import os
from typing import Optional
import time
from pathlib import Path
import json
import re


class ContextInspector:
    """Handles UI context inspection by running the compiled UI inspector binary."""
    
    def __init__(self):
        # Correctly resolve the project root and build paths
        self.project_root = Path(__file__).resolve().parent.parent.parent.parent.parent
        self.inspector_path = self.project_root / "src/ui_inspector/compiled_ui_inspector"
        self.output_dir = self.project_root / "src/ui_inspector/output"
    
    def run_inspection(self) -> Optional[dict]:
        """
        Execute the UI inspector binary, find its JSON output file, parse it,
        and return the full UI map as a dictionary.
        """
        try:
            # Check if the inspector binary exists and is executable
            if not os.path.exists(self.inspector_path) or not os.access(self.inspector_path, os.X_OK):
                print(f"[CTX-ERROR] UI Inspector binary not found or not executable at {self.inspector_path}")
                return None
            
            # Get the state of the output directory before running the inspector
            files_before = set(os.listdir(self.output_dir))
            
            # Run the inspector subprocess
            result = subprocess.run(
                [str(self.inspector_path)],
                capture_output=True,
                text=True,
                timeout=15
            )
            
            if result.returncode != 0:
                stderr_output = result.stderr.strip() if result.stderr else "No error details"
                print(f"[CTX-ERROR] Inspector process failed with code {result.returncode}. Error: {stderr_output}")
                return None

            # Find the newest JSON file in the output directory
            time.sleep(0.1)
            files_after = set(os.listdir(self.output_dir))
            new_files = files_after - files_before
            
            new_json_files = [f for f in new_files if f.startswith('ui_map_') and f.endswith('.json')]

            if not new_json_files:
                print("[CTX-ERROR] Inspector ran but no new JSON output file was found.")
                return None

            latest_file = max(
                [self.output_dir / f for f in new_json_files],
                key=os.path.getmtime
            )

            # The file contains only JSON, so we can load it directly.
            with open(latest_file, 'r') as f:
                return json.load(f)
            
        except Exception as e:
            print(f"[CTX-ERROR] An exception occurred during UI inspection: {str(e)}")
            return None