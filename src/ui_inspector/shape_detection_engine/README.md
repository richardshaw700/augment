# Shape Detection Engine

A sophisticated computer vision system for automatically identifying and classifying interactive UI elements from screenshots. This engine detects clickable and interactable elements that traditional accessibility APIs might miss.

## Overview

The Shape Detection Engine is one of three parallel detection systems (alongside Accessibility and OCR engines) that provides comprehensive UI element coverage for automation and analysis. It specializes in detecting:

- Visual elements without proper accessibility labels
- Custom UI components in web applications
- Graphics-based interface elements  
- Window control buttons (close, minimize, maximize)
- Search boxes and text input fields

## Architecture

The system follows a modular, orchestrated architecture with clear separation of concerns:

```
Screenshot Input (CGImage)
         ↓
    ShapeDetectionOrchestrator
         ↓
    Performance Strategy Selection
         ↓
    ┌─────────────┬─────────────┬─────────────┐
    │   Contour   │    Shape    │ Interaction │
    │  Detection  │Classification│  Detection  │
    └─────────────┴─────────────┴─────────────┘
         ↓
    Specialized Detectors (Optional)
         ↓
    Performance Optimization & Caching
         ↓
    UIShapeCandidate[] Output
```

## Files Overview

### Core Components

- **`Orchestrator.swift`** - Main coordinator that orchestrates the 11-step detection pipeline
- **`ShapeDataModels.swift`** - Data structures and enums used throughout the system
- **`ContourDetection.swift`** - Vision framework interface for extracting geometric shapes
- **`ShapeClassification.swift`** - Geometric analysis and UI role inference
- **`InteractionDetection.swift`** - Semantic analysis and interaction type assignment

### Detection Modules

- **`SpecializedDetectors.swift`** - Fast, performance-optimized detection methods
- **`ExpensiveDetectors.swift`** - High-accuracy pixel-level analysis (can be slow)
- **`PerformanceOptimization.swift`** - Caching, adaptive thresholds, and performance management

## Usage

### Basic Usage

```swift
let shapeElements = ShapeDetectionOrchestrator.detectShapes(
    in: screenshot,
    windowFrame: windowFrame,
    visualConfig: true,
    debug: false
)
```

### Performance Configuration

```swift
// Configure performance thresholds
PerformanceOptimization.PerformanceThresholds.maxPixelCount = 1_500_000
PerformanceOptimization.PerformanceThresholds.maxElementCount = 75
PerformanceOptimization.PerformanceThresholds.adaptiveThresholds = true
```

## Detection Pipeline

1. **Cache Check** - Look for cached results using image hash
2. **Strategy Selection** - Choose fast/balanced/full based on image complexity
3. **Contour Detection** - Extract raw shapes using Vision framework
4. **Contour Optimization** - Filter noise and invalid shapes
5. **Shape Classification** - Analyze geometry to determine shape types
6. **UI Role Inference** - Map shapes to UI purposes using relative sizing
7. **Specialized Detection** - Add window controls and specific elements
8. **Interaction Assignment** - Determine interaction capabilities
9. **Interactive Filtering** - Keep only automation-relevant elements
10. **Early Termination** - Stop if sufficient elements found or time limits exceeded
11. **Caching & Metrics** - Store results and record performance data

## Performance Strategies

### Three-Tier Detection System

- **Fast** (~0.735s): Basic contour detection + generic window controls
- **Balanced**: Fast detection + limited expensive detection for <50 elements  
- **Full** (~1.315s): All detection methods including pixel-level analysis

### Adaptive Performance

The system automatically adjusts based on:
- Image size and complexity
- System memory pressure
- Historical performance metrics
- Configurable thresholds

## Key Features

### Universal Compatibility
- ✅ No hardcoded app-specific coordinates
- ✅ Relative positioning based on window dimensions
- ✅ Dynamic sizing that scales across screen resolutions
- ✅ Platform-agnostic design

### Intelligent Classification
- Geometric analysis using aspect ratios and curvature
- Relative size thresholds that adapt to container dimensions
- Position-based heuristics using percentage calculations
- Multi-criteria confidence scoring

