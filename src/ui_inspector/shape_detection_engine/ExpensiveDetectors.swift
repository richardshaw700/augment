import Foundation
import AppKit
import CoreGraphics

// MARK: - Expensive Detectors (Pixel-Level Analysis)
//
// WARNING: These methods perform expensive pixel-level operations
// and can cause 13+ second delays. Use sparingly or with heavy optimization.

class ExpensiveDetectors {
    
    // MARK: - Full Visual Detection (Comprehensive but Slow)
    
    static func detectSpecializedVisualElementsFull(
        in image: CGImage, 
        windowFrame: CGRect, 
        debug: Bool
    ) -> [ClassifiedShape] {
        var visualElements: [ClassifiedShape] = []
        
        if debug {
            print("🔍 DEBUG: Starting FULL visual elements detection (enhanced window controls)")
        }
        
        // Universal window controls detection with color verification
        let windowControls = detectWindowControlsWithColor(in: image, windowFrame: windowFrame, debug: debug)
        visualElements.append(contentsOf: windowControls)
        
        if debug {
            print("🔍 DEBUG: Full visual detection complete:")
            print("   Window controls: \(windowControls.count)")
            print("   Total: \(visualElements.count)")
        }
        
        return visualElements
    }
    
    // MARK: - Window Controls with Color Verification
    
    static func detectWindowControlsWithColor(
        in image: CGImage, 
        windowFrame: CGRect, 
        debug: Bool
    ) -> [ClassifiedShape] {
        if debug {
            print("🔍 DEBUG: Enhanced window controls detection with color verification")
        }
        
        var windowControls: [ClassifiedShape] = []
        let startTime = Date()
        
        // Universal window control detection (relative to window size)
        let controlSize = min(12, Int(windowFrame.width * 0.02)) // 2% of window width or 12px max
        let controlSpacing = Int(Double(controlSize) * 1.5) // 1.5x control size spacing
        let topMargin = Int(windowFrame.height * 0.03) // 3% from top or reasonable default
        let leftMargin = Int(windowFrame.width * 0.03) // 3% from left
        
        let controlPositions = [
            (x: leftMargin, y: topMargin, name: "close", expectedColor: (r: CGFloat(0.9), g: CGFloat(0.3), b: CGFloat(0.3))),
            (x: leftMargin + controlSpacing, y: topMargin, name: "minimize", expectedColor: (r: CGFloat(0.9), g: CGFloat(0.7), b: CGFloat(0.2))),
            (x: leftMargin + (controlSpacing * 2), y: topMargin, name: "zoom", expectedColor: (r: CGFloat(0.2), g: CGFloat(0.7), b: CGFloat(0.2)))
        ]
        
        for (x, y, name, expectedColor) in controlPositions {
            // Quick bounds check using dynamic control size
            let halfSize = controlSize / 2
            guard x + halfSize < image.width && y + halfSize < image.height && x - halfSize >= 0 && y - halfSize >= 0 else {
                continue
            }
            
            // Check if the pixel color matches expected window control color
            guard let actualColor = getPixelColor(image: image, x: x, y: y) else {
                continue
            }
            
            let colorDistance = calculateColorDistance(actualColor, expectedColor)
            
            // If color matches reasonably well, it's likely a window control
            if colorDistance < 0.3 { // Threshold for color matching
                let bounds = CGRect(x: x - halfSize, y: y - halfSize, width: controlSize, height: controlSize)
                let contour = ShapeContour(
                    path: CGPath(ellipseIn: bounds, transform: nil),
                    boundingBox: bounds,
                    pointCount: 8,
                    aspectRatio: 1.0,
                    area: CGFloat(Double.pi * Double(halfSize * halfSize)), // Dynamic radius
                    confidence: 0.8 // Higher confidence due to color verification
                )
                
                let classifiedShape = ClassifiedShape(
                    contour: contour,
                    type: .circle,
                    uiRole: .button,
                    confidence: 0.8
                )
                
                windowControls.append(classifiedShape)
                
                if debug {
                    print("🔍 DEBUG: Found \(name) window control at (\(x), \(y)) - color match: \(String(format: "%.3f", 1.0 - colorDistance))")
                }
            } else if debug {
                print("🔍 DEBUG: Skipped \(name) control at (\(x), \(y)) - color mismatch: \(String(format: "%.3f", colorDistance))")
            }
        }
        
        let detectionTime = Date().timeIntervalSince(startTime)
        if debug {
            print("🔍 DEBUG: Window control detection took \(String(format: "%.3f", detectionTime))s, found \(windowControls.count) controls")
        }
        
        return windowControls
    }
    
