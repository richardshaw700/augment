"""
Simple structured logging system for workflow recording.
Outputs detailed logs to files in src/workflow_automation/output/
"""

import os
import json
import time
from datetime import datetime
from typing import Dict, Any, Optional
from pathlib import Path

class WorkflowLogger:
    """Handles structured logging for a workflow recording session."""
    
    def __init__(self, session_id: str, workflow_name: str):
        self.session_id = session_id
        self.workflow_name = workflow_name
        self.start_time = time.time()
        
        # Create output directory
        self.output_dir = Path(__file__).parent.parent.parent / "output"
        self.output_dir.mkdir(exist_ok=True)
        
        # Create log file with timestamp
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        self.log_file = self.output_dir / f"recording_raw_{timestamp}.txt"
        self.summary_file = self.output_dir / f"recording_summary_{timestamp}.txt"
        
        self._init_log_file()
        
        # Counters for statistics
        self.event_count = 0
        self.step_count = 0
        self.error_count = 0

    def get_log_file_path(self) -> str:
        """Returns the path to the main log file."""
        return str(self.log_file)
        
    def _init_log_file(self):
        """Initialize the log file with header information."""
        header = f"""
================================================================================
WORKFLOW RECORDING SESSION LOG
================================================================================
Session ID: {self.session_id}
Workflow Name: {self.workflow_name}
Start Time: {datetime.fromtimestamp(self.start_time).strftime('%Y-%m-%d %H:%M:%S')}
Log File: {self.log_file.name}
Summary File: {self.summary_file.name}
================================================================================

"""
        with open(self.log_file, 'w') as f:
            f.write(header)
        
        print(f"📝 Workflow recording log initialized: {self.log_file}")

    def log(self, log_type: str, message: str, data: Optional[Dict[str, Any]] = None):
        """
        Writes a generic log entry to the file.
        This is the primary method for logging.
        """
        # Update counters based on log type
        if log_type == "SYSTEM_EVENT":
            self.event_count += 1
        elif log_type == "WORKFLOW_STEP":
            self.step_count += 1
        elif log_type == "ERROR":
            self.error_count += 1

        timestamp = datetime.now().strftime('%H:%M:%S.%f')[:-3]
        log_entry = f"\n[{timestamp}] {log_type}: {message}\n"
        
        if data:
            try:
                formatted_data = json.dumps(data, indent=2, default=str)
                log_entry += f"Data:\n{formatted_data}\n"
            except Exception as e:
                log_entry += f"Data (raw): {str(data)}\nJSON Error: {str(e)}\n"
        
        log_entry += "-" * 80 + "\n"
        
        try:
            with open(self.log_file, 'a') as f:
                f.write(log_entry)
        except Exception as e:
            print(f"❌ Failed to write to log file: {e}")

    def write_summary(self, summary_content: str):
        """Writes the final summary content to the summary file."""
        try:
            with open(self.summary_file, 'w') as f:
                f.write(summary_content)
            print(f"📄 Session summary saved to: {self.summary_file}")
        except Exception as e:
            print(f"❌ Failed to write summary file: {e}")

    def close(self):
        """Finalizes the logging session."""
        duration = time.time() - self.start_time
        print(f"🎬 Logging session closed. Duration: {duration:.2f}s, Steps: {self.step_count}, Errors: {self.error_count}")

    def __del__(self):
        self.close() 