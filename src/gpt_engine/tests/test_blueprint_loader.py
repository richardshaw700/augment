#!/usr/bin/env python3
"""
Test script to verify blueprint loader functionality.
"""

import sys
from pathlib import Path

# Add the project root to the path
project_root = Path(__file__).parent.parent.parent.parent
sys.path.append(str(project_root))

from src.gpt_engine.blueprint_loader import BlueprintLoader, load_blueprint, get_available_blueprints, get_blueprint_summary

def test_blueprint_loader():
    """Test the blueprint loader functionality."""
    
    print("🧪 TESTING BLUEPRINT LOADER")
    print("=" * 50)
    
    # Test 1: Check available blueprints
    print("📁 Test 1: Get available blueprints")
    available = get_available_blueprints()
    print(f"Available blueprints: {list(available.keys())}")
    
    for number, file_path in available.items():
        print(f"   Blueprint {number}: {file_path}")
    
    # Test 2: Load specific blueprints
    print(f"\n📋 Test 2: Load blueprint content")
    for number in sorted(available.keys()):
        print(f"\n--- Blueprint {number} ---")
        steps = load_blueprint(number)
        if steps:
            for i, step in enumerate(steps, 1):
                print(f"   {i}. {step}")
        else:
            print(f"   ❌ Failed to load blueprint {number}")
    
    # Test 3: Get summaries
    print(f"\n📝 Test 3: Get blueprint summaries")
    for number in sorted(available.keys()):
        summary = get_blueprint_summary(number)
        print(f"   Blueprint {number}: {summary}")
    
    # Test 4: Test BlueprintLoader class directly
    print(f"\n🔧 Test 4: BlueprintLoader class methods")
    loader = BlueprintLoader()
    all_blueprints = loader.list_all_blueprints()
    
    for number, info in all_blueprints.items():
        print(f"   Blueprint {number}:")
        print(f"      Summary: {info['summary']}")
        print(f"      Exists: {info['exists']}")
    
    # Test 5: Test invalid blueprint number
    print(f"\n❌ Test 5: Test invalid blueprint")
    invalid_steps = load_blueprint(999)
    print(f"   Blueprint 999: {invalid_steps}")  # Should be None
    
    invalid_summary = get_blueprint_summary(999)
    print(f"   Summary 999: {invalid_summary}")  # Should be None

if __name__ == "__main__":
    test_blueprint_loader()