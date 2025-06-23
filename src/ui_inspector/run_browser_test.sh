#!/bin/bash

echo "🧪 Browser Inspector Test Runner"
echo "================================"

# Check if we're in the right directory
if [ ! -f "src/ui_inspector/test_browser_inspector.swift" ]; then
    echo "❌ Please run this script from the augment root directory"
    echo "   Current directory: $(pwd)"
    echo "   Expected: /path/to/augment"
    exit 1
fi

# Create output directory if it doesn't exist
mkdir -p src/ui_inspector/output

echo "📁 Output directory: src/ui_inspector/output"
echo ""

# Compile and run the Swift test
echo "🔨 Compiling Swift test..."
if ! swift src/ui_inspector/test_browser_inspector.swift src/ui_inspector/BrowserInspector.swift 2>/dev/null; then
    echo "❌ Swift compilation failed. Trying alternative approach..."
    echo ""
    
    # Try running without compilation (interpreted mode)
    echo "🔄 Running in interpreted mode..."
    swift -I src/ui_inspector src/ui_inspector/test_browser_inspector.swift
else
    echo "✅ Test completed successfully!"
fi

echo ""
echo "📋 Instructions for testing:"
echo "1. Open Safari, Chrome, or Edge"
echo "2. Navigate to any website (try Netflix, Google, etc.)"
echo "3. For Safari: Enable Develop > Allow JavaScript from Apple Events"
echo "4. Run this script again"
echo ""
echo "📂 Check src/ui_inspector/output/ for test results" 