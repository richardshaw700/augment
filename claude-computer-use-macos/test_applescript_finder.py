#!/usr/bin/env python3
"""
AppleScript test to inspect Finder window accessibility data
Modified to output complete JSON data showing all available information
"""

import subprocess
import json
import re
from datetime import datetime

def timestamp():
    return datetime.now().strftime("%H:%M:%S.%f")[:-3]

def run_applescript(script, timeout=10):
    """Run AppleScript and return result"""
    try:
        result = subprocess.run(['osascript', '-e', script], 
                              capture_output=True, text=True, timeout=timeout)
        if result.returncode == 0:
            return result.stdout.strip()
        else:
            return f"ERROR: {result.stderr.strip()}"
    except subprocess.TimeoutExpired:
        return "ERROR: Script timeout"
    except Exception as e:
        return f"ERROR: {str(e)}"

def clean_applescript_json(raw_json):
    """Clean AppleScript JSON output to handle 'missing value' and other issues"""
    # Replace 'missing value' with null
    cleaned = raw_json.replace('"missing value"', 'null')
    cleaned = cleaned.replace("'missing value'", 'null')
    cleaned = cleaned.replace("missing value", 'null')
    
    # Fix any other AppleScript-specific issues
    cleaned = re.sub(r':\s*,', ': null,', cleaned)  # Fix empty values
    
    return cleaned

