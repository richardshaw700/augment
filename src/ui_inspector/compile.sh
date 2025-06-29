#!/bin/bash

echo "🚀 Compiling Clean Architecture UI Inspector..."

# Compile all Swift files together with clean architecture
swiftc \
  Configuration.swift \
  DataModels.swift \
  DataCleaningService.swift \
  CompressionService.swift \
  WindowManager.swift \
  CoordinateSystem.swift \
  AccessibilityEngine.swift \
  OCREngine.swift \
  OutputManager.swift \
  PerformanceMonitor.swift \
  MenuBarInspector.swift \
  FileManager.swift \
  AppDetectionService.swift \
  ParallelDetectionCoordinator.swift \
  fusion_engine/_FusionOrchestrator.swift \
  fusion_engine/Deduplication.swift \
  fusion_engine/ElementCreation.swift \
  fusion_engine/ElementQualityFilter.swift \
  fusion_engine/SpatialOptimization.swift \
  fusion_engine/UIElementAnalyzer.swift \
  fusion_engine/UIElementExtensions.swift \
  fusion_engine/VisualIntegration.swift \
  shape_detection_engine/_ShapeOrchestrator.swift \
  shape_detection_engine/ShapeDataModels.swift \
  shape_detection_engine/ContourDetection.swift \
  shape_detection_engine/ShapeClassification.swift \
  shape_detection_engine/InteractionDetection.swift \
  shape_detection_engine/SpecializedDetectors.swift \
  shape_detection_engine/ExpensiveDetectors.swift \
  shape_detection_engine/PerformanceOptimization.swift \
  _UIInspectOrchestrator.swift \
  -o compiled_ui_inspector

if [ $? -eq 0 ]; then
    echo "✅ Clean Architecture compilation successful!"
    echo "🏗️ Architecture features:"
    echo "   • Separated concerns with dedicated services"
    echo "   • AppDetectionService for app management"
    echo "   • ParallelDetectionCoordinator for efficient processing"
    echo "   • ElementQualityFilter for intelligent filtering"
    echo "   • UIElementAnalyzer for comprehensive analysis"
    echo "   • Extended services with specialized methods"
    echo ""
    echo "💡 To run the UI Inspector:"
    echo "   ./compiled_ui_inspector > output/latest_run_logs.txt 2>&1"
else
    echo "❌ Compilation failed!"
    exit 1
fi 