### Performance Optimization
- 30-second result caching with automatic expiration
- Memory pressure detection and threshold adjustment
- Early termination to prevent excessive processing time
- Configurable performance parameters

## Output Format

The system produces `UIShapeCandidate` objects with:

```swift
struct UIShapeCandidate {
    let contour: CGPath           // Exact shape boundary
    let boundingBox: CGRect       // Position and size  
    let type: ShapeType          // circle, rectangle, roundedRectangle, etc.
    let uiRole: UIRole           // button, icon, inputField, container, etc.
    let interactionType: InteractionType // textInput, button, closeButton, etc.
    let confidence: Double        // 0.0-1.0 confidence score
    let area: CGFloat            // Shape area
    let aspectRatio: CGFloat     // Width/height ratio
    let corners: [CGPoint]       // Key corner points
    let curvature: Double        // Shape complexity measure
}
```

## Specialized Detection Types

### Text Input Detection
- Wide rectangles with aspect ratio >2.5
- Center positioning heuristics
- Multiple detection strategies for modern search boxes

### Button Detection  
- Medium-sized circles and rectangles
- High confidence scoring
- Interactive position validation

### Window Control Detection
- Small circles in top-left corner using relative positioning
- Color verification for enhanced accuracy
- Dynamic sizing based on window dimensions

## Configuration Options

### Performance Thresholds (via `PerformanceOptimization.PerformanceThresholds`)

```swift
static var maxPixelCount: Double = 2_000_000      // Max pixels for expensive detection
static var maxElementCount: Int = 100             // Max elements before skipping expensive detection  
static var maxExpensiveDetectionTime: Double = 5.0 // Max time for expensive detection
static var adaptiveThresholds: Bool = true        // Enable adaptive behavior
```

### Vision Framework Parameters (in `ContourDetection.swift`)

```swift
request.contrastAdjustment = 2.0      // Enhance contrast for better detection
request.maximumImageDimension = 1024   // Balance performance vs accuracy
```

## Integration

The Shape Detection Engine integrates with the broader UI Inspector system:

```swift
// Called by ParallelDetectionCoordinator
let shapeElements = ShapeDetectionOrchestrator.detectShapes(...)

// Results fused with other detection engines
let fusedElements = fusionEngine.integrateVisualElements(
    fusedElements: accessibilityElements,
    visualElements: shapeElements,
    ocrElements: ocrElements,
    windowFrame: windowFrame
)
```

## Performance Monitoring

The system includes comprehensive performance monitoring:

```swift
// Access performance metrics
let report = PerformanceOptimization.generatePerformanceReport()
let cacheHitRate = PerformanceOptimization.calculateCacheHitRate()

// Measure operation timing
let result = PerformanceOptimization.measureTime("my_operation") {
    // Your code here
}
```

## Debug Mode

Enable detailed logging for development:

```swift
let shapeElements = ShapeDetectionOrchestrator.detectShapes(
    in: screenshot,
    windowFrame: windowFrame, 
    visualConfig: true,
    debug: true  // Enable detailed debug output
)
```

Debug output includes:
- Detection timing breakdowns
- Element classification details
- Performance strategy decisions
- Cache hit/miss information
- Shape filtering results

## Best Practices

1. **Use appropriate performance strategy** - Let the system auto-select based on image complexity
2. **Enable caching** - Significant performance benefits for repeated detections
3. **Monitor memory usage** - Enable adaptive thresholds for resource-constrained environments
4. **Configure thresholds** - Adjust based on your specific use case and performance requirements
5. **Use debug mode sparingly** - Only enable for development/troubleshooting

## Limitations

- Pixel-level operations in `ExpensiveDetectors` can cause 13+ second delays
- Detection accuracy depends on image quality and contrast
- Some UI elements may require multiple detection strategies
- Performance varies significantly based on image size and complexity

## Future Improvements

- Platform-specific optimizations (Windows, Linux support)
- Machine learning-based classification improvements  
- Enhanced text input detection for modern web frameworks
- Real-time detection for video streams
- GPU acceleration for pixel-level operations