    // MARK: - Universal Pixel Analysis Utilities
    
    // MARK: - Universal Edge Detection
    
    static func hasColorVariation(image: CGImage, x: Int, y: Int) -> Bool {
        // Real pixel-level edge detection - this is expensive!
        guard x > 0 && y > 0 && x < image.width - 1 && y < image.height - 1 else {
            return false
        }
        
        // Get actual pixel colors (expensive operation)
        guard let centerColor = getPixelColor(image: image, x: x, y: y),
              let leftColor = getPixelColor(image: image, x: x-1, y: y),
              let rightColor = getPixelColor(image: image, x: x+1, y: y),
              let topColor = getPixelColor(image: image, x: x, y: y-1),
              let bottomColor = getPixelColor(image: image, x: x, y: y+1) else {
            return false
        }
        
        // Calculate color variance (expensive computation)
        let variance = calculateColorVariance(center: centerColor, neighbors: [leftColor, rightColor, topColor, bottomColor])
        
        // Threshold for edge detection
        return variance > 0.1
    }
    
    // MARK: - Universal Pixel Operations
    
    static func getPixelColor(image: CGImage, x: Int, y: Int) -> (r: CGFloat, g: CGFloat, b: CGFloat)? {
        // This is the expensive pixel extraction operation!
        guard let dataProvider = image.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else {
            return nil
        }
        
        let bytesPerPixel = 4
        let bytesPerRow = image.bytesPerRow
        let pixelOffset = (y * bytesPerRow) + (x * bytesPerPixel)
        
        guard pixelOffset + 3 < CFDataGetLength(data) else {
            return nil
        }
        
        let r = CGFloat(bytes[pixelOffset + 0]) / 255.0
        let g = CGFloat(bytes[pixelOffset + 1]) / 255.0  
        let b = CGFloat(bytes[pixelOffset + 2]) / 255.0
        
        return (r: r, g: g, b: b)
    }
    
    // MARK: - Universal Color Analysis
    
    static func calculateColorVariance(
        center: (r: CGFloat, g: CGFloat, b: CGFloat), 
        neighbors: [(r: CGFloat, g: CGFloat, b: CGFloat)]
    ) -> CGFloat {
        // Expensive statistical calculation!
        var totalVariance: CGFloat = 0
        
        for neighbor in neighbors {
            let rDiff = abs(center.r - neighbor.r)
            let gDiff = abs(center.g - neighbor.g)
            let bDiff = abs(center.b - neighbor.b)
            
            // RGB distance calculation
            let distance = sqrt(rDiff * rDiff + gDiff * gDiff + bDiff * bDiff)
            totalVariance += distance
        }
        
        return totalVariance / CGFloat(neighbors.count)
    }
    
    static func calculateColorDistance(
        _ color1: (r: CGFloat, g: CGFloat, b: CGFloat), 
        _ color2: (r: CGFloat, g: CGFloat, b: CGFloat)
    ) -> CGFloat {
        // Expensive RGB distance calculation!
        let rDiff = color1.r - color2.r
        let gDiff = color1.g - color2.g
        let bDiff = color1.b - color2.b
        
        return sqrt(rDiff * rDiff + gDiff * gDiff + bDiff * bDiff)
    }
}