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
  BrowserInspector.swift \
  ShapeDetectionEngine.swift \
  MenuBarInspector.swift \
  FileManager.swift \
  main.swift \
  -o compiled_ui_inspector

if [ $? -eq 0 ]; then
    echo "✅ Compilation successful!"
    echo "🏃 Running UI Inspector..."
    ./compiled_ui_inspector > latest_run_logs.txt 2>&1
    echo "📝 Logs saved to latest_run_logs.txt"
    echo "📊 Last few lines of output:"
    tail -10 latest_run_logs.txt
else
    echo "❌ Compilation failed!"
    exit 1
fi 