import Foundation
import AppKit

// MARK: - Coordinate System

class CoordinateSystem: CoordinateMapping {
    private let windowFrame: CGRect
    private let gridMapper: AdaptiveDensityMapper
    
    init(windowFrame: CGRect) {
        self.windowFrame = windowFrame
        self.gridMapper = AdaptiveDensityMapper(windowFrame: windowFrame)
    }
    
    // MARK: - Coordinate Normalization
    
    func normalize(_ point: CGPoint) -> NormalizedPoint {
        // Convert absolute screen coordinates to window-relative coordinates
        let relativeX = point.x - windowFrame.origin.x
        let relativeY = point.y - windowFrame.origin.y
        
        // Normalize to 0.0-1.0 range within the window bounds
        let normalizedX = Double(relativeX / windowFrame.width)
        let normalizedY = Double(relativeY / windowFrame.height)
        
        return NormalizedPoint(normalizedX, normalizedY)
    }
    
    func toGrid(_ point: NormalizedPoint) -> AdaptiveGridPosition {
        // Convert normalized coordinates to grid position
        let colIndex = min(39, max(0, Int(point.x * Double(UniversalGrid.COLUMNS))))
        let rowIndex = min(49, max(0, Int(point.y * Double(UniversalGrid.ROWS))))
        
        let columnString = AdaptiveGridPosition.columnString(from: colIndex)
        let row = rowIndex + 1
        
        return AdaptiveGridPosition(columnString, row)
    }
    
    // MARK: - Grid Mapping
    
    func gridPosition(for point: CGPoint) -> AdaptiveGridPosition {
        let normalized = normalize(point)
        return toGrid(normalized)
    }
    
    func pixelPosition(for gridPos: AdaptiveGridPosition) -> CGPoint {
        let x = windowFrame.origin.x + (CGFloat(gridPos.columnIndex) * gridMapper.cellWidth) + (gridMapper.cellWidth / 2)
        let y = windowFrame.origin.y + (CGFloat(gridPos.rowIndex) * gridMapper.cellHeight) + (gridMapper.cellHeight / 2)
        
        return CGPoint(x: x, y: y)
    }
    
    func cellBounds(for gridPos: AdaptiveGridPosition) -> CGRect {
        // Use the same coordinate system as toGrid() - consistent with normalized approach
        let cellWidth = windowFrame.width / CGFloat(UniversalGrid.COLUMNS)
        let cellHeight = windowFrame.height / CGFloat(UniversalGrid.ROWS)
        
        let x = windowFrame.origin.x + (CGFloat(gridPos.columnIndex) * cellWidth)
        let y = windowFrame.origin.y + (CGFloat(gridPos.rowIndex) * cellHeight)
        
        return CGRect(x: x, y: y, width: cellWidth, height: cellHeight)
    }
    
    // MARK: - Coordinate Validation
    
    func isValidCoordinate(_ point: CGPoint) -> Bool {
        return point.x >= windowFrame.minX &&
               point.x <= windowFrame.maxX &&
               point.y >= windowFrame.minY &&
               point.y <= windowFrame.maxY
    }
    
    func clampToWindow(_ point: CGPoint) -> CGPoint {
        return CGPoint(
            x: max(windowFrame.minX, min(windowFrame.maxX, point.x)),
            y: max(windowFrame.minY, min(windowFrame.maxY, point.y))
        )
    }
    
    // MARK: - OCR Coordinate Correction
    
    func correctOCRCoordinates(_ ocrData: OCRData) -> OCRData {
        // OCR bounding box is in normalized coordinates (0.0-1.0)
        // Convert to absolute window coordinates
        let bbox = ocrData.boundingBox
        
        let absoluteX = windowFrame.origin.x + (bbox.origin.x * windowFrame.width)
        let absoluteY = windowFrame.origin.y + (bbox.origin.y * windowFrame.height)
        let absoluteWidth = bbox.width * windowFrame.width
        let absoluteHeight = bbox.height * windowFrame.height
        
        let correctedBounds = CGRect(
            x: absoluteX,
            y: absoluteY,
            width: absoluteWidth,
            height: absoluteHeight
        )
        
        return OCRData(
            text: ocrData.text,
            confidence: ocrData.confidence,
            boundingBox: correctedBounds
        )
    }
    
