#!/usr/bin/env python3
"""
Agent Computer Use - Main execution script

This is the main entry point for running the Agent Computer Use system.
It's designed to be simple and easy to understand.
"""

import asyncio
import sys
from pathlib import Path

# Add the project root to the path
project_root = Path(__file__).parent.parent.parent
sys.path.append(str(project_root))

from .computer_use import AgentOrchestrator


async def main():
    """Main interactive mode for Agent Computer Use"""
    computer_use = AgentOrchestrator()
    
    print("🖥️  Agent Computer Use System")
    print("AI-powered computer automation with multiple LLM support")
    print("=" * 60)
    
    # Show available applications
    computer_use.show_available_applications()
    
    # Example tasks to try
    example_tasks = [
        "Take a screenshot by inspecting the current UI",
        "Open Safari browser",
        "Open Cursor editor",
        "Open ChatGPT application",
        "Show me what's currently on the screen"
    ]
    
    print(f"\nExample tasks you can try:")
    for i, task in enumerate(example_tasks, 1):
        print(f"  {i}. {task}")
    
    while True:
        print("\n" + "=" * 60)
        task = input("Enter a task (or 'quit' to exit): ").strip()
        
        if task.lower() in ['quit', 'exit', 'q']:
            break
        
        if not task:
            continue
        
        try:
            results = await computer_use.execute_task(task)
            
            print(f"\n📊 Task Summary:")
            print(f"Total iterations: {len(results)}")
            successful_actions = sum(1 for r in results if r["result"].success)
            print(f"Successful actions: {successful_actions}/{len(results)}")
            
        except KeyboardInterrupt:
            print("\n⏹️  Task interrupted by user")
        except Exception as e:
            print(f"\n💥 Unexpected error: {str(e)}")


async def run_single_task(task: str):
    """Run a single task from command line arguments"""
    computer_use = AgentOrchestrator()
    print(f"🚀 Starting Agent Computer Use")
    print(f"📝 Task: {task}")
    print("=" * 60)
    
    try:
        results = await computer_use.execute_task(task)
        
        print(f"\n📊 Task Summary:")
        print(f"Total iterations: {len(results)}")
        successful_actions = sum(1 for r in results if r["result"].success)
        print(f"Successful actions: {successful_actions}/{len(results)}")
        
    except KeyboardInterrupt:
        print("\n⏹️  Task interrupted by user")
    except Exception as e:
        print(f"\n💥 Unexpected error: {str(e)}")


if __name__ == "__main__":
    # Check if task was provided as command line argument
    if len(sys.argv) > 1:
        # Non-interactive mode - execute the task from command line
        task_from_args = " ".join(sys.argv[1:])
        asyncio.run(run_single_task(task_from_args))
    else:
        # Interactive mode
        asyncio.run(main())