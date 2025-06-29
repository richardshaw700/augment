#!/usr/bin/env python3
"""
Test the --list-blueprints functionality without requiring main.py dependencies
"""

import sys
from pathlib import Path

# Add project root to path  
project_root = Path(__file__).parent.parent.parent
sys.path.append(str(project_root))
sys.path.append(str(project_root / "src"))

from src.agent_engine.blueprint_loader import get_available_blueprints, get_blueprint_summary

def test_list_blueprints_functionality():
    """Test the blueprint listing functionality that would be used by --list-blueprints"""
    
    print("🧪 TESTING --list-blueprints FUNCTIONALITY")
    print("=" * 50)
    
    # Test getting available blueprints
    available_blueprints = get_available_blueprints()
    
    if not available_blueprints:
        print("❌ No action blueprints found.")
        print("📁 Create blueprints in src/workflow_automation/action_blueprints/")
        return
    
    print(f"✅ Found {len(available_blueprints)} blueprint(s):")
    
    # Create summary dictionary like AugmentController.get_available_blueprints() does
    result = {}
    for number, file_path in available_blueprints.items():
        summary = get_blueprint_summary(number)
        result[number] = summary or "Unknown workflow"
    
    # Display like the main.py --list-blueprints would
    for number in sorted(result.keys()):
        summary = result[number]
        print(f"  {number}. {summary}")
    
    print()
    print("📋 Usage examples:")
    print("  python3 src/main.py --task 'Execute blueprint 2'")
    print("  python3 src/main.py --task 'Run workflow 3'")
    
    print()
    print("🎯 Swift Frontend Integration:")
    print("  The Swift frontend can call these blueprints using:")
    for number in sorted(result.keys()):
        print(f"  executeInstruction('Execute blueprint {number}')")

if __name__ == "__main__":
    test_list_blueprints_functionality()