#!/usr/bin/env python3
"""
Test script to generate action blueprint from existing summary.
"""

import sys
from pathlib import Path

# Add the project root to the path
project_root = Path(__file__).parent.parent.parent.parent
sys.path.append(str(project_root))

from src.workflow_automation.recording.analysis.summary_generator import _generate_action_blueprint

def test_action_blueprint():
    """Test action blueprint generation with sample data."""
    
    # Mock events based on the actual timeline
    mock_events = [
        {
            "type": "mouse_click",
            "description": "Clicked on an unnamed element in Messages",
            "app_name": "Messages",
            "timestamp": 1234567890,
            "coordinates": [1166, 168]
        },
        {
            "type": "ui_inspected", 
            "app_name": "Messages",
            "timestamp": 1234567892
        },
        {
            "type": "mouse_click",
            "description": "Clicked on txt:iMessage@A-23:49 in Messages",
            "app_name": "Messages", 
            "timestamp": 1234567894,
            "coordinates": [1423, 841]
        },
        {
            "type": "keyboard",
            "app_name": "Messages",
            "typed_text": "hi1 i saw you do this in monekey see. now i'm doing it in monkey do.",
            "timestamp": 1234567896
        }
    ]
    
    print("🧪 TESTING ACTION BLUEPRINT GENERATION")
    print("=" * 60)
    
    blueprint = _generate_action_blueprint(mock_events)
    print(blueprint)

if __name__ == "__main__":
    test_action_blueprint()