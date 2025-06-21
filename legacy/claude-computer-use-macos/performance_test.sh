#!/bin/bash

echo "🚀 UI Inspector Performance Test"
echo "================================"
echo "$(python3 -c "import datetime; print(datetime.datetime.now().strftime('%a %b %d %H:%M:%S.%f %Z %Y'))" 2>/dev/null || date +"%a %b %d %H:%M:%S %Z %Y"): Script startup complete"
SWIFT_START_TIME=$(python3 -c "import time; print(time.time())" 2>/dev/null || date +%s)
echo "$(python3 -c "import datetime; print(datetime.datetime.now().strftime('%a %b %d %H:%M:%S.%f %Z %Y'))" 2>/dev/null || date +"%a %b %d %H:%M:%S %Z %Y"): Building Swift program..."
echo ""

# Run Swift and process output in real-time
swift ui_inspector.swift 2>&1 | while IFS= read -r line; do
    if [[ "$line" == "SWIFT_COMPILATION_FINISHED" ]]; then
        BUILD_TIME=$(python3 -c "import time; print(f'{time.time()-${SWIFT_START_TIME}:.3f}')" 2>/dev/null || echo "N/A")
        echo "$(python3 -c "import datetime; print(datetime.datetime.now().strftime('%a %b %d %H:%M:%S.%f %Z %Y'))" 2>/dev/null || date +"%a %b %d %H:%M:%S %Z %Y"): Swift compilation finished"
        echo "⚡ Swift build time: ${BUILD_TIME}s"
        echo ""
    elif [[ "$line" =~ "⏱️  PERFORMANCE BREAKDOWN:" ]]; then
        echo "$line"
        performance_section=true
    elif [[ "$line" =~ "🏁 TOTAL TIME:" ]] && [[ "$performance_section" == "true" ]]; then
        echo "$line"
        echo ""
        performance_section=false
    elif [[ "$line" =~ "📊 COMPRESSION STATS:" ]]; then
        echo "$line"
        compression_section=true
    elif [[ "$line" =~ "Compression ratio:" ]] && [[ "$compression_section" == "true" ]]; then
        echo "$line"
        echo ""
        compression_section=false
    elif [[ "$performance_section" == "true" ]] || [[ "$compression_section" == "true" ]]; then
        echo "$line"
    fi
done

echo "✅ Performance test complete!"
echo "$(python3 -c "import datetime; print(datetime.datetime.now().strftime('%a %b %d %H:%M:%S.%f %Z %Y'))" 2>/dev/null || date +"%a %b %d %H:%M:%S %Z %Y"): Test finished" 