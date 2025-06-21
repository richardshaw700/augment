import Foundation
import AppKit
import Vision
import CoreImage

// MARK: - Shape Detection Engine

class ShapeDetectionEngine {
    
    // MARK: - Performance Optimization: Image Conversion Caching
    private static var cgImageCache: [String: CGImage] = [:]
    private static var cacheAccessTimes: [String: Date] = [:]
    private static let cacheTimeout: TimeInterval = 1.0 // 1 second cache
    private static let maxCacheSize = 3 // Limit cache size
    
    // MARK: - Multi-Shape Detection Pipeline
    
    func detectUIShapes(in image: NSImage, windowFrame: CGRect, debug: Bool = false) -> [UIShapeCandidate] {
        if debug {
            print("🔍 DEBUG: Starting shape detection on image \(Int(image.size.width))x\(Int(image.size.height))")
        }
        
        guard let cgImage = convertToCGImage(image) else {
            print("❌ Failed to convert NSImage to CGImage for shape detection")
            return []
        }
        
        if debug {
            print("🔍 DEBUG: Successfully converted to CGImage \(cgImage.width)x\(cgImage.height)")
        }
        
        // Step 1: Detect contours (any shape)
        let contours = detectContours(cgImage, imageSize: image.size, windowFrame: windowFrame, debug: debug)
        if debug {
            print("🔍 DEBUG: Contour detection returned \(contours.count) shapes")
        }
        
        // Step 2: Classify shape types
        let classifiedShapes = classifyShapes(contours)
        if debug {
            print("🔍 DEBUG: Shape classification returned \(classifiedShapes.count) classified shapes")
        }
        
        // Step 3: Filter for UI-relevant shapes
        let uiElements = filterForUIElements(classifiedShapes, debug: debug)
        if debug {
            print("🔍 DEBUG: UI filtering returned \(uiElements.count) UI elements")
        }
        
        // Step 4: Assign interaction types
        let allCandidates = assignInteractionTypes(uiElements, debug: debug)
        
        // Step 5: Filter to only high-value interactive elements (buttons and text inputs)
        let interactiveCandidates = filterForInteractiveElements(allCandidates)
        
        if debug {
            print("🔍 DEBUG: Interaction assignment returned \(allCandidates.count) candidates")
            print("🔍 DEBUG: Interactive filtering returned \(interactiveCandidates.count) high-value elements")
        }
        
        print("🔍 Detected \(interactiveCandidates.count) interactive UI elements from \(contours.count) contours")
        
        // Print specialty breakdown for main output
        printSpecialtyBreakdown(interactiveCandidates)
        
        return interactiveCandidates
    }
    
    // MARK: - Contour Detection (Replace Rectangle Detection)
    
    private func detectContours(_ cgImage: CGImage, imageSize: CGSize, windowFrame: CGRect, debug: Bool) -> [ShapeContour] {
        if debug {
            print("🔍 DEBUG: Creating CIImage from CGImage...")
        }
        let ciImage = CIImage(cgImage: cgImage)
        
        // Create contour detection request
        if debug {
            print("🔍 DEBUG: Setting up VNDetectContoursRequest...")
        }
        let request = VNDetectContoursRequest()
        request.contrastAdjustment = 2.0      // Enhance contrast for better detection
        request.maximumImageDimension = 1024   // Balance performance vs accuracy
        
        if debug {
            print("🔍 DEBUG: Creating VNImageRequestHandler...")
        }
        let handler = VNImageRequestHandler(ciImage: ciImage)
        
        do {
            if debug {
                print("🔍 DEBUG: Performing contour detection request...")
            }
            try handler.perform([request])
            
            guard let observations = request.results else {
                if debug {
                    print("🔍 DEBUG: No observations returned from contour detection")
                }
                return fallbackToRectangleDetection(cgImage, imageSize: imageSize, windowFrame: windowFrame, debug: debug)
            }
            
            if debug {
                print("🔍 DEBUG: Got \(observations.count) contour observations from Vision")
            }
            
            // Convert observations to our format
            let shapes = observations.flatMap { observation in
                convertContoursToShapes(observation, imageSize: imageSize, windowFrame: windowFrame, debug: debug)
            }
            
            if debug {
                print("🔍 DEBUG: Converted to \(shapes.count) shape contours")
            }
            
            if shapes.isEmpty {
                if debug {
                    print("🔍 DEBUG: No shapes after conversion, trying rectangle fallback...")
                }
                return fallbackToRectangleDetection(cgImage, imageSize: imageSize, windowFrame: windowFrame, debug: debug)
            }
            
            return shapes
            
        } catch {
            print("❌ Contour detection failed: \(error)")
            
            // Fallback to rectangle detection if contours fail
            if debug {
                print("🔍 DEBUG: Falling back to rectangle detection due to error...")
            }
            return fallbackToRectangleDetection(cgImage, imageSize: imageSize, windowFrame: windowFrame, debug: debug)
        }
    }
    
