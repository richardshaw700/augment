#!/usr/bin/env python3
"""
Comprehensive test suite for Augment system
Tests UI inspector, GPT engine, actions, and main coordinator
"""

import asyncio
import os
import sys
from pathlib import Path
import json

# Add project paths
project_root = Path(__file__).parent.parent
sys.path.append(str(project_root))
sys.path.append(str(project_root / "src"))

from gpt_engine.gpt_computer_use import GPTComputerUse
from actions.action_executor import ActionExecutor

async def test_ui_inspector():
    """Test the UI inspector integration"""
    print("🧪 Testing UI Inspector Integration")
    print("=" * 40)
    
    ui_inspector_path = project_root / "src" / "ui_inspector" / "compiled_ui_inspector"
    
    # Check if UI inspector exists
    if not ui_inspector_path.exists():
        print(f"❌ UI Inspector not found at: {ui_inspector_path}")
        print("\n💡 Build the UI inspector:")
        print("   cd src/ui_inspector && ./run.sh")
        return False
    
    # Test UI inspector execution
    computer_use = GPTComputerUse()
    ui_state = await computer_use.get_ui_state()
    
    if "error" in ui_state:
        print(f"❌ UI Inspector Error: {ui_state['error']}")
        print("\n💡 Troubleshooting:")
        print("1. Make sure the UI inspector is compiled:")
        print("   cd src/ui_inspector && ./run.sh")
        print("2. Check if the binary has execute permissions:")
        print(f"   chmod +x {ui_inspector_path}")
        return False
    else:
        print("✅ UI Inspector working!")
        
        # Display UI data summary
        if "summary" in ui_state:
            summary = ui_state["summary"]
            clickable_count = len(summary.get("clickableElements", []))
            text_count = len(summary.get("textContent", []))
            print(f"📊 Found {clickable_count} clickable elements and {text_count} text items")
        
        formatted = computer_use.format_ui_state_for_gpt(ui_state)
        print("📋 Sample UI data:")
        print(formatted[:300] + "..." if len(formatted) > 300 else formatted)
        return True

async def test_action_executor():
    """Test the action execution system"""
    print("\n🎯 Testing Action Executor")
    print("=" * 40)
    
    executor = ActionExecutor(debug=True)
    
    # Test wait action (safe to run)
    wait_action = {
        "action": "wait",
        "parameters": {"seconds": 0.1},
        "reasoning": "Testing wait action"
    }
    
    result = await executor.execute(wait_action)
    
    if result.success:
        print("✅ Action executor working!")
        print(f"📊 Execution time: {result.execution_time:.3f}s")
        print(f"📝 Output: {result.output}")
        
        # Test error handling
        invalid_action = {
            "action": "invalid_action",
            "parameters": {},
            "reasoning": "Testing error handling"
        }
        
        error_result = await executor.execute(invalid_action)
        if not error_result.success and "Unknown action" in error_result.error:
            print("✅ Error handling working correctly")
            return True
        else:
            print("❌ Error handling not working")
            return False
    else:
        print(f"❌ Action executor failed: {result.error}")
        return False

async def test_gpt_connection():
    """Test OpenAI API connection"""
    print("\n🔗 Testing OpenAI API Connection")
    print("=" * 40)
    
    if not os.getenv('OPENAI_API_KEY'):
        print("❌ OPENAI_API_KEY not found in environment")
        print("\n💡 Troubleshooting:")
        print("1. Create a .env file in the project root")
        print("2. Add: OPENAI_API_KEY=your_key_here")
        return False
    
    computer_use = GPTComputerUse()
    
    try:
        response = await computer_use.chat_with_gpt("Hello, can you help me test the connection? Please respond with a simple JSON action.")
        if "GPT API Error" in response:
            print(f"❌ API Error: {response}")
            print("\n💡 Troubleshooting:")
            print("1. Check your .env file has OPENAI_API_KEY set")
            print("2. Verify your API key is valid")
            print("3. Check your OpenAI account has credits")
            return False
        else:
            print("✅ OpenAI API working!")
            print(f"📝 Sample response: {response[:150]}...")
            
            # Try to parse as JSON to test structured output
            try:
                json.loads(response)
                print("✅ GPT producing structured JSON output")
                return True
            except json.JSONDecodeError:
                print("⚠️ GPT response not JSON, but API connection works")
                return True
                
    except Exception as e:
        print(f"❌ Connection failed: {str(e)}")
        return False