def get_complete_finder_json():
    """Get complete Finder window data as JSON"""
    print(f"[{timestamp()}] Capturing complete Finder accessibility data as JSON...")
    
    # First, make sure Finder has a window open
    open_script = '''
    tell application "Finder"
        activate
        if (count of windows) = 0 then
            make new Finder window
        end if
    end tell
    '''
    run_applescript(open_script)
    
    # Wait for window to appear
    import time
    time.sleep(1)
    
    # Comprehensive JSON generation script
    json_script = '''
    tell application "System Events"
        tell process "Finder"
            tell window 1
                -- Start JSON construction
                set jsonData to "{"
                
                                 -- Window basic info
                 set windowSize to size
                 set windowPos to position
                 set jsonData to jsonData & "\\"window\\": {"
                 set jsonData to jsonData & "\\"title\\": \\"" & title & "\\", "
                 set jsonData to jsonData & "\\"size\\": [" & (item 1 of windowSize as string) & ", " & (item 2 of windowSize as string) & "], "
                 set jsonData to jsonData & "\\"position\\": [" & (item 1 of windowPos as string) & ", " & (item 2 of windowPos as string) & "], "
                 set jsonData to jsonData & "\\"role\\": \\"" & role & "\\", "
                 try
                     set jsonData to jsonData & "\\"enabled\\": " & enabled & ", "
                 on error
                     set jsonData to jsonData & "\\"enabled\\": null, "
                 end try
                 set jsonData to jsonData & "\\"focused\\": " & focused & ""
                 set jsonData to jsonData & "}, "
                
                -- Element counts
                set jsonData to jsonData & "\\"element_counts\\": {"
                set jsonData to jsonData & "\\"buttons\\": " & (count of buttons) & ", "
                set jsonData to jsonData & "\\"text_fields\\": " & (count of text fields) & ", "
                set jsonData to jsonData & "\\"static_text\\": " & (count of static text) & ", "
                set jsonData to jsonData & "\\"images\\": " & (count of images) & ", "
                set jsonData to jsonData & "\\"groups\\": " & (count of groups) & ", "
                set jsonData to jsonData & "\\"scroll_areas\\": " & (count of scroll areas) & ", "
                set jsonData to jsonData & "\\"toolbars\\": " & (count of toolbars) & ", "
                set jsonData to jsonData & "\\"total_elements\\": " & (count of entire contents) & ""
                set jsonData to jsonData & "}, "
                
                -- Buttons detailed
                set jsonData to jsonData & "\\"buttons\\": ["
                set buttonCount to count of buttons
                repeat with i from 1 to buttonCount
                    set jsonData to jsonData & "{"
                    set jsonData to jsonData & "\\"index\\": " & i & ", "
                    
                    try
                        set jsonData to jsonData & "\\"title\\": \\"" & (title of button i) & "\\", "
                    on error
                        set jsonData to jsonData & "\\"title\\": null, "
                    end try
                    
                    try
                        set jsonData to jsonData & "\\"description\\": \\"" & (description of button i) & "\\", "
                    on error
                        set jsonData to jsonData & "\\"description\\": null, "
                    end try
                    
                    try
                        set jsonData to jsonData & "\\"help\\": \\"" & (help of button i) & "\\", "
                    on error
                        set jsonData to jsonData & "\\"help\\": null, "
                    end try
                    
                    try
                        set jsonData to jsonData & "\\"value\\": \\"" & (value of button i) & "\\", "
                    on error
                        set jsonData to jsonData & "\\"value\\": null, "
                    end try
                    
                    set jsonData to jsonData & "\\"enabled\\": " & (enabled of button i) & ", "
                    set jsonData to jsonData & "\\"role\\": \\"" & (role of button i) & "\\", "
                    
                    try
                        set jsonData to jsonData & "\\"role_description\\": \\"" & (role description of button i) & "\\", "
                    on error
                        set jsonData to jsonData & "\\"role_description\\": null, "
                    end try
                    
                                         try
                         set btnPos to position of button i
                         set jsonData to jsonData & "\\"position\\": [" & (item 1 of btnPos as string) & ", " & (item 2 of btnPos as string) & "], "
                     on error
                         set jsonData to jsonData & "\\"position\\": null, "
                     end try
                     
                     try
                         set btnSize to size of button i
                         set jsonData to jsonData & "\\"size\\": [" & (item 1 of btnSize as string) & ", " & (item 2 of btnSize as string) & "]"
                     on error
                         set jsonData to jsonData & "\\"size\\": null"
                     end try
                    
                    set jsonData to jsonData & "}"
                    if i < buttonCount then set jsonData to jsonData & ", "
                end repeat
                set jsonData to jsonData & "], "
                
                -- Static text elements
                set jsonData to jsonData & "\\"static_text\\": ["
                set textCount to count of static text
                repeat with i from 1 to textCount
                    set jsonData to jsonData & "{"
                    set jsonData to jsonData & "\\"index\\": " & i & ", "
                    
                    try
                        set jsonData to jsonData & "\\"value\\": \\"" & (value of static text i) & "\\", "
                    on error
                        set jsonData to jsonData & "\\"value\\": null, "
                    end try
                    
                    try
                        set jsonData to jsonData & "\\"description\\": \\"" & (description of static text i) & "\\", "
                    on error
                        set jsonData to jsonData & "\\"description\\": null, "
                    end try
                    
                    set jsonData to jsonData & "\\"role\\": \\"" & (role of static text i) & "\\"" 
                    set jsonData to jsonData & "}"
                    if i < textCount then set jsonData to jsonData & ", "
                end repeat
                set jsonData to jsonData & "], "
                
                -- Groups
                set jsonData to jsonData & "\\"groups\\": ["
                set groupCount to count of groups
                repeat with i from 1 to groupCount
                    set jsonData to jsonData & "{"
                    set jsonData to jsonData & "\\"index\\": " & i & ", "
                    set jsonData to jsonData & "\\"role\\": \\"" & (role of group i) & "\\", "
                    
                    try
                        set jsonData to jsonData & "\\"description\\": \\"" & (description of group i) & "\\", "
                    on error
                        set jsonData to jsonData & "\\"description\\": null, "
                    end try
                    
                                         try
                         set grpPos to position of group i
                         set jsonData to jsonData & "\\"position\\": [" & (item 1 of grpPos as string) & ", " & (item 2 of grpPos as string) & "], "
                     on error
                         set jsonData to jsonData & "\\"position\\": null, "
                     end try
                     
                     try
                         set grpSize to size of group i
                         set jsonData to jsonData & "\\"size\\": [" & (item 1 of grpSize as string) & ", " & (item 2 of grpSize as string) & "], "
                     on error
                         set jsonData to jsonData & "\\"size\\": null, "
                     end try
                    
                    -- Count elements within group
                    set jsonData to jsonData & "\\"buttons_in_group\\": " & (count of buttons of group i) & ", "
                    set jsonData to jsonData & "\\"images_in_group\\": " & (count of images of group i) & ""
                    
                    set jsonData to jsonData & "}"
                    if i < groupCount then set jsonData to jsonData & ", "
                end repeat
                set jsonData to jsonData & "], "
                
                -- Toolbar info (simplified to avoid access errors)
                set jsonData to jsonData & "\\"toolbar_info\\": {"
                try
                    set toolbarCount to count of toolbars
                    set jsonData to jsonData & "\\"toolbar_count\\": " & toolbarCount & ", "
                    if toolbarCount > 0 then
                        set jsonData to jsonData & "\\"toolbar_buttons\\": " & (count of buttons of toolbar 1) & ""
                    else
                        set jsonData to jsonData & "\\"toolbar_buttons\\": 0"
                    end if
                on error
                    set jsonData to jsonData & "\\"toolbar_count\\": 0, \\"toolbar_buttons\\": 0"
                end try
                set jsonData to jsonData & "}"
                
                set jsonData to jsonData & "}"
                
                return jsonData
            end tell
        end tell
    end tell
    '''
    
    result = run_applescript(json_script, timeout=20)
    return result