    private func convertContoursToShapes(_ observation: VNContoursObservation, imageSize: CGSize, windowFrame: CGRect, debug: Bool) -> [ShapeContour] {
        var shapes: [ShapeContour] = []
        var potentialSearchBoxes: [CGRect] = []
        
        if debug {
            print("🔍 DEBUG: Converting contour observation with \(observation.contourCount) contours")
        }
        
        // Process each contour
        for contourIndex in 0..<observation.contourCount {
            if debug {
                print("🔍 DEBUG: Processing contour \(contourIndex + 1)/\(observation.contourCount)")
            }
            do {
                let contour = try observation.contour(at: contourIndex)
                
                // Convert normalized path to window coordinates
                let windowPath = convertNormalizedPath(contour.normalizedPath, imageSize: imageSize, windowFrame: windowFrame)
                let boundingBox = windowPath.boundingBox
                
                // Track potential search boxes (wide rectangles in center area)
                let aspectRatio = boundingBox.width / boundingBox.height
                if aspectRatio > 2.0 && boundingBox.width > 100 && boundingBox.height > 20 {
                    potentialSearchBoxes.append(boundingBox)
                    if debug {
                        print("🔍 DEBUG: POTENTIAL SEARCH BOX - Contour \(contourIndex): \(Int(boundingBox.width))x\(Int(boundingBox.height)) at (\(Int(boundingBox.origin.x)), \(Int(boundingBox.origin.y))) - aspect: \(String(format: "%.1f", aspectRatio))")
                    }
                }
                
                // Filter out tiny or huge shapes
                guard isValidShapeSize(boundingBox, debug: debug) else { 
                    if debug {
                        print("🔍 DEBUG: Contour \(contourIndex) filtered out by size validation")
                    }
                    continue 
                }
                
                let shapeContour = ShapeContour(
                    path: windowPath,
                    boundingBox: boundingBox,
                    pointCount: contour.pointCount,
                    aspectRatio: boundingBox.width / boundingBox.height,
                    area: boundingBox.width * boundingBox.height,
                    confidence: 0.8 // Base confidence for contour detection
                )
                
                shapes.append(shapeContour)
                
            } catch {
                print("⚠️ Failed to process contour \(contourIndex): \(error)")
            }
        }
        
        if debug && !potentialSearchBoxes.isEmpty {
            print("🔍 DEBUG: Found \(potentialSearchBoxes.count) potential search box candidates (before size filtering)")
            for (index, box) in potentialSearchBoxes.enumerated() {
                print("   Candidate \(index + 1): \(Int(box.width))x\(Int(box.height)) at (\(Int(box.origin.x)), \(Int(box.origin.y)))")
            }
        }
        
        return shapes
    }
    
    private func convertNormalizedPath(_ normalizedPath: CGPath, imageSize: CGSize, windowFrame: CGRect) -> CGPath {
        // First convert normalized coordinates (0-1) to image pixel coordinates
        var imageTransform = CGAffineTransform(scaleX: imageSize.width, y: imageSize.height)
        guard let imagePath = normalizedPath.copy(using: &imageTransform) else {
            return normalizedPath
        }
        
        // Then scale from high-res image coordinates to window coordinates
        let scaleX = windowFrame.width / imageSize.width
        let scaleY = windowFrame.height / imageSize.height
        
        // Apply scaling and translation to window coordinates
        var windowTransform = CGAffineTransform(scaleX: scaleX, y: scaleY)
        windowTransform = windowTransform.translatedBy(x: windowFrame.origin.x / scaleX, y: windowFrame.origin.y / scaleY)
        
        return imagePath.copy(using: &windowTransform) ?? imagePath
    }
    
