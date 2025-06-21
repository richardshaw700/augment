#!/usr/bin/env python3
"""
Test script for GPT Computer Use simulation
"""

import asyncio
import os
from gpt_computer_use import GPTComputerUse

async def test_ui_inspector():
    """Test the UI inspector integration"""
    print("🧪 Testing UI Inspector Integration")
    print("=" * 40)
    
    computer_use = GPTComputerUse()
    
    # Test UI inspector directly
    ui_state = await computer_use.get_ui_state()
    
    if "error" in ui_state:
        print(f"❌ UI Inspector Error: {ui_state['error']}")
        print("\n💡 Troubleshooting:")
        print("1. Make sure the UI inspector is compiled:")
        print("   cd claude-computer-use-macos/ui_inspector && ./run.sh")
        print("2. Check if the binary exists:")
        print("   ls -la claude-computer-use-macos/ui_inspector/compiled_ui_inspector")
        return False
    else:
        print("✅ UI Inspector working!")
        formatted = computer_use.format_ui_state_for_gpt(ui_state)
        print("📋 Sample UI data:")
        print(formatted[:500] + "..." if len(formatted) > 500 else formatted)
        return True

async def test_gpt_connection():
    """Test OpenAI API connection"""
    print("\n🔗 Testing OpenAI API Connection")
    print("=" * 40)
    
    computer_use = GPTComputerUse()
    
    try:
        response = await computer_use.chat_with_gpt("Hello, can you help me test the connection?")
        if "GPT API Error" in response:
            print(f"❌ API Error: {response}")
            print("\n💡 Troubleshooting:")
            print("1. Check your .env file has OPENAI_API_KEY set")
            print("2. Verify your API key is valid")
            print("3. Check your OpenAI account has credits")
            return False
        else:
            print("✅ OpenAI API working!")
            print(f"📝 Sample response: {response[:200]}...")
            return True
    except Exception as e:
        print(f"❌ Connection failed: {str(e)}")
        return False

async def test_simple_task():
    """Test a simple computer use task"""
    print("\n🎯 Testing Simple Task Execution")
    print("=" * 40)
    
    computer_use = GPTComputerUse()
    
    try:
        # Simple task: just inspect the UI
        results = await computer_use.execute_task("Inspect the current UI and tell me what you see", max_iterations=2)
        
        if results:
            print(f"✅ Task executed! {len(results)} actions performed")
            for i, result in enumerate(results, 1):
                action = result['action']
                success = result['result'].success
                status = "✅" if success else "❌"
                print(f"   {i}. {status} {action.get('action', 'unknown')} - {action.get('reasoning', '')}")
            return True
        else:
            print("❌ No actions performed")
            return False
            
    except Exception as e:
        print(f"❌ Task execution failed: {str(e)}")
        return False

async def main():
    """Run all tests"""
    print("🚀 GPT Computer Use - System Tests")
    print("=" * 60)
    
    # Check environment
    if not os.getenv('OPENAI_API_KEY'):
        print("❌ OPENAI_API_KEY not found in environment")
        print("💡 Create a .env file with your OpenAI API key")
        return
    
    # Run tests
    tests = [
        ("UI Inspector", test_ui_inspector),
        ("OpenAI API", test_gpt_connection),
        ("Simple Task", test_simple_task)
    ]
    
    results = []
    for test_name, test_func in tests:
        try:
            result = await test_func()
            results.append((test_name, result))
        except Exception as e:
            print(f"❌ {test_name} test crashed: {str(e)}")
            results.append((test_name, False))
    
    # Summary
    print("\n" + "=" * 60)
    print("📊 Test Results Summary:")
    passed = sum(1 for _, result in results if result)
    total = len(results)
    
    for test_name, result in results:
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"   {status} {test_name}")
    
    print(f"\nOverall: {passed}/{total} tests passed")
    
    if passed == total:
        print("🎉 All systems ready! You can now run: python gpt_computer_use.py")
    else:
        print("⚠️  Some tests failed. Check the error messages above.")

if __name__ == "__main__":
    asyncio.run(main()) 