def main():
    print(f"[{timestamp()}] Starting COMPLETE JSON Finder accessibility data capture...")
    print("="*80)
    
    # Get complete JSON data
    json_data = get_complete_finder_json()
    
    print(f"\n[{timestamp()}] COMPLETE ACCESSIBILITY DATA (JSON):")
    print("="*80)
    
    if json_data.startswith("ERROR:"):
        print(f"❌ {json_data}")
        return
    
    # Clean the AppleScript JSON output
    cleaned_json = clean_applescript_json(json_data)
    
    try:
        # Parse and pretty-print the JSON
        parsed_data = json.loads(cleaned_json)
        print(json.dumps(parsed_data, indent=2))
        
        print(f"\n[{timestamp()}] ✅ Successfully captured complete Finder accessibility data")
        print(f"[{timestamp()}] Total JSON size: {len(json_data)} characters")
        print(f"[{timestamp()}] Total UI elements found: {parsed_data.get('element_counts', {}).get('total_elements', 'unknown')}")
        
        # Show summary of what data we have vs missing
        print(f"\n[{timestamp()}] ACCESSIBILITY DATA SUMMARY:")
        print("="*50)
        
        buttons = parsed_data.get('buttons', [])
        print(f"Window: {parsed_data.get('window', {}).get('title', 'Unknown')}")
        print(f"Total elements: {parsed_data.get('element_counts', {}).get('total_elements', 0)}")
        print(f"Buttons found: {len(buttons)}")
        
        if buttons:
            print("\nButton details:")
            for i, btn in enumerate(buttons, 1):
                title = btn.get('title') or 'NULL'
                desc = btn.get('description') or 'NULL'
                help_text = btn.get('help') or 'NULL'
                print(f"  Button {i}: title='{title}', desc='{desc}', help='{help_text}'")
        
        groups = parsed_data.get('groups', [])
        if groups:
            print(f"\nGroups found: {len(groups)}")
            for i, grp in enumerate(groups, 1):
                buttons_in_group = grp.get('buttons_in_group', 0)
                images_in_group = grp.get('images_in_group', 0)
                print(f"  Group {i}: {buttons_in_group} buttons, {images_in_group} images")
        
        toolbar = parsed_data.get('toolbar_info', {})
        if toolbar.get('toolbar_count', 0) > 0:
            print(f"\nToolbar: {toolbar.get('toolbar_buttons', 0)} buttons")
        
    except json.JSONDecodeError as e:
        print(f"❌ JSON parsing still failed after cleaning: {e}")
        print(f"\n[{timestamp()}] CLEANED JSON (for debugging):")
        print("-" * 40)
        print(cleaned_json)
        print("-" * 40)
        print(f"\n[{timestamp()}] ORIGINAL RAW OUTPUT:")
        print("-" * 40)
        print(json_data)
        print("-" * 40)

if __name__ == "__main__":
    main() 