    private func fallbackToRectangleDetection(_ cgImage: CGImage, imageSize: CGSize, windowFrame: CGRect, debug: Bool) -> [ShapeContour] {
        if debug {
            print("🔄 DEBUG: Falling back to rectangle detection...")
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.2
        request.maximumAspectRatio = 20.0
        request.minimumSize = 0.01
        request.maximumObservations = 50
        request.minimumConfidence = 0.3
        
        if debug {
            print("🔍 DEBUG: Rectangle detection parameters:")
            print("   - minimumAspectRatio: \(request.minimumAspectRatio)")
            print("   - maximumAspectRatio: \(request.maximumAspectRatio)")
            print("   - minimumSize: \(request.minimumSize)")
            print("   - minimumConfidence: \(request.minimumConfidence)")
        }
        
        let handler = VNImageRequestHandler(ciImage: ciImage)
        
        do {
            if debug {
                print("🔍 DEBUG: Performing rectangle detection...")
            }
            try handler.perform([request])
            
            guard let observations = request.results else { 
                if debug {
                    print("🔍 DEBUG: No rectangle observations returned")
                }
                return [] 
            }
            
            if debug {
                print("🔍 DEBUG: Got \(observations.count) rectangle observations")
            }
            
            let shapes = observations.map { observation in
                let rect = CGRect(
                    x: observation.boundingBox.origin.x * imageSize.width,
                    y: (1.0 - observation.boundingBox.origin.y - observation.boundingBox.height) * imageSize.height,
                    width: observation.boundingBox.width * imageSize.width,
                    height: observation.boundingBox.height * imageSize.height
                )
                
                if debug {
                    print("🔍 DEBUG: Rectangle found - confidence: \(observation.confidence), size: \(Int(rect.width))x\(Int(rect.height))")
                }
                
                // Create rectangular path
                let path = CGPath(rect: rect, transform: nil)
                
                return ShapeContour(
                    path: path,
                    boundingBox: rect,
                    pointCount: 4,
                    aspectRatio: rect.width / rect.height,
                    area: rect.width * rect.height,
                    confidence: Double(observation.confidence)
                )
            }
            
            if debug {
                print("🔍 DEBUG: Rectangle detection created \(shapes.count) shape contours")
            }
            return shapes
            
        } catch {
            print("❌ Fallback rectangle detection failed: \(error)")
            return []
        }
    }
    
    // MARK: - Shape Classification System
    
    private func classifyShapes(_ contours: [ShapeContour]) -> [ClassifiedShape] {
        return contours.map { contour in
            let type = determineShapeType(contour)
            let uiRole = inferUIRole(type, contour)
            let confidence = calculateShapeConfidence(type, uiRole, contour)
            
            return ClassifiedShape(
                contour: contour,
                type: type,
                uiRole: uiRole,
                confidence: confidence
            )
        }
    }
    
    private func determineShapeType(_ contour: ShapeContour) -> ShapeType {
        let aspectRatio = contour.aspectRatio
        let pointCount = contour.pointCount
        let area = contour.area
        
        // Analyze shape characteristics
        let isSquarish = abs(aspectRatio - 1.0) < 0.3
        let isWide = aspectRatio > 2.0
        let isTall = aspectRatio < 0.5
        
        // Circle detection (compact, roughly square, many points for smooth curves)
        if isSquarish && pointCount > 12 && area > 200 {
            return .circle
        }
        
        // Rectangle detection (4 corners, reasonable aspect ratio)
        if pointCount <= 8 && (isWide || isTall || isSquarish) {
            // Check if it has rounded corners by analyzing curvature
            let curvature = estimateCurvature(contour)
            if curvature > 0.3 {
                return .roundedRectangle
            } else {
                return .rectangle
            }
        }
        
        // Line/border detection (very wide or very tall)
        if aspectRatio > 10.0 || aspectRatio < 0.1 {
            return .line
        }
        
        // Default to irregular for complex shapes
        return .irregular
    }
    
    private func estimateCurvature(_ contour: ShapeContour) -> Double {
        // Simple curvature estimation based on point count vs perimeter
        let boundingPerimeter = 2 * (contour.boundingBox.width + contour.boundingBox.height)
        let complexityRatio = Double(contour.pointCount) / Double(boundingPerimeter)
        return min(1.0, complexityRatio * 100) // Normalize to 0-1
    }
    
    private func inferUIRole(_ type: ShapeType, _ contour: ShapeContour) -> UIRole {
        let area = contour.area
        let aspectRatio = contour.aspectRatio
        let bounds = contour.boundingBox
        
        switch type {
        case .circle:
            if area < 1000 {
                return .icon       // Small circles = icons/icon buttons
            } else if area < 4000 {
                return .button     // Medium circles = buttons
            } else {
                return .decoration // Large circles = decorative
            }
            
        case .rectangle:
            if aspectRatio > 3.0 && bounds.height < 60 {
                return .inputField // Wide, short rectangles = input fields
            } else if area < 10000 && aspectRatio < 3.0 {
                return .button     // Square-ish rectangles = buttons
            } else {
                return .container  // Large rectangles = containers
            }
            
        case .roundedRectangle:
            if area < 8000 {
                return .button     // Rounded rectangles = modern buttons
            } else {
                return .container  // Large rounded = containers
            }
            
        case .line:
            return .decoration     // Lines are usually decorative
            
        case .irregular:
            if area < 2000 {
                return .icon       // Small irregular = icons
            } else {
                return .decoration // Large irregular = decorative
            }
        }
    }
    
    private func calculateShapeConfidence(_ type: ShapeType, _ role: UIRole, _ contour: ShapeContour) -> Double {
        var confidence = contour.confidence
        
        // Boost confidence for likely UI elements
        switch (type, role) {
        case (.circle, .button), (.circle, .icon):
            confidence += 0.2
        case (.rectangle, .inputField):
            confidence += 0.3
        case (.roundedRectangle, .button):
            confidence += 0.25
        default:
            break
        }
        
        // Penalize very small or very large elements
        let area = contour.area
        if area < 100 || area > 50000 {
            confidence -= 0.2
        }
        
        return max(0.1, min(1.0, confidence))
    }
    
    // MARK: - UI Element Filtering
    
    private func filterForUIElements(_ shapes: [ClassifiedShape], debug: Bool = false) -> [ClassifiedShape] {
        let filtered = shapes.filter { shape in
            let bounds = shape.contour.boundingBox
            let aspectRatio = shape.contour.aspectRatio
            
            // DEBUG: Print all shapes being considered for UI filtering
            if debug && bounds.width > 50 && aspectRatio > 1.5 { // Only print potentially interesting shapes
                print("🔍 DEBUG: UI Filter candidate - role: \(shape.uiRole.rawValue), type: \(shape.type.rawValue), confidence: \(String(format: "%.2f", shape.confidence)), size: \(Int(bounds.width))x\(Int(bounds.height))")
            }
            
            // Only keep shapes that are likely UI elements
            switch shape.uiRole {
            case .button, .inputField, .icon:
                return shape.confidence > 0.3
            case .container:
                return shape.confidence > 0.5 && shape.contour.area > 5000
            case .decoration:
                return shape.confidence > 0.6 && isLikelyInteractiveDecoration(shape)
            case .unknown:
                return shape.confidence > 0.7
            }
        }.sorted { $0.confidence > $1.confidence }
        
        if debug {
            print("🔍 DEBUG: UI filtering kept \(filtered.count) out of \(shapes.count) shapes")
        }
        return filtered
    }
    
    private func isLikelyInteractiveDecoration(_ shape: ClassifiedShape) -> Bool {
        // Some decorations might be interactive (logos, etc.)
        let bounds = shape.contour.boundingBox
        
        // Check if in typical interactive positions
        let isInTopCorner = bounds.minY < 100 && (bounds.minX < 100 || bounds.maxX > bounds.width - 100)
        let isReasonableSize = shape.contour.area > 400 && shape.contour.area < 5000
        
        return isInTopCorner && isReasonableSize
    }
    
    // MARK: - Interactive Element Filtering
    
    private func filterForInteractiveElements(_ candidates: [UIShapeCandidate]) -> [UIShapeCandidate] {
        return candidates.filter { candidate in
            // SPECIALIZED DETECTORS: Only keep text inputs and buttons
            switch candidate.interactionType {
            case .textInput:
                return true  // TEXT INPUT SPECIALTY: Always keep text inputs
            case .button, .iconButton, .closeButton:
                return true  // BUTTON SPECIALTY: Keep all button types
            case .dropdown:
                return false // Skip dropdowns for now - not in our specialties
            case .menuButton:
                return false // Skip menu buttons for now - not in our specialties
            case .slider, .toggle, .tab:
                return false // Skip other elements for now - not in our specialties
            case .unknown:
                return false // Skip unknown elements
            }
        }
    }
    
    // MARK: - Interaction Type Assignment
    
    private func assignInteractionTypes(_ shapes: [ClassifiedShape], debug: Bool = false) -> [UIShapeCandidate] {
        return shapes.map { shape in
            let interactionType = determineInteraction(shape, debug: debug)
            
            return UIShapeCandidate(
                contour: shape.contour.path,
                boundingBox: shape.contour.boundingBox,
                type: shape.type,
                uiRole: shape.uiRole,
                interactionType: interactionType,
                confidence: shape.confidence,
                area: shape.contour.area,
                aspectRatio: shape.contour.aspectRatio,
                corners: extractKeyCorners(shape.contour),
                curvature: estimateCurvature(shape.contour)
            )
        }
    }
    
    private func determineInteraction(_ shape: ClassifiedShape, debug: Bool = false) -> InteractionType {
        let bounds = shape.contour.boundingBox
        let type = shape.type
        let role = shape.uiRole
        let area = shape.contour.area
        
        // Specific interaction type based on position and characteristics
        
        // Enhanced text input detection (optimized for search boxes and text fields)
        if isTextInputCandidate(shape, debug: debug) {
            return .textInput
        }
        
        // EDGE-DETECTED TEXT INPUT: Check if this might be a text input from edge detection
        if isEdgeDetectedTextInput(shape, debug: debug) {
            return .textInput
        }
        
        // FINE-TUNED BUTTON DETECTION for real interactive elements only
        
        // 1. Close/window control buttons (small circles in top-left corner)
        if type == .circle && area >= 100 && area <= 800 && isInTopCorner(bounds) {
            return .closeButton
        }
        
        // 2. Main action buttons (reasonable size, typically rectangular-ish)
        if role == .button && area >= 1000 && area <= 10000 {
            return .button
        }
        
        // 3. Icon buttons (medium-sized circles or squares, not tiny artifacts)
        if (type == .circle || type == .irregular) && 
           area >= 600 && area <= 3000 && // Increased minimum to filter false positives
           bounds.width >= 20 && bounds.height >= 20 && // Increased minimum clickable size
           role == .icon {
            
            // FILTER OUT: Small circular false positives (common artifacts)
            if type == .circle && area < 1500 && bounds.width < 40 && bounds.height < 40 {
                return .unknown // Filter out small circles
            }
            
            return .iconButton
        }
        
        // Dropdown detection (rectangle with specific aspect ratio)
        if type == .rectangle && shape.contour.aspectRatio > 2.0 && shape.contour.aspectRatio < 5.0 {
            return .dropdown
        }
        
        return .unknown
    }
    
    private func extractKeyCorners(_ contour: ShapeContour) -> [CGPoint] {
        let bounds = contour.boundingBox
        
        // For now, return bounding box corners
        // TODO: Could be enhanced to find actual path corners
        return [
            CGPoint(x: bounds.minX, y: bounds.minY), // Top-left
            CGPoint(x: bounds.maxX, y: bounds.minY), // Top-right
            CGPoint(x: bounds.maxX, y: bounds.maxY), // Bottom-right
            CGPoint(x: bounds.minX, y: bounds.maxY)  // Bottom-left
        ]
    }
    

    
    // MARK: - Helper Methods
    
    private func isValidShapeSize(_ bounds: CGRect, debug: Bool) -> Bool {
        let area = bounds.width * bounds.height
        let isValid = area > 40 && area < 100000 && // Reasonable size range (40px = small button height)
                     bounds.width > 5 && bounds.height > 5 && // Minimum dimensions
                     bounds.width < 2000 && bounds.height < 2000 // Maximum dimensions
        
        if !isValid && debug {
            print("🔍 DEBUG: Shape filtered out - size: \(Int(bounds.width))x\(Int(bounds.height)), area: \(Int(area))")
        }
        
        return isValid
    }
    
    private func isInTopCorner(_ bounds: CGRect) -> Bool {
        return bounds.minY < 100 && (bounds.minX < 100 || bounds.maxX > bounds.width - 100)
    }
    
    private func isInTopArea(_ bounds: CGRect) -> Bool {
        return bounds.minY < 150
    }
    
    private func isTextInputCandidate(_ shape: ClassifiedShape, debug: Bool = false) -> Bool {
        let bounds = shape.contour.boundingBox
        let type = shape.type
        let aspectRatio = shape.contour.aspectRatio
        let area = shape.contour.area
        
        // DEBUG: Print all potential candidates for analysis
        if debug {
            print("🔍 DEBUG: Analyzing potential text input - type: \(type.rawValue), aspect: \(String(format: "%.1f", aspectRatio)), size: \(Int(bounds.width))x\(Int(bounds.height)), area: \(Int(area)), center: (\(Int(bounds.midX)), \(Int(bounds.midY)))")
        }
        
        // Note: Google search box may be too subtle for contour detection
        // but accessibility system typically handles it well
        
        // ENHANCED TEXT INPUT DETECTION for modern search boxes
        
        // 1. Classic wide rectangles (traditional input fields)
        if type == .rectangle && aspectRatio > 3.0 && bounds.height >= 20 && bounds.height <= 60 {
            return true
        }
        
        // 2. Rounded rectangles (modern search boxes like Google)
        if type == .roundedRectangle && aspectRatio > 2.5 && bounds.height >= 25 && bounds.height <= 80 {
            return true
        }
        
        // 3. Large irregular shapes that are wide and in center area (Google-style search)
        if type == .irregular && 
           aspectRatio > 2.0 && // More flexible aspect ratio
           bounds.height >= 30 && bounds.height <= 120 && // Larger height range for modern search boxes
           area >= 5000 && // Minimum size for main search boxes
           isInCenterArea(bounds) { // Must be in center area of screen
            return true
        }
        
        // 4. Medium irregular shapes that are very wide (alternative search box styles)
        if type == .irregular && 
           aspectRatio > 4.0 && // Very wide
           bounds.height >= 20 && bounds.height <= 80 && 
           area >= 2000 {
            return true
        }
        
        return false
    }
    
    private func isInCenterArea(_ bounds: CGRect) -> Bool {
        // Check if element is in the center portion of the screen (for main search boxes)
        let centerY = bounds.midY
        let screenHeight: CGFloat = 869 // From window frame
        
        // Consider center area as middle 60% of screen height
        let centerStart = screenHeight * 0.2
        let centerEnd = screenHeight * 0.8
        
        return centerY >= centerStart && centerY <= centerEnd
    }
    
    private func isEdgeDetectedTextInput(_ shape: ClassifiedShape, debug: Bool = false) -> Bool {
        let bounds = shape.contour.boundingBox
        let type = shape.type
        let aspectRatio = shape.contour.aspectRatio
        let width = bounds.width
        let height = bounds.height
        
        // EdgeDetectionEngine-inspired criteria for text inputs
        let minWidth: CGFloat = 50
        let maxWidth: CGFloat = 800
        let minHeight: CGFloat = 15
        let maxHeight: CGFloat = 100
        let minAspectRatio: CGFloat = 1.5  // At least 1.5:1 width to height
        let maxAspectRatio: CGFloat = 20.0 // But not extremely wide
        
        // Basic size and aspect ratio check
        guard width >= minWidth && width <= maxWidth &&
              height >= minHeight && height <= maxHeight &&
              aspectRatio >= minAspectRatio && aspectRatio <= maxAspectRatio else {
            return false
        }
        
        // Prefer rectangles and rounded rectangles for text inputs
        guard type == .rectangle || type == .roundedRectangle || type == .irregular else {
            return false
        }
        
        // Debug output for edge-detected candidates
        if debug {
            print("🔍 DEBUG: Edge-detected text input candidate - type: \(type.rawValue), aspect: \(String(format: "%.1f", aspectRatio)), size: \(Int(width))x\(Int(height))")
        }
        
        // Additional criteria for high-confidence detection
        if aspectRatio > 4.0 && width > 200 && height > 25 && height < 80 {
            if debug {
                print("✅ DEBUG: High-confidence text input detected!")
            }
            return true
        }
        
        return false
    }
    
    private func convertToCGImage(_ nsImage: NSImage) -> CGImage? {
        // Performance optimization: Cache CGImage conversion with image hash
        let imageHash = generateImageHash(nsImage)
        let now = Date()
        
        // Check cache first
        if let cachedImage = Self.cgImageCache[imageHash],
           let cacheTime = Self.cacheAccessTimes[imageHash],
           now.timeIntervalSince(cacheTime) < Self.cacheTimeout {
            Self.cacheAccessTimes[imageHash] = now // Update access time
            return cachedImage
        }
        
        // Convert image
        guard let imageData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: imageData),
              let cgImage = bitmap.cgImage else {
            return nil
        }
        
        // Cache management: Remove old entries if cache is full
        if Self.cgImageCache.count >= Self.maxCacheSize {
            cleanupImageCache()
        }
        
        // Cache the result
        Self.cgImageCache[imageHash] = cgImage
        Self.cacheAccessTimes[imageHash] = now
        
        return cgImage
    }
    
