#!/bin/bash

echo "🔧 Enabling Safari JavaScript from Apple Events..."
echo "================================================"

osascript << 'EOF'
tell application "Safari"
    activate
    delay 1
end tell

tell application "System Events"
    tell process "Safari"
        -- Step 1: Open Safari Settings (⌘,)
        keystroke "," using command down
        delay 2
        
        -- Step 2: Go to Advanced tab
        try
            click button "Advanced" of toolbar 1 of window 1
            display notification "✅ Step 2: Clicked Advanced tab"
            delay 1
        on error errMsg
            display notification "❌ Step 2 failed: Could not find Advanced tab"
            return
        end try
        
        -- Step 3: Check "Show features for developers" (if unchecked)
        try
            set featuresCheckbox to checkbox "Show features for web developers" of window 1
            if value of featuresCheckbox is 0 then
                click featuresCheckbox
                display notification "✅ Step 3: Enabled 'Show features for web developers'"
                delay 2
            else
                display notification "✅ Step 3: 'Show features for web developers' already enabled"
                delay 1
            end if
        on error errMsg
            display notification "❌ Step 3 failed: Could not find features checkbox"
            return
        end try
        
        -- Step 4a: Click the Developer tab in the top right
        try
            click button "Developer" of toolbar 1 of window 1
            display notification "✅ Step 4a: Clicked Developer tab"
            delay 2
        on error errMsg
            display notification "❌ Step 4a failed: Could not find Developer tab"
            return
        end try
        
        -- Step 4b: Click "Allow JavaScript from Apple Events" (if unchecked)
        try
            set jsCheckbox to checkbox "Allow JavaScript from Apple Events" of window 1
            if value of jsCheckbox is 0 then
                click jsCheckbox
                display notification "✅ Step 4b: Enabled 'Allow JavaScript from Apple Events'"
            else
                display notification "✅ Step 4b: 'Allow JavaScript from Apple Events' already enabled"
            end if
        on error errMsg
            display notification "❌ Step 4b failed: Could not find JavaScript checkbox"
            return
        end try
        
        -- Success!
        display notification "🎉 Safari JavaScript permissions fully enabled!"
        
        -- Close settings window
        delay 1
        keystroke "w" using command down
    end tell
end tell
EOF

echo ""
echo "✅ Safari JavaScript permissions setup complete!"
echo "🧪 You can now run the browser test: ./src/ui_inspector/run_browser_test.sh" 