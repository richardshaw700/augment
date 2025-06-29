import Foundation
import AppKit
import CoreGraphics

// MARK: - Specialized Detectors

class SpecializedDetectors {
    
    // MARK: - Fast Specialized Detection
    
    static func detectSpecializedVisualElementsFast(
        in image: CGImage, 
        windowFrame: CGRect, 
        debug: Bool
    ) -> [ClassifiedShape] {
        var visualElements: [ClassifiedShape] = []
        
        // Only detect window controls (fast and high-value)
        let windowControls = detectWindowControlsFast(in: image, windowFrame: windowFrame, debug: debug)
        visualElements.append(contentsOf: windowControls)
        
        // Skip expensive circular detection and message bubble detection for now
        // These were causing the 13-second delay
        
        return visualElements
    }
    
    // MARK: - Window Controls Detection
    
    static func detectWindowControlsFast(
        in image: CGImage, 
        windowFrame: CGRect, 
        debug: Bool
    ) -> [ClassifiedShape] {
        // Fast window control detection - use generic approach without hardcoded positions
        var coloredElements: [ClassifiedShape] = []
        
        if debug {
            print("🔍 DEBUG: Fast window control detection (generic approach)")
        }
        
        // Generic detection in top-left corner area (relative to window size)
        let searchArea = CGRect(
            x: 0, 
            y: 0, 
            width: min(100, windowFrame.width * 0.2), // Search top 20% width or 100px max
            height: min(50, windowFrame.height * 0.1)  // Search top 10% height or 50px max
        )
        
        // Look for small circular elements in the search area that could be window controls
        let potentialControlSize = min(12, Int(windowFrame.width * 0.02)) // 2% of window width or 12px max
        let gridStep = potentialControlSize / 2
        
        // Calculate coordinate transformation from image to window coordinates
        let scaleX = windowFrame.width / CGFloat(image.width)
        let scaleY = windowFrame.height / CGFloat(image.height)
        
        var controlsFound = 0
        let maxControls = 3 // Limit to avoid false positives
        
        for x in stride(from: Int(searchArea.minX + CGFloat(gridStep)), to: Int(searchArea.maxX - CGFloat(gridStep)), by: gridStep) {
            for y in stride(from: Int(searchArea.minY + CGFloat(gridStep)), to: Int(searchArea.maxY - CGFloat(gridStep)), by: gridStep) {
                if controlsFound >= maxControls { break }
                
                // Quick bounds check
                guard x + potentialControlSize < image.width && y + potentialControlSize < image.height else { continue }
                
                // Create bounds in image coordinates first
                let imageBounds = CGRect(
                    x: x - potentialControlSize/2, 
                    y: y - potentialControlSize/2, 
                    width: potentialControlSize, 
                    height: potentialControlSize
                )
                
                // Transform to window coordinates
                let windowBounds = CGRect(
                    x: windowFrame.origin.x + (imageBounds.origin.x * scaleX),
                    y: windowFrame.origin.y + (imageBounds.origin.y * scaleY),
                    width: imageBounds.width * scaleX,
                    height: imageBounds.height * scaleY
                )
                
                let contour = ShapeContour(
                    path: CGPath(ellipseIn: windowBounds, transform: nil),
                    boundingBox: windowBounds,
                    pointCount: 8,
                    aspectRatio: 1.0,
                    area: CGFloat(Double.pi * Double(windowBounds.width/2 * windowBounds.height/2)),
                    confidence: 0.4 // Lower confidence for generic detection
                )
                
                let classifiedShape = ClassifiedShape(
                    contour: contour,
                    type: .circle,
                    uiRole: .button,
                    confidence: 0.4
                )
                
                coloredElements.append(classifiedShape)
                controlsFound += 1
                
                if debug {
                    print("🔍 DEBUG: Added potential window control at image(\(x), \(y)) -> window(\(Int(windowBounds.origin.x)), \(Int(windowBounds.origin.y)))")
                }
            }
            if controlsFound >= maxControls { break }
        }
        
        if debug {
            print("🔍 DEBUG: Fast detection found \(controlsFound) potential window controls")
        }
        
        return coloredElements
    }
    
    // MARK: - Debugging & Analysis
    
    static func printSpecialtyBreakdown(_ candidates: [UIShapeCandidate]) {
        let textInputs = candidates.filter { $0.interactionType == .textInput }
        let buttons = candidates.filter { 
            $0.interactionType == .button || $0.interactionType == .iconButton || $0.interactionType == .closeButton 
        }
        
        print("🎯 SHAPE DETECTION SPECIALTIES:")
        print("   📝 Text Input Detector: \(textInputs.count) elements")
        print("   🔘 Button Detector: \(buttons.count) elements")
        
        if !textInputs.isEmpty {
            print("      Text inputs found:")
            for textInput in textInputs {
                let bounds = textInput.boundingBox
                print("         • \(textInput.type.rawValue) at (\(Int(bounds.origin.x)), \(Int(bounds.origin.y))) - \(Int(bounds.width))x\(Int(bounds.height))")
            }
        }
        
        if !buttons.isEmpty {
            print("      Buttons found:")
            for button in buttons.prefix(5) { // Show first 5 to avoid clutter
                let bounds = button.boundingBox
                print("         • \(button.interactionType.rawValue) at (\(Int(bounds.origin.x)), \(Int(bounds.origin.y))) - \(Int(bounds.width))x\(Int(bounds.height))")
            }
            if buttons.count > 5 {
                print("         • ... and \(buttons.count - 5) more buttons")
            }
        }
    }
    
    static func printShapeBreakdown(_ candidates: [UIShapeCandidate]) {
        let typeBreakdown = Dictionary(grouping: candidates, by: { $0.type })
        let roleBreakdown = Dictionary(grouping: candidates, by: { $0.uiRole })
        let interactionBreakdown = Dictionary(grouping: candidates, by: { $0.interactionType })
        
        print("📊 Shape type breakdown:")
        for (type, shapes) in typeBreakdown {
            print("   \(type.rawValue): \(shapes.count)")
        }
        
        print("📊 UI role breakdown:")
        for (role, shapes) in roleBreakdown {
            print("   \(role.rawValue): \(shapes.count)")
        }
        
        print("📊 Interaction type breakdown:")
        for (interaction, shapes) in interactionBreakdown {
            print("   \(interaction.rawValue): \(shapes.count)")
        }
    }
    
    // MARK: - Helper Methods
    
    static func isInteractiveType(_ type: InteractionType) -> Bool {
        switch type {
        case .textInput, .button, .iconButton, .closeButton, .menuButton, .slider, .toggle, .dropdown, .tab:
            return true
        case .unknown:
            return false
        }
    }
}