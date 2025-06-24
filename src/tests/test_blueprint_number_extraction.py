#!/usr/bin/env python3
"""
Simple test for blueprint number extraction without heavy imports.
"""

import re
from typing import Optional

def extract_blueprint_number(task: str) -> Optional[int]:
    """Extract blueprint number from task string"""
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

def test_number_extraction():
    """Test blueprint number extraction"""
    
    print("🧪 TESTING BLUEPRINT NUMBER EXTRACTION")
    print("=" * 50)
    
    test_cases = [
        ("execute blueprint 2", 2),
        ("run workflow 5", 5), 
        ("blueprint 7", 7),
        ("execute #3", 3),
        ("run 9", 9),
        ("invalid task", None),
        ("execute blueprint", None),  # No number
        ("blueprint abc", None),      # Non-numeric
    ]
    
    for task, expected in test_cases:
        result = extract_blueprint_number(task)
        status = "✅" if result == expected else "❌"
        print(f"   {status} '{task}' → {result} (expected: {expected})")

if __name__ == "__main__":
    test_number_extraction()