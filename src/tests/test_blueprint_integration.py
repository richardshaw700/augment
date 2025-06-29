#!/usr/bin/env python3
"""
Test script to verify blueprint integration with the main controller.
"""

import sys
from pathlib import Path

# Add the project root to the path
project_root = Path(__file__).parent.parent.parent
sys.path.append(str(project_root))
sys.path.append(str(project_root / "src"))

import asyncio
from src.agent_engine.task_classifier import TaskClassifier, TaskType
from src.agent_engine.blueprint_loader import get_available_blueprints, get_blueprint_summary

def test_blueprint_classification():
    """Test that blueprint tasks are classified correctly"""
    
    print("🧪 TESTING BLUEPRINT CLASSIFICATION")
    print("=" * 50)
    
    classifier = TaskClassifier()
    
    # Test various blueprint task formats
    test_tasks = [
        "execute blueprint 2",
        "run blueprint 5", 
        "follow blueprint 1",
        "action blueprint 3",
        "workflow blueprint 7",
        "run workflow 4",
        "execute workflow 6"
    ]
    
    print("📝 Testing blueprint task classification:")
    for task in test_tasks:
        classification = classifier.classify_task(task)
        result = "✅" if classification.task_type == TaskType.ACTION_BLUEPRINT else "❌"
        print(f"   {result} '{task}' → {classification.task_type.value} (confidence: {classification.confidence:.2f})")
    
    print("\n📝 Testing non-blueprint tasks (should not be classified as blueprints):")
    non_blueprint_tasks = [
        "open safari",
        "send a message to john",
        "what is the weather"
    ]
    
    for task in non_blueprint_tasks:
        classification = classifier.classify_task(task)
        result = "✅" if classification.task_type != TaskType.ACTION_BLUEPRINT else "❌"
        print(f"   {result} '{task}' → {classification.task_type.value}")

def test_blueprint_availability():
    """Test blueprint availability and summaries"""
    
    print(f"\n🧪 TESTING BLUEPRINT AVAILABILITY")
    print("=" * 50)
    
    available = get_available_blueprints()
    print(f"📁 Available blueprints: {list(available.keys())}")
    
    print(f"\n📝 Blueprint summaries:")
    for number in sorted(available.keys()):
        summary = get_blueprint_summary(number)
        print(f"   Blueprint {number}: {summary}")

async def test_controller_integration():
    """Test blueprint integration with AugmentController (mock)"""
    
    print(f"\n🧪 TESTING CONTROLLER INTEGRATION")
    print("=" * 50)
    
    # Test blueprint number extraction
    from src.main import AugmentController
    
    # Create controller (but don't fully initialize to avoid heavy dependencies)
    print("📝 Testing blueprint number extraction:")
    
    test_tasks = [
        ("execute blueprint 2", 2),
        ("run workflow 5", 5), 
        ("blueprint 7", 7),
        ("execute #3", 3),
        ("invalid task", None)
    ]
    
    # Create a minimal controller instance for testing extraction method
    class MockController:
        def _extract_blueprint_number(self, task: str):
            import re
            patterns = [
                r"blueprint\s+(\d+)",
                r"workflow\s+(\d+)",
                r"run\s+(\d+)",
                r"execute\s+(\d+)",
                r"#(\d+)"
            ]
            
            task_lower = task.lower()
            for pattern in patterns:
                match = re.search(pattern, task_lower)
                if match:
                    return int(match.group(1))
            
            return None
    
    mock = MockController()
    
    for task, expected in test_tasks:
        result = mock._extract_blueprint_number(task)
        status = "✅" if result == expected else "❌"
        print(f"   {status} '{task}' → {result} (expected: {expected})")

def main():
    """Run all tests"""
    test_blueprint_classification()
    test_blueprint_availability()
    asyncio.run(test_controller_integration())
    
    print(f"\n🎉 All blueprint integration tests completed!")

if __name__ == "__main__":
    main()