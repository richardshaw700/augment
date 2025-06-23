#!/usr/bin/env python3
"""
Test script to verify improved summary generation
"""

import sys
import os
sys.path.append('src')

from workflow_automation.recording.logger import WorkflowLogger

def test_improved_summary():
    # Create a test logger
    logger = WorkflowLogger("test_improved", "Test Improved Summary")
    
    # Simulate some events with UI inspection events
    test_events = [
        {
            "event_type": "click",
            "timestamp": 1000.0,
            "description": "Click at (100, 200)",
            "data": {
                "coordinates": [100, 200],
                "app_name": "TestApp",
                "element": {"description": "Submit Button"}
            }
        },
        {
            "event_type": "keyboard", 
            "timestamp": 1002.0,
            "description": "Key 'h'",
            "data": {
                "key_char": "h",
                "app_name": "TestApp"
            }
        },
        {
            "event_type": "keyboard", 
            "timestamp": 1002.1,
            "description": "Key 'e'",
            "data": {
                "key_char": "e",
                "app_name": "TestApp"
            }
        },
        {
            "event_type": "keyboard", 
            "timestamp": 1002.2,
            "description": "Key 'l'",
            "data": {
                "key_char": "l",
                "app_name": "TestApp"
            }
        },
        {
            "event_type": "keyboard", 
            "timestamp": 1002.3,
            "description": "Key 'l'",
            "data": {
                "key_char": "l",
                "app_name": "TestApp"
            }
        },
        {
            "event_type": "keyboard", 
            "timestamp": 1002.4,
            "description": "Key 'o'",
            "data": {
                "key_char": "o",
                "app_name": "TestApp"
            }
        }
    ]
    
    # Log the events
    for event in test_events:
        logger.log_system_event(event)
    
    # Add some mock UI inspection events to the log file that match real patterns
    with open(logger.log_file, 'a') as f:
        f.write("""
[13:16:40.123] ERROR: Error #3: ELEMENT_DETECTION
Data:
{
  "error_number": 3,
  "error_type": "ELEMENT_DETECTION",
  "error_message": "Running fresh UI inspection for TestApp",
  "error_data": {}
}
[13:16:41.456] ERROR: Error #4: DEBUG_UI
Data:
{
  "error_number": 4,
  "error_type": "DEBUG_UI",
  "error_message": "Starting UI inspection with timeout 15s",
  "error_data": {}
}
[13:16:44.789] ERROR: Error #5: DEBUG_UI
Data:
{
  "error_number": 5,
  "error_type": "DEBUG_UI",
  "error_message": "UI inspection completed in 2.50s",
  "error_data": {}
}
""")
    
    print(f"Recorded events count: {len(logger.recorded_events)}")
    
    # Test session end (this should trigger improved summary generation)
    logger.log_session_end({
        "message": "Test session ended",
        "duration": 5.0,
        "total_steps": 2
    })
    
    print("Test completed! Check the summary file for improved formatting.")

if __name__ == "__main__":
    test_improved_summary() 