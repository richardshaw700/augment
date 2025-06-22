#!/usr/bin/env python3
"""
Background Automation Example
Demonstrates how to send messages, emails, and perform other actions in the background
"""

import asyncio
import sys
import os

# Add the src directory to the path so we can import our modules
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'src'))

from actions.background_automation import BackgroundAutomation

async def main():
    """Example usage of background automation"""
    
    # Initialize the background automation system
    automation = BackgroundAutomation(debug=True)
    
    print("🤖 Background Automation Examples")
    print("=" * 50)
    
    # Example 1: Send an iMessage
    print("\n📱 Example 1: Send iMessage")
    recipient = "+1234567890"  # Replace with actual phone number
    message = "Hey! This message was sent via automation without opening Messages app."
    
    result = await automation.send_imessage(recipient, message)
    if result.success:
        print(f"✅ Message sent successfully: {result.output}")
    else:
        print(f"❌ Failed to send message: {result.error}")
    
    # Example 2: Send an email
    print("\n📧 Example 2: Send Email")
    email_recipient = "someone@example.com"  # Replace with actual email
    subject = "Automated Email Test"
    body = "This email was sent via background automation!"
    
    result = await automation.send_email(email_recipient, subject, body)
    if result.success:
        print(f"✅ Email sent successfully: {result.output}")
    else:
        print(f"❌ Failed to send email: {result.error}")
    
    # Example 3: Add a reminder
    print("\n📝 Example 3: Add Reminder")
    reminder_title = "Call the dentist"
    
    result = await automation.add_reminder(reminder_title)
    if result.success:
        print(f"✅ Reminder added successfully: {result.output}")
    else:
        print(f"❌ Failed to add reminder: {result.error}")
    
    # Example 4: Create a note
    print("\n📄 Example 4: Create Note")
    note_title = "Automation Test"
    note_content = "This note was created automatically via AppleScript!"
    
    result = await automation.create_note(note_title, note_content)
    if result.success:
        print(f"✅ Note created successfully: {result.output}")
    else:
        print(f"❌ Failed to create note: {result.error}")
    
    # Example 5: Execute shell command
    print("\n⚡ Example 5: Shell Command")
    command = "echo 'Background automation is working!'"
    
    result = await automation.execute_shell_command(command)
    if result.success:
        print(f"✅ Command executed: {result.output}")
    else:
        print(f"❌ Command failed: {result.error}")
    
    print("\n🎉 Background automation examples completed!")

if __name__ == "__main__":
    print("This example demonstrates background automation capabilities.")
    print("Make sure to update the phone number and email address before running.")
    print("\nTo run this example:")
    print("1. Update recipient information in the script")
    print("2. Run: python examples/background_automation_example.py")
    print("\nNote: You may need to grant permissions for automation access.")
    
    # Uncomment the line below to run the examples
    # asyncio.run(main()) 