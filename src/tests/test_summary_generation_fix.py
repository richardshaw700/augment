#!/usr/bin/env python3
"""
Test summary generation after fixing the missing 're' import
"""

import sys
from pathlib import Path

# Add project root to path  
project_root = Path(__file__).parent.parent.parent
sys.path.append(str(project_root))
sys.path.append(str(project_root / "src"))

from src.workflow_automation.recording.analysis.summary_generator import generate_summary

def test_summary_generation():
    """Test that summary generation works without crashing"""
    
    print("🧪 TESTING SUMMARY GENERATION AFTER RE MODULE FIX")
    print("=" * 50)
    
    # Create test events
    test_events = [
        {
            "type": "mouse_click",
            "timestamp": 1750782228.0,
            "app_name": "Messages",
            "coordinates": (983, 248),
            "description": "Clicked on txt:iMessage@A-25:49 in Messages"
        },
        {
            "type": "keyboard",
            "timestamp": 1750782229.0,
            "app_name": "Messages",
            "key_char": "H"
        },
        {
            "type": "keyboard",
            "timestamp": 1750782229.1,
            "app_name": "Messages",
            "key_char": "i"
        },
        {
            "type": "keyboard",
            "timestamp": 1750782230.0,
            "app_name": "Messages",
            "key_char": "return"
        }
    ]
    
    try:
        # Test summary generation
        summary = generate_summary(
            session_id="test_session",
            workflow_name="Test Workflow",
            start_time=1750782228.0,
            events=test_events,
            steps=4,
            errors=0
        )
        
        print("✅ Summary generation successful!")
        print(f"📄 Summary length: {len(summary)} characters")
        
        # Check that the summary contains expected sections
        if "EVENT TIMELINE" in summary:
            print("✅ Timeline section found")
        else:
            print("❌ Timeline section missing")
            
        if "ACTION BLUEPRINT" in summary:
            print("✅ Action blueprint section found")
        else:
            print("❌ Action blueprint section missing")
            
        # Preview first few lines
        lines = summary.split('\n')[:10]
        print("\n📋 Summary preview (first 10 lines):")
        for i, line in enumerate(lines, 1):
            print(f"   {i:2d}. {line}")
            
        return True
        
    except Exception as e:
        print(f"❌ Summary generation failed: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = test_summary_generation()
    if success:
        print("\n🎉 SUMMARY GENERATION WORKING CORRECTLY!")
    else:
        print("\n💥 SUMMARY GENERATION STILL HAS ISSUES!")