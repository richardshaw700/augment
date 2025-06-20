#!/bin/bash

echo "🚀 Compiling Refactored UI Inspector..."

# Compile all Swift files together
swift \
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
  -o ui_inspector_refactored

if [ $? -eq 0 ]; then
    echo "✅ Compilation successful!"
    echo "🏃 Running UI Inspector..."
    ./ui_inspector_refactored
else
    echo "❌ Compilation failed!"
    exit 1
fi 