    // MARK: - Accessibility Coordinate Validation
    
    func validateAccessibilityCoordinates(_ accData: AccessibilityData) -> AccessibilityData {
        guard let position = accData.position else { return accData }
        
        // Ensure accessibility coordinates are within window bounds
        let validatedPosition = clampToWindow(position)
        
        return AccessibilityData(
            role: accData.role,
            description: accData.description,
            title: accData.title,
            help: accData.help,
            enabled: accData.enabled,
            focused: accData.focused,
            position: validatedPosition,
            size: accData.size,
            element: accData.element,
            subrole: accData.subrole,
            value: accData.value,
            selected: accData.selected,
            parent: accData.parent,
            children: accData.children
        )
    }
    
    // MARK: - Spatial Correlation
    
    func spatialDistance(between point1: CGPoint, and point2: CGPoint) -> Double {
        let dx = point1.x - point2.x
        let dy = point1.y - point2.y
        return sqrt(Double(dx * dx + dy * dy))
    }
    
    func isNearby(_ point1: CGPoint, _ point2: CGPoint, threshold: Double = 50.0) -> Bool {
        return spatialDistance(between: point1, and: point2) < threshold
    }
    
    // MARK: - Debug Information
    
    func debugCoordinateInfo(for point: CGPoint) -> [String: Any] {
        let normalized = normalize(point)
        let gridPos = gridPosition(for: point)
        
        return [
            "absolute": ["x": point.x, "y": point.y],
            "normalized": ["x": normalized.x, "y": normalized.y],
            "grid": gridPos.description,
            "windowFrame": [
                "x": windowFrame.origin.x,
                "y": windowFrame.origin.y,
                "width": windowFrame.width,
                "height": windowFrame.height
            ]
        ]
    }
}

// MARK: - Adaptive Density Mapper

class AdaptiveDensityMapper {
    let windowSize: CGSize
    let windowOrigin: CGPoint
    let cellWidth: CGFloat
    let cellHeight: CGFloat
    
    init(windowFrame: CGRect) {
        self.windowSize = windowFrame.size
        self.windowOrigin = windowFrame.origin
        
        self.cellWidth = windowSize.width / CGFloat(UniversalGrid.COLUMNS)
        self.cellHeight = windowSize.height / CGFloat(UniversalGrid.ROWS)
    }
    
    func gridPosition(for point: CGPoint) -> AdaptiveGridPosition {
        let relativeX = point.x - windowOrigin.x
        let relativeY = point.y - windowOrigin.y
        
        let colIndex = min(39, max(0, Int(relativeX / cellWidth)))
        let rowIndex = min(49, max(0, Int(relativeY / cellHeight)))
        
        let columnString = AdaptiveGridPosition.columnString(from: colIndex)
        let row = rowIndex + 1
        
        return AdaptiveGridPosition(columnString, row)
    }
    
    func pixelPosition(for gridPos: AdaptiveGridPosition) -> CGPoint {
        let x = windowOrigin.x + (CGFloat(gridPos.columnIndex) * cellWidth) + (cellWidth / 2)
        let y = windowOrigin.y + (CGFloat(gridPos.rowIndex) * cellHeight) + (cellHeight / 2)
        
        return CGPoint(x: x, y: y)
    }
    
    func cellBounds(for gridPos: AdaptiveGridPosition) -> CGRect {
        let x = windowOrigin.x + (CGFloat(gridPos.columnIndex) * cellWidth)
        let y = windowOrigin.y + (CGFloat(gridPos.rowIndex) * cellHeight)
        
        return CGRect(x: x, y: y, width: cellWidth, height: cellHeight)
    }
    
    var gridDensity: GridDensityMetrics {
        return GridDensityMetrics(
            cellWidth: cellWidth,
            cellHeight: cellHeight,
            pixelsPerCell: cellWidth * cellHeight,
            windowSize: windowSize
        )
    }
} 