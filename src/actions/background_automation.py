#!/usr/bin/env python3
"""
Background Automation Module
Perform macOS actions in the background without interrupting user workflow
"""

import subprocess
import asyncio
import json
import os
from typing import Optional, Dict, Any, List
from dataclasses import dataclass

@dataclass
class BackgroundActionResult:
    """Result of a background automation action"""
    success: bool
    output: str = ""
    error: str = ""
    action_type: str = ""

class BackgroundAutomation:
    """Handles background automation tasks on macOS"""
    
    def __init__(self, debug: bool = False):
        self.debug = debug
        
    async def send_imessage(self, recipient: str, message: str) -> BackgroundActionResult:
        """
        Send an iMessage in the background without opening Messages app
        
        Args:
            recipient: Phone number (+1234567890) or email address
            message: Text message to send
            
        Returns:
            BackgroundActionResult with success status
        """
        # Clean phone number format
        if recipient.startswith('+'):
            phone_number = recipient
        elif recipient.startswith('('):
            # Format like (555) 123-4567
            phone_number = recipient
        elif '@' in recipient:
            # Email address for iMessage
            phone_number = recipient
        else:
            # Assume it's a raw phone number, format it
            phone_number = recipient
        
        applescript = f'''
        tell application "Messages"
            set targetService to id of 1st account whose service type = iMessage
            set targetBuddy to participant "{phone_number}" of account id targetService
            send "{message.replace('"', '\\"')}" to targetBuddy
        end tell
        '''
        
        return await self._execute_applescript(applescript, f"Sending iMessage to {recipient}")
    
    async def send_sms(self, recipient: str, message: str) -> BackgroundActionResult:
        """
        Send an SMS in the background (requires iPhone nearby with text forwarding)
        
        Args:
            recipient: Phone number
            message: Text message to send
            
        Returns:
            BackgroundActionResult with success status
        """
        applescript = f'''
        tell application "Messages"
            try
                set targetService to id of 1st service whose service type = SMS
                set targetBuddy to participant "{recipient}" of service id targetService
                send "{message.replace('"', '\\"')}" to targetBuddy
            on error
                -- Fallback to iMessage if SMS service not available
                set targetService to id of 1st account whose service type = iMessage
                set targetBuddy to participant "{recipient}" of account id targetService
                send "{message.replace('"', '\\"')}" to targetBuddy
            end try
        end tell
        '''
        
        return await self._execute_applescript(applescript, f"Sending SMS to {recipient}")
    
    async def send_email(self, recipient: str, subject: str, body: str, 
                        cc: Optional[str] = None) -> BackgroundActionResult:
        """
        Send an email in the background using default mail app
        
        Args:
            recipient: Email address
            subject: Email subject
            body: Email body text
            cc: Optional CC recipients
            
        Returns:
            BackgroundActionResult with success status
        """
        cc_part = f'set cc to "{cc}"' if cc else ""
        
        applescript = f'''
        tell application "Mail"
            set theMessage to make new outgoing message with properties {{subject:"{subject}", content:"{body.replace('"', '\\"')}"}}
            tell theMessage
                make new to recipient at end of to recipients with properties {{address:"{recipient}"}}
                {cc_part}
                if cc is not "" then
                    make new cc recipient at end of cc recipients with properties {{address:cc}}
                end if
                send
            end tell
        end tell
        '''
        
        return await self._execute_applescript(applescript, f"Sending email to {recipient}")
    
    async def add_calendar_event(self, title: str, start_date: str, 
                               end_date: Optional[str] = None) -> BackgroundActionResult:
        """
        Add a calendar event in the background
        
        Args:
            title: Event title
            start_date: Start date/time (YYYY-MM-DD HH:MM format)
            end_date: Optional end date/time
            
        Returns:
            BackgroundActionResult with success status
        """
        end_part = f'end date:date "{end_date}",' if end_date else ""
        
        applescript = f'''
        tell application "Calendar"
            tell calendar "Calendar"
                make new event with properties {{summary:"{title}", start date:date "{start_date}", {end_part}}}
            end tell
        end tell
        '''
        
        return await self._execute_applescript(applescript, f"Adding calendar event: {title}")
    
    async def add_reminder(self, title: str, due_date: Optional[str] = None) -> BackgroundActionResult:
        """
        Add a reminder in the background
        
        Args:
            title: Reminder text
            due_date: Optional due date (YYYY-MM-DD format)
            
        Returns:
            BackgroundActionResult with success status
        """
        due_part = f'due date:date "{due_date}",' if due_date else ""
        
        applescript = f'''
        tell application "Reminders"
            tell list "Reminders"
                make new reminder with properties {{name:"{title}", {due_part}}}
            end tell
        end tell
        '''
        
        return await self._execute_applescript(applescript, f"Adding reminder: {title}")
    
    async def execute_shell_command(self, command: str) -> BackgroundActionResult:
        """
        Execute a shell command in the background
        
        Args:
            command: Shell command to execute
            
        Returns:
            BackgroundActionResult with command output
        """
        try:
            result = await asyncio.create_subprocess_shell(
                command,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, stderr = await result.communicate()
            
            if result.returncode == 0:
                return BackgroundActionResult(
                    success=True,
                    output=stdout.decode().strip(),
                    action_type="shell"
                )
            else:
                return BackgroundActionResult(
                    success=False,
                    error=stderr.decode().strip(),
                    action_type="shell"
                )
        except Exception as e:
            return BackgroundActionResult(
                success=False,
                error=f"Failed to execute command: {str(e)}",
                action_type="shell"
            )
    
    async def create_note(self, title: str, content: str) -> BackgroundActionResult:
        """
        Create a note in the background using Notes app
        
        Args:
            title: Note title
            content: Note content
            
        Returns:
            BackgroundActionResult with success status
        """
        applescript = f'''
        tell application "Notes"
            tell account "iCloud"
                tell folder "Notes"
                    make new note with properties {{name:"{title}", body:"{content.replace('"', '\\"')}"}}
                end tell
            end tell
        end tell
        '''
        
        return await self._execute_applescript(applescript, f"Creating note: {title}")
    
    async def _execute_applescript(self, script: str, description: str = "") -> BackgroundActionResult:
        """Execute AppleScript and return formatted result"""
        try:
            # Print OS-formatted status before execution
            if description:
                print(f"🤖 OS Response: {{\"reasoning\": \"{description}\"}}")
            
            process = await asyncio.create_subprocess_exec(
                'osascript', '-e', script,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            stdout, stderr = await process.communicate()
            
            if process.returncode == 0:
                output = stdout.decode('utf-8').strip() if stdout else ""
                
                # Print success message in OS format
                success_msg = f"✅ {description} completed successfully!" if description else "✅ Action completed successfully!"
                print(f"🤖 OS Response: {{\"reasoning\": \"{success_msg}\"}}")
                
                return BackgroundActionResult(
                    success=True,
                    output=output,
                    action_type="applescript"
                )
            else:
                error = stderr.decode('utf-8').strip() if stderr else f"Process returned code {process.returncode}"
                
                # Print error message in OS format
                error_msg = f"❌ {description} failed: {error[:100]}..." if description else f"❌ Action failed: {error[:100]}..."
                print(f"🤖 OS Response: {{\"reasoning\": \"{error_msg}\"}}")
                
                return BackgroundActionResult(
                    success=False,
                    error=error,
                    action_type="applescript"
                )
        
        except Exception as e:
            error_msg = f"❌ {description} failed: {str(e)[:100]}..." if description else f"❌ Action failed: {str(e)[:100]}..."
            print(f"🤖 OS Response: {{\"reasoning\": \"{error_msg}\"}}")
            
            return BackgroundActionResult(
                success=False,
                error=str(e),
                action_type="applescript"
            )
    
    async def lookup_contact(self, name: str) -> BackgroundActionResult:
        """
        Look up a contact by name and return their phone number or email
        
        Args:
            name: Contact name to search for
            
        Returns:
            BackgroundActionResult with contact info in output field
        """
        applescript = f'''
        tell application "Contacts"
            set matchingPeople to people whose name contains "{name}"
            if (count of matchingPeople) > 0 then
                set firstPerson to item 1 of matchingPeople
                set contactInfo to ""
                
                -- Try to get phone number first
                set phoneNumbers to phones of firstPerson
                if (count of phoneNumbers) > 0 then
                    set contactInfo to value of item 1 of phoneNumbers
                else
                    -- Fall back to email if no phone
                    set emailAddresses to emails of firstPerson
                    if (count of emailAddresses) > 0 then
                        set contactInfo to value of item 1 of emailAddresses
                    end if
                end if
                
                if contactInfo is not "" then
                    return contactInfo
                else
                    return "ERROR: No phone or email found for " & name
                end if
            else
                return "ERROR: Contact not found: " & name
            end if
        end tell
        '''
        
        return await self._execute_applescript(applescript, f"Looking up contact: {name}")
    
    async def send_message_to_contact(self, contact_name: str, message: str) -> BackgroundActionResult:
        """
        Send a message to a contact by name (automatically looks up phone/email)
        
        Args:
            contact_name: Name of the contact
            message: Message to send
            
        Returns:
            BackgroundActionResult with success status
        """
        # First, look up the contact
        lookup_result = await self.lookup_contact(contact_name)
        
        if not lookup_result.success:
            return BackgroundActionResult(
                success=False,
                error=f"Contact lookup failed: {lookup_result.error}",
                action_type="contact_message"
            )
        
        contact_info = lookup_result.output.strip()
        
        if contact_info.startswith("ERROR:"):
            return BackgroundActionResult(
                success=False,
                error=contact_info,
                action_type="contact_message"
            )
        
        # Now send the message using the resolved contact info
        print(f"🤖 OS Response: {{\"reasoning\": \"📱 Sending message to {contact_name} ({contact_info})...\"}}")
        
        return await self.send_imessage(contact_info, message)
    
    async def lookup_group_chat(self, chat_name: str) -> BackgroundActionResult:
        """
        Look up a group chat by name in Messages app
        
        Args:
            chat_name: Group chat name to search for
            
        Returns:
            BackgroundActionResult with chat ID in output field
        """
        applescript = f'''
        tell application "Messages"
            set matchingChats to {{}}
            
            -- Search through all chats for ones containing the name
            repeat with aChat in chats
                try
                    set chatName to name of aChat
                    if chatName contains "{chat_name}" then
                        set end of matchingChats to id of aChat
                        exit repeat
                    end if
                end try
            end repeat
            
            if (count of matchingChats) > 0 then
                return item 1 of matchingChats
            else
                return "ERROR: Group chat not found: " & "{chat_name}"
            end if
        end tell
        '''
        
        return await self._execute_applescript(applescript, f"Looking up group chat: {chat_name}")
    
    async def send_message_to_group_chat(self, chat_name: str, message: str) -> BackgroundActionResult:
        """
        Send a message to a group chat by name
        
        Args:
            chat_name: Name of the group chat
            message: Message to send
            
        Returns:
            BackgroundActionResult with success status
        """
        # First, look up the group chat
        lookup_result = await self.lookup_group_chat(chat_name)
        
        if not lookup_result.success:
            return BackgroundActionResult(
                success=False,
                error=f"Group chat lookup failed: {lookup_result.error}",
                action_type="group_message"
            )
        
        chat_id = lookup_result.output.strip()
        
        if chat_id.startswith("ERROR:"):
            return BackgroundActionResult(
                success=False,
                error=chat_id,
                action_type="group_message"
            )
        
        # Send message to the group chat using its ID
        applescript = f'''
        tell application "Messages"
            set targetChat to chat id "{chat_id}"
            send "{message.replace('"', '\\"')}" to targetChat
        end tell
        '''
        
        return await self._execute_applescript(applescript, f"Sending message to group chat: {chat_name}")
    
    async def send_message_smart(self, recipient: str, message: str) -> BackgroundActionResult:
        """
        Smart message sending that tries individual contact first, then group chat
        
        Args:
            recipient: Contact name or group chat name
            message: Message to send
            
        Returns:
            BackgroundActionResult with success status
        """
        # If it looks like phone/email, send directly
        if '@' in recipient or recipient.startswith('+') or recipient.replace('(', '').replace(')', '').replace('-', '').replace(' ', '').isdigit():
            return await self.send_imessage(recipient, message)
        
        # Try individual contact first
        print(f"🤖 OS Response: {{\"reasoning\": \"🔍 Looking for '{recipient}' in contacts...\"}}")
        contact_result = await self.send_message_to_contact(recipient, message)
        
        if contact_result.success:
            return contact_result
        
        # If individual contact failed, try group chat
        print(f"🤖 OS Response: {{\"reasoning\": \"🔍 Contact not found, trying group chats...\"}}")
        group_result = await self.send_message_to_group_chat(recipient, message)
        
        if group_result.success:
            return group_result
        
        # Both failed
        return BackgroundActionResult(
            success=False,
            error=f"Could not find '{recipient}' as either a contact or group chat. Contact error: {contact_result.error}. Group chat error: {group_result.error}",
            action_type="smart_message"
        )

# Convenience functions for easy integration
async def send_text_message(recipient: str, message: str) -> bool:
    """
    Smart function to send a text message
    Automatically handles: phone numbers, emails, contact names, and group chat names
    """
    automation = BackgroundAutomation()
    result = await automation.send_message_smart(recipient, message)
    return result.success

async def send_message_to_contact_name(contact_name: str, message: str) -> bool:
    """Quick function to send a message by contact name (with lookup)"""
    automation = BackgroundAutomation()
    result = await automation.send_message_to_contact(contact_name, message)
    return result.success

async def send_quick_email(recipient: str, subject: str, body: str) -> bool:
    """Quick function to send an email"""
    automation = BackgroundAutomation()
    result = await automation.send_email(recipient, subject, body)
    return result.success

async def add_quick_reminder(title: str) -> bool:
    """Quick function to add a reminder"""
    automation = BackgroundAutomation()
    result = await automation.add_reminder(title)
    return result.success 