async def test_integrated_workflow():
    """Test the integrated workflow: UI inspection -> GPT reasoning -> Action execution"""
    print("\n🔄 Testing Integrated Workflow")
    print("=" * 40)
    
    computer_use = GPTComputerUse()
    
    try:
        # Test a simple workflow: inspect UI
        results = await computer_use.execute_task(
            "Inspect the current UI and tell me what you see", 
            max_iterations=2
        )
        
        if results:
            print(f"✅ Workflow executed! {len(results)} actions performed")
            
            # Analyze results
            ui_inspections = sum(1 for r in results if r['action'].get('action') == 'ui_inspect')
            successful_actions = sum(1 for r in results if r['result'].success)
            
            print(f"📊 UI inspections: {ui_inspections}")
            print(f"📊 Successful actions: {successful_actions}/{len(results)}")
            
            # Show action details
            for i, result in enumerate(results, 1):
                action = result['action']
                success = result['result'].success
                status = "✅" if success else "❌"
                reasoning = action.get('reasoning', 'No reasoning provided')
                print(f"   {i}. {status} {action.get('action', 'unknown')} - {reasoning[:60]}...")
            
            return successful_actions > 0
        else:
            print("❌ No actions performed")
            return False
            
    except Exception as e:
        print(f"❌ Workflow test failed: {str(e)}")
        return False

async def test_performance_benchmarks():
    """Run performance benchmarks"""
    print("\n⚡ Performance Benchmarks")
    print("=" * 40)
    
    computer_use = GPTComputerUse()
    
    # Benchmark UI inspector speed
    print("📊 UI Inspector Speed Test...")
    import time
    
    times = []
    for i in range(3):
        start = time.time()
        ui_state = await computer_use.get_ui_state()
        end = time.time()
        
        if "error" not in ui_state:
            times.append(end - start)
            print(f"   Run {i+1}: {(end-start)*1000:.1f}ms")
        else:
            print(f"   Run {i+1}: Failed - {ui_state['error']}")
    
    if times:
        avg_time = sum(times) / len(times)
        print(f"✅ Average UI inspection time: {avg_time*1000:.1f}ms")
        
        # Compare to screenshot baseline (theoretical)
        screenshot_time = 2.5  # Typical screenshot + processing time
        speedup = screenshot_time / avg_time
        print(f"🚀 Speedup vs screenshots: {speedup:.1f}x faster")
        
        return avg_time < 1.0  # Should be under 1 second
    else:
        print("❌ All UI inspector tests failed")
        return False

async def main():
    """Run all tests"""
    print("🚀 Augment System Tests")
    print("=" * 60)
    
    # Check environment first
    if not os.getenv('OPENAI_API_KEY'):
        print("⚠️ OPENAI_API_KEY not found - some tests will be skipped")
        print("💡 Create a .env file with your OpenAI API key for full testing")
    
    # Define test suite
    tests = [
        ("UI Inspector", test_ui_inspector),
        ("Action Executor", test_action_executor),
        ("OpenAI API", test_gpt_connection),
        ("Integrated Workflow", test_integrated_workflow),
        ("Performance Benchmarks", test_performance_benchmarks)
    ]
    
    # Run tests
    results = []
    for test_name, test_func in tests:
        try:
            print(f"\n{'='*20} {test_name} {'='*20}")
            
            if test_name in ["OpenAI API", "Integrated Workflow"] and not os.getenv('OPENAI_API_KEY'):
                print(f"⏭️ Skipping {test_name} - No API key")
                results.append((test_name, None))
                continue
            
            result = await test_func()
            results.append((test_name, result))
            
        except KeyboardInterrupt:
            print(f"\n⏸️ {test_name} test interrupted by user")
            results.append((test_name, False))
            break
        except Exception as e:
            print(f"💥 {test_name} test crashed: {str(e)}")
            results.append((test_name, False))
    
    # Summary
    print("\n" + "=" * 60)
    print("📊 TEST RESULTS SUMMARY")
    print("=" * 60)
    
    passed = sum(1 for _, result in results if result is True)
    failed = sum(1 for _, result in results if result is False)
    skipped = sum(1 for _, result in results if result is None)
    total = len(results)
    
    for test_name, result in results:
        if result is True:
            status = "✅ PASS"
        elif result is False:
            status = "❌ FAIL"
        else:
            status = "⏭️ SKIP"
        print(f"   {status} {test_name}")
    
    print(f"\nResults: {passed} passed, {failed} failed, {skipped} skipped")
    
    if failed == 0 and passed > 0:
        print("🎉 All available tests passed! System is ready.")
        print("\nNext steps:")
        print("1. Run: python src/main.py")
        print("2. Try: python src/main.py --task 'Show me what is on the screen'")
    elif failed > 0:
        print("⚠️ Some tests failed. Check the error messages above.")
    else:
        print("⚠️ No tests could be run. Check your setup.")

if __name__ == "__main__":
    asyncio.run(main()) 