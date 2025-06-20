#!/bin/bash

echo "🚀 Compiling Refactored UI Inspector..."

# Compile all Swift files together
swiftc \
  DataModels.swift \
  WindowManager.swift \
  CoordinateSystem.swift \
  AccessibilityEngine.swift \
  OCREngine.swift \
  FusionEngine.swift \
  GridMapper.swift \
  CompressionEngine.swift \
  OutputManager.swift \
  PerformanceMonitor.swift \
  main.swift \
  -o compiled_ui_inspector

if [ $? -eq 0 ]; then
    echo "✅ Compilation successful!"
    echo "🏃 Running UI Inspector..."
    ./compiled_ui_inspector
else
    echo "❌ Compilation failed!"
    exit 1
fi 