    private func generateImageHash(_ image: NSImage) -> String {
        // Fast hash based on image properties
        let size = image.size
        let timestamp = Date().timeIntervalSince1970
        return "\(Int(size.width))x\(Int(size.height))_\(Int(timestamp * 1000) % 10000)"
    }
    
    private func cleanupImageCache() {
        let now = Date()
        let expiredKeys = Self.cacheAccessTimes.compactMap { (key, time) in
            now.timeIntervalSince(time) > Self.cacheTimeout ? key : nil
        }
        
        for key in expiredKeys {
            Self.cgImageCache.removeValue(forKey: key)
            Self.cacheAccessTimes.removeValue(forKey: key)
        }
        
        // If still full, remove oldest entries
        if Self.cgImageCache.count >= Self.maxCacheSize {
            let sortedByTime = Self.cacheAccessTimes.sorted { $0.value < $1.value }
            let toRemove = sortedByTime.prefix(Self.cgImageCache.count - Self.maxCacheSize + 1)
            
            for (key, _) in toRemove {
                Self.cgImageCache.removeValue(forKey: key)
                Self.cacheAccessTimes.removeValue(forKey: key)
            }
        }
    }
    

    
    private func printSpecialtyBreakdown(_ candidates: [UIShapeCandidate]) {
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
    
    private func printShapeBreakdown(_ candidates: [UIShapeCandidate]) {
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
    
    private func isInteractiveType(_ type: InteractionType) -> Bool {
        switch type {
        case .textInput, .button, .iconButton, .closeButton, .menuButton, .slider, .toggle, .dropdown, .tab:
            return true
        case .unknown:
            return false
        }
    }
}

// MARK: - Data Models

struct ShapeContour {
    let path: CGPath
    let boundingBox: CGRect
    let pointCount: Int
    let aspectRatio: CGFloat
    let area: CGFloat
    let confidence: Double
}

struct ClassifiedShape {
    let contour: ShapeContour
    let type: ShapeType
    let uiRole: UIRole
    let confidence: Double
}

struct UIShapeCandidate {
    let contour: CGPath
    let boundingBox: CGRect
    let type: ShapeType
    let uiRole: UIRole
    let interactionType: InteractionType
    let confidence: Double
    let area: CGFloat
    let aspectRatio: CGFloat
    let corners: [CGPoint]
    let curvature: Double
}

// MARK: - Enums

enum ShapeType: String, CaseIterable {
    case circle = "circle"
    case rectangle = "rectangle"
    case roundedRectangle = "rounded_rectangle"
    case irregular = "irregular"
    case line = "line"
}

enum UIRole: String, CaseIterable {
    case button = "button"
    case icon = "icon"
    case inputField = "input_field"
    case decoration = "decoration"
    case container = "container"
    case unknown = "unknown"
}

enum InteractionType: String, CaseIterable {
    case textInput = "text_input"
    case button = "button"
    case iconButton = "icon_button"
    case closeButton = "close_button"
    case menuButton = "menu_button"
    case slider = "slider"
    case toggle = "toggle"
    case dropdown = "dropdown"
    case tab = "tab"
    case unknown = "unknown"
}