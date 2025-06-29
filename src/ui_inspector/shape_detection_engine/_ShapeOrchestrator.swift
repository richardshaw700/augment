import Foundation
import AppKit
import CoreGraphics

// MARK: - Shape Detection Orchestrator
//
// Clean orchestration that reads like pseudocode - coordinates all shape detection components

class ShapeOrchestrator {
    
    // MARK: - Main Detection Workflow
    
    static func detectShapes(
        in image: CGImage,
        windowFrame: CGRect,
        visualConfig: Bool,
        debug: Bool
    ) -> [UIShapeCandidate] {
        
        if debug {
            print("🔍 SHAPE DETECTION ORCHESTRATOR")
            print("==============================")
            print("   Image: \(image.width)x\(image.height)")
            print("   Window: \(Int(windowFrame.width))x\(Int(windowFrame.height))")
            print("   Visual config: \(visualConfig ? "FULL" : "FAST")")
        }
        
        let overallStartTime = Date()
        
        // STEP 1: Performance optimization and caching check
        let imageHash = PerformanceOptimization.generateImageHash(image)
        if let cachedResults = PerformanceOptimization.getCachedDetection(for: imageHash) {
            if debug {
                print("✅ Using cached detection results")
            }
            return InteractionDetection.assignInteractionTypes(cachedResults, debug: debug)
        }
        
        // STEP 2: Determine detection strategy based on performance constraints
        let strategy = PerformanceOptimization.getOptimalDetectionStrategy(
            imageSize: CGSize(width: image.width, height: image.height),
            debugEnabled: debug
        )
        
        if debug {
            print("🎯 Detection Strategy: \(strategy)")
        }
        
        // STEP 3: Contour detection using Vision framework
        let contours = PerformanceOptimization.measureTime("contour_detection") {
            ContourDetection.detectContours(image, imageSize: CGSize(width: image.width, height: image.height), windowFrame: windowFrame, debug: debug)
        }
        
        if debug {
            print("📐 Found \(contours.count) raw contours")
        }
        
        // STEP 4: Pre-filter contours for performance
        let optimizedContours = PerformanceOptimization.optimizeContourDetection(contours)
        
        if debug {
            print("⚡ Optimized to \(optimizedContours.count) contours")
        }
        
        // STEP 5: Shape classification and UI role inference
        let classifiedShapes = PerformanceOptimization.measureTime("shape_classification") {
            ShapeClassification.classifyShapes(optimizedContours)
        }
        
        // STEP 6: Filter for meaningful UI elements
        let uiShapes = ShapeClassification.filterForUIElements(classifiedShapes, debug: debug)
        
        // STEP 7: Add specialized visual elements based on configuration and strategy
        var allShapes = uiShapes
        
        switch strategy {
        case .fast:
            // Fast strategy: only window controls
            let fastShapes = SpecializedDetectors.detectSpecializedVisualElementsFast(in: image, windowFrame: windowFrame, debug: debug)
            allShapes.append(contentsOf: fastShapes)
            
        case .balanced:
            // Balanced strategy: fast detection + some expensive detection
            let fastShapes = SpecializedDetectors.detectSpecializedVisualElementsFast(in: image, windowFrame: windowFrame, debug: debug)
            allShapes.append(contentsOf: fastShapes)
            
            // Add limited expensive detection if we haven't found too many elements
            if allShapes.count < 50 {
                let limitedExpensiveShapes = getBalancedExpensiveDetection(image: image, windowFrame: windowFrame, debug: debug)
                allShapes.append(contentsOf: limitedExpensiveShapes)
            }
            
        case .full:
            // Full strategy: all detection methods (if performance allows)
            if visualConfig && PerformanceOptimization.shouldUseExpensiveDetection(CGSize(width: image.width, height: image.height), elementCount: allShapes.count) {
                
                let expensiveShapes = PerformanceOptimization.measureTime("expensive_detection") {
                    ExpensiveDetectors.detectSpecializedVisualElementsFull(in: image, windowFrame: windowFrame, debug: debug)
                }
                allShapes.append(contentsOf: expensiveShapes)
                
                if debug {
                    print("💎 Added \(expensiveShapes.count) expensive detection results")
                }
            } else {
                // Fall back to fast detection
                let fastShapes = SpecializedDetectors.detectSpecializedVisualElementsFast(in: image, windowFrame: windowFrame, debug: debug)
                allShapes.append(contentsOf: fastShapes)
                
                if debug {
                    print("⚡ Fell back to fast detection")
                }
            }
        }
        
        // STEP 8: Interaction type assignment and filtering
        let shapeCandidates = InteractionDetection.assignInteractionTypes(allShapes, debug: debug)
        let interactiveElements = InteractionDetection.filterForInteractiveElements(shapeCandidates)
        
        // STEP 9: Early termination check
        let elapsedTime = Date().timeIntervalSince(overallStartTime)
        if PerformanceOptimization.shouldTerminateEarly(shapesFound: interactiveElements.count, timeElapsed: elapsedTime) {
            if debug {
                print("⏹️ Early termination: \(interactiveElements.count) shapes in \(String(format: "%.3f", elapsedTime))s")
            }
        }
        
        // STEP 10: Cache results for future use
        PerformanceOptimization.cacheDetection(allShapes, for: imageHash)
        
        // STEP 11: Performance reporting
        PerformanceOptimization.recordPerformanceMetric("total_shape_detection", time: elapsedTime)
        
        if debug {
            print("🎯 SHAPE DETECTION COMPLETE")
            print("   Total shapes: \(allShapes.count)")
            print("   Interactive elements: \(interactiveElements.count)")
            print("   Detection time: \(String(format: "%.3f", elapsedTime))s")
            print("   Strategy used: \(strategy)")
            
            // Print performance report
            print("\n" + PerformanceOptimization.generatePerformanceReport())
        }
        
        return interactiveElements
    }
    
    // MARK: - Helper Methods
    
    private static func getBalancedExpensiveDetection(
        image: CGImage,
        windowFrame: CGRect,
        debug: Bool
    ) -> [ClassifiedShape] {
        // Balanced approach: only run window controls detection (the only universal expensive detection)
        let windowControls = ExpensiveDetectors.detectWindowControlsWithColor(in: image, windowFrame: windowFrame, debug: debug)
        return windowControls
    }
}

// MARK: - Orchestrator Extensions for Debugging

extension ShapeOrchestrator {
    
    static func printDetailedAnalysis(_ candidates: [UIShapeCandidate]) {
        print("\n🔍 DETAILED SHAPE ANALYSIS")
        print("==========================")
        
        SpecializedDetectors.printSpecialtyBreakdown(candidates)
        SpecializedDetectors.printShapeBreakdown(candidates)
        
        // Print top confidence shapes
        let topShapes = candidates.sorted { $0.confidence > $1.confidence }.prefix(10)
        print("\n🏆 TOP CONFIDENCE SHAPES:")
        for (index, shape) in topShapes.enumerated() {
            let bounds = shape.boundingBox
            print("   \(index + 1). \(shape.interactionType.rawValue) - \(shape.type.rawValue) at (\(Int(bounds.origin.x)), \(Int(bounds.origin.y))) confidence: \(String(format: "%.2f", shape.confidence))")
        }
    }
}